#import "utils.typ": *

This section narrows the description of the Bluesky social network (see @sec-sota-description) into the most important mechanics to study the objective.

To model all the features in a complete social network is a challenge out of the scope of this project. To achieve the objectives of the project within its time constraints and scope, a significant subset of the Bluesky platform will be modeled according to the research tools and approaches to be followed. It is believed that the selected subset of features will behave as a microblogging social network.

*1. Just the Following Feed*

The following feed is a timeline with a reverse-chronological post showing criteria, and from now on this will be referred to as the _timeline_ of every user. As simulating a recommender is a difficult challenge in itself, it is believed that the flow of information can be meaningfully studied with a more traditional content strategy, even if the use of these feeds is not the norm on social networks. 

*2. Static Users and Followers*

During the course of the simulation, no new users will be added, nor new relationships between them. The inter-user relationships are considered static during the whole duration of the simulation, as the flow of content can be studied without this behavior.

*3. No Mutes nor Blocks*

We assume that if user $u$ follows user $v$, user $u$ will receive all posts from user $v$.


*4. No Quotes, no Replies*

With the same criteria, we want to focus on the content of the text, so the way the information transmits itself can be reduced to a single post.

*5. No Profile of a User*

A user won't be able to enter to see other users' profiles; they will be limited to observing their posts on the timeline.

Let's define which features of Bluesky are going to be modeled in the simulation:
1. Users can act over a post by liking or reposting it.
2. Users see posts in a timeline: posts will be seen in reverse-chronological order from the accounts they follow.


To model these dynamics, this section introduces a unified mathematical notation that models the microblogging platform as a Time-Varying Heterogeneous Graph #todo[i've lost the ref of the friking original paper xd] and the reasons for that are given in the section @sec-method-graph. This formulation rests on the acknowledgment that there are two distinct entities, users and posts, as well as different types of edges to characterize the relationships between entities of the same type and different types. The relationships between the entities are, by their very nature, changing over time.

#def(name: "Time-Varying Heterogeneous Graph")[Having established the temporal properties of our entities and their relationships, we formally define our system as a Time-Varying Graph $cal(G) = (V, E, T, rho, psi, eta)$. Here, $V$ and $E$ form the universal topological space, $psi$ and $rho$ govern the temporal existence of nodes and edges respectively, and $eta$ bounds the chronological flow of information across the network.]

The following text defines and maps all the functions and sets according to this given definition.

== Network Entities and Topology

The model consists of two entities: users $cal(U)$ and posts $cal(I)$ #footnote[the nomenclature $cal(I)$ stems from recommender theory, and stands for items]. 

Unlike traditional dynamic graphs where the set of vertices grows, we define the graph over the universe of all entities that will ever participate in the simulation. 

#def(name: "Universal Nodes")[The node set $V$ is the static union of all participating entities throughout the entire simulation lifecycle: $V = cal(U) union cal(I)$.]

To represent the temporal reality of posts being created, we introduce a node presence function $psi$. Given the continuous time domain $T = RR^+$, the presence function dictates whether a node exists at time $t$:

$ psi: V times T -> {0, 1} $

Due to our simulation assumptions, the user base remains stable, meaning $forall u in cal(U), forall t in T, psi(u, t) = 1$. In contrast, a post $i in cal(I)$ is intrinsically tied to its creation timestamp $t_c$. Thus, its presence is a step function:
$ psi(i, t) = cases(1 "if" t >= t_c, 0 "otherwise") $

We can now cleanly define the set of available items at any time $t$ simply as $cal(I)_t = { i in cal(I) | psi(i, t) = 1 }$.

#comment[l'existència de $rho$ elimina la necessitat de tenir un conjunt en funció del temps $cal(I)(t)$]

== Relational Dynamics and Edge Properties

Similar to the node set, we define a universal edge set $E$ containing every potential interaction between entities. There are two types of relationships: $cal(R)_(cal(U) cal(U)) = {"follow"}$ and $cal(R)_(cal(U) cal(I)) = { "create", "like", "repost", "ignore" }$.

#def(name: "Universal Edges")[We denote the set of all possible edges $E = E_(cal(U)cal(U)) union E_(cal(U)cal(I))$, where 
$ E_(cal(U)cal(I)) = { (u, i, r) | u in cal(U), i in cal(I), r in cal(R)_(cal(U) cal(I)) } $
$ E_(cal(U)cal(U)) = { (u, v, "follow") | u in cal(U), v in cal(U) } $]

To capture the specific temporal dynamics of these connections, we define two continuous-time functions over the edge set: the edge presence function $rho$ and the latency function $eta$.

