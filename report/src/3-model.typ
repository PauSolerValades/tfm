#import "utils.typ": def, flex-caption, todo, comment
#import "@preview/cetz:0.4.2"

This section justifies which features of Bluesky are going to be modeled from the exhaustive description provided in @sec-sota-description. Then, proceeds to model and introduce notation for the problem. 

== Modelization and Notation

To pick the most rellevant subset of features is needed to not drown in unnecessary complexity and to keep adhered to the time and scope constraints. It is believed that the selected subset of features will behave as a microblogging social network.

*1. Just the Following Feed*: The following feed is a timeline with a reverse-chronological post showing criteria, and from now on this will be referred to as the _timeline_ of every user. As simulating a recommender is a difficult challenge in itself, it is believed that the flow of information can be meaningfully studied with a more traditional content strategy, even if the use of these feeds is not the norm on social networks. 

*2. Static Users and Followers*: During the course of the simulation, no new users will be added, nor new relationships between them. The inter-user relationships are considered static during the whole duration of the simulation, as the flow of content can be studied without this behavior.

*3. No Mutes nor Blocks*: We assume that if user $u$ follows user $v$, user $u$ will receive all posts from user $v$.

*4. No Quotes, no Replies*: To further simplify the model (and given the assumptions that will be stated in @sec-method-des-assumptions) quotes and replies will not be included. They are going to add a lot of modelization complexity for what is deemed diminishing returns. See @apx-mechanics for more about additional mechanics.

*5. No Profile of a User*: A user won't be able to enter to see other users' profiles; they will be limited to observing their posts on the timeline.

Let's define which features of Bluesky are going to be modeled in the simulation:
1. Users can act over a post by liking or reposting it.
2. Users see posts in a timeline: posts will be seen in reverse-chronological order from the accounts they follow.


To model these dynamics, this section introduces a unified mathematical notation that models the microblogging platform as a Time-Varying Heterogeneous Graph @casteigts2012timevarying. This formulation rests on the acknowledgment that there are two distinct entities ---users and posts--- as well as different types of edges to characterize the relationships between entities of the same type and different types. The relationships between the entities are, by their very nature, changing over time.

#def(name: "Time-Varying Heterogeneous Graph")[Having established the temporal properties of our entities and their relationships, we formally define our system as a Time-Varying Graph $cal(G) = (V, E, T, rho, psi, eta)$. Here, $V$ and $E$ form the universal topological space, $psi$ and $rho$ govern the temporal existence of nodes and edges respectively, and $eta$ bounds the chronological flow of information across the network.]

The following text defines and maps all the functions and sets according to this given definition.

=== Network Entities and Topology

The model consists of two entities: users $cal(U)$ and posts $cal(I)$ #footnote[the nomenclature $cal(I)$ stems from recommender theory, and stands for items]. Unlike traditional dynamic graphs where the set of vertices grows, we define the graph over the universe of all entities that will ever participate in the simulation. 

#def(name: "Universal Nodes")[The node set $V$ is the static union of all participating entities throughout the entire simulation lifecycle: $V = cal(U) union cal(I)$.]

To represent the temporal reality of posts being created, we introduce a node presence function $psi$. Given the continuous time domain $T = RR^+$, the presence function dictates whether a node exists at time $t$:

$ psi: V times T -> {0, 1} $

Due to our simulation assumptions, the user base remains stable, meaning $forall u in cal(U), forall t in T, psi(u, t) = 1$. In contrast, a post $i in cal(I)$ is intrinsically tied to its creation timestamp $t_c$. Thus, its presence is a step function:
$ psi(i, t) = cases(1 "if" t >= t_c, 0 "otherwise") $

We can now cleanly define the set of available items at any time $t$ simply as $cal(I)_t = { i in cal(I) | psi(i, t) = 1 }$.

=== Relational Dynamics and Edge Properties

