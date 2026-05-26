#import "utils.typ": *

This chapter outlines directions for extending the simulation beyond its current scope, organized into two independent tracks. The first addresses computational performance — removing the remaining bottlenecks that limit scalability to tens of millions of users. The second addresses model fidelity — lifting the simplifying assumptions of content-agnostic, action-independent diffusion to capture the semantic and psychological drivers of real social network behavior.

== Performance Optimizations
<sec-future-performance>

The simulation already applies arena-based memory allocation and buffered file I/O to keep the hot loop from stalling (see @sec-impl-memory and @sec-impl-trace-io). Two bottlenecks remain that are structural rather than implementational: the $O(log n)$ cost of the event queue, and the single-threaded nature of trace writing.

=== Future Event Set Data Structures

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

=== Parallelism
<sec-future-multiprocess>

#todo[FINISH]

Three main points to cover here:
1. Parallel discrete-event simulations: they are it's own field of research, not the objective of this project.
2. Multithreading on execution: it would be very good for a lot of things and was not feasible to implement due to time constirctions. It would involve:
  - Spliting the `Topology` struct into the CSR + inmmutable information and the users information.
  - Reseting the users and the arenas per run to avoid more overhead than necessary.
3. I/O optimization: split every thread into an evented IO, in which one green thread would just write the trace, and another would just compute. when to dump would be a pointer change, as we would have two buffers.


=== Multi-Stage Compilation
<sec-future-compiletime>

The simulation currently parses the JSON configuration at runtime and resolves distribution types through tagged unions. Every call to `.sample()` dispatches through a union tag, and the concrete distribution type (e.g., `Exponential(f64)` vs `Erlang(f64)`) is invisible to the compiler's optimizer, as well as ever if guarding all the trace writing calls `if (simconf.trace_to_file)` depend on a runtime variable, so even if the variable `simconf.trace_to_file = false`, the if will be executed at every iteration.

A solution to this small inconveniences can be found in metaprogramming capabilities, that is, having a program that generates the specialized code of the simulation on it's runtime, and then the simulation will see the `json` configuration as a compile time know variable. With that done, the first program is an specialization of the actual simulation. Let's define them as

- *simulation-builder.zig*: receives the JSON config as a parameter and emits specialized Zig source code.
- *simulation.zig*: the simulation binary, compiled by the zig compiler invoked by simulation-builder.zig.

Simulation-builder is a code generator that runs once per configuration. Simulation is the actual simulation, now compiled with full knowledge of which distributions it will use and if it has to write the traces or not. This is a multi-compilation stage pipeline, which can be implemented with the zig build system, which is in itself a zig program that manages the zig compilation.

Benefits:
- Runtime distribution dispatch (tagged union switch) is eliminated but all the distributions are still settable at runtime. While the branch predictor handles this well at runtime, the real win is that LLVM can inline the entire sampling call chain once concrete types are known. A call to `.sample(rng)` becomes a direct invocation of, e.g., the Ziggurat exponential sampler, with zero indirection.
- Heap pre-allocation estimates can be computed at code-gen time from the known distribution parameters and network size. If the expected event count per user is statically bounded by the config and topology dimensions, the per-user timeline heaps can be pre-sized, eliminating reallocation churn in the hot loop. Notably, the topology is only *inspected* for these aggregate statistics — the network data itself is not embedded in the specialized binary and remains a runtime input, so the same specialized binary can process different topologies of similar scale.

As trade-offs, each configuration change requires a recompilation (a few seconds), and the resulting binary is specialized to one config shape. This approach favors long-running, single-config executions or a small number of carefully chosen parameter points over rapid parameter sweeps with hundreds of configs. For the final calibrated configuration that will be run at full scale with many replications, the compile-time investment may be justified by the runtime savings.
Implement appropiately the session gaps, duration and inter post creation as the data gave. The decisions taken in the works were result of a severe time limitation constraint and the need for the distribtuions software to implement the lognormal, the weibull and the gamma from scratch.

== Execution and Evaluation
<sec-future-execution>

#todo[Write this properly]

