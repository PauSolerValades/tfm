#import "@preview/lovelace:0.3.0": *

#import "utils.typ": todo, comment

This chapter covers the design decisions and implementation sensibilities to build the simulation. It starts with an overview of the general flux of the program (see @sec-design-overview); the following sections focus on the design of the implementation: entities and a description of the data model (see @sec-design-entities), a specific description of the parts that conform the simulation (see @sec-design-lifecycle), what every event processing and creation implies to the simulation (see @sec-design-mechanics) and how time causality is mantained through the simulation. The second part of the chapter focuses on implementation aspects, such which data structures have been used for every rellevant part of the simulation (see @sec-design-datastructures) and the description and application of Data-Oriented-Design #todo[need a good font for this one, probably fabians game developement book?] to handle cache locality, memory allocation strategies and dynamic dispatch.

== Design Overview
<sec-design-overview>

This section aims to give a general description of why the simulation is built the way it is, and how it has been build this way.

=== Aims and Objectives

The primary objective of this computational architecture is to overcome the severe scalability limits inherent in general-purpose Discrete-Event Simulation (DES) packages. While off-the-shelf simulation software is highly effective for localized queuing networks, evaluating the Continuous-Time Independent Cascade (CTIC) model across a microblogging topology requires simulating millions of highly interconnected nodes over continuous time. To achieve statistical convergence and properly explore the parameter space, the model must be replicated hundreds of times.

Under these constraints, relying on traditional, object-heavy simulation tools would result in computationally intractable wall-clock execution times. Therefore, a custom, highly optimized simulation engine was developed from the ground up. The engine is implemented in Zig @zig, a modern systems programming language selected specifically for its deterministic memory management and seamless support for Data-Oriented Design (DOD) (see @sec-design-overview-techology and @ sec-design-implementation). By explicitly controlling memory layout and enforcing CPU cache locality, the architecture minimizes the overhead of stochastic event generation and state evaluation, reducing the computational bottleneck of simulating a 10-million-user network to a practically executable timeframe.

=== Architecture 
<sec-design-architecture>

The simulation engine operates as a centralized Discrete-Event Simulation, where the global flow of continuous time is strictly dictated by a centralized priority queue $Q$. To fully grasp how the theoretical model (see @sec-method-model) is operationalized, it is necessary to understand the holistic lifecycle of the program from initialization to termination.

A single execution of the simulation follows a strict three-phase lifecycle (see @sec-design-lifecycle for a more extensive description): 1) loads the topological graph of the social network into memory, in a format adequate for the simulation to check which users follows who. Then, 2) the simulation runs a warm-up phase to fill user timelines deactivating all other events, as it does not produce degenerate behaviour on starting. Lastly 3) the main event loop starts, where the engine extracts the event with the smallest temporal timestamp from the future event set ($"pop"(Q)$), advanced the clock of the simulation to that instant, processes the state transition, and schedules future events of the same time. This loop runs until the event horizon is exhausted.  

The simulation emulates a user seeing their timeline, which is translated with the following two facts:
1. independence of users within the event loop.
2. independence of the actions 

A worth remarking architectural distinction within the event loop is the strict independence of the user actors and the abstraction of their actions. In the theoretical model, a user interacts with a specific post. However, within the simulation engine, an `action` event scheduled in $Q$ is entirely "blind" to the content. 

When an `action` event fires for user $u$, it merely signals the user's cognitive availability to consume information. The engine then inspects the user's independent, localized timeline queue. If the timeline is populated, the user extracts the most recent post and applies their reactive behavioral policy ($pi_"act"$)—choosing to ignore, like, or repost it. 

This decoupled design tries to mimics human behavior on microblogging platforms: a user logs online and decides to scroll (the event), but what they actually interact with is entirely dependent on what the network has autonomously deposited at the top of their feed at that specific millisecond. If the timeline is empty when the `action` event fires, the user ends their session, as all the content it can see has been consumed.

=== Technology Approach
<sec-design-overview-techology>
Because the validity of a DES relies entirely on sheer computational volume and repeated runs to achieve statistical significance, a suboptimal implementation can easily contradict the underlying assumptions needed to guarantee a successful process. Execution speed, deterministic behavior, and tightly optimized computational loops are paramount. 

