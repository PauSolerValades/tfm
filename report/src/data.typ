#import "utils.typ": todo, comment

This section covers the analysis of the Bluesky Firehose dataset in order to find the rellevant statistical quantites for the calibration of the simulation.

== Technology Stack

#comment[What did we actually use as software, please finish]
- StartRocksDB: a statistical database that stores by columsn instead of rows.
- Python 3.13: main tool for data analytics. rellevant packages apart from numpy and polars are powerlaw and scipy
- R 4.5.3: Used for per-user distribution fitting and inter-post gap analysis. The R scripts depend on `poweRlaw` (Clauset et al. power-law MLE), `fitdistrplus` (MLE for exponential, log-normal, Weibull, gamma), `data.table` (fast CSV ingestion), `tidyverse` (data wrangling and plotting), `broom` (tidying model outputs), and `parallel` (multi-core per-user fitting).

== Firehose Data
<sec-data-firehose>

The Bluesky firehose is a continuous stream of all public AT Protocol events emitted by the network. For this study, a 6-day snapshot (April 11--17, 2026) was ingested into a StarRocks columnar database. The raw data is organised into two tables in the `bsky` schema.

The table `bsky.posts` contains $approx 28.1 times 10^6$ post records, normalised with columns `did`, `rkey`, `time_us`, `created_at`, `post_text`, `lang`, and reply-chain fields (`reply_root_uri`, `reply_parent_uri`). Top-level posts are those with `reply_root_uri IS NULL` ($15.3 times 10^6$, 54.4%).

The table `bsky.records`: $approx 212.5 times 10^6$ raw firehose events covering all AT Protocol lexicon collections. The three dominant record types are likes (`app.bsky.feed.like`, $161.7 times 10^6$, 76.1%), reposts (`app.bsky.feed.repost`, $26.4 times 10^6$, 12.4%), and follows (`app.bsky.graph.follow`, $18.8 times 10^6$, 8.8%). Remaining types include blocks, profile updates, lists, and moderation records.

The `bsky.records` table additionally captures follows ($18.8 times 10^6$), blocks ($1.7 times 10^6$), profile updates, thread reply controls, list memberships, and other moderation records, for a total of 16 lexicon collections. The `records` schema includes `subject_uri`, `subject_did`, and a full `record_json` payload enabling reconstruction of the target of every like, repost, follow, and block. A pre-aggregated per-user summary table `pau_db.users` ($3.09 times 10^6$ DIDs) stores `num_posts`, `num_likes`, `num_reposts`, `num_follows`, `first_seen_us`, `last_seen_us`, and `primary_lang` for each unique user. The full database schema is documented in `docs/database-data-description.md`.

Before applying any session threshold, a systematic EDA was conducted to understand which users drive the gap distribution. The EDA is a structured pipeline of eight sections (each a standalone Python script under `session-analysis/eda/*.py`), orchestrated by `session-analysis/eda.py`. All scripts query the StarRocks database, compute a specific statistic, and produce both plots and summary text files under `session-analysis/eda/results/`.

=== Event-count distribution

The number of core events per user follows a heavy-tailed distribution. @tbl-events-percentiles gives the empirical percentiles.

#figure(
  table(
    columns: 9,
    align: center,
    stroke: none,
    table.hline(stroke: 0.8pt),
    [Percentiles], [1], [10], [25], [50], [75], [90], [95], [99],
    table.hline(stroke: 0.5pt),
    [Event-counts], [1], [1], [2], [5], [18], [61], [124], [424],
    table.hline(stroke: 0.8pt),
  ),
  caption: [
    Event-count percentiles per user, 8-day window. The
    values 1, 10, …, 99 are the percentile ranks; the
    bottom row reports the corresponding event counts.
  ],
) <tbl-events-percentiles>

A power-law fit via MLE with KS-based $x_min$ estimation @clauset2009powerlaw (script `powerlaw_binning.py`) yields $x_min = 5$, $alpha approx 1.68$. Since the heavy tail begins at 6 events, users with $<= 5$ events —-half of the population-— may be considered *tourists* who generate too little activity to produce meaningful inter-arrival statistics. @fig-events-powerlaw shows the complementary CDF with the fitted power-law tail.

#figure(
  image("figures/01_events_per_user.png", width: 100%),
  caption: [Complementary CDF of core events per user (log-log). The straight-line decay in the tail confirms power-law behaviour with $alpha approx 1.68$, $x_min = 5$. ]
) <fig-events-powerlaw>

=== User Archetypes

