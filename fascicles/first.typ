#let margins = (
  top: 3.5cm,
  bottom: 3cm,
  y: 1.8cm,
)
#let blue = rgb(43, 129, 173)
#let grey = rgb(100, 100, 100)

#import "@preview/cetz:0.5.2"

#set page(paper: "a4", margin: margins, numbering: "1")

#set text(size: 11pt, font: "New Computer Modern", lang: "en")

#set par(spacing: 0.7em, leading: 0.7em, justify: true, first-line-indent: 1.5em,)

#set heading(numbering: "1.")
#show heading.where(level: 1): set text(
  size: 20pt,
  weight: "bold",
)

#show heading.where(level: 2): set text(
  size: 14pt,
  weight: "bold",
)

#show heading.where(level: 3): set text(
  size: 12pt,
  weight: "bold",
)

#show heading.where(level: 4): set heading(outlined: false, numbering: none)
#show heading.where(level: 5): set heading(outlined: false, numbering: none)
#show heading.where(level: 4): set text(
  size: 11pt,
  weight: "bold",
)

#show heading: it => [
  #block(above: 1.5em, below: 1em, it)
]

#set math.equation(numbering: "(1)")

// Add a bit of breathing room after figure captions
#show figure: it => {
  it
  v(0.6em)
}

// Track when Typst is generating the outline (List of Figures/Tables/etc.)
#let in-outline = state("in-outline", false)

// Flip the state to true ONLY inside outlines
#show outline: it => {
  in-outline.update(true)
  it
  in-outline.update(false)
}

// Custom caption: short version in lists, long version in main body
#let flex-caption(short, long) = context if in-outline.get() { short } else { long }



= First Summer Bitacora 

This document shows results and tracks progress. It's meant to be very straight to the point and to communicate progress and ideas.

== "Fixing" the simulation

Doing the presentation for the `IDea_lab` I found out that I never implemented a proper reverse-chronological timeline.

*What was implemented*

User $u$ had timeline $cal(T) (u)$, which behaves like a priority queue returning the `TimelineEvents` objects with the _biggest_ time, so the most recent one.

This meant that if the simulation was processing times $t=100$ and $e = "pop"(cal(T) (u))$ could have perfectly been at $e_"t" = 10$ which is intended behaviour. The problem is when a followee of $u$ propagates something at $t=101$. The propagation will make the event 

$ e = { "time" = 101, "post_id" = i } $ 

in $cal(T) (u)$ being the time in this new event bigger than any other element in the list, therefore the next $"pop"(cal(T) (u))$ is going to make the user make it see an element which is not really there if we are following the "Reverse-chronological timeline" approach.

The appropriate behaviour should be that the user timeline "recharges" when he is checking the posts in a single session. That is, the event with $t=101$ should just be stored to be checked on the next session.

*What is implemented*

To get to this "recharging" behaviour now every user has two timelines, the active timeline $cal(T)_t^a (u)$ and the passive timeline $cal(T)_t^p (u)$. The active timeline is the one the user pops from when online and checking posts, is exactly the same as the one being used so far. 

The passive timeline is the one that stores the propagation events when the user is online. A nice way to understand it is that every $"pop"$ is performed on the active timeline, and every $"push"$ is on the passive timeline, where all content gets stored.

Now, the $e_t = 101$ will be stored on $cal(T)^p (u)$, and the next element the user will see from $"pop"(cal(T)^a (u))$ will still conform to the contents of the timeline, and it will simply get pushed to the passive timeline. This of course introduces the simulation to the concept of "the swap", which modifies the boredom mechanic.

*The swap*

The first exploration of the simluation make us realize that a LOT of sessions were preemptively finished due to boredom, which made the actual session far shorter than scheduled. Now the boredom mechanic ---that a user finishes his session due to $cal(T) (u) = emptyset$ has slightly changed.

If $cal(T)^a (u) = emptyset$, check if $cal(T)^p (u)$. If the passive is also empty, boredom kicks in and the user disconnects. If $cal(T)^p != emptyset, quad "swap"()$, which essentially means that the active empty timeline is now the passive timeline and viceversa!

