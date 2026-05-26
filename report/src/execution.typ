#import "utils.typ": *

This section covers what are we going to execute and why, as well as the results with the metrics defined in the topology section.

== Datasets and Runs

As explained in @sec-data-topology, the full Bluesky social graph ($1.47 times 10^9$ edges) was sampled at three scales using the Forest Fire algorithm. Each scale was executed for a different number of independent runs, determined by the execution time budget: smaller topologies allow many replications for statistical power; the largest topology permits fewer, reflecting its heavy computational cost.

#figure(
  table(
    columns: 4,
    align: (center, right, right, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Dataset*], [*Nodes*], [*Edges*], [*Runs*],
    table.hline(stroke: 0.5pt),
    [DS-100K], [$99834$], [$approx 1.7 times 10^6$], [1400],
    [DS-500K], [$499197$], [$approx 11.2 times 10^6$], [134],
    [DS-1M],   [$997779$], [$approx 25.1 times 10^6$], [10],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Datasets used for the evaluation. All three are Forest Fire samples of the full Bluesky follower graph. Edge counts grow superlinearly with nodes, consistent with the heavy-tailed degree distribution of the underlying network. The number of runs per dataset was allocated proportionally to the available compute budget (see @tbl-execution-time).]
) <tbl-datasets>

Every run produced the four trace files described in @sec-design-traces. The following metrics were computed from the JSONL output of each run and aggregated across replications.

Before presenting the simulation results, a brief execution performance characterization is warranted. @fig-execution-time shows the wall-clock time per run as a function of network size.

#figure(
  image("images/results/execution_time_scaling.png", width: 85%),
  caption: [Simulation execution time vs. network size. Points show the mean and observed range across all runs of each dataset. The dashed line is a linear regression ($R^2 = 1.000$ over the three points), with slope $1.42$ s per thousand users ($1.4$ ms per user). Doubling the number of users doubles the execution time —-a textbook example of linear scalability-— meaning the simulation can grow to larger networks without collapsing under its own weight.]
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
  caption: [Execution time and peak memory per dataset. Time grows linearly with node count; memory grows superlinearly due to the $N times M$ impression matrices (see @sec-impl-impressions). All runs executed on the same server (see @apx-performance-hardware).]
) <tbl-execution-time>

#todo[this i don't like it that much, rewrite ]

To put these numbers in perspective: simulating the full activity of a one-million-user social network —-every post created, every timeline served, every like and repost propagated through the follower graph-— completes in roughly 23 minutes on a single server. This is a remarkable result. When the project began, the ambition was simply to reach a scale large enough to produce meaningful statistical output within a practical time frame; there was no guarantee that a ground-up simulation engine written in a systems language would scale gracefully. The fact that execution time grows in direct proportion to the number of users —-not quadratically, not exponentially-— means that what could have been a multi-day batch job fits comfortably into an afternoon.

Concretely: a run at 100K users takes just over a minute, making 600 independent replications feasible. At 500K users, a run takes around 11 minutes, allowing 134 replications. Even at 1M users —-the largest topology tested-— ten full runs were completed. Across all three scales, the simulation produced a total of 744 independent traces, each containing the complete event-level history of a synthetic social network. This volume of data is what makes the statistical analysis in the following sections possible: without linear scalability, the replication count would drop sharply with network size, undercutting the confidence of every estimate.

The linear behaviour is not accidental. It is the direct result of deliberate engineering choices: the D-ary heap with preallocated capacity (@sec-impl-queue) keeps every event-queue operation at $O(1)$ amortized cost; the CSR graph layout (@sec-impl-csr) turns neighbour iteration into a cache-friendly sequential scan; and the buffered binary I/O pipeline (@sec-impl-trace-io) avoids serialization inside the hot simulation loop. Each of these decisions was made with scalability as the guiding concern, and the data confirm they paid off.

Memory, by contrast, grows superlinearly —-roughly $10 times$ from 100K to 1M nodes-— driven by the two `PagedBitSet` instances that track seen and interacted posts. Each matrix is $N times M$ bits, and $M$ itself grows with $N$ (more users produce more posts during the fixed simulation horizon). This $O(N^2)$ worst-case memory footprint is the primary bottleneck for scaling beyond one million users, and addressing it is a central item in @sec-future-performance. A more detailed breakdown of memory consumption is provided in @apx-performance-space.

== Steady State of the Simulation
<sec-exec-stationary>

Before committing to the full batch execution, a single representative run from each dataset scale was analysed to confirm that the simulation reaches a stationary regime within the configured horizon. The DES model involves stochastic session dynamics: users go online and offline according to calibrated Pareto distributions, and the system needs enough time for these rhythms to stabilise into a steady proportion of simultaneously active users. If the simulation were still burning in when the metrics are collected, the results would reflect transient startup behaviour rather than the equilibrium the CTIC model describes.

@fig-stationary-100K, @fig-stationary-500K, and @fig-stationary-1M (generated with `des-ctic/python-utilities/stationary.py`) show the online user fraction over time for one representative run at each scale. The dashed vertical line marks the detected stationary threshold —-the point after which the rolling mean of the online fraction stabilises within a narrow band.

#figure(
  image("images/execution/100K_session_trace_stationary.png", width: 90%),
  caption: [Stationary analysis for DS-100K (99,834 users, 450,605 session events). Stationary state reached at $t approx 2385$; average online fraction 7.7%.]
) <fig-stationary-100K>

#figure(
  image("images/execution/500K_session_trace_stationary.png", width: 90%),
  caption: [Stationary analysis for DS-500K (499,197 users, 2,213,374 session events). Stationary state reached at $t approx 2222$; average online fraction 8.5%.]
) <fig-stationary-500K>

#figure(
  image("images/execution/1M_session_trace_stationary.png", width: 90%),
  caption: [Stationary analysis for DS-1M (997,779 users, 4,549,885 session events). Stationary state reached at $t approx 2436$; average online fraction 7.6%.]
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
  caption: [Stationary distribution summary across datasets. The online fraction is stable across scales; stationary state is reached well within the active simulation window ($t in [1000, 5000]$).]
) <tbl-stationary>

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

Complementing the Methodology @sec-method-des-metrics this section will classify the metrics that we want to obtain.

In a simulation we can separate between two relevant quantites:
- Quantities of Interest: those are the quantities we do want to build the simulation for. In our case are structural virality and post lifetime.
- Features Quantities: quantities that are intrinsic to the simulation dynamics, that will appear out of the simulation execution.

*Structural Virality*

From the trace `creation` and `propagate`, the structural virality is going to be computed per every simulation. The idea is to verify the following across the distribution: which percentatge of viral posts there are. 

*Post Lifetimes*






