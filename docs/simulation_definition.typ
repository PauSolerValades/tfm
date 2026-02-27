
#import "@preview/lovelace:0.3.0": *

#set text(font: "Liberation Sans")

#set par(justify: true)

#set heading(numbering: "1.")

#set page(numbering: "1")

= Introduction

This document defines the simulations an their necessary mathematical background.

= Context and Problem Definition 

In this section we define all the features of the network

The main objective of the simulation is to analyze how do posts behave: how far they travel, how many distinct users interact with that post within the timeline and no custom recommender in action. 

For that, we need to implement *Posts* and the relations with themselves, which are (1) a post can be a reply of another post (2) a post can be reposted (3) a post can quote another post. Actions (1) and (2) needs of (4) a post can be created by a user.

Posts are shown to *users* according to the post creation time in a *timeline* and which set of users is the user *following* at a given time. The order of the post is *reverse-chronological*, so the user will see the posts from newest to oldest.

A user can interact with a post in several ways, so we must define *actions* that a user can perform over a post. In the bluesky case those are to like, reply, repost and quote another post. Replying, reposting and quoting will influence the followers of the user's timeline as well as timelines of all other users.


== Problem Modeling
<sec-modeling>

[Why this is a Graph temporal data evolution and why is it modeled this way @andriamampianina-2022-graph (section 3)]

[Why a social network behaves like a time-Heterogeneous Graph @andriamampianina-2025-selective (introduction)]

This section defines a unified notation to model the problem as a Time-Evolving Heterogeneous Graph.
- Graph: can be modeled with nodes and edges.
- Heterogeneous: entities and relationships between them have different types.
- Time-Evolving: the topology of the graph changes with time (a user can repost a post)


Let's define the entities at play $E = cal(U) union cal(I)$, where $cal(U)$ is the set of Users and $cal(I)$ is the set of Posts (Items). 
- The simulation contains $N in NN$ users, so $|cal(U)| = N$.
- The simulation contains $M in NN$ posts, so $|cal(I)| = M$.

=== Relationships Between Entities

Every event that happens during the simulation is an edge of the graph, that is, there are different types of edges, according to the performed action, which in turn changes according the entities involved.


*Definition*: An edge is a tuple $e = (v_"src", v_"dst", a, t) in cal(E)$ representing an interaction originating from a source node $v_"source"$, targeting a destination node $v_"destination"$, of a specific type, at time $t$.

We categorize the edge types ($cal(R)$) into three distinct relationship sets:

*User-to-User Actions* ($cal(R)_(cal(U) cal(U))$): This actions must be performed by a user over other user. We'll call this actions $ cal(R)_(cal(U) cal(U)) = { "follow", "mute", "block", "unfollow" } $

All edges added by actions in $cal(R)$ are just one edge, as this one: $(u_1, u_2, a_(u,u), t) "where" a_(u,u) in cal(R)_(cal(U), cal(U))$.

* User-to-Post Edges* ($cal(R)_(cal(U) cal(I))$): This actions are must be performed by a user over a post. Actions include $ cal(R)_(cal(U) cal(I)) = { "create", "like", "repost", "reply", "quote", "ignore" } $

All edges added by actions in $cal(R)$ are just one edge, as this one: $(u, i, a_(u,i), t) "where" a_(u,i) in cal(R)_(cal(U), cal(I))$.

*Post-to-Post Edges* ($cal(R)_(cal(I) cal(I))$): This actions must be performed by a user over a post $i$ but on the contrary as the user to posts actions, this involve the creation of the other two relationships. The actions are 

$ cal(R)_(cal(I) cal(I)) = { "replies", "quotes" } $

- Replies: If the action performed by $u in cal(U)$ over $i in cal(I)$ is a reply, the following edges must be added to the graph, at the same time $t$: ${(u, i_r, "create", t), (i_r, i, "replies", t)}$.
- Quote: If the action performed by $u in cal(U)$ over $i in cal(I)$ is a quote, the following edges must be added to the graph: ${(u, i_r, "create", t), (i_r, i, "quotes", t)}$

=== Graph Neighborhoods

It's is trivial now that, if we recall the definition of $E = cal(U) union cal(I)$ and we define $V = V_(cal(U) cal(U)) union V_(cal(U) cal(I)) union V_(cal(I) cal(I))$, where each subset is defined as:

$ V_(cal(U) cal(U)) = { (v_"src", v_"dst", r, t) | v_"src" in cal(U), v_"dst" in cal(U), r in cal(R)_(cal(U) cal(U)), t in T } $

