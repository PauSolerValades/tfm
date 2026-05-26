#import "../utils.typ": todo, comment

This appendix documents the complete StarRocks database schema used throughout the data analysis pipeline. All tables reside in two schemas: `bsky` (read-only, raw firehose dump) and `data` (derived and result tables).

==== `bsky.posts`

Normalised post content extracted from `app.bsky.feed.post` records.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`did`], [`VARCHAR(64)`], [DID of the post author],
    [`rkey`], [`VARCHAR(16)`], [Record key (unique within author's repo)],
    [`time_us`], [`BIGINT`], [Firehose event timestamp (microseconds)],
    [`created_at`], [`DATETIME`], [Post creation timestamp (UTC)],
    [`post_text`], [`VARCHAR(65533)`], [Full text content],
    [`lang`], [`VARCHAR(16)`], [Language tag (nullable)],
    [`reply_root_uri`], [`VARCHAR(256)`], [Root post URI (null for top-level)],
    [`reply_root_cid`], [`VARCHAR(64)`], [Root post content ID],
    [`reply_parent_uri`], [`VARCHAR(256)`], [Immediate parent URI],
    [`reply_parent_cid`], [`VARCHAR(64)`], [Immediate parent content ID],
    table.hline(stroke: 0.8pt),
  ),
  caption: [`bsky.posts` schema. $28.1 times 10^6$ rows, $1.45 times 10^6$ unique authors.]
) <tbl-schema-posts>

==== `bsky.records`

All AT Protocol record events from the firehose.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`did`], [`VARCHAR(64)`], [DID of the acting user],
    [`time_us`], [`BIGINT`], [Event timestamp (microseconds)],
    [`rev`], [`VARCHAR(16)`], [Revision ID],
    [`operation`], [`VARCHAR(8)`], [`create`, `update`, or `delete`],
    [`collection`], [`VARCHAR(128)`], [AT Protocol lexicon collection],
    [`rkey`], [`VARCHAR(64)`], [Record key],
    [`cid`], [`VARCHAR(64)`], [Content ID (hash) — null for deletions],
    [`created_at`], [`DATETIME`], [Record creation timestamp — nullable],
    [`subject_uri`], [`VARCHAR(256)`], [URI of the subject record],
    [`subject_cid`], [`VARCHAR(64)`], [CID of the subject record],
    [`subject_did`], [`VARCHAR(64)`], [DID of the subject (follows, blocks)],
    [`via_uri`], [`VARCHAR(256)`], [Indirect reference URI],
    [`via_cid`], [`VARCHAR(64)`], [Indirect reference CID],
    [`record_json`], [`JSON`], [Full record payload as JSON],
    table.hline(stroke: 0.8pt),
  ),
  caption: [`bsky.records` schema. $212.5 times 10^6$ rows, $2.84 times 10^6$ unique DIDs.]
) <tbl-schema-records>

Record type breakdown (creates only): `app.bsky.feed.like` ($159.7 times 10^6$, 76.1%), `app.bsky.feed.repost` ($25.4 times 10^6$, 12.4%), `app.bsky.graph.follow` ($16.2 times 10^6$, 8.8%), `app.bsky.graph.block` ($1.6 times 10^6$, 0.8%), and 12 minor collections.

==== `data.users`

Per-user activity summary, contains all users in the dataset. One row per unique DID appearing in either `bsky.posts` or `bsky.records`.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`did`], [`VARCHAR(128)`], [User identifier (primary key)],
    [`num_posts`], [`BIGINT`], [Total posts authored],
    [`num_likes`], [`BIGINT`], [Total likes given],
    [`num_reposts`], [`BIGINT`], [Total reposts given],
    [`num_follows`], [`BIGINT`], [Total follow actions],
    [`first_seen_us`], [`BIGINT`], [Earliest activity timestamp],
    [`last_seen_us`], [`BIGINT`], [Latest activity timestamp],
    [`primary_lang`], [`VARCHAR(16)`], [Modal language on posts, or NULL],
    table.hline(stroke: 0.8pt),
  ),
  caption: [`data.users` — $3.09 times 10^6$ rows.]
) <tbl-schema-users>

==== `data.all_events`

