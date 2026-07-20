#import "utils.typ":  def, code, flex-caption //todo, comment,
#import "@preview/cetz:0.4.2"

This chapter details the concrete engineering decisions that realize the simulation design described in @sec-design. While the previous chapter established what the simulation models and why specific algorithmic choices were made, this chapter addresses how those choices are realized in code: the performance strategies, the input/output pipeline, and the data structures that make the simulation scale to millions of users within practical execution times. 

== Technology Approach 
<sec-design-techology>

Because the validity of any simulation can rely on sheer computational volume and repeated runs to achieve statistical significance, a suboptimal implementation can easily contradict the underlying assumptions needed to guarantee a successful process. Execution speed, deterministic behavior, and the tightly optimized computational loops mentioned above are paramount. 

The first step in achieving this explicit memory control is choosing the appropriate tools for the job. Interpreted languages like Python @python and R @rlang are immediately discarded. Even on powerful hardware, the overhead of interpretation introduces unacceptable latency for massive, CPU-bound simulation loops. Moreover, they do not offer control over memory allocation---the most critical performance killer, since any garbage collector memory strategy will affect performance greatly. This is also why the excellent performance of Julia is discarded: despite being fast, its garbage collector introduces the same fundamental limitation. Following this logic, manual memory management becomes necessary to deeply optimize performance and take full advantage of CPU caching. With requirements pointing strictly toward a systems language with manual memory management, the engine was implemented in Zig @zig.

Zig is a modern systems programming language selected specifically for its deterministic memory management and seamless support for Data-Oriented Design (DOD) (see @sec-impl-memory). By design, it provides C-like performance alongside modern quality-of-life improvements and strict guardrails against common C pitfalls, such as segmentation faults and null pointer dereferences. With the application of the right memory optimization techniques (see @sec-impl-memory), Zig enables highly scalable implementations that extract the maximum possible performance from the hardware.

More information about software is documented in @apx-software-stack.


== Versioning  
<sec-impl-version>

To build a simulation engine from scratch in a systems level programming language is a relatively heavy undertaking, so a the following implementation strategy was followed from the beginning of the project to guarantee a successful result. The plan responds to the following maxima: small prototyping and iteration. So, to arrive at the final state of the simulation, three previous versions have been developed so far.

==== v1: Cronological Order and max posts per user

The first version served as a proof of concept implementation and design, and was where most of the needed utilities but not part of the main program were developed, such as the Heap implementation, the _distributions_ library with the Exponential, Normal and Categorical implementation, as well as the runtime dynamic dispatch JSON config file, in order to iterate quickly with the parameters, as explained in 

The first version did not even aim to implement the same behaviour as the final product. In there, was assumed that user timelines were min-heaps, not max-heaps, so the simulation was serving posts in chronological order, not reverse-chronological order. To simplify it even further, the users were assumed to be homogeneous and behave all equally. In essence, this simplifications allowed to test the propagate behaviour, as well as the essential architecture of the DES simulation with a very similar data structures as the final version will end up having.

The first version of the network topology loading and wiring was introduced here, as well as the scripts to generate some sample ones to validate it. Furthermore, none of the strategies discussed later in this section where applied here, being very noticeable the poor performance when loading and wiring the topology.

==== v2: Reverse-Chronological Order and Sessions

To change every user timeline into a max-heap was the most complicated part of all the process implementation, for every user now had to disconnect from the simulation for their timeline to be refilled. That introduces plenty of bugs and misbehaviors with time traveling errors such a repost made to a post before the post arrived to a user timeline; the propagate event was introduced to isolate those bugs, as the old mechanism directly inserted posts into the user timelines ---was nor a very good idea nor a good design decision.

Here some DOD principles were applied, specially when wiring the graph topology structure, as the reading data format was redesigned. 

==== v3: Unilimited Posts and Refactor

When the core functionalities of the simulation was build, the Pagination was introduced to allow an unlimited number of posts per user, while maintaining all the other features. 

Some additional mechanics were introduced at this version, such as notifications (allowed a user to do an interaction while offline) or quoting (two posts where appeared at the user timeline) but were dropped due to scope and design reasons.

Lastly, a small effort to refactor and improve performance was made, introducing different memory allocators depending on the task (see @sec-impl-memory), rewriting suboptimal code an tiding up the codebase.

==== v4: Evaluation release

Contains the same features of the v3 simulation with optimizations to be run multiple times. Those optimizations are:
1. Dropping the JSON simulation configuration structure to avoid the VTable dereferences. The config struct is manually set to the parameters defined in @sec-calibration-summary.
2. Always logging the trace, avoiding several branching if conditions at runtime.
3. Trace folder renaming, to parallelize the runs across multiple processes.

== Memory Allocation Strategies
<sec-impl-memory>

