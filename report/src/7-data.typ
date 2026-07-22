#import "utils.typ": todo, comment, flex-caption

#todo[Rewrite this header when the actual section is done]
This chapter describes the Bluesky Firehose dataset —-its structure, content, and the statistical properties of the content it carries. The post lifetime dynamics and structural virality are characterised here as properties of the platform itself, and described accordingly to Methodology @sec-method-des-metrics. The translation of these findings into simulation calibration parameters is deferred to @sec-calibration. The technology stack used throughout the data pipeline is documented in @apx-software-stack.

== Firehose Data Description
<sec-data-firehose>

The Bluesky Firehose is a continuous stream of all public AT Protocol events emitted by the network. The dataset contains all registered events from April 11th to 17th of 2026, six days of events.

@fig-eventtype-dist shows the distribution of the top 14 event types, which represent over 99.9% of all events. A full list of all the events can be found in @anx-data-eventlist.

#figure(
  image("../images/data/61_eventtype_distribution.png", width: 100%),
  caption: flex-caption(
    [Distribution of the top 14 firehose event types.],
    [Distribution of the top 14 event types in the Bluesky firehose. Events below 0.1% are omitted. See @tbl-full-event-types for the full breakdown.],
  )
) <fig-eventtype-dist>

As it can be seen, the majority of events on Bluesky are liking a post (`feed_like_create` 66.4%), reposting a post (`feed_repost_create` with 10.6%) and creating a post (`post_top` + `post_reply` with 11.7%). Specifically, the top 5 events represent a 95.5% of total events. Despite all other events being negligible, they act as a proxy for when a user is online, which is the information needed to define the sessions #todo[cite the report], therefore non event type will be excluded from the data.

There are a total of 3.08 million distinct users in the dataset, and events are not uniformly distributed among them. Specifically, the distributions of events per user, events per user in a day and events per user in an hour, follow a lognormal distribution as it can be seen in @fig-userevent-dist (see @anx-data-eventperuserfitting for the reasons and methodology of the fitting).

#figure(
  image("../images/data/62_ecdf_userevents.png", width: 100%),
  caption: flex-caption(
    [[ECDF with fitted lognormals for events per user, per active day, and per active hour.]],
    [Distribution of events per user (blue), events per user per hour (green) and events per user per day (yellow). Parameters: events per user $mu = 2.40$, $sigma = 1.85$, events per active day $mu = 1.43$, $sigma = 1.28$, events per active hour $mu = 0.94$, $sigma = 0.89$.],
  )
) <fig-userevent-dist>

This proves that there are an enormous quantity of users with both very few events in general in the dataset. In order to obtain more informative data, the users with less than two $(<=2)$ events per day, representing a 29% of distinct users out of the dataset (2.19 million users). 

#comment[Here we could enter into a lot of cool things but that kinda makes no sense to do due to space constraints. EG
- user characterization for time
- user characterization for most common type of event
- *user characarteization for types of events (more post creation, more liking, more reposting)*
]

== Post Lifetime Analysis
<sec-data-lifetime>

#comment[
  This is how this session should unfold: 
  1. Explain which quantities are important and why
  2. Explain (defer to appendix if needed) the datasets (which are the same as the traces)
  3. Present the actual values of the metrics.

  Here is the first time we hear talk about post lifetime, we have to introduce the reader to what, why and how.
]

Whereas session analysis is needed for the calibration, we will compute the quantities of interest of the simulation, to compare them with the data real life simulation data. This section studies the lifetime of $15.3 times 10^6$ top-level posts in the firehose snapshot (posts with `reply_root_uri IS NULL`).

=== Engagement Counts

A striking 50.7% of posts receive no engagement at all. Of engaged posts, likes are the most common (92.7%), followed by replies (35.4%) and reposts (33.1%). The Python script `eda/fit_powerlaw_counts.py` fits a discrete power-law via MLE with KS-based $x_min$ selection and compares against lognormal, Weibull, and exponential alternatives via Vuong's LLR test.

For each engagement type, the counts in the tail follow a discrete power-law (@tbl-powerlaw-counts). The power-law is strongly favoured over all alternatives: Vuong's $R$ values range from $+2,933$ (replies vs lognormal) to $+85,822$ (combined vs exponential), with $p < 0.001$ throughout.

