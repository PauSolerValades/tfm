
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


Let's define the entities at play $V = cal(U) union cal(I)$, where $cal(U)$ is the set of Users and $cal(I)$ is the set of Posts (Items). 
- The simulation contains $N in NN$ users, so $|cal(U)| = N$.
- The simulation contains $M in NN$ posts, so $|cal(I)| = M$.

*Definition* $V$ will be the nodes of the social network graph. It will be a heterogeneous graph, as there are two types of nodes, which we called entities.

=== Relationships Between Entities

Every event that happens during the simulation is an edge of the graph, that is, there are different types of edges, according to the performed action, which in turn changes according the entities involved. To define and edge, we first have to formalize the relationships between entities. We categorize those relationships $cal(R)$ into three distinct relationship sets:

*User-to-User Actions* ($cal(R)_(cal(U) cal(U))$): These actions must be performed by a user over other user. We'll call this actions $ cal(R)_(cal(U) cal(U)) = { "follow", "mute", "block", "unfollow" } $

All edges added by actions in $cal(R)$ are just one edge, as this one: $(u_1, u_2, a_(u,u), t) "where" a_(u,u) in cal(R)_(cal(U), cal(U))$.

*User-to-Post Edges* ($cal(R)_(cal(U) cal(I))$): These actions are must be performed by a user over a post. Actions include $ cal(R)_(cal(U) cal(I)) = { "create", "like", "repost", "reply", "quote", "ignore" } $

All edges added by actions in $cal(R)$ are just one edge, as this one: $(u, i, a_(u,i), t) "where" a_(u,i) in cal(R)_(cal(U), cal(I))$.

*Post-to-Post Edges* ($cal(R)_(cal(I) cal(I))$): These actions must be performed by a user over a post $i$ but on the contrary as the user to posts actions, this involve the creation of the other two relationships. The actions are 

$ cal(R)_(cal(I) cal(I)) = { "replies", "quotes" } $

- Replies: If the action performed by $u in cal(U)$ over $i in cal(I)$ is a reply, the following edges must be added to the graph, at the same time $t$: ${(u, i_r, "create", t), (i_r, i, "replies", t)}$.
- Quote: If the action performed by $u in cal(U)$ over $i in cal(I)$ is a quote, the following edges must be added to the graph: ${(u, i_r, "create", t), (i_r, i, "quotes", t)}$

*Definition*: An edge is a tuple $e = (v_"src", v_"dst", a, t) in cal(E)$ representing an interaction originating from a source node $v_"source"$, targeting a destination node $v_"destination"$, of a specific relationship $a in cal(R)$, at time $t$.


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
= Simulation Concepts and Definitions

In this section we explain all rellevant simulations concepts.

== Static _versus_ Dynamic

Let's take a step back from the problem defined at @sec-modeling for a minute. In there, we assumed for the sake of simplicity that $cal(U)$ remained _static_ for the duration of the simulation. Let's define what that means.

*Definition* An *entity* is called static when the amount of them in the simulation will not change. On the contrary, we will call it *dynamic* if the cardinal of the set changes during the simulation duration.

In @sec-modeling we assumed all entities and relationships between users are static, so they are not going to be added or removed during the simulation. A different thing is when an entity appears, and which strategy we follow to make them appear.

=== Warm Up and Timeline
<sec-warmup>

The time creation of the posts make the simulation vary widely according to where the most amount of posts are created. If all the posts are generated with an exponential with mean 1, all the posts will be created for all the simulation duration. Instead, if we use a $"Unif"(0, "horizon")$ they will appear as the simulation goes on. 

To have the freedom of picking how's the state of the network when the simulation starts, we define a warm up state, which is a time in where the simulation executes itself but stores no trace until a condition is met.

A simulation timeline now contains of this rellevant timestamps:
- Horizon $t_h$: maximum time the simulation will be ran.
- Duration $d$: actual time in which the simulation will be ran.
- Warm up $t_w$: time where the trace and metrics are not being stored.

So, we can define the duration of the simulation as the following:
- A simulation _executes_ always from 0 to $t_"end" = min {t_w + d, t_h}$.
- A simulation is _evaluated_ always from $t_w$ to $t_"end"$.

This allows us to introduce two new concepts, regarding when and how a new event plays into the simulation.

*Definition* We call an event:
- *deterministic* if it appears at the same exact timestamp between runs i.e is not randomly generated.
- *scheduled* if it gets created stochastically before the simulation runs.
- *stochastic* if it gets created stochastically while the simulation is running.

(Probably) If an entity is dynamic, then it will be always an stochastic. 

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
   - Max Items: New posts will be apended to the simulation, but not in a random way, that is: timelines will be predefined beforehand.
   - Static User Relationship: The follower graph $cal(N)_"out"$ and $cal(N)_"in"$ remains constant; no follow/unfollow actions occur.

4. Relationship Subset: The only User-to-Post actions that can occur are $cal(R)^' _(cal(U) cal(U)) = {"ignore", "like", "repost"} subset cal(R)_(cal(U), cal(U))$

5. Algorithm: shows followers posts with a chronological (oldest to newest) order.

Despite being enforced by the definition of $cal(T) (u,t)$, let's add this two other axioms:

6. No-self-loop: A user cannot have its own posts on its timeline ($cal(P) (u, t) inter cal(T) (u, t) = emptyset$)

7. Single-Action Loop: A user can interact with an item once.

== Implementation

We can simulate the networks with a Discrete Event Simulation with the Event Scheduling algorithm. This coincides with the Embedded Discreet-Time Markov Chain formalized described in the previous section as an approximation of the CTMC that could be deduced from the data.

=== Types of Implementation 

As v1 is absolutely _static_ we can define four different types of implementations according how the post entities get managed:

