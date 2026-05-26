#import "@preview/lovelace:0.3.0": *
#import "utils.typ": todo, comment

This chapter presents the trace analysis of the agent-based simulation at three network scales: 100K, 500K, and 1M nodes. The analysis follows the metric framework defined in @sec-method-des-metrics, comparing batch-means across replications and relating emergent macro-level dynamics to the model's micro-parameters.

== Stationary Behaviour

The simulation must first demonstrate that it reaches a stationary state after the 1000-tick warm-up phase. The two primary indicators are the average online fraction and the percentage of sessions that end with an empty timeline (content starvation).

@tbl-stationary summarises the batch means across all replicates for each network size. Standard deviations are reported as $pm 1 sigma$ across runs.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K* ($n=1600$)], [*500K* ($n=136$)], [*1M* ($n=10$)],
    table.hline(stroke: 0.5pt),
    [Online fraction $E[|cal(O)|/N]$], [$11.54% pm 0.10%$], [$12.56% pm 0.06%$], [$11.33% pm 0.07%$],
    [Empty-timeline exits], [$50.9% pm 0.4%$], [$45.9% pm 0.3%$], [$53.0% pm 0.3%$],
    [Median backlog at session end], [$0.03 pm 0.23$], [$10.42 pm 1.00$], [$0.00 pm 0.00$],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Batch means of stationary-state indicators. 500K is the healthiest configuration: highest online fraction, lowest starvation, and non-zero median backlog.]
) <tbl-stationary>

*Finding:* the 500K network is the Goldilocks configuration. Both extremes underperform — 100K suffers from insufficient absolute content volume, while 1M suffers from content dilution (the same total post-creation rate spread across ten times more consumers). The online fraction is stable across scales ($approx 11.5%$), indicating that the Activity-Driven dynamics reach equilibrium independent of network size, but the health of that equilibrium — measured by empty-timeline exits — is non-monotonic.

=== Per-Session Engagement

With the session pairing implemented via `out_sessions.parquet`, we can quantify exactly how many timeline encounters a user experiences per session. @tbl-session-actions shows the breakdown by session duration bucket for the 1M network.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Duration bucket*], [*Sessions*], [*Mean actions*], [*Mean reposts*], [*Empty exit %*],
    table.hline(stroke: 0.5pt),
    [$< 10$ ticks], [$653$K], [0.41], [0.005], [85.3%],
    [$10$–$60$ ticks], [$665$K], [6.59], [0.079], [63.0%],
    [$60$–$300$ ticks], [$740$K], [34.5], [0.413], [25.7%],
    [$300+$ ticks], [$193$K], [171.1], [2.057], [18.6%],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Per-session engagement metrics by duration bucket (1M network, 1 run). The boredom mechanism dominates short sessions: 85% of sessions under 10 ticks end with zero backlog. Long sessions still show 19% empty exits.]
) <tbl-session-actions>

The boredom mechanism (exit on empty timeline) is the dominant session termination cause: 53.4% of all sessions end with backlog zero. Sessions with backlog at end last $9.5 times$ longer (median 114 vs 12 ticks) and see $3.6 times$ more posts (50 vs 14). The median session sees only 9 timeline encounters total.

*Finding:* the simulation is content-starved. Approximately 22% of sessions have zero actions — the user comes online and immediately goes offline because no posts have propagated to their timeline yet. This is a direct consequence of the design decision to clear timelines on session end (@sec-design-sources-sessions): every session starts with an empty feed, and the user must wait for content to arrive via propagation delays.

== Queued Content Congestion

=== Backlog Distribution

#todo[Insert histogram: backlog at session end across runs for 500K. Show the spike at zero and the heavy tail.]

The median backlog at session end is zero for 100K and 1M, and 10 for 500K. This is a direct consequence of the empty-timeline exit: users who exhaust their feed leave immediately, so the backlog distribution is censored — we never observe what the backlog *would have been* had they stayed. The non-zero median at 500K indicates that at this scale, content arrives fast enough that many sessions end naturally (Pareto duration expires) rather than by starvation.

=== Backlog and Session Duration

@tbl-backlog-duration shows that backlog at session end and duration are tightly coupled.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Duration bucket*], [*Mean backlog at end*], [*Empty exit %*], [*Median actions*],
    table.hline(stroke: 0.5pt),
    [$< 10$ ticks], [125], [85%], [0],
    [$10$–$60$ ticks], [404], [63%], [5],
    [$60$–$300$ ticks], [1204], [26%], [30],
    [$300$–$1K$ ticks], [2238], [17%], [—],
    [$> 1K$ ticks], [3425], [29%], [—],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Backlog at session end by duration bucket. Content availability grows monotonically with session length — users who stay longer have more to consume.]
) <tbl-backlog-duration>

