#import "@preview/lovelace:0.3.0": *
#import "utils.typ": todo, comment, def, procedure, flex-caption

This chapter continues @sec-data findings into the definitions of the parameter values required by the simulation configuration. The rationale behind the following parameters is explained: `session_duration`, `user_inter_session` (in @sec-cal-sessions and @sec-cal-dist), `post_inter_creation` (@sec-cal-interpost), `user_inter_action` (@sec-cal-interaction), `user_policy` (@sec-cal-policy), and the `propagation_delay` as reference metric to remove the time units in the analysis results. 

== Session Definition & Requirements
<sec-cal-sessions>

The whole simulation design rests on the user defined behaviour of a "session", which has to be constructed from the Bluesky Firehose events descibed in @sec-data. Despite a mathematical modelization defined on @sec-model-sessions as an element of $cal(O)(u)$, this section will provide a more intuitive definition, as well as success crteria on what a good session is.

#def(name: "Session")[
  A session is an interval of time in which the user is connected and using the social network platform.  
]

Despite being interested in a more restrictive definition, such as "the interval of time in which the user is _actively and meaningfully_ engaging with _content_", this definition of session is impossible to obtain with the data from the Firehose, despite the current one being more than enough for the puroposes of this work. More about this in @apx-sessions-def.
 
The primary intuition behind this definition is that sessions are formed by an aggregation of events, and a session must end when those events become too far apart timewise. The definition also specifies that events must be meaningful, opening the door to filtering out minor background telemetry in favor of high-engagement actions, such as reposts, creations, or replies.

The upper definiton of session is the one that veryfies the following postulates:
- Existance of short-sessions: it is very well known that users do notification checking, or check the social network in lots of microdoses (bathroom breaks, boredom while waiting on a queue), therefore the method must be able to produce singelton sessions (one element), and very short ones that are near: that is, it must be very fine grained.
- Non existance of macrosessions: it is not expected to be a lot of very long sessions, as stated in the previous point: several 8 to 10 hour sessions can exist but not be a majority.
- Akind to known distributions: the results must produce univariate distributions (at most clearly bivariate) as this serves as the input of a DES simulation.
- Circadianty: the macropatterns of day night for non-globally spoken languages in the dataset must be coherent with its timezone (such as german, japanese or other labelled languages.)

Now the key question is: given two consecutive actions by the same user, how long can the pause between them be before we consider the user to have logged off?

== Session Creation

The method picked to create the session is DBSCAN (@sec-method-session-dbscan) with parameters `ms=2` and $epsilon=300$. See @apx-session-dbscanparams for details regarding candidates and why this method and these parameters are the correct choice for this problem.

The produced sessions verify the definition postulates of @sec-cal-sessions, as summarised in @tbl-cal-session-stats and @fig-cal-session-hists: $40.71%$ of the 44.9M sessions are singletons and $62.77%$ last under a minute (fine-grained short sessions); the median lasts 110 s and only $0.07%$ exceed one hour (no macro-sessions); the population histograms follow single heavy-tailed laws ; and session starts align with each language's timezone (circadianity, @fig-cal-circadian). The full statistics and candidate-method comparisons are reported in @apx-session-dbscanparams.

#figure(
  grid(
    columns: (1fr, 1fr),
    column-gutter: 1.5em,
    [
      #table(
        columns: 2,
        align: (left, right),
        stroke: none,
        table.hline(stroke: 0.8pt),
        [*Quantity*], [*Value*],
        table.hline(stroke: 0.5pt),
        [Total sessions], [44,925,735],
        [Singletons], [40.71%],
        [Median duration], [110 s],
        [Mean duration], [230 s],
        [P90], [559 s],
        [P95], [833 s],
        table.hline(stroke: 0.8pt),
      )
    ],
    [
      #table(
        columns: 2,
        align: (left, right),
        stroke: none,
        table.hline(stroke: 0.8pt),
        [*Quantity*], [*Value*],
        table.hline(stroke: 0.5pt),
        [P99], [1,710 s],
        [Maximum], [691,196 s (~8 days)],
        [Sessions < 1 min], [62.77%],
        [Sessions > 1 h], [0.07%],
        [Sessions > 4 h], [0.00%],
        [Sessions > 8 h], [0.00%],
        table.hline(stroke: 0.8pt),
      )
    ],
  ),
  caption: flex-caption(
    [Statistics of the produced sessions.],
    [Duration statistics of the DBSCAN ($epsilon = 300$ s, $m_"pts" = 2$) sessions over the whole production table ($N = 44.9 times 10^6$ sessions).],
  )
) <tbl-cal-session-stats>

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    figure(image("../images/calibration/session_hist_duration.png"), caption: [Session duration]),
    figure(image("../images/calibration/session_hist_gap.png"), caption: [Inter-session gap]),
  ),
  caption: flex-caption(
    [Session duration and inter-session gap distributions.],
    [Distributions of session durations and inter-session gaps of the produced sessions. Both are heavy-tailed; the gap histogram shows the clean lower edge at $epsilon = 300$ s.],
  )
) <fig-cal-session-hists>