This maps essentially as the user "refreshing" the feed when they found already seen content. As we are _simplifying_ the simulation this is not going to be added, but the swap mechanism could be triggered befroe the active timeline is emtpy to make the user always see newer content.

== Revision of the Trace Analysis

I've redone the pipeline of the trace analysis in the `des-ctic`. Specially, I've completely rewritten from scratch the cascade generation from the traces code in Zig, and the pipeline form Python to Go.

Now, from the traces, all the cascades that are in the program are written in a space separated values `.ssv` file with the following header (and example lines)

#figure(
```
run_id  post_id  user_id  parent_id  type         time
0       200      7363     7363       creation     19.663644790649414
0       200      7363     -1         propagation  20.663644790649414
0       461      8768     8768       creation     108.9035415649414
0       461      8768     -1         propagation  109.9035415649414
0       461      3900     -1         propagation  134.22376665472984
0       461      6357     -1         propagation  607.1554308794439
0       461      4688     -1         propagation  778.7290179636329
0       461      3900     8768       repost       133.22376665472984
0       461      6357     8768       repost       606.1554308794439
0       461      4688     8768       repost       777.7290179636329
```
)

which contains the creation and reposting and it's associated propagation. It's time sorted within (run_id, post_id). Additionally we provide the likes separately in another ssv.

With the traces and the dataset we can construct the following 9 datasets. We can split them in three general types:
1. Generic: contains information of several magnitudes, such as runs, users or sessions or posts.
2. Posts Lifetimes: contains either information to compute the lifetimes or aggregated metrics of the lifetimes, and are the posts. 
3. Cascades: contains information deduced from the cascades. There are the general dataset, the broadcast (or subcascade) and the root-to-path dataset.

Both datasets 1 and 2 are computed with just DuckDB and sql scripts, which have been AI generated with human supervision --- I am very rusty with SQL and it really did some wonderfull things there.

=== Generic Datasets 

*Per-run Dataset*
Very alike to the `SimResult` structure that the simulation outputs as a control. Gives global information per run. Contains information like total_reposts, total likes, ignores, total sessions, total swaps...

*User dataset*
Contains information about the number of sessions, the number of swaps, total time online, reposts and likes. It's very useful to compare with the actual values every user has the simulation assigned to `session_duration`, `inter_session_lenght` and `inter_post_creation` and with their in-degree and out-degree.

*Sessions*
Aggregates metrics Session level. This is a middle step to compute the user dataset and it can be mostly used to check the effects on the boredom over all the users eg, compare the values that the sessions and the gaps should follow vs the ones they do actually follow.

*Per-post metric*
Most basic information: how many likes, reposts ignores and conversion_rate (interactions/impressions) per post.


=== Lifetime Datasets

*Raw Post Lifetime Analysis Dataset*

Aggregates the informations of all the posts in a single table to facilitate the computation of the post lifetime analysis and the next datasets. The features are the following:
- run_id (pk)
- post_id (pk)
- parent_id (pk): from whom the reposter_id received the post. 
- post_creation_time: when the post is created.
- reposter_id: user_id of who reposted the post (if creation is the creator)
- propagated_time: when the post arrived to the reposter_id queue
- repost_time: when the repost over post_id was performed.
- sitting_in_timeline: how much time the post_id was in the timeline before being reposted (repost_time - propagated_time)
- global_gap: (time of the last repost of this post disregarding parent_id) - (time of the current repost)
- topology_gap: (time of the last repost coming from parent_id) - (time of the current repost) 

*Post Lifetime Datasets*

A quick aggregation of all the metrics the posts lifetime analysis have to use and abuse. Contains the following features:
- run_id (pk)
- post_id (pk)
- author_id
- creation_time
- last_repost: at which time the last propagation of this event has happened.
- T_50: time from creation to getting the 50% of total reposts.
- T_95: time from creation to getting the 95% of total reposts.
- T_99: time from creation to getting the 99% of total reposts.
- time_to_peak: time from creation to the maximum concentration of reposts per peak 