First, try to profile the parts of the current simulation that are actual bottlenecks, and perfrom a professional performance analysis, with hunderds of rams, with warm and cold caches, and give the input analysis time, memory and trace lenght (space).

Implement appropiately the session gaps, duration and inter post creation as the data gave. The decisions taken in the works were result of a severe time limitaiton constraint and the need for the distribtuions software to implement the lognormal, the weibull and the gamma from scratch.


== Content-Aware Information Diffusion
<sec-future-content>

This section aims to highlight the limitations of the model proposed in this work, and where could be improved to be more faithful to a microblogging social network.

Traditional information diffusion models (see @sec-sota-diffusionmodels) treat diffusion as a purely structural mechanic, steaming just from the network topology: if the network has the appropriate properties, the system will behave as an social network. The Independent Cascade model assigns a fixed transmission probability to each edge. This abstraction keeps the mathematics tractable, but it erases the primary driver of real social network behavior: people engage with content mainly because of what it says, not just because who said it.

The current simulation inherits these limitations through its two simplifying assumptions: post homogeneity, and action independence (see @sec-method-des-assumptions). All posts are interchangeable and actions are memoryless. The following sections outline how could these two assumptions be lifted, building toward a content-aware simulation where user behavior emerges from the interaction between personal preferences and post semantics, not only the topology characterization.

=== Why Content Matters

Most classical diffusion models ---including the one presented in this work (@sec-method-model)--- deliberately focus on the "container" rather than the "content." The justification for this approach lies in the unique topological properties of social networks (see @sec-sota-topologies), where the observed flow of information often mimics real-world data patterns regardless of the message being sent. For instance, basic structural models can effectively replicate the heavy-tailed distribution of cascades found in empirical datasets without modeling a single word of the posts themselves.

We see a tangential acknowledgment of content in the application of specific models: the Independent Cascade (IC) model is frequently utilized to simulate the viral spread of misinformation, with the underlying assumptions that is not difficult for a user to spread it, it does not need to be convinced #comment[Is this true? should i look for a source?]. In contrast, there are other models that model believe change, as a user needs multiple expousures to similar content to actually transmit it to it's followers. These choices imply an underlying assumption about the type of content being transmitted, even if the model itself remains mathematically agnostic to the semantics.

By introducing content-aware mechanisms, one could model the most critical driver of social interaction: homophily. In @sec-sota-topo-homophily, the explanation has focused on explaining homophily to the network level (users will tend to follow similar users topology wise), but this holds true for user and content, as similar users will engage and create similar type of content. #comment[probably need a citation of a paper that i already got here]. This is absolutely consistent with the clusters of users social networks are usually characterized, as they not only aggregate by real life contact, but also by hobbies and interests.

In content-agnostic models, the probability $p$ that a user $u$ reposts item $i$ is often treated as a constant $p in [0,1]$, but in a content-aware approach, the dynamic could be related of the similarity of the content to a user function proportional to the similarity between the item $i$ and the user's historical preferences or "history" $cal(H)_u$ at time $t$.

$ p(u, i) prop "sim"(i, cal(H)_u (t)) $

But content similarity is only half the picture. Even the most perfectly aligned post may be ignored if the user has not been exposed to it enough times. The type of contagion ---whether an idea spreads after a single exposure or requires sustained reinforcement--- also depends on the nature of the content, and traditional models handle these regimes very differently.

=== Simple and Complex Contagion

Information diffusion models fall into two broad families based on how a node transitions from inactive to active.

*Simple contagions*, such as the spread of a viral meme or a breaking news headline, require only a single exposure to "infect" a user. The Independent Cascade (IC) model captures this elegantly: each newly activated node gets a single, independent chance to activate each of its outgoing neighbors, after which it becomes refractory and can never activate again @gomezrodriguez2011uncovering. This single-chance mechanic is well-suited for content that spreads impulsively --- a user sees a funny post, reposts it, and moves on.

*Complex contagions* ---such as the adoption of a new political belief, a lifestyle change, or trust in a controversial claim--- require reinforcement from multiple sources to overcome social inertia @centola2007complex. A user might ignore a claim the first time they see it, but after hearing it from three different friends in separate communities, the cumulative social proof becomes persuasive.