+ Diffusion simulation: if we wanted to analyze just the post spreading, we could decide a fixed amount of posts per user that will be created at the exact same time. This would be a deterministic way of handling posts. If you were to randomize when those post appear, it would make the events scheduled.
+ Standard: an event scheduling implementation making the user creating the posts stochastically. To enforce the maximum amount of posts per simulation, we must keep track of how many posts did the user create, and when reached, not generate any more posts. This approach allows a warm up strategy to investigate more advanced stages in the network. All post creation events are stochastic by nature.

Additionally, by implementing a loading checkpoint strategy in the standard approach, we can skip the warm up. If what it's actually needed is to evaluate a network from an starting deterministic position, this would be the correct approach. Tho also allowing warm up, it makes no sense to do it, as the initial state can be already rich enough to not need it.

The actual implementation of v1 is the diffusion simulation.

=== Data Generation and Structure

[Paper about how to generate social networks topologies here: @amin2022scale]

First, we'll use synthetic data generated in JSON format to run the simulation. This code can be found in [simulation/synthetic_data_generation/generate_data.py]. The graph has three parameters that controls the end result.
 
#text(blue)[TODO: Read the paper and make a section regarding this (summarized)]


=== Options and Configuration

For the simulation to run, the following config file needs to be provided as a valid JSON:

```json
{
  "seed": null,
  "horizon": 10001,
  "duration": 9000,
  "warmup_time": 1000,
  "user_policy": { // probability of each action
    "categorical": {
      "weights": [0.50, 0.30, 0.20 ],
      "data": [ "ignore", "like", "repost" ]
    }
  },
  "user_inter_action": { // Time between actoins
    "exponential": {
      "mean": 3
    }
  },
  "max_post_per_user": 10, // Max amount of posts per user
  "diffusion_post_schedule": {
    "min": 0,
    "max": 10000,
    "interval": "oc"
  },
  "propagation_delay": { // Time between action and appearence of followers timeline
    "constant": {
      "value": 1
    }
  },
  "interaction_delay": { // Time between seeing a post and acting upon it.
    "constant": {
      "value": 1
    }
  },
  "creation_delay": { // Time between deciding to create a post and it's appearence
    "constant": {
      "value": 1
    }
  },
  "trace_to_file": true // should the traces be outputed to file
}
```
Each parameter in the JSON accepts a different type of distribution: Constant, Uniform, Exponential, Categorical or ECDF as part of the Distributions library @distributions-lib.

To run the simulation we'll use the *Event Scheduling Algorithm*. An event in our simulation is defined as
- time: which timestamp has this event happened.
- action: which action has the user did.
- user: all the information listed in the user category.
- id: number of the event happening in the simulation.

There is just one event in the simulation `Action` - ignore, like, repost. 

The idea of the algorithm is to model every timeline of a given user as a MinHeap. All posts of the simulation get scheduled according to the Uniform `diffusion_post_schedule` - notice this is not allowed to be an arbitrary distribution, just a uniform one - to the whole simulation. That also constructs user timelines with all the posts they will see during the simulation. Once the simulation starts running, reposting will propagate posts to user timelines.

The simulation will log out a trace in JSON format, which is a register of all events that happened in the simulation. Contains the same information of the event with the id of the post that has been interacted with.

Before detailing the algorithm, we define the following helper functions and structures:
- $Q$: A priority queue of events ordered by time $t$.
- $"pop"(S)$: Extracts and returns the first element from an ordered set or queue $S$. If $S$ is empty, it returns $emptyset$.
- $"push"(S, x)$: Inserts element $x$ into the set or queue $S$.
- $"gen"(u, t)$: Generates a random future event $e$ with action $a$ for user $u$ at a time $t + tau$ where $tau ~ X$ is a random variable. 
- An event $e$ is a tuple $("time", "action", "user", "id")$, where $t$ is the timestamp, $a in cal(A)$ is the action, $u$ is the user, and $"id"$ is the event identifier.
- Every user has a distinct timeline $cal(T)_u$, which is a priority queue defined at the first point and its already filled with data from the data loading step.
- Recall from our notation that $r in cal(A)$ denotes a repost action.
- $cal(S)$: A global set tracking $(u, i)$ pairs to ensure users do not process or receive posts they have already seen (maps to user_seen_post).

#pseudocode-list[
  + $t_c <- 0.0$
  + $Q <- emptyset$
  + $cal(S) <- emptyset$
  + *for* $u in cal(U)$
    + $"push"(Q, "gen_action"(u, t_c))$
  + *end*
  + *while* $t_c <= t_h$ *and* $Q != emptyset$
    + $"event" <- "pop"(Q)$
    + $t_c <- "event"."time"$
    + $u <- "event"."user"$
    + $"push"(Q, "gen_action"(u, t_c))$ 
    + $"post" <- "peek"(cal(T) (u))$
    + *if* $"post" != emptyset$ *and* $"post"."time" <= t_c$ *then*
      + $i <- "post"."id"$
      + $"pop"(cal(T) (u))$
      + $cal(S) <- cal(S) union \{(u, i)\}$
      + *if* tracing is enabled *then*
        + $"Log"(t_c, "event"."action", "event"."id", u, i)$
      + *end*
      + *if* $"event"."action" == "repost"$ *then*
        + *for* $v in  cal(N)_"out" (u)$
          + *if* $(v, i) in.not cal(S)$ *then*
            + $"push"(cal(T) (v), "gen_arrival"(i, t_c))$
          + *end*
        + *end*
      + *end*
    + *end*
  + *end*
]

=== Implementation quirks

There must be a list with all the scheduled events MinHeap, and then each user has a MinHeap with a index to the post the user has to see (the oldest one). 

*Peek and Time Travel*

There is a potential time travelling due to the interaction of `propagation_delay`, $t_c$ and each user having it's own timeline. Let's give an example.