=== Backlog at Session Start

A critical finding: *backlog at session start is always zero*. The simulation clears timelines on session end (`HandleGoOffline` in @sec-design-sources-sessions). This means every new session begins with an empty feed. Combined with the propagation delay ($Delta_p = 1$ tick), users experience a "cold start" where they must wait for content to arrive. In real social media, timelines persist across sessions — the user returning after 8 hours sees accumulated content. This design choice amplifies the starvation dynamic.

== Lifetimes and Scale

=== Power-Law Exponents

The power-law exponent $gamma$ of the repost cascade size distribution is estimated via discrete MLE @clauset2009powerlaw with $x_min = 1$. @tbl-gamma summarises the batch means.

#figure(
  table(
    columns: 3,
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Network*], [*$gamma$*], [*$sigma_gamma$*],
    table.hline(stroke: 0.5pt),
    [100K], [1.730], [0.009],
    [500K], [1.723], [0.004],
    [1M], [1.736], [0.002],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Batch-means of $gamma$ across network sizes. The exponent is scale-invariant at $gamma approx 1.73$. Standard deviation decreases with more replications (1600 at 100K, 10 at 1M).]
) <tbl-gamma>

*Finding:* $gamma approx 1.73$ is a universal constant of the simulation at this configuration. It does not depend on network size, seed, or replication count. The empirical $gamma$ for real Bluesky repost cascades is $2.21$ (@tbl-powerlaw-counts) — significantly steeper. The simulation's heavier tail ($gamma = 1.73$ vs real $2.21$) means rare large cascades are *more common* in simulation than in reality. This is expected given the homogeneous policy: in the real network, most users never repost, while the simulation assigns $p_"repost" = 0.012$ uniformly. A heterogeneous policy (power users with higher $p_"repost"$, casual users with near-zero) would steepen the tail.

=== Post Lifetime Distribution

The post lifetime $tau_"raw"$ (time from creation to last engagement) and the normalized lifetime $tau_"norm" = tau_"raw" / Delta_p$ (with $Delta_p = 1$) are computed for all $approx 10^5$–$10^7$ posts created during steady state. @tbl-lifetime summarises.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Posts with any reposts], [25.1%], [21.3%], [19.4%],
    [Mean lifetime (w/ reposts)], [843], [984], [1107],
    [Median lifetime (w/ reposts)], [—], [613], [750],
    [Posts with zero engagement], [29.1%], [35.4%], [38.7%],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Post lifetime statistics. Larger networks produce longer-lived posts but fewer posts get any reposts. Zero-engagement posts increase with network size — content dilution.]
) <tbl-lifetime>

*Finding:* Post lifetimes grow with network size (843 $arrow.r$ 984 $arrow.r$ 1107 ticks), but the fraction of posts that get any reposts *declines* (25% $arrow.r$ 21% $arrow.r$ 19%). More users means more content, but also more competition for attention. The zero-engagement fraction rises from 29% to 39%.

#todo[Insert scatter plot: lifetime_norm vs total_reposts. Does a post need to get big to live long, or can small posts persist?]

=== Burstiness Analysis

The burstiness parameter $B = (sigma_tau - mu_tau) / (sigma_tau + mu_tau)$ is computed from inter-repost times. $B in [-1, 1]$: $B = 1$ is perfectly bursty, $B = 0$ is Poisson, $B = -1$ is perfectly regular.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Repost count*], [*Mean $B$*], [*$sigma_B$*], [*$n$ (1M)*],
    table.hline(stroke: 0.5pt),
    [1], [0.000], [0.000], [1.04M],
    [2–4], [$-0.635$], [0.450], [0.65M],
    [5–9], [$+0.140$], [0.204], [0.21M],
    [10–49], [$+0.381$], [0.151], [0.13M],
    [50+], [$+0.521$], [0.112], [4.7K],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Burstiness by repost count. Small cascades are anti-bursty ($B < 0$): reposts are spread out. Large cascades ($50+$ reposts) are bursty ($B approx +0.5$): reposts cluster together. Viral cascades accelerate; small cascades trickle.]
) <tbl-burstiness>

