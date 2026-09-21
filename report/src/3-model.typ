#import "utils.typ": def, flex-caption, todo, comment
#import "@preview/cetz:0.4.2"

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
- *Interaction Delay*: Associated with reactive event edges $e = (u, i, r)$ where $r in {"like", "repost", "view"}$, representing the cognitive processing time before a user reacts to a post.
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
$ cal(A)_t (u) = { i in cal(I) | exists e = (u, i, r) in E \ "where" rho(e, tau) = 1 "for some" tau < t "and" r in {"repost", "create"} } $ <def-activity>
]

#def(name: "Timeline")[The timeline $cal(T)_t (u)$ is the aggregated activity of the user's out-neighborhood $cal(N)_"out" (u)$, strictly excluding items the user organically authored themselves, $cal(P)_t(u)$. The time at which an item from followee $v$ appears in $u$'s timeline is offset by the propagation delay $eta((u, v, "follow"), t)$:
$ cal(T)_t (u) = ( union.big_(v in cal(N)_"out" (u)) cal(A)_(t - eta((u, v, "follow"), t))(v) ) - cal(P)_t (u) $]

The subindex $t$ in the timeline makes posts available to be inserted (or extracted) according to the value of time $t$. The resulting event $e_1 = cal(T)_(t_1) (u) != cal(T)_(t_2) (u) = e_2$ where $t_1 <= t_2$.

Lastly, we have to define a set that contains all the interacted posts by a given user $u$. This is needed to comply with the CTIC model, as a user cannot propagate if it has already been infected. We will call the set interaction history.

#def(name: "User Interaction History")[The Interaction History set of a user $cal(H)_t (u)$ includes all the items the user has either propagated or liked prior to time $t$

$ cal(H)_t (u) = { i in cal(I) | exists e = (u, i, r) in E "where" \\ rho(e, tau) = 1 "for some" tau < t "and" r in {"repost", "like"} } $ 
]

=== User Decisions and Policy
<sec-model-def-policy>

The interactions within the network are driven by the decision-making processes of the users. We model user behavior through a policy $pi$, which governs the probability of executing specific actions. Because consuming existing content and generating new content are fundamentally different mechanisms, the policy is bifurcated into two distinct components: a reactive policy and a spontaneous generative policy.

1. *Reactive Policy (User-to-Post):* When an online user is presented with a post $i$ in their timeline $cal(T)_t (u)$, they must decide how to interact with it. We define the reactive policy $pi_"act"$ as a probability distribution over the subset of timeline-permissible actions, $cal(R)'_(cal(U)cal(I)) = {"ignore", "like", "repost"}$. 