$ V_(cal(U) cal(I)) = { (v_"src", v_"dst", r, t) | v_"src" in cal(U), v_"dst" in cal(I), r in cal(R)_(cal(U) cal(I)), t in T } $

$ V_(cal(I) cal(I)) = { (v_"src", v_"dst", r, t) | v_"src" in cal(I), v_"dst" in cal(I), r in cal(R)_(cal(I) cal(I)), t in T } $

then $G = (E, V)$ is a time-heterogeneous graph.

*Definition*: We define the neighborhood of a user to represent their social connections at a given time $t$:
- $cal(N)_"out" (u, t)$: The set of users that $u$ follows at time $t$ (Out-edges).
- $cal(N)_"in" (u, t)$: The set of users following $u$ at time $t$ (In-edges).

We can abbreviate both as $cal(N)_o^t (u)$ or $cal(N)_i^t (u)$.

=== User Activity and Timeline

*Definition*: The activity of a user $u$ up to time $t$ is the set of posts they have actively spread by doing an action which spreads the post, which are "reply", "quote" and "repost".

$ cal(A)(u, t) = { i in cal(I) | exists e = (u, i, a, tau) in cal(E) "where" tau < t "and" a in {"repost", "replies", "quotes"} } $

*Definition*: The non restricted timeline $cal(T)_n (u, t)$ for a given user $u$ at time $t in T$ is the chronologically sorted set of posts generated or interacted with by their followed network.

$ cal(T)_"raw" (u, t) = union.big_(v in cal(N)_o (u, t)) (cal(A)(v, t) union cal(P)(v, t)) $

Where $cal(P)(v, t)$ is the set of original posts created by user $v$ up to time $t$.

To generate an accurate timeline two additional conditions are needed to prevent infinite actions loop. E.g, consider this graph $G = ({u_1, u_2} union {(u_1, u_2, "follow", 0), (u_2, u_1, "follow", 0), (u_1, A, "create", 0)}).$ Now, at $t=1$,  $(u_2, A, "repost", t)$. As $u_1$ also follows $u_2$, means that $cal(T)(u_1, 1) = {A}$, which should not happen: a timeline of a user must not contain it's users own posts. 

[Write an example of three users]

To prevent infinite action loops, the timeline $cal(T)(u, t)$ must filter out posts the user has already authored or interacted with. 

*Definition*: The strictly evaluated timeline $cal(T)(u, t)$ is the set difference between the raw timeline and the user's own historical footprint:
$ cal(T)(u, t) = cal(T)_"raw"(u, t) - (cal(A)(u, t) union cal(P)(u, t)) $

Essentially this imposes a no-self-loop (a user cannot interact with posts that he owns) and a single interaction rule (a user can interact with an item once). Additionally, we need two additional variables to not make the appendance inmediate:
1. Propagation delay $tau_p$ is the time from a post from a user to be interacted with and the $t$ it should appear on it's timeline.
2. Interaction delay $tau_i$ is the time between a user making an impression (the post being shown to them) and actually performing the action.

To make it clear, let's add an example.
1. At $t$ post $i$ is "reposted". This adds the following edge to the graph $(u, i, "repost", t)$.
2. Now user $v$ sees the repost and likes it, which adds this other edge $(v, i, "like", t)$.

It should not be possible for two actions to happen at the same time: we must assume a delay of the information moving; those are $tau_p$ and $tau_i$. 
1. At $t_1$ post $i$ is "reposted". This adds the edge $(u,i,"repost", t_1)$ to the graph BUT will appear at the user timeline at $t_2 = t_1 + tau_i$ to not make information be instant.
2. Now user $v$ sees the repost and likes it, which adds this other edge at time $t_3 = t_2 + tau_i$: $(v, i, "like", t_3)$.

To process the timeline chronologically, we define the standard retrieval functions for a time-sorted set $S$:
- $"newest"(S)$: returns the item $i in S$ associated with the largest timestamp.
- $"oldest"(S)$: returns the item $i in S$ associated with the smallest timestamp.
- $S(t)$: returns all elements in the set with a timestamp smaller than $t$.


=== Tracking structures 

Lastly, we define three ways of evaluating and keeping track of 

- *Impression History*: $cal(H)^"imp"_u(t) = (i_1, i_2, ..., i_k)$. The reverse-chronological sequence of posts user $u$ has actually viewed from $cal(T)(u, t)$.
- *User Historic Activity*: $cal(H)^"act"_u(t) = { e in V | v_"src" = u "and" tau < t }$. A complete log of a user's generated edges.
- *Item Trajectory*: $cal(H)^"traj"_i(t) = { e in V | v_"dst" = i "and" "type" in {"repost", "reply_to", "quote"} "and" tau < t }$. The list of all spreading actions applied to post $i$, which tracks the cascade.
- *Simulation Trace*: $cal(H)^"trace" = "sorted"(V, "horizon") $: All that the simulation must output to review the full picture is just  the sorted edged at the end of the simulation.

