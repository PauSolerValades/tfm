#import "utils.typ": *

This chapter outlines directions for extending the simulation beyond its current scope, organized into two independent tracks. The first addresses computational performance — removing the remaining bottlenecks that limit scalability to tens of millions of users. The second addresses model fidelity — lifting the simplifying assumptions of content-agnostic, action-independent diffusion to capture the semantic and psychological drivers of real social network behavior.

== Performance Optimizations
<sec-future-performance>

The simulation already applies Data-Oriented Design and buffered I/O to keep the hot loop from stalling (see @sec-impl-performance). Two bottlenecks remain that are structural rather than implementational: the $O(log n)$ cost of the event queue, and the single-threaded nature of trace writing.

=== Pre-Allocated Memory Structure for the Future Event Set

The Event Queue is a well known performance critical point. Event with the precautions taken, a MinHeap might not be enough for scalability into the millions of users, so another more specific data structure could be used.

The current implementation uses a binary heap for the global event queue $Q$ (see @sec-impl-queue). While the heap provides $O(log n)$ operations, the future event set remains the principal bottleneck as the simulation scales toward $N = 10^7$ users. A flattened binary heap stores elements in non-contiguous memory regions, causing cache misses during sift-down operations: loading one tree node does not pre-fetch the next comparison target, stalling the CPU.

With at most $4N$ events simultaneously in the queue and each event requiring two to four heap operations, the actual computational cost is several times the theoretical $log_2(4N) approx 25$ comparisons. The lack of batch insertion in a heap means there is no avenue for amortization.

The solution is a Calendar Queue @brown1988calendar — a bucketed priority queue that achieves $O(1)$ amortized time by distributing events across time slices. Brown originally introduced the Calendar Queue for the simulation event set problem, demonstrating experimental hold times three times shorter than splay trees for 10,000 events. The standard dynamic Calendar Queue resizes its bucket array to maintain optimal density, but the simulation's known parameters (static user count, bounded events per user, known delay distributions) allow a static heuristic to determine the optimal configuration upfront, eliminating all resizing overhead.

==== Heuristic design

This heuristic depends on three simulation characteristics known a priori:
- The static number of users ($N$) and the maximum bounded events per user (yielding a maximum queue size of $4N$).
- The available memory budget, which dictates the maximum number of buckets $B_"max"$.
- The weighted average delay of generated events ($T_"mean_delay"$), derived from the probability distributions of the simulation configuration.

The design requires finding the optimal time width for a single bucket ($b$). A bucket represents a specific time slice $[t, t+b)$, and the time width must be chosen to ensure an optimal average number of events ($k$) land in each bucket.

First, we determine our target density $k$ by dividing the maximum queue size by our fixed memory budget $B_"max"$:

$ k = frac(4N, B_"max") $

In the absence of strict memory constraints, $B$ can simply be defined as the smallest power-of-two capable of fitting all simultaneous events:

$ B = 2^(ceil(log_2(4N))) $

Once $k$ is established, we calculate the bucket width $b$. By dividing the weighted average delay of all events $T_"mean_delay"$ by the total events $4N$, we find the average time gap between any two events in the queue. Multiplying this gap by our target density $k$ yields the optimal bucket time width:

$ b = k dot frac(T_"mean_delay", 4N) $

Notably, if we substitute the definition of $k$ directly into the equation for $b$, the $4N$ terms cancel out, revealing a highly simplified relationship:

$ b = frac(4N, B_"max") dot frac(T_"mean_delay", 4N) = frac(T_"mean_delay", B_"max") $

This demonstrates that the optimal time-slice $b$ is entirely independent of the number of users, dictated strictly by the chosen bucket array size and the simulation's overall event frequency. By configuring the Calendar Queue with a statically allocated array of $B_"max"$ pointers and a bucket width of $b$, the queue achieves stable $O(1)$ performance without ever requiring an array reallocation or bucket width recalculation.

To illustrate the heuristic, we assume the weighted average delay of the simulation events is calculated as $T_"mean_delay" = 11.92$ time units. #text(blue)[TODO: recalcular amb la calibració final]

