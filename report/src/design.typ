#import "@preview/lovelace:0.3.0": *

#import "utils.typ": procedure, flex-caption //, todo, comment
#import "@preview/cetz:0.4.2"

This chapter covers the design of the simulation: the entities and data model (see @sec-design-entities), the semantics of each event source (see @sec-design-sources), the overall simulation lifecycle (see @sec-design-lifecycle), and the trace schema that captures all state transitions (see @sec-design-traces). For every data structure referenced here, only the algorithmic motivation is provided; the concrete realization, memory layout, and performance considerations are treated separately in @sec-impl.

== Design Overview
<sec-design-overview>

This section aims to give a general description of why the simulation is built the way it is, and how it has been built this way.

=== Experiential Interpretation of the Simulation 
<sec-design-experiential>

The goal of this section is to map the real-world phenomena the simulation attempts to replicate directly to its mechanics, showcasing exactly what the implementation is translating into computational behavior.

In essence, the experience that the simulation models is the behavior of several users checking a social network application to interact with the content on their timelines. To accurately resemble reality, not all users are online at the same time, and they can choose to not engage with content if they decide to do so. All the users in the simulation can choose between two primary actions when checking the timeline: either to create a post (which will be seen by their followers) or to interact with the existing timeline via reposts (which will also propagate to their followers) or likes.

The main two factors to understand about the design of the simulation are also its main mechanics regarding how reality is resembled.

Despite the model covering $N$ different users, an individual user's perspective is entirely isolated from the macroscopic scale of the social network---that is, from the other users. Regardless of the number of users, the subjective experience of scrolling a timeline remains identical. Therefore, any event that the simulation generates and processes is tied to a single user. 

While a larger user base generates a significantly higher volume of global content, the individual's capacity to process and interact with that content remains strictly localized and bounded by human limitations. A good analogy would be that every user is running their own isolated micro-simulation, but they are all merged together globally to allow content to propagate in the network.

The other important mechanic is the decoupling of the users' intent from the content on their timelines. The timeline operates as an independent, autonomous entity that aggregates posts curated by the broader network. When a user decides to open the application and scroll, this underlying intent is completely distinct from the specific posts they will encounter.

In real life, a user logs onto a social platform and decides to engage. However, the specific piece of information they interact with depends entirely on what the network has autonomously surfaced to the top of their feed at that exact moment. They react to this presented content---based on their behavioral policy $pi$--- without prior knowledge of what the content would be. If a user exhausts the available posts in their feed, their session naturally concludes. 

=== Simulation Rules
<sec-design-rules>

While the previous section (@sec-design-experiential) gives a good idea of what is the simulation about, I think the best way to reason about the design is to narrow the simulation down to a series of rules, which define what's possible, what's not allowed and which logic paths can be traced. These are the following:
+ A user can either create a post, or see the timeline.
+ A user can be in two states: online or offline. When a user is offline, it can't perform any action.
+ When a post is reposted, ends up on their follower timelines if the followers have not interacted with it.
+ The only interactions with a post are to like them or to repost them. Ignoring a post is modeled, but does nothing. 
+ A user can't interact (like or repost) with a post already liked and reposted by itself.
+ A user can see a post he has already seen if it get propagated from another user.
+ If an online user finds themselves with an empty timeline, they will change their state to offline.
+ Every propagation introduces a delay between the repost action and the post appearing on followers' timelines.

=== Aims and Objectives

The objective is to build a highly performant Discrete-Event Simulation which guarantees some degree of scalability while keeping itself in a reasonable time-frame execution. While off-the-shelf simulation software can be highly effective for localized queuing networks, evaluating the Continuous-Time Independent Cascade (CTIC) model across a microblogging topology requires simulating millions of highly interconnected nodes over continuous time. To achieve statistical convergence and properly explore the parameter space, the model must be replicated hundreds of times.

Under these constraints, relying on traditional, object-heavy simulation tools would result in less performant and slower executions, as well as the author of this work lack of experience with said software. Therefore, a custom, highly optimized simulation engine was developed from the ground up. To reduce the computational bottleneck of simulating a 1-million-user network to a practically executable timeframe, this custom architecture must explicitly control memory layout and enforce CPU cache locality, minimizing the overhead of stochastic event generation and state evaluation.