=== Cascades Datasets

*General Cascade*

The first dataset is very straight forward: contains the structural virality, the depth, size and max out degree.

This table is the one that has to be compared ONE-TO-ONE with the empirical data findings and analysis.

*Additional Datasets*

I've just though about them very recently, and there is two more metrics we can check both in real bluesky data and the real cascade. Consider the following repost cascade for a single post:

#figure(
  cetz.canvas({
    import cetz.draw: *

    let node-style = (radius: 0.35, fill: white, stroke: 1pt + black)

    // Node coordinates (root at top, leaves at bottom)
    let nodes = (
      ("R", 0,    0),
      ("A", -2.5, -1.5), ("B", 0,   -1.5), ("C", 2.5, -1.5),
      ("D", -3.5, -3),   ("E", -1.5, -3), ("F", 0,   -3), ("G", 2.5, -3),
      ("H", -4.5, -4.5), ("I", -2.5, -4.5), ("J", 0,   -4.5), ("K", 2.5, -4.5),
    )

    // Edges point from parent to child (who reposted from whom)
    let edges = (
      ("R", "A"), ("R", "B"), ("R", "C"),
      ("A", "D"), ("A", "E"),
      ("B", "F"),
      ("C", "G"),
      ("D", "H"), ("D", "I"),
      ("F", "J"),
      ("G", "K"),
    )

    // Draw nodes first (edges reference node names)
    for (name, x, y) in nodes {
      circle((x, y), name: name, ..node-style)
      content(name, text(size: 10pt, weight: "bold", str(name)))
    }

    // Draw edges
    for (from, to) in edges {
      line(from, to, stroke: 1pt + black)
    }

    // Depth indicators on the right
    content((3.5, 0),    text(size: 9pt, fill: grey, [depth 0 (root)]), anchor: "west")
    content((3.5, -1.5), text(size: 9pt, fill: grey, [depth 1]), anchor: "west")
    content((3.5, -3),   text(size: 9pt, fill: grey, [depth 2]), anchor: "west")
    content((3.5, -4.5), text(size: 9pt, fill: grey, [depth 3 (leaves)]), anchor: "west")
  }),
  caption: [Reconstructed cascade tree from topology-informed traces. Each node is a repost event; edges point from parent to child (who reposted from whom). Leaf nodes (H, I, E, J, K) are users who received the post but never reposted it.]
) <fig-cascade-tree>
The first exploration of the simluation make us realize that a LOT of sessions were preemptively finished due to boredom, which made the actual session far shorter than scheduled. Now the boredom mechanic ---that a user finishes his session due to $cal(T) (u) = emptyset$ has slightly changed.

If $cal(T)^a (u) = emptyset$, check if $cal(T)^p (u)$. If the passive is also empty, boredom kicks in and the user disconnects. If $cal(T)^p != emptyset, quad "swap"()$, which essentially means that the active empty timeline is now the passive timeline and viceversa!

This maps essentially as the user "refreshing" the feed when they found already seen content. As we are _simplifying_ the simulation this is not going to be added, but the swap mechanism could be triggered befroe the active timeline is emtpy to make the user always see newer content.

== Warm-up time

The original simulation was running with $t=1000$ warm-up. This value was unrevised ---and chosen at random--- when picked up the first time. Apparently, the reasoning was: the higher the warm-up, the more amount of posts there will be so boredom is lower, unknowingly leaving the door open to constructing very few cascades from posts not created outside the warm-up.

An experiment has been conducted analyzing several values of warm-up: $0$, $2$, $3$, $5$, $10$, $50$, $100$ ticks. After sweeping across dataset sizes (10K--1M), the final sweep settled on `warmup = 3.0` for all dataset sizes. The combined summary for the 100K dataset is shown in @fig-warmup-100k.