The Linear Threshold (LT) model formalizes the complex contagion dynamic: every node $i$ has a threshold $theta_i in [0, 1]$ representing their resistance to change, and every directed edge from neighbor $j$ to node $i$ carries an influence weight $w_{j i}$ @zhang2014chapter1. A node becomes active only when the cumulative influence from its currently active neighbors meets or exceeds its personal threshold:

$ sum_{j in cal(N)(i)} w_{j i} >= theta_i $

Because it strictly requires accumulated exposures, the LT model tends to accurately captures meso-scale properties of social networks: information easily saturates dense communities (clusters, echo chambers) but struggles to propagate through weak ties between communities @centola2007complex.

The LT model, like the IC model, is content-blind. The threshold $theta_i$ measures how many neighbors are active, not what they are saying. A node in the LT model will adopt a belief after enough neighbors adopt it, regardless of whether that belief aligns with or contradicts everything the node has previously expressed. Complex contagion ---and the LT model--- translate this fact, but is still content blind. 

=== Large Language Models and Generative Agents

The most ambitious approach to content-aware simulation leverages Large Language Models (LLMs) within a Generative Agent-Based Modeling (GABM) framework. In this paradigm, each agent is powered by an LLM that generates posts, evaluates incoming content, and decides whether to engage ---all based on a rich internal representation of the agent's personality, beliefs, and history. Frameworks such as OASIS #todo[Citation: OASIS framework paper] demonstrate that LLM-driven agents can produce remarkably human-like diffusion patterns, including complex contagion effects that emerge naturally from semantic reasoning rather than from parameterized thresholds. #comment[Check what the actual OASIS paper results say]

This approach solves both complex contagions and content awareness simultaneously. Content awareness is native: an agent reading a post understands its meaning and can assess alignment with the base prompt provided configuration. Complex contagion is emergent: repeated exposure to an idea from diverse will influence the decisions of the agents as they will remain in its history, which will be used to prompt a response.

The cost, however, is computational. Every agent action requires at least one LLM inference, requiring GPU acceleration. In a simulation with millions of users generating tens of millions of events, this tens to infeasibly. One of the core strengths of the simulation approach iss throughput: processing events in microseconds, not seconds. Introducing LLM inference inside the hot loop would increase execution time by orders of magnitude, sacrificing the scalability that makes the current engine valuable.

This section proposes another solution not involving LLMs. Rather than giving every agent a full language model, we can represent both users and content as points in a shared embedding space ---a continuous vector space where semantic similarity corresponds to geometric proximity. This preserves the key property of content awareness (a user's response depends on how similar a post is to their interests) while keeping per-event computation to a single dot product. The next sections sections theoretically develops what this embedding-based architecture could work and be implemented.

=== Representing Users and Content as Embeddings

The main strong point of this approach is to avoid heavyweight operations per-event in the middle of the hot loop, as they compromise simulation scalability, such as LLMs inference. An embedding is a fixed-dimensional vector that captures the semantic essence of a post or user in a form that supports fast arithmetic. #todo[cite embedding from a serious font]

Given a user $u in cal(U)$, their observable identity ---what they have contributed to the network--- is captured by their activity set $cal(A)_t (u)$, which includes both original creations and reposts (see @sec-method-model, @def-activity). This is distinct from the narrower set of original posts $cal(P)_t (u)$: a repost is an act of endorsement that shapes the user's public identity just as much as an original post.

#todo[finish this]

#def(name: "Embedding")[
  Something that if you cosine similarity a user with a post and gives a kind of probability of an interaction (like respost ignore).
]

Details on two tower approach without mencioning two tower approach.

Let $f$ be an embedding function that maps a post to a vector in $bb(R)^d$. The user's identity embedding $S_"id"(u, t)$ is an aggregation of everything they have output:

$ S_"id" (u, t) = Gamma_"id" ({ f(i) | i in cal(A)_t (u) }) $

