#import "../utils.typ":  def, code, flex-caption, todo, comment,

#import "@preview/cetz:0.4.2"

This appendix details the concrete engineering decisions that realize the simulation design described in @sec-design. While the previous chapter established what the simulation models and why specific algorithmic choices were made, this appendix addresses how those choices are realized in code: the performance strategies, the input/output pipeline, and the data structures that make the simulation scale to millions of users within practical execution times. 

== Technology Approach 
<apx-design-techology>

Because the validity of any simulation can rely on sheer computational volume and repeated runs to achieve statistical significance, a lot of care must be used to develop the implementation to achieve both quick iteration speed and results analysis. In a sentence: performance is king.

The first step in achieving high performance is choosing the appropriate tools for the job. Interpreted languages like Python @python and R @rlang are immediately discarded, as the interpretation process introduces more workload than strictly needed: a simple operation such as an integer addition costs well over 100 CPU cycles once bytecode dispatch and object boxing are accounted for @vanderplas2014python. Moreover, they do not offer control over memory allocation, which has been proved crucial in loading datasets at the scale of this work. This is also why despite providing excellent performance, developer ergonomics and ecosystem, Julia @julia is discarded #footnote[Despite being discarded, a Julia implementation would have produced a reasonably fast implementation due to its excellent JIT compiler, eventually compiling the whole program]: despite being fast, its garbage collector introduces the same fundamental limitation. Following this logic, manual memory management becomes preferable to deeply optimize performance and take full advantage of CPU caching. With requirements pointing strictly toward a systems language with manual memory management, the engine was implemented in Zig @zig.

Zig is a modern systems programming language selected specifically for its deterministic memory management and seamless support for Data-Oriented Design (DOD) (see @apx-impl-memory). By design, it provides C-like performance alongside modern quality-of-life improvements and strict guardrails against common C pitfalls, such as segmentation faults and null pointer dereferences. With the application of the right memory optimization techniques (see @apx-impl-memory), Zig enables highly scalable implementations that extract the maximum possible performance from the hardware.


== Versioning  
<apx-impl-version>

To build a simulation engine from scratch in a systems level programming language is a relatively heavy undertaking, so the following implementation strategy was followed from the beginning of the project to guarantee a successful result. The underlying philosophy of this approach can be summarized as "prototype small, enhance big, then repeat". To arrive at the final state of the simulation, three previous versions have been developed so far.

==== v1: Chronological Order and max posts per user

The first version served as a proof of concept implementation and design, and was where most of the needed utilities but not part of the main program were developed, such as the Heap implementation, the _distributions_ library with the Exponential, Normal and Categorical implementation, as well as the runtime dynamic dispatch JSON config file ---despite not being near its final form, but very functional---, in order to iterate quickly with the parameters.

The first version did not even aim to implement the same behaviour ---therefore not correct--- as the final simulation, as the timeline implements a chronological timeline (min-heaps) not a reverse one (max-heap), so the simulation was serving the older post the user had not seen, not the most recent one. To simplify it even further, the users were assumed to be homogeneous and behave all equally. These simplifications allowed to test the propagate behaviour, as well as the essential architecture of the DES simulation with very similar data structures as the final version will end up having.

The first version of the network topology loading and wiring was introduced here, as well as the scripts to generate some sample ones to validate it. Furthermore, none of the strategies discussed later in this section were applied here, with the poor performance being very noticeable when loading and wiring the topology.

==== v2: Reverse-Chronological Order and Sessions

To change every user timeline into a max-heap was the most complicated part of bringing the model into life, for every user now had to disconnect from the simulation for their timeline to be refilled. That introduces plenty of bugs and misbehaviours with "time traveling" errors ---time causality violations--- such as a repost made to a post before the post arrived at a user timeline; the propagate event @sec-design-sources-propagate was introduced to isolate those bugs, as the old mechanism directly inserted posts into the user timelines ---was neither a very good idea nor a good design decision.

Here some DOD principles were applied, especially when wiring the graph topology structure, as the reading data format was redesigned. 

==== v3: Unlimited Posts and Refactor

When the core functionalities of the simulation were built, the Pagination was introduced to allow an unlimited number of posts per user, while maintaining all the other features. 

Some additional mechanics were introduced at this version, such as notifications (allowed a user to do an interaction while offline) or quoting (two posts that appeared at the user timeline) but were dropped due to scope and design reasons, see them described on appendix @apx-mechanics.

Lastly, a small effort to refactor and improve performance was made, introducing different memory allocators depending on the task (see @apx-impl-memory), rewriting suboptimal code and tidying up the codebase.

==== v4: Final Release 

Contains the same features of the v3 simulation with performance optimizations regarding memory management. Although it might sound weird to the reader, the main performance improvements are not introduced in the last version as a refactor, as performance is a consequence of good through design from the beginning of the project.

The main feature of the last version is multithreading execution with a predefined number of workers (see @apx-impl-parallelism) while ensuring reproducibility, as well as the creation of the pipeline to be able to schedule as many executions as needed.

== Memory Allocation Strategies
<apx-impl-memory>

Every program needs memory where to hold the data it operates on. Every program has two types of memory: 
- *Stack*: is all allocated by the OS when the program starts. Functions and variables are stored there.
- *Heap*: Memory not reserved by default, but given on request to the programmer with the use of certain functions; in C would be `malloc, calloc, realloc`.

As the simulation needs to hold a massive amount of data to store the topology and its own state, the need of heap memory is the only way forward. Every new memory allocation is a `SYSCALL` @wiki-syscall, which will imply program execution halting to get the reserved addresses of memory back, which is an unavoidable part of the program: getting the memory addresses to work. What is a far worse performance concern is the reallocation of memory. Let's take C `malloc` vs `realloc` functions.