Based on the ratio of content creation (posts + replies) to passive engagement (likes + reposts), users fall into distinct behavioural classes (script `user_classification.py`). Let $p = (n_"posts" + n_"replies") / (n_"posts" + n_"replies" + n_"likes" + n_"reposts")$ be the authored-content fraction and $r = n_"reposts" / (n_"likes" + n_"reposts")$ the repost-to-engagement ratio. The classification rules are:

- *Tourist:* $ <= 5$ total events — too little data for a meaningful ratio.
- *Creator:* $p >= 0.7$ — at least 70% of activity is authoring original content.
- *Engager:* $p <= 0.3$ and $r < 0.4$ — likes dominate; few reposts.
- *Curator:* $p <= 0.3$ and $r >= 0.4$ — heavy repost-to-like ratio, acting as a content amplifier.
- *Balanced:* $0.3 < p < 0.7$ and $r < 0.4$ — mix of creation and engagement.
- *Balanced-Curator:* $0.3 < p < 0.7$ and $r >= 0.4$ — balanced creation/engagement with a curatorial repost bias.

The naming reflects behavioural intent: a *Creator* primarily authors posts, an *Engager* primarily likes others' content, a *Curator* amplifies via reposts, and *Balanced* users split their effort across actions. @tbl-archetypes gives the empirical counts.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Archetype*], [*Users*], [*\%*], [*Criterion*],
    table.hline(stroke: 0.5pt),
    [Tourist], [$922,044$], [52.7], [$<= 5$ events],
    [Engager], [$418,525$], [23.9], [$p <= 0.3$, $r < 0.4$],
    [Balanced], [$148,994$], [8.5], [$0.3 < p < 0.7$, $r < 0.4$],
    [Creator], [$142,948$], [8.2], [$p >= 0.7$],
    [Curator], [$90,655$], [5.2], [$p <= 0.3$, $r >= 0.4$],
    [Balanced-Curator], [$27,636$], [1.6], [$0.3 < p < 0.7$, $r >= 0.4$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [User archetypes by event-type composition with classification thresholds. $p = ("posts"+"replies")/("posts"+"replies"+"likes"+"reposts")$, $r = "reposts"/("likes"+"reposts")$.]
) <tbl-archetypes>

Creators and engagers form distinct populations, not a continuum: creators produce content in bursts, engagers browse and react more passively. This suggests different session rhythms and motivates per-user adaptive thresholds (see §@sec-data). Figure @fig-archetypes shows the archetype composition across the full user base.

#figure(
  image("figures/02_archetype_distribution.png", width: 80%),
  caption: [Distribution of user archetypes by event-type composition. Tourists (52.7%) dominate the head count but contribute negligible gaps. ]
) <fig-archetypes>

=== Activity Span

A third of users (32.6%) are active on only one day out of the 8-day window; these bingers produce inter-arrival gaps that are really intra-burst activity, not between-session pauses. For session analysis, active_days $>=$ 2 should be required so that inter-session gaps carry meaning (script `activity_span.py`).

=== Coverage Analysis

Table @tbl-coverage bins users by total event count and asks: who supplies the inter-arrival gaps? (script `coverage.py`).

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Events*], [*Users (%)*], [*Events (%)*], [*Gaps (%)*], [*Role*],
    table.hline(stroke: 0.5pt),
    [1],          [22.6],  [0.7],   [0.0],  [Irrelevant],
    [2–5],        [30.1],  [3.0],   [2.1],  [Negligible],
    [6–25],       [27.7],  [11.1],  [10.6], [Meaningful],
    [26–100],     [13.4],  [22.0],  [22.3], [Meaningful],
    [101–500],    [5.5],   [36.3],  [37.4], [Dominant],
    [501+],       [0.8],   [26.8],  [27.7], [Bot-heavy],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Coverage analysis: the 101–500 event bucket (5.5% of users) supplies 37.4% of all inter-arrival gaps — this is the stratum that objectively drives any gap-based analysis.]
) <tbl-coverage>

#figure(
  image("figures/05_coverage.png", width: 85%),
  caption: [Share of inter-arrival gaps contributed by each user stratum. The 101–500 bucket (5.5% of users) dominates with 37.4% of gaps. Generated by `coverage.py`.]
) <fig-coverage>

The bins in @fig-coverage are ordered by ascending event-count, mirroring the table above.

The *Events* column in @tbl-coverage is the total number of core events (posts, replies, reposts) each user generated across the full 8-day firehose window, not events per day. The 101–500 event bucket alone contributes 37.4% of all inter-arrival gaps while representing only 5.5% of users. @fig-coverage visualizes this imbalance: a small dominant stratum produces the majority of the signal, while the tourist majority ($<=5$ events, 52.7% of users) is barely visible. The 501+ bucket adds another 27.7% of gaps, but users in this range generate over 62 events per day on average — a rate suspicious of automated or scheduled accounts. These high-frequency users are excluded from threshold detection because their artificially tight posting intervals would compress the elbow downward. Together, just 6.3% of users drive 65.1% of the gap distribution.

