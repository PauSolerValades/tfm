#import "@preview/lovelace:0.3.0": *
#import "utils.typ": todo, comment, def, procedure, flex-caption

This chapter continues @sec-data findings into the definitions of the parameter values required by the simulation configuration. The rationale behind the following parameters is explained: `session_duration`, `user_inter_session` (in @sec-cal-sessions and @sec-cal-dist), `post_inter_creation` (@sec-cal-interpost), `user_inter_action` (@sec-cal-interaction), `user_policy` (@sec-cal-policy), and the `propagation_delay` as reference metric to remove the time units in the analysis results. 

== Session Definition Process <sec-cal-sessions>

Several of the parameters needed to run the simulation depend on the session concept. A session has already been defined in @sec-model-sessions as $cal(O)(u)$, representing the times $t$ that a user is online rather than offline. Like most mathematical definitions, this is accurate but impractical to apply directly to the raw data, as the Firehose data analyzed in @sec-data-firehose contains no explicit reference to sessions. This occurs because the Firehose records state-change events, whereas sessions are traditionally inferred from when posts are served to the user—data that does not exist in the Firehose feed. Although these timeline data can be obtained from the AppView, they are highly proprietary due to their value in marketing, making them tightly restricted and not readily available. Therefore, the first — and most critical — task is to determine how a session should be adaptively inferred from the available data. Let's start by constructing a holistic, intuitive definition to isolate its most essential qualities.

#def(name: "Session")[
  A session is an interval of time in which the user is actively and meaningfully engaging with content or other users of the social network platform.  
]

The primary intuition behind this definition is that sessions are formed by an aggregation of events, and a session must end when those events become too far apart timewise. The definition also specifies that events must be *meaningful*, opening the door to filtering out minor background telemetry in favor of high-engagement actions, such as reposts, creations, or replies.

Now the key question is: given two consecutive actions by the same user, how long can the pause between them be before we consider the user to have logged off?

The EDA coverage analysis (@sec-data-firehose) showed that per-user inter-arrival gaps span six orders of magnitude, from seconds to days. A single global threshold — such as the 265 s elbow derived from the dominant stratum (see @apx-threshold for the fixed-threshold methodology) — will fragment power users into single-event noise while merging multi-day pauses into spurious sessions for casual users.

In essence, this problem is analogous to finding outliers in a dataset, and one of the simplest and most effective methods for doing so is Tukey's Fences, commonly used to detect outliers in box plots @lares-tukey. The core idea is to apply interquartile range (IQR) outlier detection over the activity gaps for every user $u in cal(U)$, defined as:

$ Delta_i^u = t_(i+1)^u - t_i^u $

This yields a vector $bold(Delta^u)$, to which we apply the following threshold function to define a session boundary:

$
delta(u) = max(Q_3(u) + k dot "IQR"(u), 120 "s")
$

where $"IQR"(u) = Q_3(u) - Q_1(u)$ is the user's interquartile range, and $k=1.5$ by convention. The $max$ function establishes a hard floor to prevent rapid bursts of activity from collapsing the threshold into an unrealistically short session, while also accounting for baseline periods where a user is actively reading but not generating events.The method was applied to both source tables (see @sec-data-firehose), producing two complementary session tables:
- *`data.sessions_all`* ($47.4 times 10^6$ sessions, $2.3 times 10^6$ users): includes all event types (likes, reposts, follows, blocks, posts, replies).
- *`data.sessions_engagement`* ($19.6 times 10^6$ sessions, $2.4 times 10^6$ users): excludes likes.

@tbl-sessions-summary compares the two tables. The difference is by design: including likes produces denser, shorter sessions (median 23 s) dominated by rapid-fire micro-bursts; excluding likes produces sparser, longer sessions (median 4.8 min) more appropriate for studying content creation rhythms.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*sessions_all*], [*sessions_engagement*], [*Unit*],
    table.hline(stroke: 0.5pt),
    [Sessions], [$47.4 times 10^6$], [$19.6 times 10^6$], [—],
    [Median duration], [23], [290], [s],
    [Mean duration], [882], [25,025], [s],
    [Median inter-session gap], [36.5], [195], [min],
    [Zero-duration sessions], [33.2], [22.7], [%],
    [Median per-user gap], [2.4], [558], [min],
    [Likes-only sessions], [59.2], [—], [%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Session-level summary statistics for the two Tukey IQR session tables.],
    [Session-level summary statistics for the two Tukey IQR session tables. `sessions_all` captures rapid-fire browsing (median 23 s); `sessions_engagement` captures content creation sessions (median 4.8 min).],
  )
) <tbl-sessions-summary>

