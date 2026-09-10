#import "../utils.typ": flex-caption

This annex contains hardware information where the executions were performed and provides additional detail on the simulation's memory footprint. 

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
  caption: flex-caption(
    [Hardware specifications for host _artemis_.],
    [Hardware specifications for host _artemis_.],
  )
) <tbl-hardware>

It is relevant to provide information about the caches cores on the system, listed in @tbl-cache.

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
  caption: flex-caption(
    [Cache hierarchy — 2× AMD EPYC 9654 (Genoa).],
    [Cache hierarchy — 2× AMD EPYC 9654 (Genoa).],
  )
) <tbl-cache>

