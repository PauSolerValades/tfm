#import "@preview/lovelace:0.3.0": *
#import "utils.typ": todo, comment

This section covers the design of the simulation program and implementation.

== Assumptions
To ensure tractability and isolate specific network dynamics in the first version of this simulation, we constrain the theoretical model using the following simplifying assumptions:

1. *User Homogeneity:* Every user $u in cal(U)$ is indistinguishable in behavior and shares the exact same decision policy $pi$ and creation rate $lambda$.
$ forall u, v in cal(U) : pi^(u) = pi^(v) = pi quad "and" quad lambda^(u) = lambda^(v) = lambda $
#text(red)[Note: The implementation code parses User Decision Policy and `max_posts` per-user from JSON, breaking strict theoretical user homogeneity.]

2. *Post Homogeneity:* All posts are treated as content-agnostic commodities. A user's probability of executing an action $a$ is completely independent of the specific item being evaluated:
$ pi(a | i) = pi(a | j) = pi(a) quad forall i, j in cal(I), forall a in cal(R)'_(cal(U)cal(I)) $

3. *Action Independence (Markovian Behavior):* A user's choice to interact with a post $i$ at time $t$ depends strictly on the static policy $pi$ and is independent of their historical impression history $cal(H)_u^"act"$. Letting $PP$ denote probability:
$ PP ( (u, i, a, t) in E mid(|) cal(H)^"act"_u(t) ) = pi(a) $

4. *Timeline Consumption (Reverse-Chronological):* The timeline $cal(T)(u,t)$ is consumed strictly in reverse-chronological order. We formalize the timeline as a priority structure (akin to a max-heap), where the next item presented to the user is extracted via a $"pop"$ operation that retrieves the item $i$ associated with the most recent timestamp $tau_i$:
$ "pop"(cal(T)(u, t)) = arg max_(i in cal(T)(u, t)) tau_i $

5. *Session-Based Activity:* Interactions are strictly gated by the user state function $S(u, t)$. When online, actions evaluated by $pi$ and $lambda$ are executed; when offline, the user acts only as a passive accumulator of incoming timeline events.


6. *No-Self-Loop:* A user will never be served their own created content in their timeline.
$ cal(P) (u, t) inter cal(T)(u, t) = emptyset $

7. *Single-Action Limit:* A user can meaningfully interact with a specific item $i$ at most once.
$ (u, i, a_1, t_1) in E quad "and" quad (u, i, a_2, t_2) in E arrow.r.double a_1 = a_2 quad "and" quad t_1 = t_2 $
#text(red)[Note: The implementation actively enforces a single-impression limit via the `user_seen_post` bitset matrix, meaning users strictly cannot even view the same post twice on their timeline, implicitly enforcing the single-action limit.]

== Mechanics

This section establishes which main components are in play.

=== User Decision Policy

The user decision policy $\pi$ determines which action a user takes when they see a post.
- It is implemented using a `Categorical` discrete distribution.
- During initialization, the simulation parses the JSON configuration to map a list of possible actions (`"ignore"`, `"like"`, `"repost"`) to their respective probability weights.
- When an `action` event is triggered, the simulation simply evaluates `simconf.user_policy.sample(rng)` in $O(1)$ empirical time to determine the exact action to schedule next.

=== Session and Timelines

The introduction of sessions introduces several operational challenges to the discrete event simulation, specifically regarding the interruption of stochastic processes. Time between actions and creations are measured *within a session* rather than globally. 

Because DES relies on uninterrupted renewal processes to sample probability distributions correctly, pausing a user's activity when they go offline could mathematically invalidate the process (e.g., failing a goodness-of-fit test) if not handled properly. To circumvent this, the simulation associates a `session_gen` identifier to each user. Whenever a user goes offline, their timeline is cleared (as it would be refreshed upon new login) and their `session_gen` counter increments. 

When the simulation pops an event from the central queue, it first checks if `event.session_gen != user.session_gen`. If this condition holds true, the event is considered *stale* (originating from a previous session that was interrupted) and is safely discarded. 
#text(red)[Note: The Zig implementation codebase explicitly calls this variable `session_id` rather than `session_gen`.]

=== Delays and Quicks

