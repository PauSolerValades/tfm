# Trace Analysis → Real Data Alignment: Problems & Gaps

Two sections in `results.typ` need their methodology aligned with `data.typ` so the presentation's comparison tables stop being weird.

---

## 1. Post Lifetimes

### 1.1 What `data.typ` does

- Population: **all top-level posts** (15.3M), split into **engaged** (7.5M, any engagement with positive lifetime) vs **unengaged** (7.8M, zero engagement)
- Engagement breakdown among engaged: likes 92.7%, replies 35.4%, reposts 33.1%
- **Distribution fitting** on lifetimes: fits Pareto, Weibull, lognormal, exponential via MLE + Vuong's LLR
- Reports a **two-component model**:
  - Body (< 15.6 h, ~75% of engaged): Weibull k = 0.53
  - Tail (> 15.6 h, ~25% of engaged): Pareto α = 2.16
- Reports: median 3.8 h, P₉₉ = 133 h (5.6 days)
- Time unit: **hours**

### 1.2 What `results.typ` does

- Population split: **reposted** vs **not reposted** (a different axis entirely)
- Zero-engagement reported only as % **within zero-repost posts** (29.1% of zero-repost, not of all posts)
- **Summary statistics only**: mean (843 ticks), median (471 ticks)
- Tail described qualitatively: "heavy (power-law)" — **no α fitted**
- Engagement-type breakdown: **not computed** (no % likes, % reposts among engaged)
- Time unit: **ticks** (1 tick = Δₚ = 1 s, but never converted)

### 1.3 Specific mismatches

| Problem | Detail |
|---|---|
| **Wrong denominator** | Slide says "29.1% zero engagement" but that's 29.1% **of zero-repost posts**. True zero-engagement rate across all posts is ~21.8% (74.9% zero-repost × 29.1%). The gap to Bluesky's 50.7% is even bigger than shown. |
| **Different populations** | Simulation splits by reposted/not-reposted; Bluesky splits by engaged/unengaged. They don't overlap cleanly. |
| **Mean vs α** | Slide compares simulation mean (843 ticks) to Bluesky Pareto α (2.16). A location statistic vs a shape parameter. Nonsensical. |
| **No distribution fit** | Simulation never fits distributions to lifetimes. Can't compare α, k, x_min, or say "≈ same" for the tail. |
| **Units invisible** | 471 ticks vs 3.8 h with no conversion. If 1 tick = 1 s, simulation median ≈ 7.8 min vs Bluesky 228 min — **29× difference**. |
| **No match column fillers** | Two rows just say "—" because the data isn't comparable. The table format itself breaks. |

### 1.4 What to rerun / compute

**In the simulation trace analysis** (the Python/R scripts that produce `results.typ` numbers):

1. **Split by engaged/unengaged** (not reposted/not-reposted). "Zero engagement" = 0 likes AND 0 reposts. Compute over ALL posts.
2. **Compute engagement-type breakdown**: among engaged posts, % with ≥1 like, % with ≥1 repost.
3. **Fit distributions to lifetimes**: same pipeline as `fit_powerlaw_lifetimes.py` from the data chapter. Run MLE fits for Pareto, Weibull, lognormal, exponential. Use Vuong's LLR to select best. Report:
   - Best body distribution + parameters
   - Best tail distribution + α + x_min
   - Body/tail cutoff
   - Median, P₉₉ (in both ticks and hours)
4. **Convert ticks → hours** (divide by 3600, since 1 tick = 1 s). Or report both.
5. **Report lifetime statistics for all engaged posts** (not just w/ reposts) to match the Bluesky population.

**After rerunning**, the comparison becomes:

| Metric | Simulation (100K) | Bluesky Data |
|---|---|---|
| % posts with zero engagement | (new) | 50.7% |
| % engaged with ≥1 repost | (new) | 33.1% |
| % engaged with ≥1 like | (new) | 92.7% |
| Tail Pareto α | (new) | 2.16 |
| Body Weibull k | (new) | 0.53 |
| Body/tail cutoff | (new) | 15.6 h |
| Median lifetime (engaged) | (new) | 3.8 h |
| P₉₉ lifetime (engaged) | (new) | 133 h |

Every row now compares the same quantity, same population, same methodology.

---

## 2. Cascade Metrics (Structural Virality + Size/Depth)

### 2.1 What `data.typ` does

- **Cascade definition**: size ≥ 2 (1 repost minimum), N = 4.41M cascades
- **Structural virality** ν via Wiener index: mean 1.35, median 1.00, max 80.7
- Full ν percentiles: P₉₀ = 2.03, P₉₅ = 2.98, P₉₉ = 3.37, P₉₉.₉ = 6.93
- **Three-regime classification**: broadcast (ν = 1.0, 54.7%), mixed (1.0 < ν ≤ 3.0, 42.7%), viral (ν > 3.0, 2.6%)
- **ν by size bucket**: full table with ν mean/median/P₉₀/max per size range
- **Cascade size buckets**: 2, 3, 4–5, 6–10, 11–20, 21–50, 51–100, 101–500, 501–1000, 1001+
- **Depth**: 73.4% depth = 1, max depth 235. Mean/median depth for all cascades: **not reported** (only "median 2, mean 3.1 for viral cascades")
- **Max cascade size**: 12,720

### 2.2 What `results.typ` does

