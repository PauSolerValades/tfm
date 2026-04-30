#import "utils.typ": todo, comment

This section covers ...

== Models

Why did we model the information diffusion as the Queue-Based, Activty Driven Continnuous-Time Cascade Model

[TODO: el seguent paragraf no té cita perque estic introduint el que s'ha programat a la simulació.]

This "one-shot" evaluation directly mimics the behavior of a user scrolling through a timeline. A user sees a post once, decides instantaneously to retweet it or ignore it, and then scrolls past it forever.

An underlying assumption of the standard IC model is the discrete generations, assuming all nodes evaluate information instantly. In a real OSN, the network topology dictates the potential highways for information, but time dictates the traffic. To recreate observed structural virality accurately, the IC model must be extended with temporal constraints. Introducing temporal delays, session durations (when users log off), and interaction delays ensures that if a user receives a retweet but logs off before scrolling far enough to see it, that branch of the cascade dies. Incorporating these realistic temporal mechanics is needed for accurate simulations of platform-specific transmission (see [sec-results o sec-design]).

== Activity-Driven Network Dynamics

Standard static network models assume that nodes and edges are perpetually available for information transmission. However, empirical studies of social and technological systems reveal that human interactions are fundamentally bursty and temporally disconnected (Accessed: 2026-04-29). To capture this reality, the Activity-Driven modeling framework describes a time-varying network where the topological evolution is strictly governed by the intrinsic behavioral patterns of individual nodes (Accessed: 2026-04-29).

In this paradigm, each user is characterized by an "activity" rate, defined as their propensity to engage with the network and form connections or interactions at a given time (Accessed: 2026-04-29). Consequently, nodes alternate between discrete online sessions and offline "vacation" periods. The continuous-time duration of these sessions, as well as the inter-session intervals, are sampled from distinct probability distributions, generating a heterogeneous temporal fabric where users are only susceptible to receiving or spreading information during active windows (Accessed: 2026-04-29). 

Furthermore, the integration of "attractiveness"—the inherent propensity of a node to receive connections or attention—creates significant asymmetries in the spreading process. Heterogeneous distributions of attractiveness dynamically alter the contagion thresholds; highly attractive nodes may act as temporal hubs, deeply influencing the macroscopic spread of the cascade despite the network's transient connectivity (Accessed: 2026-04-29).

== Queue-Based Processing and Divided Attention

While the Activity-Driven framework dictates when users are present, it does not fully explain how they consume information. Social contagion is heavily moderated by the cognitive limits of human processing and the user interface of the platform itself (Accessed: 2026-04-29). Information does not instantly infect an active neighbor; instead, individual responses to exposure are mediated by visibility and divided attention (Accessed: 2026-04-29).

To mathematically capture this cognitive bottleneck, information diffusion is modeled as a queueing process. When an active node transmits a piece of information, continuous-time delays—such as system propagation delays—postpone its arrival. Upon arrival, the information is deposited into the receiving user's timeline, which functions mathematically as a chronologically ordered priority queue (Accessed: 2026-04-29). 

When a user initiates an online session, they do not evaluate all incoming connections simultaneously. Instead, they sequentially process the events pending in their timeline queue, governed by an inter-action time distribution that dictates the pace of their attention (Accessed: 2026-04-29). For each popped event, the user executes a discrete decision sampled from a categorical policy distribution—such as choosing to ignore, endorse (like), or transmit (repost) the content (Accessed: 2026-04-29).

Crucially, the position of the exposing message within this queue strongly affects the likelihood of social contagion (Accessed: 2026-04-29). If a post is buried deep in the backlog or if the user's session ends before the queue is fully drained, the transmission opportunity is lost entirely. By coupling Activity-Driven session dynamics with Queue-Based timelines, the model naturally produces the long-tailed, asynchronous cascade patterns observed in real-world social media environments (Accessed: 2026-04-29).

== Discrete Event Simulation

#text(red)[Esteve, si tens alguna font per citar això que sigui més pro digues-me-la]

Discrete Event Simulation (DES) is a modeling methodology that represents the operation of a complex system as a chronological sequence of events. In a DES model, the system's state only changes at discrete points in time when a specific event occurs, allowing the simulation engine to jump efficiently from one event to the next without calculating the time in between.

It is useful to contrast this methodology with recent developments in Agent-Based Modeling (ABM). Modern ABM is increasingly utilized to explore complex, highly interactive environments, such as social network dynamics simulated via Large Language Models (LLMs) [1]. Furthermore, while some ambitious initiatives—such as the DESIRE project at the University of Graz—are exploring ABM as a pathway to develop accurate "digital twins" of real-world systems, the methodology fundamentally revolves around generating bottom-up, emergent macro-behavior from the micro-level interactions of stateful agents.

DES, conversely, takes a top-down, process-centric approach. Instead of explicitly simulating the microscopic interactions of individual agents, DES abstracts entities into continuous flows governed by probability distributions and queueing theory [2]. Because it relies fundamentally on statistical abstraction rather than structural agent simulation, DES guarantees the validity of its results through two strict statistical assumptions: the simulation must process enough volume (entities) for the outcomes to be extrapolable, and the model must be replicated a sufficient number of times for those probabilistic distributions to achieve statistical convergence.

== Technology Approach

Because the validity of a DES relies entirely on sheer computational volume and repeated runs to achieve statistical significance, a suboptimal implementation can easily contradict the underlying assumptions needed to guarantee a successful process. Execution speed, deterministic behavior, and tightly optimized computational loops are paramount. 

The first step in implementation is choosing the appropriate tools for the job. Interpreted languages like Python and R are immediately discarded; even on powerful hardware, the overhead of interpretation introduces unacceptable latency for massive, CPU-bound simulation loops. Following this logic, manual memory management becomes necessary to deeply optimize performance and take full advantage of CPU caching. This requirement effectively rules out garbage-collected languages such as Java or Go, which cannot guarantee the deterministic, low-latency execution and exact memory layout control required here. With requirements pointing strictly toward a systems language with manual memory management, the choice of Zig was clear.

Zig is a general-purpose programming language and toolchain designed for maintaining robust, optimal, and reusable software. By design, it provides C-like performance alongside modern quality-of-life improvements and strict guardrails against common C pitfalls, such as segmentation faults and null pointer dereferences. With the application of the right memory optimization techniques (see [TODO: @ sec-des-hpc]), Zig enables highly scalable implementations that extract the maximum possible performance from the hardware.


== Random Number Generation

This section covers the implementations of the Random Number Generators needed in the main simulation, as Zig did not have a library of distributions. The distributions library has been published under the MIT license and its source available [TODO: Citar el repository de distirbuitons]


=== Ziggurat Algorithm
The generation of random variates for continuous distributions, specifically the Normal and Exponential distributions, relies on the highly optimized Ziggurat algorithm [TODO: Cite ziggurat algorhtim]. This method is a form of rejection sampling that overlays the target probability density function (PDF) with a set of $n=256$ horizontal rectangles (called "ziggurat" to the resemblance to the building with the same name TODO: Cite ziggurat) of equal area, constructed such that they tightly bound the distribution curve.

Our implementation in Zig heavily leverages compile-time evaluation (`comptime`) to specialize the algorithm identically for both `f32` and `f64` precision without runtime overhead. The core optimization focuses on minimizing calls to the pseudo-random number generator (PRNG). Instead of requiring two distinct random values—one to select a rectangle and another to sample a point within it—a single 64-bit random integer is generated (or 32-bit for `f32`).

From this single random word, two values are extracted with zero PRNG overhead:
1. The lowest 8 bits are masked (`bits & 0xff`) to uniformly select the index $i$ of one of the 256 precomputed rectangles.
2. The remaining 52 bits are shifted and directly utilized as the mantissa of an IEEE 754 floating-point number. [TODO: cite the IEEE soruce]

To construct the uniform floating-point value efficiently, the integer mantissa is bitwise OR-ed with a predefined exponent mask. For symmetric distributions like the Normal, the exponent is chosen such that the resulting float falls into the interval $[2, 3)$. Subtracting 3 then shifts the domain to $[-1, 1)$. For asymmetric distributions like the Exponential, the exponent mask places the float in $[1, 2)$, and subtracting an offset near 1 yields a uniform variate in $[0, 1)$.

This uniformly distributed value $u$ is scaled by the $x$-coordinate boundary of the selected rectangle $i$, producing a candidate sample $x = u \cdot x_i$. If the candidate falls strictly within the core of the rectangle ($|x| < x_{i+1}$), it is immediately accepted. This fast-path covers approximately 99% of all generation requests and bypasses costly mathematical operations.

When a candidate falls outside the fast-path core, two edge cases are handled:
- *Boundary Cases:* If $i > 0$ and the sample is in the wedge between rectangles, an additional random draw evaluates the exact PDF to deterministically accept or reject the candidate.
- *Tail Cases:* If $i = 0$, the sample lies in the infinite tail of the distribution. A specialized `zeroCase` function handles this tail recursively. For the Exponential distribution, it evaluates the inverse transform shifted by the rightmost boundary $R$, yielding $R - \ln(U)$. For the Normal distribution, it implements Marsaglia's tail generation, looping to draw values until $-2y < x^2$ is satisfied, and appropriately shifting the result by $R$.

=== Categorical Distribution
 
The categorical distribution models discrete random variables that can take on one of $k$ possible
 categories, each with a specific probability. In our Zig implementation, a categorical distribution is
 initialized with an array of distinct items (`data`) and their corresponding probabilities (`weights`).
 During initialization, an accumulator array (`acc`) is computed that stores the cumulative sum of the
given probabilities.

To sample from this distribution, we employ a standard inverse transform method: a uniform
 floating-point value $u in [0, 1)$ is drawn and compared linearly against the cumulative weights array
 until a value satisfying $u <= text("acc")[i]$ is found, at which point the category at index $i$ is
 returned.

While theoretically faster alternatives like the Alias Method #todo[Cite alias method] exist --—capable of sampling in $O(1)$ time after a linear $O(k)$ setup—-- they introduce additional memory overhead and initialization complexity. For the context of this simulation, where $k$ is typically very small (e.g., modeling a handful of user action types), the performance difference is strictly negligible. Thus, we have opted for the linear search approach due to its simplicity and cache locality.

However, to optimize the performance of the linear search, the following convention has been maintained when constructing the distributions: the categories must always be sorted by their probability in descending order. By placing the most probable outcomes at the beginning of the arrays, the cumulative sum grows rapidly, maximizing the chance that the linear search terminates in the very first iterations, thereby achieving near $O(1)$ empirical performance.

// === Erlang Distribution
//
// Another meaningful optimization present in the simulation pertains to the generation of Erlang-distributed random variates. The Erlang distribution with shape parameter $k$ and rate parameter $lambda$ describes the sum of $k$ independent and identically distributed Exponential random variables. 
//
// Naively simulating this process using the inverse transform method would involve generating $k$ standard uniform random variables $U_i$, computing their inverse transforms, and summing the results: 
// $ X = sum_(i=1)^k frac(-ln(U_i), lambda) $
// This standard approach requires invoking the computationally expensive logarithm function $k$ times, alongside $k$ divisions. 
//
// Instead, our implementation exploits the mathematical properties of logarithms to condense these operations. By factoring out the rate parameter and converting the sum of logarithms into the logarithm of a product, the calculation is reduced to:
// $ X = frac(-1, lambda) ln(product_(i=1)^k U_i) $
// This optimization allows the algorithm to simply compute a running product of $k$ standard uniform variables and perform a single logarithm and a single division at the end. By reducing the number of logarithm calls from $k$ to exactly 1, the generation speed for Erlang variates is drastically improved, especially for higher values of $k$.
//

 == Dynamic Graphs

 #text(red)[Esteve, no acabo d'entendre exactament què haig d'escriure aquí. Osigui perquè he necessitat un time heterogeneous graph per modelizar el problema?]

Revise the articles from the beginning. This is not about the data (users and relationships) and data, but the model of the data.



