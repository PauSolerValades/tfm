#import "@preview/lovelace:0.3.0": *

#import "utils.typ": procedure, flex-caption, todo, comment
#import "@preview/cetz:0.4.2"

This chapter covers the design of the simulation: the entities and data model (see @sec-design-entities), the semantics of each event source (see @sec-design-sources), the overall simulation lifecycle (see @sec-design-lifecycle), and the trace schema that captures all state transitions (see @sec-design-traces). For every data structure referenced here, only the algorithmic motivation is provided; the concrete realization, memory layout, and performance considerations are treated separately in @sec-impl.

== Design Overview
<sec-design-overview>

This section aims to give a general description of why the simulation is built the way it is, and how it has been built this way.

=== Experiential Interpretation of the Simulation 
<sec-design-experiential>

The goal of this section is to map the real-world phenomena the simulation attempts to replicate directly to its mechanics, showcasing exactly what the implementation is translating into computational behavior.

In essence, the experience that the simulation models is the behavior of several users checking a social network application to interact with the content on their timelines. Let's focus on the perspective of one single simulated user, as the subjective experience of scrolling a timeline remains identical in a single user basis.

When a user is logged in, it will be actively looking at its timeline posts, one by one. For every post, the user will be able to ignore it, like it or repost it, which will propagate that post to its followers according to a policy $pi$. If the user sees posts he has already seen (went so back into the past that he has seen all the content that it's followers have produced since he logged in), he will refresh the timeline, and see the most recent published post, and start scrolling again. The user will log out if it rans out of new posts to see ---when the timeline refreshes no new posts appear--- or when he gets tired of scrolling. Mapping to the nomenclature of section @sec-model, the logged in time of the user is a session ($S in cal(O) (u)$). If the session finished naturally its ended due to *fatigue*, and if its ended due to a refresh having no new content, it ends out of *boredom*.


The order in which the users will see the posts is in reverse-chronological: newest post first, and they will scroll back into the previous posts. In addition to that, not all users are online at the same time: they will connect and disconnect at their own unique paces, making the amount of content in the user timelines fluctuate. 

The simulation ensembles $N$ distinct users with the described behaviour checking their timelines simultaneously. Despite the experience being the same per every user, the amount of content they will see depends on how are the posts flowing: if user $u$ has a lot of followees and they repost a lot, and they connect with at the same times as he, $u$ will have a lot of content to see and not finish the sessions out of boredom, but due to fatigue.

The best way to interiorize the system workings is to think about it as every user running the microsimluation, but all acting at the same time changes how the content flow, which changes what they see, creating the characteristic feedback loop of complex systems #todo[cite complex system definition]

Lastly, a reminder that the policy $pi$ (probability of ingoring, liking, or reposting a post) is the same per every user and does not depend on the post the user is seeing, as stated in #todo[metodology-assumptions]

=== Simulation Rules
<sec-design-rules>

While the previous section (@sec-design-experiential) gives an intuition of what is the simulation about, it is worth to narrow down the simulation to a series of rules, which define what's possible and characterize the system. These are the following:
+ A user can either create a post, or see the timeline.
+ A user can be in two states: online or offline. When a user is offline, it can't perform any action.
+ When a post is reposted, gets stored in the user timeline, enquequed to be seen later.
+ The only interactions with a post are to like them or to repost them. Ignoring a post is modeled, but does nothing. 
+ A user can't interact (like or repost) with a post already liked and reposted by itself.
+ A user can see a post he has already seen if it gets propagated from another user, but cannot see a post that has already been interacted by the user.
+ If an online user exhausts their visible window and a refresh yields no new posts, they go offline out of *boredom*.
+ Every propagation introduces a delay between the repost action and the post appearing on followers' timelines.

=== Aims and Objectives
#comment[Everything about "of the shelve software for simluation" i really have no clue: either i go deep on it or I don't comment it. Also, this justification ---if it matters--- should be under methodology answering the question: why did you use Zig and write the engine from scratch instread of using simula]

== Data Model
<sec-design-entities>

This section describes the entities used by the simulation and the information they contain to properly characterize it, as well as relating it to the Time-Varying Heterogeneous Graph described in section @sec-model.

=== State Entities 
<sec-design-dm-state>

User entity is the continuous state variables that physically manifest the sets $cal(U)$. It encapsulates the behavioural and temporal parameters to conform to the Activity-driven $cal(U)$.

- *Connectivity*: the entity contains the user state (online or offline) and their follower relationships to enable post propagation on a repost.
- *Behavioural*: every user has the distributions that dictate how long is the session duration, the gap between sessions and the frequency of post creation.


The Post entity is the manifestation of the elements of the set $cal(I)$. It is a fairly simple entity as the post homogeneity makes every post equal, we must just track an identifier and creation time, the two elment needed to evaluate the presence function $psi(i, t)$.

=== Mechanical Entities
<sec-design-dm-mechanical>

Unlike Users and Posts, which represent the theoretical entities of the network, Events and TimelineEvents are strictly operational constructs required by the Discrete-Event Simulation engine to advance continuous time and propagate the information.  
- *Event*: The fundamental mechanical unit of the simulation. An Event is a scheduled state transition always associated to the user the event relates with ---such as a user session starting or ending, interacting with the next post on the timeline, or to create a post. It serves as the operational trigger that updates the network's state without requiring the simulation to compute inactive time intervals.  
- *TimelineEvent*: A simple tuple that links a post identifier to its specific arrival timestamp in a user's chronological feed $cal(T)_t (u)$. It acts as the mechanical payload that physically delivers propagated content to a follower's timeline once the required propagation delay has elapsed. #todo[in the implementation we must discuss why this is a very good idea when adding content]

Lastly, the structure this events are contanied in are the main simulation queue $Q$ and every user timeline $cal(T)_t (u)$.

== Event Sources 
<sec-design-sources> 

This section describes the implementation strategies of the different sources of the simulation provided in the Event subsection on @sec-design-dm-mechanical, and which logic follows the simulation when an event gets processed according to the rules of the simulation (@sec-design-rules).

=== Propagate
<sec-design-sources-propagate>

The first event we must cover is the only event type that does not correspond to any recurrent source: the `propagate` event.

The CTIC model (see @sec-sota-diffusion-ctic and @sec-model-ctic) has a strong emphasis in the incubation time for the infection: "the delay between a node $j$ becoming infected at time $t_j$ and subsequently infecting an uninfected neighbor $i$ at time $t_i > t_j$" which not only serves the purpose of modeling reality, but that delay forces the model to not degenerate and teleport posts from user to user. 

For example, without delay, user $A$ can repost a post at time $t$, that repost arrives at time $t$ at $B$ timeline, and if he has a scheduled action at time $t$, the post can be reposted at also $t$, having the information teleport. This is of course not a valid behaviour, and this idea is showcased with a more in depth example in @anx-ex-teleport.

The `propagate` event therefore contains two critical pieces of information:
- `post_id`: which post has to be propagated.
- `user_id`: the id of the user that created or reposted the post with `post_id`.

The @proc-propagate showcases the implementation of the propagation, which is the same as the one described in @eq-proc-propagate at section the description of the DES simulation (see @sec-method-des-mechanics).

#procedure(caption: flex-caption([Procedure of propagation of a post.], [Procedure of propagation of a post]))[
  #pseudocode-list[
    + *procedure* $"PropagatePost"(u: cal(U), i: cal(I), t_c: T)$
      + *for* $v in cal(N)_"in" (u)$
        + *if* $(v, i) in.not cal(H)_(t_c) (v)$ *then*
          + $"push"(cal(T)(v), "TimelineEvent"{t_c, i})$
        + *end*
      + *end*
    + *end*
  ] 
]<proc-propagate>

