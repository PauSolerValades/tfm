#import "utils.typ": todo, comment, def, flex-caption

This chapter presents the empirical evaluation of the Continuous-Time Independent Cascade (CTIC) model. 

== Execution

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
    [`propagation_delay`], [1 s], [@sec-method-ctic],
    [`interaction_delay`], [1 s], [@sec-method-des-assumptions],
    [`creation_delay`], [1 s], [@sec-method-des-assumptions],
    [`offline_startup_ratio`], [0.5], [@sec-cal-warmup],
    [`warmup_time`], [2,000 ticks], [@sec-cal-warmup],
    [`horizon`], [42,000 ticks], [@sec-exec-stationary],
    [`duration`], [40,000 ticks], [@sec-exec-stationary],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Final simulation parameters.],
    [Recap of the final simulation parameters, used in the resported execution.],
  )
) <tbl-res-config>

@tbl-res-finalbatch descibes which datasets has the simulation ran, as well as the parallelism used (workers), how many replications and which config file has been used, which are the same as described in @tbl-res-config.

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
    [1M], [98#footnote[Server ran out of disk space when the simulation was running, last two runs excluded. ]], [1], 
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Final run execution of the simulation],
    [Final run of every dataset, workers and config.],
  )
) <tbl-res-finalbatch>


== Scalability

Regarding performance, this section describes the growth of the simulation according to input value both in time and in memory. Check @apx-hardware for a detailed specification of the hardware this was ran on and @apx-method-exec for how the showcased data has been obtained.
 
@fig-res-time-scalability shows the scalability of the simulation by regressing over the data points in logaritmic scale. Taking into account al 5 datasets, the simulation has a slightly superlinear time growth of $O(n^1.31)$, and if just taking into account the bigger datasets (100K, 500K and 1M) it shows an almost linear growth of $O(n^0.98)$. @tbl-res-time summarizes the execution time per run across datasets, with the 95% confidence interval of the mean, as well as giving the specific values of the plot.


#figure(
  image("../images/results/time_scalability.png", width: 100%),
  caption: flex-caption(
    [Simulation wall-clock time versus dataset size.],
    [Simluation wall-clock per run versus topology size in logarithmic scale. The slope is the grow rate.],
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
    [1M], [90], [1,058,691], [9,407], [1,050,362], [1,002,021], [1,340,140],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Execution time per run.],
    [Execution statistics time per run.],
  )
) <tbl-res-time>


 Regarding times, we can see this scalability in more human terms: a 10K run averages about 2.7 s, 50K about 34 s, 100K about 2 min, 500K about 12 min, and 1M about 18 min.

Regaring memory growth, @fig-res-ram-per-run shows the RAM usage per run across the datasets, and 
@tbl-res-ram reports the RAM usage per run, normalized per worker, with the minimum and maximum observed to interpret the plot. It paints a very similar picture to the time scalability, with a growth of $O(n^1.31)$ with all datapoints (superlinear) but a $O(n^0.98)$ with just the big datasets (linear).

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


The decision of fitting the data twice ---both in for time and memory--- attempts to showcase the difference between the smaller and bigger (and denser) networks. Density wise, 10K and 50K should be considered outliers for how much smaller in comparison they are to bigger size networks. The large order fitting gives a linear growth with more complete networks that are much more representative of real life microblogging social networks.

Analyzing the bigger picture, that ram and time grow with exactly the same rates makes the case for a trivial observation steaming from the simulation design: the simulation is absolutely memory bounded, whith CPU usage never surpassing 0.2% of usage even with the 16 or 12 workers.

This also validates that the implementation of the design (see @apx-impl) is successfull in acheving reasonable execution times and resource efficiency: we are able to run a 11.4 hours simluation ---converting 42000 ticks into hours using the conversion explicited in
@sec-exec-agnostic --- in 18 minutes (@tbl-res-time). It is definetly a win.

== Reposts Power-law

First metric to evaluate in the simulation is the reposts power-law, a characteristic quantity (see @sec-method-des-metrics) that must behave as real data. In @sec-data-reposts, data did not exactly followed a power-law but a lognormal distribution. @tbl-res-reposts reports, per dataset size, the distribution of the fitted exponent $alpha$ across runs and how many runs are actually better described by a power law according to Vuong's test.

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

No run is a power law: the lognormal is preferred in every case, matching the real Bluesky data (@fig-data-reposts-hist), where $alpha = 2.053$ and the lognormal also wins decisively #todo[do we have the p-value?]. The simulated exponents are higher ($approx 2.5$–$2.9$ vs. $2.05$), and the large gap between mean and median at 100K and 500K reflects a bimodal fit ---the `x_min` selection oscillates between two regimes--- rather than a clean single exponent. @fig-res-powerlaw-comp showcases them graphically: the two tails share the Bluesky $x_"min" = 12$ so that the only difference is the exponent, and the simulated tail decays markedly faster. The picture shows that the long tail is pretty much well simulated, but the higher reposts posts have less reposts in the simulation.

#figure(
  image("../images/results/powerlaw_alpha_comparison.png", width: 100%),
  caption: flex-caption(
    [Power-law tails sharing $x_"min" = 12$.],
    [Synthetic power-law tails with the Bluesky exponent ($alpha = 2.05$) and the representative simulated exponent ($alpha = 2.9$), both sharing the Bluesky lower cutoff $x_"min" = 12$. Left: CCDF on log-log axes. Right: density on linear axes.],
  )
) <fig-res-powerlaw-comp>

== Structural Virality