=== Filtering outcome

On the basis of this EDA, the following filtering strategy was adopted and
two derived tables were created in StarRocks:

- *Remove tourists:* `total_events` $>= 6$ (52.7% of users, 2.1% of gaps).
- *Remove bots:* `total_events` $<= 500$ (0.8% of users, 27.7% of gaps).

This produced:

- `user_core_events_dominant` (101--500 events, $N = 95,795$, $19.4 times 10^6$ events). The dominant stratum, the population that objectively drives the elbow. Populated by `create_core_events_dominant.sql` and `insert_core_events_dominant.sql`.
- `user_core_events_human` (6--500 events, $N approx 810,000$, $36 times 10^6$ events). The human range, tourists and bots removed, preserving the diversity of casual, regular, and power-user rhythms. Populated by `create_core_events_human.sql` and `insert_core_events_human.sql`.

The base table `user_core_events` (all 1.75M users, $53.5 times 10^6$ events) was also retained as an unfiltered reference. It was created by `create_core_events_table.sql` and `insert_core_events.sql`.

== Topology Obtention

The simulation has been executed until now over a synthetic social network data set for testing purposes (see @sec-impl-topology). The first objective is to extract a subset of the Bluesky graph first.

// #todo[Talk about../../bsky-data-analysis/topology-time-reconstruction/ and all the data]

== Session Analysis

The most important simulation quantities are session duration, time between session, time between actions, time between post creation and the Categorical distribution of the $pi$ policy ---the probability that a user likes, reposts or ignores a piece of content. 

The objective of this section is to explain the means used to obtain all of the quantities stated in the above paragraph: 
1. Session Lengths (`session_duration` in the configuration)
2. Time between sessions (`inter_session_time` in the configuration)
2. Time between post creations (`inter_session_time` in the configuration)
4. Time between two user actions (`inter_action_time` in the configuration)
5. The $pi$ policy: $p_("ignore"), p_"like", p_"repost"$ (`Categorical` distribution in the configuration)

=== Methodology

This section covers and justifies the methodology that allowed to obtain the threshold of how long a session is from the Firehose dataset (@sec-data-firehose). 

Narrowing down on specifics, what needs to be obtained is a quantity we will call $delta$, which represent the maximum amount of time between events in which the user is considered to still be online. In other words, let's assume the following timestamps of a single user $t_1, t_2, t_3$. If $t_2 - t_1 < delta$ and $t_3 - t_2 < delta$, then the user session will be spand from $[t_1, t_3]$. If instead, $t_3 - t_2 > delta$, the session will spand from $[t_1, t_2]$, and $t_3$ not be in the session, as the distance between it's past event is greater as $delta$.

Two methods were used to obtain sessions data: the Kooti et al. replication @kooti2016twitter (detailed in the appendix) and the Tukey's fences method described below.

=== Tukey Range per User
<sec-data-sessions-tukey>

The fixed threshold of $265$ s (derived in the appendix), while data-driven, applies the same session boundary to all users. Yet the EDA gap analysis (@sec-data-firehose, §4 of the EDA) showed that per-user median inter-arrival gaps span six orders of magnitude, from seconds to days. Only 23.9% of users have a median gap below 5 minutes. A single global threshold will fragment power users into single-event noise while merging multi-day pauses into spurious sessions for casual users.

To address this, we adopt a per-user adaptive threshold based on Tukey's
fences (interquartile range outlier detection). For each user, the gaps $g_i = t_(i+1) - t_i$ are computed between every consecutive action and apply:

$
"threshold"(u) = max(Q_3(u) + k dot "IQR"(u), 120 "s")
$

where $Q_1(u)$ and $Q_3(u)$ are the first and third quartiles of user $u$'s gap distribution, $"IQR"(u) = Q_3(u) - Q_1(u)$, and $k = 1.5$ is the standard Tukey multiplier. Any gap larger than this user-specific threshold is treated as a session boundary. A hard floor of 120 s (2 minutes) prevents fragmenting a single browsing burst, and a global fallback of 60 minutes is applied to users with fewer than 4 inter-event gaps (24% of users) — too few data points for a meaningful quartile estimate.

*Concrete example.* A user whose typical gaps lie in $30$–$90$ s has $"IQR" = 60$ s and receives a threshold of $90 + 1.5 dot 60 = 180$ s (3 min). A user whose gaps span $20$–$120$ s gets $120 + 1.5 dot 100 = 270$ s. In contrast, a once-a-day checker whose gaps are measured in hours falls back to the 60-minute default.