Similar to the node set, we define a universal edge set $E$ containing every potential interaction between entities. There are two types of relationships: $cal(R)_(cal(U) cal(U)) = {"follow"}$ and $cal(R)_(cal(U) cal(I)) = { "create", "like", "repost", "ignore" }$. As orthodox it may seem, the "ignore" (user $i$ does not interact with post $i$) is modeled as an action a user takes at a specific time. It makes the concept more intuitive despite having a no concrete equivalent in a social media platform.

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

It is necessary to have a delay when information propagates to avoid instant information transmission. In Implementation @sec-design-sources-propagate there is an example showcasing why it is necessary. In Methodology @sec-model-ctic it is also explained why is necessary to fit a specific model.

=== User Session Dynamics
<sec-model-sessions>

Individual user engagement occurs in discrete, contiguous sessions. Rather than defining an external state function, these sessions act as an intrinsic structural constraint on the edge presence function $rho$.

#def(name: "User Sessions")[We define the periods a user $u$ is online as a subset of time $cal(O)(u) subset T$. The edge presence function for any reactive or generative event is strictly constrained by this subset. If a user is offline, no action edges can be generated:
$ t in.not cal(O)(u) arrow.r.double forall i in cal(I), forall r in cal(R)_(cal(U)cal(I)), rho((u, i, r), t) = 0 $

Consequently, the existence of any event edge inherently requires the user to be in an active session:
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
$ cal(A)_t (u) = { i in cal(I) | exists e = (u, i, r) in E "where" rho(e, tau) = 1 "for some" tau < t "and" r in {"repost", "create"} } $ <def-activity>
]

#def(name: "Timeline")[The timeline $cal(T)_t (u)$ is the aggregated activity of the user's out-neighborhood $cal(N)_"out" (u)$, strictly excluding items the user organically authored themselves, $cal(P)_t(u)$. The time at which an item from followee $v$ appears in $u$'s timeline is offset by the propagation delay $eta((u, v, "follow"), t)$:
$ cal(T)_t (u) = ( union.big_(v in cal(N)_"out" (u)) cal(A)_(t - eta((u, v, "follow"), t))(v) ) - cal(P)_t (u) $]

The subindex $t$ in the timeline makes posts available tot pop (or to push) according to t. The resulting event $e_1 = cal(T)_(t_1) (u) != e_2 cal(T)_(t_2)$ where $t_1 <= t_2$.

Lastly, we have to define an set that contains all the interacted posts by a given user $u$. This is needed to comply with the CTIC model, as a user cannot propagate if it has already been infected. We will call the set interaction history.

#def(name: "User Interaction History")[The Interaction History set of a user $cal(H)_t (u)$ includes all the items the user has either propagated or liked prior to time $t$

$ cal(H)_t (u) = { i in cal(I) | exists e = (u, i, r) in E "where" rho(e, tau) = 1 "for some" tau < t "and" r in {"repost", "like"} } $ 
]


=== User Decisions and Policy

The interactions within the network are driven by the decision-making processes of the users. We model user behavior through a policy $pi$, which governs the probability of executing specific actions. Because consuming existing content and generating new content are fundamentally different mechanisms, the policy is bifurcated into two distinct components: a reactive policy and a spontaneous generative policy.

1. *Reactive Policy (User-to-Post):* When an online user is presented with a post $i$ in their timeline $cal(T)_t (u)$, they must decide how to interact with it. We define the reactive policy $pi_"act"$ as a probability distribution over the subset of timeline-permissible actions, $cal(R)'_(cal(U)cal(I)) = {"ignore", "like", "repost"}$. 