#pagebreak()
= Version 1: Bare-bones 

We are going to define the bare-bones simulation. The objective of this is to build an engine which does not take into account _real data_ but only all the concepts that are going to interact and test if the theoretical idea makes sense.

== Scope

This first version of the engine simulation should be used to verify and stablish a solid implementation basis which are verifiable - that is to be as certain as possible of bug's absence. The document _specification_bluesky_ specifies what features compose the features Bluesky social network has, which we'll describe (hollisticaly) a subset in the following paragraph.


== Axioms/Assumptions
<sec:axioms>

This lists what the simulations assumes (several simplifications) in order to simplify the implementations. This are not immutable, some of them will be torn down in more advanced versions of the simulation.

1. User Homogeneity: Every user $u in cal(U)$ is indistinguishable in behavior and shares the exact same decision policy $pi$.
  
$ forall u_i, u_j in cal(U) : pi_(u_i) = pi_(u_j) = pi $

2. Action Independence: A user's choice to interact with a post $i$ at time $t$ depends strictly on their static policy $pi$, independent of their historical impression history $cal(H)_u^"act"$. 

$ PP (e = (u, i, a, t) | cal(H)^"act"_u(t)) = pi(a) $

3. Structural Stability: The underlying graph topology and population are static throughout the simulation.
   - Static Population: No new users or posts are created after initialization ($t=0$).
   - Pre-scheduled new Items: New posts will be apended to the simulation, but not in a random way, that is: timelines will be predefined beforehand.
   - Static User Relationship: The follower graph $cal(N)_"out"$ and $cal(N)_"in"$ remains constant; no follow/unfollow actions occur.

4. Relationship Subset: The only User-to-Post actions that can occur are $cal(R)^' _(cal(U) cal(U)) = {"ignore", "like", "repost"} subset cal(R)_(cal(U), cal(U))$

5. Algorithm: shows followers posts with a chronological (oldest to newest) order.

Despite being enforced by the definition of $cal(T) (u,t)$, let's add this two other axioms:

6. No-self-loop: A user cannot have its own posts on its timeline ($cal(P) (u, t) inter cal(T) (u, t) = emptyset$)

7. Single-Action Loop: A user can interact with an item once.

== Algorithm Evaluation via Markov Properties
#text(blue)[
Under the axioms defined in @sec:axioms, we can characterize the underlying model as a Continuous-Time Markov Chain (CTMC) where interarrival times of actions follow an exponential distribution. *Move to implementation*]. However, to formally prove the correctness of the Simulation Engine's state transitions and simplify analytical verification, we evaluate its Embedded Discrete-Time Markov Chain (DTMC), commonly known as the jump chain. [This is the pdf `embbedded_markov.pdf`, ask for a better source.]

For this to be a Markov chain, we must ensure the memoryless property is fulfilled, where considering an states $s_0, ..., s_t$ can be expressed as follows:

$ PP (s_j | s_1,...,s_(j-1)) = PP (s_j | s_(j-1)) $


To ensure that, we need to discretize time strictly to the sequence of events, denoted by step $n in NN$. We define the global state of the simulation $S_n$ strictly as the time-evolving network graph at step $n$:

$ S_n = G(n) = (V, E_n) $

Where $V = cal(U) union cal(I)$ is the static set of all users and pre-scheduled items (Axiom 3), and $E_n$ is the cumulative set of all edges (interactions and creations) that have occurred up to step $n$.

Under this graph-state formulation, the system satisfies the memoryless Markov property:

$ PP (G(n) | G(n-1), ..., G(1)) = PP (G(n) | G(n-1)) $

The transition from graph $G(n-1)$ to $G(n)$ is determined entirely by the current edge configuration $E_(n-1)$. In this configuration, $E_(n-1)$ is used to deterministically compute the current user timelines (Axiom 5), and applies the static policy $pi$ (Axioms 1 and 2) to generate the next edge $e_n$. Because no historical state prior to $n-1$ is required to compute $n$-th state, the process is memoryless.

Let's invoke the remaining axioms to guarantee the model is a Markov Chain. Axiom 2 ensures that the decision policy $pi_u$ does not change with step $n$. While the contents of a user's timeline depend on the simulation's progress, the probability rules governing their actions remain constant, making the system time-homogeneous, as well as Axioms 3 and 4. Although posts are revealed sequentially during the simulation, the finite set of total posts and the static user graph are predefined, meaning the underlying structural rules do not shift. 

