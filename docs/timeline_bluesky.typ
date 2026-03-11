#set text(font: "Liberation Sans")

#set par(justify: true)

#set heading(numbering: "1.")

= Introduction

This document aims to explain how is the Bluesky social repository structured and it's relation with the ATProtocol, what's a feed implementation and where is the "timeline" implementation.

= Bluesky Architecture

The AT Protocol @wiki-atproto @atproto-guides (ATP from now on) is a protocol and set of open standards for decentralized publishing and distribution of self-authenticating data within the social web. Bluesky @wiki-bluesky is a microblogging social network which serves as the reference implementation of ATP. To understand Bluesky structure, we have to take a look at how ATP is structured.

== ATP

ATP is a way to separate the content produced by the user on a social media platform from the infrastructure of the social media platform @abramov2024open. That means essentially defining a format for the characteristics of the data to be usable in _any_ social media app that implements the ATP protocol. This is to allow true sovereignty and ownership of the user-produced data, as if bluesky decided to start putting ads on the platform or adopting anti-consumer policies, users could grab theirs ATP compliant data and move to another platform that implements the ATP.

Jumping into technical details, ATP implements Lexicons @atproto-lexicon that define that define Remote Procedure Calls (RPC) for the actions the application can perform, as well as Record Types, which dictate the structure and formatting of the stored data.. Using Bluesky as example, an RPC would be `app.bsky.feed.getPostThread` and a record type `app.bsky.feed.post`.

To avoid making a language lock in, the lexicons are defined in JSON, and the actual implementation is left to the developers to do with their preferred tools. 

In summary, the Lexicon serves as a blueprint of what needs to be built to establish a client-server connection following the appropiate protocols, and it's defined in JSON, making it language agnostic.

ATP is also decentralized, which means the user data may not live in the same server as the web runs on, they are conceptually decoupled. User data is going to be stored in a Personal Data Server (PDS), where is stored and organizes according to the specification and then retrieved by the server (the social media application) as the AppView, implementing both its side of the protocol.

== at-proto repo

The bluesky implementation of the ATP can be found on Github, the `at-proto` repo @atproto-repo. As it's a very big implementation, we'll map the ATP structure described on past paragraph to the repository folders.reposts

All the rellevant code that implements the timeline is under the `packages` folder. Specifically, lexicons definitions are at `packages/bsky/src/lexicon`, personal data servers are at `packages/pds`. Lastly, we'll see several more folders under `packages/bsky/src` which implement the mechanisms under the timelines get reconstructed and displayed.

= Get the timeline: step by step and file by file

All of the following files can be found in the `atproto` github repository @atproto-repo.

== Lexicon Definition 

(Reference File: packages/bsky/src/lexicon/types/app/bsky/feed/getTimeline.ts [Accessed: Feb 19, 2026])

The lexicon definition for getting the timeline specifies the `id` of the petition (`app.bluesky.feed.getTimeline`) and how should the output be formatted. 

== How does a Bsky Client work? 

#link("https://github.com/bluesky-social/atproto/blob/main/packages/api/src/bsky-agent.ts")[Reference File 1]

#link("https://github.com/bluesky-social/atproto/blob/main/packages/xrpc/src/xrcp-client.ts")[Reference File 2]


The lexicon gets translated to code automatically, but who actually _performs_ the petition? The answer is reliant on the the bluesky agent, which gets generated wverytime a user starts a session using the XRCP engine. Reference File 2 shows how the XRCP server is inited, and this creates a `bsky-agent`, showcased in file 2, specifically, lines 60-63

```TypeScript
const reqUrl = constructMethodCallUrl(methodNsid, def, params)
const reqMethod = getMethodSchemaHTTPMethod(def)
const reqHeaders = constructMethodCallHeaders(def, data, opts)
```

