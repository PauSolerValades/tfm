#import "utils.typ": todo, comment, def, flex-caption

This chapter presents the empirical evaluation of the Continuous-Time Independent Cascade (CTIC) model. 

== Execution
<sec-results-execution>

This section described the parameters and configuration of the execution of the simulation. @tbl-res-config describes all the parameters (@sec-model) and the value used for the run (@sec-calibration).

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Paramete*], [*Value*], [*Source*],
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
    [Recap of the final simulation parameters, used in the resported execution.],
  )
) <tbl-res-config>

@tbl-res-finalbatch describes which datasets has the simulation ran, as well as the parallelism used (workers), and how many replications for dataset have been performed (no more than 100 as it offers diminishing returns precision wise--- with the configuration described in @tbl-res-config.

#figure(
  table(
    columns: 3,
    align: (center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Dataset*], [*runs*], [*workers*],
    table.hline(stroke: 0.5pt),
    [10K], [100], [16], 
    [50K#footnote[Added for scalability analysis puroposes, but not analized in depth]], [100], [16], 
    [100K], [100], [12], 
    [500K], [100], [2], 
    [1M], [91#footnote[Eight runs were excluded from the analysis.]], [1], 
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Workers, runs and batches of execution.],
    [Final run of every dataset, workers.],
  )
) <tbl-res-finalbatch>


== Scalability <sec-res-scalability>

Regarding performance, this section describes the growth of the simulation according to input value both in time and in memory. Check @apx-hardware for a detailed specification of the hardware this was ran on and @apx-method-exec for how the showcased data has been obtained.
 
@fig-res-time-scalability shows the scalability of the simulation by regressing over the data points in logaritmic scale. Taking into account all 5 datasets, the simulation has a slightly superlinear time growth of $O(n^1.31)$, and if just taking into account the bigger datasets (100K, 500K and 1M) it shows an almost linear growth of $O(n^0.98)$. @tbl-res-time summarizes the execution time per run across datasets, with the 95% confidence interval of the mean, as well as giving the specific values of the plot.


#figure(
  image("../images/results/time_scalability.svg", width: 100%),
  caption: flex-caption(
    [Simulation wall-clock time versus dataset size.],
    [Simulation wall-clock per run versus topology size in logarithmic scale. The slope is the grow rate.],
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
@tbl-res-ram reports the RAM usage per run, normalized per worker, with the minimum and maximum observed to interpret the plot. It depicts a very similar picture to the time scalability, with a growth of $O(n^1.31)$ with all datapoints (superlinear) but a $O(n^0.98)$ with just the big datasets (linear).

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


The decision of fitting the data twice ---both for time and memory--- attempts to showcase the difference between the smaller and bigger (and denser) networks. Density wise, 10K and 50K should be considered outliers for how much smaller in comparison they are to bigger size networks. The large order fitting gives a linear growth with more complete networks that are much more representative of real life microblogging social networks.

Analyzing the bigger picture, that ram and time grow with exactly the same rates makes the case for a trivial observation steming from the simulation design: the simulation is absolutely memory bounded, with CPU usage never surpassing 0.2% of usage even with the 16 or 12 workers.

This also validates that the implementation of the design (see @apx-impl) is successfull in acheving reasonable execution times and resource efficiency: we are able to run a 11.4 hours simulation ---converting 42000 ticks into hours using the conversion explicited in
@sec-exec-agnostic --- in 18 minutes (@tbl-res-time). It is definietly a win.

== Reposts Power-law
<sec-results-powerlaw>

First metric to evaluate in the simulation is the reposts power-law, a characteristic magnitude (see @sec-method-des-metrics) that must behave as real data. In @sec-data-reposts, data did not exactly followed a power-law but a lognormal distribution. @tbl-res-reposts reports, per dataset size, the distribution of the fitted exponent $alpha$ across runs and how many runs are actually better described by a power law according to Vuong's test.

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

No run is a power law: the lognormal is preferred in every case, matching the real Bluesky data (@fig-data-reposts-hist), where $alpha = 2.053$ and the lognormal also wins decisively ($p = 1.18 dot 10^(-63)$, see @sec-data-reposts). The simulated exponents are higher ($approx 2.5$–$2.9$ vs. $2.05$), and the large gap between mean and median at 100K and 500K reflects a bimodal fit ---the `x_min` selection oscillates between two regimes--- rather than a clean single exponent. @fig-res-powerlaw-comp showcases them graphically: the two tails share the Bluesky $x_"min" = 12$ so that the only difference is the exponent, and the simulated tail decays markedly faster. The picture shows that the long tail is pretty much well simulated, but the higher reposts posts have less reposts in the simulation.

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

The $±$ values are the 95% confidence interval of the mean across runs, the run being the unit of observation: cascades within a run share the same topology and user population and are not independent, so the interval is taken over the run-level means rather than over the cascades. Pooling all cascades would give an interval roughly an order of magnitude smaller and overstate the precision. @fig-res-cascade-shape shows the shape behind these numbers: as in the empirical data (@fig-data-cascade-shape), size and maximum out-degree decay in near lockstep while depth stays an order of magnitude lower.

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

Following @goel2016structural, the cascades split into *broadcast* (depth 1: a star, every repost hangs directly off the root) and *viral* (depth ≥ 2: at least one repost-of-repost). Broadcast diffusion dominates everywhere: 79.4%–81.6% of cascades are broadcasts and only 18.4%–20.6% are viral (@tbl-res-broadcast), a slightly stronger broadcast bias than the real data (71.05% broadcast). The split is flat across the four sizes, so the broadcast/viral balance does not depend on the network size.

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

== Structural Virality
<sec-results-sv>

Structural virality $nu(T)$ @goel2016structural captures the macro-level shape of the repost propagation tree, distinguishing *broadcast* diffusion (one-to-many) from *viral* spread (person-to-person chains). As with the repost power law, the cascades are pooled across all runs of each dataset: the per-run mean $nu(T)$ spans at most $0.012$ within a dataset, so the pooled distribution is representative, while the confidence interval below is taken across runs (the run being the unit of observation), since cascades within a run are not independent.

For the viral cascades alone, $nu(T)$ stays shallow: the mean is $1.585$ at 10K and rises gently to $1.716$ at 1M, with a median of $1.5$–$1.667$ and a maximum of $4.7$–$6.3$ (@tbl-res-viral-sv). @fig-res-nu-density shows the distributions: all four are concentrated just above the minimum $nu = 4/3$ (a single repost-of-repost) and decay quickly, so they sit *below* the broadcast floor $nu = 2$ — the simulated "viral" cascades are barely more viral than a large star. This is where the simulation diverges most from the data: real viral cascades have mean $2.142$, median $2.000$ and a tail reaching $50.27$ (@sec-data-virality), i.e. half of them sit above the broadcast floor, whereas the simulation never produces the long repost-of-repost chains that push $nu(T)$ past it.

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


== Comparison with Bluesky Data <sec-results-comparison>

With all the metrics analyzed in both fronts, the comparison of real vs simulated data can be done.
@tbl-res-vs-data contrasts the key metrics: the Bluesky values against each of the four simulated datasets (pooled over all runs).

#figure(
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
  ),
  caption: flex-caption(
    [Key metrics comparison: empirical data vs. simulation results],
    [Bluesky values from @sec-data-reposts, @sec-data-cascade-shape and @sec-data-virality against each of the four simulated datasets (pooled over runs). The verdicts are discussed below.],
  )
) <tbl-res-vs-data>