Furthermore, Axiom 5 ensures a deterministic, chronological ordering of timelines. This strictly defines the state transitions—the topology of the chain's state space. A more sophisticated, dynamic recommender algorithm might introduce hidden historical dependencies, which would (probably) violate the Markov property. Ultimately, satisfying the memoryless property allows us to formalize the entire simulation engine as a MC. Because it operates as an absorbing chain, we can statically analyze its expected final state to mathematically verify the implementation.

As a final note, the User Homogeneity axiom is not required for the system to be modeled as a Markov chain. It is, however, strictly necessary to simplify the transition probabilities enough to derive an analytical expression to test the code against.


== Transition Probabilities

To define the transition probability function that governs the step-by-step stochastic evolution from $G(n-1)$ to $G(n)$ to analytically express what we are going to approximate with the simulation.

In the embedded DTMC, a discrete step occurs when any user's continuous exponential timer triggers. Under the User Homogeneity assumption (Axiom 1), the mathematical probability of any specific user $u$ being the next to act is uniformly distributed across the active population. Thus, the probability of a specific user $u$ "waking up" to act at step $n$ is $1 / |cal(U)|$. 

When an active user $u$ acts, their specific action $a_n$ is drawn from the homogeneous probability policy $pi = (p_"ignore", p_"like", p_"repost", p_"create")$ do to the action limitation in axiom 5.

Let $G'$ represent a candidate for the next state. If the user's timeline $cal(T)(u, n-1)$ is not empty, let $i_u$ be the chronologically oldest unseen post in that timeline. For a "create" action, we bypass the timeline entirely; instead, the action activates an inert, pre-scheduled node $j_"new" in cal(I)$ to satisfy the topological requirement of adding new nodes versus linking existing ones). 

The conditional transition probability, assuming user $u$ is the active user at step $n$, is defined as:

$ PP(G' | G(n-1), "user" u "is active") = cases(
  p_"ignore" & "if" G' = G(n-1) union { (u, i_u, "ignore", n) },
  p_"like" & "if" G' = G(n-1) union { (u, i_u, "like", n) },
  p_"repost" & "if" G' = G(n-1) union { (u, i_u, "repost", n) },
  p_"create" & "if" G' = G(n-1) union { (u, j_"new", "create", n) },
  1 & "if" cal(T)(u, n-1) = emptyset "and" G' = G(n-1),
  0 & "otherwise"
) $


To obtain the global transition probability of moving from $G(n-1)$ to $G'$, we marginalize over all possible users in the network:

$ PP(G(n) = G' | G(n-1)) = sum_(u in cal(U)) frac(1, |cal(U)|) dot PP(G' | G(n-1), "user" u "is active") $

*Note*: Action "ignore" has chosen to be modeled due to the need to diferenciate between a user that has seen (and chosen to not interact with) the post and a user who has not seen this post at all. With this, both the graph and the historics are representing everything.

