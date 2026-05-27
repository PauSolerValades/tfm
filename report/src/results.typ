#import "utils.typ": todo, comment, def

This chapter presents the empirical evaluation of the Continuous-Time Independent Cascade (CTIC) model. Utilizing the discrete-event simulation pipeline over the generated Bluesky topologies, we analyze the resulting event traces across three scales: 100K, 500K, and 1M nodes. The analysis follows a top-down framework: we first establish the macroscopic stability of the simulation, then descend into the microscopic user experience (platform congestion), before analyzing the meso-scale dynamics of information spread (engagement lifetimes and cascade morphology). We conclude by bridging these scales through non-dimensional coupling ratios and assessing the model against empirical data.

== Stability and Stationary Behavior
<sec-results-stationary>

Before analyzing the shape of information diffusion, it is necessary to confirm that the simulation metrics are statistically stable. The time-domain stationarity of individual runs was established in @sec-exec-stationary, where a single-run analysis detected convergence to a steady online fraction by $t approx 2200$–$2450$ (absolute time, including the $t in [0, 1000]$ warmup). Those single-run averages ranged from 7.6% to 8.5%.

Here we shift focus from within-run time convergence to *cross-run* statistical convergence: given that each run already reports a stationary-average online fraction (computed via sweep-line integration over $t >= 1000$), do these per-run estimates stabilize as we add more replications? The answer is an unambiguous yes.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K* ($n = 1600$)], [*500K* ($n = 136$)], [*1M* ($n = 10$)],
    table.hline(stroke: 0.5pt),
    [User online fraction], [$0.1154 plus.minus 5 times 10^(-5)$], [$0.1256 plus.minus 0.0001$], [$0.1133 plus.minus 0.0004$],
    [Empty-timeline exit %], [$50.85 plus.minus 0.02$], [$45.89 plus.minus 0.05$], [$53.03 plus.minus 0.20$],
    [Median backlog at exit], [$0.03 plus.minus 0.01$], [$10.42 plus.minus 0.17$], [$0.00$ (all 10 runs zero)],
    [Power-law exponent $gamma$], [$1.730 plus.minus 0.0004$], [$1.723 plus.minus 0.0007$], [$1.736 plus.minus 0.0015$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Batch means $plus.minus$ 95% confidence interval of stationary-state indicators across all replications. All four metrics converge tightly; the online fraction and $gamma$ exponent are scale-invariant, while empty-timeline exits and median backlog reveal a non-monotonic network-size effect.]
) <tbl-stationary-results>

@tbl-stationary-results reports batch means and 95% confidence intervals across the full replication set. Two key observations anchor the entire chapter. First, the online fraction converges to a consistent value across all three scales ($0.113$–$0.126$). This is a direct consequence of the calibrated session parameters: Pareto distributions governing duration and inter-session gaps are sampled from the same empirical ECDF regardless of network size, so the aggregate proportion of simultaneously active users is scale-invariant. The exceptionally tight confidence intervals —-standard deviations of $0.001$ at 100K and $0.0007$ at 1M-— confirm that the Activity-Driven session generation effectively balances concurrency without destabilizing the scheduler.

Second, the stationarity indicators show a non-monotonic pattern across network sizes. The 500K dataset yields the lowest empty-timeline exit rate ($45.9%$) and the only non-zero median backlog ($10.42$), while both the 100K and 1M datasets have median backlogs near zero and higher starvation. Whether this reflects a genuine network-size effect or a structural difference between the three Forest Fire samples (degree distribution shape, diameter, clustering) cannot be determined without a controlled ablation of sample topology. The 500K sample may simply have a more favourable connectivity structure; our suspicion leans toward simulation artifact over genuine optimum, but resolving this requires testing against additional samples at each scale. This non-monotonicity is explored further in @sec-results-congestion.

#figure(
  image("images/results/s1_convergence.png", width: 100%),
  caption: [Cumulative mean of the per-run average online fraction across replications. The x-axis indexes simulation runs (1 to $n$), not simulation time. Each run contributes its own stationary-average `avg_online_frac` (pre-computed via sweep-line integration over $t >= 1000$, see @sec-exec-stationary). The cumulative mean converges rapidly: at 100K, 1600 replications pin the estimate to $0.1154$ with a 95% CI of $5 times 10^(-5)$; at 1M, even with only 10 runs, the estimate settles at $0.1133 plus.minus 0.0004$. The shaded band is $plus.minus$ 1 SD of the per-run values.]
) <fig-s1-convergence>

@fig-s1-convergence shows how the estimator of the online fraction sharpens with replication count. The cumulative mean at 100K stabilizes to its final value within the first 100 runs (the shaded band narrows and the line goes flat), meaning the 1600-run budget is far more than needed for this metric —-the surplus replications serve other, higher-variance metrics. At 500K, 136 runs are sufficient; at 1M, 10 runs already yield a usable estimate, albeit with a wider confidence band. This is the statistical analogue of the time-domain stationarity established in @sec-exec-stationary: the system is not only in equilibrium within each run, but the equilibrium itself is reproducible across independent runs with different random seeds.

#figure(
  image("images/results/s1_histograms.png", width: 100%),
  caption: [Distribution of stationary indicators across runs: online fraction, empty-timeline exit percentage, and power-law exponent $gamma$. All three metrics form tight, unimodal distributions around their means, confirming convergence and the absence of multi-modal or chaotic regimes.]
) <fig-s1-histograms>

@fig-s1-histograms shows the per-run distribution of the three key indicators. All are unimodal and tightly concentrated, with no evidence of multi-stability or phase transitions within the explored parameter space. The power-law exponent $gamma approx 1.73$ deserves particular mention: it is invariant to network size, seed, and replication count, suggesting it is a universal constant of the simulation at this parameterization. The real Bluesky $gamma$ is $2.21$ (@tbl-powerlaw-counts) — significantly steeper — indicating that the simulation's homogeneous repost policy produces heavier tails than observed empirically. This discrepancy is addressed in @sec-results-validation.

== Queue Congestion
<sec-results-congestion>

With the baseline environment stabilized, we evaluate the main flow of information diffusion: the timeline queue. The central tension in a decentralized chronological feed is the balance between content starvation and timeline overload.

=== Timeline Starvation

The boredom mechanism (@sec-design-sources-sessions) terminates a session as soon as the user exhausts their feed. The mechanic represents the lack of new content to keep the user engaged, and represents the user seeing pasts posts that have already been seen. 

@tbl-congestion summarises the key congestion indicators derived from the session trace analysis.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [% sessions ending empty], [$50.9%$], [$45.9%$], [$53.0%$],
    [% sessions with zero actions], [$26.7%$], [$19.0%$], [$21.8%$],
    [Median backlog at exit], [0], [10], [0],
    [Mean actions per session], [28.1], [31.6], [28.2],
    [Median actions per session], [8], [12], [9],
    [% sessions creating $>= 1$ post], [9.2%], [10.2%], [9.3%],
    [Mean posts created per session], [0.40], [0.45], [0.40],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Platform congestion metrics across network scales. The 500K dataset shows the lowest starvation and highest engagement, while 1M has a median backlog of zero and 53% empty exits — worse than 100K, despite having 10× the users. Whether this is a network-size effect or a structural artifact of the specific Forest Fire samples is not resolved by these metrics alone.]
) <tbl-congestion>