Every program needs memory where to hold the data it operates on. Every program has two types of memory: 
- *Stack*: is all allocated by the OS when the program starts. Functions and variables are stored there.
- *Heap*: Memory not reserved by default, but given on request to the programmer with the use of certain functions; in C would be `malloc, callor, realloc`, and this mechanism is hidden in non memory managed languages, such as Python.

As the simulation needs to hold a massive amount of data, the need of heap memory is the only way forward. Every new memory allocation is a `SYSCALL` @wiki-syscall, which will imply program execution halting to get the reserved addresses of memory back, which is an unavoidable part of the program: getting the memory addresses to work. What is a far worse performance concern is the reallocation of memory. Let's take C `malloc` vs `realloc` functions.

`malloc` will return a pointer to a chunk of contiguous memory, ready for the program to use. Imagine we want to store an array of 32 unsigned integers (each of which has a size of 4 bytes) on to the heap, we can ask `malloc` for $32·4 = 128$ bytes of memory with a `SYSCALL`, and the OS will provide that to use, in a contiguous manner. Now, the list contained 40 numbers, instead of 32, so we have to ask for more memory, with the requisite we still want the previous memory to be contiguous with the new one. Now we have to call `realloc` to give us 32 more integers (as good principled programmers ask the memory in powers of two...), to get a $64 · 4 = 256$ bytes. The catch is that `realloc` will make sure the memory is still contiguous, so when reallocating the memory one of two things can happen:
1. Good path: the OS just extends previous memory to 64 integers without problem, as the next 128 byte chunk was empty.
2. Bad path: the next 128 byte chunk is not empty, therefore the OS needs to search for a 256 bytes of contiguous memory in another part of the memory, copy all the previous numbers and return the new address of memory.


Performance wise, one would think that the rule of thumb would be to try to avoid the bad path, and go for the good path. That is half right, as there are situations where you must ask for more memory. But the optima is to try to never ask the OS for more memory by choosing a clever memory allocation strategy.

In Zig, Heap memory is managed with `Allocators`, and each of them follows different memory strategies, and will be more or less suited in different situations. The main two used in the simulation are the following:
+ *General Purpose Allocator*: reserves memory in a linear and contiguous fashion. Requires an interruption of the program execution for the kernel to provide the memory addresses. Can be resized if there is free memory adjacent to the allocation. It's the `malloc` and `realloc` equivalent in C.
+ *Arena Allocator*: reserves a large pool of memory (just one `SYSCALL`), and controls which portion of the memory is used by just incrementing an offset. As the whole memory is already allocated upfront, very few kernel interruptions to ask for more memory are needed during execution. 
@zig-std-heap


In the simulation, Arenas are perfectly fit for the data loading and the graph topology storage, as it's big data unchanged at runtime.

In _v3_, the JSON containing all the distinct users and their followers is loaded in its entirety in an arena, `json_arena`. Then, the information is used to create an instance of `Topology` struct, which creates the CSR representation of the graph (see @sec-impl-csr), as well as having as much memory needed for all the specific user information, as explained in user entity on @sec-design-entities. Once the `Topology` struct is created with a different arena, we deinit `json_arena` to have that memory free for another uses, as the JSON topology is not needed anymore.

The main disadvantages of arenas are resizing and growing. When an item gets freed from an arena it is not freed as returning it back to the OS, but the offset of the arena grows. Freeing a lot can lead to fragmentation issues as well as resizing overhead, at to resize an entire arena is time consuming for the OS.

In the simulation, everything that is not managed by an arena is managed by a standard `Allocator`. All data structures that cannot have an estimation of how many elements will require beforehand, are used with a General Purpose Allocator, such as the $T (u)$ timeline heaps. These structures grow and shrink as events are processed and sessions start and end, as well as changing a lot depending on the config file _e.g_ the load of the timeline $T (u)$ is not going to be the same with an `inter_action_time` of 5 second between any post that a on of 1 second between any post. 

Despite assuming that memory reallocation is necessary, there are strategies to mitigate it the most. For the global heap, an heuristic has been computed (see @sec-impl-queue) to have more than enough memory to use; for every user timeline, a capacity of `1024` timeline events is assumed, so unless the queue needs more, it will never reallocate memory. That these heuristics are possible does not imply that is a good idea the use of an arena, as they might need resizing, which in an arena would be catastrophic performance wise.

== Buffered File I/O
<sec-impl-trace-io>

I/O is the most important feature of the simulation, as the traces are the main method of obtaining the output needed to generalize the results. At the same time, opening and writing to files can be one of the biggest bottlenecks when taking performance into account. 

As well as with memory, a `SYSCALL` is needed to both open a file and to write to it, which interrupts the program execution via a context switch @wiki-context-switch. As an interruption is performance expensive, it is clear that the number of `SYSCALL` to write to file must be reduced. The most efficient way to do that is through the use of a buffer.