To realistically model information propagation without dragging down computational performance, specific delays are introduced.
- *Propagation Delay*: A continuous random variable `propagation_delay` is sampled once when a post is broadcasted. It represents the time it takes for an action to travel across the network and reach followers' timelines.
- *Interaction Delay*: Sampled via `interaction_delay`, this dictates the temporal gap between a user seeing a post and effectively reacting to it.
- *Creation Delay*: Dictates the time between deciding to make a post and the actual execution of the creation event.
- *Avoidance of Continuous Time Management*: Instead of "ticking" the simulation or actively polling for state changes, delays are mathematically added to the global clock $t_c$ exactly when the event is formulated. The resultant absolute timestamps are pushed straight into the global Priority Queue, side-stepping the need to manually track "time left until execution."

== Data Structures
<sec-design-datastructures>

Essentially, as the axiom of stability remains unchanged, the graph topology structures remain static. 

*Calendar Queue*
The main queue of the simulation is implemented with a Calendar Queue. #text(blue)[Todo: això s'ha d'explicar bé]


*User Timeline (Max Heap)*
To satisfy the reverse-chronological consumption constraint, the timeline associated to every user is modeled as a Max Heap. This ensures that the element with the largest timestamp is always returned first. This structure must be carefully managed to prevent unbound memory growth, which is why timelines are explicitly cleared when a user logs off.

*MultiArrayList*
What is exactly this as a data structure and how does it implement the concept on Data Oriented Design basics (see @sec-desgin-dodbasics)


*Compressed Sparse Row (CSP)*
The followers of the graph are represented as a CSR.

*BitSet*
TO be removed with the modelization changes

*Paged/Segmented Paradigmns*
SegmentedList, Segmented MultiArrayList and 

== Pseudocode

The simulation relies on four main routines to govern the discrete event generation. `PropagatePost` handles the spreading of an item to followers. `StageOne` generates the initial state (the warm-up phase) to fill timelines before active simulation. `InitSessions` assigns the initial online/offline states based on a random proportion. Finally, `Simulation` executes the core loop.

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

== Implementation

This section addresses steps taken in the design to ensure optimal performance and scalability. That is, mention that scalability is important and must be ensured at all costs. Connect with the methodology sections.

=== Data Oriented Design Basics
<sec-desgin-dodbasics>

This implementation strictly adheres to Data-Oriented Design (DOD) principles to maximize throughput and harness modern CPU architecture.
- *Structure of Arrays (SoA)*: Instead of declaring an Array of Structs (AoS) where user properties are bundled together, Zig's `MultiArrayList` separates fields into disjoint arrays. This means boolean flags like `.is_online` are packed contiguously in memory independently of `id`s.
- *Cache Line Locality*: When the simulation iterates over millions of users to check their online status, the CPU fetches entire cache lines (typically 64 bytes). Because `.is_online` flags are tightly packed natively in the SoA, a single memory fetch loads data for 64 users simultaneously, drastically minimizing cache misses.
- *Binary Shifting and Masking*: CPU architectures evaluate bitwise operations in single clock cycles. Advanced structures in the simulation (like the segmented lists and paginated bitsets) strictly enforce power-of-two capacities, allowing the codebase to calculate boundaries using highly optimized bitwise arithmetic (`>>` and `&`) rather than costly mathematical modulo or division instructions.
- Memory allocation strategies.

=== Future Event Set
#todo[Revisar que això no peti per tot arreu]

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

=== Runtime Dynamic Dispatch of Distributions

#text(blue)[
  Aquesta secció serà una tocada de collons màxima. Primer, explicar la diferència entre "run-time" i "compile-time", després explicar què és el polimorfisme, i després explicar què és el "dynamic dispatch". Per acabar, explicar que el que passa és que en temps d'execució, les distribucions de la configuració (runtime) son les que el programa utilitza (dispatch) encara que canviin per execució (dynamic).
]

Because the simulation configures statistical models dynamically at runtime, a system is required to parse distinct probability functions seamlessly.
- A custom `loadJson` function processes the JSON config and maps JSON distribution strings directly into `ContDist` and `DiscDist` wrapper types.
- These wrapper types utilize Zig's struct polymorphism via vtables (`vtable = &.{ .sample = sampleImpl }`) to abstract the underlying algorithms (like Ziggurat for Exponential or the Inverse Transform for Categorical). 
- This dynamic dispatch guarantees that the core event loops simply call `.sample(rng)` without caring about the concrete mathematical implementation underneath.

=== Heap and n-ary Leaf

