#import "utils.typ": *

This section covers what are we going to execute and why, as well as the results with the metrics defined in the topology section.

== Datasets and Runs
<sec-exec-datasets>

As explained in @sec-data-topology, the full Bluesky social graph ($1.47 times 10^9$ edges) was sampled at three scales using the Forest Fire algorithm. Each scale was executed for a different number of independent runs, determined by the execution time budget: smaller topologies allow many replications for statistical power; the largest topology permits fewer, reflecting its heavy computational cost.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Nodes], [100,001], [500,008], [1,000,002],
    [Edges], [120M], [502M], [654M],
    table.hline(stroke: 0.3pt),
    [Avg. in-degree], [1208], [1005], [654],
    [Median in-degree], [203], [191], [111],
    [Zero-follower users], [$2.2%$], [$1.8%$], [$2.2%$],
    [$gamma$ (power-law MLE)], [1.17], [1.17], [1.19],
    [Tail $alpha$ ($x > 1000$)], [1.94], [1.32], [1.16],
    [Max in-degree], [42,568], [211,726], [407,981],
    table.hline(stroke: 0.5pt),
    [Runs], [1600], [136], [10],
    table.hline(stroke: 0.5pt),
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Datasets used for evaluation.],
    [Datasets used for evaluation. All three are Forest Fire samples of the full Bluesky follower graph. Average degree declines with sample size (1208 $arrow.r$ 654) because larger samples include more peripheral low-degree nodes from the heavy tail. The power-law exponent $gamma approx 1.17$ is near-identical across scales, confirming Forest Fire preserves the scale-free structure, but the tail exponent $alpha$ for $x > 1000$ steepens in smaller samples due to finite-size truncation. The number of runs was allocated proportionally to the available compute budget (see @tbl-execution-time).],
  )
) <tbl-datasets>

While all three samples share the same underlying graph and sampling method, their topological properties diverge in ways that affect simulation dynamics. The declining median degree ($203 arrow.r 111$) and diverging tail behaviour ($alpha = 1.94 arrow.r 1.16$) mean the three samples are not simply scaled copies of each other — the 1M sample has a heavier tail but a lower median degree, which contributes to the non-monotonic results observed in @sec-results.

Every run produced the four trace files described in @sec-design-traces. The following metrics were computed from the JSONL output of each run and aggregated across replications.

Before presenting the simulation results, a brief execution performance characterization is warranted. @fig-execution-time shows the wall-clock time per run as a function of network size.

#figure(
  image("images/results/execution_time_scaling.png", width: 85%),
  caption: flex-caption(
    [Simulation execution time vs. network size.],
    [Simulation execution time vs. network size. Points show the mean and observed range across all runs of each dataset. The dashed line is a linear regression ($R^2 = 1.000$ over the three points), with slope $1.42$ s per thousand users ($1.4$ ms per user). Doubling the number of users doubles the execution time —-a textbook example of linear scalability-— meaning the simulation can grow to larger networks without collapsing under its own weight.],
  )
) <fig-execution-time>

#figure(
  table(
    columns: 4,
    align: (center, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Dataset*], [*Time range (s)*], [*Mean time (s)*], [*Peak RSS (GB)*],
    table.hline(stroke: 0.5pt),
    [DS-100K], [70 -- 92], [81], [32 -- 34],
    [DS-500K], [600 -- 700], [650], [250 -- 260],
    [DS-1M],   [1,320 -- 1,390], [1,355], [800 -- 900],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Execution time and peak memory per dataset.],
    [Execution time and peak memory per dataset. Time grows linearly with node count; memory grows superlinearly due to the $N times M$ impression matrices (see @sec-impl-impressions). All runs executed on the same server (see @apx-performance-hardware).],
  )
) <tbl-execution-time>

#todo[this i don't like it that much, rewrite ]

To put these numbers in perspective: simulating the full activity of a one-million-user social network —-every post created, every timeline served, every like and repost propagated through the follower graph-— completes in roughly 23 minutes on a single server. This is a remarkable result. When the project began, the ambition was simply to reach a scale large enough to produce meaningful statistical output within a practical time frame; there was no guarantee that a ground-up simulation engine written in a systems language would scale gracefully. The fact that execution time grows in direct proportion to the number of users —-not quadratically, not exponentially-— means that what could have been a multi-day batch job fits comfortably into an afternoon.

Concretely: a run at 100K users takes just over a minute, making 1600 independent replications feasible. At 500K users, a run takes around 11 minutes, allowing 136 replications. Even at 1M users —-the largest topology tested-— ten full runs were completed. Across all three scales, the simulation produced a total of 1746 independent traces, each containing the complete event-level history of a synthetic social network. This volume of data is what makes the statistical analysis in the following sections possible: without linear scalability, the replication count would drop sharply with network size, undercutting the confidence of every estimate.