Structural virality $nu(T)$ @goel2016structural captures the macro-level shape of the repost propagation tree, distinguishing *broadcast* diffusion (one-to-many) from *viral* spread (person-to-person chains). As with the repost power law, the statistics are pooled across all runs of each dataset: the cascades produced by different runs of the same topology are statistically indistinguishable (per-run mean $nu(T)$ spans at most $0.012$ within a dataset, apart from the aborted 1M run noted in @tbl-res-finalbatch), so a per-run breakdown adds noise without information.

Almost no post ever becomes a cascade. Across the four datasets between 92.2% and 93.4% of all posts receive no repost at all (`CascadeSize` = 1), leaving only 6.6%–7.8% that form a non-trivial cascade (at least one repost). This is roughly half the rate observed in the real Bluesky data (16.32% in @sec-data-virality), consistent with the calibrated 1.2% repost weight of the user policy. @tbl-res-cascade-stats summarises the tree-level metrics of these cascades: the typical cascade is tiny and shallow (median size 2, median depth 1) in every dataset, but the heavy tail grows with the network, from a maximum of $32$ nodes at 10K up to $1,697$ nodes at 1M, with a maximum out-degree of $1,599$.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*Stat*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    table.cell(rowspan: 3)[*Size*], [mean], [2.54], [2.70], [2.92], [2.97],
    [median], [2], [2], [2], [2],
    [max], [32], [174], [779], [1,697],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Depth*], [mean], [1.26], [1.27], [1.25], [1.24],
    [median], [1], [1], [1], [1],
    [max], [10], [12], [13], [13],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Max out-degree*], [mean], [1.26], [1.38], [1.59], [1.65],
    [median], [1], [1], [1], [1],
    [max], [28], [161], [726], [1,599],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*$nu(T)$*], [mean], [1.157], [1.187], [1.205], [1.198],
    [median], [1.0], [1.0], [1.0], [1.0],
    [max], [4.69], [5.64], [6.08], [6.25],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Cascade-level statistics per dataset.],
    [Tree metrics for the cascades with at least one repost, pooled over all runs. Each metric is broken down into its mean, median and maximum across datasets.],
  )
) <tbl-res-cascade-stats>

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
    [95% CI ($±$)], [0.001], [0.0004], [0.0002], [0.0001],
    [Median], [1.500], [1.667], [1.667], [1.667],
    [Min], [1.333], [1.333], [1.333], [1.333],
    [Max], [4.69], [5.64], [6.08], [6.25],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Structural virality of viral cascades per dataset.],
    [Mean (with 95% bootstrap confidence interval), median, minimum and maximum of $nu(T)$ over the viral cascades (depth ≥ 2), pooled over all runs.],
  )
) <tbl-res-viral-sv>

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    image("../images/results/viral_nu_density_10K.png", width: 100%),
    image("../images/results/viral_nu_density_100K.png", width: 100%),
    image("../images/results/viral_nu_density_500K.png", width: 100%),
    image("../images/results/viral_nu_density_1M.png", width: 100%),
  ),
  caption: flex-caption(
    [Structural virality of viral cascades.],
    [Log-$x$ density of $nu(T)$ for the viral cascades (depth ≥ 2) in each dataset, with the broadcast floor $nu = 2$ (dashed) and the median (dotted) marked.],
  )
) <fig-res-nu-density>

== Comparison with Bluesky Data

#comment[Sketch — first-pass comparison of the simulated quantities against the real Bluesky values of @sec-data-reposts and @sec-data-virality. To be refined: significance tests and a figure overlaying @fig-data-nu-density with @fig-res-nu-density.]

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
    [Repost exponent $alpha$ (mean)], [—], [2.053], [2.497], [2.692], [2.706], [2.927],
    [Repost cutoff $x_"min"$ (mean)], [—], [12], [1.0], [1.76], [3.14], [4.78],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Data vs. simulation, key metrics.],
    [Bluesky values from @sec-data-reposts and @sec-data-virality against each of the four simulated datasets (pooled over runs). The verdicts are discussed below.],
  )
) <tbl-res-vs-data>

Read together, the verdicts are that the bulk of the distribution matches — both are tiny-and-shallow, broadcast-dominated cascades — but the tail is systematically truncated. Metric by metric:

- *Cascade rate.* The simulation produces roughly half the real share of non-trivial cascades (6.6–7.8% vs. 16.32%), the direct effect of the calibrated 1.2% repost weight.
- *Size.* The median matches (2 vs. 3), but the tail is ~7× shorter (max 1,697 vs. 12,720).
- *Depth.* The median matches (1); the tail is ~10× shorter (13 vs. 131) — the sim never builds deep repost chains.
- *Max out-degree.* Median off by one (1 vs. 2); tail ~5× shorter (1,599 vs. 7,768).
- *$nu(T)$.* The sim is too shallow: mean 1.16–1.21 vs. 1.454, max 6.25 vs. 50.27.
- *Viral $nu(T)$.* The biggest gap: simulated viral cascades sit *below* the broadcast floor (mean 1.585–1.716, median 1.5–1.667), while real ones average 2.142 with median 2.000 — half of the real viral cascades sit above $nu = 2$, and $311$ of them (0.04%) exceed $nu = 10$, which the sim never reaches. The "viral" regime is the weakest point of the calibration.
- *Broadcast share.* The sim is more broadcast-shaped (79.4–81.6% vs. 71.05%).
- *Reposts.* Lognormal in both, but the simulated exponent ($2.5$–$2.9$) decays faster than the real $2.053$, with a much lower cutoff ($x_"min" approx 1$–$5$ vs. $12$), consistent with the missing deep cascades.