where $Gamma_"id"$ is an aggregation function (e.g., a recency-weighted mean with exponential decay). Since $f(i)$ are vectors, $S_"id" (u, t)$ is itself a vector in the same space ---a compact numerical summary of the user's expressed interests and opinions, visible to the rest of the network.

Separate from their output we can characterize every user by the content they interact with. We define an influenced state $S_"inf" (u, t)$ that captures how cumulative exposure has altered the user's creative landscape:

$ S_"inf" (u, t) = Gamma_"inf" ({ w(i) dot f(i) | i in cal(T)_t (u) }) $

where $cal(T)_t (u)$ is the user's timeline ---all posts they have been exposed to--- and $w(i)$ is a weight reflecting the depth of engagement with post $i$:

$ w(i) = cases(
  w_"like" &"if" i in cal(H)_t(u) "and" i in.not cal(A)_t(u),
  w_"repost" &"if" i in cal(A)_t(u)
) $

with $w_"repost" > w_"like" > w_"seen" > 0$. The weight hierarchy acknowledges that posts the user actively engaged with leave a deeper imprint than those merely scrolled past. Critically, however, even content the user never liked or reposted contributes to $S_"inf"$: exposure alone, without endorsement, shapes what a user is likely to create next. This weights should be tuned accordingly to the data, as this is more of a thought experiment rather than a specific proposal.

Taken together, $S_"id"$ and $S_"inf"$ attemp to represent the user's in two different ways: what they are (output identity) and what they are becoming (exposure-driven drift). This user-as-embedding representation allows us to circumvent the content-agnostic assumptions of the current model while adding a complex contagion dynamic.

=== Content-Aware Post Generation
<sec-future-content-generation>

With users decomposed into identity and influenced states, content generation becomes a function of both who the user is and what they have been exposed to. Rather than synthesizing posts solely from the user's own historical output---the implicit assumption of a purely spontaneous creation model---we propose that creation draws from both the user's identity posts $cal(A)_t(u)$ and their exposure posts $cal(T)_t(u)$, with the balance governed by $alpha in [0, 1]$.

More abstractly, to create a new post $i_"new"$ at time $t$, user $u$ samples a set of candidate posts $C(u, t)$ drawn from both identity and exposure:

$ C(u, t) = "sample"( cal(A)_t (u), cal(T)_t (u); alpha ) $

where $alpha$ controls the proportion drawn from identity versus exposure, and within $cal(T)_t (u)$ the sampling is biased by the engagement weight $w(i)$ defined in the previous section. At $alpha = 1$, the user creates purely from their own history---the content-agnostic limit equivalent to the spontaneous creation policy $lambda_0$ in the current simulation (see @sec-method-des-assumptions). As $alpha$ decreases, weighted sampling from $cal(T)_t (u)$ pulls the candidate pool toward content the user engaged with most.

The new post embedding is then a convex combination of the candidate pool's embeddings:

$ f(i_"new") = sum_(j=1)^K w_j dot f(i_j) quad "where" i_j in C(u, t) $

with weights drawn from a Dirichlet distribution $bold(w) ~ "Dir"(bold(1))$, ensuring $sum w_j = 1$ and $w_j >= 0$. #todo[don't say it as true, but as maybe] This guarantees the generated embedding lies within the convex hull of semantically valid posts---unlike additive Gaussian noise, which can drift into meaningless regions of the embedding space. The exact sampling strategy for constructing $C(u, t)$ and the optimal Dirichlet concentration remain open questions, as this is a design sketch rather than a finalized algorithm.

This formulation captures a fundamental feedback loop absent from the current simulation. As a user scrolls through their timeline, the engagement-weighted sampling from $cal(T)_t(u)$ ensures that the candidate pool gradually drifts toward the semantic center of their information diet. A user embedded in a polarized community will see their creations shift toward that community's positions---not because they necessarily agree with everything they read, but simply because that is what surrounds them. Over time, $S_"id"$ follows: the user's own output (now part of $cal(A)_t(u)$) feeds back into their identity, closing the loop. This models the slow, feedback-driven nature of opinion change that purely spontaneous creation cannot produce.

=== Homophily-Driven Action Policy
<sec-future-content-homophily>

