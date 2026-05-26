#import "../utils.typ": todo

This appendix documents the full technology stack used across the project, spanning the data analysis pipeline and the simulation engine.

== Data Pipeline

The data analysis pipeline processes the Bluesky Firehose (see @sec-data-firehose) and spans three languages and a columnar database:

- *StarRocks:* a columnar, OLAP-oriented SQL database that stores data by columns rather than rows, enabling fast aggregation queries over hundreds of millions of records. All raw and derived tables reside in the `bsky` and `pau_db` schemas.
- *Python 3.13:* main tool for data extraction, exploratory analysis, and plotting. Key packages beyond `numpy` and `polars` are `powerlaw` (Clauset et al. power-law MLE), `scipy` (distribution fitting), and `matplotlib`.
- *R 4.5.3:* used for per-user distribution fitting. Dependencies include `poweRlaw`, `fitdistrplus`, `data.table`, `tidyverse`, `broom`, and `parallel`.
- *Go 1.24:* used for the structural virality computation (streaming $O(N)$ cascade tree builder), the topology ingestion pipeline, and the Forest Fire graph sampling.
- *parquet*: #todo[Parquet file format]

== Simulation Engine

The Discrete-Event Simulation engine (see @sec-design and @sec-impl) is built with the following tools:

- *Zig 0.16:* the core simulation engine, including all data structures (the D-ary heap, the `PagedBitSet`, the `SegmentedMultiArrayList`) and all probability distributions (Exponential, Pareto, Normal, Categorical, Uniform, Constant). Zig was chosen for its deterministic memory management, compile-time code generation, and C-grade performance without garbage collection overhead.
- *Distributions library:* a custom Zig library implementing the Ziggurat algorithm @marsaglia2000ziggurat for continuous variate generation, plus discrete distributions (Categorical with inverse-transform sampling). Published under the MIT license @soler2025distributions.
- *EazyArgs:* the only external Zig dependency, an argument parsing library that uses compile-time execution to generate code fitted specifically for the simulation's command-line interface @soler2025eazyargs.
- *Python 3.13:* used for non-performance-critical auxiliary tasks, such as artificial topology data generation and trace validation scripts.