$ sum_(a in cal(R)'_(cal(U)cal(I))) pi (a) = 1 $

2. *Spontaneous Policy (Creation):* The act of creating a new post does not depend on the contents of the timeline; it is a spontaneous event generated by the user. We define the generative policy $lambda$ as the probability (or rate) at which an online user decides to execute the $"create"$ action during a given time step or session, introducing a completely new item into $cal(I)_t$.

== Model
<sec-model-ctic>

This section details the model chosen to evaluate the information diffusion. To accurately capture the real-world dynamics of the phenomena, we integrate the mathematically rigorous Continuous-Time Independent Cascade (CTIC) model (see @sec-sota-diffusion-ctic) with a Queue-Based (see @sec-model-ctic), Activity-Driven simulation architecture.

#todo[revise everything in here throrugly to shorten if possible]

=== Continuous-Time Diffusion in Microblogging
<sec-method-ctic>

To accurately represent the dynamics of information diffusion on a microblogging platform like Bluesky (see @sec-sota-description), we utilize the Continuous-Time Independent Cascade (CTIC) (see @sec-sota-diffusion-ctic) model. While standard diffusion models operate in discrete, synchronized epochs @gomezrodriguez2012inferring, real-world microblogging is fundamentally asynchronous: users do not consume information in locked steps; rather, information propagation occurs continuously over time. 

The CTIC model is a good fit for microblogging networks due to its reliance on survival analysis and time-dependent transmission likelihoods: posts are injected into a fast-moving, chronologically ordered feed. A post's "survival" (its probability of being seen and reposted before being buried by newer content) is heavily dependent on the exact continuous time elapsed since its creation @gomezrodriguez2011uncovering. By allowing transmission at different rates using continuous temporal processes (such as exponential or power-law distributions), the CTIC model naturally captures the temporally heterogeneous interactions and long-tailed viral fads characteristic of modern social media.

While the CTIC model provides the ideal theoretical framework for continuous-time diffusion, evaluating these continuous hazard and survival functions analytically across a massive, highly connected graph is computationally prohibitive. Therefore, to operationalize this model, we chose to translate the continuous-time dynamics into a Discrete Event Simulation (DES) (see @sec-method-des).  

By modeling the system as a chronological sequence of discrete events—such as post creation, propagation, and user session initializations—we can simulate the exact continuous-time timestamps of the CTIC model without calculating the continuous time in between. Needless to say, the distinction is purely practical, as the definition of CTIC just impose a different quantity $t_i > t_j$, which the DES modelization absolutely fulfills. The methodology and assumptions of this DES approach are detailed in @sec-method-des, while the design of the simulation (architecture, event semantics) is documented in @sec-design and its concrete implementation (data structures, performance optimizations) in @sec-impl

=== The Homogeneous Rate Simplification


In the Gomez Rodríguez et. al article @gomezrodriguez2011uncovering, the theoretical formulation of the CTIC model has the transmission likelihood governed by a specific pairwise transmission rate, $alpha_(j,i)$, defined uniquely for every directed edge from node $j$ to node $i$. This parameter needs to be "flattened" due to the user homogeneity (see @sec-method-des-assumptions for context), so the transmission rate is uniform across all network edges, such that:

$ alpha_(i,j) = alpha quad forall i, j in V $

where $V$ is the set of all users in the network. This universal rate, $alpha$, represents the global `propagation_delay` of the network and platform: the continuous time required for a post to be processed by the platform's infrastructure and appearing into a follower's timeline.

This simplification plays very nice into the actual dynamics of modeling an OSN: content cannot immediately appear in other users timelines without any explanation, as that is not accurate in respect of reality and could generate degenerated cases (post being created and immediately having several reposts) on the simulation traces (see @sec-design-traces). Also, this conveys a implicit and very noticeable computational advantage.

A more structural justification for uniform $alpha$ comes from the timeline itself. The reverse-chronological feed operates as a LIFO (Last-In, First-Out) queue @hodas2014simple: the most recently propagated post sits at the top, and the user scrolls downward through progressively older content. When $alpha$ varies per edge, a post created earlier but delayed by a slow transmission could arrive after a post created later via a fast edge, scrambling the expected temporal ordering. Uniform $alpha$ guarantees that propagation preserves the global creation order: if post $p_1$ is created before post $p_2$, then $p_1$ will appear in every follower's timeline before $p_2$. This makes the timeline a faithful temporal projection of the platform's activity, which is both analytically cleaner and closer to how a real microblogging feed behaves in the absence of algorithmic reordering. 



=== Activity-Driven Network Dynamics
<sec-method-activity>

When modeling an OSN with users as the primary entities, there is a particular aspect that is highly intuitive for human behavior but heterodox in traditional graph theory: nodes are not available for information transmission at all times; rather, their availability is a function of time $t$. 

Standard static network models assume that nodes and edges are perpetually available for information transmission. However, empirical studies of social and technological systems reveal that human interactions are fundamentally bursty and temporally disconnected @barabási2005bursts. To capture this reality, the Activity-Driven modeling framework describes a time-varying network where the topological evolution is strictly governed by the intrinsic behavioral patterns of individual nodes @pozzana2017epidemic.

In this paradigm, each user is characterized by an "activity" rate, defined as their propensity to engage with the network and form connections at a given time. Consequently, nodes alternate between discrete online sessions and offline "vacation" periods. As explained when modeling the problem (see @sec-model-ctic), this bursty interactions have already been modeled as $cal(O) (u)$, and despite no restrictions being imposed on it's nature, we can characterize it as

$ cal(O) (u) = union.big_(k=1)^oo [t_k, t_k + Delta_k) "where" t_k in T $

and $Delta_k$ is a positive random variable representing the sessions duration. 

- The interval $I_k = [t_k, t_k + Delta_k)$ constitutes the online duration (sampled from `session_duration`).
- The gap between sessions, mathematically expressed as $d = t_(k+1) - (t_k + Delta_k)$, constitutes the offline vacation period (sampled from `user_inter_session`; see @sec-calibration-summary).

In OSNs, these activity states are usually called sessions: a user starts a session when they log in to the platform to consume content, and it ends when they close the application or log off.

While the Activity-Driven framework dictates when users are present in the network via $cal(O)(u)$, it does not fully explain how they consume information. Social contagion is heavily moderated by the cognitive limits of human processing and the user interface of the platform itself @hirakura2023method @hodas2014simple. 

=== Lifetime Description
#todo[this section i think it's very interesting if strigtened up and shortened.]
To mathematically capture this cognitive bottleneck within our formal model, information diffusion is modeled as a reverse-chronological queueing process. As established in @sec-model-ctic, this is resolved by the timeline subset $cal(T)_t (u)$, which functions as a time-descending priority queue where propagated posts are stored.

Let us assume a post $i$ is created (or reposted) by user $u$ at time $t$, and $v in cal(N)_"out"(u)$ is a follower of user $u$. The exact time user $v$ is actually exposed to this post, denoted as $tau$, can be modeled as:

$ tau = t_a + X $

where $t_a = t + eta((u,v,"follow"), t)$ is the exact arrival time of the post in the timeline (incorporating the structural platform delay), and $X$ is a dynamic random variable representing the user-side consumption delay. 

Because the timeline is sorted in reverse-chronological order (newest first), $X$ is a complex convolution of the user's offline status and their scrolling behavior, structured as:

$ X = Delta_"idle" + Delta_"scroll" $

These components behave strictly according to the LIFO (Last-In, First-Out) nature of the timeline:
+ *Offline Penalty ($Delta_"idle"$)*: If the post arrives at time $t_a$ while the user is offline ($t_a in.not cal(O)(v)$), it sits unseen until the user's next active session interval $I_k$ begins at $t_k$. Therefore, $Delta_"idle" = t_k - t_a$. If the user is already online when the post arrives, it appears at the top of the feed, meaning $Delta_"idle"$ is effectively just the time until the user's next immediate action tick.
+ *Reverse-Chronological Processing ($Delta_"scroll"$)*: Once the user is online, they consume the feed from newest to oldest. Therefore, the "backlog" obstructing post $i$ does not consist of older posts, but of $N_"newer"$ posts that arrived *after* $t_a$ (e.g., while the user was still offline). $Delta_"scroll"$ represents the cumulative inter-action time required for the user to evaluate and scroll past all $N_"newer"$ posts positioned above post $i$ in $cal(T)_t (v)$.

This reverse-chronological dynamic introduces a somewhat survival mechanism for the posts, perfectly mirroring the hazard functions of the CTIC model. If a post arrives early in a long offline period, a massive volume of newer posts will pile on top of it. When the user logs in, the required $Delta_"scroll"$ to reach the post will be exceptionally high. 

If the user's active session duration $Delta_k$ is shorter than the time required to scroll past the newer content ($Delta_"scroll" > Delta_k$), the transmission opportunity is lost entirely. In our simulation, timelines are purged upon session termination, meaning buried, unread posts fail to propagate ($tau -> oo$). Because $X$ dynamically depends on the instantaneous influx of competing posts and overlapping temporal session boundaries, it is mathematically intractable to solve via closed-form equations, which justifies the use of a Discrete Event Simulation (DES), which allows us to natively resolve $X$ by simulating reverse-chronological consumption step-by-step.

=== Post Lifetime Analysis
#todo[this section i think it's very interesting if strigtened up and shortened, as well as how this dynamic affect the cascades generations]

To formally synthesize this dynamic, the probability of post $i$ surviving the queue and being seen by user $v$ is fundamentally dictated by the volume of competing information. We can define a timeline influx rate, $mu_v$:

#def(name: "Influx Rate")[The influx rate $mu_v$ is the expected number of posts arriving per unit of time in user $v$'s timeline.]

As a macroscopic variable, $mu_v$ is an aggregation of the network topology (the out-degree $|cal(N)_"out"(v)|$), the generative creation rates of those followees ($lambda$), and their reactive repost probabilities ($pi("repost")$), for which we do not attempt to derive a closed-form analytical expression.

If post $i$ arrives at time $t_a$ while the user is offline, it will sit idle until the next session begins at $t_k$, resulting in an offline penalty $Delta_"offline" = t_k - t_a$. During this exact temporal window, newer posts continue to arrive at rate $mu_v$. 

To find the exact probability of the post being seen, we must consider the processing time of every single newer post. Let $D_"action"^((m))$ be the random variable representing the time taken by user $v$ to process the $m$-th newer post. For post $i$ to be successfully seen, the cumulative time required to evaluate the $N_"newer"$ posts positioned above it must be strictly less than the user's active session duration $Delta_k$. The exact survival probability is therefore:

$ PP ("seen") = PP  ( sum_(m=1)^(N_"newer") D_"action"^((m)) < Delta_k ) $

Evaluating this strict probability analytically requires convolving the distributions of the arrival process ($N_"newer"$), the individual reading times ($D_"action"^((m))$), and the session durations ($Delta_k$). Because this is a very complex system, finding a closed-form solution is computationally intractable. This intractability fundamentally justifies the reliance on the Discrete Event Simulation (DES) (see @sec-method-des) to natively resolve these reverse-chronological interactions.

However, to establish an intuitive macroscopic understanding of the system's core mechanism, we can apply a first-order mean-value approximation. The expected number of newer posts positioned above post $i$ when the user finally logs in can be approximated by:

$ EE[N_"newer"] approx mu_v dot Delta_"idle" = mu_v dot (t_k - t_a) $

Let $EE[D_"action"]$ denote the expected inter-action delay (the average time user $v$ spends processing a single post). Applying Wald's Equation, the expected continuous time required to scroll past the newer backlog is:

$ EE[Delta_"scroll"] approx EE[N_"newer"] dot EE[D_"action"] = mu_v dot (t_k - t_a) dot EE[D_"action"] $

In this deterministic mean-value framework, the condition for a post to likely survive is that the expected scrolling time must be bounded by the user's active session duration:

$ EE[Delta_"scroll"] < Delta_k $

Together, the theoretical probability and its mean-value approximation define the core mechanism of the simulation: the likelihood of a post surviving the queue is *inversely proportional* to both the timeline influx rate $mu_v$ and the elapsed idle time.


