This annex contains hardware information where the executions were performed aand provides additional detail on the simulation's memory footprint. 

== Hardware Specifications
<apx-performance-hardware>

All simulation runs were executed on the same dedicated server with the listed specifications on @tbl-hardware.

#figure(
  table(
    columns: 2,
    align: (left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Component*], [*Specification*],
    table.hline(stroke: 0.5pt),
    [CPU], [2× AMD EPYC 9654 (Genoa)],
    [Cores / Threads], [192 / 384],
    [RAM], [1.1 TB DDR5],
    [OS], [Ubuntu 24.04.4 LTS (x86-64)],
    [Kernel], [Linux 6.8.0-111-generic],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Hardware specifications for host _artemis_.]
) <tbl-hardware>

It is rellevant to provide informaction about the caches cores on the system, listed in @tbl-cache.

#figure(
  table(
    columns: 2,
    align: (left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Cache level*], [*Specification*],
    table.hline(stroke: 0.5pt),
    [L1d (data)], [6 MiB — 32 KB per core × 192 cores],
    [L1i (instruction)], [6 MiB — 32 KB per core × 192 cores],
    [L2], [192 MiB — 1 MiB per core × 192 cores],
    [L3], [768 MiB — 32 MiB per CCD × 24 CCDs],
    table.hline(stroke: 0.5pt),
    [*Total on-chip cache*], [*972 MiB*],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Cache hierarchy — 2× AMD EPYC 9654 (Genoa).]
) <tbl-cache>

== Space Analysis
<apx-performance-space>

The measurements reported here are approximate -—-peak RSS was recorded from system monitoring rather than from instrumented allocation tracing--— and should be treated as indicative rather than precise.

#figure(
  table(
    columns: 4,
    align: (center, right, right, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Users*], [*Memory (GB)*], [*GB / 100K users*], [*Increase from previous*],
    table.hline(stroke: 0.5pt),
    [100K], [32 -- 34], [32 -- 34], [—],
    [250K], [$approx$ 100], [$approx$ 40], [$approx 3.0 times$],
    [500K], [$approx$ 400], [$approx$ 80], [$approx 4.0 times$],
    [1M],   [$approx$ 900], [$approx$ 90], [$approx 2.25 times$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Peak memory usage across dataset sizes. The per-100K-user column shows that the memory cost per user increases with scale, confirming superlinear growth. A log-log fit over these four points yields an exponent of $approx 2.0$, consistent with the expected $O(N^2)$ worst case driven by the $N times M$ impression matrices (see @sec-impl-impressions).]
) <tbl-memory-scaling>

The dominant consumers are the two `PagedBitSet` instances (seen and interacted matrices, each $N times M$ bits for $M$ posts created during the run) and the CSR follower array ($2 |E|$ bytes of `u32`). For a 500K-user run producing $approx 5 times 10^6$ posts, the two bitsets alone account for $approx 1.25$ TB of addressable bits ($approx 156$ GB), though actual allocation is page-granular and depends on how many posts the simulation actually generates. Timeline heaps are preallocated at $1024$ elements each, contributing $approx 1024 · 16 · N$ bytes (roughly $16$ MB per 1M users), negligible next to the bitsets and adjacency.