When a propagate event reaches the head of $Q$, the main event loop dispatches it to the handler below, as can be seen in @proc-propagate-switch. So, propagation event is not a source, but the result of any repost performed on the simulation.

#procedure(caption: flex-caption([Propagate event dispatch in the main simulation loop.], [Propagate event dispatch in the main simulation loop]))[
  #pseudocode-list[
    + *procedure* $"HandlePropagate"(Q: "EventQueue", t: T, u: cal(U), p: cal(I))$
      + $"pop"(Q) arrow.r (t, u, "propagate"(p))$
      + $"PropagatePost"(u, p, t)$
      + $"processed_events" arrow.l "processed_events" + 1$
    + *end*
  ]
]<proc-propagate-switch>

The propagation delay $Delta_p$ can be configured with the variable `propagation_delay`. 

=== Sessions
<sec-design-sources-sessions>

The second event of the simulation are three events, but they behave complementary. A `session` event can be either one of the following: either `start`, `end` or `end_boredom`. The `start` forces a user back online, and the `end` makes it go back offline.

==== Going Online

When the simulation processes the event `online` for an offline user $u$, it has to restart all the event sources for the next session. To do that, it needs to create an `action` event to start checking the timeline, a `create` event and to schedule when the session will end with a `session.end` ---all according to the users distribution--- in order for the characteristic loop of DES can start with both of the real sources.

#procedure(caption: flex-caption([Session start: puts a user back online.], [Session start: puts a user back online and primes the event loop]))[
  #pseudocode-list[
    + *procedure* $"HandleGoOnline"(Q: "EventQueue", t: T, u: cal(U))$
      + $u."is_online" arrow.l "true"$
      + $u."session_gen" arrow.l u."session_gen" + 1$
      + $u."session_start" arrow.l t$
      + $"push"(Q, "eventAction"(u, t))$
      + $"push"(Q, "eventCreatePost"(u, t))$
      + $"push"(Q, "eventSessionEnd"(u, t))$
      + $"metrics.generated_events" arrow.l "metrics.generated_events" + 3$
    + *end*
  ]
]<proc-go-online>


==== Going Offline

A user goes offline in two scenarios, both handled by the same mechanism:

- *Fatigue* ($"end"$): the session's scheduled duration expires. The user is marked offline and the next session start is queued.
- *Boredom* ($"end_boredom"$): the user drains their visible window, refreshes to expand it, but still finds no new posts in $cal(T)_(t_c) (u)$. The user logs off and the next session start is scheduled.