The data reveals a clear bimodal behaviour depending on dataset size. At 1M, $21.8%$ of sessions record zero actions: the user comes online, finds an empty timeline, and immediately goes offline as there is not new content to see. The remaining $31.2%$ of empty-exit sessions (totaling $53.0%$) had at least one action but still exhausted the feed before the session ended —-they consumed what little content was available and then hit the boredom exit. At 500K the picture is healthier: only $19.0%$ of sessions are truly starved (zero actions) and $45.9%$ end empty overall, the lowest across all scales. Therefore, it can be concluded that content starvation is a real phenomena in our executions. It happens also across all scales, as roughly half of all sessions end because the timeline runs dry, but at a lesser degree in the 500K nodes size.

One possible explanation could be a heavy in-degree imbalance: users with very few followers receive less content through their timelines and therefore starve more often. To test this, per-user empty-exit rates were stratified by follower count (in-degree). @tbl-empty-by-indegree reports the result of the statistics of sessions ended with zero posts in the backlog per dataset.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Followers*], [*Users*], [*Mean empty %*], [*Median empty %*], [*Mean duration*], [*Mean actions*],
    table.hline(stroke: 0.5pt),
    table.cell(colspan: 6)[*100K*],
    table.hline(stroke: 0.3pt),
    [Zero], [2171], [44.1%], [47%], [129], [100.9K],
    [1–9], [12.1K], [45.1%], [50%], [127], [99.5K],
    [10–99], [26.6K], [44.7%], [49%], [128], [100.1K],
    [100–999], [30.7K], [44.3%], [47%], [129], [100.7K],
    [1K+], [28.3K], [44.7%], [48%], [128], [100.1K],
    table.hline(stroke: 0.3pt),
    table.cell(colspan: 6)[*500K*],
    table.hline(stroke: 0.3pt),
    [Zero], [8.9K], [40.2%], [39%], [142], [9.4K],
    [1–9], [52.2K], [40.7%], [40%], [141], [9.4K],
    [10–99], [139.4K], [40.3%], [39%], [141], [9.4K],
    [100–999], [192.3K], [40.7%], [40%], [141], [9.4K],
    [1K+], [106.5K], [40.5%], [39%], [141], [9.4K],
    table.hline(stroke: 0.3pt),
    table.cell(colspan: 6)[*1M*],
    table.hline(stroke: 0.3pt),
    [Zero], [22.0K], [44.8%], [47%], [147], [638],
    [1–9], [135.8K], [45.1%], [47%], [146], [635],
    [10–99], [333.6K], [45.0%], [47%], [146], [635],
    [100–999], [370.3K], [45.0%], [47%], [146], [635],
    [1K+], [136.2K], [45.0%], [47%], [146], [636],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Per-user empty-exit rate stratified by indegree (follower count). The result is unequivocal: follower count has no effect on timeline starvation. Zero-follower users starve at the same rate as users with 10K+ followers. Mean session duration and total actions per user are also flat across all buckets. The bimodal empty-exit distribution observed in @fig-s2-user-empty is not explained by network position.]
) <tbl-empty-by-indegree>

This finding rules out the in-degree imbalance hypothesis. Users who happen to be online during active periods receive content regardless of how many followers they have; users who log in during quiet periods find empty timelines regardless of their follower count.

#figure(
  image("images/results/s2_empty_by_indegree.png", width: 90%),
  caption: [Per-user empty-exit rate by indegree bucket. The distributions are nearly identical across all follower-count buckets at every scale, confirming that timeline starvation is a timing effect, not a topological one.]
) <fig-s2-empty-by-indegree>

The root cause lies in how the simulation manages timelines across sessions: when a user goes offline, their timeline is cleared (@sec-design-sources-sessions), purging all content accumulated during that session. However, propagations from followed users continue to arrive throughout the offline period — the timeline repopulates with whatever was posted while the user was away. When the user returns, they see only content from the most recent offline gap, not from prior sessions. This means content availability at session start depends entirely on whether other users were active during that specific offline window, which is a stochastic timing effect unrelated to the user's own degree. This session-purging design, combined with the propagation delay $Delta_p = 1$ tick, means a session can start with content (if the offline gap coincided with active periods) or with an empty feed (if it did not). 


#figure(
  image("images/results/s2_backlog_hist.png", width: 90%),
  caption: [Distribution of backlog at session end (log-log scale) for all three network sizes. The spike at zero dominates all three distributions: backlog zero is the mode at every scale. The 500K network shows the strongest rightward shift, with a visible mass between 10 and $10^3$ items, while 100K and 1M collapse almost entirely onto the zero backlog spike.]
) <fig-s2-backlog>

@fig-s2-backlog confirms the bimodal structure: the zero-backlog spike dominates all three scales, but 500K develops a distinct secondary mode with a heavy right tail, visible as mass between $10^1$ and $10^3$ backlog items. This secondary mode represents sessions that end with substantial unread content. At 1M, this mode collapses and the distribution concentrates almost entirely at zero. The cause of this difference — whether it is inherent to network size or a property of this particular 1M sample — is not resolved by the backlog distribution alone.

The boredom mechanic attempts to modelize the user "catching up" to past content, and therefore logging of: they see the most recent posts at the top of a reverse-chronological feed and stop long before reaching the older ones. The simulation approximates this by discarding older session content and retaining only what propagated during the most recent offline gap. This behaviour is not undesirable, but it does not reflect real life microblogging social networks nor the users behaviour entirely, so it would be worth that some amount of effort is redirected into modifying the model and the parameter calibration to make it behave more as its real counterpart.

Specifically, the boredom predomincance factor can be mitigated by reducing the `propagation_delay`: the faster the content travels, the more full the timelines will be, making the end of sessions due to boredom less prominent. Additionally, having a more diversity of sessions (that is, acknowledging the session length, gap and inter-creation post argued in Calibration @sec-cal-summary-pareto) could make the behaviour less prominent. Last but not the least, an argument could be made that the model is incomplete, and the boredom mechanism needs another counterpart mechanism that complements it. For example, if some user catches up on old content, could try to check content that has arrived  

In conclusion, the starvation rates reported can be considered a legitimate finding about the simulation's dynamics, not an artifact from data analysis.


=== Session Duration and Engagement

The boredom mechanic not just interacts with the queue, but it will also shift the `session_duration` parameter. This section answers which effects this has over it, with @tbl-session-dur reports the batch means of key session metrics, and @tbl-session-percentiles provides the full duration distribution.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Mean duration (no unit)], [$115.2 plus.minus 0.05$], [$128.9 plus.minus 0.11$], [$115.5 plus.minus 0.52$],
    [Median duration (no unit)], [$35.2 plus.minus 0.05$], [$49.5 plus.minus 0.10$], [$38.4 plus.minus 0.40$],
    [Actions per session], [$28.1 plus.minus 0.01$], [$31.6 plus.minus 0.03$], [$28.2 plus.minus 0.13$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Session metrics — batch means $plus.minus$ 95% CI across replications. The 500K network achieves the highest engagement (129 ticks mean duration, 32 actions per session). All values are scale-stable within tight confidence bands.]
) <tbl-session-dur>

