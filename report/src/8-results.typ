#import "utils.typ": todo, comment, def, flex-caption

This chapter presents the empirical evaluation of the Continuous-Time Independent Cascade (CTIC) model. 

== Execution
<sec-results-execution>

This section describes the parameters and configuration of the execution of the simulation. @tbl-res-config describes all the parameters (@sec-model) and the value used for the run (@sec-calibration).

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Parameter*], [*Value*], [*Source*],
    table.hline(stroke: 0.5pt),
    [`session_duration`], [1 of 16 fitted pairs, per-user empirical parameters], [@sec-cal-dist],
    [`inter_session_time`], [Same 16-pair table as `session_duration`], [@sec-cal-dist],
    [`inter_creation_time`], [ECDF of within-session post gaps], [@sec-cal-interpost],
    [`offset_creation_time`], [ECDF of within-session post offset], [@sec-cal-interpost],
    [`user_inter_action`], [$lambda = 1/3$ (mean 3 s)], [@sec-cal-interaction],
    [`user_policy`], [Weights $[0.915, 0.073, 0.012]$ on `ignore`, `like`, `repost`], [@sec-cal-policy],
    [`propagation_delay`], [1 s], [@sec-model-incubation],
    [`interaction_delay`], [1 s], [@sec-method-des-assumptions],
    [`creation_delay`], [1 s], [@sec-method-des-assumptions],
    [`offline_startup_ratio`], [0.5], [@sec-cal-warmup],
    [`warmup_time`], [2,000 ticks], [@sec-cal-warmup],
    [`horizon`], [42,000 ticks], [@sec-exec-stationary],
    [`duration`], [40,000 ticks], [@sec-exec-stationary],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Simulation configuration],
    [Recap of the final simulation parameters, used in the reported execution.],
  )
) <tbl-res-config>

@tbl-res-finalbatch describes which datasets the simulation has run on, the parallelism used (workers), and how many replications per dataset were performed (no more than 100, as it yields diminishing returns precision-wise --- with the configuration described in @tbl-res-config).

#figure(
  table(
    columns: 3,
    align: (center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Dataset*], [*runs*], [*workers*],
    table.hline(stroke: 0.5pt),
    [10K], [100], [16], 
    [50K#footnote[Added for scalability analysis purposes, but not analyzed in depth]], [100], [16], 
    [100K], [100], [12], 
    [500K], [100], [2], 
    [1M], [91#footnote[Eight runs were excluded from the analysis.]], [1], 
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Workers, runs and batches of execution.],
    [Final runs and workers of every dataset.],
  )
) <tbl-res-finalbatch>


== Scalability <sec-res-scalability>

Regarding performance, this section describes the growth of the simulation according to input value both in time and in memory. Check @apx-hardware for a detailed specification of the hardware this was ran on and @apx-method-exec for how the showcased data has been obtained.
 
@fig-res-time-scalability shows the scalability of the simulation by regressing over the data points in logarithmic scale. Taking into account all 5 datasets, the simulation has a slightly superlinear time growth of $O(n^1.31)$; this is the primary fit. Fitting only the bigger datasets (100K, 500K and 1M) gives an almost linear $O(n^0.98)$, but with only three points that fit is a rough cross-check rather than a rigorous result. @tbl-res-time summarizes the execution time per run across datasets, with the 95% confidence interval of the mean, as well as giving the specific values of the plot.


#figure(
  image("../images/results/time_scalability.svg", width: 100%),
  caption: flex-caption(
    [Simulation `cpu_thread` time versus dataset size.],
    [Simulation `cpu_thread` time per run versus topology size in logarithmic scale. The slope is the growth rate.],
  )
) <fig-res-time-scalability>

#figure(
  table(
    columns: 7,
    align: (center, center, right, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Size*], [*Runs*], [*Mean (ms)*], [*$±$CI95 (ms)*], [*Median (ms)*], [*Min (ms)*], [*Max (ms)*],
    table.hline(stroke: 0.5pt),
    [10K], [100], [2,667], [124], [2,500], [2,002], [4,458],
    [50K], [100], [34,230], [969], [32,927], [27,580], [46,842],
    [100K], [100], [119,776], [4,210], [112,288], [100,673], [180,241],
    [500K], [100], [731,821], [4,376], [732,814], [684,260], [815,866],
    [1M], [91], [1,058,691], [9,407], [1,050,362], [1,002,021], [1,340,140],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Execution time per run.],
    [Execution statistics time per run.],
  )
) <tbl-res-time>


Regarding times, we can see this scalability in more human terms: a 10K run averages about 2.7 s, 50K about 34 s, 100K about 2 min, 500K about 12 min, and 1M about 18 min.

Regarding memory growth, @fig-res-ram-per-run shows the RAM usage per run across the datasets, and 
@tbl-res-ram reports the RAM usage per run, normalized per worker, with the minimum and maximum observed to interpret the plot. It depicts a very similar picture to the time scalability: a growth of $O(n^1.32)$ over all datapoints (superlinear), and an $O(n^0.93)$ fit when restricted to the big datasets (near-linear). As with time, the all-datasets fit is the primary one and the three-point big-only fit is only a rough check.

#figure(
  image("../images/results/ram_scalability.png", width: 100%),
  caption: flex-caption(
    [RAM usage per run.],
    [RAM usage per run versus topology size.],
  )
) <fig-res-ram-per-run> 


#figure(
  table(
    columns: 5,
    align: (center, center, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Size*], [*Workers*], [*Min (GB)*], [*Median (GB)*], [*Max (GB)*],
    table.hline(stroke: 0.5pt),
    [10K], [16], [1.46], [1.46], [1.89],
    [50K], [16], [14.04], [21.70], [26.55],
    [100K], [12], [54.25], [77.38], [89.17],
    [500K], [2], [234.18], [436.77], [466.23],
    [1M], [1], [311.81], [607.22], [633.26],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [RAM usage per run.],
    [RAM usage per run, normalized per worker.],
  )
) <tbl-res-ram>