A buffer is an array of stack memory, with compile time fixed size. The idea is, instead of every `write` call to be fired immediately, fill the buffer. When the buffer is full, call the `write` call with all the contents inside the buffer! This is called to `flush` the buffer.

Almost all languages implement printing as an inner buffer, which gets flushed if a newline character is found (`\n`) or if the buffer gets full. 


Zig lets the programmer choose between a streaming I/O (the system decides when to write) or buffered I/O, which allows the programmer to create a buffer where to store everything that needs to be written to a file, and when the `flush()` function is invoked it interrupts the program flow, writes to file and resumes execution @zig-std-io.

There are four different traces, one per event, therefore there are four different file descriptors with 64KB buffers associated to them. They keep filling until they are full, and then when they are, they are dumped into memory. This guarantees very few interruptions, as a 64KB buffer is pretty large especially taking into account the next section performance strategy: the buffers do not contain characters, but bytes of the trace struct (see @sec-design-traces for the different traces) which is going to be much faster and smaller than serializing @wiki-serialization into text, as @sec-impl-config.

Writing raw binary has one obvious drawback however: the resulting trace files are not human readable and need to be deserialized into strings. Zig std provides with a JSON api @zig-std-json, which allows conversion between structs and strings without any inconvenient. Therefore, one the simulation has finished, the binary traces are loaded into memory, and using the struct alignment definition, tuned into the original `TraceType` struct, converted into a JSON with the standard library utility and dumped into a file.

Despite adding a postprocessing computational effort after the simulation finishes, this moves a costly operation (convert the struct into a JSON to write into the buffer) out of the hot simulation loop, the main loop (see @sec-design-lifecycle-main) improving the overall speed.

== Simulation Configuration
<sec-impl-config>

The simulation's behavior is governed by a set of tunable parameters: probability distributions for user actions and inter-event timing, the simulation horizon, whether traces are written to disk, and the random seed. How these parameters reach the simulation engine changed across versions — from a flexible JSON file resolved at runtime (v1–v3) to hardcoded calibration constants compiled directly into the binary (v4). This section traces that evolution and explains the dispatch mechanism that made runtime configuration possible.

=== JSON Dynamic Configuration (v1–v3)

The first three versions of the simulation accepted a JSON configuration file at startup, enabling parameter changes without recompilation. The file defines every tunable quantity: the duration of the simulation, the user behaviour policy, the inter-action time, and whether traces are written to disk. A loading function reads the file into memory and deserializes it into a `SimConfig` struct — the exact mechanism is standard JSON parsing and not particularly relevant to the simulation itself; what matters is the schema it enforces.

#figure(kind: "code", supplement: [Code], caption: flex-caption([JSON configuration example.], [Example JSON configuration (subset of the full schema; illustrative, not calibrated)]))[
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

`"user_policy"` must resolve to a discrete distribution — either a `Categorical` over the `Action` enum or an empirical CDF. `"inter_action_time"` must resolve to a continuous distribution — Exponential, Normal, Uniform, or Pareto. Any other key is rejected at startup with a parse error.

=== Distribution Dispatch via VTable

The JSON schema is only half the story. The other half is how the `distributions` library makes a single `SimConfig` struct hold *any* distribution without knowing at compile time which one will be chosen. The JSON example above deserializes into:

#figure(kind: "code", supplement: [Code], caption: flex-caption([The `SimConfig` struct.], [The `SimConfig` struct. Each distribution field uses a generic wrapper type — not a concrete distribution — so any valid distribution from the JSON can occupy the same field at runtime.]))[
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

The library provides two generic wrapper types: `ContinuousDistribution` and `DiscreteDistribution`. Internally they are thin unions over all supported distributions, backed by a VTable — a table of function pointers, one per operation (`.sample()`, `.init()`, `.deinit()`). Every concrete distribution exports a vtable with its own implementations.

The supported distribution families are:

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Type*], [*Wrapper*], [*Available distributions*],
    table.hline(stroke: 0.5pt),
    [Continuous], [`ContinuousDistribution(f64)`], [Exponential, Normal, Uniform, Pareto, Erlang, Hyperexponential, Hypoexponential, Constant, ECDF],
    [Discrete], [`DiscreteDistribution(f64, T)`], [Categorical, ECDF],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Supported distribution families in the `distributions` library.],
    [Supported distribution families in the `distributions` library. The continuous wrapper unifies nine distributions behind a single `.sample(rng)` interface; the discrete wrapper unifies two. The JSON parser maps the distribution name (e.g., `"exponential"`) to the corresponding concrete type.],
  )
) <tbl-dist-types>