1. User $u$ sees posts $i$ and reposts it.
2. Post $i$ propagates to $cal(T) (v)$ at time $t_i = t_c + d_p$.
3. User $v$ has an action scheduled at $t_a$ where $t_c < t_a < t_i$, but $cal(T) (v) = {i}$, so $"pop"(cal(T) (v)) = i$, which should be at time $t_i$ processed at time $t_a$.

We have time traveled to the future. To avoid that, we introduce the $"peek"$ operation, where we access tot the post $i$ but it does not get deleted from $Q$. Let's replay the example

3. User $v$ has an action scheduled at $t_a$ where $t_c < t_a < t_i$. $cal(T) (v) = {i}$, so $"peek"(cal(T) (v)) = i$ and $t_a < t_i$ so it does not get processed.
4. Next event is another user $v$ action, now at $t_c > t_i$, so the peek condition will be fullfiled and the event processed.


*Graph Representation* 

Normally, graphs are performance killers. Choosing a wrong representation of the data will essentially kill performance, as traditional graph representations will maximize cache miss rates. A graph must contain the following information:
+ List of users (nodes)
+ List of posts (nodes)
+ Relationships between users (follows)
+ Relationships of post ownership and viewship.

List of users and post are covered in the following subsections. To further continue the explanation, we shall assume they exists and they contain the information.

As per axiom of stability of the simulation, the follows are predefined and static, se we can make an adjacency list with fixed indexes instead of a matrix. This is called a Compressed Sparse Row or, with graph theory nomenclature, and static adjacency list. Normal OOP mindset would be to make every user have it's own followers array, but that implies loading small lists on to CPU cache from RAM, which is a time consuming operation. Specially, the transmission of a repost involves accessing this array per the post author, so it has to be done once per cycle in the main loop.

Instead of each user storing an array of followers (pointers to a user or user ids) we centralize all the following logic in an static dynamically allocated slice `followers: []Index`. It does not need to grow dynamically, therefore an `ArrayList` is not needed. All the followers are stored sequentially on the array, concatenating one another, and then we store the starting index and it's count in separate arrays.  This paradigm is called CSC or CSR (compressed sparse row) #text(blue)[fins a good way to cite this] Lets make an example to showcase it:

$ cal(N)_("out") (u_1) = {u_2, u_3, u_4, u_5} \ cal(N)_("out") (u_2) = {u_3} \ cal(N)_("out") (u_3) = emptyset \ cal(N)_("out") (u_4) = { u_1, u_5} \ cal(N)_("out") = (u_5) = emptyset $

Then, this code would allow us to access the information:

```zig 
const user_index_start = [_]u32{ 0, 4, 5, 5, 7 };
const user_count = [_]u32{ 4, 1, 0, 2, 0 };

const followers = [_]u32{ 
    2, 3, 4, 5, // u1 (start 0, count 4)
    2,          // u2 (start 4, count 1)
                // u3 (start 5, count 0)
    1, 5        // u4 (start 5, count 2)
                // u5 (start 7, count 0)
};
```

The followers of user $u_(i+1)$ can be accessed by slicing the followers static array:

```zig
const i = 1;
const start = user_index_start[i];  // 4 
const amount = user_count[i];       // 1 

for (followers[start..start+amount]) |f| { //4..5 -> just 4
  // do stuff
}
```

Additionally, this can be further simplified by eliminating the user_count array completely and use the next element of the array to know the count, making the struct smaller.



To improve locality this matrix is not implemented as an array of arrays, but is flattened into a 2D array. To access user $u_j$ $i$-th post is with the formula $N*u + i$. Check data structures for actual implementation of this field.

*No Pointers, just Indices*