#procedure(caption: flex-caption([Session end: marks the user offline.], [Session end: marks the user offline and schedules the next session start]))[
  #pseudocode-list[
    + *procedure* $"HandleGoOffline"(Q: "EventQueue", t: T, u: cal(U))$
      + $u."is_online" arrow.l "false"$
      + $"push"(Q, "eventSessionStart"(u, t))$
    + *end*
  ]
] <proc-go-offline>

Both of this options are nested under a check when the event type is a `session`, shown in the @proc-session-handle:


#procedure(caption: flex-caption([Session handle.], [Session handle: dispatches start, end (fatigue), and end_boredom]))[
  #pseudocode-list[
    + *procedure* $"HandleSession"(Q: "EventQueue", u: cal(U), t_c: T, s: "Session")$
      + *if* s == start *then*
        + $"HandleGoOnline"(Q, u, t_c)$
      + *else if* s == end *or* s == end_boredom *then* 
        + $"HandleGoOffline"(Q, u, t_c)$
      + *end*
    + *end*
  ]
] <proc-session-handle>

==== Event Management when User is Online

#comment[this is very important for the simulation, and it's desgin also, but feels close to the implementation. Maybe should be refactored as an example or heavily shortened and kept here]

In an Activity-Driven Discrete-Event Simulation, interrupting a stochastic process introduces a severe operational challenge. Because the system relies on scheduling future events (such as the next user action or post creation) within a continuous renewal process, a user transitioning to an offline state leaves previously scheduled events orphaned in the global Future Event Set ($Q$). Dynamically locating and deleting these orphaned events from the global priority queue upon every session boundary would require O(N) traversals and continuous memory reallocations, effectively destroying the engine's cache locality and computational performance (#todo[cite the implementation appendix when done]).

To resolve this without breaking time causality, the engine employs a lazy-evaluation mechanism via a `session_gen` counter. Every time a user initiates a new online session, their internal generation counter increments. Any event scheduled during that session carries this specific generation integer as part of its payload. When the main simulation loop eventually pops an event, it simply compares the event's stored generation ID against the user's current `session_gen`. If the values do not match, the event is immediately discarded as "stale". This guarantees O(1) event invalidation and ensures that offline users cannot illegally execute actions, preserving the integrity of the inter-action distributions. A step by step example showcasing the need for this is provided in @anx-ex-session-gen.

Knowing the necessity of this mechanism, the @proc-session-event-handle shows the whole process, while calling the previous showcased procedures. $e_"gen"$ is the `session_gen` of the current event, which we already know it's a session

#procedure(caption: flex-caption([Session event dispatch with stale-event guard.], [Session event dispatch with stale-event guard]))[
  #pseudocode-list[
    + *procedure* $"HandleSessionEvent"(Q: "EventQueue", u: cal(U), t_c: T, s: "Session", e_"gen": bb(N))$
      + $"is_stale" arrow.l e_"gen" != u."session_gen"$
      + *if* s = end *and* (!u.is_online *or* $"is_stale"$) *then*
        + *return*
      + *end*
      + *if* s = start *then*
        + $"HandleGoOnline"(Q, u, t_c)$
      + *else if* s = end *then*
        + $"HandleGoOffline"(Q, u, t_c)$
      + *end*
      + $"metrics"."processed_events" arrow.l "metrics"."processed_events" + 1$
    + *end*
  ]
] <proc-session-event-handle>


=== Create

The `create` event behaves as a stardard event source, as it does not have relationships with other event sources or events. When a `create` event is assigned, the simulation searches the last `post_id`, augments it and makes the current user $u$ its author. The @proc-create showcases the event.

#procedure(caption: flex-caption([Create event dispatch.], [Create event dispatch with stale-event and max-posts guard]))[
  #pseudocode-list[
    + *procedure* $"HandleCreate"(Q: "EventQueue", u: cal(U), t_c: T, e_"gen": bb(N))$
      + $"is_stale" arrow.l e_"gen" != u."session_gen"$
      + *if* $"is_stale" or "max_posts_reached" or !u."is_online"$ *then*
        + *return*
      + *end*
      + $cal(P)(u) arrow.l cal(P)(u) union {(u, i)}$
      + $"mark" i "as seen by" u$
      + $"mark" i "as interacted by" u$
      + $"push"(Q, "PropagateEvent"(u, i, t_c))$
      + $"generated_events" arrow.l "generated_events" + 1$
      + $"TraceCreate"(u, t_c, i)$
      + $"post_count" arrow.l "post_count" + 1$
      + $"processed_events" arrow.l "processed_events" + 1$
      + $"push"(Q, "eventCreatePost"(u, t_c))$
      + $"generated_events" arrow.l "generated_events" + 1$
    + *end*
  ]
] <proc-create>

// this paragraph is plain implemenation, not needed
// A noticeable fact is that the `create` type does not contain any payload, as the user that creates it is at that point information known by the program and the `post_id` will be selected if the event is created. Preselecting which `post_id` would the post have when the create event is scheduled is, again, the naive approach, but breaks when interacting with the possibility of an event being stale.

