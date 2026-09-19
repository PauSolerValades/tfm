#import "../utils.typ": *

This appendix documents the complete pipeline from raw firehose JSONL files to simulation-ready graph samples. It covers the data source, the three-phase DuckDB ingestion architecture, the SCD2 design, known data gaps, and the Go Forest Fire sampling implementation.

== Data Source

The social graph is reconstructed from `app.bsky.graph.follow` and `app.bsky.graph.block` events (despite being excluded from normal processing in @anx-data-eventlist they are absolutely used here) in the Bluesky Firehose. The dataset used spans 14 months (February 3, 2025 to May 12, 2026) with 88.4% calendar-day coverage.

The raw data consists of JSONL files organised as `YYYY-MM/DD/records_*.jsonl` under `/data/nfs/datasets/bluesky/firehose/non-posts/`. Each file contains one JSON object per line with AT Protocol record events @lazzaroni2025blueskyfirehose. Only records where `$.commit.collection` is `app.bsky.graph.follow` or `app.bsky.graph.block` are relevant for topology.

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

=== Data Ingestion

The JSONL files were initially ingested into a StarRocks `bsky_topology.graph_events` table using a Go-based parallel ingestion tool with 64 producers and 40 consumers.

A single-threaded Python prototype would have needed an estimated 13 days to process the full dataset; Go's lightweight goroutines and producer–consumer pipeline brought this down to approximately 12 hours. The choice of Go over alternatives was pragmatic: the author had enough prior experience with the language to ship a working ingester without learning a new concurrency model from scratch. The denormalised event log stores every create and delete operation:

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

== Graph Extraction

The StarRocks event log is too large for direct analysis. A three-phase DuckDB pipeline transforms it into Parquet with the slowly changing dimensions type 2 (SCD Type 2) paradigm @kimball2013datawarehouse, in order to obtain quearible subsets of the network with just one file.

// the citation is this! The Data Warehouse Toolkit: The Definitive Guide to Dimensional Modeling (The 3rd Edition from 2013 is the most commonly cited modern version)
==== Export

DuckDB reads `graph_events` via the `mysql` extension, splitting the 14-month range into ~70 weekly chunks to stay under StarRocks' `query_timeout`. Four parallel workers export each chunk as a `.parquet` file to apply all transformations without the network latency.

==== SCD2 Transform

The SCD2 design exploits a key property of AT Protocol: each record has a unique URI with at most one create and one delete event. A single DuckDB `GROUP BY uri` query collapses the event log into one row per edge:

#code(caption: flex-caption([Collapse the event log into SCD2 edges.], [Collapse the denormalised event log into one SCD2 row per edge with a single `GROUP BY uri` query.]))[
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
] <code-topo-scd2>

The `valid_to = NULL` means the edge is still active. Flip-flopping (follow $arrow.r$ unfollow $arrow.r$ follow) creates separate rows with different URIs — correct by construction.

The transform was originally attempted with an `ORDER BY actor_did` clause, which caused 23+ TB of temp spill during an external merge sort on 830M groups. Removing the sort reduces runtime from unmanageable to 25 minutes using ~400 GB RAM.

=== Materialize

The SCD2 Parquet files are queryable immediately after Phase 2 for full-scan aggregations. For indexed point lookups, the separate parquets are loaded into a DuckDB `.db` file with indexes on `(actor_did)`, `(subject_did)`, and `(valid_from, valid_to)`, such as the @tbl-topo-scd2 shows.

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

The active follow graph at the end of the observation window (May 12, 2026) is described in @tbl-topo-snapshot.

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

This structure makes it possible, with the three-line query shown in @code-topo-active-edges, to reconstruct the active topology at the end of the observation window:

#code(caption: flex-caption([Extract the active follow graph.], [Extract the active follow graph at the end of the observation window; `valid_to IS NULL` keeps only edges that were never deleted.]))[
  ```sql
  SELECT actor_did, subject_did
  FROM read_parquet('follow_edges.parquet')
  WHERE valid_to IS NULL;
  ```
] <code-topo-active-edges>