*Finding:* Burstiness transitions from negative to positive as cascade size grows. Small cascades (2–4 reposts) have $B approx -0.63$ — reposts are spaced farther apart than a Poisson process, consistent with users encountering the post independently over time. Large cascades ($50+$ reposts) have $B approx +0.52$ — reposts cluster, indicating that once a post reaches critical mass, repost events trigger each other in rapid succession.

== Cascades Analysis

=== Batch-Means of Cascade Metrics

@tbl-cascade-batch summarises the cascade morphology metrics across all replications.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Cascades with size $>= 3$], [26.5M], [10.5M], [1.32M],
    [Mean cascade size $N$], [5.26], [6.10], [6.30],
    [Median cascade size], [4], [4], [4],
    [Max cascade size], [217], [953], [1632],
    [Mean depth $d_"max"$], [2.87], [3.31], [3.55],
    [Max depth], [70], [106], [87],
    [Mean virality $nu$], [1.90], [2.05], [2.10],
    [Max virality], [26.9], [29.8], [34.9],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Batch-means of cascade morphology metrics. The maximum cascade size grows with network scale, but the median cascade (4 nodes) is independent of network size.]
) <tbl-cascade-batch>

=== Viral Post Percentages

@tbl-viral-pct shows the fraction of cascades exceeding various size thresholds.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Threshold*], [*100K*], [*500K*], [*1M*],
    table.hline(stroke: 0.5pt),
    [Size $>= 10$], [13.6%], [13.7%], [13.6%],
    [Size $>= 20$], [1.0%], [3.3%], [3.9%],
    [Size $>= 50$], [0.02%], [0.22%], [0.47%],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Percentage of cascades above size thresholds. The basic viral rate ($>= 10$) is constant at $approx 13.6%$ across scales. The tail gets fatter with network size: large cascades become more common in bigger networks.]
) <tbl-viral-pct>

=== Depth–Size Scaling

Cascade depth grows sub-linearly with cascade size (@tbl-depth-size).

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Size bucket*], [*Mean depth*], [*Mean virality*], [*Mean max-out*],
    table.hline(stroke: 0.5pt),
    [3–9], [2.8], [1.7], [1.4],
    [10–49], [7.9], [4.3], [5.5],
    [50–99], [18.7], [8.1], [22.3],
    [100–499], [28.4], [10.3], [49.6],
    [500+], [47.7], [9.8], [317.2],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Depth–size scaling for 1M cascades. Depth grows sub-linearly: the largest cascades (500+ nodes) have moderate depth (48 hops) but extreme branching (mean out-degree 317). Viral cascades are wide-branching, not deep chains.]
) <tbl-depth-size>

*Finding:* The largest cascades achieve their size through branching, not depth. A cascade of 500+ nodes has mean max-out-degree 317 (317 direct children on a single node) but depth only 48. This is consistent with broadcast-dominant diffusion: one influential reposter fans out to hundreds of followers, who each fan out to a few more, but the chain rarely goes deep.

=== Structural Virality Distribution

#todo[Insert histogram: struct_virality distribution. Show the spike at ν = 1.33 (minimal chain) and the heavy tail.]

40% of cascades are minimal ($nu <= 1.34$): pure chains with no branching. 35–46% of cascades have any branching at all ($"max_out_degree" >= 2$). The mean virality is 1.90–2.10, but for cascades with size $>= 10$, it rises to 4.0–4.4.

*Finding:* Simulated virality ($nu_"mean" approx 2.1$) is *higher* than real Bluesky virality ($nu_"mean" = 1.35$, @tbl-virality-stats). However, the real network has 54.7% of cascades at exactly $nu = 1.0$ (pure broadcast — every reposter saw the original post directly), while the simulation has 40% at $nu <= 1.34$ (slightly above broadcast because the propagation tree forces at least one hop through the author). The simulation misses the "direct repost" mechanism: in Bluesky, a user can repost the original post directly without going through an intermediate, while in the CTIC model every repost must propagate through the network graph hop-by-hop. This inflates simulated virality.

=== Influencer Effect

@tbl-influencer shows cascade metrics stratified by the author's follower count.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Author followers*], [*Cascades*], [*Mean size*], [*Mean depth*], [*Mean $nu$*],
    table.hline(stroke: 0.5pt),
    [Zero], [579K], [5.21], [2.87], [1.89],
    [1–9], [3.18M], [5.27], [2.90], [1.91],
    [10–99], [7.05M], [5.29], [2.91], [1.91],
    [100–999], [8.06M], [5.24], [2.89], [1.90],
    [1K–10K], [7.33M], [5.26], [2.89], [1.90],
    [10K+], [289K], [5.42], [2.97], [1.94],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Cascade metrics by author follower count (100K network). Cascade size, depth, and virality are nearly identical across all follower-count buckets. There is no influencer effect.]
) <tbl-influencer>