== Data Model
<sec-design-entities>

This section describes the entities needed to define the data model of the simulation to properly characterize it.

The aim of this data model is to translate the mathematical rules of the described model with the Time-Varying Heterogeneous Graph (see @sec-model) and the CTIC based model (see @sec-method-model) into concrete logical entities. In a Discrete-Event Simulation, these entities must encapsulate all necessary state variables to evaluate the Activity-Driven dynamics and continuous-time delays at any arbitrary simulation tick.

=== Event & Timeline Event
<sec-design-dm-event>

The fundamental entity of the simulation is the *Event*. It represents a unit of temporal state transition with the elements residing in the global priority queue $Q$. An Event is a composite structure containing the scheduled execution time ($t$), the targeted user, a session validation tracker, and the specific payload (`EventType`) dictating the transition. The type of an event can be a user state-change (`session`), a post creation (`create`), an interaction with a post (`action`), or an information propagation (`propagate`).

These are the same event types described in @sec-method-des-mechanics, but with the extra `propagate`. The reasoning behind introducing the propagate event is to never break time causality, and to delay the propagation to the neighbors as much as possible. If an `action:repost` or a `create` event is processed at $t$, this will generate an event `propagate(i)` and be pushed in $Q$ to be attended at time $t+ tau$ and be propagated when it gets popped from the list $Q$ (see @sec-design-sources-propagate).

The simulation needs to differentiate between what is an event that changes state ---such as the Event entity also described in this section--- and a smaller event to represent the contents of the timelines of a user, the *Timeline Event*. It is a highly specialized, minimalist tuple linking a continuous timestamp $t$ (when did the post arrive) with the `post_id` of the event the user sees. These events are stored in every user timeline $cal(T)_t (u)$, and are treated as the reverse-chronological storage: when a "pop" operation is performed, the event with the maximum time $t$ will be returned; this is the opposite of the main queue $Q$, where a "pop" will return the event with the minimum timestamp.

=== Users & Posts

Users and Posts are the protagonist entities of the simulation, as they are the main actors of it.

A *User* is the logical representation of a node $u in cal(U)$. The entity tracks the dynamic variables necessary to evaluate activity and cognitive bottlenecks, which are:
- `id`: unique identifier.
- `follower_start`: integer offset into the global CSR follower array where this user's follower block begins (see @sec-design-datastructures-topology).
- `is_online`: whether the user is currently in an active session.
- `session_gen`: which session generation the user is currently in. Incremented on each login; used to invalidate stale events from previous sessions. See @sec-method-activity for why this is needed.
- `session_duration`: Pareto-distributed random variable governing how long the user stays online per session.
- `inter_session_time`: Pareto-distributed random variable governing the offline gap between consecutive sessions.
- `inter_creation_time`: Pareto-distributed random variable governing the interval between post creations.
- `num_posts`: how many posts the user has authored so far.
- `session_start_time`: the timestamp at which the current session began; used for analysis and validation.

The *Post* is the logical representation of an item $i in cal(I)$. It requires only a unique, monotonically increasing identifier `id` and a pointer to its author's `author`. This entity remains highly open to new characteristics and features (see @sec-future)

=== Relationships between Entities 

Once all the entities have been described, the data model can be defined by the relationships that link them together. @fig-design-relationships summarizes these structural links; the following paragraphs walk through each one in detail.