- **Cascade definition**: size ≥ 3 (2 reposts minimum). **Threshold mismatch with data.**
- **Structural virality** ν: mean 1.90, median 1.67, max 26.9. Full percentiles in `tbl-virality-dist`: P₂₅ = 1.33, P₇₅ = 2.21, P₉₅ = 3.33
- **Three-regime classification**: not reported as such, but % minimal (ν ≤ 1.34) = 39.4%, % branching = 45.8%. **Missing direct "broadcast/mixed/viral" table.**
- **Cascade size**: mean 5.3, median 4, max 217
- **Size thresholds**: % N ≥ 10 = 9.3%, % N ≥ 50 = 0.02%
- **Depth**: mean 2.9, max depth 70. **Missing: % depth = 1.**
- **Depth-by-size**: full table with mean ν, mean depth, mean max-out per size bucket

### 2.3 Specific mismatches

| Problem | Detail |
|---|---|
| **Size threshold mismatch** | Simulation uses size ≥ 3, Bluesky uses size ≥ 2. ~2.41M Bluesky cascades (54.7%) are size 2 and invisible in simulation terms. All % metrics shift. |
| **Missing % broadcast** | Simulation reports "% minimal (ν ≤ 1.34)" but Bluesky reports "% broadcast (ν = 1.0)". The simulation's minimum ν is ~1.33 (tree reconstruction artifact with 2 reposts). Need equivalent bucket. |
| **Missing three-regime table** | Bluesky has a clean broadcast/mixed/viral classification. Simulation doesn't. Easy to add. |
| **Missing mean/median depth for Bluesky** | Data chapter says "73.4% depth 1" and "median 2, mean 3.1 for viral" but never reports mean/median for all cascades. Simulation has mean 2.9 but nothing to compare against. |
| **Missing cascade size percentiles for Bluesky** | Simulation has mean/median/max size. Bluesky has the bucket table but never computes mean/median directly. Computable from the buckets, but not reported. |
| **% size ≥ 50 mismatch** | Simulation: 0.02%. Bluesky: ~2.1%. That's **100× different**. Currently invisible because Bluesky doesn't compute this directly. |

### 2.4 Computable from existing Bluesky data (no rerun needed)

From `tbl-virality-by-size` bucket counts, approximate:

| Metric | Bluesky (approximate) |
|---|---|
| Mean cascade size | ~12.2 |
| Median cascade size | 2 (54.7% have size 2) |
| % size ≥ 10 | ~10.0% |
| % size ≥ 50 | ~2.1% |
| % size ≥ 100 | ~1.2% |

But you still need **mean/median depth for all Bluesky cascades** — requires a query against the cascade tree data.

### 2.5 What to rerun / compute

**In the Bluesky data pipeline** (a quick SQL/Go query):

1. **Compute mean/median cascade depth** for all 4.41M cascades (not just viral ones). Already stored during tree construction in the Go pipeline.
2. **Compute cascade size mean/median directly** (not from bucket midpoints). Trivial from the same data.
3. **Compute % size ≥ 10, ≥ 50, ≥ 100** directly.

**In the simulation trace analysis:**

1. **Lower cascade threshold to size ≥ 2** to match Bluesky. This means counting cascades with ≥1 repost, not ≥2.
2. **Add % depth = 1** (all reposters are direct). Already stored (max depth per cascade), just needs counting.
3. **Add three-regime classification**: broadcast (ν = 1.0), mixed (1.0 < ν ≤ 3.0), viral (ν > 3.0). Use the same ν = 1.0 definition even though the simulation's minimum is ~1.33 — note the discrepancy but report the bucket anyway (it'll be ~0%).
4. **Compute % size ≥ 10, ≥ 50, ≥ 100** to match Bluesky thresholds.

**After rerunning**, the comparison becomes:

| Metric | Simulation (100K) | Bluesky Data | Match? |
|---|---|---|---|
| **Cascade size** | | | |
| Cascades (size ≥ 2) | (new) | 4.41M | — |
| Mean size | (new, ≥2 threshold) | ~12.2 | Lower |
| Median size | (new, ≥2 threshold) | 2 | Higher |
| Max size | (new, ≥2 threshold) | 12,720 | Much lower |
| % size ≥ 10 | (new) | ~10.0% | ? |
| % size ≥ 50 | (new) | ~2.1% | Much lower |
| **Cascade depth** | | | |
| Mean depth | 2.9 | (new) | ? |
| % depth = 1 | (new) | 73.4% | Much lower |
| Max depth | 70 | 235 | Lower |
| **Structural virality** | | | |
| Mean ν | 1.90 | 1.35 | Higher |
| Median ν | 1.67 | 1.00 | Higher |
| P₉₅ ν | 3.33 | 2.98 | ≈ same |
| Max ν | 26.9 | 80.7 | Lower |
| % broadcast (ν = 1.0) | (new, ≈0%) | 54.7% | Missing |
| % mixed (1 < ν ≤ 3) | (new) | 42.7% | ? |
| % viral (ν > 3) | (new) | 2.6% | ? |

---

## 3. Summary of reruns needed

| Pipeline | What | Effort |
|---|---|---|
| **Simulation trace analysis** | Split by engaged/unengaged; fit lifetime distributions; convert ticks→hours; compute engagement-type breakdown; add % depth=1; add three-regime ν classification; lower cascade threshold to ≥2; compute % size thresholds | **Big** — new fitting code + reprocess existing traces |
| **Bluesky data pipeline** | Compute mean/median depth for all cascades; compute mean/median/percentile cascade sizes directly | **Small** — one Go query on existing data |
| **Presentation slide** | Rewrite both tables with aligned metrics | **Trivial** once numbers exist |

---

## 4. Root cause

The simulation analysis was written as a self-contained results chapter (means, medians, qualitative descriptions) while the data chapter was written as a rigorous statistical characterisation (distribution fits, parameters, buckets, regime classifications). To compare them, the simulation chapter needs to adopt the data chapter's methodology. Not the other way around — the data is ground truth.