Unlike the fixed-threshold approach (detailed in the appendix), which restricted itself to core events (posts, replies, reposts), the adaptive method ingests *all* visible user actions to build the most complete picture of session activity. The script `session-analysis/session_engagement_analysis.py` queries both `bsky.records` and `bsky.posts` via `UNION ALL`, producing per-user timelines that include likes, reposts, follows, posts, and all other record types (blocks, profile updates, list management, etc.). This is important: a user who only likes posts would have zero core events and be invisible to a core-event-only analysis, yet their likes define real browsing sessions.

The script was run on the same human-range population identified by the EDA (@sec-data-firehose): the 815,271 users in `user_core_events_human` (6--500 core events), excluding both tourists and suspected bots. Users are processed in batches of 2,000 DIDs, each timeline is clustered using Tukey's rule, and results are written directly to `sessions_tukey`. The schema extends `sessions_threshold` with columns for likes, follows, and `user_threshold_s` (the per-user adaptive threshold used).

Applied to the 815,271 human-range users, the adaptive method produced 28.2 million sessions (Table @tbl-tukey-results).

The prevalence of zero medians for reposts, posts authored, and follows reflects the dominance of liking as the primary session action. In most sessions, users exclusively like posts — reposting or authoring content is a rarer, higher-effort action. Over 50% of sessions contain zero reposts and zero posts authored, so the median sits at zero. The mean values ($0.3$–$0.7$) capture the non-zero minority. This asymmetry is expected: liking is the lowest-cost engagement and dominates casual browsing.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*Median*], [*Mean*], [*P₂₅*], [*P₇₅*],
    table.hline(stroke: 0.5pt),
    [Session duration (s)], [100], [8,126], [3], [493],
    [Likes per session], [3], [6.0], [1], [6],
    [Reposts per session], [0], [0.4], [0], [0],
    [Posts authored], [0], [0.3], [0], [0],
    [Interactions (like + repost)], [3], [6.4], [1], [7],
    [Follows per session], [0], [0.7], [0], [0],
    [Other actions], [0], [0.7], [0], [1],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Session-level statistics from `sessions_tukey` ($29.3 times 10^6$ sessions, $2.28 times 10^6$ users).]
) <tbl-tukey-results>

The mean duration (8,126 s) is inflated by a long tail of multi-hour sessions; the median of 100 s is the more reliable central tendency. Likes dominate action types, with a median of 3 per session. 24% of users relied on the 60-minute fallback threshold due to fewer than 4 inter-event gaps.



=== Session Distribution Fitting
<sec-session-dist>

With sessions defined by the adaptive method, the final calibration step is to characterise the statistical distributions governing session durations and inter-session gaps. The analysis is performed by `session-analysis/session_distribution_fit.R`, a parallelised R script using the packages `poweRlaw`, `fitdistrplus`, `data.table`, `tidyverse`, `broom`, and `parallel`. Data flows from StarRocks via CSV export (`session-analysis/export_sessions_csv.py`) into R for per-user fitting.

For each user with $>= 10$ data points (477,659 users from `sessions_tukey`),
we fit five candidate distributions — Pareto (MLE with KS-based $x_min$ estimation @clauset2009powerlaw), exponential, log-normal, Weibull, and gamma — and select the best via Vuong's log-likelihood ratio test (significance $alpha = 0.05$) with AIC as a tie-breaker.

Table @tbl-dist-fit summarizes the results.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Distribution*], [*Session duration*], [*Inter-session gap*],
    table.hline(stroke: 0.5pt),
    [Pareto], [71.0% (338,819 users)], [74.0% (353,384 users)],
    [lognormal], [12.1% (57,872)], [17.3% (82,757)],
    [weibull], [7.1% (34,032)], [7.1% (34,141)],
    [exponential], [3.6% (17,293)], [$<$0.01% (1)],
    [gamma], [0.6% (2,774)], [$<$0.01% (161)],
    [*no fit*], [5.6% (26,869)], [1.5% (7,215)],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Distribution fitting results for 477,659 users with $>= 10$ data points from `sessions_tukey`. Power-law is the overwhelming winner for both session durations (71%) and inter-session gaps (74%).]
) <tbl-dist-fit>

*Power-law dominates.* For both quantities, roughly three-quarters of fittable users follow a power-law. The median exponent is $alpha = 2.68$ for durations and $alpha = 2.43$ for gaps — both in the $2$–$3$ range characteristic of social media behaviour, with gaps slightly fatter-tailed (more extreme outliers). The power-law regime begins at $x_min = 394$ s ($6.6$ min) for durations and $x_min = 12,798$ s ($3.6$ h) for gaps, meaning only the tail beyond these cut-offs is truly power-law-distributed; the body of short sessions and brief gaps follows a different regime. Figure @fig-dur-pareto, @fig-gap-pareto, @fig-dur-lognormal, @fig-gap-lognormal, @fig-dur-weibull, and @fig-weibull-k show the parameter density estimates for the three most relevant distributions individually.