The distribution fitting described below uses `sessions_all` for durations (representing the browsing rhythm) and inter-session gaps (representing return-to-platform intervals), as these quantities must capture the complete activity pattern including passive engagement.

== Session Distribution Fitting
<sec-cal-dist>

With sessions defined, the statistical distributions governing session durations and inter-session gaps were characterised via per-user MLE fitting. The analysis was performed by the R script `sessions/analysis/fit_distributions.R`, which reads a `csv` with session data exported from StarRocks via `sessions/analysis/export_sessions.py`.

For each user with $>= 10$ data points ($1.16 times 10^6$ users from `sessions_all`), five candidate distributions were fit — Pareto (MLE with KS-based $x_min$ estimation @clauset2009powerlaw), exponential, log-normal, Weibull, and gamma — and the best was selected via Vuong's log-likelihood ratio test ($alpha = 0.05$) with AIC as a tie-breaker.
#todo[citar què és el Vuongs log-likelihood test]

@tbl-cal-dist-fit summarises the results. Power-law dominates both quantities.

#figure(
  table(
    columns: 3,
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Distribution*], [*Session duration (%)*], [*Inter-session gap (%)*],
    table.hline(stroke: 0.5pt),
    [Power-law], [53.0], [50.6],
    [Lognormal], [9.0], [25.9],
    [Weibull], [9.5], [22.3],
    [Exponential], [12.6], [$< 0.01$],
    [Gamma], [2.1], [$< 0.01$],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Distribution fitting results for $1.16 times 10^6$ users with $>= 10$ sessions.],
    [Distribution fitting results for $1.16 times 10^6$ users with $>= 10$ sessions from `sessions_all`. Power-law wins for both session durations (53%) and inter-session gaps (51%). Exponential is effectively absent for gaps (1 user).],
  )
) <tbl-cal-dist-fit>

*Power-law dominates.* For session durations, the median exponent is $alpha = 2.47$ with $x_min = 98$ s (1.6 min). For inter-session gaps, $alpha = 2.05$ with $x_min = 5,806$ s (1.6 h). Both lie in the $2$–$3$ range — finite mean, infinite variance. The $x_min$ values reveal a two-regime structure: the power-law only governs the tail; the body of short sessions and brief gaps follows a different regime.

#figure(
  image("../images/calibration/7-1_duration_pareto_params.png", width: 70%),
  caption: flex-caption(
    [Pareto parameter densities for session durations.],
    [Pareto parameter densities for session durations ($alpha$ left, $x_min$ right). Median $alpha = 2.47$, $x_min = 98$ s (1.6 min).],
  )
) <fig-cal-dur-pareto>

#figure(
  image("../images/calibration/7-1_gap_pareto_params.png", width: 70%),
  caption: flex-caption(
    [Pareto parameter densities for inter-session gaps.],
    [Pareto parameter densities for inter-session gaps. Median $alpha = 2.05$, $x_min = 5,806$ s (1.6 h). The gap $x_min$ is substantially higher than duration $x_min$, reflecting the longer timescales of inter-session pauses.],
  )
) <fig-cal-gap-pareto>

*Lognormal is the credible alternative for gaps.* 25.9% of users have log-normally distributed inter-session gaps, with median $mu = 9.84$, $sigma = 0.96$, corresponding to a central tendency of $approx 5.2$ h with wide spread. For session durations, lognormal users have median $mu = 5.21$, $sigma = 0.63$, corresponding to $approx 3.1$ min.

#figure(
  image("../images/calibration/7-1_duration_lognormal_params.png", width: 70%),
  caption: flex-caption(
    [Lognormal parameter densities for session durations.],
    [Lognormal parameter densities for session durations ($mu$ left, $sigma$ right). Median $mu = 5.21$, $sigma = 0.63$, corresponding to a central tendency of $approx 3.1$ min.],
  )
) <fig-cal-dur-lognormal>