#figure(
  image("../images/results/overlap_empirical_sim.svg", width: 100%),
  caption: flex-caption(
    [Cascade size tail: empirical vs. simulation.],
    [Complementary cumulative distribution of cascade size (nodes, root included) on log-log axes, comparing the Bluesky data against the four simulated datasets (pooled over runs). The simulation reproduces the bulk of the distribution but truncates the heavy tail.],
  )
) <fig-res-overlap>

#figure(
  image("../images/results/overlap_depth_empirical_sim.svg", width: 100%),
  caption: flex-caption(
    [Cascade depth tail: empirical vs. simulation.],
    [Complementary cumulative distribution of cascade depth on log-log axes, comparing the Bluesky data against the four simulated datasets (pooled over runs), non-trivial cascades only. The simulation reproduces the bulk but dies by depth $13$, while the empirical tail reaches $131$.],
  )
) <fig-res-overlap-depth>

#figure(
  image("../images/results/overlap_width_empirical_sim.svg", width: 100%),
  caption: flex-caption(
    [Cascade width tail: empirical vs. simulation.],
    [Complementary cumulative distribution of the maximum out-degree on log-log axes, comparing the Bluesky data against the four simulated datasets (pooled over runs), non-trivial cascades only. The simulation truncates the width tail at $1,599$ against the empirical $7,768$.],
  )
) <fig-res-overlap-width>