When the JSON parser encounters `"exponential"`, it constructs an `Exponential` and wraps it inside a `ContinuousDistribution` whose vtable points to the Exponential's `.sample()` function. From that point on, the simulation only ever calls `.sample(rng)` on the wrapper — it never knows which concrete type sits behind it. The same field could hold a Pareto in one run and a Normal in the next, decided entirely by the JSON file.

This is runtime dynamic dispatch: the distribution is chosen after compilation, with no need to recompile for a parameter change. The cost is one pointer dereference per `.sample()` call — the vtable lookup. In the hot simulation loop, where `.sample()` is called tens of millions of times, this overhead is measurable.

=== v4 Configuration Strategy

The evaluation release (v4) drops the JSON config file and its vtable dispatch in favor of compiled-in constants. The motivation is performance: eliminating one pointer dereference per `.sample()` call in the hot simulation loop, where `.sample()` is invoked tens of millions of times.

Version 4 replaces the JSON config file with a hand-written `calibrate()` function that constructs every distribution directly in Zig source code (see @sec-calibration-summary for the calibrated values). The `SimConfig` struct uses typed fields — `Exponential(f64)`, `Pareto(f64)`, `Categorical(f64, Action)` — instead of generic `ContinuousDistribution` / `DiscreteDistribution` wrappers. The compiler resolves all distribution calls statically, eliminating the vtable pointer dereference entirely. The trade-off is that changing a parameter now requires recompilation — acceptable for the evaluation phase, where the parameters are fixed to the empirical calibration and the simulation is run hundreds of times with identical configuration.

Trace output follows the same philosophy: binary writes replace text serialization, as discussed in @sec-impl-trace-io.



== Input Data
<sec-impl-topology>

While @sec-impl-config describes how the simulation is parameterized, this section covers the data the simulation operates on: the network of users and their follower relationships. The topology is the simulation's world model — it defines who can see whose posts and therefore determines every propagation path through the system.

=== Topology JSON Format

The simulation consumes a single JSON file describing the network topology, decoupled from the simulation configuration. The schema has two top-level arrays:

- `users[]`: each entry specifies a user `id`, a list of `actions` (string labels for the actions the user can perform), a `policy` (probability vector aligned with the actions list), and an optional `max_posts` cap. Under the homogeneous-user assumption, all user policies are identical, but the schema permits heterogeneity for future use.
- `followers[]`: each entry defines a directed edge with `follower_id` and `followed_id`. The graph is directed: a follower sees the posts of the users they follow.

#figure(kind: "code", supplement: [Code], caption: flex-caption([Example topology JSON fragment.], [Example topology JSON fragment (illustrative).]))[
  ```json
  {
    "users": [
      { "id": 0, "actions": ["ignore", "like", "repost"], "policy": [0.5, 0.3, 0.2] },
      { "id": 1, "actions": ["ignore", "like", "repost"], "policy": [0.5, 0.3, 0.2] }
    ],
    "followers": [
      { "follower_id": 1, "followed_id": 0 },
      { "follower_id": 0, "followed_id": 1 }
    ]
  }
  ```
] <code-topology-json>

=== Synthetic Data Generation

The simulation relies on synthetic topologies generated by a Python script, `generate_data.py`. Since real-world social network data at the target scale is not publicly available in a clean format, a synthetic generator based on the Barabási-Albert preferential attachment model @barabasi1999emergence was extended with a configurable clustering mechanism @amin2022scalefree. This approach was chosen because it produces the two structural features most relevant to information diffusion on a single pass: a heavy-tailed degree distribution (a few hubs, a long tail of low-connectivity users) and tunable local clustering (tight-knit communities that amplify multi-hop propagation). Running the model without these properties would produce either uniform-degree graphs (missing the influencer dynamic entirely) or tree-like graphs (no clustering, no cyclic reinforcement), both of which would invalidate the cascades analysis.

Once the graph is built, the script assigns homogeneous user policies and action probabilities to every node, then serializes the result to the JSON format described above. The process is parameterized by the number of nodes, the number of edges per new node, and the clustering probability, making it straightforward to generate topologies at different scales for performance benchmarking and sensitivity analysis.

The data generation and the simulation are fully decoupled: the same simulation binary accepts any compliant JSON topology, whether synthetic or derived from real-world data.

=== Parquet Loading Pipeline

The Forest Fire sampler (described in @apx-topology) outputs the sampled subgraph as Apache Parquet files: `nodes.parquet` (user integer IDs), `induced_edges.parquet` (all edges between sampled nodes as `actor_id`–`subject_id` pairs), and `burned_edges.parquet` (the traversal path). These are columnar, compressed files that can be read efficiently by data analysis tools but pose a problem for a systems-language simulation: Zig has no native Parquet reader.