#figure(
  image("../images/calibration/7-1_gap_lognormal_params.png", width: 70%),
  caption: flex-caption(
    [Lognormal parameter densities for inter-session gaps.],
    [Lognormal parameter densities for inter-session gaps. Median $mu = 9.84$, $sigma = 0.96$, central tendency $approx 5.2$ h. Greater dispersion than durations.],
  )
) <fig-cal-gap-lognormal>

*Weibull hazard interpretation.* For session durations, the Weibull shape has median $k = 1.58$ — mildly increasing hazard (sessions tend to end on a schedule). 24% of duration-Weibull users have $k < 1$ (decreasing hazard — the longer you browse, the more engaged you get). For inter-session gaps, median $k = 1.08$ — nearly exponential, with 46% of users showing $k < 1$ (decreasing hazard: the longer you've been away, the *less* likely you are to return — abandonment or sleep).

#figure(
  image("../images/calibration/7-1_duration_weibull_params2.png", width: 70%),
  caption: flex-caption(
    [Weibull parameter densities for session durations.],
    [Weibull parameter densities for session durations (shape $k$ left, scale $lambda$ right). Median $k = 1.58$, median $lambda = 258$ s (4.3 min).],
  )
) <fig-cal-dur-weibull>

#figure(
  image("../images/calibration/7-1_gap_weibull_params2.png", width: 70%),
  caption: flex-caption(
    [Weibull parameter densities for inter-session gaps.],
    [Weibull parameter densities for inter-session gaps. Median $k = 1.08$ — 46% of users have $k < 1$ (decreasing hazard, abandonment). Median $lambda = 35,229$ s (9.8 h).],
  )
) <fig-cal-gap-weibull>

*Exponential is definitively ruled out* for inter-session gaps (1 user out of 1.16M). Inter-session absences are structured, not memoryless. For durations, 12.6% of users are exponential — the only credible use of memoryless behaviour.

@tbl-cal-dist-params consolidates the parameter estimates.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Distribution*], [*Parameter*], [*Median (dur.)*], [*Median (gap)*], [*Interpretation*],
    table.hline(stroke: 0.5pt),
    [Pareto], [$alpha$], [2.47], [2.05], [Exponent in $2$–$3$ range (finite mean, infinite variance)],
    [Pareto], [$x_min$], [98 s (1.6 min)], [5,806 s (1.6 h)], [Tail threshold; body below follows a different regime],
    [Lognormal], [$mu$], [5.21], [9.84], [$exp(mu) approx 183$ s dur., $18{,}700$ s gap],
    [Lognormal], [$sigma$], [0.63], [0.96], [Greater dispersion in gaps than durations],
    [Weibull], [shape $k$], [1.58], [1.08], [46% of gap Weibull users have $k < 1$ (decreasing hazard)],
    [Weibull], [scale $lambda$], [258 s (4.3 min)], [35,229 s (9.8 h)], [Characteristic timescale],
    [Exponential], [mean $1/lambda$], [172 s (2.9 min)], [—], [Only 12.6% of users for durations; absent for gaps],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Full parameter estimates for all four distribution families from `sessions_all`.],
    [Full parameter estimates for all four distribution families from `sessions_all` ($1.16 times 10^6$ users). Medians are reported as they are robust to extreme outliers. Generated by `fit_distributions.R`.],
  )
) <tbl-cal-dist-params>

*Simulation mapping.* The `session_duration` and `inter_session_time` fields on the `User` struct are `Pareto(f64)` — the simulation natively supports power-law distributions. Per-user $(alpha, x_min)$ pairs are sampled from the ECDF and loaded from `params/session_duration_params.txt` and `params/inter_session_params.txt` at startup (see @sec-calibration-summary). The Pareto is the best fit for 53% of users (durations) and 51% (gaps); the remaining lognormal, Weibull, and exponential users are approximated by Pareto draws from the same ECDF, preserving the observed per-user heterogeneity in a single distribution family.

This allows to properly characterize how both the user `session_duration` and `inter_session_time` should be characterized.

