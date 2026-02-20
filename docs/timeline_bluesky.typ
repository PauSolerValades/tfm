#set text(font: "Liberation Sans")

#set par(justify: true)



Here is the complete, structured technical document summarizing everything we reverse-engineered about the Bluesky architecture and timeline algorithms.

Bluesky Architecture & Timeline Algorithm Summary
1. Introduction: The AT Protocol Architecture
To understand how a feed is generated in Bluesky, one must first understand that Bluesky is not a single monolithic server. It is built on the AT Protocol, which separates the network into distinct physical and logical layers. The generation of a feed spans across these distinct environments:

The Lexicon (The Blueprint): A set of JSON schemas that define the exact inputs and outputs of every network request. It is the contract that both clients and servers must follow.

The PDS (Personal Data Server): The server where a user's data actually lives. It holds cryptographic keys and personal posts, but it lacks the global database required to build a network-wide feed.

The App View: The massive aggregator server for the Bluesky application. It listens to the entire network firehose, indexes everything into a PostgreSQL database, and handles the heavy lifting of building timelines.

The Data Plane: An internal microservice within the App View designed specifically to execute high-performance, raw SQL queries against the database.

Because of this separation, a request for a timeline originates at the PDS, gets forwarded to the App View, reaches down into the Data Plane for raw IDs, and bubbles back up through a complex pipeline before reaching the user.

2. The Timeline Lifecycle: From Request to Render
When a user's app requests their home timeline, it triggers a multi-step pipeline. Below is the exact step-by-step lifecycle of that request.

Step 1: The Request Definition (Lexicon)
The client app initiates a request to the app.bsky.feed.getTimeline endpoint. The structure of this request (accepting limit and cursor parameters, and returning an array of FeedViewPost objects) is rigidly defined by the auto-generated Lexicon types.

Reference File: packages/bsky/src/lexicon/types/app/bsky/feed/getTimeline.ts [Accessed: Feb 19, 2026]

Note: The legacy algorithm string parameter still exists in this schema but is largely unused natively, as custom feeds were offloaded to the external Feed Generator architecture.

Step 2: The PDS Proxy & Read-After-Write
The request first hits the user's PDS. Since the PDS cannot compute a global timeline, it acts as a proxy.

Reference File: packages/pds/src/api/app/bsky/feed/getTimeline.ts [Accessed: Feb 19, 2026]

Key Functions: * computeProxyTo(): Forwards the client's request to the massive App View server.

pipethroughReadAfterWrite() & formatAndInsertPostsInFeed(): Intercepts the returning feed from the App View and artificially injects the user's most recent local posts at the top of the feed to create an illusion of instantaneous posting.

Step 3: The App View Pipeline Entry
Once the request reaches the App View, it enters a strict four-step pipeline that constructs the feed from the ground up.

Reference File: packages/bsky/src/api/app/bsky/feed/getTimeline.ts [Accessed: Feb 19, 2026]

Key Function: createPipeline(skeleton, hydration, noBlocksOrMutes, presentation)

Step 4: The Skeleton (Data Plane SQL)
The first step of the pipeline (skeleton) asks the Data Plane for the raw database rows. The Data Plane does not query a "posts" table; it queries a unified feed_item table that tracks all timeline-eligible actions (posts, reposts, etc.).

Reference File: packages/bsky/src/data-plane/server/routes/feeds.ts [Accessed: Feb 19, 2026]

Key Functions:

getTimeline(): Executes the raw Kysely/SQL queries. It joins the feed_item table with the user's follow table and sorts everything chronologically by sortAt and cid. Crucially, it fetches all replies and quotes blindly without filtering them at the database level.

feedItemFromRow(): A simple function that checks if an action's uri matches the target postUri. If they differ, the item is flagged as a Repost.

Step 5: Hydration (Batching the Context)
The skeleton returns an array of bare URIs. The hydration step takes these URIs and fetches the massive amount of context needed to render them (text, author profiles, like counts, viewer states, moderation tags).