The table shows the RAM footprint per run, normalized per worker: it grows from roughly 1.5 GB at 10K to over 600 GB at 1M. These footprints already exceed consumer hardware past the 500K run, so the larger datasets are only feasible on the dedicated server described in @apx-hardware.


The decision to fit the data twice ---both for time and memory--- is a check on the asymptotic regime: the all-datasets fit is the primary result, while the big-datasets-only fit is an unrigorous cross-check, as it rests on only three points and the smaller (and sparser) networks may not lie in the same regime as the larger ones. It is reported because the larger networks are closer to real microblogging topologies, but it should not replace the all-datasets exponent.

Analyzing the bigger picture, ram and time grow at more or less the same rates, and the CPU usage never surpasses 0.2% even with the 16 or 12 workers.

This also validates that the implementation of the design (see @apx-impl) is successful in achieving reasonable execution times and resource efficiency: we are able to run an 11 hours 40 minutes simulation ---converting 42,000 ticks into hours using the conversion made explicit in
@sec-exec-agnostic --- in 18 minutes (@tbl-res-time). It is definitely a win.

== Reposts Power-law
<sec-results-powerlaw>

First metric to evaluate in the simulation is the reposts power-law, a characteristic magnitude (see @sec-method-des-metrics) that must behave as real data. In @sec-data-reposts, the data did not exactly follow a power-law but a lognormal distribution. @tbl-res-reposts reports, per dataset size, the distribution of the fitted exponent $alpha$ across runs and how many runs are actually better described by a power law according to Vuong's test.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [*Runs*], [100], [100], [100], [91],
    [*$alpha$ mean*], [2.497], [2.692], [2.706], [2.927],
    [*$alpha$ median*], [2.496], [2.909], [2.839], [2.949],
    [*$alpha$ CI95 ($±$)*], [0.003], [0.055], [0.048], [0.013],
    [*$alpha$ min*], [2.464], [2.343], [2.255], [2.541],
    [*$alpha$ max*], [2.532], [2.978], [2.857], [2.973],
    [*$x_"min"$ mean*], [1.000], [1.760], [3.140], [4.780],
    [*$x_"min"$ median*], [1.0], [2.0], [3.0], [5.0],
    [*$x_"min"$ CI95 ($±$)*], [0.000], [0.336], [1.197], [0.114],
    [*$x_"min"$ min*], [1], [1], [1], [1],
    [*$x_"min"$ max*], [1], [18], [63], [5],
    [*Power-law runs*], [0/100], [0/100], [0/100], [0/91],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Power-law fits of repost counts per run.],
    [Fitted power-law exponent $alpha$ and lower cutoff $x_"min"$ summarized across runs (mean, median, 95% confidence interval, range), per dataset size, plus the number of runs for which a power law is preferred over a lognormal (Vuong test, $p < 0.05$).],
  )
) <tbl-res-reposts>

No run is a power law: where the Vuong test is decisive it favours the lognormal, so the power-law row stays at 0/100; in two runs (one at 100K, one at 500K) the test is inconclusive rather than favouring a power law. This matches the real Bluesky data (@fig-data-reposts-hist), where $alpha = 2.053$ and the lognormal also wins decisively ($p = 1.18 dot 10^(-63)$, see @sec-data-reposts). The simulated exponents are higher ($approx 2.5$–$2.9$ vs. $2.05$), and the large gap between mean and median at 100K and 500K reflects a bimodal fit ---the `x_min` selection oscillates between two regimes--- rather than a clean single exponent. @fig-res-powerlaw-comp showcases them graphically: the two tails share the Bluesky $x_"min" = 12$ so that the only difference is the exponent, and the simulated tail decays markedly faster, with fewer of the highly reposted posts than the real data.

#figure(
  image("../images/results/powerlaw_alpha_comparison.svg", width: 100%),
  caption: flex-caption(
    [Synthetic power-law comparison of $alpha=2.05$ (Bluesky) _v.s._ $alpha=2.9$ (simulation). ],
    [Synthetic power-law tails with the Bluesky exponent ($alpha = 2.05$) and the representative simulated exponent ($alpha = 2.9$), both sharing the Bluesky lower cutoff $x_"min" = 12$. Left: CCDF on log-log axes. Right: density on linear axes.],
  )
) <fig-res-powerlaw-comp>

== Cascade Metrics
<sec-results-cascade-metrics>

We now turn to the shape of the cascades the simulation produces, using the size, depth and width definitions of @sec-method-des-metrics. Almost no post ever becomes a cascade. Across the four datasets between 92.2% and 93.4% of all posts receive no repost at all (`CascadeSize` = 1), leaving only 6.6%–7.8% that form a non-trivial cascade (at least one repost). This is roughly half the rate observed in the real Bluesky data (16.32% in @sec-data-cascade-shape), consistent with the calibrated 1.2% repost weight of the user policy. @tbl-res-cascade-stats summarises the tree-level metrics of these cascades: the typical cascade is tiny and shallow (median size 2, median depth 1) in every dataset, but the heavy tail grows with the network, from a maximum of $32$ nodes at 10K up to $1,697$ nodes at 1M, with a maximum out-degree of $1,599$.