`malloc` will return a pointer to a chunk of contiguous (virtual) memory, ready for the program to use. Imagine we want to store an array of 32 unsigned integers (each of which has a size of 4 bytes) on to the heap, we can ask `malloc` for $32·4 = 128$ bytes of memory with a `SYSCALL`, and the OS will provide that to use, in a contiguous manner. Now, the list contained 40 numbers, instead of 32, so we have to ask for more memory, with the requisite we still want the previous memory to be contiguous with the new one. Now we have to call `realloc` to give us 32 more integers (as good principled programmers ask the memory in powers of two...), to get a $64 · 4 = 256$ bytes. The catch is that `realloc` will make sure the memory is still contiguous, so when reallocating the memory one of two things can happen:
1. Good path: the OS just extends previous memory to 64 integers without problem, as the next 128 byte chunk was empty.
2. Bad path: the next 128 byte chunk is not empty, therefore the OS needs to search for a 256 bytes of contiguous memory in another part of the memory, copy all the previous numbers and return the new address of memory.

Performance wise, one would think that the rule of thumb would be to try to avoid the bad path, and go for the good path. That is half right, as there are situations where you must ask for more memory. But the optima is to try to never ask the OS for more memory after the program has started, by choosing a clever memory allocation strategy.

In Zig, Heap memory is managed with `Allocators` @zig-std-heap, an interface that must be implemented and allows to follow different memory allocation strategies, and will be more or less suited in different situations. An allocator must implement the VTable shown in @code-allocator-vtable.

#code(caption: flex-caption([The `Allocator.VTable` interface.], [The `Allocator.VTable` interface from the Zig standard library. An allocator is a context pointer plus a table of four function pointers: `alloc`, `resize`, `remap` and `free`.]))[
  #show raw: set text(size: 6pt)
  ```zig
  pub const VTable = struct {
      alloc:  *const fn (*anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8,
      resize: *const fn (*anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool,
      remap:  *const fn (*anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8,
      free:   *const fn (*anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void,
  };
  ```
] <code-allocator-vtable>

=== Arena Allocation

Arenas are a backed allocator by a simpler allocator such as the `page_allocator` @zig-std-heap #footnote[Page Allocator is the most simplest allocator one can have: asks the OS for fixed memory chunks (pages), resizes and frees them. This is the closest equivalent of what standard C `malloc` is. ] and provide them as needed. The implementation is as simple as having an increasing offset, marking the first free memory space to allocate, trading off the ability of reusing or freeing memory addresses behind current offset. This means that whenever attempting to resize in place, the arena will refuse and ask you to ask for more memory, copy the bigger structure in front of the arena and increment the offset. Therefore, arenas are perfectly fit for storing big immutable structures.  In the simulation, this is exactly what the simulation parameters ---both global and user specific--- are, as well as the network topology storage, as its data is unchanged at runtime.

To reduce the amount of useful memory at minimum, more than one arena is used (and then discarded) in the loading data process. To load the graph topology in the simulation, a temporary arena is created to hold the raw data in memory, all at once. When that is done, the real arena is used to hold the `Topology` struct with the CSR (see @sec-design-datastructures-topology).

#code(caption: flex-caption([Arena usage when loading the topology in `src/main.zig`.], [Arena usage when loading the topology in `src/main.zig`.]))[
  ```zig
  var load_data_arena: ArenaAllocator = .init(page_allocator);
  const tmpalloc = load_data_arena.allocator();
  const sampled_topology: BinaryGraph = try .create(io, tmpalloc, args.datafile);
  var topology: Topology = try .create(arena, gpa, sampled_topology);
  sampled_topology.delete(tmpalloc);
  load_data_arena.deinit();
  ```
] <code-main-arena>

The same pattern is used to generate the different types of users. The user config is loaded with a temporary `arena` to hold the information in the `users.json` specifying the distributions of `session_duration`, `inter_session_lenght`, `inter_post_creation` and `offset_post_creation`. Once that is loaded, the `user_config` array is created, and the arena is deleted.

=== General Purpose Allocator

General Purpose Allocators are allocators that, with more or less sophistication, allow one to resize and reclaim the memory if it's chosen; in a simulation context, the important one of those two is the resizing, as moving a new structure and copying is pretty costly. The timeline $Q$ uses a `SMPAllocator` @zig-std-heap to manage its own memory. First, using the number of elements in the queue upper bound, we init the capacity to $4N$, and if in any moment the queue needs more memory, will be able to resize with a not as big cost penalty as if it were copied around.

=== Jemalloc Allocator

The optimal resource management of each user timeline $T(u)$ has been a troublesome one, especially when mixed with the multithreading paradigm to provide parallelism in the execution.

The timeline $T(u)$ is perfectly suited for a General Purpose Allocator memory management paradigm, as their length can be extremely variable per user (the in-degree of the user might make it see some orders of magnitude more posts than a far less in-degree user) and we cannot approximate the capacity it needs without taking into account the topology position of that user. Even if we could make that approximation and make a good enough upper bound, we must take into account that by the chance of the dice (the distributions that govern the users) it could be surpassed, and memory will need to be resized. This eliminates the possibility of an arena: this simulation is conceived as an _any parameter input_ therefore using an arena might lead to really fast Out-of-Memory errors when the current config can perfectly fit in memory.

The problem with the General Purpose Allocator is the `SMPAllocator` implementation. The `SMPAllocator` is a high performance `ReleaseFast` mode allocator, which works ---very simplified--- in the following manner:
- if the structure being allocated is less than 64KB, it allocates a Slab, which counts as a virtual memory area, or VMA for short.
- if the structure surpasses the 64KB, the allocator will `mmap` the whole structure in its own VMA, letting them have a very high speed area for itself.

To run the simulation multiple times multithreading has been implemented: the main thread allocates once both the parameters and the topology, and it shares it with the spawned threads. Then, every subthread will load the full simulation state in memory, which are all the variables that can change between runs. The structure is shown in @code-simstate.

#code(caption: flex-caption([The `SimState` struct.], [The `SimState` struct (`src/SimState.zig`): the per-worker mutable state, a `MultiArrayList(User)` plus the post store. Everything else ---parameters and topology--- is shared read-only with the main thread.]))[
  ```zig
  pub const User = struct {
      id: u32,
      is_online: bool,
      session_gen: u32,
      num_posts: u32,
      session_start_time: f64,
      liked_posts: Set(u32),
      reposted_posts: Set(u32),
      timeline: UserTimeline,
  };

  users: MultiArrayList(User),
  posts: SegmentedMultiArrayList(Post, 16),
  ```
] <code-simstate>