*Finding:* There is no influencer effect. A post from a user with 10K+ followers has mean cascade size 5.42 vs 5.21 for a zero-follower user — a 4% difference. The cascade does not care who started it; it only depends on the repost probability ($p_"repost" = 0.012$) of whoever encounters it downstream. The initial follower count provides a larger first-hop audience, but with only 1.2% of followers reposting, the cascade dies or lives based on the subsequent propagation structure, not the seed. This is a direct consequence of the homogeneous behavioral policy.

#todo[Discuss: heterogeneous policies (power users with higher p_repost) would create an influencer effect. This is a calibration target for future work.]

== Micro-Macro Coupling

The three coupling ratios defined in @sec-method-des-metrics relate the model's input parameters to its emergent dynamics.

=== Pace Ratio

$
rho = frac(tau_"action"){tau_"repost"} = frac(3.0)(3.0 / 0.012) = 0.012
$

Users interact $1/rho approx 83$ times more frequently than they repost. This is purely a consequence of the policy weights: $p_"repost" = 0.012$ means one repost per 83 timeline encounters, and the inter-action time is Exponential(3). In the real Bluesky data, the ratio of likes to reposts is $161.7 times 10^6 : 26.4 times 10^6 = 6.13 : 1$ (@tbl-records-collections). The simulation's 83:1 ratio is far more extreme — it overstates passivity by an order of magnitude.

=== Session Persistence

$
pi = frac(tau_"post"){tau_"session"}
$

From sample runs:
- 1M: $pi = 1107 / 115 = 9.62$
- 500K: $pi = 984 / 129 = 7.64$

A post outlives an average session by 8–10×. The user logs in, scrolls for $approx 2$ minutes, and logs out — but the post they liked continues receiving engagement for $approx 16$ more minutes. Content has inertia that sessions do not.

#todo[Compute batch means of π across all runs once out_sessions.parquet is available for all sizes.]

=== Saturation Index

$
sigma = frac(tau_"between reposts"){tau_"offline"}
$

From sample runs, the mean offline gap is $approx 450$ ticks. The global repost rate is approximately one repost per 250 ticks per online user, but with only 11% of users online the global inter-repost interval is far larger. $sigma << 1$: content arrives slower than users return — this is a mathematical restatement of content starvation.

#todo[Compute batch means of σ across all runs once out_sessions.parquet is available.]

== Simulation versus Reality

@tbl-sim-vs-real compares the key metrics between the simulation output and the Bluesky firehose data (@sec-data).

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*Simulation (1M)*], [*Bluesky data*], [*Agreement*],
    table.hline(stroke: 0.5pt),
    [$gamma$ (repost power-law)], [1.74], [2.21], [Sim tail heavier],
    [$nu$ mean], [2.10], [1.35], [Sim more viral],
    [$nu$ median], [1.67], [1.00], [Sim more viral],
    [Posts with any reposts], [19.4%], [28.9%], [Sim fewer reposts],
    [Policy like:repost ratio], [0.188 : 0.012 $approx$ 15.7 : 1], [161.7M : 26.4M $approx$ 6.1 : 1], [*Not directly comparable*],
    [Max cascade size], [1632], [$> 10^4$], [Sim smaller max],
    [Max $nu$], [34.9], [80.7], [Sim less extreme],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Simulation vs. Bluesky reality. The simulation overstates passivity (15.7:1 like:repost vs 6.1:1 real), produces more viral average cascades but a thinner viral tail, and has fewer posts getting any reposts.]
) <tbl-sim-vs-real>

=== Discussion

Three major discrepancies emerge:

1. *Passivity is overstated but not directly comparable.* The simulation's policy ratio ($p_"like" : p_"repost" = 0.188 : 0.012 approx 15.7 : 1$) is the per-encounter probability ratio — given a user sees a post, they are 15.7× more likely to like than repost. The real Bluesky ratio (161.7M likes : 26.4M reposts $approx$ 6.1 : 1) is a global event-count ratio, which conflates the per-encounter probability with how many posts each user sees. A proper comparison would require normalising by impressions (posts seen), which the simulation traces but the firehose data does not. Qualitatively, the simulation does appear more passive: only 19.4% of posts get any reposts vs 28.9% in reality, and 35–39% get zero engagement vs 50.7% in reality. The policy weights ($p_"ignore" = 0.80$, $p_"like" = 0.188$, $p_"repost" = 0.012$) were intended as calibration targets but differ from the calibration file.