#todo[DO NOT TRUST THIS DATA, ALL WRONG]
#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Type*], [*$alpha$*], [*$x_min$*], [*$n_"tail"$*], [*KS*], [*$p$*],
    table.hline(stroke: 0.5pt),
    [Reposts], [2.21], [84], [30,610], [0.0145], [1.00],
    [Likes], [2.15], [127], [112,443], [0.0093], [1.00],
    [Replies], [2.26], [42], [9,206], [0.0273], [1.00],
    [Combined], [2.14], [152], [115,128], [0.0087], [1.00],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Discrete power-law fit on engagement counts.],
    [Discrete power-law fit on engagement counts. All four pass the bootstrap goodness-of-fit test ($p > 0.05$). $alpha approx 2.15$ lies in the finite-mean, infinite-variance regime — engagement is extremely concentrated on very few posts.],
  )
) <tbl-powerlaw-counts>

So, its safe to say that (and consistently with the literature) post lifetimes do follow a power-law.

#figure(
  image("../images/data/6-3_engagement_counts_ccdf.png", width: 90%),
  caption: flex-caption(
    [Complementary CDF of engagement counts.],
    [Complementary CDF of engagement counts for reposts, likes, and replies. All three decay as straight lines in log-log space — the hallmark of a power-law. Generated by `fit_powerlaw_counts.py`.],
  )
) <fig-powerlaw-counts>

=== Lifetime Distribution

#todo[This is stupid, just present the proper h(t) computed with the R package]

*Question:* how long does a post stay alive? Lifetime is measured as $t_"last" - t_"created"$ for the $7.5 times 10^6$ posts that receive any engagement with positive lifetime.

The second question we have to ask about the data is the time a post stays alive. Lifetime of a post is defined as $t_"last" - t_"created"$ for the $7.5 times 10^6$ posts that receive any engagement with positive lifetime.

The @tbl-lifetimes-fit shows the result of fitting four continuous distributions over the posts lifetimes. The lifetime exhibits a two-component structure: the body (lifetimes $< 15.6$ h, $approx 75$% of engaged posts) is best fit by a Weibull with shape $k = 0.53$; the tail ($> 15.6$ h, $approx 25$% of engaged posts) follows a Pareto with $alpha = 2.16$. The median lifetime is 3.8 h, but $P_{99}$ reaches 133 h (5.6 days).

#figure(
  table(
    columns: 4,
    align: (center, left, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Rank*], [*Distribution*], [*Log-likelihood*], [*Parameters*],
    table.hline(stroke: 0.5pt),
    [1], [Pareto (tail)], [$-23.8 times 10^6$], [$alpha = 2.16$, $x_min = 15.6$ h],
    [2], [Weibull], [$-84.7 times 10^6$], [shape $= 0.53$, scale $= 9.4$ h],
    [3], [Lognormal], [$-85.3 times 10^6$], [$sigma = 2.61$, $mu = 9.00$],
    [4], [Exponential], [$-88.8 times 10^6$], [scale $= 14.2$ h],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Distribution fit on post lifetimes.],
    [Distribution fit on post lifetimes. Pareto is best for the tail ($> 15.6$ h). Weibull (shape 0.53) best describes the body. Exponential is a poor fit — lifetimes are not memoryless.],
  )
) <tbl-lifetimes-fit>

#figure(
  image("../images/data/6-3_lifetimes_ccdf.png", width: 90%),
  caption: flex-caption(
    [Combined post lifetime CCDF with distribution fit overlays.],
    [Combined post lifetime CCDF with Pareto, Weibull, and lognormal fit overlays. The Pareto fit captures the heavy tail; Weibull (shape 0.53) captures the body. Generated by `fit_powerlaw_lifetimes.py`.],
  )
) <fig-lifetimes-ccdf>

The Weibull shape $k = 0.53 < 1$ implies a decreasing hazard rate: a post is actually less likely to die the longer it has been alive, consistent with rich-get-richer dynamics. For simulation, the two-component model is the recommended calibration target.

=== Temporal Decay

Does a post, within its lifetime, within a post's lifetime, receive all its engagement evenly in time or cluster early? The script `eda/temporal_decay.py` fits $N(t) prop t^beta$ — the cumulative number of events as a function of time since creation — per-post on a sample from four engagement-volume buckets.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Engagement bucket*], [*$n$*], [*Median $beta$*], [*Mean $beta$*], [*Std $beta$*],
    table.hline(stroke: 0.5pt),
    [20–99 events], [98], [0.49], [0.57], [0.27],
    [100–999], [99], [0.49], [0.53], [0.22],
    [1K–10K], [99], [0.52], [0.60], [0.25],
    [10K+], [99], [0.61], [0.64], [0.18],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Per-post temporal decay exponent $beta$ by engagement volume.],
    [Per-post temporal decay exponent $beta$ by engagement volume. All $beta$ values are well below 1 — engagement always decelerates. Higher-engagement posts spread events more evenly (higher $beta$), but no post in the sample showed linear or accelerating engagement.],
  )
) <tbl-temporal-decay>

