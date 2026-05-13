# HPC Performance Improvements for dynamic-posts

Here is an HPC-focused performance analysis of the `dynamic-posts` simulation codebase. Several critical issues exist—some are standard optimizations, but others are **silent performance killers** that will destroy the CPU cache or bottleneck execution for large networks.

Items marked ~~strikethrough~~ have already been addressed.

---

### 1. 🚨 Routing Already-Interacted Posts through the Global Event Queue
**File:** `src/simulation.zig` (`.action` branch)  
**The Issue:** Inside the `.action` branch, when a user pops a post from their timeline, the code checks `graph.user_interacted_post.isSet(current_uid, post_id)`. If the post was already interacted with (liked or reposted), the loop skips it but **schedules a new `.action` event and pushes it into the global event queue.** Only a single post is popped per event iteration. If a user has 1,000 already-interacted posts stacked at the top of their timeline, they will make 1,000 expensive round-trips through the $O(\log N)$ global priority queue just to drain them.  
**The Fix:** Use a `while` loop to drain the timeline inline until an *unseen, un-interacted* post is found, and only then schedule the next action event:
```zig
var found_post: ?Index = null;
while (graph.timelines[current_uid].items.len != 0) {
    const p = graph.timelines[current_uid].remove();
    if (!graph.user_interacted_post.isSet(current_uid, p.post_id)) {
        found_post = p.post_id;
        break;
    }
}
// process found_post or handle empty timeline
```

### 2. 🚨 O(Degree) Push Propagation Bottleneck
**File:** `src/simulation.zig` (`propagatePost`)  
**The Issue:** When a post propagates, the code iterates over every single follower and pushes the event into their individual `TimelineHeap`. For a "celebrity" node with 1,000,000 followers, one propagation event triggers 1,000,000 $O(\log T)$ heap insertions and potential dynamic memory allocations. This is a classic HPC graph bottleneck.  
**The Fix:** 
- **Short term:** Do not use `Heap` for timelines. Pushing to a flat `ArrayList` and using `std.sort` *only when the user comes online* is often much faster due to sequential memory access and vectorized sorting.
- **Long term:** Shift to a "Pull" or "Hybrid" model where users dynamically pull from their followees' outboxes when they come online, completely eliminating the $O(N)$ push.

### ~~3. Passing Large Structs by Value on the Hot Path~~ ✅ FIXED
**File:** `src/simulation.zig` (`eventAction`, `eventSessionStart`, etc.)  
All event-generation functions and `simulate`/`stageOne`/`initSessions` now take `simconf: *const SimConfig` instead of by value. This eliminates the stack copy of the config struct (which contains multiple distribution objects) in the tightest loops of the DES.

### 4. `Event` Struct Size & Memory Alignment
**File:** `src/entities.zig`  
**The Issue:** The `Event` struct was 40 bytes (`f64` time + tagged union `EventType` + `u32` user_id + `u64` session_gen + `u64` id). Priority Queue operations (sinking/swimming) constantly swap these structs in memory. `session_gen` has been reduced to `u32` (saving 4 bytes, now 36 bytes), but the struct is still not cache-optimal.  
**Remaining fix:** Turn `EventType` into a compact `tag: u8` + `payload: u32` (holding either `post_id`, `Action` enum, etc.) to eliminate standard union padding. Combined with the `u32` session_gen, this would bring the struct to exactly 32 bytes — fitting two events per 64-byte L1 cache line.

### 5. I/O Virtual Function Calls in Trace Writing
**File:** `src/main.zig` & `src/simulation.zig`  
**The Issue:** The simulation calls `try action_trace.writeAll(...)` passing an `*Io.Writer`. In Zig, this is a pointer to an interface (type erasure), which forces a dynamic vtable dispatch for *every single trace event*.  
**The Fix:** Pass the actual buffered writer type as a generic/comptime parameter to `simulate` to allow devirtualization and inline formatting.
> **Note:** The struct padding issue that previously accompanied this item has been fixed — all trace structs (`TraceAction`, `TraceCreate`, `TraceSession`, `TracePropagation`) now have their fields ordered largest-to-smallest, eliminating internal padding that was being written to disk via `std.mem.asBytes`.

### 6. Branching on `trace_to_file` in the Core Loop
**File:** `src/simulation.zig`  
**The Issue:** The `if (simconf.trace_to_file)` check evaluates at runtime inside the tightest `.action`, `.propagate`, and `.create` branches. Even with a discarding writer, the trace structs are still constructed and serialized to bytes.  
**The Fix:** Pass `trace_to_file` as a `comptime trace: bool` parameter to the `simulate` function. The compiler will completely dead-code eliminate the trace-building and I/O logic when tracing is disabled, providing a perfectly clean hot path.

### 7. The Global Priority Queue — Calendar Queue with Static Heuristic
**File:** `src/simulation.zig`

**The Issue:** A single binary `Heap` is used for the global event queue. With `N = 10⁷` users, the queue holds up to `3N = 3·10⁷` events simultaneously (each online user has at most 3 pending events: action, create, session_end). A flattened binary heap causes `log₂(3·10⁷) ≈ 25` pointer-chasing hops per `remove()`, each crossing cache lines. Additionally, heap operations cannot be batched — the simulation performs 2–4 queue operations per processed event (remove + insert next action + insert next create + insert session_end), multiplying the logarithmic cost.