#figure(
  image("img/warmup-100k.png", width: 100%),
  caption: [Combined summary for the 100K dataset with warmup = 3.0. From left to right: boredom timeline, first session backlog, new post traction, sessions & actions, and warmup attention decay.]
) <fig-warmup-100k>

With `warmup = 3.0` on the 100K dataset, boredom ends $39.4%$ of first sessions, and the average session length is $136.7$ time units. The new post traction panel shows that non-warmup posts quickly dominate interactions --- $15.1%$ of posts proliferate, with a mean of $2.58$ reposts per post. Indirect reposts account for $1.5%$ and multilevel cascades for $3.0%$.

Therefore, warm-up is shown to be either $2$ or $3$, as $2$ shows a middle ground behaviour from $0$ and $3$, but $3$ behaves more like the other warm-up values, so it seems a more generalized approach.

_Note:_ the minimum amount of warm-up time to test is lower bounded by `creation_delay`, as the time the post will appear when created is $t = "creation_delay" + "warmup_inter_post_creation.sample"()$, therefore warm-ups less than $1$ are impossible, and will behave like `warmup = 0` (I found out the painful way xd)

== Stability regime

The stability regime experiment has been executed across all dataset sizes (10K, 50K, 100K, 250K, 500K, 750K, 1M). All datasets achieve stability at the same time $t = 1016$, and the online percentage of users ranges from $1.6%$ to $2.4%$, which does _not_ grow with topology size, althoug it just has been ran once per run.

#figure(
  image("img/stable-regime-100k.png", width: 100%),
  caption: [Session trace for the 100K dataset showing the system reaching stability at $t = 1016$.]
) <fig-stable-regime>

== What now?

Before running the simulation, I will rewrite and revise the session creation and obtention from the real data. This is the most critical data analysis of this work: if the sessions are ill defined, no result is going to be actually representing the real data. If the session generation changes, it will also be the case for the distributions that every user in the simulation follows, therefore the experiments showcased (warm-up and stability) will need to be repeated ---it takes around 12 hours of compute.


Assuming the sessions pass the checking bar, we will be ready to actually run the longest simulation batch per every dataset, as we will know:
1. Correct Warm-up time
2. Duration informed by stability regime (eg, 1000-3000 ticks more than the stability forms, those cascades will be the most real life resembling ones)
3. Sessions well defined.
4. Which metrics can be extracted from the traces and the bsky data equally --- the ones defined in the 9 datasets described in this document.

To reliably run the simulation, the cascades and the dastaset construction, I am building an orchestrator using Zig build system _i.e_ I am using Zig metaprograming capabilities to use zig as make and manage which binaries to run, in which order and if a rebuild is needed. Once this is done, an execution proposal runs will be

#figure(
  table(
    columns: 4,
    align: (center, center, center, center),
    table.header(
      [*Dataset*], [*Runs*], [*Workers*], [*Avg runs / worker*],
    ),
    table.hline(),
    [10K],  [1000], [8], [125],
    [50K],  [1000], [8], [125],
    [100K], [500],  [4], [125],
    [250K], [400],  [4], [100],
    [500K], [250],  [2], [125],
    [750K], [100],  [1], [100],
    [1M],   [70],   [1], [70],
  ),
  caption: [Execution proposal for the final simulation runs.]
) <tbl-execution>

For what I've observed so far, more than 500 runs is absolutely overkill giving 95%CI of the order of 0.0001 on the metrics and quantities. The amount of workers, despite knowing the sever has 96 -- i think?--- logical threads, cannot be augmented due to performance degradation: despite the topology being shared in memory by all workers (it's allocated by the parent thread, passed by reference and not modified) the user state and all the timelines change per run, therefore every worker has n users allocated with it's associated data, so the amount of pyhiscal ram can be exhausted if a lot of simulatneous workers are ran. Not only that, but maximizing the amount of RAM in usage will lead to a heavy performance degradation due to cache swaping more frequently to attend more pepole (cache is shared in all the system) therefore, we cannot just but 23 or 64 workers as it might be slower than having less workers.