The $±$ values are the 95% confidence interval of the mean across runs, the run being the unit of observation: cascades within a run share the same topology and user population and are not independent, so the interval is taken over the run-level means rather than over the cascades. @fig-res-cascade-shape shows the shape behind these numbers: as in the empirical data (@fig-data-cascade-shape), size and maximum out-degree decay in near lockstep while depth stays an order of magnitude lower.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*Stat*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    table.cell(rowspan: 4)[*Size*], [mean], [2.54], [2.70], [2.92], [2.97],
    [95% CI ($±$)], [0.0021], [0.0010], [0.0008], [0.0067],
    [median], [2], [2], [2], [2],
    [max], [32], [174], [779], [1,697],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 4)[*Depth*], [mean], [1.26], [1.27], [1.25], [1.24],
    [95% CI ($±$)], [0.0010], [0.0003], [0.0001], [0.0018],
    [median], [1], [1], [1], [1],
    [max], [10], [12], [13], [13],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 4)[*Max out-degree*], [mean], [1.26], [1.38], [1.59], [1.65],
    [95% CI ($±$)], [0.0014], [0.0007], [0.0007], [0.0040],
    [median], [1], [1], [1], [1],
    [max], [28], [161], [726], [1,599],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 4)[*$nu(T)$*], [mean], [1.157], [1.187], [1.205], [1.198],
    [95% CI ($±$)], [0.0005], [0.0002], [0.0001], [0.0013],
    [median], [1.0], [1.0], [1.0], [1.0],
    [max], [4.69], [5.64], [6.08], [6.25],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Cascade-level statistics per dataset.],
    [Tree metrics for the cascades with at least one repost, pooled over all runs. The $±$ row is the 95% confidence interval of the mean across runs (unit of observation = the run, since cascades within a run are not independent).],
  )
) <tbl-res-cascade-stats>

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    image("../images/results/cascade_shape_ranksize_10K.svg", width: 100%),
    image("../images/results/cascade_shape_ranksize_100K.svg", width: 100%),
    image("../images/results/cascade_shape_ranksize_500K.svg", width: 100%),
    image("../images/results/cascade_shape_ranksize_1M.svg", width: 100%),
  ),
  caption: flex-caption(
    [Cascade shape per dataset.],
    [The three tree metrics sorted largest to smallest for the non-trivial cascades of each dataset, log-log axes. As in the empirical data (@fig-data-cascade-shape), size and maximum out-degree decay in near lockstep while depth stays an order of magnitude lower.],
  )
) <fig-res-cascade-shape>

== Structural Virality
<sec-results-sv>

Structural virality $nu(T)$ @goel2016structural captures the macro-level shape of the repost propagation tree, distinguishing *broadcast* diffusion (one-to-many) from *viral* spread (person-to-person chains). As with the repost power law, the cascades are pooled across all runs of each dataset: the per-run mean $nu(T)$ spans at most $0.012$ within a dataset, so the pooled distribution is representative, while the confidence interval below is taken across runs (the run being the unit of observation), since cascades within a run are not independent.

For the viral cascades alone, $nu(T)$ stays shallow: the mean is $1.585$ at 10K and rises gently to $1.716$ at 1M, with a median of $1.5$–$1.667$ and a maximum of $4.7$–$6.3$ (@tbl-res-viral-sv). @fig-res-nu-density shows the distributions: all four are concentrated just above the minimum $nu = 4/3$ (a single repost-of-repost) and decay quickly, so they sit *below* the broadcast floor $nu = 2$ — the simulated "viral" cascades are barely more viral than a large star. This is where the simulation diverges most from the data: real viral cascades have mean $2.142$, median $2.000$ and a tail reaching $50.27$ (@sec-data-virality), with a median that sits exactly at the broadcast floor. The simulation produces too few long repost-of-repost chains to lift its mean or median past it, and the shortfall is largest at the smallest network and narrows monotonically with size (mean gap $0.557$ at 10K, $0.501$ at 100K, $0.438$ at 500K, $0.426$ at 1M).

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*$nu(T)$ (viral)*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Mean], [1.585], [1.641], [1.704], [1.716],
    [95% CI ($±$)], [0.0011], [0.0003], [0.0002], [0.0013],
    [Median], [1.500], [1.667], [1.667], [1.667],
    [Min], [1.333], [1.333], [1.333], [1.333],
    [Max], [4.69], [5.64], [6.08], [6.25],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Structural virality of viral cascades per dataset.],
    [Mean (with the 95% confidence interval of the mean across runs), median, minimum and maximum of $nu(T)$ over the viral cascades (depth ≥ 2), pooled over all runs.],
  )
) <tbl-res-viral-sv>

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    image("../images/results/viral_nu_density_10K.svg", width: 100%),
    image("../images/results/viral_nu_density_100K.svg", width: 100%),
    image("../images/results/viral_nu_density_500K.svg", width: 100%),
    image("../images/results/viral_nu_density_1M.svg", width: 100%),
  ),
  caption: flex-caption(
    [Structural virality of viral cascades.],
    [Log-$x$ density of $nu(T)$ for the viral cascades (depth ≥ 2) in each dataset, with the broadcast floor $nu = 2$ (dashed) and the median (dotted) marked.],
  )
) <fig-res-nu-density>


Following Goel et al. @goel2016structural, the cascades split into *broadcast* (depth 1: a star, every repost hangs directly off the root) and *viral* (depth ≥ 2: at least one repost-of-repost). Broadcast diffusion dominates everywhere: 79.4%–81.6% of cascades are broadcasts and only 18.4%–20.6% are viral (@tbl-res-broadcast), a slightly stronger broadcast bias than the real data (71.05% broadcast). The split is flat across the four sizes, so the broadcast/viral balance does not depend on the network size.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Dataset*], [*Total*], [*Broadcast*], [*Broadcast %*], [*Viral*], [*Viral %*],
    table.hline(stroke: 0.5pt),
    [10K], [1.758e6], [1.408e6], [80.1%], [3.502e5], [19.9%],
    [100K], [1.961e7], [1.557e7], [79.4%], [4.044e6], [20.6%],
    [500K], [9.399e7], [7.549e7], [80.3%], [1.850e7], [19.7%],
    [1M], [1.504e8], [1.228e8], [81.6%], [2.762e7], [18.4%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Broadcast vs. viral cascades per dataset.],
    [Split of the non-trivial cascades into broadcast (depth 1) and viral (depth ≥ 2), pooled over all runs. Counts in scientific notation, with each category's share of the total.],
  )
) <tbl-res-broadcast>



