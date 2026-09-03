#import "@preview/lovelace:0.3.0": *
#import "utils.typ": todo, comment, def, procedure, flex-caption

This chapter describes how the parameters required by simulation design ---introduced either in @sec-model (Model) or @sec-design (Design)--- have been measured from the Firehose Data introduced in @sec-data (Bluesky Data Analysis). First, an actuable definition of a session is introduced and those are created from all the events in @sec-cal-sessions. Then it is possible to measure the following parameters: `session_duration` and `inter_session_time` in @sec-cal-dist, times between post creation (`inter_creation_time`) in @sec-cal-interpost, how often does a user see a post while scrolling (`inter_action_time`) in @sec-cal-interaction, and the $pi$ policy described in @sec-model-def-policy in @sec-cal-policy. Lastly, we measure the simulation phases change timestamps introduced in @sec-design-lifecycle (Simulation Phases): minium warmup time $t_w$ in @sec-cal-warmup and minimum horizon $t_h$ in @sec-exec-stationary, as well as estabishing an adimentional framework to analyze the results @sec-exec-agnostic. 


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
    [Distribution of the session-start hour for German, Korean and Japanese users. X-axis: 24h, Y-axis: density. The evening peaks follow each language's main timezone.],
  )
) <fig-cal-circadian>


== Session Duration & Inter-Session Time
<sec-cal-dist>

With the sessions created, it is possible to fit distributions of `session_length` and `inter_session_lenght` per every user of the dataset. As a reminder
- `session_length`: sampling the distribution should tell us how long will the user current session last. The goodness-of-fit test will be applied to the duration of all the user session length.
- `inter_session_duration`: sampling the distribution should give for how long the user is going to be offline. The goodness-of-fit test will be applied to all the duration between the ending of a session and the start of the next consecutive one ---what has been called "gap" due to being in between sessions---. It is worth mentcioning that the DBSCAN method will produce a gaps distribution shifted by $epsilon=300$, as there cannot be gap smaller than $epsilon$; the histograms showcased are all already shifted that quantity $Y = X - 300$. 

As this is inherently human behaviour ---as Barabási @barabási2005bursts states--- the distribution chosen for the goodness-of-fit test have to have heavy-tails and high peaks, as well as very "similar" forms. The ones chosen are the Exponential, Gamma, Lognormal, Weibull, and Pareto familiy distributions: Pareto, Lomax and Generalized Pareto Distribution.#footnote[Lomax is a reparametrization of the Generalized Pareto, and the Pareto (Type I, threshold fixed at the observed minimum) covers the boundary case of a lower bound away from zero; see @apx-session-pareto.]

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
        [Exp], [67,933], [27.93%],
        [Weibull], [59,133], [24.31%],
        [Gamma], [44,029], [18.10%],
        [Lognorm], [36,101], [14.84%],
        [Pareto], [36,021], [14.81%],
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
        [Weibull], [119,526], [49.14%],
        [Lognorm], [77,198], [31.74%],
        [Pareto], [46,444], [19.10%],
        [Gamma], [46], [0.02%],
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

Session durations are spread across the exponential (27.9%), Weibull (24.3%), gamma (18.1%), lognormal (14.8%) and Pareto (14.8%) families, which together account for all active users.

Gaps remain more concentrated than durations: the Weibull (49.1%), lognormal (31.7%) and Pareto (19.1%) families account for roughly 99.9% of users, with negligible gamma and exponential. The gap behaviour is therefore well captured by the majority families.

Now we must study how the session-gap pair is distributed across users, as there might be a relationship between the session and the gap distributions. @tbl-cal-pair-dist shows the distribution of pairs over the same active users. In fact, adding the rows gives the same as @tbl-cal-dist-family left, and the colums of the right one.

#figure(
  table(
    columns: 7,
    align: (left, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [], table.vline(stroke: 0.5pt), [*Weibull*], [*Lognorm*], [*Pareto*], [*Gamma*], [*Exp*], [*Total*],
    table.hline(stroke: 0.5pt),
    [*Exp*], [16.3%], [8.1%], [3.6%], [0], [0], [*27.9%*],
    [*Weibull*], [10.0%], [8.7%], [5.6%], [0], [0], [*24.3%*],
    [*Gamma*], [8.3%], [6.1%], [3.7%], [0], [0], [*18.1%*],
    [*Lognorm*], [7.1%], [4.4%], [3.4%], [0], [0], [*14.8%*],
    [*Pareto*], [7.5%], [4.5%], [2.8%], [0], [0], [*14.8%*],
    [*Gap total*], [*49.1%*], [*31.7%*], [*19.1%*], [*0*], [*0*], [*100%*],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Per-user best-fit family: session duration vs inter-session gap.],
    [Rows are session-duration families and columns are inter-session gap families; each cell gives the share of users with that combination, and the margins give the per-family totals.],
  )
) <tbl-cal-pair-dist>

