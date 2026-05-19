#import "utils.typ": todo, comment

This chapter details the concrete engineering decisions that realize the simulation design described in @sec-design. While the previous chapter established what the simulation models and why specific algorithmic choices were made, this chapter addresses how those choices are realized in code: the technology stack, the performance strategies, the input/output pipeline, and the data structures that make the simulation scale to millions of users within practical execution times.

== Technologies
<sec-impl-technologies>

This section addresses all the diferent tools used.

Zig 0.16 was used to develop all the core simulation engine, as well as all the data structures used such as the Heap, the PaginatedBitSet and the SegmentedMultiArrayList. Also, all the distributions used by the simulation engine have been implemented in Zig also. The only external dependencies user are an argument parsing library called _EazyArgs_ @soler2025eazyargs which uses compile-time execution to generate code fitted specifically for the requested arguments.

Python 3.13 has been used for rapid and one-shot tasks developement, such as the artificial topology data generator and the trace validation scripts.

== Roadmap and Methodology

To build a simulation engine from scratch in a systems level programming language is a relatively heavy undertaking, so a plan was developed from the beginning of the project to not tackle the whole final simulation from the beginning, which could have been maddening.

The development process has been splited in three separate versions of the simulation, with the following milestones inside them:

*v1: Cronological Order and max posts per user*

The first version served as a proof of concept implementation and design, and was where most of the tangential utilities were developed. Here the Heap was implemented, as well as the _distributions_ library for the Categorical distribution $pi$.

The most interesting simplification was to assume user timelines were min-heaps, not max-heaps, so the simulation was not even behaviourally correct, and it was not intended to. To simplify it even further, the users were assumed to be homogeneous and behave all equally. The metrics of that simulation helped to verify the Categorical, Exponencial implementations, as well as define the multiple heaps per user implementation and the backbone of the event scheduling mechanic.

The first version of the network topology loading and wiering was introduced here, as well as the scripts to generate some sample ones to validate it. Furthermore, none of the strategies from Data Oriented Design (@sec-impl-dod) where applied here, being very noticeable the poor performance when loading and wiring the topology.

*v2: Reverse-Chronological Order and Sessions*

To change every user timeline into a max-heap was the most complicated part of the implementation, for every user now had to disconnect from the simulation for their timeline to be refilled. That introduces plenty of bugs and missbehaviours with time traveling errors such a repost made to a post before the post arrived to a user timeline; the propagate event was introduced to isolate those bugs, as the old mechanism directly inserted posts into the user timelines.

Here some DOD principles were applied, specially when wiring the graph topology structure, as the reading data format was redesigned. 

*v3: Unilimited Posts and Refactor*

When the core functionalities of the simulation was build, the Pagination was introduced to allow an unlimited number of posts per user, while maintaining all the other features. 

Some additional mechanics were introduced at this version, such as notifications (allowed a user to do an interaction while offline) or quoting (two posts where appeared at the user timeline) but were dropped due to scope and design reasons.

Lastly, a small effort to refactor and improve performance was made, introducing different memory allocators depending on the task (see @sec-impl-memory), rewriting suboptimal code an tiding up the codebase.


== Performance in a Systems Level Language 
<sec-impl-performance>

This section covers the principles applied throughout the implementation to keep the simulation's hot loop from stalling on any hardware resource: CPU cache, memory allocation, and I/O.

=== Data Oriented Design Basics
<sec-impl-dod>

The implementation strictly adheres to Data-Oriented Design (DOD) principles to maximize throughput and harness modern CPU architecture.
- *Structure of Arrays (SoA)*: Instead of declaring an Array of Structs (AoS) where user properties are bundled together, Zig's `MultiArrayList` separates fields into disjoint arrays. This means boolean flags like `.is_online` are packed contiguously in memory independently of `id`s. The alignment is what matters, relate with the CPU cache
- *Cache Line Locality*: When the simulation iterates over millions of users to check their online status, the CPU fetches entire cache lines (typically 64 bytes). Because `.is_online` flags are tightly packed natively in the SoA, a single memory fetch loads data for 64 users simultaneously, drastically minimizing cache misses.
- *Binary Shifting and Masking*: CPU architectures evaluate bitwise operations in single clock cycles. Advanced structures in the simulation (like the segmented lists and paginated bitsets) strictly enforce power-of-two capacities, allowing the codebase to calculate boundaries using highly optimized bitwise arithmetic (`>>` and `&`) rather than costly mathematical modulo or division instructions.
- *System Calls*: if you do them, all at the same time. Avoid when performance critical code is running, interrupts the execution.