Let's assume for a moment that when a `create` event is scheduled, the `post_id` is already picked. Now, if that event becomes stale (as it is scheduled at a time when user $u$ is not going to be online), the `post_id` sequence will have gaps, which breaks the power-of-two indexing scheme used by the paginated post storage (see @sec-impl-posts).

Apart from the staleness nuance, the three real and direct consequences this action has are 
1. A post gets created and stores (see @sec-impl-datastructures)
2. The new post gets marked as seen by $u$, as a user cannot be exposed to its own content (see @sec-impl-datastructures)
3. The new post gets marked as interacted by its author $u$, as cannot like nor repost a post authored by itself. (see @sec-impl-datastructures)

Create has two random quantities associated to it, the time between creations (handled by the variable `inter_post_creation`) and the delay simulating how long does a user take to create a post (variable `creation_delay`).

=== Actions

The action source is the fundamental event in the simulation, as is how the actual content diffusion is achieved: the continuous flow of actions represents the current user $u$ checking their timeline. When an event is generated by the simulation, the source will generate another action.

To simulate the user decision making, a Categorical (or a generalized Bernoulli) distribution $pi$ is used. We can define the used distribution with $k=3$ parameters, $p_1, p_2, p_3$ event probabilities and support $x in {"nothing", "repost", "like"}$, with pdf $PP(x=i) = p_i$. The values of $p_i$ are obtained with calibration (see @sec-cal-policy). 

The @proc-action-handle showcases the logic of the dispatch action event, draining the timeline until a non-interacted post surfaces. The visible window is parameterized by $u."session_start"$, so only posts with arrival time $<= u."session_start"$ are reachable. When the window is exhausted, a refresh expands it to $t_c$ (current clock), exposing posts that arrived during the session. Only when the refreshed window is also empty does the user go offline out of boredom (@proc-go-offline).

#procedure(caption: flex-caption([Action event dispatch.], [Action event dispatch with stale-event guard, timeline drain, and refresh]))[
  #pseudocode-list[
    + *procedure* $"HandleActionEvent"(Q: "EventQueue", u: cal(U), t_c: T, a: "Action", e_"gen": bb(N))$
      + $"is_stale" arrow.l e_"gen" != u."session_gen"$
      + *if* "is_stale" or "not" u."is_online" *then*
        + *return*
      + *end*
      + *if* $cal(T)_(u."session_start") (u) != emptyset$ *then*
        + *while* $cal(T)_(u."session_start") (u) != emptyset$ *do*
          + $(t_p, i) arrow.l "pop"(cal(T)(u))$
          + *if* $(u, i) in.not cal(H)(u)$ *then*
            + $"HandleActionOnPost"(Q, u, t_c, a, i)$
            + *return*
          + *end*
        + *end*
        + $u."session_start" arrow.l t_c$ // timeline refresh
      + *end*
      + *if* $cal(T)_(t_c) (u) != emptyset$ *then*
        + // new posts surfaced after refresh, schedule action to consume them
        + $"push"(Q, "eventAction"(u, t_c))$
        + $"generated_events" arrow.l "generated_events" + 1$
      + *else*
        + // truly empty — no content left → boredom
        + $"HandleGoOffline"(Q, u, t_c)$
      + *end*
    + *end*
  ]
] <proc-action-handle>

#procedure(caption: flex-caption([Per-action processing.], [Per-action processing after a non-interacted post is found]))[
  #pseudocode-list[
    + *procedure* $"HandleActionOnPost"(Q: "EventQueue", u: cal(U), t_c: T, a: "Action", i: cal(I))$
      + $"mark" i "as seen by" u$
      + $"impressions" arrow.l "impressions" + 1$
      + *if* a = repost *then*
        + $cal(H)(u) arrow.l cal(H)(u) union {(u, i)}$
        + $"push"(Q, "PropagateEvent"(u, i, t_c))$
        + $"generated_events" arrow.l "generated_events" + 1$
        + $"reposts" arrow.l "reposts" + 1$
      + *else if* a == "like" *then*
        + $cal(H)(u) arrow.l cal(H)(u) union {(u, i)}$
        + $"likes" arrow.l "likes" + 1$
      + *else if* a = ignore *then*
        + $"ignored" arrow.l "ignored" + 1$
      + *end*
      + $"push"(Q, "eventAction"(u, t_c))$
      + $"generated_events" arrow.l "generated_events" + 1$
      + $"processed_events" arrow.l "processed_events" + 1$
    + *end*
  ]
] <proc-action-on-post>

The quantities that control the actions is the time between actions `inter_action_time` and the interaction delay `interaction_delay`, which gets added to the propagation delay for any interaction.


== Simulation Lifecycle
<sec-design-lifecycle>

This section covers the distinct parts the simulation has, and which purpose each one serves. The simulation can be split in three phases: the warm-up (@sec-design-lifecycle-warmup), the initialization (@sec-design-lifecycle-init) and the actual simulation logic (@sec-design-lifecycle-main).

=== Stage One
<sec-design-lifecycle-warmup>