==== Example 1: Unconstrained Memory (Target $N = 10^7$)

With $10$ million users, the maximum queue capacity is $40,000,000$ events. If memory is unconstrained, we find the next power-of-two for $B$:
$ B = 2^(ceil(log_2(40000000))) = 2^26 = 67108864 "buckets" $
The resulting density $k$ and bucket width $b$ are:
$ k = frac(40000000, 2^26) approx 0.60 "events per bucket" $
$ b = frac(T_"mean_delay", B) = frac(11.92, 67108864) approx 1.78 times 10^(-7) "time units" $
This configuration requires approximately 537 MB of RAM for the bucket pointers. Because $k < 1$, the vast majority of buckets will contain a single event, guaranteeing absolute $O(1)$ retrieval without list traversal.

==== Example 2: Limited Memory (Target $N = 10^6$, Max 2MB RAM)

With $1$ million users, the queue holds up to $4 dot 10^6$ events. The unconstrained $B$ would be $2^23$ (~67 MB). If the system is strictly limited to 2 MB for the queue array, we cap $B_"max"$ at $2^18$ (yielding 262,144 buckets):
$ B_"max" = 2^18 = 262144 "buckets" $
$ k = frac(4000000, 262144) approx 15.26 "events per bucket" $
$ b = frac(11.92, 262144) approx 4.54 times 10^(-5) "time units" $
By restricting the memory, the density $k$ increases to ~15 elements per bucket. While this incurs a small $O(k)$ penalty during insertion as the algorithm scans the short linked list, the performance remains exceptionally fast while strictly adhering to hardware constraints.

==== Example 3: Massive Scale (Target $N = 10^9$)

When scaling to $1$ billion users, the queue capacity reaches $4 dot 10^9$ events. Applying the unconstrained formula yields:
$ B = 2^(ceil(log_2(4000000000))) = 2^32 = 4294967296 "buckets" $
While mathematically optimal for time complexity, allocating an array of $4.29$ billion 8-byte pointers requires $34.3$ GB of RAM exclusively for the Calendar Queue's root array structure. At this massive scale, utilizing a $B_"max"$ constraint becomes virtually mandatory to trade a surplus of RAM for a slightly denser $k$ parameter.

It is important to note that the Calendar Queue and its variants remain an active research topic in the discrete-event simulation literature. The static heuristic proposed above avoids dynamic resizing altogether, but this approach has not been experimentally validated against the original resizing strategy. Furthermore, multi-tiered extensions such as MList and its dynamic-shift variant DSMList @kim2009mlist have been shown to improve performance by at least 20% over standard Calendar Queue implementations by introducing multiple dynamically-allocated calendar queues at different time resolutions. Evaluating which variant — static Calendar Queue, dynamic Calendar Queue, or a multi-tiered structure — best serves this simulation's specific event arrival pattern is an open empirical question that warrants dedicated benchmarking.

=== Concurrency and I/O
<sec-future-multiprocess>

#comment[
  Even with buffered binary writes (see @sec-impl-trace-io), the simulation loop still
  performs the memcpy into the buffer synchronously. At extreme event rates, this becomes
  a bottleneck — the CPU is context-switching between simulation logic and I/O.

  The solution is to offload trace writing to a separate thread or process.

  Points to cover:
  - Current architecture: four 64KB stack buffers flushed when full. The flush (write()
    syscall) blocks the simulation thread. Under high event throughput, flushes become
    frequent enough to matter.
  - Proposed: a dedicated writer thread consumes from a lock-free ring buffer (or a
    pair of double-buffered pages). The simulation loop writes trace events into the
    ring buffer with a single atomic store; the writer thread drains to disk
    asynchronously. No simulation cycle ever waits for a syscall.
  - Alternative: use io_uring (Linux) or IOCP (Windows) for truly asynchronous kernel-level
    I/O without spawning threads. More complex to implement but lower overhead.
  - The trace format (fixed-size binary structs) is ideal for this — each event is
    a known number of bytes, so the ring buffer can use a simple producer-consumer
    protocol without serialization or variable-length framing.
  - This optimization is independent of the Calendar Queue; both can be applied
    simultaneously for cumulative speedup.
]