#figure(
  image("figures/powerlaw_duration_params.png", width: 70%),
  caption: [Pareto parameter densities for session durations ($alpha$ left, $x_min$ right). Median $alpha = 2.68$, $x_min = 394$ s ($6.6$ min). Generated by `plot_parameter_densities.py`.]
) <fig-dur-pareto>

#figure(
  image("figures/powerlaw_gap_params.png", width: 70%),
  caption: [Pareto parameter densities for inter-session gaps. Median $alpha = 2.43$, $x_min = 12,798$ s ($3.6$ h). The gap $x_min$ is substantially higher than duration $x_min$, reflecting the longer timescales of inter-session pauses.]
) <fig-gap-pareto>

#figure(
  image("figures/lognormal_duration_params.png", width: 70%),
  caption: [Lognormal parameter densities for session durations ($mu$ left, $sigma$ right). Median $mu = 6.76$, $sigma = 0.69$, corresponding to a central tendency of $approx 14$ min.]
) <fig-dur-lognormal>

#figure(
  image("figures/lognormal_gap_params.png", width: 70%),
  caption: [Lognormal parameter densities for inter-session gaps. Median $mu = 9.60$, $sigma = 0.94$, central tendency $approx 4.1$ h. Greater dispersion than durations.]
) <fig-gap-lognormal>

#figure(
  image("figures/weibull_duration_params.png", width: 70%),
  caption: [Weibull parameter densities for session durations (shape $k$ left, scale $lambda$ right). Median $k = 1.14$ — nearly exponential, indicating roughly constant session termination probability.]
) <fig-dur-weibull>

*Exponential is absent for gaps.* Only 1 user out of 478K has exponential inter-session gaps — definitively ruling out the memoryless hypothesis. Inter-session absences are structured, not random.

*Weibull hazard interpretation.* For gap-following Weibull users, 60% have shape $k > 1$, indicating *increasing hazard* — the longer a user has been away, the more likely they are to return (habitual checking). The remaining 40% have $k < 1$ (decreasing hazard — abandonment/churn). For durations, the Weibull shape is near $k approx 1$, i.e. nearly exponential, indicating a roughly constant probability of session termination. The density of the gap Weibull shape parameter (Figure @fig-weibull-k) confirms this split: the mode lies at $k approx 1.3$, but a substantial left tail extends below $k = 1$.

#figure(
  image("figures/weibull_gap_params.png", width: 70%),
  caption: [Weibull shape parameter $k$ for inter-session gaps.
    $k < 1$ (decreasing hazard — abandonment, 40%) and
    $k > 1$ (increasing hazard — habitual checking, 60%).
    The density peaks near $k approx 1.3$.]
) <fig-weibull-k>

The full per-distribution parameter estimates are given in @tbl-dist-params. The power-law $x_min$ values reveal a two-regime structure: most session durations under $394$ s ($6.6$ min) and most inter-session gaps under $12,798$ s ($3.6$ h) follow a different distribution (the "body"); the power-law only governs the tail beyond these cut-offs. Lognormal users have median parameters $mu = 6.76$, $sigma = 0.69$ for durations and $mu = 9.60$, $sigma = 0.94$ for gaps, corresponding to central tendencies of $approx 14$ min and $approx 4.1$ h respectively. For the 3.6% of exponential-duration users, the rate parameter $lambda^(-1) = 252$ s ($4.2$ min). The negligible exponential presence for gaps (1 user) definitively rules out memoryless inter-session behaviour.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Distribution*], [*Parameter*], [*Median (dur.)*], [*Median (gap)*], [*Interpretation*],
    table.hline(stroke: 0.5pt),
    [Pareto], [$alpha$], [2.68], [2.43], [Exponent in $2$–$3$ range (finite mean, infinite variance)],
    [Pareto], [$x_min$], [394 s (6.6 min)], [12,798 s (3.6 h)], [Tail threshold; body below follows different regime],
    [lognormal], [$mu$ (meanlog)], [6.76], [9.60], [$exp(mu) approx 863$ s dur., $14{,}771$ s gap],
    [lognormal], [$sigma$ (sdlog)], [0.69], [0.94], [Greater dispersion in gaps than durations],
    [weibull], [shape $k$], [1.14], [1.33], [60% of gap Weibull users have $k > 1$ (habitual checking)],
    [weibull], [scale $lambda$], [6,587 s (1.8 h)], [47,433 s (13.2 h)], [Characteristic timescale],
    [exponential], [scale $lambda^(-1)$], [252 s (4.2 min)], [—], [Only 3.6% of users; absent for gaps],
    [gamma], [shape $k$], [—], [—], [Negligible ($< 1$% of users for both)],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Full parameter estimates for all five distribution families from `sessions_tukey` (477,659 users with $>= 10$ data points). Medians are reported as they are robust to extreme outliers in parameter fits. Generated by `session_distribution_fit.R`.]
) <tbl-dist-params>