#figure(
  table(
    columns: 7,
    align: (left, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Network*], [*$P_5$*], [*$P_25$*], [*$P_50$*], [*$P_75$*], [*$P_95$*], [*$P_99$*],
    table.hline(stroke: 0.5pt),
    [100K], [2], [6], [35], [128], [436], [1165],
    [500K], [2], [10], [50], [143], [469], [1285],
    [1M],   [2], [8], [38], [125], [429], [1194],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Session duration percentiles (pooled across all runs). The distribution is heavily right-skewed at every scale: the median is 35–50 ticks, but $P_99$ reaches $approx 1200$ ticks. The intended Pareto tail (which extends past 4000 ticks) is truncated by the boredom mechanism — no session lives as long as its Pareto distribution theoretically permits.]
) <tbl-session-percentiles>

#figure(
  image("images/results/s2_duration_hist.png", width: 90%),
  caption: [Session duration distribution (log-log scale) across network sizes. All three follow a heavy-tailed shape consistent with the underlying Pareto mixture, but the mass below $10^1$ ticks reflects boredom-truncated sessions that exit almost immediately.]
) <fig-s2-duration-hist>

@fig-s2-duration-hist shows the impact of the boredom is prominent on Pareto's heavy tail, as it should smoothly decrease. Instead, gets instantly trucated in both the 100K and 500K users. In the 1M dataset it is slowly decreasing, which could be significant. Unfortunately, to say that the dynamic is different in the 1M dataset, a significant more amount of runs would be needed to diferentate the behaviour from the other two graphs in a statistically significant way.

#figure(
  image("images/results/s2_duration_vs_empty.png", width: 90%),
  caption: [Session duration for empty-exit versus non-empty-exit sessions. At every scale, empty-exit sessions are dramatically shorter: the median empty-exit session lasts 12 ticks, while the median non-empty session lasts 105–114 ticks — a $9.5 times$ difference. Long sessions almost never end empty.]
) <fig-s2-duration-vs-empty>

@fig-s2-duration-vs-empty reveals the clearest signal of the boredom mechanism's impact. Across all scales, empty-exit sessions have a median duration of 12 ticks, while non-empty sessions have a median of 105 ticks — a factor of $9.5$. Long sessions of 300+ ticks end empty only 13–18% of the time, confirming that when content is available, users stay engaged and naturally reach their Pareto timeout. The boredom mechanism bifurcates the user population into two regimes: fast-exiting starvers and content-saturated engagers.

To quantify how far the empirical durations depart from the intended distribution, @tbl-pareto-compare compares the Pareto mixture (sampled from the 10,000 empirically-fitted parameter pairs assigned to users at initialization) against the actual session durations from the 1M network. The boredom mechanism does not uniformly shrink sessions. At the median, empirical durations (38 ticks) are slightly *longer* than intended (31 ticks), because sessions with content outlast their Pareto expiry —-the user keeps scrolling as long as there are posts. However, the tail is heavily truncated: the intended $P_99$ of 4142 ticks is never observed; the empirical $P_99$ is 1194 ticks (a 3.5× reduction). Zero-backlog sessions tell the other half: median 12 ticks versus intended 31 (a 2.6× reduction). These two opposing effects —-content-extended sessions and boredom-truncated sessions-— balance at the aggregate median ($38 approx 31$), masking the underlying bimodality.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Percentile*], [*Intended Pareto*], [*All sessions*], [*Empty-exit*], [*Non-empty-exit*],
    table.hline(stroke: 0.5pt),
    [$P_5$], [1], [2], [1], [3],
    [$P_25$], [9], [8], [2], [14],
    [$P_50$], [31], [38], [12], [105],
    [$P_75$], [100], [125], [45], [246],
    [$P_90$], [313], [270], [116], [428],
    [$P_95$], [726], [429], [199], [590],
    [$P_99$], [4142], [1194], [552], [1478],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Intended Pareto mixture versus empirical session duration percentiles (1M network, single run). The boredom mechanism does not shift the median ($31 arrow.r 38$) but severely truncates the tail: $P_99$ drops from 4142 to 1194 ticks (3.5×). Zero-backlog sessions are an order of magnitude shorter at every percentile.]
) <tbl-pareto-compare>

=== Per-User Engaged Analysis

Beyond session-level aggregates, per-user summaries would ideally reveal whether the starvation burden is distributed uniformly or concentrated on specific users. Computing per-user session aggregation across all 1746 replications proved computationally prohibitive within the project's time constraints, so @tbl-per-user offers a baseline snapshot from a single randomly-selected run per scale: sessions are grouped by `user_id` and aggregated within each user (total sessions, mean and median duration, fraction of empty exits, total actions, total reposts). The table reports the mean and median of these per-user distributions. While these single-run values should not be extrapolated to the full replication corpus, they establish the existence of per-user heterogeneity and motivate more rigorous cross-run per-user analysis in future work.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Per-user metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Mean sessions per user], [3.3], [3.4], [3.3],
    [Mean session duration (ticks)], [202], [223], [206],
    [Median session duration], [87], [102], [91],
    [Mean % empty exits], [$34.4%$], [$28.4%$], [$34.2%$],
    [Mean total actions], [96], [106], [96],
    [Mean total reposts], [1.1], [1.3], [1.2],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Per-user aggregated metrics from a single random run per scale. The average user experiences 3.3 sessions, with mean session durations of $approx 200$ ticks. Per-user empty-exit rates ($28$–$34%$) are substantially lower than the session-level rate ($46$–$53%$), because most users experience a mix of empty and non-empty sessions rather than starving consistently.]
) <tbl-per-user>

#figure(
  image("images/results/s2_user_empty_hist.png", width: 90%),
  caption: [Per-user empty-exit fraction histogram. The distribution is bimodal: a concentration near zero (users who almost never starve) and a secondary mode near 50–60%. Few users starve in every session, and few users never starve —-most experience a mix.]
) <fig-s2-user-empty>

@fig-s2-user-empty shows that the starvation burden is neither uniform nor perfectly concentrated. A substantial fraction of users have low empty-exit rates ($< 20%$), indicating they consistently find content. Another cluster sits at 50–60%, and a thin tail extends to 100%. This suggests that timeline starvation is partially structural (driven by network position — low-degree users receive less content) and partially stochastic (driven by session timing overlaps). A user who comes online during a content lull may starve regardless of their follower count.

#figure(
  image("images/results/s2_actions_hist.png", width: 90%),
  caption: [Actions per session distribution (log-log). The mode is at 1 action, and the heavy tail —-reaching $10^3$ actions in the longest sessions-— reflects the Pareto-driven engagement of the content-saturated minority. Users are net consumers: the created-to-consumed ratio is approximately $0.014$ across all scales.]
) <fig-s2-actions>

#figure(
  image("images/results/s2_reposters_vs_non.png", width: 90%),
  caption: [Session duration for users who ever repost versus those who never repost. Reposters have significantly longer sessions: their median session duration is 2–3$times$ that of non-reposters. Engagement depth and propagation activity are tightly coupled —-users who repost are also users who stay online longer.]
) <fig-s2-reposters>

@fig-s2-reposters reveals a coupling between engagement depth and session persistence: users who ever perform a repost have substantially longer sessions (median 2–3$times$ that of never-reposters). This is mechanistically expected — reposting requires the user to encounter a post and choose to propagate it, so reposters must have sessions long enough to consume content — but it also has a feedback implication: the users driving cascade propagation are the same users sustaining platform engagement, forming a virtuous cycle where content sustains attention and attention sustains content.