There is exactly one realistic path to reading Parquet from Zig: linking the DuckDB C driver @duckdb, which provides a full Parquet ingestion engine. This would introduce a large external dependency into the simulation binary — DuckDB is an in-process analytical database, not a lightweight I/O library — and would couple the engine's build system to a particular Parquet implementation and its transitive `C++` toolchain. Rather than absorb that complexity, the simulation opts for an offline preprocessing step. A Python script, `release-v4/parquet_to_bin.py`, reads the Parquet files using `pyarrow` and serialises the relevant fields into a flat, headerless binary file. This file is then read directly by the Zig simulation using only the standard library's buffered I/O — no external dependencies, no system calls beyond the initial `open`.

The resulting `network.bin` uses a simple little-endian layout with no header:

#figure(kind: "code", supplement: [Code], caption: flex-caption([Binary layout of `network.bin`.], [Binary layout of `network.bin`. All integers are little-endian `u32`.]))[
  ```
  u32  num_users
  u32  user_ids[num_users]
  u32  num_edges
  u32  edges[num_edges * 2]   // actor_id, subject_id interleaved
  ```
] <code-binary-layout>

The Zig side reads this file into a `BinaryGraph` struct via `std.Io.takeInt(u32, .little)` calls — no parsing, no deserialisation overhead. The `BinaryGraph` is then consumed by `Topology.create()` to build the CSR adjacency and allocate per-user data structures, after which the `BinaryGraph` and its allocator arena are immediately freed.

This two-step pipeline — Python for format conversion, Zig for high-performance loading — keeps the simulation binary self-contained while remaining compatible with any data source that can produce the same binary layout. The same approach is used for calibrated parameters: Pareto shape/scale coefficients are pre-computed in Python and stored as plain text files read at startup via `fillPareto()`.


== Core Data Structures
<sec-impl-datastructures>

This section complements the design data structures section is @sec-design-datastructures with more implementation detail, with more focused on all the non std based structures.

To properly understand the next section, the concept of cache and cache locality must be introduced.

#def(name: "Cache")[ A cache @wiki-cache is a hardware or software component that stores data so future requests can be stored faster. ]

Modern CPUs feature a multi-level cache hierarchy —-typically L1, L2, and L3 caches— with sizes and latencies that vary by generation and microarchitecture @drepper2007memory. When a CPU needs to operate on data in memory, it first checks the L1 cache. If the data resides there, the operation proceeds at maximal speed; this is called a cache hit. If the data is absent —-a cache miss—- it must be fetched from a slower level (L2, L3) or directly from main memory, which is orders of magnitude slower.

As Drepper @drepper2007memory details, the gap between CPU speed and memory latency has widened so dramatically that modern computing is effectively memory-bound: the CPU spends most of its cycles waiting for data, not computing on it. This is the root of the optimizations that follow: design data structures that keep the cache populated with the right data, so the CPU rarely stalls.

A CPU loads data into the cache in fixed-size blocks called cache lines. On modern x86-64 processors, a cache line is 64 bytes @drepper2007memory. This seemingly small architectural detail has profound implications: if a data structure fits multiple elements within a single cache line, the CPU loads them all in one fetch. If elements are scattered across memory, each access triggers a separate, expensive fetch.

Data structures designed around this constraint —-cache-friendly structures—- execute orders of magnitude faster because they minimize cache misses and keep the CPU pipeline fed @drepper2007memory. This is what we are going to call cache locality:

#def(name: "Cache Locality")[A data structure friendly into account cache locality is one that makes sure that its easily loadable in cache lines (as contiguous as possible) and can be split in the different caches in a reasonable way.]

All the performance extracted with the data structures is thanks to using cache locality.

=== Queue & Timeline: N-ary Heap
<sec-impl-queue>

@zig-std-priority-queue
Despite Zig standard library having a `PriorityQueue` data structure working as a heap, a new from scratch queue has been implemented for the simulation. The reasoning is that the Zig implementation defaults to a binary leaf implementation, which underutilizes cache lines on modern hardware.

A heap is normally built over an `ArrayList` —-non fixed size growable dynamic array—- and uses the array indexes to represent a tree, rebalanced with `sift-down` and `sift-up` methods on insertion and deletion @cormen2022algorithms. Theoretically this data structure is sufficient, but binary heaps struggle with cache locality: each level of the tree spans a different memory region, so traversing from root to leaf may touch a different cache line at every step. By increasing the branching factor —-using an $n$-ary heap instead of a binary one—- more siblings fit within a single 64-byte cache line @drepper2007memory, reducing the number of cache misses during sift operations @cormen2022algorithms.

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

The global queue executes with a 8-leaf tree, that means for a same size three $n$ given that accessing the children of the tree node is given by $$ that means visitng this amount less of leafs.

==== Memory Heuristics