Instead of storing slices of pointer to users and posts `user: []*User` we use the index of the element in an array with a `u32` type, that is `user: []u32`. This obeys two reasons:
1. Avoid pointer chasing: Every pointer defererences involves the CPU fetching from memory the contents of the pointer. Again, this is slow due to RAM being slow. Repeated access in a for loop over the accumulates several delays over the data.
2. Smaller significant representation: in a 64-bit architecture CPU, a memory address is 64 bits (8 bytes). By representing the indexes as a `u32` (32-bits, just 4 byte (32-bits, just 4 bytes) when a cache line is loaded it will contain double the amount of data than it had when loading a pointer. This implies tho that maximum users (and posts) is reduced to a maximum of $4294967296$, which is still absolutely enough. This is totally acceptable trade of for the improved speed that smaller structs in memory will result.

*Data Structure Representation*

In traditional object oriented paradigm, data is stored in a Array of Structs: each `User` with all its information is stored in an array. This is not intrisically wrong, but can be optimized according to the access needed to the data. In our case, as several fields need to be iterated upon and accessed not at the same time (eg, access to the id does not imply access to every other field of the struct and viceversa) we benefit of a Struct of Arrays approach: we store a struct with an array per every field of the `User` structure in a structure. In Zig this is implemented in the std as a `MultiArrayList`.

The advantages are clear: when iterating over user id, we are just accessing one field of the struct, improving cache locality and allowing much more data into the CPU cache. This also allows the storage of `user_start_index` as just an element `start_index` inside the `User` struct, with the `MultiArrayList` converting it into a structure of arrays.

Posts are stored with the same approach, giving the exact same benefits.

*Which user has seen which posts*

The simulation treats ownership and seeing the post equally, which can be consequence from the axioms 6 and 7 (user cannot see a post twice + user cannot see its own post)

Implementation of `user_seen_post` (set $cal(S)$ on pseudocode) is a DynamicBitSet using a 1D representaiton of the following matrix:

$ 
S(u,i) = cases(
  1 "if" bb(1)_( i in cal(H)_(u(t))^"imp" or i in cal(P) (u)) (u), 
  0 "otherwise"
) 
$

where $dim(cal(S)) = (N · m) · N = N^2 m$, where $m$ is the maximum amount of posts per user. As it's one dimensional, access to post $i$ of user $u$ is just

$ j = u · T + i  "where" T = N m $ 
 
Bitwise allows the check of an item being one to be very fast due to small type repesentation (a bit) and the CPU being absolutely efficient at making bitwise operations comparisons. the main problem with that is the implementation memory needs grow quadratic with the number of users and their max posts. To make it linearly scalable, a HashMap would be the proper choice to check if a user has seen a post. This being a proof of concept I've sacrificed scalability for speed with lower amounts of entities.


*Keeping Events Order*

Both user timelines and global timeline are implemented using a Heap structure, making every access $O(1)$, but every insertion $O(log n)$. This is the most optimal data structure without entering ring buffers implementations, which need of several assumptions to not fail. There are some data structures based on Circular Buffers called time wheels #text(blue)[reference the papers in documents] but they are a little bit more involved, although having an amazing speed up dues to not needed dynacmically allocated memory.

*Random Number Generation*

To accurately generate random numbers, i've implemented a library called `distributions` with two types of polymorphism: a Union to be able to load any continuous or discrete distributions into memory and an intrusive interface to allow a generic `Distribution` type with a `sample()` method, which allows to write the simulation code completely unrelated to which distribution has been loaded, due to the interface guaranteeing there is a sample method implemented.

Distributions implemented are `Constant`, `Uniform` with four different types of interval, `Exponential` with the Ziggurat algorithm to avoid the logarithm with the inverse method, `Normal` with the Ziggurat method, `ECDF` and `Categorical`, which assigns a weight to several actions.

== Correctness & Limitations

The Axioms massively simplify what is a social network in order to provide a verifiable implementation. I want to address two facts which may steer away the simplification too far from being an actual representation.

1. Chronologically sorted or reverse-sorted: most of social network feeds are not given from oldest to newest, but from newest to oldest. Assuming a not reverse chronological order helps not to ask unconfortable questions regarding new timeline added posts (when a newer post should appear in the timeline if you are showing it from newest to oldest) which would clutter a rather simple testing implementation. Additionally, non-reverse order for sure mantains a Markov structure, which I am not sure with reverse chronological order.
2. Timeline definition: Once a user has seen a post, it cannot be seen again. It could be a system in place that refloats newer posts if they get popular again with some criteria.

#pagebreak()
= Version 2: Sessions

The main objective of v2 is to implement a Reverse Chronological Order algorithm (instead of a Chronological Order) with the introduction of user sessions.

A user now can be in two states:
- online: will see its feed and interact according to a policy $pi_u$.
- offline: its not active in the simulation. 

A user will switch between those two states periodically according to a distribution or because it has received a notification and went back online to check an interaction.

== Model

#text(red)[*La modelització hauria de contenir els ids de sessions? Jo penso que no, que és un tema d'implementació. La modelització pot assumir que qualsevol esdeveniment s'organitza adequadament*]

We'll expand the @sec-modeling notation. First we have to add when the user is inactive or active, and what this involves.

All the part of modeling the topology does not need to be changed, as the only thing that has changed is user behaviour and when can a new edge be added to the state of the simulation.


Let's redefine the user set $cal(U) = {(1,s_1, g_1), ... (n, s_n, g_n)}$ where $(i, s)$, where $s in { "online", "offline" }$, and $g_i in NN$ is the session counter. Now, a user cannot do any action in $cal(R)$ if $s_i = "offline"$, and the simulation won't be able to.

#text(blue)[Analogous to the other definition we can do it function based. Let define a set $S$ with cardinal $N$ number of users. The function $"status": cal(U) --> S$ says in which status is user $u$ in.]

To not create time inconsistencies, we need user timeline to return the most recent post propagated, not the oldest. We will still denote the timeline as $cal(T) (u)$, but the function $"pop"(cal(T) (u))$ will return max $t$ post.



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


7. Algorithm: shows followers posts with a reverse-chronological (oldest to newest) order within it's session.

Despite being enforced by the definition of $cal(T) (u,t)$, let's add this two other axioms:

8. No-self-loop: A user cannot have its own posts on its timeline ($cal(P) (u, t) inter cal(T) (u, t) = emptyset$)

9. Single-Action Loop: A user can interact with an item once.

== Pseudocode 

We offer four pseudocodes in this section: PropagatePost is used when a post is reposted or created, moving to the followers of the user executing that action is doing, StageOne creates the initial state of the simulation by filling the timelines at $t=0$, InitSessions choses a random proportion of users that should start online, and assigns them their actions; if they start offline it assigns them when should they wake up, and SimulationV2 is the actual code of the simulation.

#pseudocode-list[
+ *procedure* $"PropagatePost"(u, i, t_c)$
  + *for* $v in cal(N)_"out"(u)$
    + *if* $(v, i) in.not cal(S)$ *then*
      + $"push"(cal(T)(v), "gen_arrival"(i, t_c))$
    + *end*
  + *end*
+ *end*
]

#pseudocode-list[
+ *procedure* $"StageOne"$
  + *for* $u in cal(U)$
    + $"push"(Q, "gen_create"(u, t_c))$
    + $cal(S) <- cal(S) union \{(u, "post_count")\}$
  + *end*
  + *while* $t_c <= t_"warmup"$ *and* $Q != emptyset$
    + $"event" <- "pop"(Q)$
    + $t_c <- "event"."time"$
    + $u <- "event"."user"$
    + *if* $"event"."type" == "create"$ *then*
      + $i <- "event"."post_id"$
      + $"PropagatePost"(u, i, t_c)$
      + $"push"(Q, "gen_create"(u, t_c))$
    + *end*
  + *end*
+ *end*
]

#pseudocode-list[
+ *procedure* $"InitSession"$
  + *for* $u in cal(U)$
    + $r <- "Uniform"(0, 1)$
    + *if* $r < "offline_ratio"$ *then*
      + $"online"(u) <- "false"$
      + $"push"(Q, "gen_session_start"(u, t_c))$
    + *else*
      + $"online"(u) <- "true"$
      + $"push"(Q, "gen_session_end"(u, t_c))$
    + *end*
  + *end*
