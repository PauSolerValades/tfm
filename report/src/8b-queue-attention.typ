#import "utils.typ": todo, comment, flex-caption

== Queue-Based Attention Bottleneck <sec-queue-attention>

@sec-missing-width left the width cap attributed to the attention mechanism, with the reverse-chronological (LIFO) drain as the prime suspect: a post is buried under whatever arrives after it, so its impression term collapses before the topology ever matters. This section isolates exactly that mechanism. We keep the topology, the seed, the calibrated parameters and the $100$ runs of @tbl-res-finalbatch fixed, and change only how a user drains their own timeline: from a LIFO stack to a *uniform random draw*. Under the random drain an old post has the same probability of being read as a fresh one, which is the cheapest possible proxy for a recommender's re-ranking ---no content, no out-of-network exposure, only a different ordering of the same background timeline. The experiment was run at 10K, 100K and 500K with `-Dtimelinerandom`; all other results in this chapter use the LIFO build.

#figure(
  table(
    columns: 7,
    align: (left, right, right, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*10K L*], [*10K R*], [*100K L*], [*100K R*], [*500K L*], [*500K R*],
    table.hline(stroke: 0.5pt),
    [Posts with $>= 1$ repost (%)], [7.33], [7.72], [7.76], [8.31], [7.25], [7.86],
    [Size, mean], [2.54], [2.47], [2.70], [2.59], [2.92], [2.77],
    [Size, max], [32], [35], [174], [200], [779], [892],
    [Depth, max], [10], [9], [12], [11], [13], [11],
    [Out-degree, mean], [1.256], [1.219], [1.382], [1.322], [1.586], [1.497],
    [Out-degree, max], [28], [31], [161], [179], [726], [787],
    [$nu(T)$, mean], [1.157], [1.136], [1.187], [1.159], [1.205], [1.176],
    [Viral $nu(T)$, mean], [1.585], [1.553], [1.641], [1.600], [1.704], [1.659],
    [Broadcast (%)], [80.1], [82.0], [79.4], [81.7], [80.3], [82.5],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Aggregate cascade metrics, LIFO (L) vs. random (R).],
    [Aggregate cascade metrics pooled over the 100 runs of each dataset, comparing the LIFO baseline (L) with the random drain (R). Cascade-level statistics are restricted to cascades with at least one repost.],
  )
) <tbl-queue-aggregate>

The aggregate picture is a wash, and if anything a regression: randomising raises the share of posts that get at least one repost, but *lowers* the mean size, the mean out-degree and $nu(T)$, and pushes the broadcast share about two points further from the real data ($71.05%$, @tbl-res-vs-data). Yet the extreme tail moves the other way at every size. @tbl-queue-extreme shows the largest cascade of the 500K datasets: under the random drain the widest cascades are both wider and deeper, reaching depth $5$ where the LIFO maximum sat at $3$--$4$, and a slightly higher $nu(T)$.

#figure(
  table(
    columns: 5,
    align: (left, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Policy*], [*Size*], [*Depth*], [*Max out-degree*], [*$nu(T)$*],
    table.hline(stroke: 0.5pt),
    [LIFO], [779], [3], [726], [2.14],
    [LIFO], [724], [4], [654], [2.22],
    [LIFO], [696], [4], [643], [2.18],
    table.hline(stroke: 0.3pt),
    [Random], [892], [5], [772], [2.35],
    [Random], [856], [4], [762], [2.23],
    [Random], [856], [5], [787], [2.20],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Largest cascades, LIFO vs. random (500K).],
    [The three largest cascades by total size in the 500K dataset under each drain policy, with their depth, maximum out-degree and structural virality. These are the extremes of the distribution, not its bulk.],
  )
) <tbl-queue-extreme>

This is the signature of an *allocation* mechanism, not a capacity one. The random draw spends the same reads but distributes them differently: it occasionally lets one post accrue attention across many sessions ---which is why the lucky extreme grows deeper as well as wider--- while spreading the ordinary post's reads into a flatter, more star-shaped distribution. The number of reads is fixed; only their assignment changes. The queue therefore shapes *which* cascades grow, not *how large* the largest can be, and it cannot explain the missing width on its own.

=== Reach does not scale with followers

To see what actually truncates the width, we measure the first-hop size against the author's true follower count. For broadcast cascades (depth $1$) the maximum out-degree *is* the number of direct reposts of the root, so this is a clean measurement of the impression term. @fig-queue-width and @tbl-queue-width report it for the 500K dataset, bucketed by the author's in-degree (taken from the topology binary the simulator consumed, see @apx-impl-topology).

#figure(
  image("../images/results/width_vs_followers.svg", width: 100%),
  caption: flex-caption(
    [Cascade size vs. author follower count.],
    [Mean cascade size (left) and probability of reaching at least $50$ reposts (right) as a function of the author's follower count, 500K dataset, LIFO vs. random. The follower buckets are log-spaced and the vertical axis is logarithmic.],
  )
) <fig-queue-width>