#figure(
  image("../images/results/viral_nu_overlap.svg", width: 100%),
  caption: flex-caption(
    [Structural virality of viral cascades: empirical vs. simulation.],
    [Log-$x$ density of $nu(T)$ for the viral cascades (depth ≥ 2), comparing the Bluesky data (black) against the four simulated datasets (pooled over runs). The simulated cascades peak at the minimum $nu = 4/3$ and decay before the broadcast floor $nu = 2$, while the empirical distribution peaks at $nu = 2$ and carries a heavy tail out to $50$.],
  )
) <fig-res-nu-overlap>

The following points explicit the main differences between real data and the simulation:
+ *Cascade rate.* The simulation produces roughly half the real share of non-trivial cascades (6.6–7.8% vs. 16.32%), the direct effect of the calibrated 1.2% repost weight.
+ *Size.* The median matches (2 vs. 3), but the tail is ~7× shorter (max 1,697 vs. 12,720).
+ *Depth.* The median matches (1); the tail is ~10× shorter (13 vs. 131) — the sim never builds deep repost chains.
+ *Max out-degree.* Median off by one (1 vs. 2); tail ~5× shorter (1,599 vs. 7,768).
+ *$nu(T)$.* The sim is too shallow: mean 1.16–1.21 vs. 1.454, max 6.25 vs. 50.27.
+ *Viral $nu(T)$.* simulated viral cascades sit below the broadcast floor (mean 1.585–1.716, median 1.5–1.667), while real ones average 2.142 with median 2.000 ---half of the real viral cascades sit above $nu = 2$, and $311$ of them (0.04%) exceed $nu = 10$, which the sim never reaches.
+ *Broadcast share.* The sim is more broadcast-shaped (79.4–81.6% vs. 71.05%).
+ *Reposts.* Lognormal in both, but the simulated exponent ($2.5$–$2.9$) decays faster than the real $2.053$, with a much lower cutoff ($x_"min" approx 1$–$5$ vs. $12$), consistent with the missing deep cascades.

The simulation manages to replicate all the medians and averages of almost all the magnitudes: cascade size (2), cascade depth (3), max out-degree (4). There are some others, such as the broadcast share (7), and $nu(T)$ (5) where the simulation falls short of actual human behaviour (more broadcast than the real data, shallower virality than real data), almost like the model did not allow the content to propagate as far as its real counterpart. Lastly, the simulation did not manage to reproduce any truly deep viral cascade (6), nor generate as many cascades as the real data (1).

*Conclusions*: The model and the simulation accurately match the bulk of the distribution ---both are tiny-and-shallow broadcast-dominated cascades--- making the model a good representation of the nature of the problem. Despite matching the bulk accurately, it consistently underperforms in replicating the heavy tail of the distribution: it is consistently truncated.

The truncation is in fact two distinct truncations. The first is *depth*: the cascade dies out before it can grow deep. The second is *width*: even the first hop --- a single node's direct reposts --- is capped. @sec-finding-missing-tail addresses the former, and @sec-missing-width the latter.

== The Missing Depth <sec-finding-missing-tail>