#procedure(caption: flex-caption([Assign session duration to a synthetic user.], [Assign session duration to a synthetic user]))[
  #pseudocode-list[
    + *procedure* $"AssignSessionDuration"(u)$
      + *Input:* per-user MLE parameter pools from $1.16 times 10^6$ users in `sessions_all`
      + $F arrow.l "Categorical"( 
        "Pareto" = 0.530, 
        "Lognormal" = 0.090,  
        "Weibull" = 0.095, 
        "Exponential" = 0.126, 
        "Gamma" = 0.021 
      )$
      + *if* $F = "Pareto"$ *then*
        + $(alpha, x_min) arrow.l "random pair from Pareto pool"$
      + *else if* $F = "Lognormal"$ *then*
        + $(mu, sigma) arrow.l "random pair from Lognormal pool"$
      + *else if* $F = "Weibull"$ *then*
        + $(k, lambda) arrow.l "random pair from Weibull pool"$
      + *else if* $F = "Exponential"$ *then*
        + $lambda arrow "ECDF"(Lambda_"Exponential")$
      + *else*
        + $(k, theta) arrow.l "random pair from Gamma pool"$
      + *end*
      + *Store* $(alpha, x_min)$ from the user's Pareto fit (every user has one regardless of best-fit family)
      + *return* $(alpha, x_min)$
    + *end*
  ]
] <proc-cal-session-duration>

#procedure(caption: flex-caption([Assign inter-session gap to a synthetic user.], [Assign inter-session gap to a synthetic user]))[
  #pseudocode-list[
    + *procedure* $"AssignInterSessionGap"(u)$
      + *Input:* per-user MLE parameter pools from $1.16 times 10^6$ users in `sessions_all`
      + $F arrow "Categorical"("Pareto" = 0.515, "Lognormal" = 0.263, "Weibull" = 0.227)$  // normalised from @tbl-cal-dist-fit
      + *if* $F = "Pareto"$ *then*
        + $(alpha, x_min) arrow.l "random pair from Pareto pool"$
      + *else if* $F = "Lognormal"$ *then*
        + $(mu, sigma) arrow.l "random pair from Lognormal pool"$
      + *else*
        + $(k, lambda) arrow.l "random pair from Weibull pool"$
      + *end*
      + *Store* $(alpha, x_min)$ from the user's Pareto fit
      + *return* $(alpha, x_min)$
    + *end*
  ]
] <proc-cal-inter-session>

== Inter-Post Creation Times
<sec-cal-interpost>

The next parameter to calibrate is how many posts does a single user produce, the `post_inter_creation` parameter. This was measured from `data.engaged_events` with just normal creations and replies, using session boundaries from `data.sessions_engagement`.

The data was analyzed in two ways: global (gap to the immediately preceding post by the same user, regardless of sessions) and within-session (gap within the same `sessions_engagement` session). For each user with $>= 10$ positive gaps, five distributions were fit via MLE on a 50,000-user sample.

@tbl-cal-interpost-summary gives the global statistics comparing the two modes.

#figure(
  table(
    columns: 3,
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Statistic*], [*Global*], [*Within-session*],
    table.hline(stroke: 0.5pt),
    [Total gaps], [$26.4 times 10^6$], [$21.3 times 10^6$],
    [Median gap], [9.7 min], [4.8 min],
    [Mean gap], [4.2 h], [2.1 h],
    [$P_90$ gap], [13.0 h], [4.0 h],
    [$P_99$ gap], [62.1 h], [37.4 h],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Inter-post gap summary statistics.],
    [Inter-post gap summary statistics. Within-session gaps are $2.0 times$ smaller than global gaps (median 4.8 min vs 9.7 min), confirming that users post in bursts during sessions.],
  )
) <tbl-cal-interpost-summary>

@tbl-cal-interpost-fits gives the best-fit distribution breakdown of both modes.

#figure(
  table(
    columns: 4,
    align: (left, center, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Distribution*], [*Global (%)*], [*Within-session (%)*], [*Interpretation*],
    table.hline(stroke: 0.5pt),
    [Power-law], [53.3], [63.1], [Bursty, heavy-tailed],
    [Lognormal], [26.4], [21.3], [Multiplicative noise around a typical cadence],
    [Weibull], [20.2], [13.8], [Hazard-driven; 87% decreasing hazard],
    [Exponential], [$< 0.01$], [1.5], [Effectively ruled out],
    [Gamma], [0.1], [0.2], [Negligible],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Best-fit distribution breakdown for inter-post gaps.],
    [Best-fit distribution breakdown for inter-post gaps ($N = 50{,}000$ users). Power-law dominates in both modes (53% global, 63% within-session). Exponential is effectively absent.],
  )
) <tbl-cal-interpost-fits>

