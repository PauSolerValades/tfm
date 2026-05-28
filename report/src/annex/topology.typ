This appendix documents the complete pipeline from raw firehose JSONL files to simulation-ready graph samples. It covers the data source, the three-phase DuckDB ingestion architecture, the SCD2 design, known data gaps, and the Go Forest Fire sampling implementation.

#import "../utils.typ": flex-caption

== Data Source

The social graph is reconstructed from `app.bsky.graph.follow` and `app.bsky.graph.block` events in the Bluesky firehose. The dataset spans 14 months (February 3, 2025 to May 12, 2026) with 88.4% calendar-day coverage.

The raw data consists of JSONL files organised as `YYYY-MM/DD/records_*.jsonl` under `/data/nfs/datasets/bluesky/firehose/non-posts/`. Each file contains one JSON object per line with AT Protocol record events. Only records where `$.commit.collection` is `app.bsky.graph.follow` or `app.bsky.graph.block` are relevant for topology.

Each event is uniquely identified by its AT Protocol URI (`at://<did>/<collection>/<rkey>`) and carries a microsecond-precision timestamp. The `create` operation establishes the relationship; the `delete` operation closes it.

=== Known Data Gaps

Two collection outages were identified from the directory tree:

#figure(
  table(
    columns: 5,
    align: (center, left, left, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Gap*], [*Start*], [*End*], [*Duration*], [*Likely cause*],
    table.hline(stroke: 0.5pt),
    [1], [2025-07-17], [2025-08-31], [46 days], [Firehose collector down],
    [2], [2026-03-25], [2026-04-01], [8 days], [Shorter outage],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Known data gaps.],
    [Known data gaps. Total missing: 54 days (11.6%).],
  )
) <tbl-topo-gaps>

The gaps affect the SCD2 tables as follows: edges created and deleted entirely within a gap are lost forever; edges deleted during a gap remain marked as active ($"valid_to" = "NULL"$); users who only appeared during a gap are absent. For the end-of-window snapshot used by the simulation, these gaps have negligible impact — any edge active in April–May 2026 was almost certainly recorded after the March 2026 outage ended.

=== Ingestion: StarRocks

The JSONL files were initially ingested into a StarRocks `bsky_topology.graph_events` table using a Go-based parallel ingestion tool with 64 concurrent workers —-a design dictated by necessity rather than ideology. A single-threaded Python prototype would have needed an estimated 13 days to process the full dataset; Go's lightweight goroutines and producer–consumer pipeline brought this down to approximately 13 hours. The choice of Go over alternatives was pragmatic: the author had enough prior experience with the language to ship a working ingester without learning a new concurrency model from scratch. The denormalised event log stores every create and delete operation:

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`event_timestamp`], [`DATETIME`], [When the follow/unfollow/block/unblock occurred],
    [`uri`], [`VARCHAR(256)`], [AT Protocol record URI (unique per event)],
    [`actor_did`], [`VARCHAR(128)`], [The user who performed the action],
    [`subject_did`], [`VARCHAR(128)`], [The target user],
    [`action_type`], [`VARCHAR(16)`], [`follow`, `unfollow`, `block`, or `unblock`],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [`bsky_topology.graph_events` schema.],
    [`bsky_topology.graph_events` schema. $1.79 times 10^9$ rows spanning 14 months.],
  )
) <tbl-topo-starrocks>

== Graph Extraction (Three-Phase DuckDB Pipeline)

The StarRocks event log is too large for direct analysis. A three-phase DuckDB pipeline transforms it into SCD2 Parquet files matching the `bluesky_db_specification.md` schema:

#figure(
  table(
    columns: 4,
    align: (center, left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Phase*], [*Input*], [*Output*], [*Runtime*],
    table.hline(stroke: 0.5pt),
    [1. Export], [StarRocks `graph_events`], [70 Parquet files (62 GB)], [$approx 12$ min],
    [2. SCD2 Transform], [Raw Parquet], [`follow_edges.parquet` (67 GB, 1.47B rows)], [$approx 25$ min],
    [3. Materialize], [SCD2 Parquet], [`bsky_topology.db` (130 GB, indexed)], [$approx 5$ min],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Three-phase DuckDB pipeline.],
    [Three-phase DuckDB pipeline. Total runtime $approx 42$ min.],
  )
) <tbl-topo-phases>

=== Phase 1: Export

DuckDB reads `graph_events` via the `mysql` extension, splitting the 14-month range into ~70 weekly chunks to stay under StarRocks' `query_timeout`. Four parallel workers export each chunk as a `.parquet` file. The script is resumable: already-exported chunks are skipped on restart.

=== Phase 2: SCD2 Transform

The SCD2 design exploits a key property of AT Protocol: each record has a unique URI with at most one create and one delete event. A single DuckDB `GROUP BY uri` query collapses the event log into one row per edge:

```sql
SELECT uri,
       MAX(actor_did)                                    AS actor_did,
       MAX(subject_did)                                  AS subject_did,
       MIN(event_timestamp)                              AS valid_from,
       NULLIF(MAX(event_timestamp), MIN(event_timestamp)) AS valid_to
FROM graph_events
WHERE action_type IN ('follow', 'unfollow')
GROUP BY uri
HAVING COUNT_IF(action_type = 'follow') > 0
```

No window functions, no state machines, no procedural code — just hash aggregation parallelised across CPU cores. The `valid_to = NULL` means the edge is still active. Flip-flopping (follow $arrow.r$ unfollow $arrow.r$ follow) creates separate rows with different URIs — correct by construction.