#figure(
  grid(
    columns: 3,
    column-gutter: 0.8em,
    figure(image("../images/calibration/circadian_de.png"), caption: [German]),
    figure(image("../images/calibration/circadian_ko.png"), caption: [Korean]),
    figure(image("../images/calibration/circadian_ja.png"), caption: [Japanese]),
  ),
  caption: flex-caption(
    [Circadian patterns of session starts by language.],
    [Distribution of the session-start hour for German, Korean and Japanese users; the evening peaks follow each language's main timezone.],
  )
) <fig-cal-circadian>


== Goodness-of-fit Session per User
<sec-cal-dist>

With the sessions created, it is possible to fit distributions of `session_length` and `inter_session_lenght` per every user of the dataset. As a reminder
- `session_length`: sampling the distribution should tell us how long will the user current session last. The goodness-of-fit test will be applied to the duration of all the user session length.
- `inter_session_duration`: sampling the distribution should give for how long the user is going to be offline. The goodness-of-fit test will be applied to all the duration between the ending of a session and the start of the next consecutive one ---what has been called "gap" due to being in between sessions---. It is worth mentcioning that the DBSCAN method will produce a gaps distribution shifted by $epsilon=300$, as there cannot be gap smaller than $epsilon$; the histograms showcased are all already shifted that quantity $Y = X - 300$. 

As this is inherently human behaviour ---as Barabási @barabási2005bursts states--- the distribution chosen for the goodness-of-fit test have to have heavy-tails and high peaks, as well as very "similar" forms. The ones chosen are the Exponential, Gamma, Lognormal, Weibull, Frisk (logistic dist), and Power-Law familiy distributions: Pareto, Lomax and Generalized Pareto Distribution.#footnote[Lomax is a reparametrization of the Generalized Pareto, and the Pareto looks to cover the boundary case.]

To select between the best fit, Akaike Information Criterion is used to favor parsimony. For the goodness-of-fit test, as the distributions have heavy tails, we also added Cramér-von Mises and Anderson-Darling statistics as well as the de facto Kolmogorov-Smirnov test, evaluated all agains the ECDF of the session and gaps data. See @apx-method-gof-dist for more information. Additionally, all users with less than 30 sessions or 30 gaps have been excluded from the fitting, which represent roughly 1.13M users (about 82% of the users with fits on both quantities, $1.37 times 10^6$ reduced to $2.43 times 10^5$).

@tbl-cal-dist-family reports, for every family, the number and percentage of users for which it was the AIC winner, for the two columns separately.

#figure(
  grid(
    columns: (1fr, 1fr),
    column-gutter: 1em,
    [
      #align(center, text(weight: "bold")[Session durations])
      #table(
        columns: 3,
        align: (left, right, right),
        stroke: none,
        table.hline(stroke: 0.8pt),
        [*Family*], [*Users*], [*%*],
        table.hline(stroke: 0.5pt),
        [Exp], [67,681], [27.83%],
        [Weibull], [59,558], [24.49%],
        [Gamma], [44,454], [18.28%],
        [Lognorm], [40,585], [16.69%],
        [Power-law], [27,349], [11.24%],
        [Fisk], [3,590], [1.48%],
        table.hline(stroke: 0.5pt),
        [*Total*], [*243,217*], [*100%*],
        table.hline(stroke: 0.8pt),
      )
    ],
    [
      #align(center, text(weight: "bold")[Inter-session lenght])
      #table(
        columns: 3,
        align: (left, right, right),
        stroke: none,
        table.hline(stroke: 0.8pt),
        [*Family*], [*Users*], [*%*],
        table.hline(stroke: 0.5pt),
        [Weibull], [119,140], [48.99%],
        [Lognorm], [74,284], [30.54%],
        [Power-law], [37,364], [15.36%],
        [Fisk], [12,412], [5.10%],
        [Gamma], [14], [0.01%],
        [Exp], [3], [0.00%],
        table.hline(stroke: 0.5pt),
        [*Total*], [*243,217*], [*100%*],
        table.hline(stroke: 0.8pt),
      )
    ],
  ),
  caption: flex-caption(
    [AIC-best family per user of `session_lenght` and `inter_session_duration`.],
    [AIC-best distribution family per user, for session durations (left) and inter-session length (right), each sorted by descending share.],
  )
) <tbl-cal-dist-family>