#figure(
  image("../images/calibration/7-2_interpost_best_dist2.png", width: 85%),
  caption: flex-caption(
    [Best-fit distribution per gap type.],
    [Best-fit distribution per gap type. Power-law dominates.],
  )
) <fig-cal-interpost-best>

Power-law users have median $alpha = 1.80$ (global) and $alpha = 2.39$ (within-session). For the global case, $alpha < 2$ means infinite variance — extreme burstiness. The median $x_min$ is 44 min (global) and 11 min (within-session).

#figure(
  image("../images/calibration/7-2_interpost_alpha_hist2.png", width: 75%),
  caption: flex-caption(
    [Histogram of power-law exponent $alpha$ for inter-post gaps.],
    [Histogram of power-law exponent $alpha$ for inter-post gaps. ],
  )
) <fig-cal-interpost-alpha>

*Simulation mapping.* The `post_inter_creation` config field is calibrated with a Pareto, sampling $(alpha, x_min)$ per synthetic user from the ECDF shown in @fig-cal-interpost-pareto-ecdf. The median global gap of 9.7 min serves as a sanity check on the central tendency. The within-session median (4.8 min) is an alternative for simulations that explicitly model session boundaries, but the current architecture does not distinguish global vs within-session creation, so the global mode is the appropriate target.

#procedure(caption: flex-caption([Assign inter-post creation gap to a synthetic user.], [Assign inter-post creation gap to a synthetic user]))[
  #pseudocode-list[
    + *procedure* $"AssignInterCreationGap"(u)$
      + *Input:* per-user MLE parameter pools from $N = 50{,}000$ users in `engaged_events` (global mode)
      + $F arrow "Categorical"("Pareto" = 0.534, "Lognormal" = 0.264, "Weibull" = 0.202)$  // normalised from @tbl-cal-interpost-fits
      + *if* $F = "Pareto"$ *then*
        + $(alpha, x_min) arrow.l "random pair from Pareto pool"$
      + *else if* $F = "Lognormal"$ *then*
        + $(mu, sigma) arrow.l "random pair from Lognormal pool"$
      + *else*
        + $(k, lambda) arrow.l "random pair from Weibull pool"$
      + *end*
      + *Store* $(alpha, x_min)$ from the user's Pareto fit (every user has one regardless of best-fit family)
      + *return* $(alpha, x_min)$
    + *end*
  ]
] <proc-cal-inter-creation>

== Inter-Action Time
<sec-cal-interaction>

The `user_inter_action` parameter governs the time between consecutive posts a user sees on their timeline — how frequently a post appears for evaluation. This quantity is one of the most important in the simulation and, paradoxically, cannot be directly measured from the firehose. The Bluesky Firehose records user *actions* (likes, reposts, follows, posts) but not *passive views*: there is no event emitted when a user scrolls past a post without interacting. To obtain this data one would need access to the Bluesky AppView logs (the frontend the user interacts with), which are not public. The value must therefore be justified by reasoning from observable platform behaviour.

=== Exponential Distribution 

We model the inter-action time as $"Exp"(lambda)$. Two arguments support this choice.

The first is experiential: microblogging consumption is dominated by rapid scrolling. Most posts receive a glance of one or two seconds before the user moves on; a minority receive deeper attention (reading the full text, inspecting an image, considering a reply), but these are few and far between. This pattern — many short gaps, a long thin tail of larger gaps — is the hallmark of an exponential distribution.

The second is structural: if the sequence of posts appearing in a user's timeline forms a Poisson process, the inter-arrival times are exponentially distributed and memoryless #todo[reference a Poisson process]. The memoryless property is reasonable here: the time a user has already spent looking at the current post carries no information about how long they will spend on the next one. Each post is an independent decision point.

=== Exponential Parameter 

What is a plausible value for $1/lambda$, the average time a user spends per post? The `sessions_all` data provides empirical anchors: the median browsing session lasts 23 s and contains a median of 3 interactions (almost exclusively likes). The user is clearly not spending 23 seconds reading 3 posts — they are scrolling past many, acting on few.

