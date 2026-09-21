#import "../utils.typ": flex-caption, todo

This appendix reports the full results of the random-timeline experiment (@sec-queue-attention) analogously to the LIFO baseline of @sec-results. The experiment keeps the topology, seed, calibrated parameters and the runs of @tbl-res-finalbatch fixed, and changes only how each user drains their own timeline: from a LIFO stack to a uniform random draw (`-Dtimelinerandom`), as motivated in @sec-missing-width and designed in @sec-queue-attention, so an old post has the same probability of being read as a fresh one. First, we check whether the repost power law still holds (@apx-rtl-powerlaw); second, we compute structural virality (@apx-rtl-sv); lastly, we compare every magnitude against the empirical Bluesky data of @sec-data (@apx-rtl-comparison).

== Reposts Power-law
<apx-rtl-powerlaw>

As in @sec-results-powerlaw, the first metric is the repost power-law. @tbl-apx-random-reposts reports, per dataset size, the distribution of the fitted exponent $alpha$ across runs and how many runs are better described by a power law according to Vuong's test.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [*Runs*], [100], [100], [100], [98],
    [*$alpha$ mean*], [2.606], [2.468], [2.863], [2.923],
    [*$alpha$ median*], [2.606], [2.468], [2.957], [2.926],
    [*$alpha$ CI95 ($±$)*], [0.002], [0.001], [0.043], [0.004],
    [*$alpha$ min*], [2.580], [2.460], [2.358], [2.799],
    [*$alpha$ max*], [2.642], [2.476], [2.977], [2.947],
    [*$x_"min"$ mean*], [1.000], [1.000], [2.680], [3.970],
    [*$x_"min"$ median*], [1.0], [1.0], [3.0], [4.0],
    [*$x_"min"$ CI95 ($±$)*], [0.000], [0.000], [0.144], [0.034],
    [*$x_"min"$ min*], [1], [1], [1], [3],
    [*$x_"min"$ max*], [1], [1], [3], [4],
    [*Power-law runs*], [0/100], [0/100], [0/100], [0/98],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Power-law fits of repost counts per run (random timeline).],
    [Fitted power-law exponent $alpha$ and lower cutoff $x_"min"$ summarized across runs (mean, median, 95% confidence interval, range), per dataset size, plus the number of runs for which a power law is preferred over a lognormal (Vuong test, $p < 0.05$). Random-timeline build.],
  )
) <tbl-apx-random-reposts>

The picture is the same as the LIFO baseline: no run is a power law, the lognormal is preferred in every case, and the exponents hover around $2.5$--$2.9$ ---slightly higher than the real $2.053$ but in the same regime as the LIFO values of @tbl-res-reposts. The $x_"min"$ oscillation between $1$ and $4$ at 500K and 1M is the same bimodal fit seen in the baseline: the `x_min` selection flips between two regimes rather than settling on a single cutoff. @fig-apx-random-powerlaw-comp shows the representative random exponent ($alpha = 2.9$, from 1M) against the Bluesky tail.

#figure(
  image("../../images/annex/random-timeline/powerlaw_alpha_comparison.svg", width: 100%),
  caption: flex-caption(
    [Synthetic power-law comparison of $alpha=2.05$ (Bluesky) _v.s._ $alpha=2.9$ (random timeline).],
    [Synthetic power-law tails with the Bluesky exponent ($alpha = 2.05$) and the representative random-timeline exponent ($alpha = 2.9$), both sharing the Bluesky lower cutoff $x_"min" = 12$. Left: CCDF on log-log axes. Right: density on linear axes.],
  )
) <fig-apx-random-powerlaw-comp>

== Structural Virality
<apx-rtl-sv>
 
