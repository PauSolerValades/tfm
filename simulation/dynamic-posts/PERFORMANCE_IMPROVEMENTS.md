# HPC Performance Improvements for dynamic-posts

Here is an HPC-focused performance analysis of the `dynamic-posts` simulation codebase. Several critical issues exist—some are standard optimizations, but others are **silent performance killers** that will destroy the CPU cache, leak massive amounts of memory, or bottleneck execution for large networks.

Here are the most critical improvements ordered by impact:

### 2. 🚨 Routing "Seen Posts" through the Global Event Queue
**File:** `src/simulation.zig` (Line ~295)  
**The Issue:** Inside the `.action` branch, if a user pops a post from their timeline and has already seen it (`graph.user_seen_post.isSet(...)`), the loop skips the post but **schedules a new `.action` event with a time delay and pushes it into the global event queue.** If a user has 1,000 seen posts in their timeline, they will make 1,000 expensive round-trips through the $O(\log N)$ global priority queue just to ignore them!  
**The Fix:** Use a `while` loop to drain the timeline inline until an *unseen* post is found, and only then schedule the next action event:
```zig
var found_post: ?Index = null;
while (graph.timelines[current_uid].items.len != 0) {
    const p = graph.timelines[current_uid].remove();
    if (!graph.user_seen_post.isSet(current_uid, p.post_id)) {
        found_post = p.post_id;
        break;
    }
}
// process found_post or handle empty timeline
```

### 3. 🚨 O(Degree) Push Propagation bottleneck
**File:** `src/simulation.zig` (Line ~123 `propagatePost`)  
**The Issue:** When a post propagates, the code iterates over every single follower and pushes the event into their individual `TimelineHeap`. For a "celebrity" node with 1,000,000 followers, one propagation event triggers 1,000,000 $O(\log T)$ heap insertions and potential dynamic memory allocations. This is a classic HPC graph bottleneck.  
**The Fix:** 
- **Short term:** Do not use `Heap` for timelines. Pushing to a flat `ArrayList` and using `std.sort` *only when the user comes online* is often much faster due to sequential memory access and vectorized sorting.
- **Long term:** Shift to a "Pull" or "Hybrid" model where users dynamically pull from their followees' outboxes when they come online, completely eliminating the $O(N)$ push.

### 4. Passing Large Structs by Value on the Hot Path
**File:** `src/simulation.zig` (`eventAction`, `eventSessionStart`, etc.)  
**The Issue:** Functions like `eventAction` and `eventPropagate` take `simconf: SimConfig` by value. `SimConfig` is a massive struct containing multiple random distributions (`ContDist`, `DiscDist`), which usually have significant state or lookup tables. Passing this by value into every event generation triggers a massive stack copy (hundreds of bytes) in the tightest loop of the Discrete Event Simulation (DES).  
**The Fix:** Change the signature to take a pointer: `simconf: *const SimConfig`.

### 5. `Event` Struct Size & Memory Alignment
**File:** `src/entities.zig`  
**The Issue:** The `Event` struct is quite large (likely 40+ bytes due to `EventType` union tagging, `f64` time, and multiple `u64` fields). Priority Queue operations (sinking/swimming) constantly swap these structs in memory.   
**The Fix:** Compress this struct to exactly 32 bytes so that exactly two events fit into a standard 64-byte L1 cache line:
- Downcast `session_gen` to `u32`.
- Turn `EventType` into a simple `tag: u8` and `payload: u32` (holding either `post_id`, `Action` enum, etc.) to eliminate standard union padding.

### 6. I/O Virtual Function Calls and Struct Padding 
**File:** `src/main.zig` & `src/simulation.zig`  
**The Issue:** The simulation calls `try action_trace.writeAll(...)` passing an `*Io.Writer`. In Zig, this is a pointer to an interface (type erasure), which forces a dynamic vtable dispatch for *every single trace event*. Additionally, `std.mem.asBytes(&a)` writes the raw memory of the struct, which includes uninitialized padding bytes (e.g., between the `Action` byte and `Index` u32). This bloats file sizes by ~20% and wastes disk bandwidth.  
**The Fix:** 
- Use a `packed struct` for trace structs, or sort fields manually from largest (8 bytes) to smallest (1 byte) to completely eliminate padding.
- Pass the actual buffered writer type as a generic/comptime parameter to `simulate` to allow devirtualization and inline formatting.

### 7. Branching on `trace_to_file` in the Core Loop
**File:** `src/simulation.zig`  
**The Issue:** The `if (simconf.trace_to_file)` check evaluates at runtime inside the tightest `.action`, `.propagate`, and `.create` loops.   
**The Fix:** Pass `trace_to_file` as a `comptime trace: bool` parameter to the `simulate` function. The compiler will completely dead-code eliminate the trace-building and I/O logic when tracing is disabled, providing a perfectly clean hot path.

### 8. The Global Priority Queue (Standard DES Bottleneck)
**File:** `src/simulation.zig`   
**The Issue:** A single binary `Heap` is used for the global event queue. As `N` scales to millions of events, the depth of the binary tree causes guaranteed cache misses on every `queue.remove()` sink operation.  
**The Fix:** Upgrading the binary heap to a **4-ary heap** (d-ary heap) usually yields a free 20-30% performance boost by making nodes more cache-line aligned. For true HPC scaling, look into Calendar Queues or Hierarchical Timing Wheels.

---
**Bonus Logic Check:** In `eventAction`, the code uses `simconf.user_policy.sample(rng)` instead of the user's specific policy stored in `graph.users.items(.policy)[current_uid]`. If user behavioral heterogeneity was intended, this bypasses it entirely!