Session durations are spread across the exponential (27.8%), Weibull (24.5%), gamma (18.3%), lognormal (16.7%) and power-law (11.2%), accounting for 99.52% of total users. Fisk (1.5%) is the only minority, and can be neglected.

Gaps remain more concentrated than durations: the Weibull (49.0%), lognormal (30.5%) and power-law (15.4%) families account for roughly 95% of users, with Fisk (5.1%) and negligible gamma and exponential. The gap behaviour is therefore well captured by the majority families.

Now we must study how the session-gap pair is distributed across users, as there might be a relationship between the session and the gap distributions. @tbl-cal-pair-dist shows the distribution of pairs over the same active users. In fact, adding the rows gives the same as @tbl-cal-dist-family left, and the colums of the right one.

#figure(
  table(
    columns: 8,
    align: (left, center, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [], table.vline(stroke: 0.5pt), [*Weibull*], [*Lognorm*], [*Power-law*], [*Fisk*], [*Gamma*], [*Exp*], [*Total*],
    table.hline(stroke: 0.5pt),
    [*Exp*], [16.2%], [7.8%], [3.0%], [0.8%], [0], [0], [*27.8%*],
    [*Weibull*], [10.1%], [8.4%], [4.4%], [1.5%], [0], [0], [*24.5%*],
    [*Gamma*], [8.4%], [5.9%], [3.0%], [1.0%], [0], [0], [*18.3%*],
    [*Lognorm*], [8.0%], [4.5%], [3.1%], [1.0%], [0], [0], [*16.7%*],
    [*Power-law*], [5.7%], [3.5%], [1.6%], [0.5%], [0], [0], [*11.2%*],
    [*Fisk*], [0.6%], [0.4%], [0.2%], [0.3%], [0], [0], [*1.5%*],
    [*Gap total*], [*49.0%*], [*30.5%*], [*15.4%*], [*5.1%*], [*0*], [*0*], [*100%*],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Per-user best-fit family: session duration vs inter-session gap.],
    [Rows are session-duration families and columns are inter-session gap families; each cell gives the share of users with that combination, and the margins give the per-family totals.],
  )
) <tbl-cal-pair-dist>

The same distribution is visualised in @fig-pair-family-bars, where the 24 largest combinations are shown in descending order (the eight smallest, 17 users in total, are omitted).

As it can be seen both in @tbl-cal-pair-dist and in @fig-pair-family-bars, the pairwise distributions are far less dominant and more spread across, specially taking into account the more dominant distributions. As the table axis are sorted by decreasing amount of users as the original tables, the further from the beginning of (Exp, Weibull) the less significant the % will be.

#comment[i feel we could say something else here but idk what to say that is not a list of the parameters and percentages]

#figure(
  image("../images/calibration/pair_family_bars.png", width: 100%),
  caption: flex-caption(
    [Most common duration--gap family pairs.],
    [Share of users (in %) for the 24 largest (duration, gap) family combinations in descending order. The eight smallest combinations ---17 users $< 0.01$%--- are omitted.],
  )
) <fig-pair-family-bars>

The pairwise session-gap analysis proves that we cannot just use @tbl-cal-dist-family separately, but pairwise: the session must define the gap and viceversa. To recapitulate, from the original 1.37M users, 243K are active users (18%) which follow the distributions that we described in this section, and 1.13M are disconnected/not interacting in the whole dataset.

== Sampling from Active Users
<sec-cal-acrossuser>

#todo[rough sketch --- refine this section]