The simulation is divided in two stages, the warm-up and the actual simulation. As the users have to consume posts from their timelines $cal(T)_t (u)$, those must have element. Instead of creating a series of artificial elements, as the topology of the chosen network in itself already provides us with the connections needed to accurately fill those timelines.

The warm-up phase consists of assuming every user is online, and each one starts creating posts with the appropriate parameters per user, but any action can be issued. As the time advances on stage one, timelines get filled following the simulation pre-established dynamics, in a more natural way rather than artificially insert posts to the users without taking into account.

The @proc-stageone shows the pseudocode of stage one, which is a small simulation in itself. The for in line 2 starts the loop of creating events, one scheduled creation per user, giving space to the main loop at line 6. There, the queue $Q$ just contains `create` events, so there is really no need for an check of which type is the event, but it can be seen from lines 10 to 17 that the function is the same that HandleCreate (@proc-create) but using the create warm-up event generate function instead of the standard create.


#procedure(caption: flex-caption([Stage One: warm-up phase.], [Stage One: warm-up phase that fills user timelines with propagated posts before the active simulation begins]))[
  #pseudocode-list[
    + *procedure* $"StageOne"(Q: "EventQueue", t_c: T, t_"warmup": T, "metrics": "SimMetrics")$
      + *for* $u in cal(U)$
        + $"push"(Q, "eventCreateWarmup"(u, t_c))$
        + $"metrics"."generated_events" arrow.l "metrics"."generated_events" + 1$
      + *end*
      + *while* $t_c <= t_"warmup"$ *and* $Q != emptyset$
        + $"event" arrow.l "pop"(Q)$
        + $t_c arrow.l "event"."time"$
        + $u arrow.l "event"."user_id"$
        + $i arrow.l "metrics"."post_count"$
        + $"mark" i "as seen by" u$
        + $"mark" i "as interacted by" u$
        + $"PropagatePost"(u, i, t_c)$
        + $"metrics"."post_count" arrow.l "metrics"."post_count" + 1$
        + $"push"(Q, "eventCreateWarmup"(u, t_c))$
        + $"metrics"."generated_events" arrow.l "metrics"."generated_events" + 1$
        + $"metrics"."processed_events" arrow.l "metrics"."processed_events" + 1$
      + *end*
    + *end*
  ]
] <proc-stageone>

This section of the simulation has different random quantities to control the time it takes and the rate of posts generated.
- `warmup_time` is the $t in T$ the simulation is going to be run until, and we denote it by $t_w$.
- `warmup_post_inter_creation`: time elapsing between posts. It is the same as the `post_inter_creation`, but for warm-up. The decision to split that is to provide the ability to have more (or less) posts than in the full simulation run.

=== Initialization
<sec-design-lifecycle-init>

Every Discrete-Event simulation needs to start its sources, and to do it the first event of each type is added manually to the queue, to kickstart the main loop. That loop will run until $t_c < t_h$. 

If the model was not an activity driven network, this section would not be necessary, as the init would just consist as to generate an `action` and a `creation` event per every user $u in cal(U)$. As this is an activity based network, some fraction of the users have to start offline, and another have to start online. The simulation has the configuration variable `offline_startup_ratio`, which is a number between one and zero, that allows us to determine which fraction of the users start offline. 

The @proc-initsession shows how the users are classified between online and offline by the use of a Uniform random variable (line 3), and if the user is online, generates when the session should end and an event `action`. 

#procedure(caption: flex-caption([Init: assigns initial online/offline state.], [Init: assigns initial online/offline state to every user and primes the event queue]))[
  #pseudocode-list[
    + *procedure* $"Init"(Q: "EventQueue", t_c: T)$
      + *for* $u in cal(U)$
        + $r arrow.l "Uniform"(0, 1)$
        + *if* $r < "offline_ratio"$ *then*
          + $u."is_online" arrow.l "false"$
          + $"push"(Q, "eventSessionStart"(u, t_c))$
          + $"generated_events" arrow.l "generated_events" + 1$
        + *else* 
          + $u."is_online" arrow.l "true"$
          + $"push"(Q, "eventSessionEnd"(u, t_c))$
          + $"push"(Q, "eventAction"(u, t_c))$
          + $"generated_events" arrow.l "generated_events" + 1$
        + *end*
      + *end*
    + *end*
  ]
] <proc-initsession>

Notice also that in the user online branch there is just the `action` event generator (line 11), but not a `create` event generator. That is consequence of the warm-up state: the `create` events are already in $Q$ from the warm-up stage for every user. 

The pseudocode @proc-lifecycle shows the lifecycle of the simulation as a big overview. The topology and the configuration are loaded before starting, that is why they are arguments of the procedure (line 1), but the queue is created inside the procedure, and it's shared by all the subprocedures that have been described so far. To showcase this, the "address-of" operator & has been used (lines 4, 5 and 6), to showcase it's not a copy, but the same queue for all the procedures.