== Comparison with Bluesky Data <sec-results-comparison>

With all the metrics analyzed in both fronts, the comparison of real vs simulated data can be done.
@tbl-res-vs-data contrasts the key metrics: the Bluesky values against each of the four simulated datasets (pooled over all runs).

#figure(
  {
    set text(size: 9pt)
    table(
      columns: 7,
      align: (left, left, center, center, center, center, center),
      stroke: none,
      table.hline(stroke: 0.8pt),
      [*Metric*], [*Stat*], [*Bluesky data*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Cascades ≥ 1 repost], [—], [16.32%], table.cell(colspan: 4)[6.6–7.8%],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Size*], [mean], [9.18], [2.54], [2.70], [2.92], [2.97],
    [median], [3], [2], [2], [2], [2],
    [max], [12,720], [32], [174], [779], [1,697],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Depth*], [mean], [1.50], [1.26], [1.27], [1.25], [1.24],
    [median], [1], [1], [1], [1], [1],
    [max], [131], [10], [12], [13], [13],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Max out-degree*], [mean], [5.82], [1.26], [1.38], [1.59], [1.65],
    [median], [2], [1], [1], [1], [1],
    [max], [7,768], [28], [161], [726], [1,599],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*$nu(T)$*], [mean], [1.454], [1.157], [1.187], [1.205], [1.198],
    [median], [1.333], [1.0], [1.0], [1.0], [1.0],
    [max], [50.27], [4.69], [5.64], [6.08], [6.25],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Viral $nu(T)$*], [mean], [2.142], [1.585], [1.641], [1.704], [1.716],
    [median], [2.000], [1.500], [1.667], [1.667], [1.667],
    [max], [50.269], [4.69], [5.64], [6.08], [6.25],
    table.hline(stroke: 0.3pt),
    [Broadcast cascades], [—], [71.05%], [80.1%], [79.4%], [80.3%], [81.6%],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Repost exponent $alpha$*], [mean], [2.053], [2.497], [2.692], [2.706], [2.927],
    [min], [—], [2.464], [2.343], [2.255], [2.541],
    [max], [—], [2.532], [2.978], [2.857], [2.973],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Repost cutoff $x_"min"$*], [mean], [12], [1.0], [1.76], [3.14], [4.78],
    [min], [—], [1], [1], [1], [1],
      [max], [—], [1], [18], [63], [5],
      table.hline(stroke: 0.8pt),
    )
  },
  caption: flex-caption(
    [Key metrics comparison: empirical data vs. simulation results],
    [Bluesky values from @sec-data-reposts, @sec-data-cascade-shape and @sec-data-virality against each of the four simulated datasets (pooled over runs). The verdicts are discussed below.],
  )
) <tbl-res-vs-data>

#figure(
  image("../images/results/overlap_empirical_sim.svg", width: 78%),
  caption: flex-caption(
    [Cascade size tail: empirical vs. simulation.],
    [Complementary cumulative distribution of cascade size (nodes, root included) on log-log axes, comparing the Bluesky data against the four simulated datasets (pooled over runs). The simulation lies below the empirical distribution at every size and truncates its heavy tail.],
  )
) <fig-res-overlap>

#figure(
  image("../images/results/overlap_depth_empirical_sim.svg", width: 78%),
  caption: flex-caption(
    [Cascade depth tail: empirical vs. simulation.],
    [Complementary cumulative distribution of cascade depth on log-log axes, comparing the Bluesky data against the four simulated datasets (pooled over runs), non-trivial cascades only. The simulation is below the data across the bulk and dies by depth $13$, while the empirical tail reaches $131$.],
  )
) <fig-res-overlap-depth>

#figure(
  image("../images/results/overlap_width_empirical_sim.svg", width: 78%),
  caption: flex-caption(
    [Cascade width tail: empirical vs. simulation.],
    [Complementary cumulative distribution of the maximum out-degree on log-log axes, comparing the Bluesky data against the four simulated datasets (pooled over runs), non-trivial cascades only. The simulation truncates the width tail at $1,599$ against the empirical $7,768$.],
  )
) <fig-res-overlap-width>

#figure(
  image("../images/results/viral_nu_overlap.svg", width: 78%),
  caption: flex-caption(
    [Structural virality of viral cascades: empirical vs. simulation.],
    [Log-$x$ density of $nu(T)$ for the viral cascades (depth ≥ 2), comparing the Bluesky data (black) against the four simulated datasets (pooled over runs). The simulated cascades peak at the minimum $nu = 4/3$ and decay before the broadcast floor $nu = 2$, while the empirical distribution is bimodal ---a mode just above the minimum $nu = 4/3$ and a near-tied one just above the broadcast floor $nu = 2$--- and carries a heavy tail out to $50$.],
  )
) <fig-res-nu-overlap>