**The Fix: Calendar Queue with a static (non-resizing) heuristic.**

A Calendar Queue replaces the binary heap with a hash-table-like structure: an array of `B` buckets, each covering a time interval of width `b`. Events are placed by `bucket = ⌊event.time / b⌋ mod B`. The queue advances a "current bucket" pointer linearly; within each bucket, events are stored in a short sorted list or min-heap. This exploits the fact that most events are scheduled near each other in time, yielding amortized O(1) operations.

The key insight is that the simulation's constraints allow a **static** configuration — no runtime resizing needed — because three parameters are known a priori:
- **Maximum queue size:** `3N`
- **Bucket budget `B`:** either unconstrained (`B = 2^{⌈log₂(3N)⌉}`, the next power-of-two), or capped by a memory limit `B_max`
- **Average event delay `T_mean`:** the average time an event is scheduled into the future, derived from the simulation's delay distributions

The heuristic:
1. Target density per bucket: `k = 3N / B`
2. Average time gap between any two events in the queue: `T_mean / 3N`
3. Bucket width to hold `k` events: `b = k · (T_mean / 3N) = T_mean / B`

Notice the `3N` terms cancel — the bucket width depends only on the array size and the average delay, not on the user count.

**Example (unconstrained, `N = 10⁷`, `T_mean = 11.92`):**
```
B = 2^{⌈log₂(30,000,000)⌉} = 2²⁵ = 33,554,432 buckets
k = 30,000,000 / 33,554,432 ≈ 0.89 events/bucket
b = 11.92 / 33,554,432 ≈ 3.55×10⁻⁷ time units
Memory: B × 8 bytes = ~268 MB for bucket pointers
```
With `k < 1`, most buckets contain a single event — absolute O(1) retrieval with no list traversal.

**Example (memory-constrained, `N = 10⁶`, 2MB budget):**
```
B_max = 2¹⁸ = 262,144 buckets (2MB)
k = 3,000,000 / 262,144 ≈ 11.4 events/bucket
b = 11.92 / 262,144 ≈ 4.54×10⁻⁵ time units
```
With `k ≈ 11`, each bucket requires a short linear scan, but performance remains excellent within hard memory limits.

---
**⚠️ Caveats to address before implementation:**

**1. `T_mean` must be defined carefully.** The heuristic uses a weighted average of all delay distributions, but the weights (relative frequencies of action, create, session, and propagate events) depend on the simulation dynamics and aren't known a priori. A repost-heavy simulation has many more propagate events than an ignore-heavy one, shifting the effective `T_mean`.

*Mitigation:* Use `T_mean = max(means of all delay distributions)` as a conservative upper bound. This widens buckets slightly (increasing per-bucket list lengths) but guarantees correctness regardless of the unknown event mix. Alternatively, run a short calibration simulation to measure the actual event frequency ratios before the main run.

**2. Propagation cascades cause event time clustering.** When a celebrity reposts, all follower propagate events fire at nearly the same timestamp (`t + propagation_delay`), dumping `M` events into a single bucket. The per-bucket scan degrades to O(M).

*Mitigation:* Use a **min-heap per bucket** instead of a linked list. This keeps intra-bucket operations at O(log M) at the cost of ~24 bytes of heap overhead per bucket. Given that 99% of buckets will have `k < 2` events, this overhead is minimal compared to the global heap it replaces.

**3. Phase-dependent event density.** The warmup phase only generates create events, while the main simulation generates all five event types. The static `b` computed from full-simulation parameters may be suboptimal during warmup.

*Mitigation:* Recompute `B` and `b` at the warmup→main simulation transition. This is a one-time operation with negligible cost.

---
**Implementation outline:**
```zig
const CalendarQueue = struct {
    buckets: []Bucket,        // B pre-allocated buckets
    b: f64,                   // bucket width
    B: u32,                   // number of buckets
    current_bucket: u32,      // current position
    current_time: f64,        // floor of processed time window
    len: usize,               // total events in queue

    fn add(q: *CalendarQueue, gpa: Allocator, event: Event) !void { ... }
    fn remove(q: *CalendarQueue) Event { ... }
};
```

For `N = 10⁷`, this replaces `log₂(3·10⁷) ≈ 25` heap hops with a single array index + short bucket scan, eliminating the cache-miss bottleneck entirely. Pre-allocation also removes all dynamic memory operations from the hot path (no more `gpa` allocations on every `queue.add()`).

---
### 🐛 Bonus Logic Bug: Per-User Policy Never Used
**File:** `src/simulation.zig` (`eventAction`)  
**The Issue:** `eventAction` samples the action from `simconf.user_policy.sample(rng)` — the global homogeneous policy — instead of the user's specific policy stored in `graph.users.items(.policy)[current_uid]`. Each `User` struct carries its own `Categorical` distribution loaded from the network JSON data, but it is **never read during simulation**.  
**The Fix:** Either:
- Pass `current_uid` to `eventAction` and sample from `graph.users.items(.policy)[current_uid]` if per-user behavioral heterogeneity is intended, **or**
- Remove the `policy` field from `User` and the per-user policy loading if global homogeneity is the design goal.
