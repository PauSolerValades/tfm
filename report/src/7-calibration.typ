#import "@preview/lovelace:0.3.0": *
#import "utils.typ": todo, comment, def, procedure, flex-caption

#todo[reread and rewrite header]
This chapter continues @sec-data findings into the definitions of the parameter values required by the simulation configuration. The rationale behind the following parameters is explained: `session_duration`, `user_inter_session` (in @sec-cal-sessions and @sec-cal-dist), `post_inter_creation` (@sec-cal-interpost), `user_inter_action` (@sec-cal-interaction), `user_policy` (@sec-cal-policy), and the `propagation_delay` as reference metric to remove the time units in the analysis results. 

== User Session Construction
<sec-cal-sessions>

The whole simulation design rests on the user defined behaviour of a "session", which has to be constructed from the Bluesky Firehose events descibed in @sec-data. Despite a mathematical modelization defined on @sec-model-sessions as an element of $cal(O)(u)$, this section will provide a more intuitive definition, as well as success crteria on what a good session is.

#def(name: "Session")[
  A session is an interval of time in which the user is connected and using the social network platform.
]

Despite being interested in a more restrictive definition, such as "the interval of time in which the user is _actively and meaningfully_ engaging with _content_", this definition of session is impossible to obtain with the data from the Firehose, despite the current one being more than enough for the puroposes of this work. More about this in @apx-sessions-def.
 
The primary intuition behind this definition is that sessions are formed by an aggregation of events, and a session must end when those events become too far apart timewise. The definition also specifies that events must be meaningful, opening the door to filtering out minor background telemetry in favor of high-engagement actions, such as reposts, creations, or replies.

The upper definiton of session is the one that veryfies the following postulates:
- *Existance of short-sessions*: it is very well known that users do notification checking, or check the social network in lots of microdoses (bathroom breaks, boredom while waiting on a queue), therefore the method must be able to produce singelton sessions (one element), and very short ones that are near: that is, it must be very fine grained.
- *Non existance of macrosessions*: it is not expected to be a lot of very long sessions, as stated in the previous point: several 8 to 10 hour sessions can exist but not be a majority.
- *Akind to known distributions*: the results must produce univariate distributions (at most clearly bivariate) as this serves as the input of a DES simulation.
- *Circadianty*: the macropatterns of day night for non-globally spoken languages in the dataset must be coherent with its timezone (such as german, japanese or other labelled languages.)

Now the key question is: given two consecutive actions by the same user, how long can the pause between them be before we consider the user to have logged off?

=== Session Creation

The method picked to create the session is DBSCAN (@sec-method-session) with parameters `ms=2` and $epsilon=300$. See @apx-session-dbscanparams for details regarding candidates and why this method and these parameters are the correct choice for this problem.

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


== Session Duration & Inter-Session Time
<sec-cal-dist>

With the sessions created, it is possible to fit distributions of `session_length` and `inter_session_lenght` per every user of the dataset. As a reminder
- `session_length`: sampling the distribution should tell us how long will the user current session last. The goodness-of-fit test will be applied to the duration of all the user session length.
- `inter_session_duration`: sampling the distribution should give for how long the user is going to be offline. The goodness-of-fit test will be applied to all the duration between the ending of a session and the start of the next consecutive one ---what has been called "gap" due to being in between sessions---. It is worth mentcioning that the DBSCAN method will produce a gaps distribution shifted by $epsilon=300$, as there cannot be gap smaller than $epsilon$; the histograms showcased are all already shifted that quantity $Y = X - 300$. 

As this is inherently human behaviour ---as Barabási @barabási2005bursts states--- the distribution chosen for the goodness-of-fit test have to have heavy-tails and high peaks, as well as very "similar" forms. The ones chosen are the Exponential, Gamma, Lognormal, Weibull, Frisk (logistic dist), and Power-Law familiy distributions: Pareto, Lomax and Generalized Pareto Distribution.#footnote[Lomax is a reparametrization of the Generalized Pareto, and the Pareto looks to cover the boundary case.]

To select between the best fit, Akaike Information Criterion is used to favor parsimony. For the goodness-of-fit test, as the distributions have heavy tails, we also added Cramér-von Mises and Anderson-Darling statistics as well as the de facto Kolmogorov-Smirnov test, evaluated all agains the ECDF of the session and gaps data. See @apx-method-gof-dist for more information. Additionally, all users with less than 30 sessions or 30 gaps have been excluded from the fitting, which represent roughly 1.13M users (about 82% of the users with fits on both quantities, $1.37 times 10^6$ reduced to $2.43 times 10^5$).

