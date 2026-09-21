

This section models and introduced notation for a microblogging social network objects and features, as well as establishing the scope of the implemented features in @sec-model-notation. Then, it introduces the full model that will be used to synthetically generate cascades in @sec-model-ctic.

== Modelization and Notation
<sec-model-notation>

As described in @sec-sota-description and @sec-sota-bluesky, a microblogging social network is a very extensive set of features to model and later implement. To adapt it into a reasonable scope, the following features have been chosen as a minimum features to reproduce a microblogging social media platform. 

*1. Just the Following Feed*: The "Following" feed is a timeline with a reverse-chronological post showing criteria, and from now on this will be referred to as the _timeline_ of every user. As simulating a recommender is a difficult challenge in itself, it is believed that the flow of information can be meaningfully studied with a more traditional content strategy. Even if the use of more traditional timelines is not how the majority of users engage with content, are still rellevant to study as they are the most simplest recomendations feeds, which will produce information diffusion patterns and is usually used in the literature as a baseline. #footnote[In fact, European Digital Services Act is making the existence of a non-algorithmic recommender feed obligatory @diemel2022digital (as well as very recent Australian law @budde2026digital), and most of the companies opt to implement a traditional reverse-chronological timeline. ]

*2. Static Users and Followers*: During the course of the simulation, no new users will be added, nor new relationships between them. The inter-user relationships are considered static during the whole duration of the simulation, as the flow of content can be studied without this behavior.

*3. No Mutes nor Blocks*: We assume that if user $u$ follows user $v$, user $u$ will receive all posts from user $v$.

*4. No Quotes, no Replies*: To further simplify the model (and given the assumptions that will be stated in @sec-method-des-assumptions) quotes and replies will not be included. They are going to add a lot of modelization complexity for what is deemed as diminishing returns. See @apx-mechanics for more about additional mechanics.

*5. No Profile of a User*: A user won't be able to enter to see other users' profiles; they will be limited to observing their posts on the timeline.

Let's define which features of Bluesky are going to be modeled in the simulation:
1. Users can act over a post by liking or reposting it.
2. Users see posts in a timeline: posts will be seen in reverse-chronological order from the accounts they follow.


To model these dynamics, this section introduces a unified mathematical notation that models the microblogging platform as a Time-Varying Heterogeneous Graph @casteigts2012timevarying. This formulation rests on the acknowledgment that there are two distinct entities ---users and posts--- as well as different types of edges to characterize the relationships between entities of the same type and different types. The relationships between the entities are, by their very nature, changing over time.

#def(name: "Time-Varying Heterogeneous Graph")[Having established the temporal properties of our entities and their relationships, we formally define our system as a Time-Varying Graph $cal(G) = (V, E, T, rho, psi, eta)$. Here, $V$ and $E$ form the universal topological space, $T$ is the time domain, $psi$ and $rho$ govern the temporal existence of nodes and edges respectively, and $eta$ bounds the chronological flow of information across the network.]

The following text defines and maps all the functions and sets according to this given definition.

=== Network Entities and Topology

The model consists of two entities: users $cal(U)$ and posts $cal(I)$ #footnote[the nomenclature $cal(I)$ (caligraphic I) stems from recommender theory, and stands as I from Items]. Unlike traditional dynamic graphs where the set of vertices grows, we define the graph over the universe of all entities that will ever participate in the simulation. 

#def(name: "Universal Nodes")[The node set $V$ is the static union of all participating entities throughout the entire simulation lifecycle: $V = cal(U) union cal(I)$.]

To represent the temporal reality of posts being created, we introduce a node presence function $psi$. Given the continuous time domain $T = RR^+$, the presence function dictates whether a node exists at time $t$:

$ psi: V times T -> {0, 1} $

Due to our simulation assumptions, the user base remains stable, meaning $forall u in cal(U), forall t in T, psi(u, t) = 1$. In contrast, a post $i in cal(I)$ is intrinsically tied to its creation timestamp $t_c$. Thus, its presence is a step function:
$ psi(i, t) = cases(1 "if" t >= t_c, 0 "otherwise") $

We can now cleanly define the set of available items at any time $t$ simply as $cal(I)_t = { i in cal(I) | psi(i, t) = 1 }$.

=== Relational Dynamics and Edge Properties

Similar to the node set, we define a universal edge set $E$ containing every potential interaction between entities. There are two types of relationships: $cal(R)_(cal(U) cal(U)) = {"follow"}$ and $cal(R)_(cal(U) cal(I)) = { "create", "like", "repost", "view" }$. As unorthodox it may seem, the "view" (user $i$ does not interact with post $i$ but gets exposed to it) is modeled as an action a user takes at a specific time. It makes the concept more intuitive despite having a no concrete equivalent in a social media platform.

#def(name: "Universal Edges")[We denote the set of all possible edges $E = E_(cal(U)cal(U)) union E_(cal(U)cal(I))$, where 
$ E_(cal(U)cal(I)) = { (u, i, r) | u in cal(U), i in cal(I), r in cal(R)_(cal(U) cal(I)) } $
$ E_(cal(U)cal(U)) = { (u, v, "follow") | u in cal(U), v in cal(U) } $]

To capture the specific temporal dynamics of these connections, we define two continuous-time functions over the edge set: the edge presence function $rho$ and the latency function $eta$.