The same distribution is visualised in @fig-pair-family-bars, where all 22 observed combinations are shown in descending order.

As it can be seen both in @tbl-cal-pair-dist and in @fig-pair-family-bars, the pairwise distributions are far less dominant and more spread across, specially taking into account the more dominant distributions. As the table axis are sorted by decreasing amount of users as the original tables, the further from the beginning of (Exp, Weibull) the less significant the % will be.

#comment[i feel we could say something else here but idk what to say that is not a list of the parameters and percentages]

#figure(
  image("../images/calibration/pair_family_bars.png", width: 100%),
  caption: flex-caption(
    [Most common duration--gap family pairs.],
    [Share of users (in %) for all 22 observed (duration, gap) family combinations in descending order. The seven smallest combinations together account for 49 users ($< 0.02$%).],
  )
) <fig-pair-family-bars>

The pairwise session-gap analysis proves that we cannot just use @tbl-cal-dist-family separately, but pairwise: the session must define the gap and viceversa. To recapitulate, from the original 1.37M users, 243K are active users (18%) which follow the distributions that we described in this section, and 1.13M are disconnected/not interacting in the whole dataset.

=== Sampling from Active Users
<sec-cal-acrossuser>


To sample from the active users poses a challenge in order to generalize. When picking a pair from @tbl-cal-pair-dist a parameter must be picked too. In @anx-session-pairhist we can see all the histograms of the parameters, and in this section we will highlight some of those to highlight why a fitting distribution approach is needed to sample from the pairs appropiately.

+ *Pareto bimodality*: all Pareto distributions show a lot of bimodality (such as in @fig-hist-power-power) which is very difficult to fit.
+ *Small sample*: for some of the pairs, sample should be bigger to trust more on what it is actually showing this.
+ *Parsimony Priniple*: This can come as a more of a design decision, but there should be a preference for parsimony: sampling from the ECDF of a small distribution in which the parameters are already result of a process of fitting is less complex than to fit the parameters into another distribution.

The simulation therefore samples the across-user parameters empirically: a simulated user is drawn from the fitted per-user table (family and parameters jointly, so only combinations that actually occur together), and its session durations and gaps are generated with the coded families ---Exponential, Pareto, Weibull, Gamma and Lognormal---. This bootstrap-style resampling reproduces the exact across-user heterogeneity of the fitted population without any meta-model.

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

As it can clearly be seen, there are not many post creation in the created sessions, with a 90.34% of users without any computable gap (users without post creation and just one). This is not a byproduct of the session definition: it is known the post creation is the most sparse of the engaging events @kooti2016twitter in any microblogging social network.

This sparsity of posts creation when sessionized indicates that a parametric goodness-of-fit is impossible, as verified in @anx-create-gof .

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
distributed and memoryless @ross2014probability. Memorylessness
is reasonable here: the time a user has already spent on the current post
carries no information about how long they will spend on the next one. Each
post is an independent decision point.

What is a plausible value for the mean $1/lambda$? #todo[say nicely i just made this up] We therefore adopt $1/lambda = 3$ seconds per post, i.e. the user scrolls past about 20 posts per minute. The data let us sanity-check this choice (see @sec-cal-policy), and @fig-pi-sensitivity shows that our conclusions are robust to the exact value.

In conclusion, the estimation `user_inter_action` $~ "Exp"(1/3)$ is reasonable both experientially and structurally, as will be seen in the next section.

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
<sec-cal-warmup>

The warm-up phase (the stageOne @proc-stageone in @sec-design-lifecycle-warmup) exists to fill every timeline before the measurement phase begins. At $t = 0$ all timelines are empty: if measurement started immediately, the first user to log in would find nothing to read, drain the empty feed, and leave out of boredom (@sec-design-sources-sessions), so every downstream metric ---impressions, engagement, session length, cascade size--- would be measured on an empty system.