The following points sum up the main differences between real data and the simulation:
+ *Cascade rate.* The simulation produces roughly half the real share of non-trivial cascades (6.6–7.8% vs. 16.32%), consistent with the calibrated 1.2% repost weight but also with fewer impressions per post.
+ *Size.* The median is off by one (2 vs. 3) and the whole distribution is shifted down; the tail is ~7.5× shorter (max 1,697 vs. 12,720).
+ *Depth.* The median matches (1); the tail is ~10× shorter (13 vs. 131) — the simulation caps depth at 13.
+ *Max out-degree.* Median off by one (1 vs. 2); tail ~5× shorter (1,599 vs. 7,768).
+ *$nu(T)$.* The sim is too shallow: mean 1.16–1.21 vs. 1.454, max 6.25 vs. 50.27.
+ *Viral $nu(T)$.* simulated viral cascades have both their mean and median below the broadcast floor (mean 1.585–1.716, median 1.5–1.667), while real ones average 2.142 with a median of exactly 2.000; $311$ real cascades (0.04% of viral) exceed $nu = 10$, which the sim never reaches.
+ *Broadcast share.* The sim is more broadcast-shaped (79.4–81.6% vs. 71.05%).
+ *Reposts.* Lognormal preferred in both and never a power law in the simulation, but the simulated exponent ($2.5$–$2.9$) decays faster than the real $2.053$, with a much lower cutoff ($x_"min" approx 1$–$5$ vs. $12$), consistent with the missing deep cascades.

The simulation does not match the empirical magnitudes, and the shortfall is not only in the tail. Size and width are *under-estimated* at every level: the means are 2.54–2.97 against 9.18 for size (bullet 2) and 1.26–1.65 against 5.82 for max out-degree (bullet 4), and the medians already sit below the data (size 2 vs. 3; width 1 vs. 2). Depth follows the same direction in the mean (1.24–1.27 vs. 1.50; bullet 3), although its median is the one quantity that matches (1 vs. 1). The broadcast share is skewed the same way, 79.4–81.6% against 71.05% (bullet 7). Structural virality is the clearest qualitative mismatch: the simulation over-produces the non-viral (broadcast) regime and under-produces the viral one, so the viral $nu(T)$ mean stays below the empirical mean (1.585–1.716 vs. 2.142; bullets 5–6); that gap is largest at 10K and shrinks monotonically as the network grows. On top of this, the simulation generates fewer than half the empirical cascades (6.6–7.8% vs. 16.32%; bullet 1).

*Conclusions*: The model reproduces the *shape class* of the empirical cascades ---tiny, shallow, broadcast-dominated trees--- but not their bulk: every size and width magnitude, and the mean depth, is below the data, and the broadcast/viral balance is shifted away from viral. The departure is systematic and, in the heavy tail, it becomes a hard truncation.

The truncation is not one failure but three caps on the diffusion tree: a content-free policy makes every cascade subcritical and caps the first-hop conversion (depth, size and width), an active-only calibration inflates the arrival rate onto every timeline (width), and reach stops at the follower graph (width). The timeline order, the obvious suspect, is tested and rejected. @sec-finding-missing-tail derives each cap in turn.

== Finding the Missing Tail
<sec-finding-missing-tail>

The comparison in @sec-results-comparison are clear: despite having appropiate shapes,the simulation is under-reproducing the empirical cascades on every axis: fewer non-trivial cascades, a smaller mean and median size, a shallower depth, a narrower width and a broadcast/viral mix shifted away from viral. It is considered that the explanation must not be a single point of failure but three independent caps on the diffusion tree, plus a fourth candidate that is tested and rejected.

=== Content-Agnositcity Makes Cascades Subcritical

This is the most fundamental cap, and the only one whose mathematics is exact. It is a property of the model: because posts carry no content, every reposter draws from the same policy, which makes each cascade a subcritical branching process.

==== Cascades as Galton–Watson Processes

Let us first define what a Galton–Watson process is. Consider a simple stochastic model for how a population grows in size, ${Z_n}_(n in NN)$.

Assumptions:
+ The population grows in generations: $forall k in ZZ^+$, let $Z_k$ denote the number of members in the $k$-th generation.
+ Each member of the $k$-th generation gives birth to a family (possibly empty) of members of the $(k+1)$-th generation.
+ The number of descendants of a given individual is $X$, where $PP(X = i) = p_i$.
+ The families form a collection of independent random variables, each distributed as $X$.

#def(name: "Galton-Watson process")[
  Condensing all the assumptions into one, a Galton–Watson process is the stochastic process defined by the recursion
  $
    Z_(k+1) = sum_(i=1)^(Z_k) X_i^((k)),
  $
  where $X_i^((k))$ are independent and identically distributed copies of $X$.
]

Let us now map the cascade concepts to these assumptions. A cascade is a stochastic process ${Z_n}_(n in NN)$ whose population is the set of users that have *reposted* the post, arranged in generations: $Z_k$ are the reposters at depth $k$ of the cascade tree. A generation can be empty (a user does not repost, so the cascade does not expand from that node). Because the policy $pi$ is fixed and homogeneous across users, and posts carry no content, every reposter draws its number of children from the same distribution --- the homogeneous assumption of @sec-method-des-assumptions. The families are not strictly independent: nodes in different cascades compete for the same followers' timelines (@sec-model-ctic), so this is a mean-field reading. What the argument needs is that the *mean* offspring is fixed and below one, which the traces confirm (@tbl-res-r0); under that reading the tail bound holds exactly, and the simulation reproduces it.

Once a cascade is a Galton–Watson process, its long-run behaviour is known without costly simulations, governed entirely by the reproduction number $R_0$.

#def(name: "Reproduction Number")[
  The reproduction number is defined as $R_0 := EE(X)$. The Galton–Watson process is classified by its value:
  - $R_0 < 1$: *subcritical* --- the population dies out with probability 1, and its size has an exponentially bounded tail.
  - $R_0 = 1$: *critical* --- the population dies out with probability 1, but the extinction time and size are heavy-tailed.
  - $R_0 > 1$: *supercritical* --- the population survives with probability $1 - d > 0$, where $d$ is the probability of ultimate extinction.
]