All $beta$ values are well below 1: engagement always decelerates. However, $beta$ *increases with volume* — viral posts ($10K+$ events) spread engagement more evenly over time than typical posts. For simulation, sample $beta$ from $cal(N)(0.49, 0.27)$ for typical posts and $cal(N)(0.61, 0.18)$ for high-engagement posts.

The aggregate $beta$ (pooling all 3,000 posts then fitting) is 0.34 — substantially lower than any per-post median. This is a classic ecological fallacy: the aggregate curve is pulled down by the fact that most posts die quickly. The per-post distributions are the relevant calibration target.

=== Time-to-First Engagement

In general, how long until the first repost, like, or reply arrives after a post is created? @tbl-time-to-first shows the percentiles.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Percentile*], [*First repost*], [*First like*], [*First reply*],
    table.hline(stroke: 0.5pt),
    [$P_1$], [9.7 s], [6.4 s], [*0.9 s*],
    [$P_{50}$ (median)], [13.3 min], [5.6 min], [5.9 min],
    [$P_{95}$], [14.9 h], [8.0 h], [9.4 h],
    [$P_{99}$], [49.1 h], [30.0 h], [32.7 h],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Time-to-first-engagement percentiles.],
    [Time-to-first-engagement percentiles. Replies are the fastest ($P_1 = 0.9$ s, median 5.9 min); reposts are the slowest (median 13.3 min). The ordering reply < like < repost is consistent with the engagement ladder hypothesis.],
  )
) <tbl-time-to-first>

The ordering is consistent across all percentiles: replies arrive fastest, reposts slowest. At $P_1$, replies appear in under a second (likely automated or pre-coordinated interactions), while reposts take nearly 10 seconds.

#figure(
  image("../images/data/6-3_time_to_first.png", width: 85%),
  caption: flex-caption(
    [Cumulative distribution of time-to-first-engagement.],
    [Cumulative distribution of time-to-first-engagement for reposts, likes, and replies (logarithmic time axis). Replies and likes are nearly indistinguishable at the median; reposts lag behind. Generated by `time_to_first.py`.],
  )
) <fig-time-to-first>

== Structural Virality
<sec-data-structural-virality>

#comment[
  Kinda similar moment from post lifetime analysis, but we've introduced structural virality in methodology. Maybe the proper idea should be to not do this here and explain it in methodology.
]
Structural virality $nu(T)$ @goel2016structural captures the macro-level shape of the repost propagation tree — distinguishing between broadcast diffusion (one-to-many) and viral spread (person-to-person chains). This is the other objective quantity the simulation wants to study, and has already been defined in @sec-method-des-metrics.

=== Cascade Tree Reconstruction

Bluesky's AT Protocol records include a `via` field in repost events: when user C reposts, the `via.uri` tells us exactly which repost (by user B) they saw. This provides the true propagation path without needing to infer it from the follow graph. Two types of reposts are distinguished:

- *Direct reposts* (`via` is null, $17.6 times 10^6$, 69.3%): the user saw the original post. These anchor directly to the root.
- *Via reposts* (`via` has a value, $7.8 times 10^6$, 30.7%): the user saw someone else's repost. These attach as children of the referenced parent repost.

The implementation streams repost events sorted by `(subject_uri, time_us)`, groups them by original post, builds the tree using a `via_uri arrow.r node` hashmap, and computes $nu$ in $O(N)$ time. The pipeline consists of three steps: a SQL dump from StarRocks ($25.4 times 10^6$ rows, 5.2 GB TSV), a Go streaming computation (354 MB CSV, $4.4 times 10^6$ rows), and Python plotting. Total runtime is $approx 3$ minutes.

=== Virality Distribution

Of $15.3 times 10^6$ top-level posts, $4.41 times 10^6$ (28.9%) received at least one repost and therefore have a cascade tree with $nu > 0$. @tbl-virality-stats summarises the empirical distribution of the structural virality across $4.41 times 10^6$ different post cascades.

