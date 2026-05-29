#import "../utils.typ": *

== `des-ctic` — Simulation engine @soler2025desctic

The simulation (see @sec-design and @sec-impl) lives in `simulation/`. Three versions follow @sec-impl-version:

+ `static-entities/` — v1–v2: reverse-chronological and chronological timeline variants. `zig build` produces both binaries.
+ `dynamic-posts/` — v3: full DES with action-based decisions and paginated post storage.
+ `all-features/` — v4: final version; no `json` config, uses calibrated parameters from @sec-cal-sessions and @sec-calibration-summary. This produced the results in @sec-results and @sec-exec.

Compile with Zig v0.16.0 and `-Doptimize=ReleaseFast`. Depends on `heap/` (a $d$-ary heap library with $O(1)$ intrusive-indexed removal, see @sec-impl-queue and @sec-impl-datastructures), vendored via Zig package manager.

The `trace-analysis/` subfolder contains the pipeline from @sec-exec-pipeline to convert raw `.jsonl` traces into `.parquet` files.

== `bsky-firehose-analysis` — Bluesky data pipeline @soler2025bskydata

Located in `bsky-data-analysis/`. Four analytical projects mirror the platform properties characterised in @sec-data:

+ *Topology:* `topology/` — Firehose ingest (Go), API-based follower crawler, Forest Fire sampling @leskovec2006sampling, and validation.
+ *Sessions:* `sessions/creation-tukey/` — Per-user adaptive Tukey IQR clustering for session boundaries (@sec-cal-sessions). Distribution fitting in `sessions/analysis/fit_distributions.R` for Pareto, lognormal, and Weibull parameters (@sec-cal-dist).
+ *Post lifetime:* `post-lifetime/sql/` — Five-stage SQL pipeline from raw firehose to `post_lifetime` and `post_engagement_events` tables. EDA scripts for temporal decay, time-to-first, and cascade ordering in `post-lifetime/eda/`.
+ *Structural virality:* `structural-virality/` — Wiener index $nu(T)$ of repost cascades @goel2016structural, computed in Go, plotted in Python (@sec-method-des-metrics).
+ *Inter-post gaps:* `inter-post-gaps/` — Distribution fitting for gaps between consecutive posts within sessions (@sec-cal-interpost).

Global EDA: `EDA/run.py` analyses the full firehose (212M records, 28M posts). Full database schema in `docs/DATABASE.md` and @apx-database.