@tbl-cal-dist-family reports, for every family, the number and percentage of users for which it was the AIC winner, for both quantities separately.

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

=== Sampling from Active Users
<sec-cal-acrossuser>


To sample from the active users poses a challenge in order to generalize. When picking a pair from @tbl-cal-pair-dist a parameter must be picked too. In @anx-session-pairhist we can see all the histograms of the parameters, and in this section we will highlight some of those to highlight why a fitting distribution approach is needed to sample from the pairs appropiately.

+ *Power-law bimodality*: all power laws show a lot of bimodality (such as in @fig-hist-power-power) which is very difficult to fit.
+ *Small sample*: for some of the pairs, sample should be bigger to trust more on what it is actually showing this.
+ *Parsimony Priniple*: This can come as a more of a design decision, but there should be a preference for parsimony: sampling from the ECDF of a small distribution in which the parameters are already result of a process of fitting is less complex than to fit the parameters into another distribution.

The simulation therefore samples the across-user parameters empirically: a simulated user is drawn from the fitted per-user table (family and parameters jointly, so only combinations that actually occur together), and its session durations and gaps are generated with the coded families ---Exponential, Pareto, Weibull, Gamma and Lognormal; the few Fisk users (1.5% of durations, 5.1% of gaps) are mapped to lognormal to reduce the burden of new distributions from scratch that this work needs. This bootstrap-style resampling reproduces the exact across-user heterogeneity of the fitted population without any meta-model.

Being able to define a session allows the next key unkown parameters to be directly calibrated from real data or right or to provide a good estimation for them.


== Inter-Post Creation Times
<sec-cal-interpost>

The next quantity to calibrate needs of the session construct to exist. `inter_post_creation` is the time between two posts creations by the same user. The procedure to obtain it resembles the one used for `session_duration` and `inter_session_time` (see @sec-cal-dist), but with widly different results.

All the post creation timestamp have been clustered into sessions. Therefore, we are measuring the gap between the any two posts creations within a session. @fig-cal-create-post-per-session shows all sessions for all users times that a post has been created inside a session. 

#figure(
  image("../images/calibration/interpost_posts_per_session.png", width: 100%),
  caption: flex-caption(
    [Post creations per session.],
    [Share of sessions (%) by number of post creations inside them for all sessions, regardless of parametric fitting.],
  )
) <fig-cal-create-post-per-session>

As it can clearly be seen, there are not many post creation in the created sessions, with a 90.34% of users without any computable gap (users without post creation and just one). This is not a byproduct of the session definition: it is known the post creation is the most sparse of the engaging events, #todo[cite an article that says that] in any microblogging social network.

This sparsity of posts creation when sessionized indicates that a parametric goodness-of-fit is impossible, as verified in @anx-create-gof

#todo[recompute this paragraph]
 The measurement yields $11.1 times 10^6$ within gaps, from which $65,311$ users pass the $n_"obs" >= 30$ filter.

=== Sampling Creation Gaps
<sec-cal-create-dist>

In @fig-cal-create-post-per-session demonstrates that there are not enought data point inside all the sessions to fit them to a parametric goodness-of-fit method to obtain a `inter_post_creation` distribution, and attemps to that can be found in @anx-create-gof. It is therefore resolved that the best approach is to use the Empirical Cumulative Distribution Function from the data.

The ECDF inside the session is the truncated quantity the simulation must reproduce: with $11.1 times 10^6$ observations the ECDF is essentially exact, and no extrapolation beyond the session ceiling is ever needed. The rejection rule comes for free: creates are only dispatched while online (@proc-create), so the staleness gate drops any create scheduled past session end. This is the same principle already used for across-user parameter sampling (see @sec-cal-acrossuser): sample empirical rows rather than fitted marginals.

