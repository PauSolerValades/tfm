#import "../utils.typ": *

This appendix documents the full technology stack used across the project, spanning the data analysis pipeline and the simulation engine.

== Data Pipeline

The data analysis pipeline processes the Bluesky Firehose (see @sec-data-firehose) and spans three languages plus a columnar database and a file format:

- *StarRocks:* a columnar, OLAP-oriented SQL database storing data by columns rather than rows, enabling fast aggregations over hundreds of millions of records. All raw and derived tables reside in the `bsky` and `pau_db` schemas (see `docs/DATABASE.md` in the analysis repository).
- *Python 3.13:* main tool for data extraction, EDA, and plotting. Key packages: `polars` (columnar DataFrame engine), `numpy`, `scipy` (distribution fitting, sparse matrices, SVD), `matplotlib`, `powerlaw` (Clauset et al. MLE power-law fitting), `kneed` (elbow detection for session thresholding), `atproto` (Bluesky API client), and `python-dotenv`.
- *R 4.5.3:* per-user maximum-likelihood distribution fitting. Dependencies: `poweRlaw`, `fitdistrplus`, `data.table`, `tidyverse`, `broom`, and `parallel`.
- *Go 1.24:* high-performance structural virality computation (streaming $O(N)$ cascade tree builder via the Wiener index), topology ingestion from the firehose, and Forest Fire graph sampling. No external dependencies beyond the standard library.
- *Apache Parquet:* columnar storage file format used for intermediate and output datasets (all `.parquet` files in the trace analysis pipeline).

== Simulation Engine

The Discrete-Event Simulation engine (see @sec-design and @sec-impl) is built with Zig and a small set of custom, single-purpose libraries:

- *Zig 0.16:* core engine implementing the D-ary heap, `PagedBitSet`, `SegmentedMultiArrayList`, and all probability distributions (Exponential, Pareto, Normal, Categorical, Uniform, Constant). Chosen for deterministic memory management, compile-time code generation, and C-grade performance without garbage collection overhead.
- *distributions:* custom Zig library implementing the Ziggurat algorithm @marsaglia2000ziggurat for continuous variate generation (Exponential, Normal, Uniform) plus discrete distributions (Categorical, ECDF) with inverse-transform sampling and Kolmogorov-Smirnov goodness-of-fit. Supports `f32`/`f64` precision and arbitrary data types at compile time. Published under the MIT license @soler2025distributions.
- *ds-bskysim:* custom Zig library providing the `PagedBitSet` and `SegmentedMultiArrayList` data structures described in @sec-impl-datastructures and @sec-impl-posts. Published under the MIT license @soler2025dsbskysim.
- *EazyArgs:* compile-time argument parsing library for Zig that generates type-safe CLI parsers from declarative flag definitions @soler2025eazyargs.