=== Memory Allocation Strategies
<sec-impl-memory>

Information fetching from RAM is the main bottleneck in modern computing. The simulation uses three different strategies to optimize memory, according to the needs of each data lifetime.

+ *General Purpose Allocator* (or `malloc`): reserves memory in a linear and contiguous fashion. Requires an interruption of the program execution for the kernel to provide the memory addresses. Can be resized if there is free memory adjacent to the allocation.
+ *Arena Allocator*: reserves a large pool of memory, and controls which portion is used by just incrementing an offset. As the whole memory is already allocated upfront, no kernel interruptions are needed during the simulation.
+ *Memory Pool*: a similar concept to the Arena, but while the arena allows chunks of memory without size restrictions, a memory pool only serves allocations of a fixed chunk size — perfect for allocating a single struct type. The main advantage is that memory reuse is straightforward: if a new element is requested but some slots have already been freed, past memory is reused. While this is possible in arenas, the non-uniformity in element sizes makes it difficult in practice.

Let us discuss the use of these three strategies in specific parts of the simulation.

Loading static, non-changing-at-runtime data is done with an Arena allocation. In the simulation, both the JSON parsing of the topology data and the construction of the actual graph (see @sec-impl-csr) use an arena. As the data is large, the arena avoids interrupting program execution with repeated kernel calls; since the data does not change during execution, the arena's inability to free individual elements is not a limitation.

All data structures that require dynamic change during the simulation — primarily the per-user timeline heaps and the global event queue — use a General Purpose Allocator. These structures grow and shrink as events are processed and sessions start and end, requiring the flexibility of individual allocations and deallocations.

=== Buffered Trace I/O
<sec-impl-trace-io>

#comment[
  This section covers how trace writing is optimized to never stall the hot loop.

  Points to cover:
  - Four trace files written simultaneously during simulation: action, session,
    create, propagation. Each gets a 64 KB stack-allocated buffer (no heap
    allocation, no resizing).
  - Traces are written in binary as fixed-size Zig structs (TraceAction,
    TraceSession, TraceCreate, TracePropagation). Zero serialization overhead
    during the simulation — just `std.mem.asBytes(&event)` and a memcpy into the
    buffer.
  - Buffers flush to disk only when full. In the common case (buffer not full),
    writing a trace event is a single bounds check + memcpy — no syscall, no
    kernel context switch.
  - Post-simulation: the binary trace files are converted to JSONL offline via
    `bytesToJsonl`. This defers the expensive text-formatting work to after the
    hot loop, and means the simulation never touches a JSON serializer.
  - When `trace_to_file` is disabled in the config, a `Discarding` writer is
    substituted. This is a zero-cost no-op that keeps the same code path — no
    `if (trace_to_file)` branches inside the simulation loop, just a vtable
    pointer swap at initialization.
  - This is the I/O equivalent of the Arena allocator pattern: batch work,
    defer expensive operations, keep the hot loop running.
]

== Input Data Format
<sec-impl-topology>

#comment[
  Describes the JSON schema the simulation reads at startup, and how synthetic
  data is generated.

  Points to cover:
  - The simulation expects a single JSON file describing the network topology:
    - `users[]`: each user has `id`, `actions` (list of action strings), `policy`
      (probability vector aligned with actions), `max_posts` (optional cap).
    - `followers[]`: each edge has `follower_id` and `followed_id`, defining the
      directed follow graph. Under user homogeneity all user policies are identical.
  - This JSON is deserialized by `loadJson` into a `NetworkJson` struct, then
    wired into the `Topology` CSR representation (see @sec-impl-csr) via an Arena
    allocator.
  - Synthetic data is generated by `generate_data.py` (Python):
    - Creates a scale-free-ish directed graph via a preferential attachment variant
      with configurable clustering coefficient.
    - Assigns homogeneous user policies and action probabilities.
    - Outputs the JSON file consumed by the simulation.
    - Parameters: number of nodes, edges per new node, clustering probability.
  - The data generation and simulation are decoupled: the same simulation binary
    can run on any compliant JSON topology (synthetic or real-world).
]