This section offers an explanation of why the simulation accurately reproduces the bulk of the distribution but falls short of replicating the tail, by modeling cascades as a Galton–Watson process @athreya1972branching. In summary, the missing tail is not a calibration failure but a mathematical consequence of the homogeneity assumptions of @sec-method-des-assumptions.

=== Cascades as Galton–Watson Processes

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

Let us now map the cascade concepts to these assumptions. A cascade is a stochastic process ${Z_n}_(n in NN)$ whose population is the set of users that have *reposted* the post, arranged in generations: $Z_k$ are the reposters at depth $k$ of the cascade tree. A generation can be empty (a user does not repost, so the cascade does not expand from that node). Because the policy $pi$ is fixed and homogeneous across users, and posts carry no content, assumptions 3 and 4 are satisfied --- every reposter draws its number of children from the same distribution, independently of everything else --- which are precisely the homogeneous assumptions of @sec-method-des-assumptions.

Once a cascade is a Galton–Watson process, its long-run behaviour is known without costly simulations, governed entirely by the reproduction number $R_0$.

#def(name: "Reproduction Number")[
  The reproduction number is defined as $R_0 := EE(X)$. The Galton–Watson process is classified by its value:
  - $R_0 < 1$: *subcritical* --- the population dies out with probability 1, and its size has an exponentially bounded tail.
  - $R_0 = 1$: *critical* --- the population dies out with probability 1, but the extinction time and size are heavy-tailed.
  - $R_0 > 1$: *supercritical* --- the population survives with probability $1 - d > 0$, where $d$ is the probability of ultimate extinction.
]

We can compute $R_0$ from the simulation traces, which are the contents of @tbl-res-r0.  It is $approx 0.22$ in every dataset, while the mean seed (direct reposts of the root) is $approx 1.2$–$1.3$. Since $R_0 < 1$, the process is subcritical: every repost replaces itself with less than one further repost, the cascade goes extinct after a few generations, and the size distribution is exponentially bounded. A heavy tail is mathematically impossible at $R_0 approx 0.22$, regardless of the topology.

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

@fig-res-offspring shows the offspring distribution $Z$: roughly 83% of reposts generate no further repost, and the mean sits far below one. This is the reason why the tail will always be truncated, and why @tbl-res-vs-data shows this consistently across all metrics: it is a property of the model, a consequence of the homogeneous policy, not of the network.

#figure(
  image("../images/results/offspring_distribution_100K.svg", width: 100%),
  caption: flex-caption(
    [Offspring distribution of reposts (100K).],
    [Number of children per reposting node in the 100K dataset. The dashed line marks the critical boundary $R_0 = 1$; the red line is the empirical mean $R_0 approx 0.22$. The overwhelming mass is at zero, and the mean is far below criticality.],
  )
) <fig-res-offspring>

=== Content as a Fix Hypothesis

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

== The Missing Width <sec-missing-width>


The other big result discrepancy is regarding the width of the cascades. There is an independent truncation that limits the maximum out-degree of a simulated cascade to about five times smaller than the empirical data one ---$1,599$ against $7,768$--- even though the bulk of the out-degree distribution matches. The width of a cascade is directly tied to the degree of each user: if a user has more followers, when it reposts that's the width of the cascade. The simulation then, makes the broadcasting from user to its followers miss ---on average--- more potential people to arrive: this is an expousure phenomenon. 

Out-degree factorises into an impression and a conversion term,

$ "out-degree" = "impressions" times "repost rate", quad EE("out-degree") = F times p_"read" times pi_"repost", $

with $F$ the author's follower count, $p_"read"$ the probability that a given follower ever reads the post, and $pi_"repost" = 1.2%$ from @sec-cal-policy. Calibration fixes $pi$ and the topology fixes $F$, so the value $p_"read"$ is what we can study to detect the behaviour. Delivery can be ruled out: `propagate` inserts the post into every follower's timeline (@proc-propagate), so the loss is entirely in consumption. For a follower $v$, the chance that one specific post is read is the ratio of what $v$ consumes to what arrives,