Now is when the problem starts playing: to make the runs time feasible, we augment the number of workers of the simulation to a number that makes sure not to make the server run out of memory. In the 100K case, the configuration is 12 workers, 100 runs, making the whole run be under an hour. The problem is that Linux limits the maximum number of memory mappings per process with the kernel variable `vm.max_map_count`, and a lot of the user timelines get bigger than 64KB, having a VMA for themselves. Therefore, $100.000 times 12 = 12 times 10^6 > "vm.max_map_count"$, and the process gets killed without ever finishing.

Therefore, to maintain both the memory growth under control an arena must not be used, but if we use the only general purpose allocator we cannot parallelize as much as the server allows us. The solution is then, to use another memory allocation strategy: the jemalloc allocator.

Jemalloc @jemalloc is a FreeBSD @freebsd implementation of an allocator which has the best of both an arena/fixed buffer allocator and a general purpose allocator by, per thread, storing different sizes of memory chunks, allowing resize to a bigger memory one and reuse of past one by new allocations. We can holistically understand them as a thread having preallocated a big chunk of memory, then split into fixed buffer allocators of different sizes, and having clever logic introduced to know which ones are reusable or need to be freed.

Jemalloc is of course written in C, but this is also Zig's speciality. By using its amazing C-interoperability, we can statically link #footnote[Statically link is to compile Jemalloc apart from the simulation targeting the proper OS and architecture, and then providing the "executable"`jemalloc.a` path to the simulation binary.] and construct the `Allocator` interface with the `c_allocator` @zig-std-c-allocator and use it as a Zig native construct, involving ---at the time this was done--- a zero code change from the simulation side.

The use of jemalloc allows to bypass the `SMPAllocator` implementation, that while being of a high quality and extremely performant, was not suited for this use case.


== Buffered File I/O
<apx-impl-trace-io>

I/O is the most important feature of the simulation, as the traces are the main method of obtaining the output needed to generalize the results. At the same time, opening and writing to files can be one of the biggest bottlenecks when taking performance into account. 

As well as with memory, a `SYSCALL` is needed to both open a file and to write to it, which interrupts the program execution via a context switch @wiki-context-switch. As an interruption is performance expensive, it is clear that the number of `SYSCALL` to write to file must be reduced. The most efficient way to do that is through the use of a buffer. A buffer is a runtime mutable array of stack memory, with size fixed at compile time. The idea is for every `write` call to be executed immediately ---halting the execution of the program---, but to fill the buffer instead. When the buffer is full, call the `write` call with all the contents inside the buffer, and start reusing the same memory. This procedure is called to `flush` the buffer.

Almost all languages implement printing as an inner buffer, which gets flushed if a newline character is found (`\n`) or if the buffer gets full. 

Zig does not implement automatic flushing. Instead it forces the programmer to create a buffer to store everything that needs to be written to a file, and chose when the `flush()` function should be invoked for that writer (or if the buffer fills up, it will be invoked automatically). This is achieved by the `Io` interface @zig-std-io.

There are five different traces: one per event type, plus the timeline-swap trace. Therefore there are five different file descriptors with 64KB buffers associated to them. They keep filling until they are full, and then when they are, they are flushed to disk. This guarantees very few interruptions, as a 64KB buffer is pretty large especially taking into account the next section performance strategy: the buffers do not contain characters, but bytes of the trace struct (see @sec-design-traces for the different traces) which is going to be much faster and smaller than serializing @wiki-serialization into text, as @apx-impl-config.

Writing raw binary has one obvious drawback however: the resulting trace files are not human readable and need to be deserialized into strings. Zig std provides a JSON API @zig-std-json, which allows conversion between structs and strings without any inconvenience. Therefore, once the simulation has finished, the binary traces are loaded into memory, and using the struct alignment definition, turned into the original `TraceType` struct, converted into a JSON with the standard library utility and dumped into a file.

Despite adding a postprocessing computational effort after the simulation finishes, this moves a costly operation (convert the struct into a JSON to write into the buffer) out of the hot simulation loop, the main loop (see @sec-design-lifecycle-main) improving the overall speed.


== Simulation Configuration
<apx-impl-config>

The simulation's behavior is governed by a set of tunable parameters: probability distributions for user actions and inter-event timing, the simulation horizon, whether traces are written to disk, and the random seed. 

The simulation accepts a JSON configuration file at runtime, enabling parameter changes without recompilation of the program. The file defines every tunable quantity: the duration of the simulation, the user behaviour policy, the inter-action time, and whether traces should be written to disk. A loading function reads the file into memory and parses it, checking that the imposed format is correct while deserializing it into a `SimConfig` struct.

#code(caption: flex-caption([JSON configuration example.], [Example JSON configuration (subset of the full schema; illustrative, not calibrated)]))[
  ```json
  {
    "seed": null,
    "horizon": 1000,
    "inter_action_time": {
      "exponential": {
        "mean": 3
      }
    },
    "user_policy": {
      "categorical": {
        "weights": [0.50, 0.30, 0.20 ],
        "data": [ "ignore", "like", "repost" ]
      }
    },
    "trace_to_file": true,
  }
  ```
] <code-json-config>

The configuration file contains a flat set of top-level fields. Each field that represents a probability distribution — such as `"user_policy"` and `"inter_action_time"` in the example — is a nested object whose first key identifies the distribution family. The parser uses this key to select the correct Zig type: `"categorical"` produces a `Categorical`, `"exponential"` an `Exponential`, `"pareto"` a `Pareto`, and so on. Whatever arguments the distribution expects (weights and data for categorical, mean for exponential) are placed inside that same object.

The parsing of the distributions is a simple parser implemented using the lower-level JSON scanner API @zig-std-json, which enforces every defined rule, as limiting the `user_policy` to a categorical distribution, or all the time distributions to continuous distributions.