The $4N$ upper bound on queue occupancy derived in @sec-design-datastructrues-queue (four events per user at any instant) is used to preallocate the heap's backing array: `ensureTotalCapacity(gpa, 4 * N)` is called once at startup, eliminating reallocation entirely during the simulation run. This is the same preallocation strategy discussed in @sec-impl-memory, applied to the single hottest data structure in the engine.

A discussion of alternative queue data structures — which would achieve $O(1)$ amortized access through bucketed time-slicing — is deferred to @sec-future.

=== Graph Topology: Compressed Sparse Row
<sec-impl-csr>

As established in @sec-design-datastructures-topology, the static follower graph maps cleanly onto a Compressed Sparse Row representation: the graph is unchanging, the adjacency matrix is sparse, and CSR provides $O(1)$ range lookup with $O("degree")$ iteration — all argued in the design chapter. Here we show the concrete Zig realization. The @code-topology-struct shows how CSR materializes in the `Topology` and `User` structs.


#code(caption: flex-caption([Topology and User Struct from v4.], [Topology and User Struct from v4]))[
  #columns(2)[
  
    ```zig 
      pub const Topology = struct {
        users: MultiArrayList(User),
        followers: []u32,
        timelines: []TimelineHeap, 
        posts: SMAList(Post, 16), 
        user_seen_post: PagedBitSet(16),
        user_interacted_post: PBitSet(16),
    }
    ```
    
    #colbreak()
    
    ```zig 
    pub const User = struct {
      id: u32,
      follower_start: u32,
      is_online: bool = false,
      session_gen: u32 = 0,
      session_duration: Pareto(f64),
      inter_session_time: Pareto(f64),
      inter_creation_time: Pareto(f64),
      num_posts: u32 = 0,
      session_start_time: f64 = 0.0,
    };
    ```

  ] 
] <code-topology-struct>

The CSR layout replaces per-node adjacency lists with two flat arrays:

- `followers: []Index` — a single contiguous slice containing all follower relationships in the graph, packed densely with no gaps. That's the adjacency matrix of the graph. 
- `follower_start: Index` inside each `User` -—-an integer offset pointing into `followers` where that user's follower block begins.

The end of a user's follower block is implicitly the `follower_start` of the *next* user in the `MultiArrayList`. To iterate over user $u_i$'s followers, it's just a matter as knowing where the followers of this user start (`User.follower_start`), when they end `topology.users.items(.follower_start)[i+1]` and then access those ids in the array, as showed in @code-neighbors-example.

#code(caption: flex-caption([Showcasing neighbour iteration for user i.], [Showcase of accessing the neighbors of the i-th user]))[
  ```zig
  const start = users.items(.follower_start)[i];
  const end   = users.items(.follower_start)[i + 1];
  const count = end - start;
  const my_followers = followers[start .. start + count];
  ```
] <code-neighbors-example>

This is exactly the standard CSR `row_ptr` pattern: the `follower_start` array serves as the row pointer, and `followers` is the column index array (the adjacency matrix has no values beyond the existence of an edge, so the values array is omitted).

Constructing the `topology` struct , each user's followers are first collected into temporary `ArrayList`s. A second pass computes running offsets: the first user gets `follower_start = 0`, the second gets `follower_start = 0 + deg(u_1)`, and so on. The temporary lists are then `memcpy`'d into the `followers` slice at their computed offsets and freed, leaving only the two flat arrays.

During a propagation storm —-when a popular user reposts-— the simulation must deliver a post to thousands of followers. With CSR, this iteration is a single slice over `followers[start..end]`: contiguous memory, one cache line after another, zero pointer dereferences @drepper2007memory. The per-user cost of storing an adjacency list is reduced to a single `u32` (`follower_start`), and the total memory for edges is exactly $2 dot |E|$ bytes (two `u32` values per edge, since the end is implicit).

=== Users: Struct of Arrays
<sec-impl-users>

The `User` entity defined in @sec-design-entities contains attributes with very different access patterns, and it's not a small struct. In the Object-Oriented paradigm, the default layout for a collection of entities is an Array of Objects, which in Zig would be an Array of Structs (AoS): a contiguous sequence where each element is a full `User` with all its fields packed together, such as `users: []User`. This is intuitive for human reasoning but catastrophically bad for CPU cache utilization when the struct is large and the access pattern is selective.

