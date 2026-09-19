#import "utils.typ": todo, comment, flex-caption

This chapter describes the Bluesky Firehose dataset, which encompases 6 days of full events: types of events, its distribution and other characteristics found in @apx-data. Then, the evaluation metric and the characteristic magnitude described in @sec-method-des-metrics are verified: total reposts per post are fitted with the Vuong's test in @sec-data-reposts and Structual Virality is computed in all the cascades within the dataset timeframe, as well as some descriptive analysis of the data provided in @sec-data-virality. Lastly, the process to obtain the topologies needed for the simulation to run are described in @sec-data-topology and explained in depth in @apx-topology


== Firehose Data Description
<sec-data-firehose>

The Bluesky Firehose is a continuous stream of all public AT Protocol events emitted by the network. The dataset contains all registered events from April 11th to 17th of 2026, six days of events. @fig-eventtype-dist shows the distribution of the top 14 event types, which represent over 99.9% of all events. A full list of all the events can be found in @anx-data-eventlist.


#figure(
  image("../images/data/611_event_distribution.svg", width: 100%),
  caption: flex-caption(
    [Distribution of the top 14 firehose event types.],
    [Distribution of the events in the dataset ($N=240,565,133$) See @tbl-full-event-types for the full breakdown.],
  )
) <fig-eventtype-dist>

As it can be seen, the majority of events on Bluesky are liking a post (`feed_like_create` 67.2%), reposting a post (`feed_repost` with 11.0%), creating a post (`post_top` and  `post_reply` with 11.7%) and following another user (`graph_follow` with a 7.8%). Specifically, the top 5 events represent a 95.5% of total events.

There are a total of 3.09 million distinct users in the dataset, and events are not uniformly distributed among them. Specifically, the distributions of events per user, events per user in a day and events per user in an hour, follow a lognormal distribution as it can be seen in @fig-userevent-dist (see @anx-data-eventperuserfitting for the reasons and methodology of the fitting).

#figure(
  image("../images/data/612_fitting_userevents.svg", width: 100%),
  caption: flex-caption(
    [ECDF with fitted lognormals for events per user, per active day, and per active hour.],
    [Distribution of events per user (blue), events per user per hour (green) and events per user per day (yellow). Parameters: events per user $mu = 2.40$, $sigma = 1.85$, events per active day $mu = 1.43$, $sigma = 1.28$, events per active hour $mu = 0.94$, $sigma = 0.89$.],
  )
) <fig-userevent-dist>

This proves that there is an enormous quantity of users with very few events in the dataset. In order to obtain more informative data, the users with fewer than two events per active day are excluded, representing 29% of distinct users and leaving 2.19 million users. Additionally, we intentionally exclude some outdated events in the dataset (check @anx-data-eventlist) as well as all the `update` and `delete` variants of all the events, as they do not have the `createdAt`, making them useless for the session construction (see @sec-method-session).

#figure(
  image("../images/data/613_filtered_event_distribution.svg", width: 100%),
  caption: flex-caption(
    [Filtered event type distribution.],
    [Event type distribution after filtering by users with $<=2$ events and no `updates` nor `delete` events ($N=231,643,526$)],
  )
) <fig-filtered-eventtype-dist>

#todo[remake this graph while overlapint the same category of @fig-eventtype-dist to see how was changing]

== Reposts Power-law
<sec-data-reposts>

To characterize the virality of posts in the dataset, we fit a power law to the number of reposts received per post. @fig-data-reposts-hist shows the distribution of reposts per post (log-binned, log-log scale): the bulk of posts receive very few reposts, while a small fraction accumulates thousands.

#figure(
  image("../images/data/reposts_histogram.svg", width: 100%),
  caption: flex-caption(
    [Histogram of reposts per post.],
    [Log-binned histogram of reposts per post ($N = 2,493,540$ posts with at least one repost), log-log scale.],
  )
) <fig-data-reposts-hist>

The tail is not a power law: a maximum-likelihood fit gives $alpha = 2.053$ ($x_min = 12$), but Vuong's log-likelihood ratio test decisively prefers the lognormal ($R = -16.84$, $p = 1.18 dot 10^(-63)$). The repost counts are therefore better described as lognormal than as a pure power law. Despite this characteristic magnitude having been refered in this manuscript as "total repost _power-law_" it is, in fact, perfectly normal for social network data to be fitted as a lognormal @clauset2009powerlaw. The more rellevant fact, is that the data exhibits a heavy-tail characteristic.