=== Multi-Stage Compilation
<sec-future-compiletime>

The simulation currently parses the JSON configuration at runtime and resolves distribution types through tagged unions. Every call to `.sample()` dispatches through a union tag, and the concrete distribution type (e.g., `Exponential(f64)` vs `Erlang(f64)`) is invisible to the compiler's optimizer.

A more radical approach: treat the simulation binary as a *specializing compiler driver*. Instead of a generic executable that interprets any config, the tool reads the JSON config, generates a monomorphized Zig source file where every distribution field is replaced by its concrete type (e.g., `Exponential(f64)` instead of `ContinuousDistribution(f64)`), invokes the Zig compiler to build a specialized binary, and executes it.

In effect, there are two programs:
- *Program 1*: reads the JSON config and emits specialized Zig source code.
- *Program 2*: the simulation binary, compiled by program 1 with all distribution types resolved to concrete implementations.

Program 1 is a code generator that runs once per configuration. Program 2 is the actual simulation, now compiled with full knowledge of which distributions it will use. This explains the name of the section: program 1 compiles program 2, while itself having been compiled beforehand — a multi-stage compilation pipeline.

Benefits:
- Distribution dispatch (tagged union switch) is eliminated. While the branch predictor handles this well at runtime, the real win is that LLVM can inline the entire sampling call chain once concrete types are known. A call to `.sample(rng)` becomes a direct invocation of, e.g., the Ziggurat exponential sampler, with zero indirection.
- Heap pre-allocation estimates can be computed at code-gen time from the known distribution parameters and network size. If the expected event count per user is statically bounded by the config and topology dimensions, the per-user timeline heaps can be pre-sized, eliminating reallocation churn in the hot loop. Notably, the topology is only *inspected* for these aggregate statistics — the network data itself is not embedded in the specialized binary and remains a runtime input, so the same specialized binary can process different topologies of similar scale.

Trade-offs: each configuration change requires a recompilation (a few seconds), and the resulting binary is specialized to one config shape. This approach favors long-running, single-config executions or a small number of carefully chosen parameter points over rapid parameter sweeps with hundreds of configs. For the final calibrated configuration that will be run at full scale with many replications, the compile-time investment may be justified by the runtime savings.

== Content-Aware Information Diffusion
<sec-future-content>

Traditional information diffusion models (see @sec-sota-diffusionmodels) treat diffusion as a purely structural mechanic. The Independent Cascade model assigns a fixed transmission probability to each edge; the Linear Threshold model assigns thresholds independent of what is being transmitted. This abstraction keeps the mathematics tractable, but it erases the primary driver of real social network behavior: people engage with content because of *what it says*, not just *who said it*.

The current simulation inherits these limitations through its three simplifying assumptions: user homogeneity, post homogeneity, and action independence (see @sec-method-des-assumptions). All posts are interchangeable, all users behave identically, and actions are memoryless. The following sections outline how to lift each of these assumptions, building toward a content-aware simulation where user behavior emerges from the interaction between personal preferences and post semantics.

=== Why Content Matters

Most classical diffusion models ---including the one presented in this work--- deliberately focus on the "container" rather than the "content." The justification for this approach lies in the unique topological properties of social networks (see @sec-sota-topologies), where the observed flow of information often mimics real-world data patterns regardless of the message being sent. For instance, basic structural models can effectively replicate the heavy-tailed distribution of cascades found in empirical datasets without modeling a single word of the posts themselves.

We see a tangential acknowledgment of content in the application of specific models: the Independent Cascade (IC) model is frequently utilized to simulate the viral spread of misinformation, whereas the Linear Threshold (LT) model is better suited for modeling belief changes on complex topics. These choices imply an underlying assumption about the *type* of content being transmitted, even if the model itself remains mathematically agnostic to the semantics.