Consider the `User` struct shown in @code-topology-struct. It contains an `id`, a `follower_start`, several `bool`/`u32` scalar fields, and three `Pareto(f64)` distribution objects — roughly $approx 200$ bytes in total, without taking struct alignment into account #footnote[A secondary benefit is that SoA eliminates internal struct padding. In AoS, the compiler inserts padding bytes between fields of different sizes to satisfy alignment requirements — a `bool` followed by a `u32` wastes 3 bytes, and a `Pareto(f64)` may require 8-byte alignment. These gaps further reduce the number of structs per cache line. SoA sidesteps this entirely: all `bool`s are tightly packed together, all `u32`s are tightly packed together, with padding only at array boundaries.]
. A typical L1 cache line is 64 bytes @drepper2007memory. With AoS, a single cache line holds at most $floor(64 / 200) = 0$ complete users — in practice, parts of one user spill across multiple lines. When the simulation iterates over all users to check `is_online` (a 1-byte field), each access loads a full 200-byte struct into cache, only to read one byte and evict the rest. The fields the loop actually needs —-the hot fields-— are dragged along with cold data like the Pareto distribution parameters, which are never touched during the online check.

The solution is the Structure of Arrays (SoA) pattern. Rather than storing `[User0, User1, ...]` as contiguous structs, each field gets its own contiguous array: all `id`s together, all `follower_start`s together, all `is_online` flags together, and so on. Zig's `MultiArrayList(User)` @zig-std-multi-array-list implements exactly this: internally it is a collection of per-field slices.

#code(caption: flex-caption([Struct of Array representation for `User`.], [Struct representation of what the Struct of Array is for the `User` concrete example. Each field becomes a separate contiguous array.]))[
  ```zig
  const Users = struct {
    ids:               []Index,       // N × 4 bytes, contiguous
    follower_starts:   []Index,       // N × 4 bytes, contiguous
    is_online:         []bool,        // N × 1 byte,  contiguous
    session_gen:       []u32,         // N × 4 bytes, contiguous
    session_duration:  []Pareto(f64), // N × 16 bytes, contiguous
    inter_session_time:[]Pareto(f64), // N × 16 bytes, contiguous
    inter_creation_time:[]Pareto(f64),// N × 16 bytes, contiguous
    num_posts:         []u32,         // N × 4 bytes, contiguous
    session_start_time:[]f64,         // N × 8 bytes, contiguous
  }
  ```
] <code-multiarrays>

The access syntax reflects this layout: `users.items(.is_online)[i]` indexes into the `is_online` array at position `i`. This is the same pattern seen in the CSR iteration at @code-neighbors-example, where `users.items(.follower_start)[i]` reads the offset for user $i$. The dot-parenthesis syntax is Zig's way of selecting which field array to index.

This pattern is cache-friendly by construction @drepper2007memory. A 64-byte cache line fits 64 `bool` flags from the `is_online` array. When the simulation checks whether user 0 is online, the CPU loads the flags for users 0 through 63 in a single fetch. The next 63 checks hit L1 cache. With AoS, accessing 64 `is_online` flags would require at least 64 cache line loads (one per 200-byte struct spread across $approx 4$ lines each).  
Hot fields — `is_online`, `session_gen`, `num_posts`, `session_start_time` — are accessed on every event. Cold fields — the three Pareto distributions — are touched only during session initialization. SoA ensures that hot loops never pay the memory cost of loading cold data, and cold initialization never pollutes the cache with hot flags it does not need.

=== Power-of-Two Indexing
<sec-impl-pow2>

@zig-std-multi-array-list @zig-std-dynamic-bit-set

Two of the simulation's core data structures —-the `SegmentedMultiArrayList` that stores posts and the `PagedBitSet` that tracks impressions-— share a common trick that eliminates the single most expensive integer operation from their indexing paths: integer division. Both are thin wrappers around standard library building blocks: `SegmentedMultiArrayList` paginates Zig's `std.MultiArrayList` into fixed-capacity shelves, and `PagedBitSet` paginates `std.DynamicBitSetUnmanaged` into fixed-width pages. The pagination logic in both relies on the same bitwise identity.

On modern x86-64 CPUs, a 64-bit integer division (`div`) takes anywhere from 20 to 80 cycles, depending on the operand values and the microarchitecture @agner2024instruction. A bitwise shift (`shr` / `shl`) or a bitwise AND (`and`) takes exactly 1 cycle —-integer division is among the most expensive single operations a CPU can perform, while bitwise arithmetic is essentially free. 

Both structures exploit the same algebraic identity to identify the page a post is in and in which position of the page: when the capacity $C$ is a power of two, $C = 2^n$:

$ "page" = floor(i / C) = i >> n quad text(and) quad "offset" = i % C = i \& (C - 1) <==> C = 2^n quad n in NN $ <eq-binary-division>

Where $>>$ is a bit-shift operation and $\&$ is the bitwise `AND` operation. The @code-pow2-indexing uses the bookshelf metaphor used in @sec-design-datastructrues-post to @eq-binary-division.