As in @sec-results-sv, structural virality $nu(T)$ @goel2016structural captures the macro-level shape of the repost propagation tree. Across the four datasets between 91.7% and 92.8% of all posts receive no repost at all (`CascadeSize` = 1), leaving 7.2%--8.3% that form a non-trivial cascade ---about half the rate of the real Bluesky data (16.32%), and slightly above the LIFO baseline's 6.6%--7.8%: randomising the drain raises the number of posts that get at least one repost, @tbl-queue-aggregate. @tbl-apx-random-cascade-stats summarises the tree-level metrics: the typical cascade is tiny and shallow in every dataset, and the heavy tail grows with the network from a maximum of $35$ nodes at 10K up to $2{,}040$ at 1M, with a maximum out-degree of $1{,}795$.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*Stat*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    table.cell(rowspan: 3)[*Size*], [mean], [2.47], [2.59], [2.77], [2.82],
    [median], [2], [2], [2], [2],
    [max], [35], [200], [892], [2,040],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Depth*], [mean], [1.23], [1.23], [1.22], [1.20],
    [median], [1], [1], [1], [1],
    [max], [9], [11], [11], [13],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Max out-degree*], [mean], [1.22], [1.32], [1.50], [1.55],
    [median], [1], [1], [1], [1],
    [max], [31], [179], [787], [1,795],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*$nu(T)$*], [mean], [1.136], [1.159], [1.176], [1.173],
    [median], [1.0], [1.0], [1.0], [1.0],
    [max], [4.63], [5.19], [5.78], [5.69],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Cascade-level statistics per dataset (random timeline).],
    [Tree metrics for the cascades with at least one repost, pooled over all runs of the random-timeline build. Each metric is broken down into its mean, median and maximum across datasets.],
  )
) <tbl-apx-random-cascade-stats>

Broadcast diffusion dominates everywhere: 81.7%--83.5% of cascades are broadcasts and only 16.5%--18.3% are viral (@tbl-apx-random-broadcast) ---a stronger broadcast bias than both the real data (71.05%) and the LIFO baseline (79.4%--81.6%). This is the same direction as the aggregate comparison of @tbl-queue-aggregate: randomising the drain pushes the cascade shape slightly *more* star-like.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Dataset*], [*Total*], [*Broadcast*], [*Broadcast %*], [*Viral*], [*Viral %*],
    table.hline(stroke: 0.5pt),
    [10K], [1.854e6], [1.520e6], [82.0%], [3.339e5], [18.0%],
    [100K], [2.101e7], [1.716e7], [81.7%], [3.851e6], [18.3%],
    [500K], [1.018e8], [8.395e7], [82.5%], [1.786e7], [17.5%],
    [1M], [1.804e8], [1.506e8], [83.5%], [2.979e7], [16.5%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Broadcast vs. viral cascades per dataset (random timeline).],
    [Split of the non-trivial cascades into broadcast (depth 1) and viral (depth ≥ 2), pooled over all runs of the random-timeline build. Counts in scientific notation, with each category's share of the total.],
  )
) <tbl-apx-random-broadcast>

For the viral cascades alone, $nu(T)$ stays shallow: the mean rises gently from $1.553$ at 10K to $1.673$ at 1M, with a median of $1.333$--$1.667$ and a maximum of $4.6$--$5.8$ (@tbl-apx-random-viral-sv). @fig-apx-random-nu-density shows the distributions: all four sit *below* the broadcast floor $nu = 2$, exactly like the LIFO baseline ---the simulated "viral" cascades are barely more viral than a large star, and the long repost-of-repost chains that push the real $nu(T)$ past $50$ never appear.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*$nu(T)$ (viral)*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Mean], [1.553], [1.600], [1.659], [1.673],
    [95% CI ($±$)], [0.001], [0.0003], [0.0002], [0.0001],
    [Median], [1.333], [1.500], [1.667], [1.667],
    [Min], [1.333], [1.333], [1.333], [1.333],
    [Max], [4.63], [5.19], [5.78], [5.69],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Structural virality of viral cascades per dataset (random timeline).],
    [Mean (with 95% bootstrap confidence interval), median, minimum and maximum of $nu(T)$ over the viral cascades (depth ≥ 2), pooled over all runs of the random-timeline build.],
  )
) <tbl-apx-random-viral-sv>

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    image("../../images/annex/random-timeline/viral_nu_density_10K.svg", width: 100%),
    image("../../images/annex/random-timeline/viral_nu_density_100K.svg", width: 100%),
    image("../../images/annex/random-timeline/viral_nu_density_500K.svg", width: 100%),
    image("../../images/annex/random-timeline/viral_nu_density_1M.svg", width: 100%),
  ),
  caption: flex-caption(
    [Structural virality of viral cascades (random timeline).],
    [Log-$x$ density of $nu(T)$ for the viral cascades (depth ≥ 2) in each random-timeline dataset, with the broadcast floor $nu = 2$ (dashed) and the median (dotted) marked.],
  )
) <fig-apx-random-nu-density>