$ p_"read" approx frac(r, lambda) $

Where $r$ is the posts $v$ reads per unit time and $lambda$ is the posts that arrive into $v$'s timeline $cal(T)_t (u)$ per unit of time. The two terms come from different populations. $r$ is a property of $v$ alone (one post every $3$ seconds during a session, @sec-cal-interaction), while $lambda$ is the sum of the posting rates of everyone $v$ follows. A model that inflates $lambda$ cannot reproduce the width, no matter how it orders the timeline ---the ordering only changes which post consumes the amount of posts capable to be consumed, not the budget itself.

The section aims to explain where is the missing width disappearing (@sec-width-reach), and points to several potential culprits (@sec-queue-attention and @sec-width-cause).

=== Out-degree versus author followers
<sec-width-reach>

To see where the width is lost, the first-hop size against the author's true follower count is measured. As explained in an upper paragraph, at some point the simulation is losing the topology in-out degree. For broadcast cascades (depth $1$) the maximum out-degree is the number of direct reposts of the root, so this isolates the impression term cleanly. @fig-queue-width and @tbl-queue-width report it for the 500K and 1M datasets, bucketed by the author's in-degree (taken from the topology binary the simulator consumed, see @apx-impl-topology). The random column belongs to the timeline-order experiment of @sec-queue-attention; here we read the reverse-chronological (LIFO) baseline.

#figure(
  image("../images/results/width_vs_followers.svg", width: 100%),
  caption: flex-caption(
    [Cascade size vs. author follower count.],
    [Mean cascade size (left) and probability of reaching at least $50$ reposts (right) as a function of the author's follower count, 500K and 1M datasets, LIFO vs. random. The follower buckets are log-spaced and the vertical axis is logarithmic.],
  )
) <fig-queue-width>

#todo[this table is a little bit incomprehensible, we should rewrite it or turn it into a graph]
#figure(
  table(
    columns: 9,
    align: (left, right, right, right, right, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.cell(rowspan: 2)[*Author followers*],
    table.cell(colspan: 4)[*500K*],
    table.cell(colspan: 4)[*1M*],
    [*Mean L*], [*Mean R*], [*$P(>= 50)$ L*], [*$P(>= 50)$ R*], [*Mean L*], [*Mean R*], [*$P(>= 50)$ L*], [*$P(>= 50)$ R*],
    table.hline(stroke: 0.5pt),
    [$<= 10$], [1.00], [1.00], [0], [0], [1.00], [1.00], [$1 dot 10^(-8)$], [$2 dot 10^(-8)$],
    [$11$--$100$], [1.02], [1.02], [$< 10^(-8)$], [$< 10^(-8)$], [1.02], [1.02], [$1 dot 10^(-7)$], [$1 dot 10^(-7)$],
    [$101$--$1k$], [1.08], [1.08], [$3.8 dot 10^(-7)$], [$3.7 dot 10^(-7)$], [1.10], [1.10], [$1.8 dot 10^(-6)$], [$1.6 dot 10^(-6)$],
    [$1k$--$10k$], [1.32], [1.32], [$3.7 dot 10^(-6)$], [$3.1 dot 10^(-6)$], [1.41], [1.41], [$1.7 dot 10^(-5)$], [$1.4 dot 10^(-5)$],
    [$10k$--$100k$], [2.83], [2.83], [$2.9 dot 10^(-4)$], [$2.2 dot 10^(-4)$], [3.61], [3.62], [$1.9 dot 10^(-3)$], [$1.5 dot 10^(-3)$],
    [$> 100k$], [173.8 ±6.3], [183.6 ±5.3], [0.729 ±0.016], [0.702 ±0.017], [194.4 ±7.9], [211.2 ±7.2], [0.537 ±0.013], [0.707 ±0.011],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Cascade size by author follower count (500K and 1M).],
    [Mean cascade size and probability that a post reaches at least $50$ reposts, as a function of the author's follower count, pooled over runs, LIFO (L) vs. random (R). The tail of the simulated sample is essentially the single largest hub. The largest-hub bucket shows its 95% CI across runs (±); all lower buckets have negligible CI.],
  )
) <tbl-queue-width>