We can compute $R_0$ from the simulation traces, which are the contents of @tbl-res-r0. It is $approx 0.22$ on the datasets where it was estimated, while the mean seed (direct reposts of the root) is $approx 1.2$–$1.3$. Since $R_0 < 1$, the process is subcritical: every repost replaces itself with less than one further repost, the cascade goes extinct after a few generations, and the size distribution is exponentially bounded. A heavy tail is mathematically impossible at a fixed $R_0 < 1$, regardless of the topology; what the over-active composition of @sec-missing-width can move is how far below one the process sits, not whether it is subcritical.

#figure(
  table(
    columns: 3,
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Quantity*], [*10K*], [*100K*],
    table.hline(stroke: 0.5pt),
    [$R_0$ (mean offspring per repost)], [0.213], [0.223],
    [Mean seed (root children)], [1.214], [1.321],
    [Mean cascade size], [2.54], [2.70],
    [Zero-offspring reposts], [82.6%], [83.2%],
    [Repost-of-reposts (depth $>= 2$)], [21.3%], [22.3%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Empirical reproduction number $R_0$ of the simulated cascades.],
    [$R_0$ (mean offspring per reposting node) and the mean seed (direct reposts of the root), estimated from the cascade trees, together with the cascade-size mean and the share of zero-offspring reposts. Estimated on 10K and 100K.],
  )
) <tbl-res-r0>

@fig-res-offspring shows the offspring distribution $Z$: roughly 83% of reposts generate no further repost, and the mean sits far below one. This is why the size and depth tails are truncated in every dataset: for a fixed homogeneous policy the tail is exponentially bounded at any $R_0 < 1$, so no topology can lift it. How far below criticality the process sits, however, also depends on the calibrated population (see @sec-missing-width): the over-active composition depresses $R_0$ further, so $0.22$ measures the severity of the cap under this calibration, while its existence is a property of the model.

#figure(
  image("../images/results/offspring_distribution_100K.svg", width: 100%),
  caption: flex-caption(
    [Offspring distribution of reposts (100K).],
    [Number of children per reposting node in the 100K dataset. The dashed line marks the critical boundary $R_0 = 1$; the red line is the empirical mean $R_0 approx 0.22$. The overwhelming mass is at zero, and the mean is far below criticality.],
  )
) <fig-res-offspring>

==== Content as a Fix Hypothesis

This section presents the intuition behind why adding content would make the simulation recreate the heavy tail more like real data without coding another full simulation ---as to add content would be an enormous work effort and is delegated to Future Work (see @sec-future)--- with the known knowledge of the stochastic process a cascade represents.

// The argument below is the first-moment version; the full derivation, including the exact tail exponent, is in @apx-branching.

Consider two regimes that share the same *average* reproduction number $R_0$:

+ *Homogeneous (current model).* Every post shares the same reproduction number $m = R_0 < 1$, so the cascade is a subcritical Galton–Watson process. We say that this model has *randomness at a node level*: the cascade growth depends only of the policy $pi$, applied in a per user basis when they perfom an action over a post. For a fixed $m < 1$ the expected size is finite and the size distribution has an exponentially bounded tail @athreya1972branching.
+ *Heterogeneous (content).* This model emulates the post having a latent quality by drawing its own reproduction number $m ~ F$ with $EE(m) = R_0$. Now the overall cascade size distribution is now a mixture model: an aggregation of thousands of subcritical branching processes. This model has shifted the *randomness to the post level*.

Homogeneous model (as seen in the previous section) we know it does not generate a heavy tail as it's a GW process with a $R_0 approx 0.22$, assumed the same per cascade as posts do not have content. The heterogeneous model in contrast can write the expected cascade for any fixed post with a fixed subcritical $m$ as a finite quantity with

$
  EE(S | m) = frac(1, 1 - m),
$

With this quantity, using the Law of Total Expectation, we can find the expected cascade size in all the platform, which can be seen as the same of taking into account all the existing post qualities given by $F$.

$
  EE(S) = integral_0^1 frac(1, 1 - m) d F(m).
$ <eq-exp-s>

By analyzing the convergence <eq-exp-s> we can see the heterogeneous model will generate a heavy tail.
+ If the support of $F$ is bounded away from $1^-$ (_i.e_ $m <= c <= 1$ where $c$ is far away enough from $1^-$) then the integral will converge and $E(S) < inf$, implying the tail will remain exponentially bounded.
+ However, if the support of $F$ lets $m -> 1^-$ arbitrarely (_i.e._ a small fraction of posts are near critical, so good they become viral), the integral will diverge, therefore $E(S)= inf$.

The divergence of the mean of $S$ proves that the tail will not be exponentially bounded ---like an exponential distribution--- but a heavy-tail behaviour ---such a power-law or lognormal distribution--- where rare but enormous cascades will dominate the expected value.

Therefore, while mantaining the same size average $R_0$, the introduction of post-level randomness, where a node can take a different action according to the post is acting upon, can transform the exponential tail of the homogeneous model (@sec-method-des-assumptions) into a heavy-tail seen in the empirical data. How to achive this efficiently and in scope is explained in @sec-future-content  

=== Missing Inactive Users
<sec-missing-width>

The second symptom is the width: the maximum out-degree of a simulated cascade is about five times smaller than the empirical one ($1,599$ against $7,768$), and the gap is not confined to the tail --- the whole out-degree distribution lies below the empirical one. The width of a cascade is the first hop, the direct reposts of the root, so it is set by the author's follower count and by how many of those followers read the post and convert.