=== Runtime Dynamic Distribution Dispatch 

Being able to achieve a generic JSON configuration file pays a performance penalty, as the program has to decide from which of the stated distributions to sample when `inter_action_time.sample()` is executed. This is called Runtime dynamic dispatch ---it happens while the program is running---, serving from multiple options dynamically, and it's a form of polymorphism. This is achieved internally by the distributions library the simulation depends upon with the generic type `DiscreteDistribution` and `ContinuousDistribution` as seen in @code-simconf.

#code(caption: flex-caption([The `SimConfig` struct.], [The `SimConfig` struct. Each distribution field uses a generic wrapper type — not a concrete distribution — so any valid distribution from the JSON can occupy the same field at runtime.]))[
  ```zig
  pub const SimConfig = struct {
      seed: ?u64,
      horizon: f64,
      user_policy: DiscreteDistribution(f64, Action),
      inter_action_time: ContinuousDistribution(f64),
      trace_to_file: bool,
  };
  ```
] <code-simconf>

The two generic wrapper types are tagged unions (`union(enum)`) internally, over all supported distributions. Each variant holds a concrete distribution struct inline. The dispatch itself uses Zig's `inline else` ---a compile-time generated `switch` that expands into a branch over every union variant. The cost per `.sample()` call, as seen in @code-inline-switch, is a single predicted branch over the enum tag. The tagged union achieves the ergonomics of runtime dispatch ---the JSON picks the distribution at runtime--- with only a single predicted branch as overhead.

#code(caption: flex-caption([The `inline else` dispatch in `UnionDist.zig`.], [The single-line `inline else` switch that dispatches `.sample()` across all union variants. At compile time this expands into a branch for each distribution type — no vtable needed.]))[
  ```zig
  pub fn sample(self: *const Self, rng: Random) Precision {
      switch (self.*) {
          inline else => |*dist| return dist.sample(rng),
      }
  }
  ```
] <code-inline-switch>

In less technical computer science words: every time `sample()` is called on the configuration file, a switch to know which distribution should be sampled is executed, and then the `sample()` method from the proper distribution is called.

== Input and Output Data
<apx-impl-topology>

While @apx-impl-config describes how the simulation is parameterized, this section covers the data the simulation operates on: the network of users and their follower relationships. 

Versions 1 to 3 of the simulation read the Topology as a JSON file, synthetically generated following the Amin & Choi et al. @amin2022scalefree algorithm. The problem with loading a big structure from a "human readable" format is the penalty of serialization/deserialization.

#def(name: "Serialization/Deserialization")[Serialization is the process of converting a data structure or object into a storable format. Deserialization is the opposite process.]

The problem of loading a file into a structure is, therefore, a deserialization problem. When reading a human readable format ---all of those that store information with strings--- two deserializations must be performed: from string to binary, and from binary into the structure. Then, whenever performance needs to be maximized, the non readable formats should be prioritized, such as parquet and raw binary.

The Forest Fire sampler (described in @apx-topology) outputs the sampled subgraph as Apache Parquet files: `nodes.parquet` (user integer IDs), `induced_edges.parquet` (all edges between sampled nodes as `actor_id`–`subject_id` pairs), and `burned_edges.parquet` (the traversal path). These are columnar, compressed files that can be read efficiently by data analysis tools but pose a problem for a systems-language simulation: Zig has no Parquet reader library.

Despite the author willingness to create software from scratch (@soler2025eazyargs, @soler2025distributions), to code a competent parquet reader is out of scope for this project. Despite some workarounds to give Zig a Parquet reader (import the DuckDB driver as a C++ cross compiled library) they involve a lot of extra code and a dependency, so we write a Python preprocessing script, which reads the parquet, converts all the user ids into monotonically increasing integers, for the simulation to use them directly as array indexes, and writes a binary file with the layout described in @code-binary-layout

#code(caption: flex-caption([Binary layout of `network.bin`.], [Binary layout of `network.bin`. All integers are little-endian `u32`.]))[
  ```
  u32  num_users
  u32  user_ids[num_users]
  u32  num_edges
  u32  edges[num_edges * 2]   // actor_id, subject_id interleaved
  ```
] <code-binary-layout>

The Zig side reads this file into a `Topology` struct via `std.Io.takeInt(u32, .little)` calls to build the CSR adjacency and allocate per-user data structures. In essence, Parquet files are binary files with the structure described as the first bytes of the file, in order to make all of the contents readable. In our simpler version, we just know that the format the binary is stored is exactly the one defined here.

== Traces Output

Following from the previous section, the trace output is clearly a serialization problem. Traces are stored as different structures according to the event they represent, showing the action struct as an example in @code-action-trace.


#code(caption: flex-caption([The `TraceAction` struct.], [The `TraceAction` struct written to disk on every user action. Each field is a flat scalar — 7 fields, 40 bytes total — enabling direct binary I/O without serialization overhead.]))[
  ```zig
  pub const TraceAction = struct {
      time: f64,      // 8 bytes
      event_id: u64,  // 8 bytes
      gen_id: u64,    // 8 bytes
      user_id: u32,   // 4 bytes
      post_id: u32,   // 4 bytes
      parent_id: u32, // 4 bytes
      type: e.Action, // 1 byte
      // total: 37 bytes + 3 padding = 40 bytes (@sizeOf)
  };
  ```
] <code-action-trace>

The simulation outputs five traces — the four event traces described in @sec-design-traces, plus the timeline-swap trace — and every trace is written twice, as a binary and as a JSONL file. This is to avoid paying the serialization task in the hot loop of the simulation. As explained in @apx-impl-trace-io, each trace has a different buffer, and to fill that buffer with a readable human format implies spending CPU cycles to serialize binary into a JSON representation of the struct. Those happen once every time the loop gets executed, which interrupts the flow of the program.

To avoid this, the serialization to a human readable format happens after the simulation has finished and as a postprocessing step in the same program. In this context a Zig native parquet SerDes would be an advantage: the only reason to make the program force this step is to avoid losing the information if the original structure changes, which in development could happen fairly often. The main advantage of parquet over raw binary reading and writing is that parquet also stores the header, making it independent from the original structures: a simple change such as swapping the order of the fields `time` and `event_id` would break a hardcoded parser, as the encoding for an `f64` is vastly different for a `u64`.