#figure(
  table(
    columns: 5,
    align: (left, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Author followers*], [*Mean size L*], [*Mean size R*], [*$P("size" >= 50)$ L*], [*$P("size" >= 50)$ R*],
    table.hline(stroke: 0.5pt),
    [$<= 10$], [1.00], [1.00], [0], [0],
    [$11$--$100$], [1.02], [1.02], [$< 10^(-8)$], [$< 10^(-8)$],
    [$101$--$1k$], [1.08], [1.08], [$3.8 dot 10^(-7)$], [$3.7 dot 10^(-7)$],
    [$1k$--$10k$], [1.32], [1.32], [$3.7 dot 10^(-6)$], [$3.1 dot 10^(-6)$],
    [$10k$--$100k$], [2.83], [2.83], [$2.9 dot 10^(-4)$], [$2.2 dot 10^(-4)$],
    [$> 100k$], [173.8], [183.6], [0.729], [0.702],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Cascade size by author follower count (500K).],
    [Mean cascade size and probability that a post reaches at least $50$ reposts, as a function of the author's follower count, pooled over $100$ runs, LIFO (L) vs. random (R). The tail of the simulated sample is essentially the single largest hub.],
  )
) <tbl-queue-width>

The relationship is monotone, so reach *does* grow with followers ---but it is compressed by orders of magnitude. An author with fewer than ten followers and one with a hundred thousand are separated by four decades of degree, yet their typical cascade moves from $1.0$ to $2.8$; the jump to $174$ happens only in the top bucket, which at 500K contains a single hub with $211{,}726$ followers. Normalised per follower, the conversion collapses as degree grows: the compression is the missing width. The tail is equally concentrated: $73%$ of the giant hub's posts reach $50$ reposts, against $0.03%$ for the $10$k--$100$k authors and essentially zero below $1$k. The simulated cascade sample is therefore the giant hub plus a thin mid-tier, and no amount of queue reordering changes that ordering of magnitudes ---indeed @tbl-queue-width shows the random drain slightly *widens* the hub's first hop ($16.6 -> 26.4$) while narrowing the $10$k--$100$k tier ($2.33 -> 2.09$). Ordering redistributes the budget between these tiers; it does not create budget.

=== Where the width goes

The width is the product of two factors, and the experiment shows both are capped independently of the queue.

*Impressions.* Every follower receives the post in their background timeline (@proc-propagate), but a session consumes a bounded number of posts shared across *everyone* the user follows. The queue decides the order of that consumption, not its volume, so the impression term saturates far below the follower count. The arithmetic is unforgiving: the largest hub in the 1M topology has $407{,}981$ followers, so even perfect in-network delivery at the calibrated $pi_"repost" = 1.2%$ caps a post at $0.012 times 407{,}981 approx 4{,}900$ direct reposts, against the $1{,}599$ actually observed ---roughly a third of its own in-network ceiling. The real maximum out-degree of $7{,}768$ would require about $7{,}768 / 0.012 approx 647{,}000$ impressions, more than any in-network audience in the reconstructed topology can supply. Reaching it therefore requires impressions *beyond* the follower graph.

*Conversion.* Because posts carry no content, every post and every user share the same repost probability $pi_"repost"$. No post can convert above the baseline, so the second factor is a constant and the tail is truncated by construction. This is the same homogeneity discussed for the missing depth (@sec-finding-missing-tail): content is the natural way to let a good post convert above baseline, and it is delegated to @sec-future-content.

*Allocation.* The queue is the remaining factor, and the experiment shows it is second-order: it decides which posts get the budget (and hence samples the tail), not how much budget exists. The giant hub's first hop widening from $16.6$ to $26.4$ under a random draw is the allocation effect at work ---the lucky post is no longer buried--- but it is dwarfed by the capacity gap above.

Taken together, the queue is an attention bottleneck, but an *allocative* one. That distinction matters for intervention: reordering an in-network feed is cheap and improves tail sampling, yet it cannot manufacture the impressions that the missing width requires. The mechanism that does both ---adding impressions beyond the follower graph and ranking them by post quality--- is a recommender, which is why recommendation appears as the natural structural fix rather than a better queue order (@lasser2025desire). It attacks the impression factor (out-of-network exposure) and, if quality-ranked, the conversion factor (post-level heterogeneity) at once, while leaving the reproduction number $R_0 < 1$ of @sec-finding-missing-tail untouched.

#todo[Measure impressions directly: the trace records the repost parent, not the number of users who saw each post, so the impression term above is inferred from the in-degree ceiling rather than observed. Instrumenting exposure would turn this decomposition into a measurement.]

#todo[Extend the random-timeline run to 1M and add bootstrap confidence intervals to @tbl-queue-aggregate and @tbl-queue-width.]