This section describes the experiment to find the smaller $t_w$ such that a user's first session has a normal amount of post to check according to it's positioning within the topology. There are two key metrics to measure it:
+ *Backlog*: how many posts does the user start the session.
+ *Boredom*: how many users end the first session by boredom.

@tbl-cal-warmup-sweep reports both for $t_w in {0, 100, 500, 1000, 2000, 5000, 10000}$ ticks on the 10K and 100K networks, as this experiment is time-consuming to run.

#figure(
  table(
    columns: 5,
    align: (right, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*$t_w$ (ticks)*], [*Backlog 10K*], [*Backlog 100K*], [*Bore 10K (%)*], [*Bore 100K (%)*],
    table.hline(stroke: 0.5pt),
    [0], [19], [77], [46.9], [34.7],
    [100], [26], [98], [32.7], [21.7],
    [500], [28], [99], [24.9], [15.4],
    [1000], [27], [105], [20.8], [12.0],
    [2000], [32], [107], [15.7], [8.8],
    [5000], [32], [113], [9.4], [5.7],
    [10000], [31], [114], [6.7], [4.2],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Warm-up sweep: first-session backlog and boredom rate.],
    [Median backlog at first-session start and share of first sessions ending in boredom, per warm-up length, on the 10K and 100K networks with `offline_startup_ratio = 0.976`.],
  )
) <tbl-cal-warmup-sweep>

#figure(
  image("../images/calibration/warmup_100K_boredom_timeline.png", width: 100%),
  caption: flex-caption(
    [Boredom over time on the 100K network.],
    [Cumulative percentage of users ending a session in boredom over ticks after warm-up, one line per warm-up length.],
  )
) <fig-cal-warmup-100k-boredom>

#figure(
  image("../images/calibration/warmup_100K_attention_decay.png", width: 100%),
  caption: flex-caption(
    [Warm-up post attention decay on the 100K network.],
    [Share of actions on warm-up posts over time, one line per warm-up length.],
  )
) <fig-cal-warmup-100k-attention>


The two figures make the trade-off visible. At $t_w = 0$ no posts are produced during warm-up, so the first session starts from an empty timeline: @fig-cal-warmup-100k-attention has nothing to plot for it, and @fig-cal-warmup-100k-boredom shows the steepest boredom growth right after warm-up, reaching the highest first-session boredom rate of the sweep (46.9% at 10K, 34.7% at 100K in @tbl-cal-warmup-sweep).

At the opposite extreme, $t_w = 10,000$ yields the flattest boredom curve and the lowest first-session boredom rate (6.7% at 10K, 4.2% at 100K) ---a residual that never vanishes, being the natural boredom floor of tiny and singleton sessions. But @fig-cal-warmup-100k-attention shows warm-up posts still being consumed deep into the measurement phase: the backlog is over-saturated, so most of that extra content is never read and is discarded from the analysis. The backlog column of @tbl-cal-warmup-sweep confirms the saturation ---it stops growing past $t_w = 2000$ (32 posts at 10K, 107 at 100K)--- so beyond that point extra warm-up only adds memory, not value.

In between, the dominant gain is already won by $t_w = 500$, where the boredom rate roughly halves. Therefore the elected value is $t_w = 2000$ ticks: the knee of the curve, where the backlog has just saturated and the first-session boredom rate (15.7% at 10K, 8.8% at 100K) has crossed below steady state and keeps falling slowly. It is a $approx 15$× reduction from the previous 30,000-tick assumption, and it dissolves the memory problem ---warm-up memory is proportional to $t_w$, so a 1M run needs $approx 72$ GB instead of $approx 2$ TB.


== Stability Regiment
<sec-exec-stationary>

With the warm-up length fixed, the remaining temporal parameter is the horizon $t_h$: how long the measurement phase must run for the system to be in steady state. The steady state of the simulation is to check which amount of users of the simulation converges being online starting from an arbitrary fraction and after how long does the simulation need for it to happen?

The measured quantity is the share of online users over time, under three initial conditions set by `offline_startup_ratio`: 0.0 (everyone online at warm-up end), 0.5 (half) and 1.0 (everyone offline). If the three curves collapse onto the same plateau, the system will enter in equilibrium ---the session distributions--- and not of the initial state, which is exactly what a steady-state claim requires. Proving that starting from three different points converges to the same amount of users also proves that the starting value of `offline_startup_ratio` is independent, therefore an arbitrary value makes sense.

*Methodology*: networks of 10K, 100K, 500K and 1M users topologies, warm-up of 2,000 ticks (see @sec-cal-warmup), duration of 60,000 ticks (to make sure that convergence is reached) with 3 replications per (size, ratio); results will be the median (the central one) over the runs.