#procedure(caption: flex-caption([Simulation Lifecycle.], [Simulation Lifecycle]))[
  #pseudocode-list[
    + *procedure* Simulation(c: Config, topo: Graph)
      + $Q <- "MinHeap"{}$
      + $t_c <- 0$
      + $"StageOne"(\&Q, c, \&"topo", t_c)$
      + $"Init"(\&Q, c, \&"topo", t_c)$
      + $"MainLoop"(\&Q, c, \&"topo", t_c)$
    + *end*
  ]
  
] <proc-lifecycle>

As $Q$ is shared, the StageOne procedure has generated `create` events for every single user of the simulation, so $Q$ not only already has the creation events for the starting online users, but it also has `create` events for all the users in the simulation. Those are not going to be processed by the `session_gen` mechanism explained in the Session source (see @sec-design-sources-sessions) and an is_online check when popping the event, which can be seen on @proc-mainloop, located at @sec-design-lifecycle-main.

=== Main Loop
<sec-design-lifecycle-main>

The simulation is orchestrated by a single event loop that lasts until the simulation horizon (`horizon` in the configuration or $t_h$) is surpassed by any event. As the simulation is just a combination of the entities and the management of the sources (see @sec-design-entities and @sec-design-sources) this section will focus on the arrangement of those, more than explaining the logic again. 

Once primed, the main loop dispatches each event type — create, session, action, or propagate — to `HandleCreate`, `HandleSessionEvent`, `HandleActionEvent`, or `PropagatePost` respectively, as can be seen in the @proc-mainloop.

#procedure(caption: flex-caption([Simulation: main event loop.], [Simulation: main event loop that dispatches each popped event to its corresponding handler]))[
  #pseudocode-list[
    + *procedure* $"MainLoop"(Q: "*EventQueue", c: "Config", "topo": "Graph", t_c: T )$
      + *while* $t_c <= t_h$ *and* $Q != emptyset$
        + $"event" arrow.l "pop"(Q)$
        + $t_c arrow.l "event"."time"$
        + $u arrow.l "event"."user_id"$
        + $e_"gen" arrow.l "event"."session_gen"$
        + *if* $"event"."type" == "create"$ *then*
          + $"HandleCreate"(Q, u, t_c, e_"gen")$
        + *else if* $"event"."type" == "session"$ *then*
          + $"HandleSessionEvent"(Q, u, t_c, "event"."session", e_"gen")$
        + *else if* $"event"."type" == "action"$ *then*
          + $"HandleActionEvent"(Q, u, t_c, "event"."action", e_"gen")$
        + *else if* $"event"."type" == "propagate"$ *then*
          + $"PropagatePost"(u, "event"."post_id", t_c)$
          + $"processed_events" arrow.l "processed_events" + 1$
        + *end*
      + *end*
    + *end*
  ]
] <proc-mainloop>

== Traces
<sec-design-traces>

Traces are the main objective for the result study of the simulation. Every action performed during the simulation is serialized into structured records ---trace events--- that are written to disk for subsequent analysis. Each trace event is a flat tuple of scalars uniquely identifying the simulation tick, the user who performed the action, the post involved (if any), and the kind of transition executed. There are four distinct trace event types, one for each `EventType` variant described in @sec-design-dm-mechanical, plus the propagation event. All trace events share a common metadata preamble:
- `time`: the continuous simulation timestamp $t$ at which the event was processed.
- `event_id`: a monotonically increasing, global identifier assigned to every event popped from $Q$.
- `gen_id`: the random seed generation identifier used for stochastic decisions in the simulation run.
- `user_id`: the identifier of the user that triggered the action.

Beyond these common fields, each trace variant carries type-specific payload:

- *TraceAction*: Logs an interaction with a post. It records the `post_id` of the post that the user saw in their timeline, along with the `type` of action chosen from the categorical distribution (ignore, like, or repost). This is the most frequent trace event, as it captures the core stochastic decision of the model: given a post in the timeline, what does the user do with it?

- *TraceCreate*: Logs the authorship of a new post. It records the `post_id` assigned to the newly created post. Unlike action events, the creation does not require an action type, as the only outcome is the post entering the system. This trace is emitted whenever a `create` event is popped from $Q$ during a user's online session.

- *TraceSession*:  Logs a change in the user's connectivity state. The `type` field encodes whether the session is starting (user comes online) or ending (user goes offline). These events delimit the activity windows of each user and are essential for reconstructing the timeline visibility windows during analysis.

- *TracePropagation*: Logs the redistribution of a post to the followers of the reposting user. The `type` field stores the `post_id` being propagated, making this trace structurally identical to `TraceCreate` in its payload but semantically distinct: it represents the delayed diffusion step that occurs when a repost action is processed and the propagation delay $tau$ elapses. The separation between action and propagation is what preserves time causality in the simulation (see @sec-design-sources).

By recording every state-transition in this structured format, the trace files provide a complete, auditable log of the simulation's execution. This enables offline reconstruction of user timelines, validation of the CTIC cascades (see @sec-impl-validation), and statistical analysis of the emergent macro-level dynamics without re-running the simulation.