This approach has the following two advantages: 
- *Parquet*: DuckDB reads column chunks in parallel, pushes down filters naturally. Best for `COUNT(DISTINCT)`, time-series, bulk aggregations, which allows to easily query the data.
- *`.db` file* (indexed lookups): sub-millisecond latency for point queries like "who does Alice follow?"

== Forest Fire Sampling
<apx-topology-forestfire>

The obtained topology, a full 29-million-node graph ($1.47 times 10^9$ edges), is far too large for the build simulation, as it would need a supercomputer sized RAM to hold all the information in memory. The main objective of this section is to explain how subgraphs of $10^4$–$10^6$ nodes have been sampled using Forest Fire @leskovec2006sampling, which allows to mantain the network graph properties despite sampling.

The Forest Fire algoritm simulates a spreading process over a directed graph. Starting from a random seed node $v$, performs the following three steps:
1. *Forward burns*: selects a random subset of $v$'s outgoing neighbours. The number selected follows a geometric distribution with parameter $p_f$.
2. *Backward burns*: selects a random subset of $v$'s incoming neighbours, governed by $p_b$.
3. Adds all selected neighbours to the visit queue and recurses.

When the queue empties before reaching the target size, a new random unvisited node is seeded. The process continues until the desired number of nodes is reached.

Forest Fire was chosen over simpler alternatives (random node, random edge, snowball) because it preserves the heavy-tailed degree distribution, community structure, and clustering coefficient of the original network @leskovec2006sampling. Random node sampling might erase degree correlations; snowball sampling over-samples high-degree nodes and produces star-like structures that inflate virality metrics.

=== Implementation

Go was chosen again as the implementation programming language as good paralelization was needed with not lot of complexity and developement time. Bitterly, this was a _second_ implementation, after a more naive python one proved to be vastly insufficient from a techincal standpoint.

The Go implementation loads the active follow edges from a binary-encoded edge list produced by `sampling-forest-fire/export.sh` from the SCD2 Parquet (16 bytes per edge: two `int64` fields, cast to `int32` on load), builds an in-memory CSR adjacency (see @apx-impl-csr) with precise pre-allocation, and runs the Forest Fire algorithm natively.

Some important design decisions to avoid pitfalls encountered in this implementation:

- *Binary edge loading*: Edges are serialised as `(int64 actor, int64 subject)` pairs to a flat binary file (cast to `int32` on load), read via buffered I/O in 16 MB chunks. This is $approx 10 times$ faster than parsing CSV/Parquet at runtime.
- *CSR adjacency*: Both outgoing and incoming adjacency are stored as slices of `[]int32`, pre-allocated to exact degree using a degree-count pass. Memory for 1.47B edges: $approx 11.8$ GB (8 bytes per edge: one `int32` slot in each direction).
- *Geometric sampling*: Uses `math.Ceil(math.Log(1-u) / math.Log(1-p))` for efficient geometric variate generation with a cap at the available neighbour count.
- *Seven target sizes*: $10^4$, $5 times 10^4$, $10^5$, $2.5 times 10^5$, $5 times 10^5$, $7.5 times 10^5$, $10^6$ nodes — a finer gradation for convergence studies.

=== Output Format

Two edge sets are output per snapshot as Parquet files:

- *Burned edges* (`burned_edges.parquet`): only the edges actually traversed by the fire. Useful for tracing the sampling path and ensuring the algorithm didn't get stuck.
- *Induced edges* (`induced_edges.parquet`): *all* edges between visited nodes. This is the full induced subgraph — the simulation topology we started this appendix searchig for.

Nodes are stored in `nodes.parquet` with both integer IDs and original DIDs. A `meta.json` file records the algorithm parameters, target/actual sizes, and timestamps.