=== Engagement Rate ($pi$ Policy)

A session is not just a cluster of timestamps; it is a browsing episode in which the user is exposed to posts and chooses whether to act. We cannot directly observe which posts a user saw, so we estimate the number of posts seen per session via a time-based proxy:

$
"posts_seen"(s) = max( ("duration"(s)) / (v),  "interactions"(s) + "posts_authored"(s) + f)
$

where $v = 5$ s is the assumed average viewing time per post and $f = 4$ is a floor of unseen posts assumed even in the shortest session. Without the floor, a single-like session (duration 0 s) would yield `posts_seen = 0`, clamping engagement to 100%. The engagement rate is then:

$
"engagement_rate"(s) = ("interactions"(s)) / ("posts_seen"(s))
$

The median engagement rate across all sessions is 20.0% (mean 19.5%). In other words, the typical Bluesky user likes or reposts roughly one in five posts they see during a browsing session. The complementary $pi$ policy — $pi_"ignore" = 80%$, $pi_"like" approx 17%$, $pi_"repost" approx 3%$ — is the categorical distribution needed for the simulation calibration.

Sensitivity analysis varying $v$ from 2 s (fast scrolling) to 15 s (deep reading) shifts the median engagement rate from $approx 6%$ to $approx 44%$, confirming that $v = 5$ s is a reasonable mid-range assumption.

== Lifetime Analysis

Whereas session analysis captures the user's *demand* side — how often they
browse and interact — post-lifetime analysis captures the *supply* side: how
long a piece of content remains alive and how engagement arrives over time.
This section studies the $15.3 times 10^6$ top-level posts in the firehose
snapshot (posts with `reply_root_uri IS NULL`), measuring their engagement
trajectories from creation to final interaction.

=== Data Preparation

Two StarRocks tables were created to support the analysis:

- `pau_db.post_lifetime` — one row per top-level post, precomputing the
  *first* and *last* timestamp of each engagement type (repost, like, reply),
  plus total counts. Populated by `create_post_lifetime_table.sql` and
  `populate_post_lifetime.sql` ($15.3 times 10^6$ rows).
- `pau_db.post_engagement_events` — individual event timeline for every
  post, with columns `(post_did, post_rkey, event_time_us, event_type,
  actor_did)`. Enables temporal decay and cascade analysis. Populated by
  `create_post_engagement_events.sql` and `populate_post_engagement_events.sql`
  ($approx 140 times 10^6$ rows).

Only top-level posts are included; replies are thread participants rather than original content. Quote-posts are currently absent because `bsky.records` contains no `app.bsky.feed.post` rows — they would require extracting `embed_uri` from the raw JSONL files.

=== Engagement Counts

*Question:* do engagement counts (reposts, likes, replies) follow a power-law?
The script `eda/fit_powerlaw_counts.py` fits a discrete power-law via MLE
with KS-based $x_min$ selection (Clauset et al., 2009) and compares against
lognormal, Weibull, and exponential alternatives via Vuong's log-likelihood
ratio test.

A striking 50.7% of posts receive *no engagement at all*. Of engaged posts,
likes are the most common (92.7%), followed by replies (35.4%) and reposts
(33.1%). For each engagement type, the counts in the tail follow a discrete
power-law (Table @tbl-powerlaw-counts).

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Type*], [*α*], [*x_min*], [*n_tail*], [*KS*], [*p*],
    table.hline(stroke: 0.5pt),
    [Reposts], [2.21], [84], [30,610], [0.0145], [1.00],
    [Likes], [2.15], [127], [112,443], [0.0093], [1.00],
    [Replies], [2.26], [42], [9,206], [0.0273], [1.00],
    [Combined], [2.14], [152], [115,128], [0.0087], [1.00],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Discrete power-law fit on engagement counts.
    All four pass the bootstrap goodness-of-fit test ($p > 0.05$).
    $alpha approx 2.15$ lies in the finite-mean, infinite-variance regime.]
) <tbl-powerlaw-counts>