This is arguably the most prominant change introduced in the content-aware simulation, the dynamically adaptation of the $pi_u$ policy to the post contents.

The current simulation uses a static categorical policy $pi_u$ where every action (ignore, like, repost) has a fixed probability independent of what the user is looking at. A content-aware simulation replaces this with a dynamic policy that responds to the alignment between the user's state and the post's content.

We define this alignment by calculating the cosine similarity $c$ between the user's identity embedding $S_"id"(u, t)$ and the post's embedding $f(i)$:

$ c = S_C (S_"id"(u, t), f(i)) = frac(bold(S)_"id"(u, t) dot bold(f)(i) ||bold(S)_"id"(u, t)||, ||bold(f)(i)||) $

To map this similarity score into a concrete decision, we compute a raw score (a "logit," $z_a$) for every possible action $a in cal(A)$ (ignore, like, repost) using two intuitive parameters, that would have to be tuned appropriately:

- *Base Bias ($beta_a$)*: the default tendency of the user to take this action, regardless of content. Because users naturally scroll past most posts, "ignore" is assigned a high base bias, while "repost" is assigned a low one.
- *Sensitivity ($theta_a$)*: how strongly the action reacts to content similarity $c$. "Like" and "repost" have high positive sensitivities (high $c$ rapidly increases their score), whereas "ignore" has a negative sensitivity (high $c$ actively reduces its likelihood). This is serves the same function as the Linear Threshold parameter.

$ z_a = theta_a dot c + beta_a $

The raw scores are converted into a valid probability distribution via softmax:

$ pi_u (a | c) = frac(exp(z_a), sum_(k in cal(A)) exp(z_k)) $

This formulation avoids deterministic predefined thresholds: high similarity exponentially boosts engagement likelihood. But homophily alone models each exposure independently — as if every time a user sees a post, they evaluate it in isolation. Real social influence is cumulative: the same post seen from multiple friends carries more weight.

=== Integrating Complex Contagion

The work of Meng et al. @meng2025spreading introduces a paradigm shift in understanding information spreading dynamics, moving beyond simple linear reinforcement. Their empirical analysis demonstrates that the probability of retweeting follows a pattern of "first rising and then falling," typically peaking at around two to three exposures ($x^* in [2, 3]$). This is driven by two competing mechanisms: social reinforcement (multiple exposures increase perceived importance) and social weakening (diminishing returns as overlapping audiences saturate).

Meng et al. formalized this as:

$ beta_i(x) = alpha_i + x (1 - gamma)^(x^(omega_i)) $

where $alpha_i$ is the intrinsic spreading power of the information, $x$ is the exposure count, $gamma$ is the average proportion of common neighbors between users, and $omega_i$ calibrates the effective exposure rate.

The original formulation assumes a static, universal spreading power $alpha_i$ for each message. We propose replacing it with a dynamic softmax per user probability $pi_u("repost" | c)$, transitioning from how viral is this post globally to how resonant is this post for this specific user.

$ beta_(u,i)(x) = pi_u ("repost" | c) dot x  (1 - gamma)^(x^(omega_i)) $

Expanding the softmax policy with the cosine similarity $c$ between user identity embedding $S_"id" (u, t)$ and post embedding $f(i)$:

$ beta_(u,i)(x) = frac(exp(theta_"repost" dot c + beta_"repost"), sum_(k in cal(A)) exp(theta_k dot c + beta_k) dot x) (1 - gamma)^(x^(omega_i) $

This synthesis resolves the reinforcement paradox: even highly exposed posts (large $x$) will not trigger unrealistic, network-wide outbreaks unless they maintain high semantic alignment ($c$) with the viewing users. Cascades naturally fracture into topically relevant sub-communities, preserving both structural decay and semantic homophily.


Taken together, the proposals given in this section sketch a research path from a purely structural, content-agnostic simulation toward one where diffusion emerges from the interplay between semantics and topology. The result is a framework where who users are, what content says, and how communities reshape it are no longer orthogonal assumptions but continuous, entangled dynamics, making ---allegidly--- a worth exploring research topic.