== Runtime Configuration & Distribution Dispatch
<sec-impl-runtime-config>

#comment[
  Covers the stats package and the JSON → distribution dispatch pipeline.

  Points to cover:
  - The `stats` package (custom Zig library) provides probability distributions:
    - Continuous: Exponential, Uniform, Erlang, Hyperexponential, Hypoexponential,
      Constant, ECDF.
    - Discrete: Categorical.
    - Each distribution is a generic type parameterized by `Precision` (f32 or f64
      at compile time). No runtime float-width branching.
  - The `Distribution` interface: every distribution exposes a vtable with a
    `.sample(rng)` function pointer. Concrete distributions embed this interface
    as a field and set the vtable to their own implementation via
    `vtable = &.{ .sample = sampleImpl }`.
  - The `ContDist` and `DiscDist` wrapper types are thin unions over all supported
    distributions. The simulation code only interacts with these wrappers — it
    never knows which concrete distribution is behind a `.sample()` call.
]

Because the simulation configures statistical models dynamically at runtime, a system is required to parse distinct probability functions seamlessly.
- A custom `loadJson` function processes the JSON config and maps JSON distribution strings directly into `ContDist` and `DiscDist` wrapper types.
- These wrapper types utilize Zig's struct polymorphism via vtables (`vtable = &.{ .sample = sampleImpl }`) to abstract the underlying algorithms (like Ziggurat for Exponential or the Inverse Transform for Categorical). 
- This dynamic dispatch guarantees that the core event loops simply call `.sample(rng)` without caring about the concrete mathematical implementation underneath.

#comment[
  Why this matters:
  - The simulation binary is compiled once. All distribution choices live in the
    JSON config file — Exponential vs Erlang, f32 vs f64 precision — and are
    resolved at runtime via the vtable dispatch.
  - This enables parameter sweeps: run the same binary hundreds of times with
    different config files, no recompilation.
  - The vtable indirection cost is one pointer chase per `.sample()` call, which
    is negligible compared to the mathematical work inside each distribution.
]

== Core Data Structures
<sec-impl-datastructures>

=== Queue: Binary Heap
<sec-impl-queue>

Talk about how the number of element in the leaf can be like very optimal, specially if kept in powers of $2^n$. That's what we do.

The global event queue $Q$ is built on the `ds` package's `Heap` type — a generic binary heap parameterized by element type and comparison function. Events are ordered by timestamp (primary key) and event id (secondary tie-breaker, ensuring deterministic ordering when two events share the same timestamp). The heap uses the standard flattened array representation, where children of node $i$ reside at indices $2i+1$ and $2i+2$.

At the target scale of $N=10^7$ users with at most three events per user simultaneously in the queue ($3N$ elements), each heap operation requires approximately $log_2(3 dot 10^7) approx 25$ comparisons — theoretically manageable. However, the flattened array layout incurs cache misses during sift-down operations, as parent-child traversal jumps across non-contiguous memory regions. A discussion of the Calendar Queue alternative — which would achieve $O(1)$ amortized access through bucketed time-slicing — is deferred to @sec-future.

=== Timeline: Max-Heap
<sec-impl-timeline>

Each user's timeline $cal(T)(u)$ is a max-heap over `TimelineEvent` tuples $(t, p_"id")$, using the same `ds.Heap` type as the global queue but with a reverse-chronological comparison function — the most recent post always sits at the root.

The heap uses the standard flattened array layout. This contiguous storage ensures memory locality: when a user scrolls through their timeline, successive heap extractions operate on adjacent memory regions, keeping the working set in cache. Tree navigation is computed arithmetically rather than through pointer indirection, eliminating the need to chase pointers across the heap.

=== Graph Topology: Compressed Sparse Row
<sec-impl-csr>

The static follower connections forming the network topology are encoded using a Compressed Sparse Row (CSR) format, generally referred to as a Static Adjacency Array.
- Instead of giving each user their own dynamic list of followers (which incurs massive pointer overhead and heap fragmentation), all follower relations are concatenated into a single, massive, contiguous `followers: []Index` slice.
- Each `User` simply stores a `follower_start` integer and a `follower_count` integer. 
- To iterate over user $u$'s followers, the code simply slices the global array: `followers[follower_start .. follower_start + follower_count]`. This ensures maximum cache hit rates during massive post propagation storms.