$ sum_(a in cal(R)'_(cal(U)cal(I))) pi (a) = 1 $

2. *Spontaneous Policy (Creation):* The act of creating a new post does not depend on the contents of the timeline; it is a spontaneous event generated by the user. We define the generative policy $lambda$ as the probability (or rate) at which an online user decides to execute the $"create"$ action during a given time step or session, introducing a completely new item into $cal(I)_t$.

== Model
<sec-model-ctic>

This section details the model chosen to evaluate the information diffusion. To accurately capture the real-world dynamics of the phenomena, we integrate the Continuous-Time Independent Cascade (CTIC) model (see @sec-sota-diffusion-ctic) with a queue-based timeline (see @sec-model-def-policy) and activity-driven users (see @sec-method-activity).

=== CTIC for Multiple Concurrent Cascades
<sec-model-incubation>

The model of this work is built on the Continuous-Time Independent Cascade (CTIC) model (see @sec-sota-diffusion-ctic) for two of its main properties we need to take advantage of. First, *diffusion is asynchronous*: users adopt content at exact timestamps rather than in synchronized epochs, so a discrete time step is an artifact of the model rather than a feature of the phenomenon. Second, an adoption is separated from the next one by an *incubation time*: if $j$ reposts a post at $t_j$, a follower $i$ can only repost it at some $t_i > t_j$, and it is the distribution of that delay that the CTIC model parameterizes per directed edge.

In the original formulation @gomezrodriguez2011uncovering, every ordered pair $(j, i)$ carries its own transmission rate $alpha_(j,i)$, estimated from observed cascades or fixed a priori, and realized through a survival function: the delay of the edge is a random variable sampled for that pair, independently of the others. This work decomposes that delay into the transmission time itself and the platform-side delivery of the post, so the incubation time of an edge is

$ t_i - t_j = T_(j,i) + Delta_p, $ <eq-incubation>

where $T_(j,i)$ is the CTIC transmission time and $Delta_p$ is the propagation delay (see @sec-design-sources-propagate) associated with pyhsical information transmission.

With a single cascade, a CTIC model choses to give $T_(j,i)$ an specific distribution and observes how the cascade changes according to the chosen distribution, as said in @sec-sota-diffusion-ctic. This work though, needs to simulate several cascades simultaneously over the same network  topology, and therefore $T_(j,i)$ cannot be sampled: the many cascades travel at once and share the same user timelines, so the time a post waits before it _might_ be inspected depends on the volume of posts that are already in the timeline that every other cascade has pushed above it, as well as on the receiver's sessions. This is exactly what the ensemble of cascades is considered complex system (@def-complexsystem in @sec-sota-background), as the propagation of a cascade will affect how others propagate by being bounded by the users attention span: the parts (individual cascades) and the whole (the attention they share) are not separable, so no set of independent per-edge rates $alpha_(j,i)$ describes it. Therefore, the ensemble of CTIC models is not itself an independent cascade model, and the rate of an edge is not constant in time but a function ---an extremey hard to analytically describe--- of the state of the system.

As sampling $T_(j,i)$ is impossible, the model opts to generate it with the reverse-chronological timeline. The post is delivered to $i$'s timeline after $Delta_p$ and then waits there until $i$ inspects it, so the incubation time is the delivery plus that wait. The survival mechanism of the CTIC model is thus preserved but realized as a queue instead of fitted, and the wait itself has structure.

The delivery delay $Delta_p$ is uniform across edges and constant in the reported run (@tbl-res-config). Uniformity keeps the platform-side component deterministic, which is what prevents a post from teleporting from one user to the next (see @sec-design-sources-propagate) and preserves the global creation order of the timeline: the reverse-chronological feed operates as a LIFO queue @hodas2014simple, and a per-edge delivery delay would let an older post arrive after a newer one. With uniform $Delta_p$, if post $p_1$ is created before $p_2$, then $p_1$ appears in every follower's timeline before $p_2$.

In short, the model preserves the decision rule of the independent cascade ---one-shot adoption, exposure distinct from adoption, decisions drawn from the user's policy--- and not the independent per-edge transmission times: the cascades are independent in how a user decides and coupled in when, or whether, a user is exposed. It is this coupling, absent from the original model, that turns the cascades into a single continuous-time process that must be advanced as a whole instead of sampled or solved edge by edge. That process only changes state at discrete event times ---a repost, a propagation, a session boundary--- so discrete-event simulation is its natural execution paradigm (the choice is justified in @sec-method-des and the implementation in @sec-design and @apx-impl). The wait that the model generates is a consequence of the users' activity dynamics, introduced next and quantified in @sec-model-rate.

=== Activity-Driven Network Dynamics
<sec-method-activity>

When modeling an OSN with users as the primary entities, there is a particular aspect that is highly intuitive for human behavior but heterodox in traditional graph theory: nodes are not available for information transmission at all times; rather, their availability is a function of time $t$. 

Standard static network models assume that nodes and edges are perpetually available for information transmission. However, empirical studies of social and technological systems reveal that human interactions are fundamentally bursty and temporally disconnected @barabási2005bursts. To capture this reality, the Activity-Driven modeling framework describes a time-varying network where the topological evolution is strictly governed by the intrinsic behavioral patterns of individual nodes @pozzana2017epidemic.

In this paradigm, each user is characterized by an "activity" rate, defined as their propensity to engage with the network and form connections at a given time. Consequently, nodes alternate between discrete online sessions and offline "vacation" periods. As explained when modeling the problem (see @sec-model-ctic), this bursty interactions have already been modeled as $cal(O) (u)$, and despite no restrictions being imposed on it's nature, we can characterize it as

$ cal(O) (u) = union.big_(k=1)^oo [t_k, t_k + Delta_k) "where" t_k in T $

and $Delta_k$ is a positive random variable representing the sessions duration. 

- The interval $I_k = [t_k, t_k + Delta_k)$ constitutes the online duration (sampled from `session_duration`).
- The gap between sessions, mathematically expressed as $d = t_(k+1) - (t_k + Delta_k)$, constitutes the offline vacation period (sampled from `user_inter_session`).

In OSNs, these activity states are usually called sessions: a user starts a session when they log in to the platform to consume content, and it ends when they close the application or log off.

While the Activity-Driven framework dictates when users are present in the network via $cal(O)(u)$, it does not fully explain how they consume information. Social contagion is heavily moderated by the cognitive limits of human processing and the user interface of the platform itself @hirakura2023method @hodas2014simple. 

=== The Effective Transmission Rate
<sec-model-rate>

Even though $T_(j,i)$ cannot be sampled, its structure can still be analyzed, revealing the role it plays in the model and how it couples with the activity-driven and queue-based parts of it. Once a post is in a receiver's timeline $cal(T)_t (v)$, the wait it experiences has two components, both consequences of the activity dynamics of @sec-method-activity:

- *Idle time* $Delta_"idle"$: the time until the post becomes readable ---the receiver's next session start, or the next refresh when the current feed empties.
- *Scrolling time* $Delta_"scroll"$: the time the receiver needs to process the posts positioned above it once the feed is being consumed.

Their sum is the queue-generated transmission time that the CTIC model leaves implicit in @eq-incubation,

$ T_(j,i) = Delta_"idle" + Delta_"scroll", $

so the full incubation time of an edge that ends in a repost is the delivery plus this wait, $t_i - t_j = Delta_p + Delta_"idle" + Delta_"scroll"$. The rest of this section derives the expected value of that wait.

#def(name: "Influx Rate")[The influx rate $mu_v$ is the expected number of posts arriving per unit of time in user $v$'s timeline. As a macroscopic quantity, it aggregates the out-degree of $v$ and the creation and repost activity of its followees, for which no closed form is attempted.]

During the idle window the backlog above the post grows at rate $mu_v$, so the expected number of newer posts obstructing it is

$ EE[N_"newer"] approx mu_v dot Delta_"idle" $

Each of those posts costs an expected $EE[D_"action"]$ to process ---the calibrated inter-action time--- so the expected scrolling time required to reach the post is

$ EE[Delta_"scroll"] approx EE[N_"newer"] dot EE[D_"action"] = mu_v dot Delta_"idle" dot EE[D_"action"] $


Of course, this section just moved the complexity being unable to sample $T_(j,i)$ into a conveniently defined $mu_v$, which is not possible to sample either. The value of this is to narrow down which factors of $T_(j,i)$ were the system-induced parts, rather than keeping it as a misterious magnitude. 

Transmission requires both that the post is reached within its session and that the receiver's policy selects a repost at that inspection (see @sec-model-def-policy). Because whatever remains unread in the active feed when the session ends is discarded, a post that is not reached within the session budget, $EE[Delta_"scroll"] < Delta_k$, has an infinite incubation time ($alpha_(j,i) = inf$). The effective transmission rate is therefore *a decreasing function of the receiver's influx and idle time*: this is the precise sense in which $alpha_(j,i)$ is an output of the system rather than a parameter, and why an empirical fit of it would be of little use to this project ---the simulation must produce it, not consume it. Obtaining the rate exactly would require convolving the arrival process, the action times and the session schedule, which has no closed form.


=== Final Model

In conclusion, the model implemented is a complex system consisting of an ensamble of multiples Time-Continuous Independent Cascades. Denoting as super index the i-th cascade, for any cascade $c$ the propagation of time just needs to satisfy $t^c_v < t^c_u$ for any pair of users $u, v$.

The time for a piece of content to travel from $u$ to $v$ is called expousure time $alpha_u,v$. On the contrary with a single Continuous-Time Independent Cascade (just one cascade) where $alpha$ is a parameter to observe with the cascade, in the ensamble model is a magnitude affected by the $cal(T)_t (u)$ timeline per user. This project models the timeline as a reverse-chronological timeline ---in techincal terms, a LIFO queue--- which determines the $alpha_(u,v)$ where $u$ is the user acting on a repost and $v in cal(N)_"in" (u)$, as if there are a lot of posts queued in that user cascades, the probability that new post $i$ entering the queue at instant $t_c$ is going to be smaller than a user which the post $j$ is the only post in the queue. This means that the $alpha_(j,i)$ from the CTIC model are now a function $alpha(u, v, t)$ that depens on the edge $(u,v)$ and the time $t$, which makes it depend of course on the system state $cal(T)_t (u)$.

The description of the function $alpha$ depends on the state of the users, as when a user is offline, the lesser will be the chances of a specific post $i$ to be seen, as other will arrive an get on top of it due to the stack behaviour of the user timeline. The best way to characterize it is that $alpha_(u,v,t)$ is a decreasing function of $v$ influx (how buisy is the network) and their offline times.

Therefore, and to summarize in one sentence, this model is an Ensemble of Continuous-Time Cascades determined by a LIFO-based transmission time with an activity-driven delay factor. 