The first step in implementation is choosing the appropriate tools for the job. Interpreted languages like Python and R are immediately discarded; even on powerful hardware, the overhead of interpretation introduces unacceptable latency for massive, CPU-bound simulation loops. Following this logic, manual memory management becomes necessary to deeply optimize performance and take full advantage of CPU caching. This requirement effectively rules out garbage-collected languages such as Java or Go, which cannot guarantee the deterministic, low-latency execution and exact memory layout control required here. With requirements pointing strictly toward a systems language with manual memory management, the choice of Zig was clear.

Zig is a general-purpose programming language and toolchain designed for maintaining robust, optimal, and reusable software. By design, it provides C-like performance alongside modern quality-of-life improvements and strict guardrails against common C pitfalls, such as segmentation faults and null pointer dereferences. With the application of the right memory optimization techniques (see [TODO: @ sec-des-hpc]), Zig enables highly scalable implementations that extract the maximum possible performance from the hardware.

== Data Model
<sec-design-entities>

In this section we describe all the entities needed to define the data model of the program, and characterize it.

The aim of this data model is to translate the mathematical rules of the described model with the Time-Varying Heterogeneous Graph (see @sec-model) and the CTIC (see @sec-method-model) into concrete logical entities. In a Discrete-Event Simulation, these entities must encapsulate all necessary state variables to evaluate the Activity-Driven dynamics and continuous-time delays at any arbitrary simulation tick.

We define the core stateful entities as follows:

- *Event*: The fundamental unit of temporal state transition, representing the elements residing in the global priority queue $Q$. An Event is a composite structure containing the scheduled execution time ($t$), the targeted user, a session validation tracker, and the specific payload (`EventType`) dictating the transition: a state-change (`session`), a generative action (`create`), a reactive action (`action`), or a delayed network diffusion (`propagate`).
- *Timeline Event*: A highly specialized, minimalist tuple linking a continuous timestamp to a `post_id`. This is the exclusive entity stored within a user's localized Max-Heap timeline, stripping away all global event metadata to strictly represent the chronological arrival $t_a$ required to resolve the reverse-chronological queueing delay.


=== Users & Posts

Users and Posts are the fundamental entities of the simulation, as they are the main actors of it.

*User*