#figure(
  cetz.canvas({
    import cetz.draw: *

    // ── User (center) ──
    // Increased radius slightly for breathing room
    circle((0, 2), radius: 0.6, name: "user")
    content("user", [*User*])

    // ── Post (below) ──
    // Widened rectangle
    rect((-1.2, -0.4), (1.2, 0.4), name: "post")
    content("post", [*Post*])
    
    line("user.south", "post.north", mark: (end: ">"))
    // Shifted right to avoid striking through the vertical line
    content((1.0, 1.0), [authors $1:N$])

    // ── Timeline Event (right) ──
    // Widened significantly to fit all 13 characters
    rect((2.4, 1.5), (6.0, 2.5), name: "tle")
    content("tle", [*TimelineEvent*])
    
    line("user.east", "tle.west", mark: (end: ">"))
    // Centered neatly above the horizontal line
    content((1.5, 2.3), [owns $1:1$])
    
    line("tle.south", "post.east", mark: (end: ">"))
    // Offset to the right of the diagonal line
    content((3.0, 0.9), [refs $N:1$])

    // ── Event (left) ──
    // Widened to fit the text comfortably
    rect((-5.5, 1.5), (-3.5, 2.5), name: "event")
    content("event", [*Event*])
    
    line("event.east", "user.west", mark: (end: ">"))
    // Centered neatly above the horizontal line
    content((-2.0, 2.3), [targets $N:1$])

    // ── Event → Post (dashed, optional) ──
    line("event.south", "post.west", stroke: (dash: "dashed"), mark: (end: ">"))
    // Offset to the left of the diagonal line
    content((-3.2, 0.9), [may ref.])

    // ── Topology / CSR (top) ──
    // Widened significantly to fit the longest string in the diagram
    rect((-2.4, 3.5), (2.4, 4.5), name: "csr")
    content("csr", [*Follower graph* (CSR)])
    
    line("csr.south", "user.north", mark: (end: ">"))
    // Shifted right to avoid the vertical line
    content((1.3, 3.0), [$N$:$N$ follows])

    // ── Queue label ──
    // Centered below the event box
    content((-4.5, 1.0), [$Q$])

    // ── Timeline label ──
    // Centered above the timeline box
    content((4.2, 3.0), [$cal(T)(u)$])
  }),
  caption: flex-caption(
    [Entity-Relationship data model.],
    [Entity-Relationship diagram of the simulation data model. A User authors Posts, owns a Timeline of TimelineEvents (each referencing a Post), and is targeted by Events from the global queue $Q$. The follower graph (CSR) stores the $N$:$N$ following relationships between Users. Dashed line indicates an optional reference (action/propagate events may carry a post).]
  )
) <fig-design-relationships>A *User* *authors* a *Post*. The relationship is tracked through the `author` field stored in every post, linking it back to exactly one user. A user may author zero or more posts over their lifetime, but every post has a single author.

A *User* *owns a timeline* composed of *TimelineEvents*. Each user carries a reverse-chronological heap that stores every post arrival scheduled for that user. The timeline is emptied when the user goes offline and repopulated as propagations arrive.

A *TimelineEvent* *references* a *Post* via its `post_id`. A single post may appear in many timelines simultaneously ---one per follower who received it--- each entry tagged with its own arrival timestamp. The reference is unidirectional: a post does not know which timelines contain it.

*Events* are *contained* in the global priority queue $Q$ and carry a `user_id` targeting the *User* whose state will be mutated when the event is extracted. Beyond this containment and the user target, events hold no further structural relationship with the other entities ---the effect of each event is dictated by its `EventType` payload and belongs to the processing logic (see @sec-design-sources), not to the data model.

These relationships are entirely static. The data model describes what can be stored and how it connects, not when or why those connections are created. The dynamics — who sees a post, when a session starts, what action a user takes — belong to the event processing logic (see @sec-design-sources) and are not part of the data model itself.

== Event Sources 
<sec-design-sources> 

This section describes the implementation strategies of the different sources of the simulation provided in @sec-design-dm-event, and which logic follows the simulation when an event gets processed according to the rules of the simulation (@sec-design-rules).

=== Propagate
<sec-design-sources-propagate>

The first event we must cover is the only event that does not correspond to any physical event: the `propagate` event.

Refreshing the CTIC model (see @sec-sota-diffusion-ctic and @sec-method-model), there is a strong emphasis in the incubation time for the infection: "the delay between a node $j$ becoming infected at time $t_j$ and subsequently infecting an uninfected neighbor $i$ at time $t_i > t_j$" which not only serves the purpose of modeling reality, but that delay helps the model not being degenerated.

==== Example

Consider a minimal microblogging network of three users forming a directed cycle:

#figure(
  cetz.canvas({
    import cetz.draw: *

    // ── Nodes (Users) ──
    circle((0, 2), radius: 0.4, name: "A", stroke: blue)
    content("A", [*A*])

    circle((-1.5, -0.5), radius: 0.4, name: "B", stroke: green)
    content("B", [*B*])

    circle((1.5, -0.5), radius: 0.4, name: "C", stroke: red)
    content("C", [*C*])

    // ── Edges (Out-Neighbors / Following) ──
    // A follows B
    line("A", "B", name: "a-b", mark: (end: ">", fill: black))
    // We can place the label roughly halfway along the line
    content((-1.0, 1.0), text(size: 0.8em, gray)[follows])

    // B follows C
    line("B", "C", name: "b-c", mark: (end: ">", fill: black))
    content((0, -0.8), text(size: 0.8em, gray)[follows])

    // C follows A
    line("C", "A", name: "c-a", mark: (end: ">", fill: black))
    content((1.0, 1.0), text(size: 0.8em, gray)[follows])
    
    // ── Optional: Show Propagation (In-Neighbors) ──
    // If you want to visually show propagation happening in reverse, 
    // you could add dashed lines flowing the opposite way:
    // line("B", "A", stroke: (dash: "dashed", paint: blue), mark: (end: ">", fill: blue))
    // content((-0.4, 0.4), text(size: 0.7em, blue)[propagation])
  }),
  caption: [
    Simple user network $cal(U) = {A, B, C}$. Arrows represent out-neighbor (following) relationships, forming a continuous cycle. Propagation naturally flows in reverse along the in-neighbor edges.
  ]
) <fig-simple-graph>

$ cal(U) = {A, B, C} $

$ cal(N)_"out" (A) = {B}, quad cal(N)_"out" (B) = {C}, quad cal(N)_"out" (C) = {A} $

Thus the follower (in-neighbor) sets ---the targets of propagation--- are:

$ cal(N)_"in" (A) = {C}, quad cal(N)_"in" (B) = {A}, quad cal(N)_"in" (C) = {B} $

Assume all three users are permanently online ($cal(O)(u) = T quad forall u in cal(U)$), and let user $A$ start a cascade by creating a post $p_0$ at $t = 0$. We trace the simulation under two regimes.

==== Without propagation delay ($Delta_p = 0$)

At creation time, the post is delivered directly to the creator's followers at the same timestamp:

1. $t = 0: quad Q = [(A, "create", 0)]$ Pop: $A$ creates $p_0$. Propagation fires over $cal(N)_"in" (A) = {C}$, scheduling an action event for $C$ at $t=0$:

$ Q = [(C, "action", 0)] $

2. $t = 0: quad$ Pop $(C, "action", 0)$. $C$ inspects $p_0$ in $cal(T)_0 (C)$ and, per policy $pi$, reposts. Propagation fires over $cal(N)_"in" (C) = {B}$:

$ Q = [(B, "action", 0)] $

3. $t = 0: quad$ Pop $(B, "action", 0)$. $B$ reposts $p_0$. Propagation over $cal(N)_"in" (B) = {A}$:

$ Q = [(A, "action", 0)] $

In a single instant $t=0$, three cascading actions have taken place. The post traverses the entire network without any notion of temporal distance: creation has the same timestamp as the last cascaded action. This degeneracy collapses any incremental diffusion process into an instantaneous event, and renders the queue $Q$ useless as a scheduling mechanism.

==== With propagation delay ($Delta_p > 0$)

Rather than delivering posts directly, the creation event pushes a propagate event into the future for each follower, at $t_c + Delta_p$:

1. $t = 0: quad Q = [(A, "create", 0)]$ Pop: $A$ creates $p_0$. For each $v in cal(N)_"in"(A) = {C}$, schedule propagation at $0 + Delta_p$:

$ Q = [(C, "propagate", Delta_p)] $

2. $t = Delta_p: quad$ Pop $(C, "propagate", Delta_p)$. $p_0$ arrives in $cal(T)_(Delta_p)(C)$. $C$ inspects it and reposts. Propagation for $C$'s followers at $Delta_p + Delta_p$:

$ Q = [(B, "propagate", 2Delta_p)] $

3. $t = 2Delta_p: quad$ Pop $(B, "propagate", 2Delta_p)$. $p_0$ appears in $cal(T)_(2Delta_p)(B)$. $B$ reposts:

$ Q = [(A, "propagate", 3Delta_p)] $

4. $t = 3Delta_p: quad$ Pop $(A, "propagate", 3Delta_p)$. $p_0$ lands in $A$'s timeline. Since $A$ created $p_0$, the already-interacted check $(A, p_0) in cal(H)_(3Delta_p)(A)$ prevents re-exposure. The cascade ends.