== Posts Propagation 
<sec-results-lifetimes>

Information in real social networks does not diffuse uniformly; it follows heavy-tailed distributions as explained in @sec-sota-topo-scalefree. This section examines whether the simulation captures the dynamics non-emerging from the topology and how the temporal properties of engagement scale with network size.

=== Post Lifetime Distribution

The post lifetime $tau_"raw"$ measures the time from creation to the last engagement (like or repost). The normalized lifetime $tau_"norm" = tau_"raw" / Delta_p$ uses $Delta_p = 1$, so the two are numerically identical but the normalized form is scale-agnostic. @tbl-lifetimes and @tbl-lifetimes-zero summarise the lifetime statistics for posts created during steady state, split by whether they received any reposts.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Total posts (steady state)], [$1.72 times 10^8$], [$7.98 times 10^7$], [$1.05 times 10^7$],
    [% posts with any reposts], [$25.1%$], [$21.3%$], [$19.4%$],
    [Mean $tau_"raw"$ (w/ reposts)], [843], [984], [1107],
    [Median $tau_"raw"$ (w/ reposts)], [471], [613], [750],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Post lifetime statistics for posts that received at least one repost. Mean lifetimes grow modestly with network size ($843 arrow.r 1107$ ticks), but the fraction of posts that attract any reposts declines ($25.1% arrow.r 19.4%$) — content dilution increases with scale.]
) <tbl-lifetimes>

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Posts with zero reposts], [$1.29 times 10^8$], [$6.28 times 10^7$], [$8.46 times 10^6$],
    [  of which: zero engagement], [$29.1%$], [$35.4%$], [$38.7%$],
    [Mean $tau_"raw"$ (zero engagement)], [168], [179], [204],
    [Median $tau_"raw"$ (zero engagement)], [2.4], [2.3], [2.2],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Lifetime statistics for posts with zero reposts. Among these, 29–39% also receive zero engagement (no likes). The truly dead posts have median lifetimes of $approx 2$ ticks: created, propagated to followers, and never interacted with again.]
) <tbl-lifetimes-zero>

Three conclusions can be extracted from both tables. First, the fraction of posts that attract any reposts declines with network size ($25.1% arrow.r 21.3% arrow.r 19.4%$). More users produce more content, but the same total propagation budget is spread thinner, therefore competition for attention grows with scale. 

Second, among posts that do attract engagement, lifetimes lengthen modestly ($843 arrow.r 984 arrow.r 1107$ ticks mean). A post in a larger network has more potential downstream reposters, so the cascade takes longer to exhaust. Therefore, a the bigger and more connected the network is, the more likely is for a post to survive longer.

Third, the zero-engagement subset (posts that receive neither likes nor reposts, comprising 29–39% of all zero-repost posts) have median lifetimes of $approx 2$ ticks and mean lifetimes of $approx 180$ ticks (driven by a long tail). These posts are propagated to followers, sit unread, and are cleared when the session ends.

#figure(
  image("images/results/s3_lifetime_ccdf.png", width: 90%),
  caption: [CCDF of normalized lifetime $tau_"norm"$ for posts with at least one repost (sampled). The distributions are heavy-tailed at all scales, with approximate power-law decay in the mid-range. Large networks shift the distribution rightward: posts survive longer as the pool of potential reposters grows.]
) <fig-s3-lifetime-ccdf>

=== Repost Power-Law Exponent

The repost cascade size distribution follows a discrete power law $PP(X >= x) ∼ x^(-(gamma - 1))$, fitted using the MLE estimator with $x_"min" = 1$ @clauset2009powerlaw. The batch means in @tbl-stationary-results report $gamma$ per network size: 1.730 (100K), 1.723 (500K), and 1.736 (1M). These values are statistically indistinguishable: the exponent is a scale-invariant property of the model, not an artifact of network size or replication count.

The empirical Bluesky repost exponent is $gamma = 2.21$ (@tbl-powerlaw-counts), significantly steeper than the simulation's $1.73$. In the real network, rare large cascades (size $>= 1000$) are substantially rarer than the simulation predicts. This discrepancy is mechanistically expected: the simulation assigns a uniform $p_"repost" = 0.012$ to every user at every timeline encounter, while real Bluesky has heterogeneous reposting behavior —-most users never repost, while a few power users repost frequently. A uniform policy inflates the probability of mid-size cascades and thus flattens the tail. This is visible in the repost CCDF (@fig-s3-reposts-ccdf).

#figure(
  image("images/results/s3_reposts_ccdf.png", width: 90%),
  caption: [CCDF of total reposts per post (sampled, posts with at least one repost). The distribution follows an approximate power law at all scales with $gamma approx 1.73$, slightly heavier-tailed than the empirical Bluesky $gamma = 2.21$. The 1M run's sparse tail reflects the limited replication count (10 runs), not a genuine difference in the exponent.]
) <fig-s3-reposts-ccdf>

=== Burstiness Analysis

Burstiness quantifies the temporal clustering of repost events within a single cascade. For a post with $n >= 2$ reposts occurring at times $t_1, t_2, ..., t_n$, let $Delta_i = t_i - t_{i-1}$ be the inter-repost gaps (following the same $Delta$ gap convention used for user activity gaps in @sec-cal-sessions). Let $mu$ and $sigma$ be the mean and standard deviation of these gaps. Burstiness is then defined as @eq-burstiness.

$ B = (sigma - mu) / (sigma + mu) $ <eq-burstiness>

The burstiness coefficient $B in [-1, 1]$
- $B = 1$ means all reposts arrive simultaneously, 
- $B = 0$ corresponds to a memoryless Poisson process, and 
- $B = -1$ indicates perfectly regular spacing.

@tbl-burstiness-global reports the global mean and standard deviation of $B$ across all reposted posts, alongside the time-to-peak metrics.

#figure(
  table(
    columns: 3,
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Size*], [$dash(B)$], [$sigma_B$],
    table.hline(stroke: 0.5pt),
    [100K], [$-0.207$], [0.435],
    [500K], [$-0.170$], [0.433],
    [1M], [$-0.164$], [0.429],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Global burstiness and time-to-peak across all reposted posts. The mean $dash(B)$ is slightly negative ($approx -0.18$), with high dispersion ($sigma_B approx 0.43$), and the median is zero at all scales — over half of reposted posts receive only one repost. The mean time to 50% of peak reposts grows linearly with network size (7.0 $arrow.r$ 15.0 ticks), while the median remains zero (the first repost accounts for most of the total).]
) <tbl-burstiness-global>

The global stats mask a strong dependence on cascade size. @tbl-burstiness-bucket stratifies $B$ by repost count bucket.

#figure(
  table(
    columns: 7,
    align: (left, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Bucket*], [$dash(B)$ (100K)], [$sigma_B$ (100K)], [$dash(B)$ (500K)], [$sigma_B$ (500K)], [$dash(B)$ (1M)], [$sigma_B$ (1M)],
    table.hline(stroke: 0.5pt),
    [1], [0.000], [0.000], [0.000], [0.000], [0.000], [0.000],
    [2–4], [$-0.631$], [0.441], [$-0.632$], [0.447], [$-0.635$], [0.450],
    [5–9], [$+0.084$], [0.244], [$+0.127$], [0.218], [$+0.140$], [0.204],
    [10–49], [$+0.336$], [0.213], [$+0.382$], [0.167], [$+0.381$], [0.151],
    [50+], [$+0.572$], [0.100], [$+0.538$], [0.107], [$+0.521$], [0.112],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Burstiness stratified by repost count bucket. Mean $dash(B)$ is near-identical across network sizes, confirming burstiness is a scale-invariant property of the CTIC model. The standard deviation decreases with bucket size: large cascades are consistently bursty ($sigma_B approx 0.1$), mid-size cascades have high variance ($sigma_B approx 0.44$). The transition from negative to positive $dash(B)$ occurs at 5–9 reposts.]
) <tbl-burstiness-bucket>

