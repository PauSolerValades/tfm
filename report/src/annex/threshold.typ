Kooti et al @kooti2016twitter studied how often Twitter users engage with content by modelling active sessions, which are contiguous bursts of activity separated by periods of absence. The central question is: given two consecutive actions by the same user, how long can the pause between them be before we consider the user to have logged off?

#figure(
  image("../figures/session_elbow_175000.png", width: 80%),
  caption: [Inter-arrival gap distribution of the dominant user stratum
    (101--500 core events, $N = 95{,}795$ users, $16.3 times 10^6$ gaps).
    The red dashed line marks the Kneedle-detected elbow at $Delta t = 265$ s
    ($4.4$ min).]
) <fig:elbow>


Kooti et al. model user activity with three event types: original content (tweets), conversation engagement (replies and quote-tweets), and amplification (retweets). Likes are deliberately excluded, as they represent passive consumption rather than content generation or curation. @tbl-twitter-bsky-events maps three considered events by the study to their Bluesky AT Protocol equivalents.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Twitter / X*], [*Bluesky equivalent*], [*AT Protocol collection*],
    table.hline(stroke: 0.5pt),
    [Original tweet], [Top-level post (no reply parent)], [`app.bsky.feed.post`],
    [Reply / Quote-tweet], [Post with a `reply_parent_uri`], [`app.bsky.feed.post`],
    [Retweet], [Repost record], [`app.bsky.feed.repost`],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Twitter event analogous to the Bluesky equivalent.]
) <tbl-twitter-bsky-events>

Quote-posts on Bluesky are regular `app.bsky.feed.post` records that embed a reference to another post in their JSON payload. They fall naturally into the `post` (top-level) or `reply` category depending on whether they carry a `reply_root_uri`, requiring no special handling.

The resulting dataset was stored in a StarRocks table `user_core_events` via the SQL script `create_core_events_table.sql` and populated by `insert_core_events.sql`. It contains 53.5 million events from 1.75 million distinct users across the 8-day firehose window, with the schema `(did, time_us, event_type)` where `event_type` takes one of the values `post`, `reply`, or `repost`.

The core of the replication is the use of the elbow method, as described by Kooti et al. With the filtered dominant table `user_core_events_dominant` already available from the EDA (@sec-data-firehose), the threshold can be detected empirically. The procedure, implemented in `session-analysis/session_threshold_elbow.py`, is:

1. *Sampling.* All 95,795 DIDs from `user_core_events_dominant` are retrieved via `SELECT … ORDER BY RAND()`. No sub-sampling is needed — the dominant table is already a tight subset.

2. *Gap computation.* For each user, events are sorted by `time_us` and the inter-arrival gap $Delta t = t_(n+1) - t_n$ is computed in seconds. The first event of each user produces no gap and is excluded.

3. *Histogram construction.* All gaps are aggregated into 10-second bins from 0 to 3,600 s (60 minutes), following the original paper's methodology.

4. *Elbow detection.* The Kneedle algorithm @satopaa2011kneedle locates the point of maximum curvature on the gap histogram — the transition from steep decline (within-session bursts) to a flat tail (between-session pauses). The Python implementation uses the `kneed` package (`KneeLocator` with `curve="convex"`, `direction="decreasing"`.

The detected elbow is 265 s (4.4 min). This is the gap duration that best separates intra-session behaviour (events spaced closer than 4.4 minutes apart — the user is still browsing) from inter-session behaviour (longer pauses — the user has logged off and returned later). For comparison, Kooti et al. report a threshold of approximately 10 minutes on Twitter. The Bluesky result is roughly half that value, consistent with a younger, more real-time platform with shorter browsing bursts.

#figure(
  table(
    columns: 3,
    align: (left, center, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Source population*], [*Elbow*], [*Notes*],
    table.hline(stroke: 0.5pt),
    [All users (unfiltered)], [195 s (3.2 min)], [Bot-distorted; discarded],
    [$>= 6$ events, $<= 100$/day], [285 s (4.8 min)], [Broad human, manual filter],
    [35–100 events/day], [255 s (4.2 min)], [Narrow active-human band],
    [*101–500 events (dominant)*], [*265 s (4.4 min)*], [*Data-driven filter — used*],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Elbow threshold sensitivity to the source population. The dominant-stratum result (265 s) is the most principled, as it applies the Kneedle algorithm to the population that objectively drives the gap distribution (37.4% of gaps), without manual bucket boundaries.]
) <tbl-elbow>

@tbl-elbow shows the sensitivity of the elbow to the filtering strategy. Unfiltered data compress the elbow downward (195 s) due to the 501+ bot bucket, whose artificially tight posting intervals dominate the short-gap region. Manual cut-offs ($>= 6$, $<= 100$/day; 35–100/day) bracket the result at 255–285 s, confirming that the dominant-stratum approach is stable.

With $Delta t = 265$ s determined, the final step is to cluster each user's events into sessions and persist them for downstream analysis. This is performed by `session-analysis/session_core_events.py`, which writes directly to `sessions_threshold`.

The clustering algorithm is straightforward: for each user, events are fetched from `user_core_events_dominant` ordered by `time_us`. The rule $Delta t > 265 s$ triggers a new session; otherwise the event is added to the current session. For each resulting session, the script records the start and end timestamps, the start of the next session (enabling inter-session gap computation), the session duration, and counts of reposts and posts authored.

The result is 8.47 million sessions from 95,795 users, with an average session
duration of 90 s and a median of 0 s (many sessions consist of a single
event). The $P_75$ duration is 104 s and $P_90$ is 277 s. The full
schema and statistics are available in `sessions_threshold`.