The logical representation of a node $u in cal(U)$. The User entity tracks the dynamic variables necessary to evaluate activity and cognitive bottlenecks, which are
- `id`: to identify itself from other users.
- `followers`: list of `id`s of other users that the user follows.
- `policy`: the categorical distribution for choosing an action (see #todo[categorical]). Despite the homogeneity of users assumption for simplification pourposes (@sec-method-des-assumptions), every user still has it's policy defines, but it's the same for everyone.
- `num_posts`: how many posts the user has authored so far.
- `max_posts`: maximum amount of the posts the user can author. If might be infinite.
- `online_status`: if it's online or offline.
- `session_gen`: in which session is the user in. See #todo[section about activity driven far in the future] to see why this is needed.
- `timeline`: contains which posts are in the user timeline at time $t$ #todo[citar la secció on parlo de la timeline?]
*Post* 

The logical representation of an item $i in cal(I)$. As an immutable information commodity, the Post is deliberately simple, requiring only a unique, monotonically increasing identifier `id` and a pointer to its author's `author`.


=== Events & EventType

The second most important entity in the simulation are the events, which are the ones on the queue $Q$. An *Event* contains
- `time` of creation of the event.
- `type` of the event, described in the lower paragraph.
- `user_id` which this event applies.
- `session_gen` in which the event has been generated.
- `id` of the event, which is the order in which the events are created.

The `type` of the event have been described in @sec-method-des-mechanics, but not exhaustively if we take the implementation as the reference. Specifically, there is another event called `propagate` when a post has to be propagated, it will always need to be done in the future. The following list describes the types according to the information they hold inside the `Event`
- `create`: it contains no payload, will just generate a post with a non used id (`id = id_last_post + 1`).
- `session`: contains the payload `start` or `end` enum, according to what user session has to do.
- `action`: contains the payload `nothing`, `like` or `repost` enum, knowing which action should the user make with next post.
- `propagate`: contains the `post_id` to be propagated as payload.

The reasoning behind introducing the propagate event is to never break time causality, and to delay the propagation to the neighbors as much as possible. If an `action:repost` or a `create` event is processed at $t$, this will generate an event `propagate(i)` and be pushed in $Q$ to be attended at time $t+ tau$ and be propagated when it gets popped from the list $Q$.

=== Timelines

To satisfy the reverse-chronological consumption constraint, the timeline associated to every user is modeled as a Max Heap. This ensures that the element with the largest timestamp is always returned first. This structure must be carefully managed to prevent unbound memory growth, which is why timelines are explicitly cleared when a user logs off.

=== Traces

=== Data Model
=== SimConfig & Metrics

== Simulation Lifecycle
<sec-design-lifecycle>

#comment[I dont know if this will be actually three sections, as the idea is very simple to explain, and maybe they end up very short]

*Warm-up*: nothing but post creations, to ensure when the simulations starts there are posts in everyuser timelines.

*Session init*: who starts online/offline plus event initialization

*main loop*: the metrics start to compute here, nowhere else.

The simulation relies on four main routines to govern the discrete event generation. `PropagatePost` handles the spreading of an item to followers. `StageOne` generates the initial state (the warm-up phase) to fill timelines before active simulation. `InitSessions` assigns the initial online/offline states based on a random proportion. Finally, `Simulation` executes the core loop.

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
+ *procedure* $"Simulation"$
  + $t_c, Q, cal(S) <- 0.0, emptyset, emptyset$
  + $"StageOne"()$
  + $"InitSessions"()$
  + *for* $u in cal(U)$ *where* $"online"(u) == "true"$
    + $"push"(Q, "gen_action"(u, t_c))$
  + *end*
  + *while* $t_c <= t_h$ *and* $Q != emptyset$
    + $"event" <- "pop"(Q)$
    + $t_c, u <- "event"."time", "event"."user"$
    + $"isEventStale" = "event"."session_gen" != u."session_gen" $ 
    + *if* $"isEventStale"$ *then* *continue* *end* 
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
          + *continue* 
        + *end*
        + $cal(S) <- cal(S) union \{(u, i)\}$
        + *if* $"event"."action" == "repost"$ *then*
          + $"PropagatePost"(u, i, t_c)$
        + *end*
        + $"push"(Q, "gen_action"(u, t_c))$
      + *else* 
        + $"online"(u) <- "false"$
        + $"session_gen"(u) <- "session_gen"(u) + 1$
        + $"push"(Q, "gen_session_start"(u, t_c))$
      + *end*
    + *end*
  + *end*
+ *end*
]

== Event Mechanics
<sec-design-mechanics> 

This section describes the implementation strategies of the different mechanics of the simulation provided in @sec-method-des-mechanics.

=== Create

A new id is generated, gets appended in the paginated bit set and the library array (cite the data structures sections)

=== Sessions

To implement an activity based behaviour, the concept of session had to be introduced in the model (see @sec-model-sessions), and while being very natural to implement, there are some potential contradictions with how the events are scheduled.

In @sec-method-des-mechanics it is explicitly stated that there are four types of events, and the session of a user $u$ is managed by an event $(u, t_1, "go_offline")$ and $(u, t_2, "go_online")$. Let's showcase the potential problem with the following example.

Lets assume a simulation with $Q$ in the following state at $t_c=0$ 

$ Q = {(u, 2, "create"), (u, 5, "go_offline")} $

When the first event is processed with $"pop"(Q)$, a post gets created, and the delay


The introduction of sessions introduces several operational challenges to the discrete event simulation, specifically regarding the interruption of stochastic processes. Time between actions and creations are measured *within a session* rather than globally. 

Because DES relies on uninterrupted renewal processes to sample probability distributions correctly, pausing a user's activity when they go offline can mathematically invalidate the process. When a session ends mid-renewal, events that were scheduled to occur at a future time (sampled from, e.g., the inter-action distribution) remain in the queue—yet the user's timeline has been cleared and the session context destroyed. If those orphaned events were allowed to execute in a later session, the inter-action times would no longer follow the intended distribution: some would be effectively truncated by the offline interval, others would be shifted across session boundaries. A goodness-of-fit test would therefore fail, as the process would no longer be an uninterrupted renewal.