2. *Virality is structurally inflated.* The CTIC model forces all reposts through propagation trees, while real Bluesky allows direct reposts that bypass the tree. This makes simulated cascades appear more viral (higher $nu$) than real ones, even though the actual depth and branching are modest.

3. *Content starvation is a design artifact.* The simulation's decision to clear timelines on session end (@sec-design-sources-sessions) combined with the boredom mechanism (exit on empty timeline) creates a self-reinforcing starvation cycle that is not present in real platforms, where timelines persist across sessions and users typically have content waiting.

#todo[Discuss: what parameter changes would bring simulation closer to reality? Recalibrated policy weights, heterogeneous user policies, persistent timelines, and direct repost mechanism.]

== Session Duration vs Intended Pareto

Each user is assigned a Pareto(s, k) distribution for session duration at initialisation, with parameters randomly drawn (with replacement) from the 10,000 empirically-fitted pairs in `params/session_duration_params.txt`. The *intended* duration is sampled from this distribution at session start; the *actual* duration is whichever comes first: the Pareto expiry or the timeline running empty (boredom exit).

@tbl-pareto-compare compares the intended Pareto mixture (sampled from the input parameters) against the empirical session durations from `out_sessions.parquet` for the 1M network.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Percentile*], [*Intended Pareto*], [*All sessions*], [*Zero-backlog*], [*Non-zero-backlog*],
    table.hline(stroke: 0.5pt),
    [$P_5$], [1], [2], [1], [3],
    [$P_{25}$], [9], [8], [2], [14],
    [$P_{50}$ (median)], [31], [38], [12], [105],
    [$P_{75}$], [100], [125], [45], [246],
    [$P_{90}$], [313], [270], [116], [428],
    [$P_{95}$], [726], [429], [199], [590],
    [$P_{99}$], [4,142], [1,194], [552], [1,478],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Session duration percentiles: intended Pareto mixture vs empirical. The boredom mechanism does not shift the median (31 $arrow.r$ 38) but severely truncates the tail — $P_{99}$ drops from 4,142 to 1,194 ticks, a 3.5× reduction. Zero-backlog sessions are an order of magnitude shorter at every percentile.]
) <tbl-pareto-compare>

*Finding:* The boredom mechanism does *not* uniformly shrink sessions. At the median, empirical durations (38 ticks) are actually *longer* than intended (31 ticks). This is because sessions that have content outlast their Pareto expiry — the user keeps scrolling as long as there is content. However, the *tail is heavily truncated*: the intended $P_{99}$ of 4,142 ticks is never observed; the empirical $P_{99}$ is 1,194 ticks (3.5× reduction). The Pareto allows very long sessions, but in practice the timeline runs dry first.

Zero-backlog sessions tell the other half of the story: median 12 ticks vs intended 31 — a 2.6× reduction. When the timeline is empty, users leave almost immediately regardless of their Pareto duration. These two effects balance at the aggregate median (38 $approx$ 31), masking the underlying bimodality.

#todo[Insert QQ-plot: intended Pareto quantiles vs empirical session duration quantiles. Show the departure from the diagonal at high quantiles. Colour points by zero-backlog vs non-zero-backlog.]

== Per-User Behavioural Heterogeneity

#todo[Aggregate `out_sessions.parquet` into per-user summaries via `group_by(sim_id, user_id)`. Key questions: (1) Does the boredom burden fall uniformly, or do some users consistently starve while others thrive? Plot per-user boredom ratio (fraction of sessions ending empty) as a histogram. (2) What is the Gini coefficient of reposts across users — are reposts concentrated on a few power users? (3) Scatter: per-user mean session duration vs per-user total reposts — do active users stay online longer? This analysis requires the completed `out_sessions.parquet` for all runs, which is currently processing.]

== Analytical Starvation Bound

#todo[Deriving a closed-form expectation for empty-timeline probability is impractical due to the random session scheduling (Pareto durations sampled per user) and the non-Poisson propagation process. However, a back-of-envelope upper bound can be obtained: if each user creates posts at rate $lambda_c$ and there are $N$ users with online fraction $f$, the global post creation rate is $f N lambda_c$. Each online user consumes posts at rate $1/tau_a$, so the per-user content arrival rate from the network is approximately $f N lambda_c / N = f lambda_c$. With $lambda_c$ from the warmup inter-creation time ($