In @sec-cal-dist we defined 16 familiy pairs of distributions that `session_duration` and `inter_session_time` variables follow. As ECDF is applied to the data, it is worth considering 16 different `inter_post_creation` in accordance to the sessions and the gaps. This is data verifiable, as the histograms of post creations per session and the ECDF do change if we narrow down the pair in which are sampled. As a showcase of this, @fig-cal-pair-hist and @fig-cal-pair-ecdf compare the gamma $times$ lognormal pair against the Weibull $times$ lognormal pair.

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    figure(image("../images/annex/interpost_pairs/posts_per_session__gamma__lognorm.png")),
    figure(image("../images/annex/interpost_pairs/posts_per_session__weibull_min__lognorm.png")),
  ),
  caption: flex-caption(
    [Posts per session of pair (Gamma, Lognorm) and (Weibull, Lognorm)],
    [Posts per session histograms for the Gamma $times$ Lognorm (Left) and Weibull $times$ Lognorm (right) pairs.],
  )
) <fig-cal-pair-hist>

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    figure(image("../images/annex/interpost_pairs/interpost_ecdf__gamma__lognorm.png")),
    figure(image("../images/annex/interpost_pairs/interpost_ecdf__weibull_min__lognorm.png")),
  ),
  caption: flex-caption(
    [Within-gap ECDFs of pair (Gamma, Lognorm) and (Weibull, Lognorm)],
    [Pooled within-gap ECDFs for the Gamma $times$ Lognorm and Weibull $times$ Lognorm pairs: the within cadence differs with the pair.],
  )
) <fig-cal-pair-ecdf>


All the pairs ECDF and histograms can be found in @apx-create-pairs.
The simulation draws `inter_post_creation` from `results/within_interpost_ecdf.txt`, a 1M uniform subsample of all within gaps (one gap per line) and constructs the ECDF as explained in @sec-method-rng-categorical

=== Sampling Offset Creation

Taking a deeper look at the data, there is an important pattern in how posts land inside a session: the offset between the session start and each post creation. @fig-cal-offset-hist shows its distribution over the first 60 seconds in 1-second bins, and @tbl-cal-offset-stats reports its statistics.

#figure(
  image("../images/calibration/post_offsets_hist.png", width: 100%),
  caption: flex-caption(
    [Post offsets within sessions.],
    [Share of all session posts (%) by offset from session start, 1-second bins over the first 15 s (331,132 posts from a 20k-user sample).],
  )
) <fig-cal-offset-hist>

#figure(
  table(
    columns: 9,
    align: (left, center, center, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*n posts*], [*min*], [*P25*], [*Median*], [*Mean*], [*P90*], [*P99*], [*< 1s*], [*< 15 s*],
    table.hline(stroke: 0.5pt),
    [331,132], [0 s], [0 s], [114 s], [453 s], [1,227 s], [5,351 s], [30.9%], [34.34%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Statistics of the post offset within sessions.],
    [Offset statistics over all posts inside sessions (20k sampled users)],
  )
) <tbl-cal-offset-stats>

The offset is heavily concentrated at the session start: $30.9%$ of all session posts land within the first 1 second, so plenty of the sessions are started by a post creation. The offset is therefore its own law, not the within-gap distribution, and the first post of a session is sampled from its own empirical offset ECDF rather than from the within-gap. This offset are computed according to the pairs defined in @sec-cal-dist, @fig-offset-pair-expon-weibull-ex shows an ECDF, and all of them can be found in @apx-offset-pairs

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../images/annex/interpost_pairs/offset_ecdf__expon__weibull_min.png"), 
  ),
  caption: flex-caption(
    [Offset ECDF of Exp $times$ Weibull (40K users)],
    [Empirical Cumulative Exponential Funciton of Exp $times$ Weibull (39,334 users) of the offset.]
      ),
) <fig-offset-pair-expon-weibull-ex>


== Inter-Action Time
<sec-cal-interaction>

The `user_inter_action` is ---arguably--- the most crucial parameter in the
simulation. It governs the time between consecutive posts a user sees on their
timeline, i.e. how many posts the user is exposed to during a session.
Paradoxically, it cannot be directly measured from the Firehose (see
@apx-sessions-dataset), as it records actions, not passive views. This section
explains the rationale for the chosen value and the data used to anchor it.

We model the inter-action time as $"Exp"(lambda)$. Two arguments support this
choice.

The first is experiential. A user browsing a timeline almost never reads every
post in full: they skim the grand majority and linger on a few. This pattern
---many short gaps and a long, thin tail of longer ones--- is the hallmark of
an exponential distribution.

The second is structural: if the sequence of posts appearing on a user's
timeline forms a Poisson process, the inter-arrival times are exponentially
distributed and memoryless #todo[reference a Poisson process]. Memorylessness
is reasonable here: the time a user has already spent on the current post
carries no information about how long they will spend on the next one. Each
post is an independent decision point.

What is a plausible value for the mean $1/lambda$, the average dwell time per
post? Viewport-dwell and eye-tracking studies of feed browsing place the
typical dwell per item at roughly 1.5--3 seconds
#todo[cite dwell-time reference]. We therefore adopt $1/lambda = 3$ seconds
per post, i.e. the user scrolls past about 20 posts per minute. The data let
us sanity-check this choice (see @sec-cal-policy), and @fig-pi-sensitivity
shows that our conclusions are robust to the exact value.