#figure(
  cetz.canvas({
    import cetz.draw: *

    // ── 1. Start Node ──
    rect((-1.8, 0.3), (1.8, 1.7), name: "start", radius: 0.2)
    content("start", [*Start MainLoop*])

    // ── 2. Loop Condition ──
    rect((-2.8, -1.7), (2.8, -0.3), name: "cond")
    content("cond", [$t_c <= t_h$ and $Q != emptyset$])
    
    line("start.south", "cond.north", mark: (end: ">"))

    // ── 3. False Branch (End) ──
    rect((4.6, -1.7), (7.4, -0.3), name: "end", radius: 0.2)
    content("end", [*End \ Simulation*])
    line("cond.east", "end.west", mark: (end: ">"))
    content((3.7, -0.7), text(size: 0.9em)[False])

    // ── 4. True Branch (Pop Event) ──
    rect((-1.8, -3.7), (1.8, -2.3), name: "pop")
    content("pop", [Pop Event from $Q$])
    line("cond.south", "pop.north", mark: (end: ">"))
    content((0.6, -2.0), text(size: 0.9em)[True])

    // ── 5. Event Type Switch ──
    rect((-1.8, -5.7), (1.8, -4.3), name: "dispatch")
    content("dispatch", [*Switch* Event Type])
    line("pop.south", "dispatch.north", mark: (end: ">"))

    // ── 6. Handlers (Row of boxes) ──
    // Width of each box is increased to 3.4 units. 
    // Centers moved outward: X1=-5.7, X2=-1.9, X3=1.9, X4=5.7
    
    rect((-7.4, -7.7), (-4.0, -6.3), name: "h_create")
    content("h_create", [`HandleCreate`])

    rect((-3.6, -7.7), (-0.2, -6.3), name: "h_session")
    content("h_session", [`HandleSessionEvent`])

    rect((0.2, -7.7), (3.6, -6.3), name: "h_action")
    content("h_action", [`HandleActionEvent`])

    rect((4.0, -7.7), (7.4, -6.3), name: "h_propagate")
    content("h_propagate", [`PropagatePost`])

    // ── 7. Dispatch Routing (Orthogonal elbows to handlers) ──
    // Create
    line("dispatch.south", (0, -6.0), (-5.7, -6.0), "h_create.north", mark: (end: ">"))
    content((-3.8, -5.7), text(size: 0.8em)[`create`])

    // Session
    line("dispatch.south", (0, -6.0), (-1.9, -6.0), "h_session.north", mark: (end: ">"))
    content((-0.9, -6.2), text(size: 0.8em)[`session`])

    // Action
    line("dispatch.south", (0, -6.0), (1.9, -6.0), "h_action.north", mark: (end: ">"))
    content((0.9, -6.2), text(size: 0.8em)[`action`])

    // Propagate
    line("dispatch.south", (0, -6.0), (5.7, -6.0), "h_propagate.north", mark: (end: ">"))
    content((3.8, -5.7), text(size: 0.8em)[`propagate`])

    // ── 8. Loop Back Mechanism ──
    // Drop lines from each handler to a common horizontal collector line at Y = -8.7
    line("h_create.south", (-5.7, -8.7))
    line("h_session.south", (-1.9, -8.7))
    line("h_action.south", (1.9, -8.7))
    line("h_propagate.south", (5.7, -8.7))
    
    // Horizontal collector line
    line((-5.7, -8.7), (5.7, -8.7))
    
    // Route from the collector back up to the loop condition
    line((0, -8.7), (0, -9.3), (-8.2, -9.3), (-8.2, -1.0), "cond.west", mark: (end: ">"))
  }),
  caption: [Flowchart of the Main Loop discrete-event dispatching logic.]
) <fig-mainloop-flow>

== Algorithmic Data Structures
<sec-design-datastructures>

This section summarizes the algorithmic reasoning behind each data structure selection, concerning design and performance from a theoretical standpoint, not from which specific implementation can yield those results. That latter performance concern through the implementation is addressed in @sec-impl.

=== Global Event Queue
<sec-design-datastructrues-queue>

The Future Event Set (FES) (referred to until now as $Q$) is the central bottleneck of any discrete-event simulation: every event processed requires one extraction and potentially multiple insertions. 

A Heap @cormen2022algorithms is the traditional data structure to implement a Priority Queue, which is exactly what the FES is. Assuming a binary heap, they have a $O(log n)$ deletion of the minimum and insertion cost, with a $O(n)$ space complexity. This is far better from the naive approach, which would be to keep a list sorted and inserting and deleting the elements. With a list, insertion and deletion would be $O(n)$: finding an element to know where to insert the next one would be a $O(log n)$ to find the index, but all the upper elements of the list have to be shifted by one position, giving an $O(n)$ cost. The same applies when removing the minimum.

On the contrary, the heap uses its tree representation to sift up or sift down the element in the tree branches, making $O(log n)$ operations at most.

==== Estimating the amount of elements in the FES

Analyzing the simulation, a good heuristic can be given to know more or less to what the number of total events at a single time $t$ will be.

An online user will have no more than four events enqueued at any time:
- The next `action`
- The next `creation`
- The `session.end` event.
- A `propagate` after the create or an `action.repost`.

If the user is offline, it will have four events at most:
- A stale `action`
- A stale `creation`
- A stale `propagate`
- The `session.start` event.