The relationship is monotone, so reach does grow with followers, but far too slowly. An author with fewer than ten followers and one with a hundred thousand are separated by four orders of magnitude of degree, yet the typical cascade moves only from $1.0$ to $2.8$; the jump to $174$ happens only in the top bucket, which at 500K contains a single hub with $211,726$ followers. Normalised per follower, the conversion collapses as degree grows: the hub's $174$ reposts are roughly $0.08%$ of its followers, against the $1.2%$ the policy allows, so $p_"read"$ for its posts is only $approx 6.8%$ even though the post reaches every one of those timelines. That collapse is the missing width, and it points straight at the arrival rate $lambda$ (@sec-missing-width): the timeline is receiving more content than a real follower would. The tail is equally concentrated: $73%$ of the giant hub's posts reach $50$ reposts, against $0.03%$ for the $10$k--$100$k authors and essentially zero below $1$k. The simulated cascade sample is therefore the giant hub plus a thin mid-tier. At 1M the same pattern repeats with a $407,981$-follower hub: mean size $194.4$ (LIFO) and $211.2$ (random), with $54%$ and $71%$ of its posts reaching $50$ reposts.

=== Alternative to Reverse-Chronological Timeline as a Fix Hypothesis
<sec-queue-attention>

The compression above has an obvious suspect: the reverse-chronological timeline as the queue-based mechanic of the model. A LIFO timeline buries a post under whatever arrives after it, so its $p_"read"$ could collapse long before the topology matters. This experiment isolates exactly that mechanism. We keep the topology, the seed, the calibrated parameters and the runs of @tbl-res-finalbatch fixed, and change only how a user drains their timeline: from a LIFO stack to a uniform random draw from all posts the user has not seen so far. Under the random drain an old post has the same probability of being read as a fresh one ---the cheapest possible proxy for a recommender's re-ranking, with no content and no out-of-network exposure, only a different order over the same background timeline. The full random-timeline build ---@sec-results-powerlaw, @sec-results-sv and @tbl-res-vs-data recomputed--- is reported in @apx-random-timeline.

#figure(
  table(
    columns: 9,
    align: (left, right, right, right, right, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*10K L*], [*10K R*], [*100K L*], [*100K R*], [*500K L*], [*500K R*], [*1M L*], [*1M R*],
    table.hline(stroke: 0.5pt),
    [Posts with $>= 1$ repost (%)], [7.33 ±0.02], [7.72 ±0.02], [7.76 ±0.006], [8.31 ±0.005], [7.25 ±0.003], [7.86 ±0.003], [6.58 ±0.1], [7.16 ±0.002],
    [Size, mean], [2.54 ±0.002], [2.47 ±0.002], [2.70 ±0.001], [2.59 ±0.001], [2.92 ±0.001], [2.77 ±0.001], [2.97 ±0.007], [2.82 ±0.001],
    [Size, max], [32], [35], [174], [200], [779], [892], [1,697], [2,040],
    [Depth, max], [10], [9], [12], [11], [13], [11], [13], [13],
    [Out-degree, mean], [1.256 ±0.001], [1.219 ±0.001], [1.382 ±0.001], [1.322 ±0.001], [1.586 ±0.001], [1.497 ±0.001], [1.645 ±0.004], [1.553 ±0.001],
    [Out-degree, max], [28], [31], [161], [179], [726], [787], [1,599], [1,795],
    [$nu(T)$, mean], [1.157 ±0.0005], [1.136 ±0.0004], [1.187 ±0.0002], [1.159 ±0.0001], [1.205 ±0.0001], [1.176 ±0.0001], [1.198 ±0.001], [1.173 ±0.00004],
    [Viral $nu(T)$, mean], [1.585 ±0.001], [1.553 ±0.001], [1.641 ±0.0003], [1.600 ±0.0003], [1.704 ±0.0002], [1.659 ±0.0002], [1.716 ±0.001], [1.673 ±0.0001],
    [Broadcast (%)], [80.1 ±0.07], [82.0 ±0.06], [79.4 ±0.02], [81.7 ±0.02], [80.3 ±0.008], [82.5 ±0.007], [81.6 ±0.1], [83.5 ±0.006],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Comparison of aggregated cascade metrics: LIFO vs Random Timeline],
    [Aggregate cascade metrics pooled over the runs of each dataset, comparing the LIFO baseline (L) with the random drain (R). Cascade-level statistics are restricted to cascades with at least one repost. Means and proportions are shown with their 95% confidence interval across runs (±); the within-cascade 95% CI (bootstrap over the pooled cascades) is an order of magnitude smaller ($<= 0.0017$ for means, $<= 0.06$ for proportions).],
  )
) <tbl-queue-aggregate>