The power-law is *strongly favoured* over all alternatives: Vuong's R values
range from $+2{,}933$ (replies vs lognormal) to $+85{,}822$ (combined vs
exponential), with $p < 0.001$ throughout. The exponent $alpha approx 2.15$
sits in the $2$–$3$ range characteristic of social media — finite mean,
infinite variance — meaning the distribution is extremely heavy-tailed.
Engagement is concentrated on very few posts.

#figure(
  image("figures/powerlaw_counts_compare.png", width: 90%),
  caption: [Complementary CDF of engagement counts for reposts, likes, and
    replies. All three decay as straight lines in log-log space — the
    hallmark of a power-law. Generated by `fit_powerlaw_counts.py`.]
) <fig:powerlaw-counts>

=== Lifetime Distribution

*Question:* how long does a post stay alive? Lifetime is measured as
$t_"last" - t_"created"$ for posts that receive any engagement.
The script `eda/fit_powerlaw_lifetimes.py` fits four continuous
distributions (Pareto, Weibull, lognormal, exponential) to the
$7.5 times 10^6$ engaged posts with positive lifetime.

#figure(
  table(
    columns: 4,
    align: (center, left, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Rank*], [*Distribution*], [*Log-likelihood*], [*Parameters*],
    table.hline(stroke: 0.5pt),
    [1], [Pareto (tail)], [$-23.8 times 10^6$], [$alpha = 2.16$, $x_min = 15.6$ h],
    [2], [Weibull], [$-84.7 times 10^6$], [shape $= 0.53$, scale $= 9.4$ h],
    [3], [Lognormal], [$-85.3 times 10^6$], [$sigma = 2.61$, $mu = 9.00$],
    [4], [Exponential], [$-88.8 times 10^6$], [scale $= 14.2$ h],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Distribution fit on post lifetimes. Power-law is best for the
    tail ($> 15.6$ h). Weibull (shape 0.53) best describes the body.
    Exponential is a poor fit — lifetimes are not memoryless.]
) <tbl-lifetimes-fit>

The result reveals a two-component structure (Figure @fig:lifetimes-ccdf).
The body of the distribution (lifetimes $< 15.6$ h, ~75% of engaged posts)
is best fit by a Weibull with shape $k = 0.53$. Since $k < 1$, the *hazard
rate decreases over time* — a post is actually *less* likely to die the longer
it has been alive, consistent with rich-get-richer dynamics. The tail
($> 15.6$ h, ~25% of engaged posts) follows a Pareto with
$alpha = 2.16$. The median lifetime is 3.8 hours, but $P_{99}$ reaches 133 h
(5.6 days).

#figure(
  image("figures/powerlaw_lifetimes_ccdf.png", width: 90%),
  caption: [Combined post lifetime CCDF with Pareto, Weibull, and lognormal
    fit overlays. Right panel: per-type CCDFs (reposts, likes, replies).
    The Pareto fit captures the heavy tail; Weibull (shape 0.53) captures
    the body. Generated by `fit_powerlaw_lifetimes.py`.]
) <fig:lifetimes-ccdf>

=== Temporal Decay

*Question:* within a post's lifetime, does engagement arrive evenly or cluster
early? The script `eda/temporal_decay.py` fits $N(t) prop t^beta$ — the
cumulative number of events as a function of time since creation — both on
pooled events from 3,000 posts and per-post on 100 posts from each of four
engagement-volume buckets.

The aggregate $beta = 0.34$ (strongly sub-linear), but this is pulled down by
the ecological fallacy: most posts die quickly. Per-post analysis yields
higher and more realistic values:

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Engagement bucket*], [*n*], [*Median β*], [*Mean β*], [*Std β*],
    table.hline(stroke: 0.5pt),
    [20–99 events], [98], [0.49], [0.57], [0.27],
    [100–999], [99], [0.49], [0.53], [0.22],
    [1K–10K], [99], [0.52], [0.60], [0.25],
    [10K+], [99], [0.61], [0.64], [0.18],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Per-post temporal decay exponent $beta$ by engagement volume.
    Higher-engagement posts spread events more evenly (higher $beta$),
    but all are sub-linear ($beta < 1$) — engagement always decelerates.]
) <tbl-temporal-decay>

All $beta$ values are well below 1: engagement always decelerates. However,
$beta$ *increases with volume* — viral posts ($10K+$ events) spread engagement
more evenly over time than typical posts ($20$–$99$ events). No post in the
sample showed linear or accelerating engagement. For simulation, $beta$ can
be sampled from $N(0.49, 0.27)$ for typical posts and $N(0.61, 0.18)$ for
high-engagement posts.

=== Time-to-First Engagement