On a mobile microblogging client, a user can flick past a post in under a second; on desktop, a quick scan takes 2–3 seconds. Posts that trigger a like or repost require slightly longer (reading the text, reaching for the button). Weighing these, an average of $1/lambda = 3$ s per post is a conservative estimate: it allows for a mix of sub-second skips and occasional 5–10 second engagements. This translates to $lambda = 1/3$ posts per second, or 20 posts per minute of active browsing.

#figure(
  table(
    columns: 3,
    align: (left, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Quantity*], [*Value*], [*Rationale*],
    table.hline(stroke: 0.5pt),
    [Distribution], [$"Exp"(lambda)$], [Memoryless; matches rapid-scroll consumption pattern],
    [Mean $1/lambda$], [3 s], [Conservative blend of sub-second skips and deeper reads],
    [Posts per minute of browsing], [$approx 20$], [Consistent with microblogging UX],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Inter-action time calibration.],
    [Inter-action time calibration. The exponential distribution with mean 3 s is chosen as a justified estimate; sensitivity analysis varying this value from 1 s to 10 s should accompany simulation runs.],
  )
) <tbl-cal-interaction>

*Simulation mapping.* The `user_inter_action` config expects an exponential with mean. A value of 3 s is recommended. Given that this parameter is an educated assumption rather than a direct measurement, sensitivity analysis should vary it across the 1–10 s range to assess its impact on diffusion outcomes.

== Engagement Rate
<sec-cal-policy>

With the inter-action time calibrated, we can now estimate how many posts a user sees per session and, from that, the probability they act on each one.

A session of duration $d$ with inter-action time $"Exp"(1/3)$ exposes the user to approximately $d / 3$ posts. However, 33.2% of sessions have zero duration (co-occurring events at the same microsecond), for which $d/3 = 0$ would imply the user saw nothing — clearly false, since these sessions contain real interactions. A floor is therefore applied:

$
"posts_seen"(s) = max( ("duration"(s)) / (3),  "interactions"(s) + 4 )
$

where $4$ is the assumed minimum number of unseen posts even in the briefest session.

Computed over 47.4M sessions in `sessions_all`, the median engagement rate is:

$
"engagement_rate"(s) = ("interactions"(s)) / ("posts_seen"(s))
$

which yields a median of $approx 20%$ (mean $approx 19.5%$). In other words, the typical Bluesky user likes or reposts roughly one in five posts they see during a browsing session.

=== The $pi$ Policy

The categorical $pi$ policy required by the simulation (§@sec-method-des-assumptions) is decomposed from the engagement rate. Among all interactions (likes + reposts) in `sessions_all`, likes account for 93.8% and reposts for 6.2%. Therefore:

$
pi_"ignore" approx 80% quad pi_"like" approx 18.8% quad pi_"repost" approx 1.2%
$

For the simulation's JSON `user_policy.categorical.weights` field, this translates to `[0.80, 0.188, 0.012]` corresponding to `["ignore", "like", "repost"]`.

The engagement rate is sensitive to the assumed inter-action time. With $1/lambda = 1$ s (rapid scanning), the median engagement rate drops to $approx 7%$; with $1/lambda = 10$ s (careful reading), it rises to $approx 50%$. The 3 s assumption places the estimate in the middle of this range.

== Consolidated Calibration
<sec-calibration-summary>

The simulation engine (`config.zig`) expects specific distribution types for each calibrated quantity. This section maps every empirical finding to its exact Zig type and initialization.

=== Per-User Pareto Sampling
<sec-cal-summary-pareto>

The simulation natively supports Pareto distributions for `session_duration`, `inter_session_time`, and `inter_creation_time` — three `Pareto(f64)` fields on the `User` struct. Rather than using fixed population-median parameters, each synthetic user receives a unique $(alpha, x_min)$ pair sampled from the empirical ECDF of per-user MLE fits. The sampled parameters are written to three text files that the simulation reads at startup via `fillPareto()`:

- `params/session_duration_params.txt` — one $(alpha, x_min)$ pair per user for session durations
- `params/inter_session_params.txt` — one $(alpha, x_min)$ pair per user for inter-session gaps
- `params/inter_creation_params.txt` — one $(alpha, x_min)$ pair per user for inter-post creation gaps