#def(name: "Edge Presence")[The function $rho: E times T -> {0, 1}$ indicates if an interaction or connection is active at a given time. Its behavior depends on the edge type:
1. *Structural Edges* ($E_(cal(U)cal(U))$): A follow relationship initiated at $t_f$ persists, meaning $rho((u, v, "follow"), t) = 1$ for all $t >= t_f$.
2. *Event Edges* ($E_(cal(U)cal(I))$): Actions upon items are punctual events. If user $u$ performs action $r$ on item $i$ exactly at time $t_e$, then $rho((u, i, r), t_e) = 1$, and $0$ otherwise. Specifically, the $"create"$ relationship triggers the node presence of a post: $rho((u, i, "create"), t_c) = 1 arrow.r.double psi(i, t) = 1$ for all $t >= t_c$.]

== Time Delays

#comment[Comparat amb la formulació anterior, ara els delays ja no són una invenció, sinó part de la formulació directa, cosa molt més elegant.]

#def(name: "Edge Latency")[Information dissemination and user reactions are not instantaneous. We define a latency function $eta: E times T -> T$ that maps every edge to a specific temporal delay based on its interaction type:
- *Propagation Delay*: Associated with structural follow edges $e in E_(cal(U)cal(U))$, dictating the time required for a followee's action to surface on the observer's timeline.
- *Interaction Delay*: Associated with reactive event edges $e = (u, i, r)$ where $r in {"like", "repost", "ignore"}$, representing the cognitive processing time before a user reacts to a post.
- *Creation Delay*: Associated with generative event edges $e = (u, i, "create")$, representing the time taken to compose and publish a new item.]

== User Session Dynamics

Individual user engagement occurs in discrete, contiguous sessions. Rather than defining an external state function, these sessions act as an intrinsic structural constraint on the edge presence function $rho$.

#def(name: "User Sessions")[We define the periods a user $u$ is online as a subset of time $cal(O)(u) subset T$. The edge presence function for any reactive or generative event is strictly constrained by this subset. If a user is offline, no action edges can be generated:
$ t in.not cal(O)(u) arrow.r.double forall i in cal(I), forall r in cal(R)_(cal(U)cal(I)), rho((u, i, r), t) = 0 $

Consequently, the existence of any event edge inherently requires the user to be in an active session:
$ rho((u, i, r), t) = 1 arrow.r.double t in cal(O)(u) $]


Lastly, we can define the users that a specific user $u$ is following, and the users that follow them:

#def(name: "Following")[The subset of users that user $u in cal(U)$ is following, assuming connections are established at $t=0$, is denoted as 
$ cal(N)_"out" (u) = { v in cal(U) | rho((u, v, "follow"), 0) = 1 }. $] 

This dictates the sources of information populating user $u$'s timeline, and coincides with the concept of the out-neighborhood of a node in graph theory.

#todo[Exemple de followers i followee]

#def(name: "Followers")[The subset of users that follow user $u$, assuming connections are established at $t=0$, is denoted as 
$ cal(N)_"in" (u) = { v in cal(U) | rho((v, u, "follow"), 0) = 1 }. $]

These are the users affected by user $u$'s actions.

== User Activity and Timeline Construction

To construct a user's timeline, we extract the historical footprint of the network using the edge presence function $rho$, while accounting for the delays defined by $eta$.

#def(name: "User Activity")[The active footprint of a user $cal(A)_t(u)$ includes all items the user has actively propagated prior to time $t$. 
$ cal(A)_t(u) = { i in cal(I) | exists e = (u, i, r) in E "where" rho(e, tau) = 1 "for some" tau < t "and" r in {"repost", "create"} } $]

#def(name: "Timeline")[The timeline $cal(T)_t (u)$ is the aggregated activity of the user's out-neighborhood $cal(N)_"out" (u)$, strictly excluding items the user organically authored themselves, $cal(P)_t(u)$. The time at which an item from followee $v$ appears in $u$'s timeline is offset by the propagation delay $eta((u, v, "follow"), t)$:
$ cal(T)_t (u) = ( union.big_(v in cal(N)_"out" (u)) cal(A)_(t - eta((u, v, "follow"), t))(v) ) - cal(P)_t (u) $]


== User Decisions and Policy

The interactions within the network are driven by the decision-making processes of the users. We model user behavior through a policy $pi$, which governs the probability of executing specific actions. Because consuming existing content and generating new content are fundamentally different mechanisms, the policy is bifurcated into two distinct components: a reactive policy and a spontaneous generative policy.

1. *Reactive Policy (User-to-Post):* When an online user is presented with a post $i$ in their timeline $cal(T)_t (u)$, they must decide how to interact with it. We define the reactive policy $pi_"act"$ as a probability distribution over the subset of timeline-permissible actions, $cal(R)'_(cal(U)cal(I)) = {"ignore", "like", "repost"}$. 

$ sum_(a in cal(R)'_(cal(U)cal(I))) pi (a) = 1 $

2. *Spontaneous Policy (Creation):* The act of creating a new post does not depend on the contents of the timeline; it is a spontaneous event generated by the user. We define the generative policy $lambda$ as the probability (or rate) at which an online user decides to execute the $"create"$ action during a given time step or session, introducing a completely new item into $cal(I)_t$.

#comment[Aquesta formulació sembla com més elegant!]