*Question:* how long until the *first* repost, like, or reply arrives?
The script `eda/time_to_first.py` computes the time from post creation to
`first_*_us` for each engagement type.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Percentile*], [*First repost*], [*First like*], [*First reply*],
    table.hline(stroke: 0.5pt),
    [$P_1$], [9.7 s], [6.4 s], [*0.9 s*],
    [$P_{50}$ (median)], [13.3 min], [5.6 min], [5.9 min],
    [$P_{95}$], [14.9 h], [8.0 h], [9.4 h],
    [$P_{99}$], [49.1 h], [30.0 h], [32.7 h],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Time-to-first-engagement percentiles. Replies are the fastest
    ($P_1 = 0.9$ s, median 5.9 min); reposts are the slowest (median
    13.3 min). The ordering reply < like < repost is consistent with the
    engagement ladder hypothesis.]
) <tbl-time-to-first>

The ordering is consistent across all percentiles: *replies arrive fastest,
reposts slowest*. At $P_1$, replies appear in under a second (likely automated
or pre-coordinated interactions), while reposts take nearly 10 seconds.
Figure @fig:time-to-first shows the full CDFs.

#figure(
  image("figures/time_to_first_cdf.png", width: 85%),
  caption: [Cumulative distribution of time-to-first-engagement for reposts,
    likes, and replies (logarithmic time axis). Replies and likes are
    nearly indistinguishable; reposts lag behind. Generated by
    `time_to_first.py`.]
) <fig:time-to-first>

=== Cascade Ordering

*Question:* in what order do engagement types arrive on a post? The script
`eda/cascade_ordering.py` analyses three aspects: (1) first-event dominance
on posts that receive all three types, (2) pairwise ordering probabilities,
and (3) a Markov transition matrix $P("next" "|" "current")$ from 3,000
sampled post timelines.

*Likes dominate the cascade.* Of the $1.04 times 10^6$ posts receiving all
three engagement types, 76.2% are liked first. The Markov transition
matrix reveals a bursty structure:

#figure(
  table(
    columns: 4,
    align: (center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [$P("next" "|" "current")$], [*Repost*], [*Like*], [*Reply*],
    table.hline(stroke: 0.5pt),
    [Repost], [0.10], [*0.84*], [0.04],
    [Like], [0.16], [*0.77*], [0.04],
    [Reply], [0.06], [*0.81*], [0.09],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Markov transition matrix for engagement events.
    Rows sum to $approx 1$ (remaining probability is other event types).
    The dominant transition from any state is to *Like* (77–84%).
    Likes cluster; reposts are the most common exit from a like burst (16%).]
) <tbl-cascade-matrix>

The data supports an *engagement ladder* model. After the initial like burst
($P("like" -> "like") = 0.77$), the next most likely event is a repost
($P = 0.16$) rather than a reply ($P = 0.04$). A repost almost always implies
a prior like ($P("like" "|" "repost") = 0.94$), but the reverse is not true
($P("repost" "|" "like") = 0.34$): likes are necessary but not sufficient
for amplification. Figure @fig:cascade-transitions shows this structure as
a heatmap.

#figure(
  image("figures/cascade_transitions.png", width: 70%),
  caption: [Markov transition heatmap $P("next" "|" "current")$ from
    83,736 observed transitions across 3,000 posts. The dominant
    self-loop on *Like* (0.77) is clearly visible. Generated by
    `cascade_ordering.py`.]
) <fig:cascade-transitions>

=== Summary of Simulation Parameters

All quantities needed to calibrate the content supply side of the simulation:

- *Engagement counts:* discrete power-law, $alpha approx 2.15$, $x_min$ by
  type (42–152). $P("any engagement") = 0.493$.
- *Lifetimes:* two-component — Weibull (shape $0.53$, scale $9.4$ h) for
  $< 15.6$ h, Pareto ($alpha = 2.16$) beyond. Median 3.8 h.
- *Temporal decay:* $beta approx 0.5$ (sub-linear), $N(t) prop t^beta$.
  Higher $beta$ for high-engagement posts.
- *Time-to-first:* median 5.6 min (like), 5.9 min (reply), 13.3 min (repost).
- *Cascade:* likes first (76%), Markov transition matrix governs subsequent
  events. $P("like" "|" "repost") = 0.94$, $P("repost" "|" "like") = 0.34$.

Scripts employed: `eda/fit_powerlaw_counts.py`, `eda/fit_powerlaw_lifetimes.py`,
`eda/temporal_decay.py`, `eda/time_to_first.py`, `eda/cascade_ordering.py`,
orchestrated by `analyze_post_lifetime.py`. SQL preparation via
`create_post_lifetime_table.sql`, `populate_post_lifetime.sql`,
`create_post_engagement_events.sql`, `populate_post_engagement_events.sql`.