The core engine for discrete event simulation relies heavily on Priority Queues, constructed intrinsically as Heaps.
- *What is a Heap?* A heap is a specialized tree-based data structure that satisfies the heap property, meaning the highest priority element is always mathematically bound to the root node. 
- *Why it's our best choice*: A heap guarantees optimal $O(log N)$ performance for inserting new events and $O(1)$ for finding the next chronological event (or reverse-chronological post in the timeline). It ensures the simulation's central loop remains lightning-fast even with millions of pending events.
- *n-ary optimizations*: Implementing heaps as contiguous arrays ensures memory locality, while mapping tree branches mathematically prevents the necessity of pointer chasing.

=== Post Creation and Storage

Because posts can be created arbitrarily throughout the simulation duration without a hard upper limit, their tracking mechanisms must be highly scalable.

*Segmented List for Posts*
To hold an uncapped number of posts in memory without incurring massive reallocation penalties, a `SegmentedMultiArrayList` is utilized. This behaves like a dynamically growing bookshelf: it allocates arrays in fixed capacities equal to a power of two ($2^n$). When one block fills up, a new one is allocated and appended. Searching for a post relies entirely on rapid bitwise operations (`i >> n` for the block, `i & (capacity - 1)` for the local index), completely avoiding array reallocation.

Additionally, this structure maintains a Structure-of-Arrays (SoA) layout. If posts eventually incorporate heavy elements like `[1536]f32` NLP embeddings, keeping data in SoA format prevents these massive arrays from polluting the CPU cache when the core simulation only needs to iterate rapidly over lightweight fields like `author_id` and `timestamp`.

*Paginated Bitset for Impressions*
To track the impression footprint—who has seen what—we model a 2D matrix (users by posts) using a custom `PagedBitSet`. Since users are static but posts grow infinitely, this bitset allocates memory in discrete "pages." Each page covers all users vertically but limits the horizontal domain (posts) to a fixed size. As new posts are generated beyond the current bound, new pages are automatically allocated, resolving the strict memory bottleneck required by statically allocated bitsets.
#text(red)[Note: The codebase specifically refers to this structure as `PagedBitSet` rather than "Paginated Bitset".]

*Post ID Assignment*
A scheduling quirk arises with dynamic creation: a post might be scheduled in the event queue as $(u, "create", p_"id", t)$, but because events can be dropped or skipped, the ID predicted at schedule time might not align with the actual ID when the event fires. To solve this, scheduled creates are assigned a placeholder ID of `0` in the queue, and are strictly assigned their true, globally unique ID only at the exact moment the event is actually processed.

=== Graph Representation of the Network Topology

The static follower connections forming the network topology are encoded using a Compressed Sparse Row (CSR) format, generally referred to as a Static Adjacency Array.
- Instead of giving each user their own dynamic list of followers (which incurs massive pointer overhead and heap fragmentation), all follower relations are concatenated into a single, massive, contiguous `followers: []Index` slice.
- Each `User` simply stores a `follower_start` integer and a `follower_count` integer. 
- To iterate over user $u$'s followers, the code simply slices the global array: `followers[follower_start .. follower_start + follower_count]`. This ensures maximum cache hit rates during massive post propagation storms.

=== Memory Allocation Strategies

Information fetching from RAM is the main bottleneck in modern computing. The simulations uses three different strategies to optimize memory, according to the needs of the simulation.

+ General Puropose Allocator (or `malloc`): reserves memory in a linear and contigous fashion. Requires an interruption of the program execution for the kernel to provide the memory addresses. Can be resized perfectly if there is memory around the simulation.
+ Arena Allocator: reserves a large pool of memory, and controls which one is used by just index increments. As the whole memory is already allocated for the program, no need for interruptions.
+ Memory Pool: a very similar concept to the Arena, but while the arena allows use of chuncks of memory without size restriction of those, a memory pool just allows to fetch memory in a certain chunck size, perfect for fetching memory for a single struct. The main advantage is that memory reusablity is now extremely easy: if a new element is asked but some elements have already been freed, past memory is going to be reused. While this is possible in arenas, the non uniformity in size of the elements makes it very difficult in practice.

Let us discuss the use of these three memory strategies in specific examples of the simulation.

Loading static non-changning at runtime data is done with an Arena allocation. In the simulation, the json reading topology data and the actual graph data (see [sec-graph-data-representation]) is used. As the data is large, the use of the arena avoids interrupting the execution of the program if it were by the use of the General Puropose Allocator, and as it does not change during the execution, the arena will not have problems copying the memory from one place to another within the same arena.

All the Data Structures that require dynamic change are used with a General Purpose Allocator, mainly the heaps (timeline) and the Queue (NOTE: this is the main bottleneck, let's just use the Calendar queue)



== Additional Mechanics: Quoting, Notifications and Replies

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