#figure(
  image("images/results/s3_burstiness.png", width: 90%),
  caption: [Mean burstiness $B$ by repost count bucket, with error bars. The transition from negative to positive $B$ occurs between 2–4 reposts (anti-bursty) and 5–9 reposts (weakly bursty). The monotonically increasing $B$ with cascade size confirms that repost timing is not scale-free: larger cascades accelerate.]
) <fig-s3-burstiness>

First conclusion to extract from @tbl-burstiness-global and @tbl-burstiness-bucket is that burstiness is basically invariant scale-wise: it does not matter the amount of nodes in a dataset, its a fundamental property of the CTIC model, so it shows regardless of the dataset. The second one is that there is a relationship between the 

The transition from anti-bursty ($B < 0$) to bursty ($B > 0$) is maybe the most important finding. Small cascades of 2–4 reposts have $B approx -0.63$: the few reposts are spread out over time, consistent with independent discovery ---each reposter encounters the post organically through their timeline, and these encounters are temporally dispersed. Large cascades of 50+ reposts have $B approx +0.52$: repost events cluster together, indicating that once a cascade reaches critical mass, each repost exposes the content to a new audience whose own reposts arrive in rapid succession. The cascade accelerates, consistent with the "rich-get-richer" dynamics expected from the CTIC model.

=== Time to Peak Engagement

The time required for a post to accumulate 50% of its total reposts ($"time_to_peak_50"$) measures the speed of cascade maturation. @tbl-ttp50 reports the mean and median.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Mean $t_"peak 50"$ (ticks)], [7.0], [10.9], [15.0],
    [Median $t_"peak 50"$ (ticks)], [0.0], [0.0], [0.0],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Time to 50% of total reposts (posts with $>= 1$ repost). The median is 0 at all scales —-half of all reposted posts receive their first repost instantly (the author's followers are notified at $t = 0$ of creation). The mean grows with network size, reflecting the increased latency of multi-hop propagation through larger topologies.]
) <tbl-ttp50>

The median $t_"peak 50"$ is zero across all scales: for half of all reposted posts, the first repost accounts for at least 50% of total reposts. This is a consequence of the heavy-tailed repost distribution — most posts get only one or two reposts total, so the first repost inherently constitutes the majority. The mean $t_"peak 50"$ grows linearly from 7.0 to 15.0 ticks as network size increases 10×, reflecting the additional topological hops required for a post to propagate through a larger follower graph. This linear scaling of temporal latency with network diameter is a direct mechanistic consequence of the hop-by-hop CTIC propagation.

#figure(
  image("images/results/s3_ttp50_hist.png", width: 90%),
  caption: [Distribution of time to 50% of peak reposts (log-binned, posts with $>= 2$ reposts and $t_"peak 50" > 0$). The mode is near zero at all scales, and the distribution spans several orders of magnitude. Larger networks extend the right tail, reflecting the additional propagation hops required to reach distant reposters.]
) <fig-s3-ttp50>

== Independent Cascade Analysis
<sec-results-cascades>

The climax of the meso-scale analysis lies in the shape of the cascades. A cascade is more than its size: two posts with 20 reposts can have fundamentally different diffusion structures — one a flat broadcast (all reposters saw the original), the other a deep multi-generational chain. The structural virality $nu$ (normalized Wiener index, @sec-method-des-metrics) captures this distinction.

=== Global Cascade Metrics

@tbl-cascades-global reports the batch means of cascade morphology metrics across all replications.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Cascades (size $>= 3$)], [$2.65 times 10^7$], [$1.05 times 10^7$], [$1.32 times 10^6$],
    [Mean cascade size $N$], [5.3], [6.1], [6.3],
    [Median cascade size], [4], [4], [4],
    [Max cascade size], [217], [953], [1632],
    [Mean depth $d_"max"$], [2.9], [3.3], [3.6],
    [Max depth], [70], [106], [87],
    [Mean virality $nu$], [1.90], [2.05], [2.10],
    [Max virality], [26.9], [29.8], [34.9],
    [% viral ($N >= 10$)], [$9.3%$], [$13.7%$], [$13.6%$],
    [% viral ($N >= 50$)], [$0.02%$], [$0.22%$], [$0.47%$],
    [% branching ($"max_out_degree" >= 2$)], [$45.8%$], [$42.0%$], [$35.6%$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Global cascade morphology metrics. The median cascade (4 nodes, depth 2–3, $nu approx 1.67$) is modest: a small star or short chain. But the tails are heavy: maximum cascade sizes reach 1632 nodes, maximum depth reaches 106 hops, and maximum virality reaches 34.9. Larger networks amplify the tail without shifting the median.]
) <tbl-cascades-global>

The table has a lot to unpack, let's analyze by facts:

First, the median cascade is modest and scale-invariant: 4 nodes at every network size. The common cascade is a small star ---the author plus two or three direct reposters--- and this does not change with network scale. 

Second, the tail fattens with network size: the fraction of cascades reaching size $>= 50$ grows from $0.02%$ at 100K to $0.47%$ at 1M (a 23× increase), and the maximum cascade size grows from 217 to 1632. Therefore, larger networks provide longer propagation chains and a larger pool of potential reposters, enabling rare extreme cascades without altering the typical case. 

Third, maximum virality reaches 34.9 at 1M — substantially beyond the real Bluesky maximum of 80.7 (@tbl-virality-stats), but within the same order of magnitude.

Fourth, the other característics from the table do change with the dataset scale, which is absolutely expected: the more amount of users and connections, the more chance for a cascade to grow big.

=== Structural Virality Distribution

This section has computed the structural virality of every post in every simulation per dataset. @fig-s4-virality shows the histrograms of structural virality $nu$, excluding cascades with the minimal $nu = 1.33$ (pure chains of 3 nodes).

#figure(
  image("images/results/s4_virality_hist.png", width: 90%),
  caption: [Structural virality distribution (binned, excluding minimal $nu = 1.33$). The distribution is unimodal with a heavy right tail. At 1M, $13.6%$ of cascades have $nu >= 4$, indicating genuine multi-generational branching rather than flat broadcast.]
) <fig-s4-virality>

Additionally, the log-log plot of the histrogram, thats the complementary cumulative distribution funciton, is provided at @fig-s4-virality-ccdf as the histograms were very steep.

#figure(
  image("images/results/s4_virality_ccdf.png", width: 90%),
  caption: [CCDF of structural virality $nu$, sampled. The heavy tail extends to $nu approx 10$ at 100K ($alpha=5.3$), $nu approx 20$ at 500K ($alpha=4.1$), and $nu approx 30$ at 1M ($alpha=3.5$). Larger networks enable more structurally complex propagation trees, but the bulk of the distribution ($nu <= 4$) is scale-invariant.]
) <fig-s4-virality-ccdf>