By introducing content-aware variables, researchers can model the most critical driver of social interaction: *homophily* (see @sec-sota-topo-homophily). In content-agnostic models, the probability $p$ that a user $u$ reposts item $i$ is often treated as a constant $p in [0,1]$. A content-aware approach transforms this into a dynamic function proportional to the similarity between the item $i$ and the user's historical preferences or "history" $cal(H)_u$ at time $t$:

$ p(u, i) prop "sim"(i, cal(H)_u (t)) $

But content similarity is only half the picture. Even the most perfectly aligned post may be ignored if the user has not been exposed to it enough times. The *type* of contagion ---whether an idea spreads after a single exposure or requires sustained reinforcement--- also depends on the nature of the content, and traditional models handle these regimes very differently.

=== Simple and Complex Contagion

Information diffusion models fall into two broad families based on how a node transitions from inactive to active.

*Simple contagions*, such as the spread of a viral meme or a breaking news headline, require only a single exposure to "infect" a user. The Independent Cascade (IC) model captures this elegantly: each newly activated node gets a single, independent chance to activate each of its outgoing neighbors, after which it becomes refractory and can never activate again @gomezrodriguez2011uncovering. This single-chance mechanic is well-suited for content that spreads impulsively --- a user sees a funny post, reposts it, and moves on.

*Complex contagions* ---such as the adoption of a new political belief, a lifestyle change, or trust in a controversial claim--- require reinforcement from multiple sources to overcome social inertia @centola2007complex. A user might ignore a claim the first time they see it, but after hearing it from three different friends in separate communities, the cumulative social proof becomes persuasive.

The Linear Threshold (LT) model formalizes this dynamic: every node $i$ has a threshold $theta_i in [0, 1]$ representing their resistance to change, and every directed edge from neighbor $j$ to node $i$ carries an influence weight $w_{j i}$ @zhang2014chapter1. A node becomes active only when the cumulative influence from its currently active neighbors meets or exceeds its personal threshold:

$ sum_{j in cal(N)(i)} w_{j i} >= theta_i $

Because it strictly requires accumulated exposures, the LT model accurately captures meso-scale properties of social networks: information easily saturates dense communities (clusters, echo chambers) but struggles to propagate through weak ties between communities @centola2007complex.

However, there is a subtle but critical limitation. The LT model, like the IC model, is *content-blind*. The threshold $theta_i$ measures how many neighbors are active, not what they are saying. A node in the LT model will adopt a belief after enough neighbors adopt it, regardless of whether that belief aligns with or contradicts everything the node has previously expressed. Complex contagion is modeled structurally, but the *reason* a user finds something persuasive ---the semantic alignment between the message and their worldview--- is absent from the mathematics.

Recent research has begun to close this gap by making agents themselves content-aware.

=== The Frontier: Large Language Models and Generative Agents

The most ambitious approach to content-aware simulation leverages Large Language Models (LLMs) within a Generative Agent-Based Modeling (GABM) framework. In this paradigm, each agent is powered by an LLM that generates posts, evaluates incoming content, and decides whether to engage ---all based on a rich internal representation of the agent's personality, beliefs, and history. Frameworks such as OASIS #todo[Citation: OASIS framework paper] demonstrate that LLM-driven agents can produce remarkably human-like diffusion patterns, including complex contagion effects that emerge naturally from semantic reasoning rather than from parameterized thresholds.

This approach solves both problems simultaneously. Content awareness is native: an agent reading a post understands its meaning and can assess alignment with their own views. Complex contagion is emergent: repeated exposure to an idea from diverse sources builds a semantic case that the agent evaluates holistically, not through a fixed threshold parameter.

The cost, however, is computational. Every agent action requires at least one LLM inference ---a forward pass through a model with billions of parameters, often requiring GPU acceleration. In a simulation with millions of users generating tens of millions of events, this is infeasible. The simulation's core strength is throughput: processing events in microseconds, not seconds. Introducing LLM inference inside the hot loop would increase execution time by orders of magnitude, sacrificing the scalability that makes the current engine valuable.