Each hop now costs $Delta_p$ units of time. The cascade unfolds as a genuine temporal process, with every user action tied to a distinct timestamp. The queue $Q$ regains its role as a proper temporal scheduler, and the resulting cascade graph reflects the incubation time that is central to the CTIC model (see @sec-sota-diffusion-ctic).

As it can be seen in the example, a delay is not a luxury, but a necessity for the model to not degenerate. Following DES best practices, instead of modifying the timelines of the user directly with the added delay, we create a `propagate` event, which will make the posts appear to the users timelines at $t + Delta_p$, when it's properly popped from the queue $Q$ and processed as an actual event.

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

When a propagate event reaches the head of $Q$, the main event loop dispatches it to the handler below, as can be seen in @proc-propagate-switch. So, propagation event is not technically a source, but a result of any propagation of posts needed.

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

The second event of the simulation are technically two events, but they behave complementary. A `session` event can be either one of the following: either `start` or `end`. The `start` forces a user back online, and the `end` makes it go back offline.

==== Going Online

When the simulation processes the event `online` for an offline user $u$, it has to start the whole simulation again. To do that, it needs to create an `action` event to start checking the timeline, and a `create` event, both according to their distributions, so the characteristic loop of DES can start with both of the real sources. Additionally, this also appends a session event with `end` payload, as the session needs to end eventually.

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

There are two ways for a user to go offline: by the simulation processing the event `end` or by running out of posts in the timeline $cal(T)_t (u) = emptyset$.

If an `end` event is processed, the user is marked as offline, and the new session `start` event gets scheduled, as the @ pseudocode shows 

If the user timeline is empty, it's interpreted as the user seeing posts it has already seen, so logs off the platform. It still does the same as going offline normally.

#procedure(caption: flex-caption([Session end: marks the user offline.], [Session end: marks the user offline, clears the timeline, and schedules the next session]))[
  #pseudocode-list[
    + *procedure* $"HandleGoOffline"(Q: "EventQueue", t: T, u: cal(U))$
      + $u."is_online" arrow.l "false"$
      + $"push"(Q, "eventSessionStart"(u, t))$
      + $cal(T)(u) <- emptyset$
    + *end*
  ]
] <proc-go-offline>

Both of this options are nested under a check when the event type is a `session`, shown in the @proc-session-handle:


#procedure(caption: flex-caption([Session handle.], [Session handle]))[
  #pseudocode-list[
    + *procedure* $"HandleSession"(Q: "EventQueue", u: cal(U), t_c: T, s: "Session")$
      + *if* s == start *then*
        + $"HandleGoOnline"(Q, u, t_c)$
      + *else if* s == end *then* 
        + $"HandleGoOffline"(Q, u, t_c)$
      + *end*
    + *end*
  ]
] <proc-session-handle>

==== Event Management when User is Online

To implement an activity based behavior, the concept of session had to be introduced in the model (see @sec-model-sessions), and while being very natural to implement, there are some potential contradictions with how the events are scheduled.

The introduction of sessions introduces several operational challenges to the discrete event simulation, specifically regarding the interruption of stochastic processes. Time between actions and creations are measured *within a session* rather than globally. 

Because DES relies on uninterrupted renewal processes to sample probability distributions correctly, pausing a user's activity when they go offline can mathematically invalidate the process. When a session ends mid-renewal, events that were scheduled to occur at a future time (sampled from, e.g., the inter-action distribution) remain in the queue—yet the user's timeline has been cleared and the session context destroyed. If those orphaned events were allowed to execute in a later session, the inter-action times would no longer follow the intended distribution: some would be effectively truncated by the offline interval, others would be shifted across session boundaries.

In @sec-method-des-mechanics it is explicitly stated that there are four types of events, and the session of a user $u$ is managed by an event $(u, t_1, "session.start")$ and $(u, t_2, "session.end")$. Let's showcase the potential problem with the following example.

The queue initially holds a single event:

$ Q = [(u, "session.end", 3)] $

1. $"pop"(Q) arrow.r (u, "session.end", 3)$. $t = 3$. $u$ is online.
   $"HandleGoOffline"$: $u$ goes offline, $"session.start"$ is scheduled at $t = 5$.

$ Q = [(u, "session.start", 5)] $