As we can see, structural virality follows a power-law distribution, with bigger the alpha the smaller the dataset. This is not due to a topology problem, but a lack of sampling: 100K with 1600 runs has much more posts that sampled more for the heavy tail, while the 1M dataset did not, so the graph does not follow the red dotted line equally.

@tbl-virality-dist summarises the virality percentiles.

#figure(
  table(
    columns: 8,
    align: (left, center, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Size*], [*Mean $nu$*], [*Median $nu$*], [$P_25$], [$P_75$], [$P_95$], [*\% minimal*], [*\% branching*],
    table.hline(stroke: 0.5pt),
    [100K], [1.90], [1.67], [1.33], [2.21], [3.33], [$39.4%$], [$45.8%$],
    [500K], [2.05], [1.67], [1.33], [2.33], [4.00], [$38.7%$], [$42.0%$],
    [1M],   [2.10], [1.67], [1.33], [2.33], [4.33], [$40.3%$], [$35.6%$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Structural virality percentiles. The median $nu = 1.67$ is stable across scales. The upper tail ($P_95$) grows from 3.33 (100K) to 4.33 (1M), consistent with larger networks enabling deeper branching structures. Approximately 40% of all cascades are minimal chains with no branching at all.]
) <tbl-virality-dist>

The fraction of minimal cascades ($nu <= 1.34$, pure chains) is remarkably stable at $approx 39%$ across all scales. These are cascades where the propagation tree is a simple chain or a two-hop fan with negligible branching ---structurally uninteresting, but numerically dominant. The branching fraction ($"max_out_degree" >= 2$) declines slightly with scale ($45.8% arrow.r 35.6%$), indicating that while larger networks produce more extreme cascades, the bulk of the distribution shifts toward simpler structures, a consequence of content dilution: posts in larger networks have more competitors and are less likely to find multiple reposters at any given hop. Additionally, the $P_95$ is consistent with the scalar topology found beforehand, the bigger the dataset the bigger can the cascades be.

=== Depth–Size Scaling

Cascade depth grows sub-linearly with cascade size. @tbl-depth-size stratifies cascade morphology by size bucket in the 1M dataset, as is the one which has more diviersity.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Size bucket*], [*Cascades (1M)*], [*Mean $nu$*], [*Mean depth*], [*Mean max-out*],
    table.hline(stroke: 0.5pt),
    [3–4], [773K], [1.44], [2.2], [1.1],
    [5–9], [364K], [2.35], [4.1], [1.9],
    [10–19], [128K], [3.82], [6.9], [4.1],
    [20–49], [46K], [5.56], [10.9], [9.6],
    [50+], [6.2K], [8.45], [20.2], [27.2],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Cascade morphology by size bucket for the 1M network. Depth grows sub-linearly with size: a 50+ cascade has mean depth 20.2 but mean max-out 27.2 —-large cascades achieve their size through extreme branching at individual nodes, not through deep chains. The 100K and 500K tables show identical structure; data available in @apx-metrics.]
) <tbl-depth-size>

#figure(
  image("images/results/s4_depth_vs_size.png", width: 90%),
  caption: [Hexbin density of cascade depth versus cascade size (log-log). The bulk traces a sub-linear scaling: depth grows approximately as $N^0.6$. The diffuse cloud at small sizes ($<= 10$) represents shallow cascades with varied depth, while the sparse high-size tail is populated by deep, heavily branched trees.]
) <fig-s4-depth-vs-size>

The sub-linear depth–size scaling is a robust finding. A cascade of 50+ nodes achieves its size through branching (mean max-out-degree 27.2) rather than depth (mean depth 20.2). @fig-s4-broadcast-vs-viral reinforces this: cascade depth in the CTIC model is fundamentally a broadcast phenomenon, not deep chaining.

#figure(
  image("images/results/s4_broadcast_vs_viral.png", width: 90%),
  caption: [Hexbin density of max-out-degree (broadcast) versus cascade depth (viral chaining). The distribution is dominated by low-depth, moderate-broadcast cascades. Deep cascades exist but are rare; the typical cascade is a wide fan-out from one or two influential reposters.]
) <fig-s4-broadcast-vs-viral>

The largest simulated cascade (1632 nodes at 1M) has depth 87 and max-out 24 — it is simultaneously deep and broad, but the breadth-to-depth ratio remains high. This is consistent with the CTIC model's broadcast-dominant mechanics: one influential reposter fans out to hundreds of followers, each of whom may propagate further, but the fan-out at each hop dwarfs the hop count. Social media cascades in the CTIC framework are wide, shallow trees — not long chains.

=== Top Cascades

@tbl-top-cascades lists the five most structurally viral cascades at each network scale.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Rank*], [*Size*], [*Depth*], [*$nu$*], [*Author degree*],
    table.hline(stroke: 0.5pt),
    table.cell(colspan: 5)[*1M*],
    table.hline(stroke: 0.3pt),
    [1], [150], [87], [34.9], [107],
    [2], [130], [60], [29.5], [29],
    [3], [142], [74], [28.1], [1848],
    [4], [98], [63], [26.3], [29],
    [5], [93], [65], [26.1], [1574],
    table.hline(stroke: 0.3pt),
    table.cell(colspan: 5)[*500K*],
    table.hline(stroke: 0.3pt),
    [1], [343], [106], [29.8], [612],
    [2], [338], [100], [27.7], [612],
    [3], [302], [94], [27.4], [612],
    [4], [217], [78], [27.4], [612],
    [5], [79], [49], [26.2], [1954],
    table.hline(stroke: 0.3pt),
    table.cell(colspan: 5)[*100K*],
    table.hline(stroke: 0.3pt),
    [1], [93], [67], [26.9], [14],
    [2], [136], [70], [25.9], [14],
    [3], [97], [65], [25.7], [14],
    [4], [144], [67], [24.3], [14],
    [5], [74], [62], [24.3], [14],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Top 5 most structurally viral cascades per network size. The most viral cascade (1M, $nu = 34.9$) has 150 nodes, depth 87, and an author with only 107 followers. At 500K, the top four cascades all originate from the same author (degree 612), suggesting that specific topological positions (not raw follower count alone) enable extreme virality. At 100K, the top five cascades all come from authors with just 14 followers.]
) <tbl-top-cascades>

The top cascades have something in common ---or rather, the lack of something in common is what they actually share. There is no correlation which the users with bigger degree connections make more viral posts. 

100K dataset is the biggest showcase of this. We know from Execution @sec-exec-datasets that $gamma=1.17$ for the power-law. The fraction of users with at least 14 followers is $PP(X >= 14) ∼ 14^(-(gamma - 1)) = 14^(-0.17) approx 0.64$ —-roughly 64% of users. A user with exactly 14 followers is thoroughly ordinary, not an outlier.

The statistical absence of any degree–virality relationship is confirmed by correlation tests across all three scales (@tbl-correlation).

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Correlation*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Pearson ($"in-degree" arrow.r nu$)], [$+0.004$], [$+0.003$], [$+0.000$],
    [Spearman ($"in-degree" arrow.r nu$)], [$+0.002$], [$+0.004$], [$+0.002$],
    [Log-log ($"in-degree" arrow.r nu$)], [$-0.000$], [$+0.005$], [$+0.004$],
    [$R^2$ (cascade size from deg)], [$1 times 10^(-5)$], [$4 times 10^(-6)$], [$-0.000$],
    [$R^2$ ($nu$ from deg)], [$2 times 10^(-5)$], [$8 times 10^(-6)$], [$-0.000$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Correlation between an author's in-degree (follower count) and the structural virality of the posts they create. All coefficients are effectively zero: Pearson and Spearman correlations are below $0.005$, and $R^2$ values are on the order of $10^(-5)$–$10^(-6)$. An author's follower count explains none of the variance in how viral their posts become.]
) <tbl-correlation>

