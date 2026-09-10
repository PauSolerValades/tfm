#import "../utils.typ": *

This annex describes the raw Bluesky firehose dataset that feeds the whole analysis: where it comes from, how it is stored, and the `via_uri` field that makes the reconstruction of repost cascades possible.

== Firehose Data Repositories

The firehose is the raw event stream of the AT Protocol @atproto-overview: every repository commit across the network ---every post, like, follow, block, or profile edit--- arrives as a signed record. By design it can be consumed by anyone connecting to the `com.atproto.sync.subscribeRepos` endpoint @bsky-firehose, which delivers the data as a binary stream.

To avoid decoding a changing binary schema, IDea_lab at UniGraz listens to Bluesky and deserializes the stream into JSONL files, one per hour @lazzaroni2025blueskyfirehose. From those files the dataset used in @sec-data-firehose is built. It consists of two StarRocks tables:

- `bsky.records` ($approx 212.5$M rows): all AT Protocol record events ---`create`, `update` and `delete` operations--- for every collection, one row per record.
- `bsky.posts` ($approx 28.1$M rows): the post content normalized out of `bsky.records` (`post_text`, `lang`, `reply_root_uri`), so a top-level post can be told apart from a reply without parsing the record JSON.

Both tables store the `created_at` timestamp and, for engagement records, the `subject` and `via` strong references; the latter is extracted into the `via_uri` field discussed next.

== `via_uri` field

To reconstruct the cascade, we use the `via_uri` field. This is _the_ cornerstone of this work, and the only reason the output of the simulation is comparable to real data. This section expands on what it is ---and what it is not--- as well as its role in the AT Protocol.

=== Origin

`via_uri` is the `via` field of the raw AT Protocol record @atproto-overview, extracted verbatim by the ingestion code that built `bsky.records`. Nothing is computed:

- Raw firehose JSONL: `commit.record.via` is a strong reference `{uri, cid}`.
- Ingestion to `bsky.records`: `record.via.uri` becomes `via_uri`, `record.via.cid` becomes `via_cid` ---the same pattern as `record.subject` to `subject_uri` / `subject_cid`.

While `subject` points to the content the user acts on, `via` records how the user discovered it: the intermediate record through which the content reached them, typically a repost. The following record, a like, shows how `subject` and `via` coexist:

#code(caption: [A like record carrying both `subject` and `via` strong references.])[
```json
{
  "$type": "app.bsky.feed.like",
  "subject": {
    "uri": "at://did:plc:author123/app.bsky.feed.post/3k43tv4rft22g",
    "cid": "bafyreigp5qh2fo7qqer2ywry4jbufajwcj63hkrws4thq5knfaoxu6gfwi"
  },
  "via": {
    "uri": "at://did:plc:curator456/app.bsky.feed.repost/3mnagwpobya2m",
    "cid": "bafyreibddujfzdhen6sqau7c6awx24xgrczrcyu565tlojyz6jbno6rtgu"
  },
  "createdAt": "2026-06-01T15:55:31.016Z"
}
```
]

=== What it means

`via` records how the user discovered the thing they acted on: a pointer attribution set by the client. From a full-hour scan of the 2026-04-11 firehose:

#figure(
  table(
    columns: (auto, auto, auto),
    stroke: (x: none, y: 0.3pt),
    inset: (x: 6pt, y: 3pt),
    align(center)[*Collection*], align(center)[*`via_uri` points to*], align(center)[*Meaning*],
    [`app.bsky.feed.like`], [`app.bsky.feed.repost` (229K in 1h)], [user liked the post because they saw it through someone's repost],
    [`app.bsky.feed.repost`], [`app.bsky.feed.repost` (55K)], [user reposted after seeing someone else's repost ---a repost-of-repost chain link],
    [`app.bsky.graph.follow`], [`app.bsky.graph.starterpack` (14K)], [user followed the account via a starter pack],
  ),
  caption: [Meaning of `via_uri` per collection, from one full hour of the 2026-04-11 firehose.],
) <tbl-anx-via-uri-meaning>

Filtering by reposts only, this construct builds cascades of truly linked content that reached the timeline through a repost mechanism, allowing a direct comparison with what the simulation does.

=== Caveats

`via` is *optional* in the lexicon (set by the official app when the view can be attributed), so most records lack it: roughly 20% of likes, 32% of reposts, and 14% of follows carry one. Three caveats follow:

- The `via` field does not exist in the 2025-04 firehose files (zero occurrences) ---it was added to the lexicon later @atproto-overview. Any time-series using it must start from when clients began emitting it.
- It is only present in `bsky.records`, not `bsky.posts`; posts carry `reply_root_uri` instead, a different concept (thread structure rather than discovery attribution).
- Its absence is not random: non-official clients never set `via`, so a missing value mixes "genuinely direct view" with "attribution lost".

As a consequence, the structural virality of the real data is a lower bound: reposts without `via` flatten onto the root, so long chains are systematically underestimated. Because we restrict ourselves to a reverse-chronological timeline, the comparison with the simulation remains fair, but it is not extrapolable to the recommender-driven feeds that dominate real use.

Despite other ways of reconstructing cascades, a more sophisticated approach ---predicting the recommender, or linking users by content similarity--- has been discarded from the beginning due to time constraints.

=== Structural virality usage

The pipeline lives in the analysis repository @soler2025bskydata: `cascade-creation/01_dump_reposts.sql` dumps the reposts, `build_cascades` resolves each repost's parent from `via_uri` (falling back to the root), and `cascade-metrics` computes the structural virality $nu = 2 dot W / (n (n-1))$ with $W$ the Wiener index ---exactly the measure of @goel2016structural. The formula and the tree semantics are correct; the one caveat worth stating is that no size threshold is applied yet, so the $nu$ distribution is dominated by tiny cascades for which $nu$ is a deterministic artifact.

== Event Dataset Description
<anx-data-eventlist>

The firehose dataset captures all AT Protocol record events from April 11--18, 2026.

#figure(
  text(size: 9pt)[
    #table( 
      columns: (auto, auto, auto, auto),
      stroke: (x: none, y: 0.3pt),
      inset: (x: 6pt, y: 3pt),
      align(center)[*Event type*], align(center)[*Description*], align(center)[*Count*], align(center)[*%*],
    [`feed_like_create`], [Like a post], [159.7M], [66.4%],
    [`feed_repost_create`], [Repost someone else's post], [25.4M], [10.6%],
    [`graph_follow_create`], [Follow another user], [16.2M], [6.8%],
    [`post_top`], [Original post, starts a thread or stands alone], [15.3M], [6.4%],
    [`post_reply`], [Reply in a thread], [12.8M], [5.3%],
    [`graph_follow_delete`], [Unfollow another user], [2.5M], [1.1%],
    [`feed_like_delete`], [Unlike a post], [2.0M], [0.8%],
    [`graph_block_create`], [Block another user], [1.6M], [0.7%],
    [`feed_threadgate_create`], [Set who can reply to a post], [1.5M], [0.6%],
    [`feed_repost_delete`], [Un-repost a post], [1.0M], [0.4%],
    [`feed_postgate_create`], [Set who can quote/embed a post], [0.8M], [0.3%],
    [`actor_profile_update`], [Edit profile metadata], [0.7M], [0.3%],
    [`graph_listitem_create`], [Add a user to a list], [0.4M], [0.2%],
    [`actor_profile_create`], [Create a new profile], [0.2M], [0.1%],
    [`graph_block_delete`], [Unblock another user], [104.6K], [0.043%],
    [`actor_status_update`], [Update presence/heartbeat signal], [97.3K], [0.040%],
    [`actor_status_create`], [Initial presence/heartbeat signal], [86.8K], [0.036%],
    [`actor_status_delete`], [Clear presence/heartbeat signal], [86.4K], [0.036%],
    [`graph_listitem_delete`], [Remove a user from a list], [79.1K], [0.033%],
    [`labeler_service_create`], [Register a labeling service], [10.7K], [4.47e-3%],
    [`labeler_service_delete`], [Delete a labeling service], [10.7K], [4.46e-3%],
    [`labeler_service_update`], [Update a labeling service], [10.5K], [4.36e-3%],
    [`feed_threadgate_update`], [Change reply-gating rules], [9.0K], [3.74e-3%],
    [`feed_generator_update`], [Edit a custom feed], [5.8K], [2.43e-3%],
    [`graph_listblock_create`], [Block an entire list], [5.1K], [2.14e-3%],
    [`graph_list_create`], [Create a user list], [5.1K], [2.10e-3%],
    [`notification_declaration_create`], [Set notification preferences], [4.6K], [1.93e-3%],
    [`feed_generator_create`], [Create a custom feed], [2.4K], [9.79e-4%],
    [`graph_list_update`], [Edit a user list], [2.1K], [8.77e-4%],
    [`feed_postgate_update`], [Change quote/embed gating], [2.0K], [8.38e-4%],
    [`graph_list_delete`], [Delete a user list], [1.5K], [6.28e-4%],
    [`graph_listblock_delete`], [Unblock an entire list], [1.5K], [6.19e-4%],
    [`notification_declaration_update`], [Change notification preferences], [1.5K], [6.14e-4%],
    [`graph_starterpack_update`], [Edit a starter pack], [1.1K], [4.61e-4%],
    [`feed_generator_delete`], [Delete a custom feed], [1.1K], [4.44e-4%],
    [`graph_starterpack_create`], [Create a starter pack], [0.7K], [2.87e-4%],
    [`graph_starterpack_delete`], [Delete a starter pack], [0.2K], [9.31e-5%],
    [`actor_profile_delete`], [Delete a profile], [14], [5.82e-6%],
    [`feed_threadgate_delete`], [Remove reply-gating rules], [8], [3.33e-6%],
    [`feed_postgate_delete`], [Remove quote/embed gating], [3], [1.25e-6%],
    [`graph_follow_update`], [Update a follow record], [1], [4.16e-7%],
    )
  ],
  caption: [All firehose event types sorted by count (descending).],
) <tbl-full-event-types>