Constructs the HTTP petition the agent will perform. Line 73
```TypeScript
const response = await this.fetchHandler.call(undefined, reqUrl, init)
```
Will perform the HTTP petition, in our case to the PDS of the user. Lastly, lines 86-88 will validate that the lexicon output is complying with the response recieved of the petition.

```TypeScript
try {
  this.lex.assertValidXrpcOutput(methodNsid, resBody)
}
```

== Client Petition

#link("https://github.com/bluesky-social/atproto/blob/main/packages/api/src/client/types/app/bsky/feed/getTimeline.ts")[Reference File]

From the lexicon definition, the client id is generated at `packages/api/src/client/types/app/bsky/feed/getTimeline.ts`. Line 17 `const id = app.bsky.feed.getTimeline` shows the id defined in the lexicon, which allowed us to connect this is the petition start.


== PDS Redirection

#link("https://github.com/bluesky-social/atproto/blob/main/packages/pds/src/api/app/bsky/feed/getTimeline.ts")[Reference File: `packages/pds/src/api/app/bsky/feed/getTimeline.ts`].

The request tries to fetch the data from the user PDS, specifically this lines:
```
export default function (server: Server, ctx: AppContext) {
  if (!ctx.bskyAppView) return

  server.app.bsky.feed.getTimeline({
    auth: ctx.authVerifier.authorization({
      authorize: (permissions, { req }) => {
        const lxm = ids.AppBskyFeedGetTimeline
        const aud = computeProxyTo(ctx, req, lxm)
        permissions.assertRpc({ aud, lxm })
      },
    }),
    handler: async (reqCtx) => {
      return pipethroughReadAfterWrite(ctx, reqCtx, getTimelineMunge)
    },
  })
}
```
Since the PDS cannot compute a global timeline, it acts as a proxy `computeProxyTo` and gets handled to the App View implementation, which will actually construct the timeline.

== Timeline Creation

#link("https://github.com/bluesky-social/atproto/blob/main/packages/bsky/src/api/app/bsky/feed/getTimeline.ts")[Reference File: `packages/bsky/src/api/app/bsky/feed/getTimeline.ts`]

The App View is where the actual ensamble of the contents of the timeline will happen, as it can be seen in lines 17-45:

```TypeScript
export default function (server: Server, ctx: AppContext) {
  const getTimeline = createPipeline(
    skeleton,
    hydration,
    noBlocksOrMutes,
    presentation,
  )
  server.app.bsky.feed.getTimeline({
    auth: ctx.authVerifier.standard,
    handler: async ({ params, auth, req }) => {
      const viewer = auth.credentials.iss
      const labelers = ctx.reqLabelers(req)
      const hydrateCtx = await ctx.hydrator.createContext({ labelers, viewer })

      const result = await getTimeline(
        { ...params, hydrateCtx: hydrateCtx.copy({ viewer }) },
        ctx,
      )

      const repoRev = await ctx.hydrator.actor.getRepoRevSafe(viewer)

      return {
        encoding: 'application/json',
        body: result,
        headers: resHeaders({ labelers: hydrateCtx.labelers, repoRev }),
      }
    },
  })
}
```

Specifically, the `createPipeline` function will use those four arguments to create the timeline in four steps, which can be summarized by the following:
- Skeleton: fetches a reverse-chronological sorted list of IDs from the `data-plane`. Here are the high-performance SQL queries.
- Hydration: given the list of IDs, the actual contents of the posts are attached to the skeleton.
- No blocks or Mutes: deletes the posts from muted and blocked users.
- Presentation: formats the JSON to comply with the lexicon defined output.

=== Skeleton

#link("https://github.com/bluesky-social/atproto/blob/main/packages/bsky/src/data-plane/server/routes/feeds.ts")[Reference File: packages/bsky/src/data-plane/server/routes/feeds.ts]

The function getTimeline gets all the ids. The code explains itself, and the comments are added explanations, not from the source code.