#figure(
  table(
    columns: 2,
    align: (left, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Statistic*], [*Value*],
    table.hline(stroke: 0.5pt),
    [$N$ (cascades)], [$4,407,830$],
    [$nu$ mean], [1.3505],
    [$nu$ median], [1.0000],
    [$nu$ std], [0.5736],
    [$nu$ max], [80.7410],
    [$nu$ $P_90$], [2.0331],
    [$nu$ $P_95$], [2.9765],
    [$nu$ $P_99$], [3.3733],
    [$nu$ $P_99.9$], [6.9299],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Structural virality summary statistics.],
    [Structural virality summary statistics for $4.41 times 10^6$ repost cascades. The median lies at the pure-broadcast boundary ($nu = 1$); 54.7% of cascades are exactly 1.0.],
  )
) <tbl-virality-stats>

54.7% of all cascades are pure broadcast ($nu = 1.0$). These are star-shaped trees where every reposter saw the original post directly — no chain of reposts. Figure @fig-virality-dist shows both the linear-scale histogram and the log-log distribution.

#figure(
  image("../images/data/6-4_virality_distribution.png", width: 90%),
  caption: flex-caption(
    [Structural virality distribution.],
    [Structural virality distribution. Left: linear-scale histogram (peak at $nu = 1.0$). Right: log-log distribution showing fast decay above $nu approx 2$. Generated by `plot_virality.py`.],
  )
) <fig-virality-dist>

=== Virality vs Cascade Size

$nu$ grows sub-linearly with cascade size (@tbl-virality-by-size). The largest cascades ($1001+$ nodes) are $approx 15 times$ more viral on average than the smallest ($2$ nodes), despite being $approx 1,000 times$ larger. A cascade of $10,000$ nodes with $nu approx 5$ still looks more like a broad fan-out than a deep chain.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Size bucket*], [*$N$*], [*$nu$ mean*], [*$nu$ median*], [*$nu$ $P_90$*], [*$nu$ max*],
    table.hline(stroke: 0.5pt),
    [2], [$2,412,956$], [1.000], [1.000], [1.000], [1.000],
    [3], [$644,490$], [1.310], [1.333], [1.333], [1.333],
    [4–5], [$509,949$], [1.663], [1.500], [2.250], [4.500],
    [6–10], [$400,019$], [1.874], [1.667], [3.067], [7.067],
    [11–20], [$224,071$], [2.276], [2.067], [4.001], [14.357],
    [21–50], [$124,565$], [2.987], [2.790], [5.812], [28.003],
    [51–100], [$40,707$], [4.134], [3.698], [8.459], [44.606],
    [101–500], [$38,241$], [6.395], [4.971], [13.984], [73.243],
    [501–1000], [$5,221$], [9.718], [5.914], [22.586], [74.301],
    [1001+], [$7,611$], [14.738], [5.944], [31.157], [80.741],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Structural virality by cascade-size bucket.],
    [Structural virality by cascade-size bucket. $nu$ grows sub-linearly: the mean increases only $approx 15 times$ while cascade size grows $approx 1,000 times$.],
  )
) <tbl-virality-by-size>

#figure(
  image("../images/data/6-4_virality_vs_size.png", width: 85%),
  caption: flex-caption(
    [Cascade size vs structural virality (hexbin).],
    [Cascade size vs structural virality (hexbin, log-scale x-axis). Black dots mark the mean $nu$ per size bucket. Values concentrate near $nu = 1.0$ for all sizes; the viral tail thins rapidly above $nu approx 3$.],
  )
) <fig-virality-vs-size>

=== Cascade Depth

73.4% of cascades have depth 1 — every reposter saw the original post directly. Even among viral cascades ($nu > 2$), the typical depth is modest (median 2, mean 3.1); high $nu$ values arise from the combination of non-trivial branching *and* chain structure. The deepest cascade (depth 235) corresponds to the post with $nu = 80.74$ and 12,720 nodes.

#figure(
  image("../images/data/6-4_virality_depth.png", width: 85%),
  caption: flex-caption(
    [Cascade tree depth distribution.],
    [Cascade tree depth distribution. Left: linear-scale histogram (peak at depth 1). Right: log-log distribution. 73.4% of cascades have all reposters seeing the original post directly.],
  )
) <fig-virality-depth>

=== Tail Behaviour and Interpretation

The CCDF of $nu$ (@fig-virality-ccdf) decays faster than a power-law: above $nu approx 2$, the probability drops by roughly an order of magnitude per unit increase. At $nu = 10$, fewer than 1 in 10,000 cascades remain.