The types `graph.repost` (186), `graph.verification` (119), `lexicon.collection` (2),
`graph.cancellation` (1), and `draft.createDraft` (1) accounting for a total of 309 events discarded. Those events are either not a proxy for user activity or previous versions of the ATProto specifications.

== Fitting the events per user
<anx-data-eventperuserfitting>
The 3.09 million users are not uniformly active, as the following three figures show.

#figure(
  image("../../images/annex/data/user_hist_events_per_user.svg", width: 100%),
  caption: [Raw histogram of total events per user over the full observation window.],
) <fig-anx-events-per-user-hists>

#figure(
  image("../../images/annex/data/user_hist_events_per_day.svg", width: 100%),
  caption: [Raw histogram of events per active day.],
) <fig-anx-events-per-day-hist>

#figure(
  image("../../images/annex/data/user_hist_events_per_hour.svg", width: 100%),
  caption: [Raw histogram of events per active hour.],
) <fig-anx-events-per-hour-hist>

The heavy tail suggests a possible power-law, which would offer a natural cutoff for
filtering tourists. To test this, a discrete power-law was fitted via MLE and compared
against a lognormal using Vuong's log-likelihood ratio test (`powerlaw` package
@alstott2014powerlaw). In all three cases the power-law was decisively rejected
in favour of the lognormal (@tbl-anx-lognormal-params).

#figure(
  table(
    columns: 6,
    align: (center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Distribution*], [*$mu$*], [*$sigma$*], [*Median*], [*$R$*], [*$p$*],
    table.hline(stroke: 0.5pt),
    [Events per user], [2.40], [1.85], [11.0], [$-$397,571], [\<0.001],
    [Events per active day], [1.43], [1.28], [4.2], [$-$298,283], [\<0.001],
    [Events per active hour], [0.94], [0.89], [2.6], [$-$366,994], [\<0.001],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Lognormal parameters and comparison against power-law.
    Negative $R$ indicates lognormal is favoured (Vuong's LLR test).],
) <tbl-anx-lognormal-params>

Since the lognormal lacks a natural cutoff ---unlike the pareto, where $"x_min"$ marks it--- users with fewer than 2 events per active day were excluded heuristically (29% of users, 0.9% of events).