+ *end*
]

#pseudocode-list[
+ *procedure* $"SimulationV2"$
  + $t_c, Q, cal(S) <- 0.0, emptyset, emptyset$
  + $"StageOne"()$
  + $"InitSessions"()$
  + *for* $u in cal(U)$ *where* $"online"(u) == "true"$
    + $"push"(Q, "gen_action"(u, t_c))$
  + *end*
  + *while* $t_c <= t_h$ *and* $Q != emptyset$
    + $"event" <- "pop"(Q)$
    + $t_c, u <- "event"."time", "event"."user"$
    + $"isEventStale" = "event"."session_gen" != u."session" $ 
    + *if* $"isEventStale"$ *then* continue *end* // Skip stale events
    + *if* $"event"."type" == "create"$ *then*
      + *if* $"online"(u) == "true"$ *then*
        + $i <- "event"."post_id"$
        + $cal(S) <- cal(S) union \{(u, i)\}$
        + $"PropagatePost"(u, i, t_c)$
      + *end*
      + $"push"(Q, "gen_create"(u, t_c))$
    + *else if* $"event"."type" == "session.start"$ *then*
      + $"online"(u) <- "true"$
      + $"session_gen"(u) <- "session_gen"(u) + 1$
      + $"push"(Q, "gen_session_end"(u, t_c))$
      + $"push"(Q, "gen_action"(u, t_c))$
      + $"push"(Q, "gen_create"(u, t_c))$
    + *else if* $"event"."type" == "session.end"$ *then*
      + $"online"(u) <- "false"$
      + $"push"(Q, "gen_session_start"(u, t_c))$
      + $"clear"(cal(T)(u))$
    + *else if* $"event"."type" == "action"$ *and* $"online"(u) == "true"$ *then*
      + $"post" <- "peek"(cal(T)(u))$
      + *if* $"post" != emptyset$ *and* $"post"."time" <= t_c$ *then*
        + $i <- "post"."id"$
        + $"pop"(cal(T)(u))$
        + *if* $(u, i) in cal(S)$ *then*
          + $"push"(Q, "gen_action"(u, t_c))$
          + *continue* // Safeguard against already seen posts
        + *end*
        + $cal(S) <- cal(S) union \{(u, i)\}$
        + *if* $"event"."action" == "repost"$ *then*
          + $"PropagatePost"(u, i, t_c)$
        + *end*
        + $"push"(Q, "gen_action"(u, t_c))$
      + *else* // Timeline drained, user logs off early
        + $"online"(u) <- "false"$
        + $"session_gen"(u) <- "session_gen"(u) + 1$
        + $"push"(Q, "gen_session_start"(u, t_c))$
      + *end*
    + *end*
  + *end*
+ *end*
]

The introduction of sessions introduces several problems to handle, which are encoded in the pseudocode.

Imagine the following example, with the following state of user $u$:
- $(u, "online")$
- $cal(T) (u) = { (1, t^p_1 ), (2, t_2^p) }$
- $Q = { (u, "action", i, t_1), (u, "end", i+1, t_2), (u, "action", i+2, t_3) (v, \_, i+3, t_\_)}$