The binary traces are also used by the `construct-cascade` importing the traces file as an external dependency, avoiding the hardcoding problem, but not guaranteeing retrocompatibility.

== Core Data Structures
<apx-impl-datastructures>

This section complements the design data structures section in @sec-design-datastructures with more implementation detail, focusing on the non-std based structures.

To properly understand the next section, a small introduction to the concept of cache and cache locality will be given. If the reader already knows this, please jump to @apx-impl-queue.

#def(name: "Cache")[ A cache @wiki-cache is a hardware or software component that stores data so future requests can be served faster. ]

Modern CPUs feature a multi-level cache hierarchy —-typically L1, L2, and L3 caches— with sizes and latencies that vary by generation and microarchitecture @drepper2007memory. When a CPU needs to operate on data in memory, it first checks the L1 cache. If the data resides there, the operation proceeds at maximal speed; this is called a cache hit. If the data is absent —-a cache miss—- it must be fetched from a slower level (L2, L3) or directly from main memory, which is orders of magnitude slower.

As Drepper @drepper2007memory details, the gap between CPU speed and memory latency has widened so dramatically that modern computing is effectively memory-bound: the CPU spends most of its cycles waiting for data, not computing on it. This is the root of the optimizations that follow: design data structures that keep the cache populated with the right data, so the CPU rarely stalls.

A CPU loads data into the cache in fixed-size blocks called cache lines. On modern x86-64 processors, a cache line is 64 bytes @drepper2007memory. This seemingly small architectural detail has profound implications: if a data structure fits multiple elements within a single cache line, the CPU loads them all in one fetch. If elements are scattered across memory, each access triggers a separate, expensive fetch.

Data structures designed around this constraint —-cache-friendly structures—- execute orders of magnitude faster because they minimize cache misses and keep the CPU pipeline fed @drepper2007memory. This is what we are going to call cache locality:

#def(name: "Cache Locality")[A data structure that takes cache locality into account is one that makes sure that it is easily loadable in cache lines (as contiguous as possible) and can be split among the different caches in a reasonable way.]

All the performance extracted with the data structures is thanks to using cache locality.

=== Queue: N-ary Heap
<apx-impl-queue>

Despite the Zig standard library having a `PriorityQueue` data structure @zig-std-priority-queue working as a heap, a new from-scratch queue has been implemented for the simulation. The reasoning is that the Zig implementation defaults to a binary leaf implementation, which underutilizes cache lines.

A heap is normally built over an `ArrayList` —-a non-fixed-size growable dynamic array—- and uses the array indexes to represent a tree, rebalanced with `sift-down` and `sift-up` methods on insertion and deletion @cormen2022algorithms. Theoretically this data structure is sufficient, but binary heaps struggle with cache locality: each level of the tree spans a different memory region, so traversing from root to leaf may touch a different cache line at every step. By increasing the branching factor ---using an $n$-ary heap instead of a binary one--- more siblings fit within a single 64-byte cache line @drepper2007memory, reducing the number of cache misses during sift operations @cormen2022algorithms.

#figure(
  cetz.canvas({
    import cetz.draw: *

    // Define styling for the nodes
    let node-style = (radius: 0.1, fill: black, stroke: none)

    // ── Level 1 (Root) ──
    circle((0, 0), name: "root", ..node-style)

    // ── Level 2 & 3 (4-ary split) ──
    for i in range(4) {
      // Calculate X position for the 4 intermediate nodes
      let x2 = -3.0 + (i * 2.0)
      let name2 = "L2_" + str(i)
      
      circle((x2, -1.5), name: name2, ..node-style)
      line("root", name2)

      // 4 leaves per intermediate node
      for j in range(4) {
        // Calculate X position for the 16 leaves, centered under their parent
        let x3 = x2 - 0.6 + (j * 0.4)
        let name3 = "L3_" + str(i) + "_" + str(j)
        
        circle((x3, -3.0), name: name3, ..node-style)
        line(name2, name3)
      }
    }
  }),
  caption: [A minimalist three-level 4-ary tree.]
) <fig-simple-tree>

The global queue executes with an 8-ary tree, that means for a same size three $n$ given that accessing the children of the tree node is given by $O(log_d n)$, it means that visiting an arbitarty node needs $1/3$ less of accesses than a binary one.

==== Memory Heuristics

Analyzing the simulation, a good heuristic can be given to upper bound the maximum number of elements in the Future Event Set $Q$. An online user will have no more than four events enqueued at any time, which are:
- The next scheduled `action` event.
- The next scheduled `creation` event.
- The `session.end` event.
- A `propagate` after the create or an `action.repost`.

If the user is offline, it will also have four events at most:
- A stale `action` event.
- A stale `creation` event.
- A stale `propagate` event.
- The `session.start` event.

The $4N$ upper bound on queue occupancy derived in @sec-design-datastructrues-queue (four events per user at any instant) is used to preallocate the heap's backing array: `ensureTotalCapacity(gpa, 4 * N)` is called once at startup, eliminating reallocation entirely during the simulation run. This is the same preallocation strategy discussed in @apx-impl-memory, applied to the single hottest data structure in the engine.

A discussion of alternative queue data structures — which would achieve $O(1)$ amortized access through bucketed time-slicing — is deferred to @sec-future.


=== Timelines: Dual Stack

The user timeline $cal(T)_t (u)$, as a reverse chronological timeline, is the textbook definition of a Stack @cormen2022algorithms: a LIFO queue. One would think that a heap is more _correct_ as it compares time of post repost, but in reality all posts are appended exactly in the order they arrive, therefore the exact timestamp of the repost is not needed to sort this out. This makes both `push` and `pop` $O(1)$, in contrast with the heap explained in the last section, where `push` involves `siftUp` and `siftDown`, making them $O(log n)$

The `ds-bskysim` repository contains a light wrapper over the `std.ArrayList` to make it behave as a stack.