At 500K, a single author (degree 612) accounts for four of the top five, but at 1M, the top cascade comes from an author with only 107 followers ($PP(X=107) approx 0.45$). The most viral cascade at any scale ($nu = 34.9$, 1M) has 150 nodes, depth 87, and max-out 24 — a genuinely deep tree with balanced branching, and it's the same for the 1M dataset.

@tbl-influencer quantifies whether cascade outcomes depend on the author's follower count by stratifying cascades into degree buckets.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Author followers*], [*Cascades*], [*Mean size*], [*Mean depth*], [*Mean $nu$*],
    table.hline(stroke: 0.5pt),
    [Zero], [579K], [5.21], [2.87], [1.89],
    [1–99], [10.2M], [5.28], [2.90], [1.91],
    [100–999], [8.1M], [5.24], [2.89], [1.90],
    [1K–10K], [7.3M], [5.26], [2.89], [1.90],
    [10K+], [289K], [5.42], [2.97], [1.94],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Cascade metrics by author follower count (100K network). Values are near-identical across all buckets. A post from a 10K+ follower author has mean cascade size 5.42 versus 5.21 for a zero-follower author —-a 4% difference. There is no influencer effect in the CTIC model with homogeneous behavioral policies.]
) <tbl-influencer>

The influencer effect is absent. Mean cascade size varies from 5.21 (zero followers) to 5.42 (10K+ followers) — a 4% difference that is dwarfed by the variance within each bucket. @fig-s4-influencer visualizes this flat relationship directly.

#figure(
  image("images/results/s4_influencer_scatter.png", width: 90%),
  caption: [Hexbin density of author in-degree versus cascade size (log-log, sampled). The cloud is horizontally flat across all three scales: cascade size does not trend upward with author follower count. The density is highest at low author degrees simply because most users have few followers — but the cascade outcomes are statistically identical at every degree level.]
) <fig-s4-influencer>

This is a direct mathematical consequence of the homogeneous policy and the CTIC model structure. In the CTIC framework, the cascade dies or lives based on the second-hop structure: if a first-hop reposter has many followers, the cascade explodes; if the first-hop reposters have few followers, the cascade dies regardless of the author's degree. The author merely provides the initial spark; the subsequent propagation structure is determined by the degree distribution of the reposters, not the author. This finding validates a core theoretical property of the CTIC model and has important implications: heterogeneous policies (power users with higher $p_"repost"$) would be necessary to reproduce the influencer effects observed in real social media.

=== Cascade Size Distribution

@tbl-cascade-log reports the cascade size distribution binned by order of magnitude.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*$log_10$(size)*], [*Cascades (1M)*], [*Mean $nu$*], [*Mean depth*], [*Mean max-out*],
    table.hline(stroke: 0.5pt),
    [0 (3–9)], [1.14M], [1.73], [2.8], [1.4],
    [1 (10–99)], [179K], [4.39], [8.3], [6.0],
    [2 (100–999)], [897], [10.33], [28.8], [54.1],
    [3 (1000+)], [4], [7.66], [44.2], [592.2],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Cascade size distribution by log scale (1M network). The exponential drop-off with size is consistent with the $gamma approx 1.73$ power-law exponent: each order of magnitude reduces the count by approximately $10^3$. Only 4 cascades in the entire 1M corpus reach size $>= 1000$.]
) <tbl-cascade-log>

The distribution spans four orders of magnitude: 1.14 million cascades of size 3–9, dropping to 179K at size 10–99, 897 at size 100–999, and just 4 at size 1000+. @fig-s4-cascade-ccdf shows the CCDF. This is not a smooth power law — the steep drop from $log_10 = 1$ to $log_10 = 2$ (a 200× reduction) reflects the simulation's finite-size cutoff, where the pool of available reposters (at most $N$ users, with $approx 11%$ online) imposes a hard upper bound on cascade growth that a true power law would not encounter. As this is equally promominent in the three datasets, it's dismissed from being caused by missing data.

#figure(
  image("images/results/s4_cascade_size_ccdf.png", width: 90%),
  caption: [CCDF of cascade size (sampled). The distribution follows the $gamma approx 1.73$ power law through the mid-range but drops sharply at the high end due to the finite network size. The 1M network supports the largest cascades ($N approx 10^3$) before hitting the finite-size cutoff.]
) <fig-s4-cascade-ccdf>

== Micro-Macro Coupling
<sec-results-coupling>

To bridge the simulation's microscopic parameters to its macroscopic emergent dynamics, we define three dimensionless temporal ratios. Each compares the lifespan of a post against a characteristic system timescale.

#def(name: "Session Persistence")[
  We denote the session persistence $pi$ the number of user sessions that fit within a post lifetime, and we compute it as the post lifetime and the session length:

  $ pi  = frac(tau_"post", tau_"session") $

  $pi > 1$ means that content outlives the users that engage with it.
]

#def(name: "Creation Destiny")[
  We denoe the creation destiny $tau_c$ the number of new posts created system-wide (the whole simulation) during one single post lifetime.  

  $ tau_c = frac(tau_"post", tau_"create") $

  It quantifies attention competitions between posts.
]

#def(name: "Offline-cycle persistence")[
  We denote as $omega$ the offline-cycle as the number of cycle a posts survives being reposted. An $omega > 1$ means that the content spans more than one user session.

  $ omega = frac(tau_"post", tau_"offline") $
]

The @tbl-coupling reports batch means $plus.minus$ 95% CI for all three ratios across the three network scales. All three ratios grow with network size because $tau_"post"$ increases (larger networks provide more potential reposters) while $tau_"session"$ and $tau_"offline"$ are scale-invariant (calibrated from the same empirical ECDF). At 1M, $omega$ exceeds 2 — content reliably bridges multiple offline cycles, ensuring information propagates across the activity rhythms of the user base.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Ratio*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [$pi$], [$7.33 plus.minus 0.01$], [$7.64 plus.minus 0.02$], [$9.59 plus.minus 0.11$],
    [$tau_c$], [$42.2 plus.minus 0.07$], [$49.2 plus.minus 0.13$], [$55.4 plus.minus 0.52$],
    [$omega$], [$1.90 plus.minus 0.003$], [$2.22 plus.minus 0.006$], [$2.51 plus.minus 0.023$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Micro-macro coupling ratios (batch means $plus.minus$ 95% CI). All three grow with network size, driven by longer post lifetimes in larger topologies. Posts outlive sessions by 7–10× ($pi$), compete with 42–55 new posts during their lifespan ($tau_c$), and survive 2–3 offline cycles ($omega$).]
) <tbl-coupling>

== Empirical Validation and Discussion
<sec-results-validation>

This section will focus on comparing similarities and differences of the quantities found within the simulation with the results found in @sec-data regarding the quantities of interest of the simulation and it's characteristics.

