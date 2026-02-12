= Bluesky Social Description 

Bluesky is a Twitter-style social network. All the concepts described in this document can be found in the Bluesky Documentation @bluesky-docs. 


== Posts
_[obtained from @bluesky-creating-post]_

Core of the network. JSON object with keys "text" and "createdAt", which are required. Once created it will be defined by `uri` (universal resource identifier) and `cid` (content-hash id).

The `uri` has this form

```
"at://" AUTHORITY [ PATH ] [ "?" QUERY ] [ "#" FRAGMENT ]
```

- AUTHORITY: is a DID @bluesky-resolving-identities (which are a persistent long term identifiers for every account) or a handle @bluesky-resolving-identities (the '@' of bluesky). That's who owns (did) the post.
- PATH: contains where is the post and its specific identifier `app.bsky.feed.post/3jwdwj2ctlk26`
- QUERY and FRAGMENT: not supported
 
A post can be liked, replied, reposted and quoted.

A reply and a quote contain strong references to the post the action is being applied to as well as the keys of a normal post. Specifically, on one hand, the replies the root post (the start of the chain) is needed, and the parent of the post also. First reply will have the same content in root and parent.

On the other hand, a quote contains an embed, which is a reference to the type of post and report

=== Feeds
_[source: @bluesky-viewing-feeds]_

Feeds are lists of posts paginated by cursors (what controls the paging of the sent content, technically relevant for content moving, not really rellevant here), and has three types of feeds:
+ timelines: chronological order of user posts
+ feed generators: that's the discover feed, are custom and can be made by anyone.
+ author: feed of post by a single author (that is checking your historic?)

Essentially are a big fat JSON paginated by the cursor.

=== Threads

_[source: @bluesky-threads]_

A thread refers to a post, its replies (descendants) and its parents (ancestors). To obtain a thread you must query them by `uri`, reply depth and parent height.

The post queried is the root of the thread. Parent is a tree-like structure of depth specified and replies is a one dimensional array with all the replies to that post. Each reply contains references to that data.

=== Like and Repost

_[source: @bluesky-like-repost]_

Posts can be liked and reposted. Likes don't get shown to other users, but every user has a likes page which contains all the posts. Repost makes a post appear in the author feed of the user, and therefore being shown in other users timelines.

Note, apparently everything is specified in the AT Protocol (Authentication Transfer) @wikipedia-at-protocol. Might be worth it to take a look into that.

== Users

Every user has a profile: it's biographical information and its historic (which can be requested as a thread).

A user can follow other users, which defines what the timelines for each user will be.

A user can mute another user, which will hide the posts from the muted user to appear on its timeline.
A user can block another user, which will prevent iteraction between the blocked user and the blockee. Blocked accounts will not be able to like, reply, repost and quote or follow, as well as post replies and profile being hidden from the blockee.









#pagebreak()
#bibliography("bib.yml")