=== Users: Struct of Arrays
<sec-impl-users>

The `User` struct (defined in @sec-design-entities) contains fields with very different access patterns. Hot fields — `is_online`, `session_gen`, `num_posts` — are checked on every event processed. Cold fields — `policy`, `max_posts` — are rarely touched after initialization. Zig's `MultiArrayList(User)` stores each field in a separate contiguous array, realizing the Structure-of-Arrays pattern discussed in @sec-impl-dod.

This means that when the simulation iterates over all users to check their online status, a single cache line containing `.is_online` flags loads the status of 64 consecutive users, without dragging in unrelated policy distributions or other cold data.

=== Posts: SegmentedMultiArrayList
<sec-impl-posts>

Because posts can be created arbitrarily throughout the simulation duration without a hard upper limit, their tracking mechanisms must be highly scalable. Posts are stored in the `ds` package's `SegmentedMultiArrayList`.

*Segmented List for Posts*
To hold an uncapped number of posts in memory without incurring massive reallocation penalties, a `SegmentedMultiArrayList` is utilized. This behaves like a dynamically growing bookshelf: it allocates arrays in fixed capacities equal to a power of two ($2^n$). When one block fills up, a new one is allocated and appended. Searching for a post relies entirely on rapid bitwise operations (`i >> n` for the block, `i & (capacity - 1)` for the local index), completely avoiding array reallocation.

Additionally, this structure maintains a Structure-of-Arrays (SoA) layout. If posts eventually incorporate heavy elements like `[1536]f32` NLP embeddings, keeping data in SoA format prevents these massive arrays from polluting the CPU cache when the core simulation only needs to iterate rapidly over lightweight fields like `author_id` and `timestamp`.

*Post ID Assignment*
A scheduling quirk arises with dynamic creation: a post might be scheduled in the event queue as $(u, "create", p_"id", t)$, but because events can be dropped or skipped, the ID predicted at schedule time might not align with the actual ID when the event fires. To solve this, scheduled creates are assigned a placeholder ID of `0` in the queue, and are strictly assigned their true, globally unique ID only at the exact moment the event is actually processed.

=== Impressions: PagedBitSet
<sec-impl-impressions>

To track the impression footprint—who has seen what—we model a 2D matrix (users by posts) using the `ds` package's `PagedBitSet`. Since users are static but posts grow infinitely, this bitset allocates memory in discrete "pages." Each page covers all users vertically but limits the horizontal domain (posts) to a fixed size. As new posts are generated beyond the current bound, new pages are automatically allocated, resolving the strict memory bottleneck required by statically allocated bitsets.
#text(red)[Note: The codebase specifically refers to this structure as `PagedBitSet` rather than "Paginated Bitset".]

== Trace Validation
<sec-impl-validation>

#comment[
  Covers the post-simulation validation pipeline.

  Points to cover:
  - `validate_trace.py` (Python) runs after simulation and independently verifies
    correctness of the output trace files. It is decoupled from the engine — it
    reads the binary→JSONL converted trace files and checks logical invariants.
  - Validation rules enforced:
    - *Time monotonicity*: timestamps are non-decreasing within each trace file.
    - *Unique event IDs*: no `event_id` is repeated within or across trace files.
    - *Session alternation*: each user's session start/end events strictly
      alternate (no two consecutive starts or ends).
    - *No duplicate posts*: each `post_id` is created exactly once.
    - *Max posts per user*: if `max_posts` is configured, no user exceeds their cap.
    - *No self-interaction*: a user never reposts or likes their own posts.
    - *Causality*: a post must be created before any user interacts with it (repost,
      like, or propagation). A user must be online to perform any action.
    - *No double reposts*: a user cannot repost the same post more than once.
  - The validation script produces a pass/fail report. A failing validation
    indicates either a bug in the simulation engine or a violation of the
    assumptions encoded in the design.
  - This serves as a regression test suite: any change to the simulation code
    can be checked by re-running a known-good configuration and validating the
    output traces.
]