Reference File: packages/bsky/src/hydration/feed.ts [Accessed: Feb 19, 2026]

Key Class/Functions: * FeedHydrator: The class responsible for this engine.

Functions like getPosts(), getPostViewerStates(), and getPostAggregates() utilize the DataLoader pattern. Instead of querying the database per post, they accept arrays of URIs (uris: string[]) to batch hundreds of requests into a few highly optimized queries.

Step 6: Presentation (Stitching the JSON)
The final step (presentation) takes the raw, hydrated buckets of data and snaps them together into the nested JSON structure required by the Lexicon. It also acts as the final bouncer for moderation.

Reference File (Main Views): packages/bsky/src/views/index.ts [Accessed: Feb 19, 2026]

Key Functions:

feedViewPost(): Constructs the final wrapper. It merges the main post, attaches the reason if it's a repost, and calls replyRef() to append the parent/root context if the post is a comment.

recordEmbed(): Recursively calls the post-formatting logic to nest Quoted posts inside the main post's embed property.

blockedPost(): Intercepts posts from blocked users and replaces them with a safe tombstone ($type: 'app.bsky.feed.defs#blockedPost') so the client app knows to render a "Post hidden" warning instead of the content.

Step 7: Thread Sorting Algorithm (The Math)
While the Following feed is reverse-chronological, the comment section (Thread View) requires a highly complex sorting algorithm to surface the best replies.

Reference File: packages/bsky/src/views/threads-v2.ts [Accessed: Feb 19, 2026]

Key Functions:

applyBumping(): Forces VIP comments to the top (replies from the OP, replies from the viewer, or replies from mutual follows) and pushes unwanted comments to the bottom (muted users, bad tags).

topSortValue(): The mathematical heart of comment sorting. It calculates a logarithmic score based on likes: Math.log(3 + likeCount) * (hasOPLike ? 1.45 : 1.0). If the Original Poster liked the reply, its score receives a massive 1.45x multiplier.

flattenTree() & flattenInDirection(): Takes the infinitely nested tree of replies and artificially flattens it into a 1D array so mobile devices can render it efficiently using visual indentations.


3. The Reply Paradox: How Comments are Handled in the Timeline
A common point of confusion is whether replies (comments) are included in the main "Following" feed and how they are filtered. The architecture handles replies through a distinct split between backend aggregation and frontend filtering.

3.1 The Backend Firehose (No Database Filtering)
Unlike a user's profile page (which explicitly uses rules like .where('post.replyParent', 'is', null) to hide comments), the home timeline query does not filter out replies at the database level.

Reference File: packages/bsky/src/data-plane/server/routes/feeds.ts [Accessed: Feb 19, 2026]

Mechanism: The getTimeline() function queries the feed_item table blindly. To the Data Plane, a comment is structurally identical to a standard post. Every single reply authored by someone the user follows is scooped up in the initial chronological fetch.

3.2 Context Packaging (The Presentation Layer)
Once the pipeline realizes a feed_item is a comment, it must provide enough context so the post makes sense when it arrives on the user's phone.

Reference File: packages/bsky/src/views/index.ts [Accessed: Feb 19, 2026]

Mechanism: Inside the feedViewPost() function, the code detects the presence of a reply and calls this.replyRef(). This function reaches out and fetches the Parent post (the specific post being replied to) and the Root post (the start of the entire thread). It bundles the original comment and this relational context into one unified JSON package.

3.3 The Frontend Bouncer (Client-Side Filtering)
If the backend sends all replies, the timeline would theoretically be cluttered with half-conversations between mutuals and strangers. Bluesky solves this by moving the final filtering step to the client application (the user's device).

Mechanism: The backend sends the fully packaged reply JSON over the network. The frontend app (built in React Native) receives it and cross-references the replyRef context with the user's local "Following Feed Preferences" settings.

Execution: If the user's settings dictate "Require following both users," the mobile app inspects the JSON, sees that the parent author is a stranger, and simply drops the post from the UI before it ever renders on the screen. The backend provides the data; the frontend acts as the final gatekeeper.