A middle ground exists. Rather than giving every agent a full language model, we can represent both users and content as points in a shared embedding space ---a continuous vector space where semantic similarity corresponds to geometric proximity. This preserves the key property of content awareness (a user's response depends on how similar a post is to their interests) while keeping per-event computation to a single dot product. The following sections develop this embedding-based architecture.

=== Representing Users and Content as Embeddings

The simulation's scalability precludes heavyweight per-event computation ---we cannot wait for GPU inference inside the hot loop. The practical alternative is an embedding: a fixed-dimensional vector that captures the semantic essence of a post or user in a form that supports fast arithmetic.

Given a user $u in cal(U)$, we can consider their posting history $cal(P)(u, 0)$ — the posts authored before the simulation starts — as a characterization of who the user is. Let $f$ be an embedding function that maps a post to a vector in $bb(R)^d$. The user's state is then an aggregation of their historical posts:

$ S(u) = Gamma(\{ f(i) mid i in cal(P)(u, 0) \}) $

where $Gamma$ is an aggregation function (e.g., mean pooling). Since $f(i)$ are vectors, $S(u)$ is itself a vector in the same space — a compact numerical summary of the user's interests and opinions.

This representation lifts the three core assumptions of the current model:
1. *User homogeneity*: each user is now a distinct point in embedding space, defined by their posting history. Synthetic data can seed diverse user states without requiring empirical ground truth.
2. *Post homogeneity*: since every user samples posts from their own state vector, no two posts are identical — each carries a unique semantic fingerprint.
3. *Action independence*: the user's state vector enables content-dependent decisions, as developed in the following sections.

=== Content-Aware Post Generation

With users represented as points in embedding space, generating a new post becomes a geometric operation. Rather than creating content from scratch, a user synthesizes a new post as a convex combination of their historical posts — a form of semantic interpolation that preserves coherence while introducing variation.

The user's state $S(u)$ is defined as the bounded collection of their $N$ most recently authored posts:

$ S(u) = \{ i_1, i_2, dots, i_N \}   "where" i_j in cal(P)(u) $

To generate a new post $i_{N+1}$, we sample a set of random weights $w_j$ (approximating a Dirichlet distribution) such that their sum equals 1:

$ sum_{i=1}^N w_i = 1 $

$ i_{N+1} = sum_{j=1}^N (w_j dot i_j) $

By updating which posts constitute $S(u)$ and their relative weights, the user's state evolves over time, and so does the content they produce. A user exposed to a divergent community will gradually drift their embedding — capturing the slow, feedback-driven nature of opinion change.

Once posts carry semantic meaning and users have defined preferences, the next question is: how does content similarity translate into behavior?

=== Homophily-Driven Action Policy

The current simulation uses a static categorical policy $pi_u(a)$ where every action (ignore, like, repost) has a fixed probability independent of what the user is looking at. A content-aware simulation replaces this with a dynamic policy that responds to the alignment between the user's state and the post's content.

We define this alignment by calculating the cosine similarity $c$ between the user's current state $S(u)$ and the post's embedding $f(i)$:

$ c = S_C(S(u), f(i)) = frac{bold{S(u)} dot bold{f(i)}}{||bold{S(u)}|| \, ||bold{f(i)}||} $

To map this similarity score into a concrete decision, we compute a raw score (a "logit," $z_a$) for every possible action $a in cal(A)$ (ignore, like, repost) using two intuitive parameters:

- *Base Bias ($beta_a$)*: the default tendency of the user to take this action, regardless of content. Because users naturally scroll past most posts, "ignore" is assigned a high base bias, while "repost" is assigned a low one.
- *Sensitivity ($theta_a$)*: how strongly the action reacts to content similarity $c$. "Like" and "repost" have high positive sensitivities (high $c$ rapidly increases their score), whereas "ignore" has a negative sensitivity (high $c$ actively reduces its likelihood).

$ z_a = theta_a dot c + beta_a $

The raw scores are converted into a valid probability distribution via softmax:

$ pi_u(a mid c) = frac{exp(z_a)}{sum_{k in cal(A)} exp(z_k)} $

This formulation avoids deterministic thresholds: high similarity exponentially boosts engagement likelihood, while preserving the stochastic noise inherent to authentic human browsing.

But homophily alone models each exposure independently — as if every time a user sees a post, they evaluate it in isolation. Real social influence is cumulative: the same post seen from multiple friends carries more weight.

=== Integrating Complex Contagion

The work of Meng et al. @meng2025spreading introduces a paradigm shift in understanding information spreading dynamics, moving beyond simple linear reinforcement. Their empirical analysis demonstrates that the probability of retweeting follows a pattern of "first rising and then falling," typically peaking at around two to three exposures ($x^* in [2, 3]$). This is driven by two competing mechanisms: social reinforcement (multiple exposures increase perceived importance) and social weakening (diminishing returns as overlapping audiences saturate).

Meng et al. formalized this as:

$ beta_i(x) = alpha_i \, x \, (1 - gamma)^{x^{omega_i}} $

where $alpha_i$ is the intrinsic spreading power of the information, $x$ is the exposure count, $gamma$ is the average proportion of common neighbors between users, and $omega_i$ calibrates the effective exposure rate.

The original formulation assumes a static, universal spreading power $alpha_i$ for each message. We propose replacing it with our dynamic, personalized softmax probability $pi_u("repost" mid c)$, transitioning from *how viral is this post globally* to *how resonant is this post for this specific user*:

$ beta_{u,i}(x) = pi_u("repost" mid c) dot x \, (1 - gamma)^{x^{omega_i}} $

Expanding the softmax policy with the cosine similarity $c$ between user state $S(u)$ and post embedding $f(i)$:

$ beta_{u,i}(x) = frac{exp(theta_{"repost"} dot c + beta_{"repost"})}{sum_{k in cal(A)} exp(theta_k dot c + beta_k)} dot x \, (1 - gamma)^{x^{omega_i}} $

This synthesis resolves the reinforcement paradox: even highly exposed posts (large $x$) will not trigger unrealistic, network-wide outbreaks unless they maintain high semantic alignment ($c$) with the viewing users. Cascades naturally fracture into topically relevant sub-communities, preserving both structural decay and semantic homophily.

Up to this point, we have assumed that a post's embedding remains static as it propagates. But in real social networks, every repost is an opportunity to reframe.

=== Semantic Mutation: How Content Drifts

Currently, once a post $i$ is created, its embedding $f(i)$ remains static throughout the contagion process. However, empirical social media interactions heavily feature mechanisms like the "quote-retweet," where a user appends their own commentary and context to an existing post.

We can model this content drift by having the repost action synthesize a new post embedding $i'$ as a convex combination of the original post's vector and the reposting user's internal state:

$ f(i') = lambda \, f(i) + (1 - lambda) \, S(u) $

where $lambda in (0, 1)$ dictates the fidelity of the repost. Under this mechanism, as a post travels further from its source, its semantic meaning actively shifts. A benign post might absorb the bias of a highly polarized network cluster over successive diffusion steps, capturing how information mutates as it traverses communities.

So far, every mechanism we have proposed assumes engagement increases with similarity. But that is only half the story.

=== Semantic Repulsion: Outrage Contagion

Our foundational softmax policy assumes that engagement scales strictly with semantic alignment (high cosine similarity $c -> 1$ drives interaction). Yet, sociological phenomena such as "rage-bait" and hate-reading demonstrate that users frequently engage with content that diametrically opposes their worldview ($c -> -1$).

To capture this adversarial engagement, the linear sensitivity parameter can be expanded into a non-linear, parabolic function for specific actions (such as a quote repost). The raw action score $z_{"repost"}$ is modified to:

$ z_{"repost"} = theta_1 c + theta_2 c^2 + beta_{"repost"} $

By tuning $theta_2 > 0$, the probability of engagement forms a U-curve, rising at both extremes of the similarity spectrum. This mathematically models outrage contagion: severe semantic clashes trigger as much virality as perfect homophily, bypassing traditional structural friction.

Taken together, these extensions outline a path from a purely structural, content-agnostic simulation toward one where information diffusion emerges from the continuous interplay between what users believe, what content says, and how communities reshape both.
