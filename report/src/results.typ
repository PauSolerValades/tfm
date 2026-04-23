#set document(title: "Social Network DES Validation Metrics", author: "Validation Report")
#set page(paper: "a4", margin: (x: 1.5cm, y: 2cm))
#set text(font: "Linux Libertine", size: 11pt)
#set par(justify: true, leading: 0.65em)

// Styling snippet for clean, readable headings and lists
#show heading.where(level: 1): it => block(
  v(1.2em) + 
  text(size: 16pt, weight: "bold", fill: rgb("1a5fb4"), it) + 
  v(0.6em)
)

#show heading.where(level: 2): it => block(
  v(0.8em) + 
  text(size: 13pt, weight: "bold", fill: rgb("26a269"), it) + 
  v(0.4em)
)

#show strong: set text(fill: rgb("333333"))

= Validation Metrics: Empirical Data vs. Simulation Traces

This document outlines the macro-level metrics for validating the Discrete-Event Simulation (DES) against real-world Bluesky firehose data, strictly isolating structural and temporal dynamics from content analysis.

== 1. Cascade Size Distribution (Power Laws)
This metric measures the absolute reach (breadth) of individual posts to confirm if your network produces the heavy-tailed distributions typical of real social platforms.

*Bluesky Firehose Extraction:*
- Filter the firehose for `app.bsky.feed.repost` and `app.bsky.feed.like` records.
- Extract the `subject.uri` (the unique identifier of the original post) from each record.
- Aggregate the total count of events per `subject.uri` over your observation window.
- Plot the frequencies of these counts to calculate the distribution exponent.

*Simulation Trace Extraction:*
- Parse the `action_trace` [cite: 50, 92] (accessed April 22, 2026).
- Filter for events where the type is `.repost` or `.like` [cite: 94] (accessed April 22, 2026).
- Aggregate the total count per `post_id` [cite: 88, 91] (accessed April 22, 2026).

== 2. Cascade Depth (Longest Chain)
Depth measures the maximum number of generational "hops" a post takes from its original author, which is distinct from sheer volume.

*Bluesky Firehose Extraction:*
- Identify a target `subject.uri` and collect all users (DIDs) who reposted it.
- Actively monitor `app.bsky.graph.follow` events to maintain a snapshot of the follower graph.
- Sort the reposts chronologically using `created_at`.
- Iterate through the chronologically sorted reposts: if User C reposts the URI, and your graph shows User C follows User B (who reposted it earlier), infer an edge from B to C.
- Count the maximum consecutive edges from the root author.

*Simulation Trace Extraction:*
- Find the root creation time and author for a `post_id` in `create_trace` [cite: 35, 68] (accessed April 22, 2026).
- Filter `action_trace` for all `.repost` events of that `post_id` [cite: 91, 94] (accessed April 22, 2026).
- To find a node's parent, cross-reference the user's `.repost` timestamp in `action_trace` with `propagate_trace` [cite: 40, 103] (accessed April 22, 2026). The parent is the `user_id` from the most recent propagation event for that `post_id` that occurred immediately before the `.repost` action.
- Traverse the resulting tree to find the longest path.

== 3. Structural Virality (The Wiener Index)
This calculates the average distance between all nodes in a reconstructed diffusion tree to determine if a post went viral via a single massive broadcast or a complex, multi-branching cascade.

*Bluesky Firehose Extraction:*
- Reconstruct the exact diffusion tree using the inferred follower-path method described in the "Cascade Depth" step.
- Apply the Wiener Index algorithm: compute the shortest path length between every possible pair of nodes within that specific tree, sum those lengths, and divide by the total number of node pairs.

*Simulation Trace Extraction:*
- Reconstruct the diffusion tree using the `action_trace` and `propagate_trace` intersection method [cite: 92, 104] (accessed April 22, 2026).
- Calculate the average shortest path between all node pairs in the reconstructed tree.

== 4. Temporal Burstiness & Time-to-Peak
This measures the velocity and clustering of engagement over time, confirming the "social reinforcement" effect where engagement spikes sharply rather than smoothly.

*Bluesky Firehose Extraction:*
- Isolate the `created_at` timestamps for all interactions pointing to a specific `subject.uri`.
- Subtract the original post's creation time from each interaction's timestamp to get absolute delta times.
- Group these deltas into fixed time bins (e.g., 5-minute intervals).
- Identify the time bin with the highest frequency of events to establish the time-to-peak, and analyze the slope of the surrounding bins for burstiness.

*Simulation Trace Extraction:*
- Filter `action_trace` for a specific `post_id` [cite: 91, 92] (accessed April 22, 2026).
- Extract the `time` field for each event [cite: 9, 91] (accessed April 22, 2026).
- Group the events into simulation tick bins.
- Locate the bin with the maximum count and map the distribution curve.

== 5. Gini Coefficient of Engagement
This metric measures the inequality of attention across the network, verifying if a small subset of users monopolizes the majority of interactions.

*Bluesky Firehose Extraction:*
- Parse `app.bsky.feed.post` events to map each `uri` to its author's `did`.
- Tally all incoming likes and reposts from the firehose, attributing them to the original author's `did`.
- Create an array of total engagement scores per user.
- Calculate the Gini coefficient of this array (0 represents perfect equality; 1 represents absolute inequality).

*Simulation Trace Extraction:*
- Parse `create_trace` to map every `post_id` to its author's `user_id` [cite: 35, 67] (accessed April 22, 2026).
- Parse `action_trace` [cite: 92] (accessed April 22, 2026) and attribute every `.like` and `.repost` [cite: 94] (accessed April 22, 2026) to the respective author's `user_id`.
- Calculate the Gini coefficient of the resulting array of user engagement totals.alculate the Gini coefficient of the resulting array of user engagement totals.
