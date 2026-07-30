#import "utils.typ": *

#comment[I think we might be able to erradicate this chapter from the report, all into appendix or just one section in Results. Regardless, i will add some comments on what i think is wrong]

This section covers what are we going to execute and why, as well as the results with the metrics defined in the topology section.

== Datasets and Runs
<sec-exec-datasets>

As explained in @sec-data-topology, the full Bluesky social graph ($1.47 times 10^9$ edges) was sampled at three scales using the Forest Fire algorithm. Each scale was executed for a different number of independent runs, determined by the execution time budget: smaller topologies allow many replications for statistical power; the largest topology permits fewer, reflecting its heavy computational cost.

#comment[I will execute all the datasets 100 times, and as they behave the same i will just report one in results. ]

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

#comment[the analysis here probably should go in Data, when talking about the sampling from the data]

While all three samples share the same underlying graph and sampling method, their topological properties diverge in ways that affect simulation dynamics. The declining median degree ($203 arrow.r 111$) and diverging tail behaviour ($alpha = 1.94 arrow.r 1.16$) mean the three samples are not simply scaled copies of each other — the 1M sample has a heavier tail but a lower median degree, which contributes to the non-monotonic results observed in @sec-results.

Every run produced the four trace files described in @sec-design-traces. The following metrics were computed from the JSONL output of each run and aggregated across replications.

Before presenting the simulation results, a brief execution performance characterization is warranted. @fig-execution-time shows the wall-clock time per run as a function of network size.


#comment[last version of the simulatoin is FASTER than this and more leaner with ram. Again, the speed is one of the main achivements of this work therefore should not be hidden, although this is just too long. Probably should be mentcioned with an in depth appendix talking about RAM usage]

#figure(
  image("../images/results/execution_time_scaling.png", width: 85%),
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
    [Execution time and peak memory per dataset. Time grows linearly with node count; memory grows superlinearly due to the $N times M$ impression matrices (see @apx-impl-impressions). All runs executed on the same server (see @apx-performance-hardware).],
  )
) <tbl-execution-time>


The linear behaviour is not accidental. It is the direct result of deliberate engineering choices: the D-ary heap with preallocated capacity (@apx-impl-queue) keeps every event-queue operation at $O(1)$ amortized cost; the CSR graph layout (@apx-impl-csr) turns neighbour iteration into a cache-friendly sequential scan; and the buffered binary I/O pipeline (@apx-impl-trace-io) avoids serialization inside the hot simulation loop. Each of these decisions was made with scalability as the guiding concern, and the data confirm they paid off.

Memory, by contrast, grows superlinearly —-roughly $10 times$ from 100K to 1M nodes-— driven by the two `PagedBitSet` instances that track seen and interacted posts. Each matrix is $N times M$ bits, and $M$ itself grows with $N$ (more users produce more posts during the fixed simulation horizon). This $O(N^2)$ worst-case memory footprint is the primary bottleneck for scaling beyond one million users, and addressing it is a central item in @sec-future-performance. A more detailed breakdown of memory consumption is provided in @apx-performance-space.

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

== Execution Pipeline 
<sec-exec-pipeline>

Explain the `construct-cascades` and `dataset-creation` repositories, and the 9 datasets that get outputed (are the same that the first summer bitacola) and then provide an appendix going in depth in each one of them

#comment[Here we could (should?) ]