In conclusion, the estimation `user_inter_action` $~ "Exp"(1/3)$ is
reasonable both experientially and structurally, as we will see in the next
section.

== User Policy $pi$
<sec-cal-policy>

The user policy is, together with `user_inter_action`
(@sec-cal-interaction), the other crucial quantity we cannot estimate
directly, and for the same reason: we do not know how many posts the user was
exposed to. Unlike the latter, however, $pi$ can be derived once
`user_inter_action` is fixed.

Per simulation design, we assume $pi$ is homogeneous across users, so we drop
the 16 pairs of families found when deducing the sessions (see
@sec-cal-acrossuser) and treat all sessions equally.

The idea is simple. Under `user_inter_action` $~ "Exp"(1/3)$, a session of
duration $t$ seconds exposes the user to $t slash 3$ posts on average. Counting
likes and reposts per session therefore yields the policy probabilities:

$
  pi_"like" = frac(|{"likes"}|, T slash 3), quad
  pi_"repost" = frac(|{"reposts"}|, T slash 3), quad
  pi_"ignore" = 1 - pi_"like" - pi_"repost",
$

where $T$ is the total session time. Zero-duration sessions (isolated events,
40.7% of sessions) are excluded: they contribute no observable exposure and
hold only 6% of all engagements. From the remaining 26.6M sessions
($T approx 6.11 times 10^9$ s, mean duration 229.5 s), we count
148.5M likes (85.9% of engagements) and 24.4M reposts (14.1%), giving:

$
  pi_"ignore" approx 91.5% quad pi_"like" approx 7.3% quad pi_"repost" approx 1.2%
$

For the simulation's JSON `user_policy.categorical.weights` field, this
translates to `[0.915, 0.073, 0.012]` corresponding to
`["ignore", "like", "repost"]`.

Two consistency remarks. First, the data bound the dwell time from above:
$pi_"like" <= 1$ requires $s <= T slash |{"likes"}| approx 41$ s per post,
and any value beyond a few seconds would imply an implausibly high engagement
rate --- the assumed 3 s sits comfortably inside the plausible range. Second,
$pi$ is exactly linear in the assumed dwell time $s$;
@fig-pi-sensitivity plots this dependence on $s in [1, 4]$ s per post: across
the whole plausible range, users ignore around 90% of what they see, so the
qualitative behaviour of the simulation does not hinge on the exact value of
$1 slash lambda$.

#figure(
  image("../images/calibration/pi_sensitivity.png", width: 80%),
  caption: [Sensitivity of the user policy $pi$ to the assumed dwell time
    $s$ (seconds per post). Zero-duration sessions excluded. The dashed line
    marks the chosen value $s = 3$ s per post.],
) <fig-pi-sensitivity>

== Warm-up time

Explain the warmup experiment, detriments and pros and why we need just 2 ticks of warmup to get the simulation started!

#todo[FINISH THIS]


== Steady State of the Simulation
<sec-exec-stationary>

#comment[this is an unrevised section. Should be far shoretr and report the width of the window and the tolerance. the numbers are still from the older simulation (no timeline swap!)]

Before committing to the full batch execution, a single representative run from each dataset scale was analysed to confirm that the simulation reaches a stationary regime within the configured horizon. The DES model involves stochastic session dynamics: users go online and offline according to calibrated Pareto distributions, and the system needs enough time for these rhythms to stabilise into a steady proportion of simultaneously active users. If the simulation were still burning in when the metrics are collected, the results would reflect transient startup behaviour rather than the equilibrium the CTIC model describes.

#todo[FINISH WITH NEW DATA]

== Time Agnostic Results
<sec-exec-agnostic>

#comment[THIS IS A FINAL VERSION!]

To ensure the simulation results remain invariant to absolute wall-clock metrics and easily comparable across alternative contexts, all temporal findings are reported as multiples of the system's fundamental propagation delay ($Delta_p$). By normalizing absolute time ($t$) against this characteristic scale, we derive a dimensionless representation of post lifetimes:

$ tau = frac(t, Delta_p) $

In this model, $Delta_p$ is defined as exactly one discrete simulation tick ($Delta_p = 1$). This magnitude was selected because it represents the most fundamental, ubiquitous operational baseline of the environment, and one of the fundamental quantities defining the continuous cascade independent model. Expressing results in terms of these intrinsic simulation ticks abstracts away specific hardware or network latencies, rendering the performance analysis strictly system-agnostic.