Regarding the specific implementation behaviour, some details must be mentioned to understand how a refresh ---and how the simulation keeps track of the posts in the background while the user is scrolling--- is performed. In design, the refresh (see @sec-design-sources, @proc-action-handle) involves updating $t$ to the current time $t_c$, but the implementation realizes this via a double-stack per user:
- *Active*: the stack the user pops from while scrolling. It holds posts visible within the current session window.
- *Background*: the stack where all incoming propagated posts land, regardless of whether the user is online, offline, or mid-scroll.

A refresh is therefore a swap of the background and active stacks — the accumulated backlog becomes the new visible window, and the drained active becomes the new passive sink. This cleanly separates the posts being consumed from the posts arriving in real time, and avoids the need to filter a single heap by arrival timestamp on every pop. 


=== Graph Topology: Compressed Sparse Row
<apx-impl-csr>

As established in @sec-design-datastructures-topology, the static follower graph maps cleanly onto a Compressed Sparse Row representation: the graph is unchanging, the adjacency matrix is sparse, and CSR provides $O(1)$ range lookup with $O("degree")$ iteration ---all argued in the design chapter. Here we show the concrete Zig realization. The @code-topology-struct shows how CSR materializes in the `Topology` and `User` structs.


#code(caption: flex-caption([The `Topology` and `User` structs (v4).], [The `Topology` and `User` structs as they exist in the final version: the two CSR arrays live in `Topology`, while the per-user mutable state lives in `SimState` (see @code-simstate).]))[
  #columns(2)[
  
    ```zig 
    // src/Topology.zig
    pub const Topology = struct {
        nodes: u32,
        edges: u32,
        csr: []u32,   // flat adjacency
        start: []u32, // row pointer
    };
    ```
    
    #colbreak()
    
    ```zig 
    // src/SimState.zig
    pub const User = struct {
        id: u32,
        is_online: bool,
        session_gen: u32,
        num_posts: u32,
        session_start_time: f64,
        liked_posts: Set(u32),
        reposted_posts: Set(u32),
        timeline: UserTimeline,
    };
    ```

  ] 
] <code-topology-struct>

The CSR layout replaces per-node adjacency lists with two flat arrays:

- `csr: []u32` — a single contiguous slice containing all follower relationships in the graph, packed densely with no gaps. That's the adjacency matrix of the graph. 
- `start: []u32` — the row pointer array: `start[i]` is an integer offset pointing into `csr` where user $u_i$'s follower block begins.

The end of a user's follower block is implicitly the `start` of the *next* user. To iterate over user $u_i$'s followers, it's just a matter of knowing where the followers of this user start (`topology.start[i]`), when they end (`topology.start[i + 1]`, or `topology.csr.len` for the last user) and then access those ids in the array, as shown in @code-neighbors-example.

#code(caption: flex-caption([Showcasing neighbour iteration for user i.], [Showcase of accessing the neighbors of the i-th user]))[
  ```zig
  const start_idx = topology.start[user_id];
  const end_idx = if (user_id + 1 < state.users.len)
      topology.start[user_id + 1]
  else
      @as(u32, @intCast(topology.csr.len));
  const count = end_idx - start_idx;
  const followers = topology.csr[start_idx .. start_idx + count];
  ```
] <code-neighbors-example>

This is exactly the standard CSR `row_ptr` pattern: the `start` array serves as the row pointer, and `csr` is the column index array (the adjacency matrix has no values beyond the existence of an edge, so the values array is omitted).

Constructing the `topology` struct, each user's followers are first collected into temporary `ArrayList`s. A second pass computes running offsets: the first user gets `start[0] = 0`, the second gets `start[1] = 0 + deg(u_1)`, and so on. The temporary lists are then `memcpy`'d into the `csr` slice at their computed offsets and freed, leaving only the two flat arrays.

During a propagation storm —-when a popular user reposts-— the simulation must deliver a post to thousands of followers. With CSR, this iteration is a single slice over `csr[start..end]`: contiguous memory, one cache line after another, zero pointer dereferences @drepper2007memory. The memory cost of the row pointer is a single `u32` per user in the `start` array, and the total memory for edges is exactly $2 dot |E|$ bytes (two `u32` values per edge, since the end is implicit).

=== Users: Struct of Arrays
<apx-impl-users>

The `User` entity defined in @sec-design-entities contains attributes with very different access patterns, and it's not a small struct. In the Object-Oriented paradigm, the default layout for a collection of entities is an Array of Objects, which in Zig would be an Array of Structs (AoS): a contiguous sequence where each element is a full `User` with all its fields packed together, such as `users: []User`. This is intuitive for human reasoning but catastrophically bad for CPU cache utilization when the struct is large and the access pattern is selective.

Consider the `User` struct shown in @code-topology-struct. Besides the scalar fields, it embeds two hash-set containers (`liked_posts`, `reposted_posts`) and the dual-stack `timeline`, which pushes the struct well past the size of a single cache line even before counting the heap-allocated contents #footnote[A secondary benefit is that SoA eliminates internal struct padding. In AoS, the compiler inserts padding bytes between fields of different sizes to satisfy alignment requirements — a `bool` followed by a `u32` wastes 3 bytes. These gaps further reduce the number of structs per cache line. SoA sidesteps this entirely: all `bool`s are tightly packed together, all `u32`s are tightly packed together, with padding only at array boundaries.]
. A typical L1 cache line is 64 bytes @drepper2007memory. With AoS, a single cache line does not even hold one complete `User` — parts of every user spill across multiple lines. When the simulation iterates over all users to check `is_online` (a 1-byte field), each access loads the whole struct into cache, only to read one byte and evict the rest. The fields the loop actually needs —-the hot fields-— are dragged along with cold data such as the interaction sets and the timeline container metadata, which are not touched during the online check.

The solution is the Structure of Arrays (SoA) pattern. Rather than storing `[User0, User1, ...]` as contiguous structs, each field gets its own contiguous array: all `id`s together, all `is_online` flags together, and so on. Zig's `MultiArrayList(User)` @zig-std-multi-array-list implements exactly this: internally it is a collection of per-field slices.