#figure(
  image("../images/data/6-4_virality_ccdf.png", width: 75%),
  caption: flex-caption(
    [Complementary CDF of structural virality (log-log).],
    [Complementary CDF of structural virality (log-log). Dashed lines mark $P_{50}$, $P_{90}$, and $P_{99}$. Decay is faster than power-law — extreme virality is exponentially rare.],
  )
) <fig-virality-ccdf>

Bluesky is *predominantly broadcast*: 54.7% of cascades are pure one-to-many diffusion. For comparison, Goel et al. @goel2016structural found Twitter cascades also had median $nu approx 1.0$, but with a longer viral tail. Bluesky's distribution is more concentrated near $nu = 1$, consistent with a smaller, less densely-connected network. The three-regime classification (@tbl-virality-regimes) cleanly separates broadcast, mixed, and viral cascades.

#figure(
  table(
    columns: 4,
    align: (left, center, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Regime*], [*$nu$ range*], [*% of cascades*], [*Interpretation*],
    table.hline(stroke: 0.5pt),
    [Broadcast], [$nu = 1.0$], [54.7%], [One-to-many, no chain],
    [Mixed], [$1.0 < nu <= 3.0$], [42.7%], [Some chain structure, mostly shallow],
    [Viral], [$nu > 3.0$], [2.6%], [Multi-generational, true diffusion],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Three-regime classification of structural virality.],
    [Three-regime classification of structural virality. 97.4% of cascades are broadcast or mixed; only 2.6% reach genuinely viral diffusion.],
  )
) <tbl-virality-regimes>

For the agent-based simulation, the empirical $nu$ distribution provides a calibration target. A correctly calibrated simulation should reproduce: $approx 55%$ of cascades at $nu = 1.0$ (pure broadcast); median $nu approx 1.0$, mean $nu approx 1.35$; maximum $nu$ in the 50–100 range; and $nu$ growing sub-linearly with cascade size.

== Topology Extraction
<sec-data-topology>

The simulation requires a social graph to run on: that is, users and follows upon the information diffuses. This section covers the obtention of a subset of the Bluesky topology.

As already explained in the event dataset description of the Firehose (see @sec-data-firehose), there are `graph_following_create`, `graph_following_delete`, `graph_following_block` and `graph_following_unblock`, and despite being just a #todo[compute the percent] of the total events, this allows us to reconstruct somewhat the topology of Bluesky ---or at least a subset--- organically.

The dataset is 14 monthsof Firehose data also collected by the IDea_Lab, spanning from February 2025 to May 2026 with 88.4% calendar-day coverage (outages are 1) a 46-day window from July to August 2025 and an 8-day window from March to April 2026).

This data was ingested and processed (more details on the ingest process in @apx-topology) and exported as a format called SCD Type 2 #todo[cite/explain on appendix] which allows the topology to be queries time-wise, making the reconstruction and query which edged have been added in a given time frame.

The resulting graph has $28.9 times 10^6$ users with $1.47 times 10^9$ follow edges, which is a massive network that, for the construction methodology, has all the properties of a social network topology.

=== Graph Sampling

#comment[i think there is no need to actually have a Sampling subsection. We could just keep the normal one.]

The complete 29-million-node follow graph exceeds the scope of the simulation execution aims, so  smaller subgraphs must be sampled while preserving the power-law degree distribution characteristic of social networks @kwak2010twitter #todo[check this citation].

#comment[maybe there is no need to explain the used algorithm here, and if not we can delete the subsection Graph Sampling and merge it with the upper and lower one]
The sampling strategy uses the Forest Fire sampling algorithm @leskovec2006sampling, which simulates a spreading process: starting from a random seed node, the sampler "burns" a fraction $p_f$ of the node's outgoing neighbours (forward burning) and $p_b$ of its incoming neighbours (backward burning), recursively visiting the newly discovered nodes. This method produces subgraphs that preserve the heavy-tailed degree distribution, community structure, and clustering coefficient of the original network — properties that simpler methods like random node or random edge sampling fail to replicate. #todo[look for a specific citation on why this is great for this]

=== Datasets Description

Running the sampling algorithm we are able to split the current data with visited nodes, generating 7 datasets with the following nodes: 10

Seven datasets are generated, one per target node count: $10^4$, $5 times 10^4$, $10^5$, $2.5 times 10^5$, $5 times 10^5$, $7.5 times 10^5$, and $10^6$ nodes.

#comment[probably here we should make some analysis of each dataset and present that are indeed social networky like]