The width is set by the influx rate $mu_v$ of @sec-model-rate. Recall that the model defined $mu_v$ as the expected number of posts arriving per unit of time in $v$'s timeline, aggregated over the creation and repost activity of $v$'s followees, and deliberately left it without a closed form: it is an output of the system, not a parameter. Here the results estimate it directly, and it is the strongest of the three width caps ---the only one that is a calibration artefact rather than a property of the model.

Let us give an intuition of why this problem is real and how to solve it. Out-degree can be factorized into an impression and a conversion term,

$ "out-degree" = "impressions" times "repost rate", quad EE("out-degree") = F times p_"read" times pi_"repost", $

with $F$ the author's follower count, $p_"read"$ the probability that a given follower ever reads the post, and $pi_"repost" = 1.2%$ from @sec-cal-policy. Calibration fixes $pi$ and the topology fixes $F$, so the value $p_"read"$ is what we can study to detect the behaviour. Delivery can be ruled out: `propagate` inserts the post into every follower's timeline (@proc-propagate), so the loss is entirely in consumption. For a follower $v$, the chance that one specific post is read is the ratio of what $v$ consumes to what arrives,

$ p_"read" approx frac(EE[D_"action"]^(-1), mu_v) $

where $EE[D_"action"]^(-1)$ is the number of posts $v$ reads per unit time (one post every $3$ seconds during a session, @sec-cal-interaction) and $mu_v$ is the influx rate onto $v$'s timeline (@def-influxrate in @sec-model-rate), i.e. the sum of the creation and repost rates of every followee of $v$. The two terms come from different populations: the reading rate is a property of $v$ alone, while $mu_v$ is set by $v$'s followees.

A model that has much more influx rate in $mu_v$ cannot reproduce the width, no matter how it orders the timeline ---the ordering only changes which post consumes the available reads, not their number (this is what @fig-queue-width proves, as it compares the normal simulation with the random timeline expermient explained in a future section @sec-queue-attention).

To find out the probablility of reading a post $i$ $p_"read"$ we can use the information available to estimate the *average influx rate $mu$*.

$ bar(mu)_"sim" approx 1.7 times 10^4 "versus" bar(mu) approx 338 $

The simulated influx is $7.2 times 10^4$ posts per timeline per day, against $approx 338$ on the empirical firehose--- roughly two orders of magnitude larger.

This checks that the users of our simulation are heavily overactive. The reason behind that is that the session and gap distributions *are fitted only on the active tail of the data* (as mencioned in @sec-cal-sessions) ---the $243$K users ($18%$) with at least $30$ sessions, and the within-session creation ECDF on the $65$K users with at least $30$ gaps--- and every simulated user then samples its activity from that table (@sec-cal-acrossuser).

As the inactive majority is absent, every followee posts like a heavy poster, and $mu_v$ is systematically larger than on a real timeline, where most followees are near-silent. With the reading rate $EE[D_"action"]^(-1)$ fixed by @sec-cal-interaction, a larger $mu_v$ depresses $p_"read"$ and truncates the first hop. The same composition also depresses $R_0$ (@tbl-res-r0), so it is consistent with the depth cap as well.
 
==== Collapse of the Impression Term
<sec-width-reach>

To see where the width is lost, the first-hop size is measured against the author's true follower count. As the factorisation above shows, the loss sits in the impression term $p_"read"$, because every follower's timeline receives the post. For broadcast cascades (depth $1$) the maximum out-degree is the number of direct reposts of the root, so this isolates the impression term cleanly. The measurement is done for the 500K and 1M datasets, bucketed by the author's in-degree (taken from the topology binary the simulator consumed, see @apx-impl-topology).

#figure(
  image("../images/results/width_vs_followers.svg", width: 100%),
  caption: flex-caption(
    [Cascade size and reach versus author follower count.],
    [Mean cascade size (left) and probability of reaching at least $50$ reposts (right) as a function of the author's follower count, 500K and 1M datasets. The follower buckets are log-spaced and the vertical axis is logarithmic; the near-flat response below the top bucket is the collapse of $p_"read"$ under the inflated influx rate.],
  )
) <fig-queue-width>

The relationship is monotone, so reach does grow with followers, but far too slowly. An author with fewer than ten followers and one with a hundred thousand are separated by four orders of magnitude of degree, yet the typical cascade moves only from $1.0$ to $2.8$; the jump to $174$ happens only in the top bucket, which at 500K contains a single hub with $211,726$ followers. Normalised per follower, the conversion collapses as degree grows: the hub's $174$ reposts are roughly $0.08%$ of its followers, against the $1.2%$ the policy allows, so $p_"read"$ for its posts is only $approx 6.8%$ even though the post reaches every one of those timelines. That collapse is the missing width, and it is the direct signature of the inflated $mu_v$. The tail is equally concentrated: $73%$ of the giant hub's posts reach $50$ reposts, against $0.03%$ for the $10$k--$100$k authors and essentially zero below $1$k. The simulated cascade sample is therefore the giant hub plus a thin mid-tier. At 1M the same pattern repeats with a $407,981$-follower hub: mean size $194.4$, with $54%$ of its posts reaching $50$ reposts.

The fix is a calibration change, not a new mechanism: representing the inactive majority explicitly lowers $mu_v$ and restores part of the width.

=== Reach is Tightly Bounded

The third checkable cap is *reach*: the users a post is delivered to at all. Width missing is relate with the post first hop ---the direct reposts of the root--- and for the broadcast cascades that dominate the distribution the widest node is the root, so the width is set by the audience the post reaches and the share of that audience that reposts, which are the followers of the user, as `propagate` inserts a post only into the timelines of the poster's followers (@proc-propagate in @sec-design), and a reposter only into the timelines of *their* followers. Every impression therefore travels along a follow edge, which fixes the audience of the root at exactly its in-degree.

Let's compute how many followers can a post reach. The first hop can be bounded by the audience times the conversion,