Then the relationship of number of element on the queue to the input number of total users $N$ is, at most, $4N$. This is useful to validate the viability of the MinHeap selection, as every operation will require approximately $log_2 (4 N)$ with a million users, we would need, at worst, $log_2 (4·10^6) approx 21.93$ comparisons, still a reasonable number. This approximation is also useful for the implementation, see @sec-impl-datastructures.


=== User Timeline

Each user's timeline $cal(T)(u)$ must maintain posts in reverse-chronological order, supporting both efficient insertion of newly propagated posts and extraction of the most recent one when the user scrolls. This is the same problem as the Future Event Set, but the priority of the queue is the maximum element, not the minimum. So a MaxHeap has the same advantages as explained in @sec-design-datastructrues-queue for the Future Event Set.

Opposite to the Global Queue, the estimation of the timeline amount of events is far more complex, and if were easily described, there would not be need for this simulation. The only optimization regarding a space storage estimation is described in @ sec-impl-timelines.


=== Follower Topology
<sec-design-datastructures-topology>

The Graph data structure is traditionally a performance killer structure, difficult to get right. Luckily, several of the assumptions (see @sec-method-des-assumptions) facilitates the election of the data representation, specifically the non changing users and followers.

As the follower graph is static throughout the simulation, a Compressed Sparse Row structure is perfectly well suited for this simulation, as it is a known fact that social networks users adjacency matrix is sparse. 

A Compressed Sparse Row (CSR) is a data storage technique that represents a matrix $M$ with three different one dimension arrays:
- A row pointer array `row_ptr`, dimension $N+1$ which stores the start index for each row, and `row_ptr[i+1]` marks the end of row i.
- A column index array `col_idx`, which stores every non zero index.
- The actual values of the matrix in a `values` array.

This storage method provides a $O(1)$ range look up and a $O("degree")$ iteration cost.

When representing an adjacency matrix $A$, the `values` array is just full of ones, as it represents the existence of the directed edge, so with just the `row_ptr` and the `col_idx` it is enough. The way this is implemented then is that each user stores only a `start_index` and `end_index` of the followers; iterating over their followers becomes a single slice operation over the global array. Details in @sec-impl-csr.

=== User Storage

The User entity carries both frequently accessed fields (e.g., online status, session generation) and rarely accessed fields (e.g., behavioral policy). Design wise, this structure is nothing but an array of user structs; implementation wise, the "array of structs" paradigm ---the most known due to the prominence of Object-Oriented Programming" is definitely not performance aware in lots of cases. This is approached in @sec-impl-users.

=== Post Storage
<sec-design-datastructrues-post>

Posts are created dynamically throughout the simulation and can be theoretically limitless. Also, any strategy to determine a potential upper bound with the number of users $N$, the distribution of `post_inter_creation` and the $t_h$ duration is information known at runtime ---not at compile time--- so no stack memory structure can be used. 

The problem with using a flat dynamic array are periodic $O(n)$ reallocation costs. A dynamic array needs contiguous memory, and as the number of posts keeps growing, the more contiguous memory needs to be found by the Operating System, and more data needs to be copied to a new location, which for a very common entity such as posts will really hurt performance.

The strategy is to paginate the list into manageable chunks for the computer. Pagination is a memory strategy involving the purposeful segmentation of data into pages to avoid the contiguous memory requirement of arrays. When a page is full, memory for another page is allocated, making OS life easier as there is no need for bigger and bigger contiguous memory blocks, but lots of fixed size blocks.

The specific data structure used is a SegmentedList, also called a Library structure. A library has shelves (the pages from the pagination) and each shelf has books (the contents of the post); when a library is full, another library is created, avoiding all the contiguous memory requirements of a normal list. In other words, a SegmentedList is just a list (dynamic, variable elements) of arrays (static, fixed-size).


The trade-off is that accessing the list is not trivial as the compute of the offset by the operator `[ ]`, as now requires two operations to access the wanted book: in which library is the book and which shelf, which makes this structure slower than a traditional list. In @sec-impl-posts the strategy for indexing is provided.

=== Impression and Seen Tracking 

The simulation needs to keep track of which posts has every user seen or interacted with. As the posts can grow unbounded, also can the interactions from a user to a post. To check a binary relationship from a user to a post, only a bit is needed per post and per user, so assuming a fixed number of posts $M$, we could represent if a user has interacted with a post with the matrix $A$ with dimensions $N times (N times M) = N^2 M$.

If we flatten that matrix into a $N^2 M$, we can represent it with a BitSet. A BitSet is a fixed size collection of bits, which can be manipulated with bit operations. In other words, a BitSet is just a sequence of zeroes and ones.

As posts can grow unbounded, we use the same Pagination strategy from post storage (@sec-design-datastructrues-post) and we generate a PaginatedBitSet, which is a BitSet split in several pages.

The impression matrix tracks which of the $N$ users have seen which of the (unbounded) $M$ posts. A monolithic bitset would require reserving memory for all $N times M$ bits upfront, which is infeasible. A paged bitset allocates memory in fixed-size pages, growing horizontally as new posts are created. The page allocation strategy is covered in @sec-impl-impressions.