Each file is a newline-separated list of `shape scale` pairs (where `shape = alpha` and `scale = x_min`). The simulation samples `sample_size = 10000` random rows per run, assigning each user a Pareto `init(shape, scale)`. This preserves the full per-user heterogeneity observed in the firehose: bursty users get $alpha < 2$, regular users get $alpha > 3$.

#figure(
  image("../images/calibration/7-1_pareto_param_ecdf.png", width: 85%),
  caption: flex-caption(
    [Empirical CDF of Pareto parameters for sessions.],
    [Empirical CDF of Pareto parameters $alpha$ (top) and $x_min$ (bottom) for session durations (left) and inter-session gaps (right), fitted per-user to `sessions_all`. These distributions are sampled to generate `params/session_duration_params.txt` and `params/inter_session_params.txt`.],
  )
) <fig-cal-pareto-ecdf>

#figure(
  image("../images/calibration/7-2_pareto_inter_post_ecdf.png", width: 75%),
  caption: flex-caption(
    [Empirical CDF of Pareto parameters for inter-post creation gaps.],
    [Empirical CDF of Pareto parameters for inter-post creation gaps (global mode), fitted per-user to `engaged_events`. Sampled to generate `params/inter_creation_params.txt`.],
  )
) <fig-cal-interpost-pareto-ecdf>


Although the procedures in @proc-cal-session-duration, @proc-cal-inter-session and @proc-cal-inter-creation describe the most correct approach — sampling the true best-fit distribution family per user and drawing its parameters from the empirical pool — the simulation simplifies this by collapsing all users to Pareto. The reasoning is pragmatic rather than ideal: implementing the full sampling logic in Zig would require adding Lognormal, Weibull, and Gamma to the distributions library, as well as a dispatch mechanism to select between them per user at startup —-all entirely feasible, but the implementation and validation effort would exceed the time budget available for this phase. By retaining only the Pareto family and sampling its parameters from the ECDF of all per-user Pareto fits (regardless of each user's true best-fit), the simulation preserves the full per-user heterogeneity observed in the firehose while keeping a single distribution type per field. The cost is that the minority of users whose inter-event gaps genuinely follow a Lognormal, Weibull, or Exponential regime are approximated by Pareto draws — a simplification that is acceptable for the evaluation phase and can be lifted in future work.


=== Parameter Mapping

@tbl-cal-sim-mapping maps each simulation field to its calibrated value and Zig type.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Simulation field*], [*Calibrated value*], [*Source*],
    table.hline(stroke: 0.5pt),
    [`session_duration`], [Per-user $(alpha, x_min)$ from `params/session_duration_params.txt` (53% best-fit, median $alpha = 2.47$, $x_min = 98$ s)], [@sec-cal-dist],
    [`inter_session_time`], [Per-user $(alpha, x_min)$ from `params/inter_session_params.txt` (51% best-fit, median $alpha = 2.05$, $x_min = 5,806$ s)], [@sec-cal-dist],
    [`inter_creation_time`], [Per-user $(alpha, x_min)$ from `params/inter_creation_params.txt` (53% best-fit, median $alpha = 1.80$, $x_min = 44$ min)], [@sec-cal-interpost],
    [`user_inter_action`], [Global $lambda = 1/3$ (mean 3 s)], [@sec-cal-interaction],
    [`user_policy`], [Weights: $[0.80, 0.188, 0.012]$ on `ignore`, `like`, `repost`], [@sec-cal-policy],
    [`propagation_delay`], [1 s (platform overhead)], [@sec-method-ctic],
    [`interaction_delay`], [1 s], [@sec-method-des-assumptions],
    [`creation_delay`], [1 s], [@sec-method-des-assumptions],
    [`offline_startup_ratio`], [0.5 (half of users start offline)], [Assumption],
    [`warmup_post_inter_creation`], [$cal(U)(0, 1000)$, `Interval.cc`], [Synthetic warmup],
    [`warmup_time`], [1000], [Synthetic warmup],
    [`horizon`], [5000], [@sec-exec-stationary],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Consolidated simulation calibration.],
    [Consolidated simulation calibration as implemented in `config.zig` and `graph_network.zig`. The three Pareto-distributed fields use per-user parameter sampling from ECDF text files; `user_inter_action` uses a global exponential; delays are constant 1 s. The warmup post creation is uniform over the warmup window.],
  )
) <tbl-cal-sim-mapping>

