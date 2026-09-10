#import "../utils.typ": *

This section describes the contents of the delivered code, as well as how to execute it and compile it.

== `des-ctic`

The `des-ctic` code repository contains the simulation engine, the cascade construction and the dataset generation from the simulation traces, as well as a pipeline to schedule and coordinate all three projects. It contains the following three subprojects plus the build system.

=== `bskysim`

Contains the simulation engine. Needs a simulation file and a topology to run. These are not attached with the code, but can be obtained by contacting its author.

Coded with Zig 0.16.0.

*Dependencies.* Code contained in `zig-pkg` and downloadable following the reference.
- `distributions` @soler2025distributions: random number sampling from probability distributions, written in and for Zig.
- `tabular` @soler2025tabular: very small and specific CSV and generic separator reader.
- `easy-args` @soler2025eazyargs: compile time defined parsing library arguments.
- `ds-bskysim` @soler2025dsbskysim: repository containing the data structures used by the simulation. It is not released as it is not intended to be used separately; it is split out only for separation of concerns.
- `jemalloc` @jemalloc: high performance C allocator, linked as a prebuilt static library (version `5.3.1-144-ge36a0fa5`) configured with `--with-jemalloc-prefix=`, so that it overrides glibc's allocator.

=== `cascades`

Constructs all the cascades in all runs and stores them into a `.tsv` file. Implementation explanation in @apx-pipeline-cascades.

Version: Zig 0.16.0, no dependencies.

=== `dataset-creation`

From the simulation traces, the `cascades.tsv` and the topology, constructs nine distinct datasets to analyze the simulation. Implementation details in @apx-pipeline-datasets.

Version: Go 1.26.3, several dependencies that can be found in the Go project.

*Dependencies.*
- DuckDB: invoked as a CLI from Go (version `1.2.1`, build `8e52ec4395`).

=== `build.zig`

Zig Build System implementation that orchestrates the pipeline. Allows for sequential execution of the three subprojects described as well as recompilation if needed. Details in @apx-pipeline-build. Zig version 0.16.0.

=== `python-utils`

There is a `python-utils` directory, which contains some handy quickly coded scripts:
1. `validate-trace.py`: used as a test when introducing big changes in the simulation, it tests basic rules and properties the traces must maintain.
2. `parquet_to_bin.py`: given the sampled datasets from the topology (@apx-topology) converts them into a binary format with monotonic user id.

Dependencies specified in the `uv` project. Python version 3.12.

== `des-ctic-progress`

The `des-ctic-progress` repository contains the successive versions of the simulation, developed incrementally before being consolidated into `des-ctic`. The four versions ---v1 (chronological timelines), v2 (reverse-chronological timelines and sessions), v3 (unlimited posts and refactor), and v4 (final release)--- are described in @apx-impl-version.

== `bskysim-data-analysis`

The `bskysim-data-analysis` repository contains the code that extracts and analyzes the datasets produced by the `des-ctic` repository, in order to calibrate and validate the simulation. It is organized into `experiments/` (the two calibration experiments), `trace-analysis/` (Python and R scripts over the simulation traces), and `performance-analysis/`.

=== Which Warmup
Determines the warm-up length ---the number of ticks the simulation must run before its timelines are saturated and measurement can begin---, concluded at 2,000 ticks. Implemented in `experiments/which-warmup/`. See @sec-cal-warmup.

=== Stability Regime
Verifies that the session layer converges to a stationary online-user fraction regardless of the initial condition, setting the transient and measurement horizons of the final runs. Implemented in `experiments/stable-regime/`. See @sec-exec-stationary.

=== Missing Tail
Fits the power-law tail of the simulated repost cascades (`trace-analysis/python/repost_powerlaw.py`) and compares it against the real data, isolating the systematic lack of large cascades reported in @sec-finding-missing-tail.

=== Performance Analysis
Peak-RAM and time-complexity analysis of the five final runs (10K to 1M users), in `performance-analysis/`. See @sec-results.

== `bsky-data-analysis`

This repository contains all the code used to analyze the Bluesky firehose and calibrate the simulation. Each analysis lives in its own folder ---`eda-raw-dataset/`, `cascade-creation/` and `cascade-metrics/`, `sessions/`, `inter-post-gaps/`, and `post-lifetime/`--- sharing a common database access layer in `running-locally/`.

=== Event Analysis
Exploratory analysis of the raw firehose event stream: event types, users, ratios, and power-law fits, in `eda-raw-dataset/`. See @sec-data-firehose.

=== Structural Virality
Computation of the Wiener-index structural virality of the repost cascades (`cascade-creation` and `cascade-metrics`). See @sec-data-virality.

=== Session Creation
Reconstruction of user sessions from the event stream using Tukey IQR thresholding (`sessions/table_creation/tukey.py`). See @sec-method-session and the comparison against HDBSCAN in @apx-sessions.

=== Session Duration and Inter-Session Time
Per-user maximum-likelihood fitting of the session duration and inter-session gap distributions (`sessions/distribution-fit/`). Requires R in addition to the `uv` project, with the packages `fitdistrplus`, `actuar`, and `evd`. See @sec-cal-sessions.

=== Inter-Post Time
Per-user fitting of the global and within-session inter-post gap distributions (`inter-post-gaps/` and `sessions/inter-post-creation/`), also in R (`fitdistrplus`, `poweRlaw`). See @sec-cal-interpost.

=== Post Lifetime
Computation of the post lifetime ($T_50$, $T_95$, $T_99$ and time-to-peak) from the cascade edges (`post-lifetime/`). See @sec-results.

== `bsky-topology-extraction`

Contains the code that reconstructs the Bluesky follow graph from the firehose and samples the subgraphs the simulation runs on. It is split into three folders.

=== `ingestion`
Parallel Go producer--consumer pipeline (64 producers, 40 consumers) that loads the firehose JSONL files into the StarRocks `bsky_topology.graph_events` table. See @apx-topology.

=== `process-scd2`
Three-phase DuckDB pipeline that turns the event log into SCD2 Parquet tables (`users`, `follow_edges`, `block_edges`) and an indexed `.db` file. See @apx-topology.

=== `sampling-forest-fire`
Go implementation of the Forest Fire sampler @leskovec2006sampling that produces the seven sampled subgraphs. See @sec-data-topology.