Having selected a winning distribution per user, the natural next step would be to fit the distribution of the per-user parameters across the population ---a "meta-distribution"--- and sample new users from it inside the simulation. This is not done. The reason is visible by grabbing one (duration, gap) pair at a time and plotting the fitted parameters of its users, as @fig-cal-pair-param-hists does for the six most populated pairs: the across-user parameter series are multimodal, degenerate and in general not describable by any standard family ---fitting them would hide exactly the structure that matters.

1. *Too few observations in some families*: after the $n_"obs" >= 30$ filter, several across-user parameter series are too small to fit at all ---the gap exponential has 5 users and the gap gamma 109 (see the family counts of @tbl-cal-dist-family)--- and their meta-fit would describe noise. #todo[recompute these counts with the rerun]
2. *Multimodality*: several parameter series are clearly multimodal. The power-law $xi$ in particular mixes a bounded subpopulation ($xi < 0$), a heavy one ($xi > 0$) and a very heavy one, so no standard family ---normal, gamma, lognormal, Weibull--- can describe it, and a parametric overlay would hide exactly the structure that matters.
3. *Layered model risk*: every meta-layer stacks new model-selection error on top of the previous fit, and the cutoff sensitivity of @tbl-composition-cutoff shows how unreliable model selection is on limited data. The per-user fits are already a model; fitting them again adds risk without adding fidelity.

The simulation therefore samples the across-user parameters empirically: a simulated user is drawn from the fitted per-user table (family and parameters jointly, so only combinations that actually occur together), and its session durations and gaps are generated with the coded families ---exponential, Pareto, Weibull, gamma and lognormal; the few Fisk users (1.5% of durations, 5.1% of gaps) are mapped to lognormal. This bootstrap-style resampling reproduces the exact across-user heterogeneity of the fitted population without any meta-model.

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    row-gutter: 0.6em,
    figure(image("../images/calibration/pair_param_expon__weibull_min.png"), caption: [expon $->$ weibull]),
    figure(image("../images/calibration/pair_param_weibull_min__weibull_min.png"), caption: [weibull $->$ weibull]),
    figure(image("../images/calibration/pair_param_weibull_min__lognorm.png"), caption: [weibull $->$ lognorm]),
    figure(image("../images/calibration/pair_param_gamma__weibull_min.png"), caption: [gamma $->$ weibull]),
    figure(image("../images/calibration/pair_param_lognorm__weibull_min.png"), caption: [lognorm $->$ weibull]),
    figure(image("../images/calibration/pair_param_expon__lognorm.png"), caption: [expon $->$ lognorm]),
  ),
  caption: flex-caption(
    [Per-pair histograms of the fitted parameters.],
    [For each of the six most populated (duration, gap) distribution pairs, histograms of the fitted parameters of the users in that pair, computed over the $N = 243{,}217$ active users. The across-user parameter series show bimodality and degenerate spreads that no standard family describes.],
  )
) <fig-cal-pair-param-hists>

== Inter-Post Creation Times
<sec-cal-interpost>

The next parameter to calibrate is how many posts does a single user produce, the `post_inter_creation` parameter. This was measured from `data.engaged_events` with just normal creations and replies, using session boundaries from `data.sessions_engagement`.

The data was analyzed in two ways: global (gap to the immediately preceding post by the same user, regardless of sessions) and within-session (gap within the same `sessions_engagement` session). For each user with $>= 10$ positive gaps, five distributions were fit via MLE on a 50,000-user sample.

#todo[REDO]

#comment[table!]

== Inter-Action Time
<sec-cal-interaction>

#comment[the idea is correct, but i have not revised this part. I don't think it does a good job explaining this]

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

The `user_inter_action` config expects an exponential with mean. A value of 3 s is recommended. Given that this parameter is an educated assumption rather than a direct measurement, sensitivity analysis should vary it across the 1–10 s range to assess its impact on diffusion outcomes.

== Engagement Rate
<sec-cal-policy>

#comment[the idea is correct, but i have not revised this part. I don't think it does a good job explaining this]

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

== Warm-up time

Explain the warmup experiment, detriments and pros and why we need just 2 ticks of warmup to get the simulation started!

#todo[FINISH THIS]

== Final Calibraiion
<sec-calibration-summary>

The simulation engine (`config.zig`) expects specific distribution types for each calibrated quantity. This section maps every empirical finding to its exact Zig type and initialization.

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