2. $"pop"(Q) arrow.r (u, "session.start", 5)$. $t = 5$. $u$ is offline.
   $"HandleGoOnline"$: $u$ goes online. Three events are queued for this session: $"session.end"$ at $t = 12$, $"action"$ at $t = 13$, $"create"$ at $t = 14$.

$ Q = [(u, "action", 6), (u, "create", 8), (u, "session.end", 12)] $

3. $"pop"(Q) arrow.r (u, "action", 6)$. $t = 6$. $u$ is online. The user acts over a post of its timeline, we skip the details as they are not relevant for the example, but another action is scheduled to keep the simulation loop running at $t=13$.

$ Q = [(u, "create", 8), (u, "session.end", 12), (u, "action", 13)] $

4. $"pop"(Q) arrow.r (u, "create", 8)$. $t = 8$. $u$ is online. A post gets created, it will get propagated at $8 + Delta_p$, and another creation gets scheduled at $t=14$.


$ Q = [(u, i, "propagate", 9), (u, "session.end", 12), (u, "action", 13), (u, "create", 14)] $

5. $"pop"(Q) arrow.r (u, "propagate", 9)$. $t = 14$. $u$ is online, and the post gets propagated and removed from the queue.

6. $"pop"(Q) arrow.r (u, "session.end", 12)$. $t = 12$. $u$ is online, but it gets marked as offline, and a new session start is scheduled at $t=16$.

$ Q = [(u, "action", 13), (u, "create", 14), (u, "session.start", 16)] $

Now, the problem becomes obvious. The next pop will process the action at $t=13$, but user $u$ is not online at that moment $13 in.not cal(O)(u)$, so the simulation cannot process either of $(u, "action", 13), (u, "create", 14)$. The naive solution would be to implement a procedure called after every go to online to just eliminate all the events between the time the user goes offline $t_e$ and the time it comes back online $t_s$ but this implies reallocating and copying large portions of the event queue on every session boundary (see @sec-impl-memory), so what is done instead is to count the amount of sessions the user has had so far and establish the following rule: an event can just be processed by the simulation if the session it has been generated is the same as the user current session.

The mechanism assigns a number to every session, and the user keeps track of how many sessions he has been active so far. Now, whenever any event is popped from the $Q$, the simulation will check the `session_gen` id. If they coincide with `user_session_id`, it will get processed, if not, it will get discarded.

Let's rerun the example with an added element to the event tuples, representing the session the user has been in so far. The queue initially holds a single event:

$ Q = [(u, "session.end", 3, 0)] $

1. $"pop"(Q) arrow.r (u, "session.end", 3, 0)$. $t = 3$. $u$ is online.
   $"HandleGoOffline"$: $u$ goes offline, $"session.start"$ is scheduled at $t = 5$, and user session id augments by one.

$ Q = [(u, "session.start", 5, 1)] $

2. $"pop"(Q) arrow.r (u, "session.start", 5)$. $t = 5$. $u$ is offline.
   $"HandleGoOnline"$: $u$ goes online. Three events are queued for this session: $"session.end"$ at $t = 12$, $"action"$ at $t = 13$, $"create"$ at $t = 14$. They all belong to `session_gen` 1 

$ Q = [(u, "action", 6, 1), (u, "create", 8, 1), (u, "session.end", 12, 1)] $


3. $"pop"(Q) arrow.r (u, "action", 6, 1)$. $t = 6$. $u$ is online. The user acts over a post of its timeline, we skip the details as they are not relevant for the example, but another action is scheduled to keep the simulation loop running at $t=13$. This new event will have the current `session_id` the user finds himself in, so $1$.

$ Q = [(u, "create", 8, 1), (u, "session.end", 12, 1), (u, "action", 13, 1), ] $

For the sake of brevity, we will skip two pops from the past example, until the queue looks as 

$ Q = [(u, "session.end", 12, 1), (u, "action", 13, 1), (u, "create", 14, 1)] $

5. $"pop"(Q) arrow.r (u, "session.end", 12, 1)$. $t = 12$. $u$ is online, but it gets marked as offline, the `user_session` augments by 1, and a new session start is scheduled at $t=16$.

$ Q = [(u, "action", 13, 1), (u, "create", 14, 1), (u, "session.start", 16, 2)] $