$ "out-degree" <= F times p_"read" times pi_"repost" <= F dot pi_"repost", $

with $F = |cal(N)_"in" (u)|$ the author's follower count and $pi_"repost" = 0.012$ the calibrated policy (@sec-cal-policy). The second inequality is the ceiling a perfectly-read post reaches, which is one.

As an example in the 1M topology the largest network hub has $407,981$ followers, so a post of its author will reach at most that many users, and yields at most $0.012 times 407,981 approx 4,900$ direct reposts, assuming every follower reads it. The simulation reaches up to $1,599$ (the distance to the ceiling is the arrival-rate cap of @sec-missing-width, since only a fraction of the audience reads), while the widest empirical cascade has $7,768$ direct reposts.

The ceiling therefore sits a factor $approx 1.6$ below the empirical width, and that factor cannot be supplied by any delivery over the follower graph. By constuction of the simulation, the cascades cannot get as big as its needed, even assuming every user in the cascade will see the post.

Possible solutions of this problem would be
1. Content addition: this would change the repost probablity of good posts to higher than $0.012$, which would in turn make the bound closer to the empirical one.
2. Like usage: the construction of the cascades is just considering `via` as repost, which might truncate seeing a liked post in your feed, which is a possibilty. This would augment expouse, making the bound higer.
3. Out-of-followers recomendations: this is making the $mu_v$ higher, as if we could ampliate the cascade to other parts of the graph that is not connected, it would be exposing it to far more people.

Two caveats bound the comparison. The empirical cascades come from the full six-day firehose graph, whereas the simulated ones run on a forest-fire sample of a $14$-month topology, so the author of the real $7,768$ cascade need not exist in the sample and the $approx 1.6$ factor is a lower bound. And the trace records the parent of each repost, not how many followers actually saw the post, so $p_"read"$ is inferred from the in-degree ceiling instead of observed; the simulation could be easily adapted to output this information.

=== Post Stacking is not the Problem 
<sec-queue-attention>

The compression above has an obvious suspect: the reverse-chronological timeline as the queue-based mechanic of the model. A LIFO timeline buries a post under whatever arrives after it, so its $p_"read"$ could collapse long before the topology matters, and with the overactive users the simulation has was a primordial suspect.

To rule this option out, a small experiment with the simulation has been conducted. With the same topology, the seed, the calibrated parameters and the runs of @tbl-res-finalbatch fixed, we change $cal(T)_t (u)$ from a LIFO stack to a uniform random draw from all posts the user has not seen so far. Under the random drain an old post has the same probability of being read as a fresh one ---the cheapest possible proxy for a recommender's re-ranking, with no content and no out-of-network exposure, only a different order over the same background timeline. The full random-timeline build ---@sec-results-powerlaw, @sec-results-sv and @tbl-res-vs-data recomputed--- is reported in @apx-random-timeline.

Changing the drain moves nothing toward the data. Randomising raises the share of posts that get at least one repost, but lowers the mean size, the mean out-degree and $nu(T)$, and pushes the broadcast share about two points further from the empirical $71.05%$ (@tbl-res-vs-data); the only thing that grows is the extreme tail, by $10$--$20%$ against the factor of $approx 5$ that separates the simulation from the data. The *order is an allocation of the fixed attention budget* --- it decides which post gets the reads, not how many there are --- so it is not one of the caps.

=== How to Find the Missing Tail
<sec-width-cause>

We have proposed diverse possibilites of problems, and now we are going to address which possible solutions we consider could be the most appropiate.

*First - Content Aware Posts*: every post shares the same $pi_"repost"$, so none can convert above the baseline and even a perfect impression budget caps the first hop at $F dot 1.2%$. By adding content, we could let a good post convert above baseline is exactly what post-level randomness buys, and it is delegated to @sec-future-content.

*Second - Arrival rate* representing the inactive majority explicitly would lower $mu_v$ and restore part of the width, and, because the same composition also depresses $R_0$, it would raise the reproduction number with it.

*Third - Adding Reach*: propagate procedure (@proc-propagate in @sec-design-sources-propagate) runs only over follow edges, so the first hop is bounded by the author's follower count times the conversion; it is lifted by an impression channel wider than the follow graph or by a content-aware conversion. This does not _necessarily_ imply that a Reverse-Chronological Timeline is unable to generate this, but that and exploration mechanism should be explored.

Two measurement caveats bound how far any of this can be pushed. First, the comparison is not like-for-like: the empirical cascades come from the full six-day firehose graph, whereas the simulated ones run on a forest-fire sample of a $14$-month topology, so the author of the real $7,768$ cascade need not exist in the sample and part of the apparent gap may be a sampling artefact, this could be fixed with a more purposely build graph sampler.

Second, the trace records the parent of each repost, not how many followers actually saw the post, so $p_"read"$ is inferred from the in-degree ceiling instead of observed; the simulation could be easily adapted to output this information.

Taken together, the width is capped by an impression budget that is (i) shared with an over-active followee population, (ii) converted at a uniform baseline, and (iii) confined to the follower graph. The timeline order is not one of the caps, as it only decides which user takes the available attention budget.

// This is why the natural structural fix is a recommender rather than a better feed order (@lasser2025desire): it attacks (iii) by adding out-of-network impressions and, if quality-ranked, (ii) by letting good posts convert above baseline, while leaving the reproduction number $R_0 < 1$ of @sec-finding-missing-tail untouched. One caveat carries back to the depth section: the same over-active composition that depresses $p_"read"$ also depresses $R_0$ (@tbl-res-r0), so $0.22$ should be read as measured under this composition. The mechanism of @sec-finding-missing-tail ---homogeneous policy, hence subcritical, hence an exponentially bounded tail--- is unchanged, but a population with realistic activity would move the number.