To make this concrete, consider a scenario where the inter-session interval is inadequately short relative to the inter-action time. Let user $u$ start online at $t = 0$. The simulation queues three events for this session: an action $e_"act"$ at $t = 8$ (sampled from a long-tailed inter-action distribution), a session end at $t = 3$ (the session duration being, by configuration, far shorter than the typical action gap), and a post creation at $t = 12$.

At $t = 3$, the session end fires: $u$ goes offline, $cal(T)(u)$ is cleared, and a session start is scheduled at $t = 5$—the offline interval lasts only 2 time units, a short draw from the inter-session distribution. At $t = 5$, the session start fires: a fresh batch of events is generated (a new action at $t = 13$, a new session end at $t = 7$, a creation at $t = 15$, etc.). 

At $t = 8$, the original action $e_"act"$—still sitting in $Q$—pops from the queue. The simulation blindly processes it: $u$ is online, so it attempts to act upon $cal(T)(u)$. However, the timeline was nuked at $t = 3$ and the posts it contained belonged to a previous session that is now gone. If $cal(T)(u)$ is empty, the simulation crashes or forces an early log-off. If posts happen to have accumulated from the new session, $u$ acts on them—but the inter-action time that was sampled as part of session 0's renewal process is now attributed to session 1, silently corrupting the calibrated distribution.

This is the core problem: events from a finished session survive in the queue and leak into future sessions, breaking the renewal process. To circumvent this, the simulation associates a `session_gen` identifier to each user. Whenever a user goes offline and starts a new session, their `session_gen` counter increments. Every event scheduled during a session is stamped with the `session_gen` value active at scheduling time.

When the simulation pops an event from the central queue, it first checks whether the session in which the event was generated is different from the one the user is currently in (`event.session_gen != user.session_gen`). If this condition holds true, the event is considered *stale* (originating from a previous session that was interrupted) and is safely discarded.

Revisiting the example with the `session_gen` guard in place: at $t = 0$ user $u$ starts with $"session_gen" = 0$, and all scheduled events carry this stamp. At $t = 5$, when the session start fires, $"session_gen" (u)$ increments to $1$. At $t = 8$, when $e_"act"$ pops, its stamp ($0$) no longer matches $u$'s counter ($1$). The mismatch is detected immediately and the stale event is discarded—the renewal process in session 1 remains pristine.

=== Actions

To simulate the user decision making, a Categorical (or a generalized Bernoulli) distribution $pi$, with parameters $k=3, p_1, p_2, p_3$ event probabilities and support $x in {"nothing", "repost", "like"}$, with pdf $PP(x=i) = p_i$. The values of $p_i$ are obtained with calibration (see #todo[@ sec-data-cal]).

The implementation of this distribution can be found in the `distributions` @soler2025distributions library, and the algorithm has been discussed already in @sec-method-rng-categorical.

=== Propagate

#pseudocode-list[
+ *procedure* $"PropagatePost"(u, i, t_c)$
  + *for* $v in cal(N)_"out"(u)$
    + *if* $(v, i) in.not cal(S)$ *then*
      + $"push"(cal(T)(v), "gen_arrival"(i, t_c))$
    + *end*
  + *end*
+ *end*
]

== Time Causality

This contin all the examples to showcase potential (and avoided) pitfalls.

=== Delays and Propagate Event

Delays are a fundamental part of the model and of the CTIC framework, but the propagation delay is also needed to avoid the following pitfall in the simulation.

Let's assume a simulation with three users, $cal(U) = {A, B, C}$, and they follow each other in this way:

#todo[make an actual nice picture or something]

$
A --> B \
B --> C \
C --> A 
$

Now, let's say that the state of $Q$ at $t=0$ is ${(A, 1, "repost"), (C, 1, "repost"), (B, 1, "repost")}$ and that $cal(T)_1 (A) != emptyset$ with $pi$ policy such as all users will always repost, and a time between actions following a constant of 1. Now, when $"pop"(Q)$, user $A$ will repost the post on it's timeline ---let's call it post $i$--- with the following queue

$ Q = {(C, 1, "repost"), (B, 1, "repost"), (A, 2, "repost")} $

So, at $t=1$, user $C$ will be able to repost a content at the same time as $A$ reposted it. When C reposts it again, $B$ will be able to have the same. This implies an instant transmission of the post $i$ to the timelines of all users. Although the reposts are not the 