Additionally, the transition function explicitly handles the scenario where a user activates but their timeline is empty ($cal(T)(u, n-1) = emptyset$). In this case, the user cannot interact with a post. The step $n$ effectively advances the clock (or jump sequence), but the graph topology remains mathematically identical to the previous step ($G' = G(n-1)$).

=== The Absorbing State Transition
    
The simulation reaches its ultimate absorbing state, denoted as $G_"final"$, when the filtered timelines $cal(T)(u, n)$ for all users $u in cal(U)$ are completely empty, and all pre-scheduled posts in $cal(I)$ have been exhausted. At this point, no topological changes can occur.

By definition, an absorbing state only transitions to itself with absolute certainty:
$ PP(G(n) = G_"final" | G(n-1) = G_"final") = 1 $

=== Proof of State Equivalence (Global Graph vs. Local Histories)

It is intuitive to view the simulation not as a monolith, but from the perspective of individual entities (users and posts). It can be proved that defining the state as the global graph $G(n)$ is mathematically isomorphic to defining it as the union of all localized entity histories.

Let $E(v, n) subset.eq E_n$ be the localized edge set (history) for any single node $v in V$ up to step $n$, defined as all edges where $v$ is either the source or destination:

$ E(v, n) = { e in E_n | v_"src" = v "or" v_"dst" = v } $

By the definition of a graph, the global edge set $E_n$ is exactly equal to the union of all localized node edge sets:

$ E_n = union.big_(v in cal(V)) E(v, n) $

Since the vertex set $V$ is strictly partitioned into users $cal(U)$ and items $cal(I)$, we can decompose this union:

$ E_n = ( union.big_(u in cal(U)) E(u, n) ) union ( union.big_(i in cal(I)) E(i, n) )  =  ( union.big_(i in cal(I)) cal(H)^"act"_u(n) ) union ( union.big_(u in cal(U)) cal(H)^"traj"_i(n) ) $

Notice that for any user $u$, their localized edge set $E(u, n)$ perfectly encapsulates their historical actions $cal(H)^"act"_u(n)$ and impression interactions. Similarly, for any item $i$, $E(i, n)$ perfectly encapsulates its cascade trajectory $cal(H)^"traj"_i(n)$. 

Therefore, the global graph state $G(n)$ contains the exact same information as the union of all individual user histories and item trajectories. Constructing the next event from $G(n)$ is mathematically identical to querying the localized histories of the active entities.

== Implementation

We can simulate the networks with a Discrete Event Simulation with the Event Scheduling Algorithm. This coincides with the Embedded Discreet-Time Markov Chain formalized described in the previous section as an approximation of the CTMC that could be deduced from the data.

=== Data Generation and Structure

First, we'll use synthetic data generated in JSON format to run the simulation. This code can be found in [simulation/synthetic_data_generation/main.py], and generates the following structure:

```json
{
  "posts": [
    { "id": 0, "time": 6.56 },
    { "id": 1, "time": 12.86 }
  ],
  "users": [
    {
      "id": 0,
      "policy": [0.2, 0.2, 0.2, 0.2, 0.2],
      "following": [84, 65, 80],
      "followers": [1, 7, 9],
      "authored_post_ids": ["0_0", "0_1"]
    },
    {
      "id": 1,
      "policy": [0.1, 0.9, 0.0, 0.0, 0.0],
      "following": [0],
      "followers": [],
      "authored_post_ids": []
    }
  ]
}
```

Next step is to create the simulation graph from the synthetic data. That is
- Users: How many, which followers and following, and store them in an array. This is $U$ from the notation section.
- Posts: Every user will have authored posts, and store them in an array. This is $I$ from the notation section.
- Fill timelines: every user has to see the posts of users that already follow him.

A user in the simulation contains the following information:
- id: identifier of the user.
- following: other users which our user follows. They determine the timeline. This is $cal(N)_("out")(u)$ from our notation.
- followers: other users which follow this user. Those users will be affected when our user interacts with a post. This is the $cal(N)_("in")(u)$ from the simulation.
- timeline: all the post the user has to see in the future. Is $cal(T)_u (t)$ from the notation section.
- posts: which post did the user author.
- policy: Probability associated to each action ($pi$). Must add to one.

A user will be able to perform three actions over a post: like, repost or nothing.

=== Options and Configuration

For the simulation to run, the following config file needs to be provided as a valid JSON:

```json
{
  "user_policy": {
    "weighted": [0.33, 0.33, 0.34] // ignore, like, repost
  },
  "user_inter_action": {
    "exponential": 3 
  },
  "propagation_delay": {
    "constant" : 1,
  },
  "interaction:delay": { 
    "constant": 1,
  },
  "horizon": 10000,
  "seed": null 
}
```

- User policy is the vector $pi$.
- User inter action is a distribution which modelizes every once in a while a user interacts with the system
- Propagation delay is an small time added between a user reposting an action and this action arriving to it's timeline.
- Interaction delay is an small time added between a user seeing a post and actually making the action.
- Horizon: duration of the simulation.
- seed: to control randomness.

To run the simulation we'll use the *Event Scheduling Algorithm*. An event in our simulation is defined as
- time: which timestamp has this event happened.
- action: which action has the user did.
- user: all the information listed in the user category.
- id: number of the event happening in the simulation.

As the simulation wants to focus on posts, it will log out a trace in JSON format, which is a register of all events that happened in the simulation. Contains the same information of the event with the id of the post that has been interacted with.

Before detailing the algorithm, we define the following helper functions and structures:
- $Q$: A priority queue of events ordered by time $t$.
- $"pop"(S)$: Extracts and returns the first element from an ordered set or queue $S$. If $S$ is empty, it returns $emptyset$.
- $"push"(S, x)$: Inserts element $x$ into the set or queue $S$.
- $"gen"(u, t)$: Generates a random future event $e$ with action $a$ for user $u$ at a time $t + tau$ where $tau ~ X$ is a random variable. 
- An event $e$ is a tuple $(t, a, u, "id")$, where $t$ is the timestamp, $a in cal(A)$ is the action, $u$ is the user, and $"id"$ is the event identifier.
- Every user has a distinct timeline $cal(T)_u$, which is a priority queue defined at the first point and its already filled with data from the data loading step.
- Recall from our notation that $r in cal(A)$ denotes a repost action.

#pseudocode-list[
  + $t_c <- 0.0$
  + $Q <- emptyset$
  + *for* $u in U$
    + $"push"(Q, "gen"(u, t_c))$
  + *end*
  + *while* $t_c <= "horizon"$ *and* $Q != emptyset$
    + $e <- "pop"(Q)$
    + $t_c <- e.t$
    + $u <- e.u$
    + $"push"(Q, "gen"(u, t_c))$ 
    + $i <- "pop"(cal(T)_u)$
    + *if* $i != emptyset$ *then*
      + $cal(H)_u <- cal(H)_u union (i)$
      + *if* tracing is enabled *then*
        + $"Log"(t_c, e.a, e."id", u, i)$
      + *end*
      + *if* $e.a == r$ *then*
        + *for* $v in Gamma_"in"(u)$
          + $"push"(cal(T)_v, i)$
        + *end*
      + *end*
    + *end*
  + *end*
]