#def(name: "Edge Presence")[The function $rho: E times T -> {0, 1}$ indicates if an interaction or connection is active at a given time. Its behavior depends on the edge type:
1. *Structural Edges* ($E_(cal(U)cal(U))$): A follow relationship initiated at $t_f$ persists, meaning $rho((u, v, "follow"), t) = 1$ for all $t >= t_f$.
2. *Event Edges* ($E_(cal(U)cal(I))$): Actions upon items are punctual events. If user $u$ performs action $r$ on item $i$ exactly at time $t_e$, then $rho((u, i, r), t_e) = 1$, and $0$ otherwise. Specifically, the $"create"$ relationship triggers the node presence of a post: $rho((u, i, "create"), t_c) = 1 arrow.r.double psi(i, t) = 1$ for all $t >= t_c$.]

=== Time Delays

#def(name: "Edge Latency")[Information dissemination and user reactions are not instantaneous. We define a latency function $eta: E times T -> T$ that maps every edge to a specific temporal delay based on its interaction type:
- *Propagation Delay*: Associated with structural follow edges $e in E_(cal(U)cal(U))$, dictating the time required for a followee's action to surface on the observer's timeline.
- *Interaction Delay*: Associated with reactive event edges $e = (u, i, r)$ where $r in {"like", "repost", "ignore"}$, representing the cognitive processing time before a user reacts to a post.
- *Creation Delay*: Associated with generative event edges $e = (u, i, "create")$, representing the time taken to compose and publish a new item.]

It is necessary to have a delay when information propagates to avoid instant information transmission. In @anx-ex-teleport there is an example showcasing why the propagation delay is necessary.

=== User Session Dynamics
<sec-model-sessions>

Individual user engagement occurs in discrete, contiguous sessions. Rather than defining an external state function, these sessions act as an intrinsic structural constraint on the edge presence function $rho$.

#def(name: "User Sessions")[We define the periods a user $u$ is online as a subset of time $cal(O)(u) subset T$. The edge presence function for any reactive or generative event is strictly constrained by this subset. If a user is offline, no action edges can be generated:
$ t in.not cal(O)(u) arrow.r.double forall i in cal(I), forall r in cal(R)_(cal(U)cal(I)), rho((u, i, r), t) = 0 $

Consequently, the creation of any event edge inherently requires the user to be in an active session:
$ rho((u, i, r), t) = 1 arrow.r.double t in cal(O)(u) $]


=== Followers and Followees

We can define the users that a specific user $u$ is following, and the users that follow them:

#def(name: "Following")[The subset of users that user $u in cal(U)$ is following, assuming connections are established at $t=0$, is denoted as 
$ cal(N)_"out" (u) = { v in cal(U) | rho((u, v, "follow"), 0) = 1 }. $] 

This dictates the sources of information populating user $u$'s timeline, and coincides with the concept of the out-neighborhood of a node in graph theory.
 
#def(name: "Followers")[The subset of users that follow user $u$, assuming connections are established at $t=0$, is denoted as 
$ cal(N)_"in" (u) = { v in cal(U) | rho((v, u, "follow"), 0) = 1 }. $]

These are the users affected by user $u$'s actions.

@fig-model-example-graph illustrate a simple three-user topology to ground these definitions.

#figure(
  cetz.canvas({
    import cetz.draw: *

    // Nodes
    circle((0, 2.5), radius: 0.4, name: "A", stroke: blue)
    content("A", [*A*])

    circle((-1.5, 0), radius: 0.4, name: "B", stroke: green)
    content("B", [*B*])

    circle((1.5, 0), radius: 0.4, name: "C", stroke: red)
    content("C", [*C*])

    // Edges: B→A, C→A, C→B
    line("B", "A", mark: (end: ">", fill: black))
    line("C", "A", mark: (end: ">", fill: black))
    line("C", "B", mark: (end: ">", fill: black))
  }),
  caption: flex-caption(
    [Three-user follower graph.],
    [Directed graph of the three-user topology: $B$ and $C$ follow $A$, $C$ also follows $B$. $A$ is a pure source (no outgoing edges), $C$ is a pure consumer (no incoming edges).]
  )
) <fig-model-example-graph>

$A$ is a pure source (follows no one, two followers). $B$ sits in the middle (one follower, one followee). $C$ is a pure consumer (follows two people, no followers).  A user's timeline is populated by their followees; their posts reach their followers.

=== User Activity and Timeline Construction

To construct a user's timeline, we extract the historical footprint of the network using the edge presence function $rho$, while accounting for the delays defined by $eta$.

#def(name: "User Activity")[The active footprint of a user $cal(A)_t(u)$ includes all items the user has actively propagated prior to time $t$. 
$ cal(A)_t (u) = { i in cal(I) | exists e = (u, i, r) in E \\ "where" rho(e, tau) = 1 "for some" tau < t "and" r in {"repost", "create"} } $ <def-activity>
]

#def(name: "Timeline")[The timeline $cal(T)_t (u)$ is the aggregated activity of the user's out-neighborhood $cal(N)_"out" (u)$, strictly excluding items the user organically authored themselves, $cal(P)_t(u)$. The time at which an item from followee $v$ appears in $u$'s timeline is offset by the propagation delay $eta((u, v, "follow"), t)$:
$ cal(T)_t (u) = ( union.big_(v in cal(N)_"out" (u)) cal(A)_(t - eta((u, v, "follow"), t))(v) ) - cal(P)_t (u) $]

The subindex $t$ in the timeline makes posts available to be inserted (or extracted) according to the value of time $t$. The resulting event $e_1 = cal(T)_(t_1) (u) != cal(T)_(t_2) (u) = e_2$ where $t_1 <= t_2$.

Lastly, we have to define a set that contains all the interacted posts by a given user $u$. This is needed to comply with the CTIC model, as a user cannot propagate if it has already been infected. We will call the set interaction history.
