#import "@preview/lovelace:0.3.0": *
#import "utils.typ": todo, comment, def, procedure, flex-caption

This chapter continues @sec-data findings into the definitions of the parameter values required by the simulation configuration. The rationale behind the following parameters is explained: `session_duration`, `user_inter_session` (in @sec-cal-sessions and @sec-cal-dist), `post_inter_creation` (@sec-cal-interpost), `user_inter_action` (@sec-cal-interaction), `user_policy` (@sec-cal-policy), and the `propagation_delay` as reference metric to remove the time units in the analysis results. 

== Session Obtention
<sec-cal-sessions>

The whole simulation design rests on the user defined behaviour of a "session", which has to be constructed from the Bluesky Firehose events descibed in @sec-data. Despite a mathematical modelization defined on @sec-model-sessions as an element of $cal(O)(u)$, this section will provide a more intuitive definition, as well as success crteria on what a good session is.

#def(name: "Session")[
  A session is an interval of time in which the user is connected and using the social network platform.  
]

Despite being interested in a more restrictive definition, such as "the interval of time in which the user is _actively and meaningfully_ engaging with _content_", this definition of session is impossible to obtain with the data from the Firehose, despite the current one being more than enough for the puroposes of this work. More about this in @apx-sessions-def.
 
The primary intuition behind this definition is that sessions are formed by an aggregation of events, and a session must end when those events become too far apart timewise. The definition also specifies that events must be meaningful, opening the door to filtering out minor background telemetry in favor of high-engagement actions, such as reposts, creations, or replies.

The upper definiton of session is the one that veryfies the following postulates:
- Existance of microsessions: it is very well known that users do notification checking, or check the social network in lots of microdoses (bathroom breaks, boredom while waiting on a queue), therefore the method must be able to produce singelton sessions (one element), and very short ones that are near: that is, it must be very fine grained.
- Non existance of macrosessions: it is not expected to be a lot of very long sessions, as stated in the previous point: several 8 to 10 hour sessions can exist but not be a majority.
- Akind to known distributions: the results must produce univariate distributions (at most clearly bivariate) as this serves as the input of a DES simulation.
- Circadianty: the macropatterns of day night for non-globally spoken languages in the dataset must be coherent with its timezone (such as german, japanese or other labelled languages.)

Now the key question is: given two consecutive actions by the same user, how long can the pause between them be before we consider the user to have logged off?

== Methodology

Very informal, this is not even resembling a final draft, but I will talk about the reasoning.


According to the literature, defining a meaningful session is far closer to an art than to a science. There are three main methods:
- global threshold: not user dependent, everybody has the same with an elbow method. I did this with replicating a paper back in april, and after rereading the paper it literally contradicts one of the sources lol. I will not even mentcion this.
- Outlier detection with Tukey: it can generate "real" sessions, but it also generates weird outliers, and it's no good at not forming clusters when it does not have to. This was the chosen way (with a lot of extras as a max and a threshold) to produce super good looking sessions. Maybe far to artificaial
- HDBSCAN: very promising, as with the proper tweaking of the hyperparameters can cofnidently give you non clusters of single events. I was looking into that, and this is the method we'll go for.

The reason for HDBSCAN is non other than its the most refined one, probably tukey is good enough. i have to actually do the comparision analysis, which involves defining "what is a good session" to tweak the methods into detecting good sessions.

#todo[FINISH]

== Session Distribution Fitting
<sec-cal-dist>

With sessions defined, the statistical distributions governing session durations and inter-session gaps were characterised via per-user MLE fitting. The analysis was performed by the R script `sessions/analysis/fit_distributions.R`, which reads a `csv` with session data exported from StarRocks via `sessions/analysis/export_sessions.py`.

#todo[some unsupervided AI generated code was not using the proper power-law library, and a LOT of the power-law distribution will probably be lognomral distributions :(]

#todo[redo]

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

== Consolidated Calibration
<sec-calibration-summary>

The simulation engine (`config.zig`) expects specific distribution types for each calibrated quantity. This section maps every empirical finding to its exact Zig type and initialization.


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