The transform was originally attempted with an `ORDER BY actor_did` clause, which caused 23+ TB of temp spill during an external merge sort on 830M groups. Removing the sort reduces runtime from unmanageable to 25 minutes using ~400 GB RAM.

=== Phase 3: Materialize

The SCD2 Parquet files are queryable immediately after Phase 2 for full-scan aggregations. For indexed point lookups, Phase 3 loads them into a DuckDB `.db` file with indexes on `(actor_did)`, `(subject_did)`, and `(valid_from, valid_to)`.

The target schema matches `bluesky_db_specification.md`:

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Table*], [*Key*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`users`], [`did`], [Unique DIDs with first-seen metadata],
    [`follow_edges`], [`uri`], [Follow relationships with `valid_from` / `valid_to`],
    [`block_edges`], [`uri`], [Block relationships with `valid_from` / `valid_to`],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [SCD2 schema.],
    [SCD2 schema. Each edge is one row. `valid_to = NULL` means still active.],
  )
) <tbl-topo-scd2>

=== Final Graph Snapshot (May 12, 2026)

The active follow graph at the end of the observation window:

#figure(
  table(
    columns: 2,
    align: (left, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*Value*],
    table.hline(stroke: 0.5pt),
    [Active follow edges], [$1,467,658,560$],
    [Active block edges], [$117,051,465$],
    [Total unique DIDs], [$28,860,506$],
    [Users who follow someone], [$21,592,211$],
    [Users with at least one follower], [$22,331,845$],
    [Avg follows per active user], [$approx 68$],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Final graph snapshot.],
    [Final graph snapshot. 75% of DIDs follow at least one user; 25% are lurkers appearing only as targets of follows/blocks.],
  )
) <tbl-topo-snapshot>

The active follow graph is extracted via:
```sql
SELECT actor_did, subject_did
FROM read_parquet('follow_edges.parquet')
WHERE valid_to IS NULL;
```

=== Query Performance: Parquet vs .db

- *Parquet* (full scans): DuckDB reads column chunks in parallel, pushes down filters. Best for `COUNT(DISTINCT)`, time-series, bulk aggregations.
- *`.db` file* (indexed lookups): sub-millisecond latency for point queries like "who does Alice follow?"

== Forest Fire Sampling

The full 29-million-node graph ($1.47 times 10^9$ edges) is far too large for agent-based simulation. Subgraphs of $10^4$–$10^6$ nodes are sampled using Forest Fire @leskovec2006sampling.

=== Algorithm

Forest Fire simulates a spreading process over a directed graph. Starting from a random seed node $v$:

1. *Forward burns*: selects a random subset of $v$'s outgoing neighbours. The number selected follows a geometric distribution with parameter $p_f$.
2. *Backward burns*: selects a random subset of $v$'s incoming neighbours, governed by $p_b$.
3. Adds all selected neighbours to the visit queue and recurses.

When the queue empties before reaching the target size, a new random unvisited node is seeded. The process continues until the desired number of nodes is reached.

Forest Fire was chosen over simpler alternatives (random node, random edge, snowball) because it preserves the heavy-tailed degree distribution, community structure, and clustering coefficient of the original network @leskovec2006sampling. Random node sampling destroys degree correlations; snowball sampling over-samples high-degree nodes and produces star-like structures that inflate virality metrics.

=== Go Implementation

The Go implementation (`topology/sampling-go/main.go`) replaces an earlier Python/DuckDB prototype that proved unable to complete a single sample at the required scale: Python's overhead made building the in-memory CSR adjacency for $1.47 times 10^9$ edges impractical, and the recursive burning process hit recursion-depth limits and memory fragmentation issues that no amount of `sys.setrecursionlimit` tuning could resolve. The Go rewrite loads active follow edges from Parquet as a binary-encoded edge list (16 bytes per edge: two `int32` fields), builds an in-memory CSR adjacency with precise pre-allocation, and runs the Forest Fire algorithm natively —-no recursion, no garbage-collector pauses, and no late-night Stack Overflow searches for `RecursionError`.

Key design decisions:

- *Binary edge loading*: Edges are serialised as `(int32 actor, int32 subject)` pairs to a flat binary file, read via buffered I/O in 16 MB chunks. This is $approx 10 times$ faster than parsing CSV/Parquet at runtime.
- *CSR adjacency*: Both outgoing and incoming adjacency are stored as slices of `[]int32`, pre-allocated to exact degree using a degree-count pass. Memory for 1.47B edges: $approx 11.8$ GB (8 bytes per edge $times$ 2 directions).
- *Geometric sampling*: Uses `math.Ceil(math.Log(1-u) / math.Log(1-p))` for efficient geometric variate generation with a cap at the available neighbour count.
- *Seven target sizes*: $10^4$, $5 times 10^4$, $10^5$, $2.5 times 10^5$, $5 times 10^5$, $7.5 times 10^5$, $10^6$ nodes — a finer gradation for convergence studies.

=== Output Format

Two edge sets are output per snapshot as Parquet files:

- *Burned edges* (`burned_edges.parquet`): only the edges actually traversed by the fire. Useful for tracing the sampling path and ensuring the algorithm didn't get stuck.
- *Induced edges* (`induced_edges.parquet`): *all* edges between visited nodes. This is the full induced subgraph — the simulation topology.

Nodes are stored in `nodes.parquet` with both integer IDs and original DIDs. A `meta.json` file records the algorithm parameters, target/actual sizes, and timestamps.

=== Validation

The `topology/sampling/validate.py` script verifies that each sample preserves key structural properties: power-law degree distribution (Kolmogorov–Smirnov test against the full graph), average clustering coefficient, and largest connected component size ratio. Samples that deviate significantly are discarded.