```TypeScript
async getTimeline(req) {
  const { actorDid, limit, cursor } = req
  const { ref } = db.db.dynamic
  
  // output must be sorted by time and id
  const keyset = new TimeCidKeyset(
    ref('feed_item.sortAt'),
    ref('feed_item.cid'),
  )
  
  // fetch all follow posts
  let followQb = db.db
    .selectFrom('feed_item')
    .innerJoin('follow', 'follow.subjectDid', 'feed_item.originatorDid')
    .where('follow.creator', '=', actorDid)
    .selectAll('feed_item')

  // structure it in paginations for easier retreival
  followQb = paginate(followQb, {
    limit,
    cursor,
    keyset,
    tryIndex: true,
  })
  
  // fetch user own posts
  let selfQb = db.db
    .selectFrom('feed_item')
    .where('feed_item.originatorDid', '=', actorDid)
    .selectAll('feed_item')

  selfQb = paginate(selfQb, {
    limit: Math.min(limit, 10),
    cursor,
    keyset,
    tryIndex: true,
  })
  
  // execute the query
  const [followRes, selfRes] = await Promise.all([
    followQb.execute(),
    selfQb.execute(),
  ])
  
  // sort all the ids from the merged lists.
  const feedItems = [...followRes, ...selfRes]
    .sort((a, b) => {
      if (a.sortAt > b.sortAt) return -1
      if (a.sortAt < b.sortAt) return 1
      return a.cid > b.cid ? -1 : 1
    })
    .slice(0, limit)
  
  // return the results
  return {
    items: feedItems.map(feedItemFromRow),
    cursor: keyset.packFromResult(feedItems),
  }
}

// If the row.uri === row.postUri, means that this post is a repost!
const feedItemFromRow = (row: { postUri: string; uri: string }) => {
  return {
    uri: row.postUri,
    repost: row.uri === row.postUri ? undefined : row.uri,
  }
}
```

Summary: this function fetches *all written posts*: posts, quotes and replies. If it's a repost, `feedItemFromRow` handles it.

=== Presentation

#link("https://github.com/bluesky-social/atproto/blob/main/packages/bsky/src/views/index.ts")[Reference File: `packages/bsky/src/views/index.ts`]

The Presentation layer is the final quality-control checkpoint. Inside the `feedViewPost` orchestrator, the server ensures the raw IDs fetched during the Skeleton phase are safely converted into the strict JSON format required by the Lexicon.

Crucially, it acts as a defensive safety net against "traps" like deleted content or third-party blocks. If a referenced post (like a parent reply) has been deleted or belongs to an author who blocked the viewing user, the presentation layer does not simply drop the item or crash. Instead, it uses a helper function like `maybePost` to swap the missing content with a safe "tombstone" object (e.g., `$type: 'app.bsky.feed.defs#notFoundPost`). This tells the mobile application to gracefully render a "Post deleted" or "Post hidden" warning instead of breaking the timeline.


The `replyRef` function is specifically responsible for packaging conversational context so that replies make sense on the user's screen.

Let's model a network where user $u_1$ follows user $u_2$, and user $u_3$ is a stranger (not followed by $u_1$). If $u_2$ takes an action, the server will evaluate and bundle the context for $u_1$'s timeline as follows:
- Scenario A (Root Reply): If $u_2$ replies directly to a root post authored by $u_3$ (and $u_3$ is neither blocked nor muted by $u_1$), the server bundles both posts into a single timeline item. The payload guarantees $u_1$ receives $u_2$'s reply and $u_3$'s root post for context.
- Scenario B (Deep Thread Reply): If $u_2$ replies to a deep comment authored by $u_3$, the server will bundle $u_2$'s reply, $u_3$'s specific comment (the parent), and the original root post of the thread.

In all valid scenarios, the server delivers these bundled posts as a single, unified item. The client application uses this package to visually draw the conversational thread. (Note: The frontend application retains the ultimate power to drop this entire bundle from the screen if $u_1$'s personal settings dictate they do not want to see replies involving strangers).




#bibliography("timeline_bib.yml")