== Implementation details

There must be a list with all the scheduled events (min heap), and then each user has a min-heap (?) with a index (or a pointer) to the post the user has to see (the oldest one). 

Each user must have both which posts has he written, which posts has he interacted and what action did the user performed (well, that's the trace)

Regarding the time between actions of the user, we will assume a exponential distribution, such as an inter arrival time.

Due to axiom 1, user will have all the same weights $pi$, but which action is performed is a weighted probability (uniform from zero to one and in which interval falls)

Potential optimizations:
- Use a time wheel instead of a heap for the heap event.
- Investigate if it makes sense in the timeline of the user.
- Change all ids to u32 instead of u64 and change the array of pointers to an array of users.
- Compact the graph: remove all the following and followers from each user, and store them as chunks in a big array.
- Investigate if `MuliArrayList` in User could be useful.
- Shrink as many structs as possible (if there is not need to delete anything from the heap delete the heap_index from TimelineEvent)

== Correctness & Limitations

The Axioms massively simplify what is a social network in order to provide a verifiable implementation. I want to address two facts which may steer away the simplification too far from being an actual representation.

1. Chronologically sorted or reverse-sorted: most of social network feeds are not given from oldest to newest, but from newest to oldest. Assuming a not reverse chronological order helps not to ask unconfortable questions regarding new timeline added posts (when a newer post should appear in the timeline if you are showing it from newest to oldest) which would clutter a rather simple testing implementation. Additionally, non-reverse order for sure mantains a Markov structure, which I am not sure with reverse chronological order.
2. Timeline definition: the definition of a timeline uses a _union_ $union$, which implies _non repeated items_ appears in the timeline. A normal implementation would just repeat the items (using a union of lists, not sets) which is not also how a social network feed behaves. There should be a system in place that refloats newer posts if they get popular again with some criteria. This will almost certainily break the Markov assumption for sure unless treated with care.


Current known limitations then are:
1. Reverse chronological order instead of non-reversed.
2. Timeline showing similar users popular posts a correct good enough times.
3. Post relation with each other: a reply should show original and replied, as well as a quote, as a single item (so both reply and quote should _create_ a post).

#pagebreak()
= Version 2: Sessions

The main objective of v2 is to implement a Reverse Chronological Order algorithm (instead of a Chronological Order) with the introduction of user sessions.

A user now can be in two states:
- online: will see its feed and interact according to a policy $pi_u$.
- offline: its not active in the simulation. 

A user will switch between those two states periodically according to a distribution or because it has received a notification and went back online to check an interaction.

A notification can bring a user back to active with a given distribution.

TODO: Introduce posts relationships and behaviours as bluesky does, described in [timeline_bluesky.typ] or move to v3

== Model

We'll expand the @sec-modeling notation. First we have to add when the user is inactive or active, and what this involves.

This does not need to be modeled actually, the topology of the graph does not change. It's only a restriction on when the user posts will appear.

Let's redefine the user set $cal(U) = {(1,s_1), ... (n, s_n)}$ where $(i, s)$, where $s in { "online", "offline" }$. Now, a user cannot do any action in $cal(R)$ if $s_i = "offline"$. Let's define what "online" and "offline" even mean.

#text(blue)[Analogous to the other definition we can do it function based. Let define a set $S$ with cardinal $N$ number of users. The function $"status": cal(U) --> S$ says in which status is user $u$ in.]

Regarding notifications, it's also an external entity which does not modify the network topology. When a user $v$ interacts with a post $i in cal(P)(u,t)$ of user $u$, this could lead them to go back offline to check the interaction of the user. Additionally, if a user is online and receives a notification, will skip the timeline and check the answer. This is analogous to say that if an edge $(i, j, r, t)$ where $i, j in cal(I), a in cal(R)_(cal(I) cal(I))$ occurs, state $s$ of the user $u$ such as $i in cal(P) (u,t)$ can be swapped.


== Axioms/Assumptions
<sec-axioms-v2>

This lists what the simulations assumes (several simplifications) in order to simplify the implementations. This are not immutable, some of them will be torn down in more advanced versions of the simulation.

1. User Homogeneity: Every user $u in cal(U)$ is indistinguishable in behavior and shares the exact same decision policy $pi$, as well as the same distribution for going and returning from Vacation.
  
$ forall u_i, u_j in cal(U) : pi_(u_i) = pi_(u_j) = pi $

2. Action Independence: A user's choice to interact with a post $i$ at time $t$ depends strictly on their static policy $pi$, independent of their historical impression history $cal(H)_u^"act"$. 

$ PP (e = (u, i, a, t) | cal(H)^"act"_u(t)) = pi(a) $

3. Vacation Independence: The sessions start and duration of every user are independent from all the other users.

4. Structural Stability: The underlying graph topology and population are static throughout the simulation.
   - Static Population: No new users or posts are created after initialization ($t=0$).
   - Pre-scheduled new Items: New posts will be apended to the simulation, but not in a random way, that is: timelines will be predefined beforehand.
   - Static User Relationship: The follower graph $cal(N)_"out"$ and $cal(N)_"in"$ remains constant; no follow/unfollow actions occur.

5. Relationship Subset: The only User-to-Post actions that can occur are $cal(R)^' _(cal(U) cal(U)) = {"ignore", "like", "repost", "quote"} subset cal(R)_(cal(U), cal(U))$

6. Notifications Mechanism: if $(u, j, "quote", t), (i,j, "quotes", t)$, user $v$ such as $i in cal(P) (u,t)$ can come back from vacation early.

7. Algorithm: shows followers posts with a reverse-chronological (oldest to newest) order within it's session.

Despite being enforced by the definition of $cal(T) (u,t)$, let's add this two other axioms:

8. No-self-loop: A user cannot have its own posts on its timeline ($cal(P) (u, t) inter cal(T) (u, t) = emptyset$)

9. Single-Action Loop: A user can interact with an item once.

== Implementation details

*Regarding User Heap*
Now the Heap associated to every user must output in reverse-chronological order, that is, return the element with the largest timestamp instead of the gloabal Heap, which has to do the opposite.

This makes us consider mainly when we have to "empty" the heap of a user, because if a user timeline keeps getting bigger but its not online a lot, could lead to unbound memory growth of `TimelineEvents` structs.

*Regarding Sessions*
Main problem of the sessions is to make sure an action $a_(u,i)^k$ is performed when the user is inactive. DoD: store another array called mask with 0 or 1 depeding of when the user is online or not and prevent generation of actions if that is set


*Regarding Notificaitons*

We need several parameters:
1. Chance of user breaking vacation.
2. Duration of notification induced session: could be different than the normal user session.


#pagebreak()
#bibliography("works.yml")


= Old Notation

I keep it here just in case i need it sometime in the future.
== Notation

This section will define a unified notation to modelize the problem.

Let's start by the two main entities of the simulation, users and posts.

*Definition*: Let's denote the set of users as $U$. A single user $u$ is an element of that set $u in U$. The simulation contains $N in NN$ users, that is $|U| = N$.

*Definition*: Let's denote the set of posts $I$ (I from items). A single post $i$ is an element of $I$. The simulations contains $M in NN$ posts, that is $|I| = M$

=== Relationships between Users and Posts

There are two meaningful relationships to be modelized between users and posts: a user performing an action over a post or user ownership of a post.


A user $u$ can perform a specific action $k$ over a post $i$. We define this set of possible actions as $cal(A)$.

*Definition*: An action $k$ is one of the elements of the following set $cal(A)$

$ cal(A) = { emptyset, "like/"l, "reply/"c, "repost/"r, "quote/"q, "create/"n} $


*Definition*: We define an action $a$ performed by user $u$ over item $i$ as the function connecting a user, an item and the action perfomed with a binary space as big as the cardinal of actions.

$ a: U times I times cal(A) --> {0, 1}^(|cal(A)|) $

*Example* If user $u$ likes post $i$: $a(u,i,l) = (0,1,0,0,0)$

A user is not limited to perform just one action, and this will yield a vector with multiple ones, e.g. $a(u,i,{l,c,r}) = (0,1,1,1,0)$.

For the sake of brevity, we will compress this notation as $a_(u,i)^k = a(u,i,k)$. If $k$ is know to be a subset and not just a single element, it can be denoted as $a_(u,i)^((k))$, which is equivalent to 

$ a_(u,i)^((k)) = (a_(u,i)^emptyset, a_(u,i)^l, a_(u,i)^c, a_(u,i)^r, a_(u,i)^q) in {0,1}^(|cal(A)|) $

Every post $i$ is owned by a certain user $u$, which is the author of the post. During the simulation, a user $u$ can create a new post $j in.not I$ at the beginning of the simulation. Regardless of addition of new posts during the simulation duration, $forall i in I$, we denote the creation function as $gamma: I --> (U, RR^+)$ which relates post $i$ being created by user $u$ at time $t$ ($gamma(i) = (u,t)$).

This might be denoted equivalently as $gamma_u (i) = t · bb(1)_{u "created" i} (i)$, so zero if the user did not create the post $i$.

*Definition*: we denote the set of posts created by user $u$ as $Gamma_("posts")(u) = Gamma_p (u) = {i in I | gamma_u (i) != 0 }$


=== Relationships between Users

A social network structures as a graph. Between users (nodes) they can follow each other (directed edges) and that determines which post each user see. 

*Definition* We define the set of user which follow a given user $u$ as $Gamma_"out" (u) = Gamma_o (u)$ (so, $Gamma_o (u)$ are users which $u$ follows), and the set of users which user $u$ follows as $Gamma_"in" (u) = Gamma_i (u)$ (user $u$ followers)

*Example*: Lets say users $u_1, u_2, u_3$. Now, given the following relationships:

$ u_1 -> u_2 \ u_3 -> u_2 \ u_2 -> u_1 $

$u_2$ followers are $Gamma_i (u_2) = { u_1, u_3 }$ so those will be exposed to $u_2$ posts. Instead, $Gamma_o (u_2) = {u_1}$ so $u_2$ will see posts from $u_1$.

Note: $Gamma$ has been chosen as it's typical to set this as the neighbors of the graph.

As the simulation advances, a user can chose to follow, unfollow, block or mute another user. This defines a new set of actions from user to user, which will be denoted by $cal(U)$.

*Definition* We denote the set of actions that a user $u$ can do in respect to user $v$

$ cal(U) = { "follow/"f, "mute/"m, "unfollow/"u, "block/"b } $

*Definition* we define an action $mu$ performed by user $u$ to $v$ as the function connecting two users performed with a binary space as big as the cardinal of actions.

$ mu (u, v, k) --> {0,1}^(|cal(U)|) $

// TODO: same idea as the user actions!

=== User Feed: Timeline

The timeline is all the posts the user will be shown. In this simulation, the timeline of a user $u$ is composed of two types of posts:
- Posts created by users followed by $u$.
- Posts quoted, replied and reposted from any user followed by $u$. 
followed in reverse-chronological order.

As we defined in the previous section, $Gamma_(p) (u)$ are all the posts created by user $u$. 

*Definition* We'll call the activity of a user the set of posts that get interacted by the user $u$. That isn

$ A (u) = {i in I | exists a_(u,i)^({c, r, q})} $

With the activity we can define the timeline for a given user:

*Definition* The timeline for a given user is 

$ cal(T) (u) = union.big_(v in Gamma_o (u)) A (v) union Gamma_p (v) $

All of the above definitions (the timeline and the activity) will be accessed in a timely matter. To do that, we define the following two access ways: let $S$ a set containing items $i$ with an associated timestamp.
- $"pop"(S)$: returns the post $i$ associated with the least timestamp.
- $"push"(S)$: returns the post $i$ associated with the biggest timestamp.
- $S(t)$ returns all the elements such as it's timestamp is smaller than $t$

=== Evaluation Metrics

Regarding evaluation metrics, we have to distinguish between several traces of the simulation, one for what the user has seen, another for what the user has done, and the last one for what has happened to the post.

- Impression history of a user: $H^"imp"_u (t) = epsilon_u (t) = (i_1, i_2, ..., i_k) $. It is essentially a subset of $cal(T)_u$, but allows us to review in order what has the used seen. will be needed to count how many users have seen each post.
- User historic activity: $H^"act"_u (t) = cal(H)_u (k)= {(i,a, tau) : a != emptyset, tau < t } $. What exactly did the user do, at which time.
- Item trajectory: $T_i (t) = {(u, a, tau)  | tau < t } "where" a in {c, r, q}  $. That is a list with all the users who have reposted at given time time $tau$.