== Structural Virality
<sec-data-virality>

Structural virality $nu(T)$ @goel2016structural captures the macro-level shape of the repost propagation tree — distinguishing between broadcast diffusion (one-to-many) and viral spread (person-to-person chains). This is the other objective quantity the simulation wants to study, and has already been defined in @sec-method-des-metrics.

Of the $15,282,058$ posts in the dataset, $12,788,518$ (83.68%) receive no repost at all, leaving $2,493,540$ (16.32%) that form a non-trivial cascade (at least one repost). @tbl-data-cascade-stats summarises the tree-level metrics of these cascades: the typical cascade is tiny and shallow (median size 3, median depth 1), but the heavy tail reaches a cascade of $12,720$ nodes, depth $131$ and a maximum out-degree of $7,768$.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Metric*], [*Mean*], [*Median*], [*Max*],
    table.hline(stroke: 0.5pt),
    [Size], [9.18], [3], [12,720],
    [Depth], [1.50], [1], [131],
    [Max out-degree], [5.82], [2], [7,768],
    [Structural virality $nu(T)$], [1.454], [1.333], [50.27],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Cascade general statistics of empirical data.],
    [Tree metrics for the $2,493,540$ cascades with at least one repost.],
  )
) <tbl-data-cascade-stats>

Following @goel2016structural, the cascades split into *broadcast* (depth 1: a star, every repost hangs directly off the root) and *viral* (depth ≥ 2: at least one repost-of-repost). Broadcast diffusion dominates: $1,771,631$ cascades (71.05%) are broadcasts and only $721,909$ (28.95%) are viral.

For the viral cascades alone, $nu(T)$ has mean $2.142$ (95% CI $[2.140, 2.144]$), median $2.000$, minimum $1.333$ and maximum $50.269$. @fig-data-nu-density shows the distribution: it is concentrated right at the broadcast floor $nu = 2$ and decays as a heavy tail, with only $311$ cascades (0.04% of viral) above $nu = 10$ and none reaching $nu >= 100$ — a genuinely viral chain would need a repost chain roughly 300 hops deep, which never occurs inside the six-day window.

#figure(
  image("../images/data/viral_nu_density.svg", width: 100%),
  caption: flex-caption(
    [Structural virality of viral cascades.],
    [Log-$x$ density of $nu(T)$ for the $721,909$ viral cascades (depth ≥ 2), with the broadcast floor $nu = 2$ (dashed) and the median (dotted) marked.],
  )
) <fig-data-nu-density>


== Topology Extraction
<sec-data-topology>

The simulation requires a social graph to run on: that is, users and follows upon which the information diffuses. This section covers the obtention of a subset of the Bluesky topology.

As already explained in the event dataset description of the Firehose (see @sec-data-firehose), there are `graph_following_create`, `graph_following_delete`, `graph_following_block` and `graph_following_unblock`, and despite being just a very few part of the total events, this allows us to reconstruct somewhat the topology of Bluesky ---or at least a subset--- organically.

The dataset is 14 months of Firehose data also collected by the IDea_Lab, spanning from February 2025 to May 2026 with 88.4% calendar-day coverage, more than enough data to obtain a complete network resembling topology. This data was ingested and processed (more details on the ingest process in @apx-topology) and exported as a format called SCD Type 2 (see @apx-topology) which allows the topology to be queries time-wise, making the reconstruction and query which edged have been added in a given time frame.

The resulting graph has $28.9 times 10^6$ users with $1.47 times 10^9$ follow edges, which is a massive network that, for the construction methodology, has all the properties of a social network topology. In order to obtain them, a sample of the network must be obtained. The caveat on this is that, sampling a social network for the sampled graph to still contain the natural properties of a social network needs to be handled with care @kwak2010twitter.

The sampling strategy uses the Forest Fire sampling algorithm @leskovec2006sampling, which simulates a spreading process: starting from a random seed node, the sampler "burns" a fraction $p_f$ of the node's outgoing neighbours (forward burning) and $p_b$ of its incoming neighbours (backward burning), recursively visiting the newly discovered nodes. This method produces subgraphs that preserve the heavy-tailed degree distribution, community structure, and clustering coefficient of the original network — properties that simpler methods like random node or random edge sampling fail to replicate. More information in @apx-topology-forestfire.