6. $"pop"(Q) arrow.r (u, "action", 13, 1)$. Current time $t=13$, user is offline and `user_session_id` is 2. Before processing the event, the `session_gen` from the event is 1, but the `user_session_id` is 2, therefore the event does not get processed, and it gets dropped. The same will happen with the create event, but not with the session.start event, as has the same, so it will keep the loop running. From now on, an event that can't be processed will be called a stale event.

Knowing that the mechanism exists, the @proc-session-event-handle shows the whole process, while calling the previous showcased procedures. $e_"gen"$ is the `session_gen` of the current event, which we already know it's a session

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

The two variables that control the time between sessions and the session length are `time_between_sessions` and `session_duration`.

=== Create

The `create` event behaves as a more traditional source of events, as it does not have relationships with other event sources or events. When a `create` event is assigned, the simulation searches the last `post_id`, augments it and makes the current user $u$ its author. The @proc-create showcases the event.

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

A noticeable fact is that the `create` type does not contain any payload, as the user that creates it is at that point information known by the program and the `post_id` will be selected if the event is created. Preselecting which `post_id` would the post have when the create event is scheduled is, again, the naive approach, but breaks when interacting with the possibility of an event being stale.

Let's assume for a moment that when a `create` event is scheduled, the `post_id` is already picked. Now, if that event becomes stale (as it is scheduled at a time when user $u$ is not going to be online), the `post_id` sequence will have gaps, which breaks the power-of-two indexing scheme used by the paginated post storage (see @sec-impl-posts).

Apart from the staleness nuance, the three real and direct consequences this action has are 
1. A post gets created and stores (see @sec-impl-datastructures)
2. The new post gets marked as seen by $u$, as a user cannot be exposed to its own content (see @sec-impl-datastructures)
3. The new post gets marked as interacted by its author $u$, as cannot like nor repost a post authored by itself. (see @sec-impl-datastructures)

Create has two random quantities associated to it, the time between creations (handled by the variable `inter_post_creation`) and the delay simulating how long does a user take to create a post (variable `creation_delay`).

=== Actions

The action source is the fundamental event in the simulation, as is how the actual content diffusion is achieved: the continuous flow of actions represents the current user $u$ checking their timeline. When an event is generated by the simulation, the source will generate another action.

To simulate the user decision making, a Categorical (or a generalized Bernoulli) distribution $pi$ is used. We can define the used distribution with $k=3$ parameters, $p_1, p_2, p_3$ event probabilities and support $x in {"nothing", "repost", "like"}$, with pdf $PP(x=i) = p_i$. The values of $p_i$ are obtained with calibration (see @sec-cal-policy). 

The @proc-action-handle showcases the logic of the dispatch action event, draining the timeline until a non-interacted post surfaces. When a fresh post is found, processing delegates to @proc-action-on-post; when the timeline is exhausted, the user is forced offline via @proc-go-offline, described in @sec-design-sources-sessions.

#procedure(caption: flex-caption([Action event dispatch.], [Action event dispatch with stale-event guard and timeline drain]))[
  #pseudocode-list[
    + *procedure* $"HandleActionEvent"(Q: "EventQueue", u: cal(U), t_c: T, a: "Action", e_"gen": bb(N))$
      + $"is_stale" arrow.l e_"gen" != u."session_gen"$
      + *if* "is_stale" or "not" u."is_online" *then*
        + *return*
      + *end*
      + *if* $cal(T)_(t_c) (u) != emptyset$ *then*
        + *while* $cal(T)_(t_c) (u) != emptyset$ *do*
          + $(t_p, i) arrow.l "pop"(cal(T)(u))$
          + *if* $(u, i) in.not cal(H)(u)$ *then*
            + $"HandleActionOnPost"(Q, u, t_c, a, i)$
            + *return*
          + *end*
        + *end*
      + *else*
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

Traces are the main objective for the result study of the simulation. Every action performed during the simulation is serialized into structured records ---trace events--- that are written to disk for subsequent analysis. Each trace event is a flat tuple of scalars uniquely identifying the simulation tick, the user who performed the action, the post involved (if any), and the kind of transition executed. There are four distinct trace event types, one for each `EventType` variant described in @sec-design-dm-event, plus the propagation event. All trace events share a common metadata preamble:
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