To realistically model information propagation without dragging down computational performance, specific delays are introduced.
- *Propagation Delay*: A continuous random variable `propagation_delay` is sampled once when a post is broadcasted. It represents the time it takes for an action to travel across the network and reach followers' timelines.
- *Interaction Delay*: Sampled via `interaction_delay`, this dictates the temporal gap between a user seeing a post and effectively reacting to it.
- *Creation Delay*: Dictates the time between deciding to make a post and the actual execution of the creation event.
- *Avoidance of Continuous Time Management*: Instead of "ticking" the simulation or actively polling for state changes, delays are mathematically added to the global clock $t_c$ exactly when the event is formulated. The resultant absolute timestamps are pushed straight into the global Priority Queue, side-stepping the need to manually track "time left until execution."

== Data Structures
<sec-design-datastructures>

Essentially, as the axiom of stability remains unchanged, the graph topology structures remain static. 

=== Queue: Calendar Queue

#todo[Check that this doesn't break everywhere]

The main bottleneck of all DES is the Future (or pending) event set, which tracks the events the simulation has already scheduled to happen, which implies the need for them to be stored somewhere and be easitly retrieved.

The naive (excluding the sorting the list every time approach) implementation of the Future Event Set is the use of a Heap (see @sec-design-datastructures) as well as the Timeline object is actually implemented as.

The binary tree based heap implementation has both a $O(log n)$ cost when inserting or retrieving the least element given a single key, as it sifts up and down all the elements to keep a very fast access into the smallest key element [TODO: cita del llibre del MIT sobre algorismes]. Unfortunately, as the simulation needs to scale user wise, this structure is going to became a bottleneck eventually.

From the simulation design can be observed that a user has at most three events in the queue: an action, a creation and the end of the session. Let's assume, following the worse case scenario typical of the complexity analysis, that every user has three elements. Then, given $N$ different users, we'll have $3N$ elements in the simulation. If $N=10^7$ as the objective is, it will cost to access the heap $log_2(3·10^7) approx 25$, which is theoretically a very good computational cost. The problem is, in this case, the hardware (see [sec-evaluation-heapvscalendar])

The heap implementation used (see [@ solervalades-dsrepo]) is a flattened binary tree, which is the standard heap implementation, which is awfull for cache locality: to load one leaf of the tree, as the data is not continguosly stored, to also load the potential next leafs to keep searching, resulting in cache misses and the CPU stalling and waiting for the data.

Additionally, the simulation design requires from two to four operations to the heap, which make the actual cost twice or four times the logarithm we expected, and as it's impossible to batch add elements into a heap, there is no space for a reduction there.