The aggregate picture is a wash, and if anything a regression: randomising raises the share of posts that get at least one repost, but lowers the mean size, the mean out-degree and $nu(T)$, and pushes the broadcast share about two points further from the real data ($71.05%$, @tbl-res-vs-data). Had the timeline order been the capacity cap, removing it should have moved all of these toward the data; it moved the bulk away from it.

The extreme tail is the exception. It moves toward the data at every size: at 500K the largest cascade grows from $779$ to $892$ nodes and the widest from $726$ to $787$ direct reposts, and at 1M from $1697$ to $2040$ nodes and $1599$ to $1795$ direct reposts (@tbl-queue-extreme). This is the signature of *an allocation mechanism, not a capacity one*. The random draw spends the same reads but distributes them differently: it occasionally lets one post accrue attention across many sessions ---which is why the lucky extreme grows deeper as well as wider--- while spreading the ordinary post's reads into a flatter, more star-shaped distribution. The number of reads is fixed; only their assignment changes. @tbl-queue-width confirms it: the random drain moves the largest hub's mean size only from $173.8$ to $183.6$ and leaves the mid-tier essentially unchanged.

#figure(
  table(
    columns: 6,
    align: (left, left, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Dataset*], [*Policy*], [*Size*], [*Depth*], [*Max out-degree*], [*$nu(T)$*],
    table.hline(stroke: 0.5pt),
    [500K], [LIFO], [779], [3], [726], [2.14],
    [500K], [LIFO], [724], [4], [654], [2.22],
    [500K], [LIFO], [696], [4], [643], [2.18],
    table.hline(stroke: 0.3pt),
    [500K], [Random], [892], [5], [772], [2.35],
    [500K], [Random], [856], [4], [762], [2.23],
    [500K], [Random], [856], [5], [787], [2.20],
    table.hline(stroke: 0.3pt),
    [1M], [LIFO], [1,697], [4], [1,599], [2.13],
    [1M], [LIFO], [1,684], [5], [1,580], [2.16],
    [1M], [LIFO], [1,663], [4], [1,564], [2.14],
    table.hline(stroke: 0.3pt),
    [1M], [Random], [2,040], [6], [1,705], [2.40],
    [1M], [Random], [1,976], [4], [1,795], [2.23],
    [1M], [Random], [1,910], [5], [1,750], [2.21],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Largest cascades, LIFO vs. random (500K and 1M).],
    [The three largest cascades by total size in the 500K and 1M datasets under each drain policy, with their depth, maximum out-degree and structural virality. These are the extremes of the distribution, not its bulk.],
  )
) <tbl-queue-extreme>

The timeline order is then not the cause of the missing width, as removing it buys the extreme tail roughly $10$--$20%$ ---and buys it by luck, through the one post that happens to be drawn often enough--- while the gap to the data is a factor of $approx 5$. What the order does control is which post is lucky. In that narrow sense a random, or re-ranked, feed is an improvement: the extremes it produces sit slightly closer to the empirical tail, as some lucky posts get shown more, making them have _deeper_ but still narrow cascades. 

=== Width Truncation Hypothesis
<sec-width-cause>