Note that the per-user behaviour distributions ---`session_duration`, `inter_session_time`, `inter_creation_time` and `offset_creation_time`--- no longer live inside `User`: they are sampled once per user at startup into a separate `MultiArrayList(UserParams)` ---holding `NonNegativeContinuousDistribution(f32)` and `ECDF(f32, f32)` values--- stored in the shared arena and reused read-only by every worker and every run. The per-user state only holds what changes during a run.

#code(caption: flex-caption([Struct of Array representation for `User`.], [Struct representation of what the Struct of Array is for the `User` concrete example. Each field becomes a separate contiguous array; the container fields keep their heap-allocated contents off the SoA arrays.]))[
  ```zig
  const Users = struct {
    ids:               []u32,          // N × 4 bytes, contiguous
    is_online:         []bool,         // N × 1 byte,  contiguous
    session_gen:       []u32,          // N × 4 bytes, contiguous
    num_posts:         []u32,          // N × 4 bytes, contiguous
    session_start_time:[]f64,          // N × 8 bytes, contiguous
    liked_posts:       []Set(u32),     // interaction history, heap-backed
    reposted_posts:    []Set(u32),     // interaction history, heap-backed
    timeline:          []UserTimeline, // dual-stack timelines, heap-backed
  }
  ```
] <code-multiarrays>

The access syntax reflects this layout: `users.items(.is_online)[i]` indexes into the `is_online` array at position `i`. This is the same pattern seen in the CSR iteration at @code-neighbors-example, where `topology.start[i]` reads the offset for user $i$. The dot-parenthesis syntax is Zig's way of selecting which field array to index.

This pattern is cache-friendly by construction @drepper2007memory. A 64-byte cache line fits 64 `bool` flags from the `is_online` array. When the simulation checks whether user 0 is online, the CPU loads the flags for users 0 through 63 in a single fetch. The next 63 checks hit L1 cache. With AoS, accessing 64 `is_online` flags would require at least 64 cache line loads, one per struct.  
Hot fields — `is_online`, `session_gen`, `num_posts`, `session_start_time` — are accessed on every event. Cold fields — the interaction sets and the timeline containers — are only touched when the user acts on a post or scrolls. SoA ensures that hot loops never pay the memory cost of loading cold data, and cold paths never pollute the cache with hot flags they do not need.


=== Impressions: Set
<apx-impl-impressions>

The impression and interaction matrices $cal(E)$ and $cal(H)$ — central to the CTIC desensitization check (see @sec-design-sources-propagate) — are modelled in @sec-design-datastructures-engaged as a set data structure. The implementation realizes this via the `ziglang-set` @ziglang-set package, backed by a `AutoHashMapUnmanaged` @zig-std-hash-map implementation. 

In handleAction @proc-action-handle, when a post is popped from the user timeline, it is checked that it has not been reposted before by that specific user with the `contains` method, which is constant cost depending on the load of the hashmap. Then, when a new post is reposted or liked, it is added with the `addAssumeNotIn` method, skipping the "is the element already in the set" check.

As a partial tangent, the check of whether or not a post has already been interacted with by a certain user is more optimal to be checked in the handleAction procedure @proc-action-handle when popping the posts rather than in the propagatePost procedure @proc-propagate: combined with the grand majority of users having few elements in $cal(T)_t (u)$ plus an $O(1)$ pop cost, the comparison is far more performant, and very high degree users would make the propagate-side comparison especially costly.

Both `reposted_posts` and `liked_posts` implement a set with these characteristics, representing the interaction history $cal(H)$ from the design model (see @sec-design-dm-state).


=== Posts: SegmentedMultiArrayList
<apx-impl-posts>

As posts do not have content in the simulation, they need not to be stored as they do not need to be retrieved. Despite the fact, the first version of the simulation conceived them with content, and therefore the structure described in this section is in the simulation, but no post is ever pushed. 

Post creation is unbounded as the simulation runs, therefore a way is needed to store them without requiring continuous memory as in an `ArrayList`: the pagination. Pagination is the strategy of splitting the memory in pages, and retrieving them by accessing the correct page. This is also known as the Library data structure, where the array (the library) is split in bookshelves (the pages) and each bookshelf contains books (the posts), and by sorting the books alphabetically or by theme (modulo the `post_id`) we can access the correct shelf and book without looking through all the books the library has.

The idea is then clear: by dividing the post id we can know in which page it is, and which element of the array it is. That involves two divisions, and on modern x86-64 CPUs, a 64-bit integer division (`div`) takes anywhere from 20 to 80 cycles, depending on the operand values and the microarchitecture @agner2024instruction. A bitwise shift (`shr` / `shl`) or a bitwise AND (`and`) takes exactly 1 cycle -—-integer division is among the most expensive single operations a CPU can perform, while bitwise arithmetic is essentially free. If we set the capacity $C$ to a power of two, $C = 2^n$:

$ "page" = floor(i / C) = i >> n quad text(and) quad "offset" = i % C = i \& (C - 1) <==> C = 2^n quad n in NN $ <eq-binary-division>

Where $>>$ is a bit-shift operation and $\&$ is the bitwise `AND` operation. The @code-pow2-indexing uses the bookshelf metaphor explained in the previous paragraph.

#code(caption: flex-caption([Power-of-two indexing for SegmentedMultiArrayList and PagedBitSet.], [The power-of-two indexing used by `SegmentedMultiArrayList` and `PagedBitSet`. The shelf (page) is found by shifting right $n$ bits; the book (offset) is found by masking with $C - 1$.]))[
  ```zig
  const shelf_count = @as(usize, 1 << n);    // C = 2^n
  const shelf       = i >> n;                // i / C,  1 cycle
  const book        = i & (shelf_count - 1); // i % C,  1 cycle
  ```
] <code-pow2-indexing>

The shift discards the $n$ low bits, effectively computing $floor(i / 2^n)$. The mask keeps only those same $n$ low bits — since `shelf_count - 1` is a bitmask of $n$ consecutive ones — computing $i mod 2^n$. No divider, no conditional, no branch misprediction.