== Comparison with Bluesky Data
<apx-rtl-comparison>
 
With all the metrics computed on the random-timeline build, @tbl-apx-random-vs-data contrasts them against the Bluesky values of @tbl-res-vs-data.

#figure(
  table(
    columns: 7,
    align: (left, left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*Stat*], [*Bluesky data*], [*10K*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Cascades ≥ 1 repost], [—], [16.32%], table.cell(colspan: 4)[7.2–8.3%],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Size*], [mean], [9.18], [2.47], [2.59], [2.77], [2.82],
    [median], [3], [2], [2], [2], [2],
    [max], [12,720], [35], [200], [892], [2,040],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Depth*], [mean], [1.50], [1.23], [1.23], [1.22], [1.20],
    [median], [1], [1], [1], [1], [1],
    [max], [131], [9], [11], [11], [13],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Max out-degree*], [mean], [5.82], [1.22], [1.32], [1.50], [1.55],
    [median], [2], [1], [1], [1], [1],
    [max], [7,768], [31], [179], [787], [1,795],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*$nu(T)$*], [mean], [1.454], [1.136], [1.159], [1.176], [1.173],
    [median], [1.333], [1.0], [1.0], [1.0], [1.0],
    [max], [50.27], [4.63], [5.19], [5.78], [5.69],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Viral $nu(T)$*], [mean], [2.142], [1.553], [1.600], [1.659], [1.673],
    [median], [2.000], [1.333], [1.500], [1.667], [1.667],
    [max], [50.269], [4.63], [5.19], [5.78], [5.69],
    table.hline(stroke: 0.3pt),
    [Broadcast cascades], [—], [71.05%], [82.0%], [81.7%], [82.5%], [83.5%],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Repost exponent $alpha$*], [mean], [2.053], [2.606], [2.468], [2.863], [2.923],
    [min], [—], [2.580], [2.460], [2.358], [2.799],
    [max], [—], [2.642], [2.476], [2.977], [2.947],
    table.hline(stroke: 0.3pt),
    table.cell(rowspan: 3)[*Repost cutoff $x_"min"$*], [mean], [12], [1.0], [1.0], [2.68], [3.97],
    [min], [—], [1], [1], [1], [3],
    [max], [—], [1], [1], [3], [4],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Key metrics comparison: empirical data vs. random-timeline simulation.],
    [Bluesky values from @sec-data-reposts, @sec-data-cascade-shape and @sec-data-virality against each of the four random-timeline datasets (pooled over runs).],
  )
) <tbl-apx-random-vs-data>

The comparison reads almost identically to @tbl-res-vs-data, so the conclusions of the comparison in @sec-results-comparison carry over unchanged. The random drain produces roughly half the real share of non-trivial cascades, matching medians but truncated tails (size $2,040$ vs. $12,720$, depth $13$ vs. $131$, max out-degree $1,795$ vs. $7,768$), a shallower $nu(T)$ ($1.14$--$1.18$ vs. $1.454$), and a more broadcast-shaped profile ($82$--$84%$ vs. $71.05%$). The repost exponent stays lognormal with a faster decay ($2.5$--$2.9$ vs. $2.053$) and a lower cutoff. Relative to the LIFO baseline, the only notable shifts are a slightly higher cascade rate (7.2%--8.3% vs. 6.6%--7.8%) and a slightly more broadcast-heavy shape, both consistent with @tbl-queue-aggregate: reordering the drain changes which cascades grow and lifts the extreme tail, but leaves the bulk of the distribution flat.