With ordering ruled out, the remaining candidates can be read directly off the decomposition of @sec-missing-width, $EE("out-degree") = F times r slash lambda times pi_"repost"$. They are not mutually exclusive, and the experiment narrows but does not single one out.

#todo[aquest paraagraf és un puto rollo arreglar]
*Impressions: the arrival rate $lambda$ is inflated.* This is the strongest candidate, and it is a property of the simulated population rather than of the model. $lambda$ ---the post arrival rate onto a timeline--- is set entirely by the *followee* population, and the simulation builds that population from the active tail of the data: the session and gap distributions are fitted on the $243$K users ($18%$) with at least $30$ sessions, and the within-session creation ECDF on the $65$K users with at least $30$ gaps, while $82%$ of the users with fits are excluded and $90%$ of all users have no computable within-session gap (@sec-cal-dist, @sec-cal-create-dist). Every simulated user then samples from this active-only table (@sec-cal-acrossuser), so every followee posts like a heavy poster and $lambda$ is systematically larger than on a real timeline, where most followees are near-silent. With $r$ fixed by @sec-cal-interaction, a larger $lambda$ depresses $p_"read"$ and truncates the width. The same composition is consistent with the rest of the failures ---the low cascade rate and the low reproduction number--- and with the null result of the timeline-order experiment, since reordering reads changes neither $r$ nor $lambda$. This is a known limitation of the calibration, accepted under the time available; it is also the one candidate that is methodological rather than fundamental, since representing the inactive majority explicitly would lower $lambda$ and restore part of the width. Measured directly, the empirical mean arrival rate is $approx 338$ posts per timeline per day, against $approx 1.7 times 10^4$--$7.2 times 10^4$ in the simulated topologies ---roughly two orders of magnitude more, the quantitative signature of the over-active followee population.

*Conversion: $pi$ is uniform.* Because posts carry no content, every post shares the same $pi_"repost"$, so none can convert above the baseline. Even a perfect impression budget would therefore cap the tail at the baseline conversion. This is the same homogeneity behind the missing depth (@sec-finding-missing-tail): letting a good post convert above baseline is exactly what post-level randomness buys, and it is delegated to @sec-future-content.

*Reach: no impressions beyond the follower graph.* Every impression in the model is in-network: propagation inserts the post only into the timelines of the author's followers (@proc-propagate). The empirical maximum out-degree of $7{,}768$ presumes an audience the follower graph does not contain ---a hub with $407{,}981$ followers already caps a perfectly-read post at $0.012 times 407{,}981 approx 4{,}900$ direct reposts. Part of the gap therefore cannot be closed by the current model at all; it needs exposure outside the graph.

Two measurement caveats bound how far any of this can be pushed. First, the comparison is not like-for-like: the empirical cascades come from the full six-day firehose graph, whereas the simulated ones run on a forest-fire sample of a $14$-month topology, so the author of the real $7,768$ cascade need not exist in the sample and part of the apparent gap may be a sampling artefact. Second, the trace records the parent of each repost, not how many followers actually saw the post, so $p_"read"$ is inferred from the in-degree ceiling instead of observed. Fortunately, the simulation could be easily adapted to output this information.

Taken together, the width is capped by an impression budget that is (i) shared with an over-active followee population, (ii) converted at a uniform baseline, and (iii) confined to the follower graph. The timeline order is not one of the caps, as it only decides which user takes the available attention budget.
#todo[això es merda]
This is why the natural structural fix is a recommender rather than a better feed order (@lasser2025desire): it attacks (iii) by adding out-of-network impressions and, if quality-ranked, (ii) by letting good posts convert above baseline, while leaving the reproduction number $R_0 < 1$ of @sec-finding-missing-tail untouched. One caveat carries back to the depth section: the same over-active composition that depresses $p_"read"$ also depresses $R_0$ (@tbl-res-r0), so $0.22$ should be read as measured under this composition. The mechanism of @sec-finding-missing-tail ---homogeneous policy, hence subcritical, hence an exponentially bounded tail--- is unchanged, but a population with realistic activity would move the number.