Window configuration wise, the online fraction of users is binned over 60s bins and smoothed with a 300 s rolling mean; stability is the earliest time after which the rolling mean stays within $plus.minus 10%$ of its final value for the rest of the run.


@fig-cal-stable-convergence shows the three initial-condition curves on the 1M network, @tbl-cal-stable-equil reports the equilibrium online fraction and @tbl-cal-stable-time the stabilization time, and the plots for all the other datasets can be found in @apx-stability-plots.

#figure(
  image("../images/calibration/initial_conditions_1M_log.png", width: 80%),
  caption: flex-caption(
    [Convergence of the online fraction on the 1M network.],
    [Online-user fraction over time for the three initial conditions ($r_0$, $r_50$, $r_100$) after a 2,000-tick warm-up, on the 1M monotonic network (logarithmic scale). The three curves collapse onto the same equilibrium.],
  )
) <fig-cal-stable-convergence>

#grid(
  columns: 2,
  column-gutter: 1em,
  [
    #figure(
      table(
        columns: 4,
        align: (left, center, center, center),
        stroke: none,
        table.hline(stroke: 0.8pt),
        [*Size*], [*0%*], [*50%*], [*100%*],
        table.hline(stroke: 0.5pt),
        [10K], [1.90 %], [1.85 %], [1.71 %],
        [100K], [2.20 %], [2.24 %], [2.21 %],
        [500K], [2.40 %], [2.37 %], [2.39 %],
        [1M], [2.09 %], [2.08 %], [2.10 %],
        table.hline(stroke: 0.8pt),
      ),
      caption: flex-caption(
        [Equilibrium online fraction per size and initial condition.],
        [Final online-user fraction (%, median over 3 runs) for the three initial conditions, after warm-up 2,000 ticks and 60,000 ticks of duration.],
      ),
    ) <tbl-cal-stable-equil>
  ],
  [
    #figure(
      table(
        columns: 4,
        align: (left, right, right, right),
        stroke: none,
        table.hline(stroke: 0.8pt),
        [*Size*], [*users*], [*%*], [*Stable at*],
        table.hline(stroke: 0.5pt),
        [10K\*], [$approx$185], [1.85], [$approx$58K s],
        [100K], [$approx$2,210], [2.21], [30--32K s],
        [500K], [$approx$11,950], [2.39], [26--29K s],
        [1M], [$approx$20,900], [2.09], [28--31K s],
        table.hline(stroke: 0.8pt),
      ),
      caption: flex-caption(
        [Stabilization time and equilibrium of the online fraction.],
        [Earliest time after warm-up at which the rolling mean of the online stabilized and the population it converges to],
      ),
    ) <tbl-cal-stable-time>
  ],
)

\*10K: the $approx$58K s is noise-limited, not a slower equilibrium ---at $approx$180 online users the Poisson noise ($plus.minus 7%$) is comparable to the $plus.minus 10%$ detection band, so the equilibrium is reached early but cannot be pinned tighter at this size.

We can obtain three meaningfull findings, in all of them 10K is excluded:
+ *Initial-condition independence holds*: @tbl-cal-stable-equil shows the numbers, distergarding the number of users online, converge to the same number within $0.2$ pp.
+ *Equilibrium is topology dependent*: different topologies reach different equilibriums. It is not also scaling with size, as 1M (2.1%) is lower than 500K (2.4%), but depends on the network topology.
+ *Convergence time*: convergence happens around 30.000 ticks in all three big topologies, despite all of the topologies wobbling a little in that regard.

== Time Agnostic Results
<sec-exec-agnostic>


To ensure the simulation results remain invariant to absolute wall-clock metrics and easily comparable across alternative contexts, all temporal findings are reported as multiples of the system's fundamental propagation delay ($Delta_p$). By normalizing absolute time ($t$) against this characteristic scale, we derive a dimensionless representation of all metrics:

$ tau = frac(t, Delta_p) $

In this model, $Delta_p$ is defined as exactly one discrete simulation tick ($Delta_p = 1$). This magnitude was selected because it represents the most fundamental, ubiquitous operational baseline of the environment, and one of the fundamental quantities defining the continuous cascade independent model. Expressing results in terms of these intrinsic simulation ticks abstracts away specific hardware or network latencies, rendering the performance analysis strictly system-agnostic.