1. Pop the first element of $Q$, an action, which pops $(2, t^p_2)$.
- $(u, "online")$
- $cal(T) (u) = { (1, t^p_1 ) }$
- $Q = { (u, "end", i+1, t_2), (u, "action", i+2, t_3) (v, \_, i+3, t_\-}$

2. User goes online
- $(u, "offline")$
- $cal(T) (u) = { (1, t^p_1 ) }$
- $Q = { (u, "end", i+1, t_2), (u, "action", i+2, t_3) (v, \_, i+3, t_\-}$

3. Next event is processed:
- $(u, "offline")$
- $cal(T) (u) = { (1, t^p_1 ) }$
- $Q = { (u, "action", i+2, t_3), (v, \_, i+3, t_\-)}$

Now, we have to question two things:
1. What should be done with $cal(T) (u)$ when goes offline? Line 29, the timeline gets deleted.
2. What should happen if an event of a user is popped from $Q$ when user $u$ is offline? We add a session id which tracks which session is the user in. An event can't be processed if the session of the user stored in the event is different from the session the user is currently in (specifically, the condition which will be invalid most of the time - if the `inter_session_duration` is reasonably long - will be $"current_event.session" + 1 == "user.session"$).

=== Calibration, Session and breaking distributions in DES

The above decision contains a sutile implication of calibration procedures: time between action and creation are measured _within a session_ and not globally.

Discrete event simulations work by sampling an uninterrupted renewal process, which we characterize with sampling a given distribution.

If the distribution we are renewing the process from is consistently truncated as the session identifier does, we are not using the specified distribtuion (eg, a GOF test would fail, as we are ommiting some samples which are dependent from another distribution) and this would _not_ be an uninterrupted renewal process.

Now, this depends then on how do we calibrate the variables `action_inter_duration` and `create_inter_duration`. It's out of the question that those events cannot be scheduled when a user is online, but the process could be interrupted and just shifted by a constant amount: the duration of the offline period.

Consider the same example as before, and we are not going to use the session counter to not break causality
- $(u, "online")$
- $cal(T) (u) = { (1, t^p_1 ) }$
- $Q = { (u, "action", i, t_1), (u, "end", i+1, t_2), (u, "action", i+2, t_3) }$
1. $"pop"(Q) -> (u, "action", i, t_1), "pop"( cal(T) (u))$
2. $"pop"(Q) -> (u, "end", i+1, t_2) -> (u, "offline")$
3. $"pop"(Q) -> (u, "action", i+2, t_3)$, but the user is offline. Instead of discarding it, we reeschedule it to appear when the user goes online:
   1. Push the new $"start"$ event: $"push"(Q, (u, "start", i+3, t_4))$
   2. Push the previous scheduled actions/create with the offset remining to create the simulation: $"push"(Q, (u, "action", i+4, t_4 + (t_3 - t_2))$
   3. Stop $"action"$ generator for user $u$ until the event is processed.


An implementation problem could arise if the following queue after processing the event.
- $Q = { (u, "end", i+1, t_2), (u, "start", i+2, t_2), (u, "action", i+3, t_3) }$
 
So a mechanism would be needed for now not reescheduling that action, which is already properly scheduled.

TL;DR: it all cames down to this what is actually `action_inter_duration`
- if it measures exactly what the name says (duration between two actions regardless of the sessions) then the current implementation is flawed.
- if it measures `action_inter_duration_within_session` then current implementation is adequately representing the current state. 

=== Proposed Session Calibration Solution
#text(blue)[This section of the document is an AI dump of ideas]

// This part of the document is an AI dump of ideas, 
A fundamental limitation of utilizing public social media firehose data (such as the ATProto Jetstream) is the "dark matter" problem: the stream strictly broadcasts write-events (e.g., posts, likes, reposts) and completely obfuscates passive read-events (e.g., timeline scrolling, profile viewing). Consequently, explicit session boundaries cannot be directly observed. To calibrate the simulation's $t_"session_duration"$ and $t_"offline"$ parameters, we outline three viable methodologies for session estimation:

+ *Heuristic Thresholding ($tau$) with Boundary Padding ($delta$):* This approach infers sessions from the densest possible set of write-events. Two consecutive actions by user $u$ at times $t_i$ and $t_{i+1}$ are grouped into the same session if the inter-action duration $Delta t <= tau$ (where $tau$ is a predefined inactivity threshold, typically 10-15 minutes). To account for the unobserved passive scrolling before the first action and after the last action, a padding variable $delta$ is introduced. The estimated session boundaries become $t_"start" = t_1 - delta_"start"$ and $t_"end" = t_n + delta_"end"$, yielding a wider, more realistic session distribution.

+ *Literature-Informed Calibration:*
  Rather than processing raw firehose data, the simulation parameters can be calibrated using established probability distributions from existing social media telemetry research. This provides immediate, empirically grounded parameters for session lengths and inter-session intervals, though it assumes user behavior on the target platform perfectly mirrors general macro-platform trends (e.g., X/Twitter or Reddit models). _(Note: Studies utilized for this calibration must be carefully selected for mobile-heavy platforms, accessed March 26, 2026)._

+ *Empirical Telemetry via Custom Feed Generators:*
  To capture absolute ground-truth session data without relying on heuristics, explicit read-telemetry can be gathered by hosting a Custom Feed Generator. When users navigate to the custom feed, the platform's AppView forwards a `getFeedSkeleton` HTTP request to the feed server. Logging the timestamps and authenticated DIDs of these pagination and refresh requests completely resolves the silent boundary problem, providing exact metrics for timeline drain rates and session lengths.

== Implementation

=== Types of Implementation 

v2 shares a large amount of features and characteristics with v1, and as well the type of implementations are very similar: both standard (with warm up allowed) and checkpointing from a fixed state simulation (no warm up allowed) work with the same dynamics.

The diffusion model requires a small tweak to be coded. In v1, the user timelines could be prefilled with the appropiate `TimelineEvent` struct. Now, the timelines being a MaxHeap, scheduling of all events outside of that session will create a time incongruency: if all the timeline is filled with events ouside of current session, specifically from the future, poping an element will give you an event skipping some events in the middle. If implemented, it should fill the `Queue` structure with `.create` events.

As the session logic is sligtly more complex and the checkpoint from standard approach is quite heavy to actually implement we can follow the following approach to achieve an adequate init state for the simulation to run over it.

*Staged*: the simulation will change behaviour when the warm up phase is over.
1. Warm Up: just post creation and for a brief time. If there aren't a minimum amount of posts at the beginning there will be strange behaviour at the beginning.
2. Standard: with just some posts created, we will run the standard implementation of the simulation, a normal event scheduling. 


== Implementation Details

Essentially, as the axiom of stability remains unchanged, all the data structures will remain exactly the same. 

*Regarding User Heap*
Now the Heap associated to every user must output in reverse-chronological order, that is, return the element with the largest timestamp instead of the gloabal Heap, which has to do the opposite.

This makes us consider mainly when we have to "empty" the heap of a user, because if a user timeline keeps getting bigger but its not online a lot, could lead to unbound memory growth of `TimelineEvents` structs.

*Post Creation*

As posts can now be created during the middle of the simulation, a way to assign not repeated id must be figured out. The problem is essentially that the interaction with the session gen id, a post can be scheduled for creation (that means the event $(u, "create", p_"id", t) in Q$, but as it can be canceled it does not guarantee that the id assigned when scheduled is going to be the same as the one it's going to end up with.

To account for this, we assign 0 as id when scheduled in the queue, but then it's created appropriately when it's checked that that event is going to be processed.


#pagebreak()
= Version 3: Unlimited Amount of Posts
// this part of the text has been AI generated
Despite being able to make `max_post_per_user` into a Poisson random variable to make the number of posts change according to the simulation, it is believed that users should not have a hard cap on posts by design. Therefore, v3 takes v2 and removes the post stability axiom. Users will not be created during simulation duration nor new follows added, but posts won't have an upper limit. We'll rename axiom 3 to Static Topology.

This will also allow us to add a _reply_ and _quote_ action, due to posts not being limited on creation, but those new two mechanics will be introduced on v4.

This will just focus on the implementations strategy and its data structures, as the simulation behaves exactly the same as v2.

== Hold the posts in memory: segmented list

To store the posts indefinitely without incurring massive performance penalties, we implemented a `SegmentedMultiArrayList`. This structure manages memory conceptually using a "bookshelf" containing multiple "shelves". 

Each shelf is a standard `MultiArrayList` initialized with a fixed capacity, defined strictly as a power of two $N = 2^n$ (or, if you speak computer `1 << n`). When a shelf reaches its capacity during post creation, the structure dynamically allocates a brand-new shelf and appends it to the bookshelf. This completely avoids the costly overhead of reallocating and copying existing items to a larger contiguous memory block as the list grows. 

Item lookups remain virtually instantaneous. By utilizing the power-of-two constraint, finding a post relies purely on fast bitwise operations: a bitwise shift (`i >> n`) determines the correct shelf, and a bitwise AND (`i & (shelf_count - 1)`) grabs the exact post within that shelf.

== Who has seen what: Paginated Bitset

To track which users have seen which posts over an uncapped duration, we transitioned to a custom `PagedBitSet`. This structure models a 2D matrix where rows represent users and columns represent posts. 

Because the number of users is a static topology but posts grow indefinitely, the matrix allocates memory in discrete "pages" comprising an `ArrayList` of `DynamicBitSet`s. Each page covers all users vertically but limits horizontal growth to a fixed chunk of posts (`1 << n` columns).

When the simulation generates a new post ID that exceeds current capacity bounds, the `ensureItemCapacity` function provisions and appends new pages as needed. Checking or setting a boolean impression uses the same fast bitwise math as the segmented list to locate the correct page and the isolated bit offset.

== Comparison with Previous Implementation

Previously, tracking impressions relied on a single contiguous `DynamicBitset` statically allocated upfront using a strict `user * user * max_post` calculation, and the simulation lacked a dedicated data structure to hold posts.

- *Memory Efficiency:* The v2 approach forced a massive upfront memory block based on a theoretical maximum limit, severely wasting space if users did not reach their hard cap. The `PagedBitSet` entirely resolves this by lazily allocating memory (pages) strictly when the simulation generates enough posts to warrant the space.
- *Infinite Scaling:* By removing the hard cap, we no longer artificially bottleneck the simulation logic. The new structures scale naturally on-demand, allowing us to simulate highly active users without triggering out-of-bounds crashes.
- *Data Retention:* Lacking a dedicated structure for posts meant post-specific metadata was impossible to retain. The `SegmentedMultiArrayList` persists post data logically---such as unique IDs and author indices---continuously through the run.

== Structuring Post Contents: The Advantage of SoA for Embeddings

As we expand the simulation (for instance, in v4 with replies and quotes), posts will likely require heavier metadata, such as dense float arrays representing content embeddings for NLP/algorithm checks. The `SegmentedMultiArrayList` is uniquely advantageous for this because its underlying "shelves" utilize Zig's `MultiArrayList`.

A `MultiArrayList` manages memory using a Structure-of-Arrays (SoA) layout rather than an Array-of-Structs (AoS). If we embed heavy data like `[1536]f32` inside the `Post` struct, a traditional AoS list would interleave those massive arrays directly alongside lightweight integers like `author` and `id`. This destroys CPU cache locality when algorithms iterate strictly over basic timeline data. 

Because `SegmentedMultiArrayList` inherits the SoA paradigm, the system stores all authors together, all IDs together, and all embeddings together in separate contiguous slices per shelf. We can query just the author of a post using the `accessField` function without dragging 6 kilobytes of irrelevant embedding data into the CPU cache. The embeddings remain neatly packed and isolated, ready to be retrieved entirely on-demand during active similarity calculations.


#pagebreak()
= Version 4: Quotes and Notifications 

Version 4 implements the last two mechanics of the simulation, Notifications and Quoting, to take advantage of that.

A user can decide to quote a post, which creates another post with the contents of the original post inside of it. When a user does one, they both get shown to followers of the user that quoted. This mechanic introduces non linearity of post spreading, and be refloated without need of contiguous reposts.

Notifications are a way to see and react to posts while the user is offline, and to break linearity of the simulation if the user is online and receive the notification.

== Quoting

Let's define the quoting rules:
- A quote instantiates a brand-new post containing a direct reference (`parent_id`) to the original post being discussed.
- The new quote post is immediately marked as seen by its creator and propagated to all of their followers.
- Unlike the standard warm-up and continuous creation loops, generating a quote does not automatically schedule another future post creation, as it is strictly a reactive event.
- Timeline injection: When a follower encounters a quote post in their timeline, the system automatically retrieves the original parent post and injects it into their timeline at the exact same timestamp, ensuring they have the full context before reacting.
- Every quote action actively generates a targeted Notification event aimed at the author of the original post, dispatched with a standard propagation delay.

== Notifications

Notifications act as an interruption and re-engagement mechanic, primarily driven by quotes:
- *Online Delivery:* If the target user is currently online when the notification arrives, the system bypasses standard propagation and immediately drops the new quote post directly into their active timeline to be processed next.
- *Offline Wakes:* If the target user is offline, the system rolls against an `attend_offline_notification` probability. If successful, the user "wakes up" out of schedule; the quote is injected into their timeline, and a new action event is immediately queued to simulate them logging on to check the interaction.
- *Pending Buffer:* If the offline user does not wake up, the notification is caught and stored in a personal pending buffer, which holds up to a maximum of 64 unprocessed interactions. 
- *Priority Processing:* When a user resumes activity (either by waking up naturally or being pulled online), the simulation forces them to clear their pending notifications first. The system will pop items from the pending buffer and present them to the user before it resumes pulling standard posts from their traditional timeline backlog.

6. Notifications Mechanism: if $(u, j, "quote", t), (i,j, "quotes", t)$, user $v$ such as $i in cal(P) (u,t)$ can come back from vacation early. When a reply to a post is made, 


== Improvements to the notification system

To make it as a discrete event simulation, we can add two mechanics: stamina and staleness
- If a user have more than n notifications (possion distribution for example), let's ignore them all.
- The users will attend m notifications (Geometrics) before getting bored and stopping. Remaining notifications will get discard.

This should be implemented as `max_post_user`, which could be different according to the user, as the user homogeneity axiom will be taken down eventually.


= Known Calibration Problems:
+ How do we obtain user sessions lenght?
+ How do we identify sessions started by a notification and sessions started by scheduling? are those independent events? (yes) but should a session started by a notification delete the scheduled session on start?
+ Action and creation variables are mesuared `_within_session` or they are independent from where the session does start/end?


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

#pagebreak()
= Classification as a Markov Chain
#text(blue)[
Under the axioms defined in @sec:axioms, we can characterize the underlying model as a Continuous-Time Markov Chain (CTMC) where interarrival times of actions follow an exponential distribution. *Move to implementation*]. However, to formally prove the correctness of the Simulation Engine's state transitions and simplify analytical verification, we evaluate its Embedded Discrete-Time Markov Chain (DTMC), commonly known as the jump chain. [This is the pdf `embbedded_markov.pdf`, ask for a better source.]

For this to be a Markov chain, we must ensure the memoryless property is fulfilled, where considering states $s_0, ..., s_t$ can be expressed as follows:

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

In the embedded DTMC, a discrete step occurs when any user's continuous exponential timer triggers. Under the User Homogeneity assumption (Axiom 1), the mathematical probability of any specific user $u$ being the next to act is uniformly distributed across the active population. Thus, the probability of a specific user $u$ "waking up" to act at step $n$ is $frac(1, |cal(U)|)$. 

When a user $u$ acts, their specific action $a_n$ is drawn from the probability policy $pi = (p_"ignore", p_"like", p_"repost", p_"create")$ do to the action limitation in axiom 5.

Let $G'$ represent a candidate for the next state. If the user's timeline $cal(T)(u, n-1)$ is not empty, let $i_u$ be the chronologically oldest unseen post in that timeline. For a "create" action, we bypass the timeline entirely; instead, the action activates an inert, pre-scheduled node $j_"new" in cal(I)$ to satisfy the topological requirement of adding new nodes versus linking existing ones). 

The conditional transition probability when user $u$ acts a step $n$, is defined as:

$ 
PP(G' | G(n-1), "user" u "is active") = cases(
  p_"ignore" & "if" G' = G(n-1) union { (u, i_u, "ignore", n) },
  p_"like" & "if" G' = G(n-1) union { (u, i_u, "like", n) },
  p_"repost" & "if" G' = G(n-1) union { (u, i_u, "repost", n) },
  p_"create" & "if" G' = G(n-1) union { (u, j_"new", "create", n) },
  1 & "if" cal(T)(u, n-1) = emptyset "and" G' = G(n-1),
  0 & "otherwise"
) 
$


To obtain the global transition probability of moving from $G(n-1)$ to $G'$, we marginalize over all possible users in the network:

$ PP(G(n) = G' | G(n-1)) = sum_(u in cal(U)) frac(1, |cal(U)|) dot PP(G' | G(n-1), "user" u "is active") $

*Note*: Action "ignore" has chosen to be modeled due to the need to diferenciate between a user that has seen (and chosen to not interact with) the post and a user who has not seen this post at all. With this, both the graph and the historics are representing everything.

Additionally, the transition function explicitly handles the scenario where a user activates but their timeline is empty ($cal(T)(u, n-1) = emptyset$). In this case, the user cannot interact with a post. The step $n$ effectively advances the clock (or jump sequence), but the graph topology remains mathematically identical to the previous step ($G' = G(n-1)$).


#text(blue)[

*Sobre això: pot ser que en tingui, o no, però no podem dir-ho sense demostrar-ho*

=== The Absorbing State Transition

The simulation reaches its ultimate absorbing state, denoted as $G_"final"$, when the filtered timelines $cal(T)(u, n)$ for all users $u in cal(U)$ are completely empty, and all pre-scheduled posts in $cal(I)$ have been exhausted. At this point, no topological changes can occur.

By definition, an absorbing state only transitions to itself with absolute certainty:
$ PP(G(n) = G_"final" | G(n-1) = G_"final") = 1 $
]

=== Proof of State Equivalence (Global Graph vs. Local Histories)

We can also view the state of the chain as the state of the entities (users and posts). It can be proved that defining the state as the global graph $G(n)$ is mathematically isomorphic to defining it as the union of all localized entity histories.

Let $E(v, n) subset.eq E_n$ be the localized edge set (history) for any single node $v in V$ up to step $n$, defined as all edges where $v$ is either the source or destination:

$ E(v, n) = { e in E_n | v_"src" = v "or" v_"dst" = v } $

By the definition of a graph, the global edge set $E_n$ is exactly equal to the union of all localized node edge sets:

$ E_n = union.big_(v in cal(V)) E(v, n) $

Since the vertex set $V$ is strictly partitioned into users $cal(U)$ and items $cal(I)$, we can decompose this union:

$ E_n = ( union.big_(u in cal(U)) E(u, n) ) union ( union.big_(i in cal(I)) E(i, n) )  =  ( union.big_(i in cal(I)) cal(H)^"act"_u(n) ) union ( union.big_(u in cal(U)) cal(H)^"traj"_i(n) ) $

Notice that for any user $u$, their localized edge set $E(u, n)$ perfectly encapsulates their historical actions $cal(H)^"act"_u(n)$ and impression interactions. Similarly, for any item $i$, $E(i, n)$ perfectly encapsulates its cascade trajectory $cal(H)^"traj"_i(n)$. 

Therefore, the global graph state $G(n)$ contains the exact same information as the union of all individual user histories and item trajectories. Constructing the next event from $G(n)$ is mathematically identical to querying the localized histories of the active entities.