All 6 major event types for every user, time-windowed to April 11--18, 2026, filtered to $>= 8$ events per user (the power-law $x_min$). Schema: `(did, time_us, event_type)` with 32 hash-distributed buckets.

Event types: `feed_like`, `feed_repost`, `graph_follow`, `graph_block`, `post_top`, `post_reply`, plus minor types.

==== `data.engaged_events`

5 engaged event types — reposts, follows, blocks, posts, replies — *no likes*. Filtered to $>= 4$ events per user. Same schema as `all_events`.

==== `data.sessions_all`

Session clustering from `all_events` using per-user adaptive Tukey IQR thresholds. $47.4 times 10^6$ sessions.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`did`], [`VARCHAR(128)`], [User identifier],
    [`session_start`], [`BIGINT`], [Session start (microseconds)],
    [`session_end`], [`BIGINT`], [Session end (microseconds)],
    [`next_session_start`], [`BIGINT`], [Next session start, or NULL],
    [`duration_s`], [`DOUBLE`], [Session duration (seconds)],
    [`likes`], [`INT`], [Likes during session],
    [`reposts`], [`INT`], [Reposts during session],
    [`posts_authored`], [`INT`], [Top-level posts during session],
    [`replies`], [`INT`], [Replies during session],
    [`follows`], [`INT`], [Follows during session],
    [`blocks`], [`INT`], [Blocks during session],
    [`interactions`], [`INT`], [`likes + reposts`],
    [`user_threshold_s`], [`DOUBLE`], [Per-user adaptive threshold (s)],
    [`user_threshold_fallback`], [`TINYINT`], [1 if fallback used (< 4 gaps)],
    table.hline(stroke: 0.8pt),
  ),
  caption: [`data.sessions_all` schema. Populated by `cluster_all.py`.]
) <tbl-schema-sessions-all>

==== `data.sessions_engagement`

Session clustering from `engaged_events` — same method, no likes. $19.6 times 10^6$ sessions. Schema: same as `sessions_all` but without `likes`, `interactions` columns; adds `reposts`, `posts_authored`, `replies`, `follows`, `blocks`.

==== `data.post_lifetime`

One row per top-level post, precomputing engagement timestamps and counts. $15.3 times 10^6$ rows.

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Column*], [*Type*], [*Description*],
    table.hline(stroke: 0.5pt),
    [`post_did`], [`VARCHAR(64)`], [Post author DID],
    [`post_rkey`], [`VARCHAR(16)`], [Post record key],
    [`created_at`], [`DATETIME`], [Post creation timestamp],
    [`num_reposts`], [`BIGINT`], [Total reposts received],
    [`num_likes`], [`BIGINT`], [Total likes received],
    [`num_replies`], [`BIGINT`], [Total replies received],
    [`first_reposted_us`], [`BIGINT`], [First repost timestamp, or NULL],
    [`last_reposted_us`], [`BIGINT`], [Last repost timestamp, or NULL],
    [`first_liked_us`], [`BIGINT`], [First like timestamp, or NULL],
    [`last_liked_us`], [`BIGINT`], [Last like timestamp, or NULL],
    [`first_replied_us`], [`BIGINT`], [First reply timestamp, or NULL],
    [`last_replied_us`], [`BIGINT`], [Last reply timestamp, or NULL],
    [`last_engagement_us`], [`BIGINT`], [Latest of all engagement timestamps],
    table.hline(stroke: 0.8pt),
  ),
  caption: [`data.post_lifetime` schema. Populated by `populate_post_lifetime.sql`.]
) <tbl-schema-lifetime>

==== `data.post_engagement_events`

Individual event timeline per post. $approx 140 times 10^6$ rows. Columns: `(post_did, post_rkey, event_time_us, event_type, actor_did)`. Enables temporal decay and cascade ordering analysis.

==== `data.graph_events`

Raw follow/block events from parallel ingestion. Simplified denormalised schema: `(event_timestamp, uri, actor_did, subject_did, action_type)` where `action_type` is `follow`, `unfollow`, `block`, or `unblock`.

See `docs/DATABASE.md` in the analysis repository #todo[reference to that repository] for the full specification, example queries, and regeneration instructions.