The solution to the main bottleneck of the simulation is to use an Calendar Queue [TODO: Cite original paper m8 (it's in my downloads)] with a good heuristic to avoid resizing to the minimum and keep the number of events per bucket as consistant as possible.

*Heuristic design*

The standard Calendar Queue implementation relies on dynamic resizing to maintain its $O(1)$ amortized time complexity. However, by leveraging the specific constraints of our simulation, we can design a static heuristic to determine the optimal Calendar Queue parameters upfront, bypassing the computational overhead of resizing operations entirely. 

This heuristic depends on three simulation characteristics known a priori:
- The static number of users ($N$) and the maximum bounded events per user (yielding a maximum queue size of $3N$).
- The available memory budget, which dictates the maximum number of buckets $B_max$.
- The weighted average delay of generated events ($T_("mean_delay")$), derived from the probability distributions of the simulation configuration.

The design requires finding the optimal time width for a single bucket ($b$). A bucket represents a specific time slice $[t, t+b)$, and the time width must be chosen to ensure an optimal average number of events ($k$) land in each bucket. 

First, we determine our target density $k$ by dividing the maximum queue size by our fixed memory budget $B_max$:

$ k = frac(3N, B_max) $

In the absence of strict memory constraints, $B$ can simply be defined as the smallest power-of-two capable of fitting all simultaneous events:

$ B = 2^ceil(log_2(3N)) $

Once $k$ is established, we calculate the bucket width $b$. By dividing the weighted average delay of all events $T_("mean_delay")$ by the total events $3N$, we find the average time gap between any two events in the queue. Multiplying this gap by our target density $k$ yields the optimal bucket time width:

$ b = k dot frac(T_("mean_delay"), 3N) $

Notably, if we substitute the definition of $k$ directly into the equation for $b$, the $3N$ terms cancel out, revealing a highly simplified relationship:

$ b = (frac(3N, B_max)) dot frac(T_("mean_delay"), 3N) = frac(T_("mean_delay"), B_max) $

This demonstrates that the optimal time-slice $b$ is entirely independent of the number of users, dictated strictly by the chosen bucket array size and the simulation's overall event frequency. By configuring the Calendar Queue with a statically allocated array of $B_max$ pointers and a bucket width of $b$, the queue achieves stable $O(1)$ performance without ever requiring an array reallocation or bucket width recalculation.


To illustrate the heuristic, we assume the weighted average delay of the simulation events is calculated as $T_("mean_delay") = 11.92$ time units. #text(blue)[TODO: recorda recalcular tot això quan tinguis la calibració feta]

*Example 1: Unconstrained Memory (Target $N = 10^7$)*
With $10$ million users, the maximum queue capacity is $30,000,000$ events. If memory is unconstrained, we find the next power-of-two for $B$:
$ B = 2^ceil(log_2(30000000)) = 2^25 = 33554432 "buckets" $
The resulting density $k$ and bucket width $b$ are:
$ k = frac(30000000, 2^25) approx 0.89 "events per bucket" $
$ b = frac(T_("mean_delay"), B) = frac(11.92, 33554432) approx 3.55 times 10^(-7) "time units" $
This configuration requires approximately 268 MB of RAM for the bucket pointers. Because $k < 1$, the vast majority of buckets will contain a single event, guaranteeing absolute $O(1)$ retrieval without list traversal.

*Example 2: Limited Memory (Target $N = 10^6$, Max 2MB RAM)*
With $1$ million users, the queue holds up to $3·10^6$ events. The unconstrained $B$ would be $2^22$ (~33 MB). If the system is strictly limited to 2 MB for the queue array, we cap $B_max$ at $2^18$ (yielding 262,144 buckets):
$ B_max = 2^18 = 262144 "buckets" $
$ k = frac(3000000, 262144) approx 11.44 "events per bucket" $
$ b = frac(11.92, 262144) approx 4.54 times 10^(-5) "time units" $
By restricting the memory, the density $k$ increases to ~11 elements per bucket. While this incurs a small $O(k)$ penalty during insertion as the algorithm scans the short linked list, the performance remains exceptionally fast while strictly adhering to hardware constraints.

*Example 3: Massive Scale (Target $N = 10^9$)*
When scaling to $1$ billion users, the queue capacity reaches $3·10^9$ events. Applying the unconstrained formula yields:
$ B = 2^ceil(log_2(3000000000)) = 2^32 = 4294967296 "buckets" $
While mathematically optimal for time complexity, allocating an array of $4.29$ billion 8-byte pointers requires $34.3$ GB of RAM exclusively for the Calendar Queue's root array structure. At this massive scale, utilizing a $B_max$ constraint becomes virtually mandatory to trade a surplus of RAM for a slightly denser $k$ parameter.



=== Timeline: Max-Heap

The core engine for discrete event simulation relies heavily on Priority Queues, constructed intrinsically as Heaps.
- *What is a Heap?* A heap is a specialized tree-based data structure that satisfies the heap property, meaning the highest priority element is always mathematically bound to the root node. 
- *Why it's our best choice*: A heap guarantees optimal $O(log N)$ performance for inserting new events and $O(1)$ for finding the next chronological event (or reverse-chronological post in the timeline). It ensures the simulation's central loop remains lightning-fast even with millions of pending events.
- *n-ary optimizations*: Implementing heaps as contiguous arrays ensures memory locality, while mapping tree branches mathematically prevents the necessity of pointer chasing.


=== Graph Topology: Compressed Sparse Row


The followers of the graph are represented as a CSR.

The static follower connections forming the network topology are encoded using a Compressed Sparse Row (CSR) format, generally referred to as a Static Adjacency Array.
- Instead of giving each user their own dynamic list of followers (which incurs massive pointer overhead and heap fragmentation), all follower relations are concatenated into a single, massive, contiguous `followers: []Index` slice.
- Each `User` simply stores a `follower_start` integer and a `follower_count` integer. 
- To iterate over user $u$'s followers, the code simply slices the global array: `followers[follower_start .. follower_start + follower_count]`. This ensures maximum cache hit rates during massive post propagation storms.



=== Users: Struct of Arrays

What is exactly this as a data structure and how does it implement the concept on Data Oriented Design basics (see @sec-desgin-dodbasics)


=== Posts: SegmentedMultiArrayList

Because posts can be created arbitrarily throughout the simulation duration without a hard upper limit, their tracking mechanisms must be highly scalable.

*Segmented List for Posts*
To hold an uncapped number of posts in memory without incurring massive reallocation penalties, a `SegmentedMultiArrayList` is utilized. This behaves like a dynamically growing bookshelf: it allocates arrays in fixed capacities equal to a power of two ($2^n$). When one block fills up, a new one is allocated and appended. Searching for a post relies entirely on rapid bitwise operations (`i >> n` for the block, `i & (capacity - 1)` for the local index), completely avoiding array reallocation.

Additionally, this structure maintains a Structure-of-Arrays (SoA) layout. If posts eventually incorporate heavy elements like `[1536]f32` NLP embeddings, keeping data in SoA format prevents these massive arrays from polluting the CPU cache when the core simulation only needs to iterate rapidly over lightweight fields like `author_id` and `timestamp`.

*Post ID Assignment*
A scheduling quirk arises with dynamic creation: a post might be scheduled in the event queue as $(u, "create", p_"id", t)$, but because events can be dropped or skipped, the ID predicted at schedule time might not align with the actual ID when the event fires. To solve this, scheduled creates are assigned a placeholder ID of `0` in the queue, and are strictly assigned their true, globally unique ID only at the exact moment the event is actually processed.

=== Impressions: PagedBitSet

*Paginated Bitset for Impressions*
To track the impression footprint—who has seen what—we model a 2D matrix (users by posts) using a custom `PagedBitSet`. Since users are static but posts grow infinitely, this bitset allocates memory in discrete "pages." Each page covers all users vertically but limits the horizontal domain (posts) to a fixed size. As new posts are generated beyond the current bound, new pages are automatically allocated, resolving the strict memory bottleneck required by statically allocated bitsets.
#text(red)[Note: The codebase specifically refers to this structure as `PagedBitSet` rather than "Paginated Bitset".]



== High Performance Computing Sensibilities 

This section addresses steps taken in the design to ensure optimal performance and scalability. That is, mention that scalability is important and must be ensured at all costs. Connect with the methodology sections.

=== Data Oriented Design Basics
<sec-desgin-dodbasics>

This implementation strictly adheres to Data-Oriented Design (DOD) principles to maximize throughput and harness modern CPU architecture.
- *Structure of Arrays (SoA)*: Instead of declaring an Array of Structs (AoS) where user properties are bundled together, Zig's `MultiArrayList` separates fields into disjoint arrays. This means boolean flags like `.is_online` are packed contiguously in memory independently of `id`s.
- *Cache Line Locality*: When the simulation iterates over millions of users to check their online status, the CPU fetches entire cache lines (typically 64 bytes). Because `.is_online` flags are tightly packed natively in the SoA, a single memory fetch loads data for 64 users simultaneously, drastically minimizing cache misses.
- *Binary Shifting and Masking*: CPU architectures evaluate bitwise operations in single clock cycles. Advanced structures in the simulation (like the segmented lists and paginated bitsets) strictly enforce power-of-two capacities, allowing the codebase to calculate boundaries using highly optimized bitwise arithmetic (`>>` and `&`) rather than costly mathematical modulo or division instructions.
- Memory allocation strategies.

=== Runtime Dynamic Dispatch of Distributions

#text(blue)[
  Aquesta secció serà una tocada de collons màxima. Primer, explicar la diferència entre "run-time" i "compile-time", després explicar què és el polimorfisme, i després explicar què és el "dynamic dispatch". Per acabar, explicar que el que passa és que en temps d'execució, les distribucions de la configuració (runtime) son les que el programa utilitza (dispatch) encara que canviin per execució (dynamic).
]

Because the simulation configures statistical models dynamically at runtime, a system is required to parse distinct probability functions seamlessly.
- A custom `loadJson` function processes the JSON config and maps JSON distribution strings directly into `ContDist` and `DiscDist` wrapper types.
- These wrapper types utilize Zig's struct polymorphism via vtables (`vtable = &.{ .sample = sampleImpl }`) to abstract the underlying algorithms (like Ziggurat for Exponential or the Inverse Transform for Categorical). 
- This dynamic dispatch guarantees that the core event loops simply call `.sample(rng)` without caring about the concrete mathematical implementation underneath.

=== Memory Allocation Strategies

Information fetching from RAM is the main bottleneck in modern computing. The simulations uses three different strategies to optimize memory, according to the needs of the simulation.

+ General Puropose Allocator (or `malloc`): reserves memory in a linear and contigous fashion. Requires an interruption of the program execution for the kernel to provide the memory addresses. Can be resized perfectly if there is memory around the simulation.
+ Arena Allocator: reserves a large pool of memory, and controls which one is used by just index increments. As the whole memory is already allocated for the program, no need for interruptions.
+ Memory Pool: a very similar concept to the Arena, but while the arena allows use of chuncks of memory without size restriction of those, a memory pool just allows to fetch memory in a certain chunck size, perfect for fetching memory for a single struct. The main advantage is that memory reusablity is now extremely easy: if a new element is asked but some elements have already been freed, past memory is going to be reused. While this is possible in arenas, the non uniformity in size of the elements makes it very difficult in practice.

Let us discuss the use of these three memory strategies in specific examples of the simulation.

Loading static non-changning at runtime data is done with an Arena allocation. In the simulation, the json reading topology data and the actual graph data (see [sec-graph-data-representation]) is used. As the data is large, the use of the arena avoids interrupting the execution of the program if it were by the use of the General Puropose Allocator, and as it does not change during the execution, the arena will not have problems copying the memory from one place to another within the same arena.

All the Data Structures that require dynamic change are used with a General Purpose Allocator, mainly the heaps (timeline) and the Queue (NOTE: this is the main bottleneck, let's just use the Calendar queue)


== Additional Mechanics

#comment[This, althoguh techinally done, it should be moved to future work maybe]

*Quoting*
A user can decide to quote a post, establishing a new piece of content that directly references a `parent_id`. 
- The newly generated quote post is immediately marked as seen by its creator and is propagated to their followers.
- Quoting is strictly a reactive action; unlike standard post generation, creating a quote does not automatically schedule subsequent post creations in the queue.
- To ensure coherent interaction flow, whenever a follower encounters a quote post in their timeline, the system automatically retrieves the original parent post and injects it at the exact same timestamp. This ensures the user has full context before responding.

*Notifications*
Every quote actively generates a targeted notification aimed at the original author, breaking the strictly linear consumption of the timeline:
- If the target user is online when the notification arrives, the system bypasses normal propagation and immediately drops the new quote post directly into the user's active timeline to be processed next.
- If the user is offline, the system evaluates an `attend_offline_notification` probability. Upon success, the user abruptly "wakes up" out of schedule; the quote is injected into their timeline, and a new action event is dispatched to simulate the user logging on specifically to check the interaction.
- If the offline user fails the probability check, the notification lands in a Pending Buffer. Once the user finally comes back online, they are forced to process and empty this priority buffer before returning to standard timeline consumption.

To maintain realism as a discrete event model, user stamina mechanics can be introduced: if a user logs in to a massive backlog of notifications, they might only process a subset (e.g., following a Geometric distribution) before getting bored and discarding the rest.

== Trace Validation

Validating the execution of a highly stochastic and concurrent DES involves parsing the simulation's event trace.
- A validation script independently runs through the output trace (typically a CSV/JSON log of executed events) and verifies discrete logical rules.
- *Causality Checks*: The trace must guarantee that a post is inherently created before it is reposted or liked by any other entity.
- *Timeline Fidelity*: It must assert that a user never interacts with their own posts, enforcing the No-Self-Loop axiom.
- *Strict Ordering*: The timeline timestamps of consumed items must rigorously obey a monotonic reverse-chronological consumption order for every discrete session.

#todo[there's stuff missing here still, we should do it]