Each shelf holds exactly $2^n$ `Post` elements. When shelf $k$ fills up, shelf $k+1$ is allocated — a small, constant-time allocation that never touches the existing shelves. Indexing uses the bitwise shift-and-mask from @code-pow2-indexing: $O(1)$ access with zero reallocation overhead.

Additionally, it also preserves the Structure-of-Arrays layout described in @apx-impl-users. Each shelf is internally a `MultiArrayList`, so fields like `author_id` and `timestamp` are stored in separate contiguous arrays even within a shelf. If posts eventually carry heavy fields like `[1536]f32` NLP embeddings, those large arrays never pollute the cache when the simulation iterates over lightweight fields.

==== Post ID Assignment

A scheduling quirk arises with dynamic creation: a post might be scheduled in the event queue as $(u, "create", p_"id", t)$, but because events can be dropped or skipped, the ID predicted at schedule time might not align with the actual ID when the event fires. To solve this, scheduled creates are assigned a placeholder ID of `0` in the queue, and are strictly assigned their true, globally unique ID only at the exact moment the event is actually processed.

== Parallelism by Multithreading
<apx-impl-parallelism>

To be able to run the maximum amount of runs with the available hardware, multithreading has also been implemented to simultaneously run the same configuration. Before the slightly technical explanation, I must introduce the definitions of concurrency, parallelism and asynchrony, extracted from Loris Cro's article "Asynchrony is not Concurrency" @cro2023asynchrony:

#def(name: "Asynchrony")[the possibility for tasks to run out of order and still be correct.]
  
#def(name: "Concurrency")[the ability of a system to progress multiple tasks at a time, be it via parallelism or task switching]

#def(name: "Parallelism")[the ability of a system to execute more than one task simultaneously at the physical level]

The simulation implements parallelism via the `Io.Threaded` @zig-std-io interface, as can be seen in @code-multithreading.

#code(caption: flex-caption([Multithreaded launch in `src/main.zig`.], [Worker launch and per-worker batch execution in `src/main.zig`. The topology and parameters are shared read-only across threads; every worker owns its `SimState`, which is reset between runs keeping its capacity.]))[
  ```zig
  fn launchWorkers(gpa, topology, sim, seed, workers, total_runs, run_dir, ...) !void {
      var threaded: Io.Threaded = .init(gpa, .{});
      defer threaded.deinit();
      const tio = threaded.io();

      var futures = try gpa.alloc(@TypeOf(try tio.concurrent(simulationBatch, undefined)), workers);
      for (0..workers) |i| {
          futures[i] = try tio.concurrent(simulationBatch, batch_args);
      }
      for (0..workers) |i| {
          try futures[i].await(tio);
      }
  }

  fn simulationBatch(gpa, tl_alloc, topology, simparams, config, run_dir, ...) !void {
      var aa: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
      defer aa.deinit();
      const arena = aa.allocator();

      var state: SimState = try .create(arena, gpa, tl_alloc, topology);
      defer state.delete(arena, gpa, tl_alloc);

      var prng: Random.DefaultPrng = .init(config.seed);
      for (0..config.runs) |i| {
          // per-run seed: the base seed is mixed with the run index
          const run_seed = config.seed +% std.hash.Wyhash.hash(0, std.mem.asBytes(&run_idx));
          prng.seed(run_seed);

          // run the simulation and write the traces...

          state.reset(); // capacity is kept, no reallocation between runs
      }
  }
  ```
] <code-multithreading>


Therefore, the topology and the parameters are in the shared thread memory and every thread can access it via pointer, without loading the data per worker. The `SimState` is different per every single worker of the simulation, as different executions have different states; it is also reset but with maintained capacity between runs to not reallocate it from scratch every time. 

== Trace Validation
<apx-impl-validation>

Guaranteeing correctness in a discrete-event simulation implementation is not self-evident nor trivial: several small mishaps can compromise behaviour ---and therefore the results--- without crashing the engine. To catch these failures, a standalone Python script — `python-utilities/validate_trace.py` independently verifies the output traces against a set of logical invariants. The script is fully decoupled from the simulation binary: it reads the JSONL traces produced by the binary-to-text conversion step (see @apx-impl-trace-io). It has no dependency on Zig or the simulation engine.

The validation rules fall into two categories.

==== Per-file structural Checks
Each of the four trace files needs to verify the following facts:

- *Time monotonicity*: timestamps are strictly non-decreasing within each file. A single backwards time step, which would indicate a queue ordering bug, fails the entire validation.
- *Unique event IDs*: no `event_id` appears more than once within a trace file. Duplicate event IDs signal a bug in the global event counter.
- *No duplicate posts* (`create_trace`): each `post_id` is created exactly once. A repeated `post_id` means the post counter was not advanced correctly.
- *No double reposts* (`action_trace`): a `(user_id, post_id)` pair cannot appear as a repost more than once, enforcing the CTIC invariant that a user interacts with a given post at most once.
- *Session alternation* (`session_trace`): for each user, `start` and `end` events strictly alternate — no two consecutive starts or ends. A violation indicates a session scheduling bug.

*Cross-file checks.* Once per-file validation passes, the script loads all four traces and performs two global checks:

- *Global `gen_id` uniqueness*: the `gen_id` field (the random seed generation identifier) must be unique across all four trace files. A collision means the same PRNG state was reused across runs, violating statistical independence.
- *Causality*: the script reconstructs the timeline of every user by merging session and action events, then verifies the following two rules: 
  1. a user must be online at the moment they perform any action (no offline interactions), and 
  2. the timestamp of any action on post $p$ must be greater than or equal to the timestamp at which $p$ was created (no time travel). A violation of either rule is a hard failure.

This validation suite not only serves as a validation for a run, but also as test suite: any change to the simulation code can be checked by re-running a known-good configuration and validating the output traces. During development, the validator caught several subtle bugs —-stale events slipping past the session guard, propagation events scheduled before post creation, and several time travelling propagations-— that could have gone unnoticed in aggregate metrics alone.