#code(caption: flex-caption([Power-of-two indexing for SegmentedMultiArrayList and PagedBitSet.], [The power-of-two indexing used by `SegmentedMultiArrayList` and `PagedBitSet`. The shelf (page) is found by shifting right $n$ bits; the book (offset) is found by masking with $C - 1$.]))[
  ```zig
  const shelf_count = @as(usize, 1 << n);    // C = 2^n
  const shelf       = i >> n;                // i / C,  1 cycle
  const book        = i & (shelf_count - 1); // i % C,  1 cycle
  ```
] <code-pow2-indexing>

The shift discards the $n$ low bits, effectively computing $floor(i / 2^n)$. The mask keeps only those same $n$ low bits — since `shelf_count - 1` is a bitmask of $n$ consecutive ones — computing $i mod 2^n$. No divider, no conditional, no branch misprediction.

This is why both structures strictly enforce power-of-two capacities: it is not an arbitrary constraint but a deliberate performance decision that turns two address calculations into single-cycle operations. The parameter $n$ is a compile-time constant, so the compiler folds the shift amount and mask directly into the instruction encoding — zero runtime overhead to compute them.

=== Posts: SegmentedMultiArrayList
<sec-impl-posts>

The pagination strategy and the library/shelves/books metaphor are introduced in @sec-design-datastructrues-post. The implementation realizes that design via the `SegmentedMultiArrayList` from the `ds` package, built on the power-of-two indexing described in @sec-impl-pow2.

Each shelf holds exactly $2^n$ `Post` elements. When shelf $k$ fills up, shelf $k+1$ is allocated — a small, constant-time allocation that never touches the existing shelves. Indexing uses the bitwise shift-and-mask from @code-pow2-indexing: $O(1)$ access with zero reallocation overhead.

Additionally, the `SegmentedMultiArrayList` preserves the Structure-of-Arrays layout described in @sec-impl-users. Each shelf is internally a `MultiArrayList`, so fields like `author_id` and `timestamp` are stored in separate contiguous arrays even within a shelf. If posts eventually carry heavy fields like `[1536]f32` NLP embeddings, those large arrays never pollute the cache when the simulation iterates over lightweight fields.

==== Post ID Assignment

A scheduling quirk arises with dynamic creation: a post might be scheduled in the event queue as $(u, "create", p_"id", t)$, but because events can be dropped or skipped, the ID predicted at schedule time might not align with the actual ID when the event fires. To solve this, scheduled creates are assigned a placeholder ID of `0` in the queue, and are strictly assigned their true, globally unique ID only at the exact moment the event is actually processed.

=== Impressions: PagedBitSet
<sec-impl-impressions>

The impression and interaction matrices $cal(E)$ and $cal(H)$ — central to the CTIC desensitization check (see @sec-design-sources-propagate) — are modelled in @sec-design-datastructrues-post as paginated bitsets. The implementation realizes this via the `PagedBitSet` from the `ds` package, applying the same power-of-two indexing from @sec-impl-pow2. The column dimension (posts) is partitioned into pages of $2^n$ columns each; the row dimension (users) is packed bitwise within each page, producing the indexing shown in @code-pagedbitset.

#code(caption: flex-caption([PagedBitSet indexing logic.], [The `PagedBitSet` indexing logic. Finding the page uses the same shift-and-mask pattern as the `SegmentedMultiArrayList`; the bit address within the page packs the user row via an additional shift.]))[
  ```zig
  const page_count  = @as(usize, 1 << n);     // C = 2^n
  const page        = j >> n;                 // which page
  const j_in_page   = j & (page_count - 1);   // column within page
  const bit_index   = (i << n) + j_in_page;   // row-major bit address
  ```
] <code-pagedbitset>

When a post is created beyond the currently allocated pages, `ensureItemCapacity` allocates new pages on demand — each a fresh `DynamicBitSet` sized for $N times 2^n$ bits. Old pages are never resized or copied, so the amortized cost of growth is constant per new post. The `isSet` check — called on every action event to test whether the user has already interacted with the surfaced post — executes three bitwise operations and one memory load: two shifts, one AND, and the bitset lookup. No division, no reallocation, no page table walk.

Both `user_seen_post` and `user_interacted_post` in the `Topology` struct use `PagedBitSet`, representing the exposure history $cal(E)$ and interaction history $cal(H)$ from the design model (see @sec-design-dm-event).

== Trace Validation
<sec-impl-validation>

Guaranteeing correctness in a discrete-event simulation implementation  is not self-evident nor trivial: several small mishaps can compromise behaviour ---and therefore the results--- without crashing the engine. To catch these failures, a standalone Python script — `python-utilities/validate_trace.py` independently verifies the output traces against a set of logical invariants. The script is fully decoupled from the simulation binary: it reads the JSONL traces produced by the binary-to-text conversion step (see @sec-impl-trace-io). It has no dependency on Zig or the simulation engine.

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