The linear behaviour is not accidental. It is the direct result of deliberate engineering choices: the D-ary heap with preallocated capacity (@sec-impl-queue) keeps every event-queue operation at $O(1)$ amortized cost; the CSR graph layout (@sec-impl-csr) turns neighbour iteration into a cache-friendly sequential scan; and the buffered binary I/O pipeline (@sec-impl-trace-io) avoids serialization inside the hot simulation loop. Each of these decisions was made with scalability as the guiding concern, and the data confirm they paid off.

Memory, by contrast, grows superlinearly —-roughly $10 times$ from 100K to 1M nodes-— driven by the two `PagedBitSet` instances that track seen and interacted posts. Each matrix is $N times M$ bits, and $M$ itself grows with $N$ (more users produce more posts during the fixed simulation horizon). This $O(N^2)$ worst-case memory footprint is the primary bottleneck for scaling beyond one million users, and addressing it is a central item in @sec-future-performance. A more detailed breakdown of memory consumption is provided in @apx-performance-space.

== Steady State of the Simulation
<sec-exec-stationary>

Before committing to the full batch execution, a single representative run from each dataset scale was analysed to confirm that the simulation reaches a stationary regime within the configured horizon. The DES model involves stochastic session dynamics: users go online and offline according to calibrated Pareto distributions, and the system needs enough time for these rhythms to stabilise into a steady proportion of simultaneously active users. If the simulation were still burning in when the metrics are collected, the results would reflect transient startup behaviour rather than the equilibrium the CTIC model describes.

@fig-stationary-100K, @fig-stationary-500K, and @fig-stationary-1M (generated with `des-ctic/python-utilities/stationary.py`) show the online user fraction over time for one representative run at each scale. The dashed vertical line marks the detected stationary threshold —-the point after which the rolling mean of the online fraction stabilises within a narrow band.

#figure(
  image("images/execution/100K_session_trace_stationary.png", width: 90%),
  caption: flex-caption(
    [Stationary analysis for DS-100K.],
    [Stationary analysis for DS-100K (99,834 users, 450,605 session events). Stationary state reached at $t approx 2385$; average online fraction 7.7%.],
  )
) <fig-stationary-100K>

#figure(
  image("images/execution/500K_session_trace_stationary.png", width: 90%),
  caption: flex-caption(
    [Stationary analysis for DS-500K.],
    [Stationary analysis for DS-500K (499,197 users, 2,213,374 session events). Stationary state reached at $t approx 2222$; average online fraction 8.5%.],
  )
) <fig-stationary-500K>

#figure(
  image("images/execution/1M_session_trace_stationary.png", width: 90%),
  caption: flex-caption(
    [Stationary analysis for DS-1M.],
    [Stationary analysis for DS-1M (997,779 users, 4,549,885 session events). Stationary state reached at $t approx 2436$; average online fraction 7.6%.],
  )
) <fig-stationary-1M>

#figure(
  table(
    columns: 3,
    align: (center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Dataset*], [*Avg. online fraction*], [*Stationary at $t approx$*],
    table.hline(stroke: 0.5pt),
    [DS-100K], [7.7%], [2385],
    [DS-500K], [8.5%], [2222],
    [DS-1M],   [7.6%], [2436],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Stationary distribution summary across datasets.],
    [Stationary distribution summary across datasets. The online fraction is stable across scales; stationary state is reached well within the active simulation window ($t in [1000, 5000]$).],
  )
) <tbl-stationarity>

Three observations become obvious giving the data a glance. First, the online fraction converges to a consistent value across all three scales, between 7.6% and 8.5% of users are simultaneously active at any moment in the steady state. This is a direct consequence of the calibrated session parameters: the Pareto distributions governing session duration and inter-session gaps are sampled from the same empirical ECDF regardless of network size, so the aggregate proportion of online users is scale-invariant.

Second, stationary state is reached at roughly the same point in all three runs ($t approx 2200$–$2450$), well within the active simulation window ($t in [1000, 5000]$ after warmup). This means that approximately half of each run's timeline operates in the stationary regime, providing ample data for the metric computations in the following sections, and no bigger horizons than 5000 are needed. 

Third, the 500K run reaches stationarity slightly earlier ($t approx 2222$) than the 100K run ($t approx 2385$). This is expected: with five times more users, the law of large numbers smooths out the aggregate signal faster, reducing the variance that the stationarity detector must wait to subside. The 1M run ($t approx 2436$) is slightly later than 500K, but all are within the same range.

These results validate the simulation horizon of 5000 time units, accounting for the 1000 warmup, makes a duration of 4000 ticks: the system reliably reaches equilibrium, and the stationary regime occupies a substantial fraction of every run.

== Time Agnostic Results
<sec-exec-agnostic>

To ensure the simulation results remain invariant to absolute wall-clock metrics and easily comparable across alternative contexts, all temporal findings are reported as multiples of the system's fundamental propagation delay ($Delta_p$). By normalizing absolute time ($t$) against this characteristic scale, we derive a dimensionless representation of post lifetimes:

$ tau = frac(t, Delta_p) $

In this model, $Delta_p$ is defined as exactly one discrete simulation tick ($Delta_p = 1$). This magnitude was selected because it represents the most fundamental, ubiquitous operational baseline of the environment, and one of the fundamentals quantites definitng the continuous cascade independent model. Expressing results in terms of these intrinsic simulation ticks abstracts away specific hardware or network latencies, rendering the performance analysis strictly system-agnostic.

== Simulation Results Obtention

Before proceeding to the results chapter, we must cover the trace analysis process into the result dataset obtention. As every simulation outputs four trace files, it was unfeasible to not develop a pipeline to generate results datasets to be analyzed. The files can be found at `des-ctic/trace-analysis/main.py`.

The main objective of this dataset was not to provide results for itself, but to aggregate the trace data first into `.parquet` formats for ease of readability. The procedure for the pipeline was relatively straight forward, as it iterates over the given directory, loads the traces into memory per run, computes the appropiate metrics and writes them.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`sim_id`], [str], [Unique simulation replication ID],
    [`post_id`], [i64], [Post identifier],
    [`total_reposts`], [i64], [Number of reposts received],
    [`lifetime_raw`], [f64], [Time from creation to last engagement (ticks)],
    [`lifetime_norm`], [f64], [`lifetime_raw` $\/ Delta_p$ ($Delta_p = 1$, same as raw)],
    [`time_to_peak_50`], [f64], [Time from first repost until 50\% of total reposts],
    [`burstiness_B`], [f64], [Burstiness parameter $B \in [-1, 1]$ from inter-repost times],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Schema of `out_posts.parquet`.],
    [Schema of `out_posts.parquet`. One row per post created during steady state. Lifetime and burstiness metrics are computed from the full repost sequence of each post.],
  )
) <tbl-posts>

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`sim_id`], [str], [Unique simulation replication ID],
    [`post_id`], [i64], [Origin post identifier],
    [`author_degree`], [i64], [Follower count (in-degree) of the post's author],
    [`cascade_size`], [i64], [Nodes in cascade tree (author + distinct reposters)],
    [`cascade_depth`], [i64], [Longest path from root to leaf in propagation tree],
    [`struct_virality`], [f64], [Wiener index normalized as average pairwise distance ($nu$)],
    [`max_out_degree`], [i64], [Max direct children for any node in the tree],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Schema of `out_cascades.parquet`.],
    [Schema of `out_cascades.parquet`. One row per post with cascade size $N >= 3$ ($>= 2$ reposts). Only posts created during steady state are included; cascade trees are reconstructed via batch parent-matching over repost and propagation traces.],
  )
) <tbl-cascades>

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`sim_id`], [str], [Unique simulation replication ID],
    [`user_id`], [i64], [User who had the session],
    [`start_time`], [f64], [Time when session started (ticks)],
    [`end_time`], [f64], [Time when session ended (ticks)],
    [`duration`], [f64], [`end_time - start_time` (ticks)],
    [`backlog_at_start`], [i64], [Backlog when session began (always 0)],
    [`backlog_at_end`], [i64], [Backlog when session ended],
    [`n_actions`], [i64], [Total timeline pops (ignore + like + repost)],
    [`n_reposts`], [i64], [Reposts performed in this session],
    [`n_likes`], [i64], [Likes performed],
    [`n_ignores`], [i64], [Ignores performed],
    [`n_posts_created`], [i64], [Posts authored during session],
    [`empty_timeline_exit`], [bool], [True if session ended with backlog $= 0$],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Schema of `out_sessions.parquet`.],
    [Schema of `out_sessions.parquet`. One row per session during steady state. Session boundaries are determined by the `session_trace.jsonl` start/end events; actions are assigned to sessions via temporal join.],
  )
) <tbl-sessions>

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`sim_id`], [str], [Unique simulation replication ID],
    [`network_size`], [i64], [Total agents in topology],
    [`avg_online_frac`], [f64], [Stationary average online fraction (sweep-line)],
    [`median_backlog`], [f64], [Median unread items at session end],
    [`empty_timeline_pct`], [f64], [\% of sessions ending with zero backlog],
    [`gamma_reposts`], [f64], [Power-law exponent $gamma$ (MLE, Clauset et al.)],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Schema of `out_run_summary.parquet`.],
    [Schema of `out_run_summary.parquet`. One row per simulation replication, aggregating all sessions and posts within the run. The power-law exponent is estimated from the per-run `total_reposts` distribution via discrete MLE with $x_min = 1$.],
  )
) <tbl-summary>

Tables @tbl-posts, @tbl-cascades, @tbl-sessions, and @tbl-summary showcase every metric obtained from the simulation. Each dataset is computed independently per run and concatenated across replications, ensuring that the statistical analysis in @sec-results operates on the full 1746-run corpus. The specific explanation and interpretation of each metric will be found in @sec-results.