First, let us discard the incomparable metircs: the simulation outputs per-encounter probabilities (e.g., $p_"repost" = 0.012$), while the firehose reports global event counts. Normalizing by impressions —-the number of timeline encounters per user-— would enable a direct comparison, but this quantity is not observable in the firehose data.

That said, several structural comparisons are meaningful. 

The repost power-law exponent ($gamma_"sim" = 1.73$ vs $gamma_"real" = 2.21$) indicates the simulation overestimates the frequency of mid-size cascades and underestimates the extreme tail, as illustrated in @fig-powerlaw-compare. Furthermore, the power-laws of a social network simulation are usually between 2 and 3, so this detail is important to state: despite not by a lot, it could be argued that the power-law is not extreme enough for a social network. 

#figure(
  image("images/results/powerlaw_comparison.png", width: 70%),
  caption: [Log-log CCDF comparison of the simulated ($gamma = 1.73$) and empirical Bluesky ($gamma = 2.21$) repost cascade size distributions. The simulation's flatter slope means rare large cascades are more common than observed in reality — a direct consequence of the uniform $p_"repost" = 0.012$ policy.]
) <fig-powerlaw-compare>

The power-law finiding are consistent with user homogeneous policies: every user has the same repost probability, whereas real networks concentrate repost activity in a small fraction of power users depending on the content and similarities.

The structural virality comparison ($nu_"sim" approx 2.10$ vs $nu_"real" = 1.35$) shows the simulation produces more branched propagation trees. In the real Bluesky data, 54.7% of cascades have $nu = 1.0$ which is pure broadcast, where every reposter saw the original post directly. The CTIC model's minimum $nu$ is approximately 1.33 (a two-hop chain through the author and one intermediate), so the entire virality distribution is shifted upward. This is a structural consequence of how the propagation tree is reconstructed in the trace analysis, not a missing simulation mechanism.

Post lifetimes reveal the strongest signature of the simulation's most restrictive simplification: post homogeneity (@sec-method-des-assumptions). In the real Bluesky data (@sec-data-lifetime), 50.7% of posts receive zero engagement and are effectively dead on arrival. In the simulation, only 29–39% of posts are lifeless —-the homogeneous repost policy artificially inflates engagement across all posts equally, flattening the distribution. Yet among posts that do attract reposts, the fraction of engaged posts that get at least one repost is remarkably close (33.1% in reality vs 32–35% in simulation). The simulation does not produce too many viral posts — it produces too many *moderately* engaged posts, and too few truly dead ones. Every post in the CTIC model is created equal, with identical repost probability regardless of content quality, timing, or topical relevance. Real posts are not: a controversial take and a mundane update face fundamentally different engagement landscapes, and this heterogeneity is what the homogeneous post assumption erases.

The empty-timeline exit rate ($46$–$53%$) has no direct empirical counterpart. Real platforms are not typically described as "starved" for content, but a direct comparison is difficult: a real user who opens the app and sees nothing new is unlikely to be counted in any public metric. The simulation's timeline model — purging on disconnect, repopulating from the offline gap ---captures the fact that users only consume recent content, but it does not model varying scroll depth. Whether a user starves depends on whether others posted during their offline window, which is ultimately a function of the global activity rate and the inter-session gap distribution.

These discrepancies are not failures of the model but calibration and design targets. The CTIC framework successfully reproduces the qualitative signatures of social media diffusion ---heavy-tailed cascade sizes, sub-linear depth–size scaling, session persistence, and scale-invariant convergence-— even if the quantities in which they are replicated are not exactly the same. That quantitative gaps point to concrete next steps: heterogeneous behavioral policies and scroll-depth-aware timeline consumption, as well as dropping some of the simplifications. Each of these is a tractable extension that builds on the validated core engine.

== Summary of Findings
<sec-results-findings>

This section acts as a small conclusion of the previous sections, highlighting the most relevant results and findings of the models executions.

=== Successes of the Model

Despite its idealized behavioral policies, the CTIC model natively captures the fundamental realities of a decentralized social network:
- *Scale-Free Engagement:* The model reliably generates heavy-tailed cascade sizes following a power-law distribution. Even with a flatter exponent ($gamma approx 1.73$), it proves that asymmetric information diffusion emerges organically from the continuous-time mechanics.
- *Temporal Inertia:* Posts successfully bridge offline gaps. With a session persistence ratio of $pi > 7$, the simulation proves that information survives across multiple user login/logout cycles, mimicking real-world relevance decay.
- *System Scalability:* The Activity-Driven simulation engine proved highly scalable and statistically stable, maintaining stationary equilibrium across 100K, 500K, and 1M node topologies without chaotic oscillation.

=== Phenomenological Findings

The trace analysis revealed several major phenomena regarding how information moves through the network:
+ *The Emergence of Burstiness:* Repost timing is not constant. The model exhibits a clear transition from anti-bursty, organic discovery in small cascades ($dash(B) approx -0.63$ for 2–4 reposts) to intense, bursty acceleration in massive cascades ($dash(B) approx +0.53$ for 50+ reposts). The transition occurs at 5–9 reposts — the critical mass where a cascade shifts from independent encounters to rich-get-richer acceleration.
+ *The Influencer Effect is Behavioral, Not Topological:* In a model with homogeneous repost policies, an author's follower count exerts zero influence over the final size or structural virality of their cascade. All correlation coefficients between in-degree and cascade outcomes are below $0.005$; $R^2$ values are on the order of $10^(-5)$. The simulation proves that reproducing real-world influencer oligarchy requires heterogeneous user behavior (power users), not just a heavy-tailed follower graph.
+ *Sub-Linear Depth Scaling:* Cascades achieve massive size not through deep, multi-generational chains, but through extreme branching at localized nodes. The dominant shape of diffusion is a wide, shallow fan rather than a deep tree —-the largest cascades have hundreds of nodes but only tens of hops.
+ *Starvation is a Timing Effect, Not a Topological One:* Per-user empty-exit rates are statistically identical across all indegree buckets. Users with zero followers starve at the same rate as users with 10K+ followers. Content availability at session start depends on whether other users were active during the offline window, not on the user's own network position.

=== Model Artifacts and Limitations
The deviations between the simulated metrics and the Bluesky firehose dataset pinpoint the exact limitations of the current design, offering clear pathways for model improvement:
- *Post Homogeneity Flattens Engagement:* The simulation undercounts zero-engagement posts (29–39% vs 50.7% in reality) because every post is treated identically. In real networks, most posts are irrelevant to most users and die immediately; the homogeneous repost policy artificially inflates the baseline engagement rate across all posts equally. Yet among posts that do attract reposts, the fraction matches reality closely (32–35% sim vs 33.1% real) —-the model gets the engaged-post dynamics right but misses the dead-post majority.
- *Flatter Power-Law Tail:* The simulation's repost cascade exponent ($gamma = 1.73$) is significantly flatter than the empirical Bluesky exponent ($2.21$), and below the 2–3 range typical of social networks. This is a direct consequence of uniform repost probabilities: every user reposts at the same rate, whereas real networks concentrate repost activity in a tiny fraction of power users.
- *Timeline Starvation as a Design Artifact:* The high rate of empty-timeline exits is amplified by the session-purging timeline model. While the amnesiac design is a valid approximation of reverse-chronological consumption, it creates a cold-start effect at every session that overstates starvation relative to a platform where timelines accumulate content during offline periods.
