#import "utils.typ": *

This chapter justifies and explains several methodology choices, such as the model chosed to simulate (see @sec-method-model), why the use of a discrete-event simulation methodology (see @sec-method-des) finishing with the random number generation has been used and implemented (see @sec-method-rng).

== Diffusion Model 
<sec-method-model>

This section details the theoretical foundation of the simulation engine. To accurately capture the real-world dynamics of information diffusion, we integrate the mathematically rigorous Continuous-Time Independent Cascade (CTIC) model (see @sec-sota-diffusion-ctic) with a Queue-Based (see ), Activity-Driven simulation architecture.

=== Continuous-Time Diffusion in Microblogging
<sec-method-ctic>

To accurately represent the dynamics of information diffusion on a microblogging platform like Bluesky (see @sec-sota-description), we utilize the Continuous-Time Independent Cascade (CTIC) (see @sec-sota-diffusion-ctic) model. While standard diffusion models operate in discrete, synchronized epochs @gomezrodriguez2012inferring, real-world microblogging is fundamentally asynchronous: users do not consume information in locked steps; rather, information propagation occurs continuously over time. 

The CTIC model is an amazing fit for microblogging networks due to its reliance on survival analysis and time-dependent transmission likelihoods: posts are injected into a fast-moving, chronologically ordered feed. A post's "survival" (its probability of being seen and reposted before being buried by newer content) is heavily dependent on the exact continuous time elapsed since its creation @gomezrodriguez2011uncovering. By allowing transmission at different rates using continuous temporal processes (such as exponential or power-law distributions), the CTIC model naturally captures the temporally heterogeneous interactions and long-tailed viral fads characteristic of modern social media.

While the CTIC model provides the ideal theoretical framework for continuous-time diffusion, evaluating these continuous hazard and survival functions analytically across a massive, highly connected graph is computationally prohibitive. Therefore, to operationalize this model, we chose to translate the continuous-time dynamics into a Discrete Event Simulation (DES) (see @sec-method-des).  

By modeling the system as a chronological sequence of discrete events—such as post creation, propagation, and user session initializations—we can simulate the exact continuous-time timestamps of the CTIC model without calculating the continuous time in between. Needless to say, the distinction is purely practical, as the definition of CTIC just impose a differnt quantity $t_i > t_j$, which the DES modelization absolutely fulfills. The methodology and assumptions of this DES approach are detailed in @sec-method-des, while the design of the simulation (architecture, event semantics) is documented in @sec-design and its concrete implementation (data structures, performance optimizations) in @sec-impl

=== The Homogeneous Rate Simplification

#comment[I am grately surprised this models adapts so well to the original design knowing nothing about this, its very beautiful :)]

In the Gomez Rodríguez et. al article @gomezrodriguez2011uncovering, the theoretical formulation of the CTIC model has the transmission likelihood governed by a specific pairwise transmission rate, $alpha_(j,i)$, defined uniquely for every directed edge from node $j$ to node $i$. This parameter needs to be "flattened" due to the user homogeneity (see @sec-method-des-assumptions for context), so the transmission rate is uniform across all network edges, such that:

$ alpha_(i,j) = alpha quad forall i, j in V $

where $V$ is the set of all users in the network. This universal rate, $alpha$, represents the global `propagation_delay` of the network an platform: the continuous time required for a post to be processed by the platform's infrastructure and appearing into a follower's timeline.

This simplification plays very nice into the actual dynamics of modeling an OSN: content cannot immediately appear in other users timelines without any explanation, as that is not accurate in respect of reality and could generate degenerated cases (post being created and immediately having several reposts) on the simulation traces (see #todo[traces? is it worth it?]). Also, this conveys a implicit and very noticeable computational advantage. 

=== Activity-Driven Network Dynamics
<sec-method-activity>

When modeling an OSN with users as the primary entities, there is a particular aspect that is highly intuitive for human behavior but heterodox in traditional graph theory: nodes are not available for information transmission at all times; rather, their availability is a function of time $t$. 

Standard static network models assume that nodes and edges are perpetually available for information transmission. However, empirical studies of social and technological systems reveal that human interactions are fundamentally bursty and temporally disconnected @barabási2005bursts. To capture this reality, the Activity-Driven modeling framework describes a time-varying network where the topological evolution is strictly governed by the intrinsic behavioral patterns of individual nodes @pozzana2017epidemic.

In this paradigm, each user is characterized by an "activity" rate, defined as their propensity to engage with the network and form connections at a given time. Consequently, nodes alternate between discrete online sessions and offline "vacation" periods. As explained when modeling the problem (see @sec-method-model), this bursty interactions have already been modeled as $cal(O) (u)$, and despite no restrictions being imposed on it's nature, we can characterize it as

$ cal(O) (u) = union.big_(k=1)^oo [t_k, t_k + Delta_k) "where" t_k in T $

and $Delta_k$ is a positive random variable representing the sessions duration. 

- The interval $I_k = [t_k, t_k + Delta_k)$ constitutes the online duration (sampled from `session_duration`).
- The gap between sessions, mathematically expressed as $d = t_(k+1) - (t_k + Delta_k)$, constitutes the offline vacation period (sampled from `user_inter_session` see #todo[@ simconfig]).

In OSNs, these activity states are usually called sessions: a user starts a session when they log in to the platform to consume content, and it ends when they close the application or log off.

While the Activity-Driven framework dictates when users are present in the network via $cal(O)(u)$, it does not fully explain how they consume information. Social contagion is heavily moderated by the cognitive limits of human processing and the user interface of the platform itself #todo[Cite cognitive limits/attention economy paper]. 

An informal mathematical way of the lifetime analysis post is provided on @apx-lifetime.



== Discrete-Event Simulation
<sec-method-des>

Discrete-event simulation is a methodology consisting of a collection of techniques that when applied to a discrete-event dynamical system, generates sequences called sample paths that characterize its behavior. In that system, one or more phenomena of interest change value or state at discrete points in time, rather than continuously in time. @fishman2001des

Discrete-event simulation usually share a set of key elements, which relate to certain behaviours. In general, there is always a future time event, which are already scheduled events by the system, which have to be retrieved according from the more recent to the furthest away in the future @ross2006simulation.

Information diffusion (see @sec-sota-diffusionmodels) models information cascades, which are created by the repost of a post in a specific instant of time. This is, as already discussed when justifying the Continuous-Time Independent Cascade model (see @sec-method-ctic), a discrete-event dynamical system: the events are creation and propagation of a post, which can be reconstructed into the so called information cascades.

=== Description and Mechanics
<sec-method-des-mechanics>

The main mechanic of the simulation is the content propagation. When a post $i$ is propagated, gets appended to the timeline of all the followers the propagator of $i$ has.

$ "procedure propagate"(u, i) quad : quad  "push"( cal(T)_(t+Delta) (v) ) quad forall v in cal(N)_t (u) $ <eq-proc-propagate>

There are three distinct actions that a user can do in the simulation, which are three different types of entities that can be simultaneously queues at the same time.
1. Create post: creates a new post $j$ and adds it to the simulation. This propagates the created post $j$
2. Action: $"pop"(cal(T)_t (u))$ and makes one action according to the policy $pi_u$, which can take three possible values:
 - nothing: the user ignores the post, no action is taken.
 - like: the user marks the post as liked, and then it can't be liked anymore, but can be reposted.
 - repost: the user reposts the post $i$, which propagates it.
3. Go online: puts the user back online. When online can do any of the actions mentioned above.
4. Go offline: changes user state from online to offline. Now it cannot interact with any posts, nor create new ones.

As every user acts as an independent entity, it is convenient to make them act independently from one another; the queue $Q$ always contains an event of each type per user always preescheduled #todo[@ sec-design-heurisic]


To comply with the Continuous-Time Independent Cascade, we have to allow reexposition to a content the user has already ignored but coming from another edge (another of it's followees). It is considered then an interaction as a like or a post, so a user can propagate or not propagate a post but interact with it. A user cannot interact nor see again their own posts.

Therefore, we can give a more abstract expression of an event ---which is an element of the queue $Q$--- such as the tuple of $(u, e, t)$, where user $u$ at time $t$ has the event $e$, which can be either "create", "action", "go_online" or "go_offline".


=== Assumptions
<sec-method-des-assumptions>

To simplify both implementation and evaluation of the simulation, we assume the following simplifications in respect of how a real online social networks behaves to adapt to the scope of the project.

// 1. *User Homogeneity:* Every user $u in cal(U)$ is indistinguishable in behavior and shares the exact same decision policy $pi$ and creation rate $lambda$.
// $ forall u, v in cal(U) : pi^(u) = pi^(v) = pi quad "and" quad lambda^(u) = lambda^(v) = lambda $
//
1. *Post Homogeneity:* All posts are treated as content-agnostic commodities. A user's probability of executing an action $a$ is completely independent of the specific item being evaluated:
$ pi(a | i) = pi(a | j) = pi(a) quad forall i, j in cal(I), forall a in cal(R)'_(cal(U)cal(I)) $

2. *Action Independence (Markovian Behavior):* A user's choice to interact with a post $i$ at time $t$ depends strictly on the static policy $pi$ and is independent of their historical impression history $cal(H)_t (u)$. 

$ PP ( rho((u, i, a), t) = 1 mid cal(H)_t (u) ) = pi(a) $


As it's been discussed until now, the proposed model is a dynamical system in which its solution cannot be found analytically due to it's complexity. In a DES implementation, the system's state only changes at discrete points in time when a specific event occurs, allowing the simulation engine to jump efficiently from one event to the next without calculating the time in between. 

=== Parameters

The main parameters that define the simulation, once the simplificating assumptions are in place (see @sec-method-des-assumptions).
1. How often does a user sees a post: this is modeled as the time between every post.
2. Actions: the probability associated to every action the user can do when sees a post.
3. Sessions: how often does a user connect (time between sessions) and the session duration of the user. Additionally, from the whole user population, we start with a fraction of the user offline, which is a controlable parameters.
4. Propagation delay: time it takes for a post to be reposted or created and then be propagated.
5. Interaction and Creation delay: when a user decides which decision takes, the delay on realizing the action is implemented into the simulation. Additionally, there is a bigger delay when the user decides to create a post, which simulates the actual writing of the post.

#todo[Create a figure of all the delays]

To see the parameter calibration and results, see #todo[@ sec-data-cal]

=== Evaluation Metrics
<sec-method-des-metrics>

To evaluate the simulation, the following metrics are going to be obtained from the simulation traces:

#todo[Expand the first two sections slightily]

#todo[Mark which ones are caracteristic metrics vs fundamental metrics]

==== Reposts Power-law

According to the CTIC model, the number of reposts of a post should follow a power law, with $gamma in [2,3]$. That is, the log-log plot of the most to least sorted repost different post has should be drawn as a line. This is the same concept introduced in @sec-sota-topo-scalefree.


==== Post Lifetimes

This measures for how long a post is alive. In this context, alive means the time from the first repost from the last repost. This is also expected to follow some sort of power-law, as the post should get the big majority of interactions on their first ticks, and then abruptely decrease as time goes on.

==== Structural Virality

Virality is a concept that is more nuanced than it first appears. While content is said to have "gone viral" when it rapidly becomes popular through person-to-person contagion, popularity alone does not imply virality: a piece of content may reach a large audience through a single broadcast event (e.g., a post by a celebrity with millions of followers) just as easily as through multi-generational peer-to-peer propagation @goel2016structural. Distinguishing between these two mechanisms requires examining the fine-grained structure of the diffusion cascade itself, not just its aggregate size.

#todo[replicate figure 1 of the paper showing broadcast vs viral cascade structures]

Intuitively, the shape of the cascade matters: a "broadcast" cascade reaches many users but remains extremely shallow (all adoptions occur within one hop from the source), whereas a genuinely "viral" cascade propagates through multiple generations, with each individual responsible for only a fraction of the total adoptions. However, simple metrics like cascade depth are fragile---a single long chain in an otherwise flat broadcast can inflate the depth without indicating true viral spread @goel2016structural.

#todo[add the picture of broadcast vs viral cascade]

To address these shortcomings, Goel et al. @goel2016structural propose a formal measure of structural virality based on the Wiener index, a classical graph invariant from mathematical chemistry @wiener1947structural. For a cascade represented as a tree $T$ with $n > 1$ nodes, the structural virality $nu(T)$ is defined as the average distance between all pairs of nodes:

$ nu(T) = frac(1, n(n-1)) sum_(i=1)^n sum_(j=1)^n d_(i j) $

where $d_(i j)$ is the length of the shortest path between nodes $i$ and $j$. Equivalently, $nu(T)$ is the average depth of nodes, averaged over all nodes in turn acting as root @goel2016structural. The measure satisfies three desirable criteria:

1. For a fixed cascade size, structural virality is minimized on the star graph (pure broadcast), where $nu(T) approx 2$, and increases with the branching factor of the structure.
2. For a fixed branching factor, structural virality increases with the number of generations (depth) of the cascade.
3. In the extreme case of a pure broadcast, structural virality remains approximately independent of size, meaning larger broadcasts are not falsely classified as more viral.

#def(name: "Structural Virality")[
  A continuous measure of how "viral" a cascade is, defined as the average distance between all pairs of nodes in the cascade tree. Higher values indicate that adopters are, on average, farther apart, suggesting a multi-generational diffusion process rather than a single broadcast event. @goel2016structural
]


#comment[I could add here another section called “Why not agent-based modeling” but idk how
interesting is, if in the SotA i don’t introduce the OASIS paper or the big LLM things. Or
maybe not event the LLM stuff, but traditional ABM modeling in Social Networks
I got a draft of it, which it should convey the following information:
ABM tend to be computationally more complex (is that even true????) due to the agents
being “active” instead of passive. That means the main loop has to evaluate users that are offline
to discard they are even active. DES just jumps over that, as the event “go back online” just
needs to be processed when it’s attended. Also, ABMs, if they discrete the time into Δ𝑡 chunks]

// == Why not Agent-Based Modeling?
// <sec-method-abm>
//
// Agent-Based Modeling (ABM) is a bottom-up simulation paradigm in which a system is modeled as a collection of autonomous, self-directed agents that follow individual behavioral rules, perceive their environment, and interact with one another @bonabeau2002agent. Unlike DES, where entities are passive and their behavior is dictated by the system's process logic, agents in ABM are "active"---each maintains its own state and decision-making autonomy @siebers2010discrete. This natural one-to-one mapping between individual users and autonomous agents has led to ABM being widely adopted in the study of online social networks, where agent-centric modeling of user behavior is conceptually appealing.
//
// Despite this conceptual fit, ABM carries a substantial computational cost when applied at scale. Whether an ABM uses fixed time-stepping or event-driven scheduling, each agent's state must still be individually evaluated whenever the simulation requires it to act, react, or remain idle. In a microblogging platform with hundreds of thousands of users, the overwhelming majority are offline at any given instant---no decision is being made, no content is being consumed, and no propagation can occur. Yet under an agent-based paradigm, the simulator must still account for every user's presence, maintain their individual state, and check whether they are eligible to participate @maidstone2012discrete. The result is that computational effort scales with the number of users $N$ regardless of how few are actually active, making the approach increasingly wasteful as the network grows.
//
// Discrete-Event Simulation avoids this overhead through its fundamental operational principle: the simulator does not advance time in uniform steps, nor does it poll entities that have nothing to do. Instead, it maintains a chronologically ordered event queue and jumps directly from one scheduled event to the next, bypassing idle intervals entirely. Processing an event---such as a post creation or a user session initialization---may involve work proportional to the local network degree (iterating over a poster's followers, scheduling follow-up events), but no work is performed for the vast silent majority of users who are offline. Because human activity in microblogging is highly bursty and intermittent @barabási2005bursts, with prolonged gaps of inactivity between short engagement sessions, this event-driven design naturally exploits the system's intrinsic sparsity.
//
// Beyond runtime performance, ABM also demands substantially more development effort. Specifying perception, individual decision-making, and inter-agent communication for every user introduces considerable model complexity @bonabeau2002agent. Maidstone @maidstone2012discrete observes that ABS models tend to take significantly more time to develop than their DES counterparts, and that this added complexity is difficult to justify when the research question concerns aggregate diffusion dynamics rather than heterogeneous individual cognition. In DES, by contrast, the system is modeled top-down through a network of processes and queues: entities flow through the system according to probability distributions and predefined routing rules @fishman2002simulation, yielding a leaner model that remains expressive enough to capture population-level propagation behavior.
//
// In the context of this work, the choice becomes clear. An ABM of a Bluesky-scale network would require maintaining and evaluating individual agent state for every user, even though the vast majority are offline and unreachable for information transmission at any given moment. When coupled with the need for hundreds or thousands of independent replications to achieve statistical convergence across the parameter space, the computational demands of an agent-based approach would render large-scale exploration infeasible. The DES approach was therefore selected not only for its natural integration with the event-driven CTIC model (see @sec-method-ctic), but also for its ability to route computational effort where it matters---toward the propagation events that actually drive the dynamics---rather than toward polling idle users.
//

All evaluation metrics listed in this section are computed from the time-aggregated counters collected during simulation execution. The trace schema (see @sec-design-traces) captures every state transition as structured records, and the buffered I/O mechanism (see @sec-impl-trace-io) writes them to disk without stalling the simulation loop. These traces are then parsed offline to compute the power-law exponents, and structural virality scores described above.

== Random Number Generation
<sec-method-rng>

This section covers the implementations of the Random Number Generators needed in the main simulation, as Zig did not have a library of distributions. The distributions library has been published under the MIT license and its source available @soler2025distributions


=== Ziggurat Algorithm
The generation of random variates for continuous distributions, specifically the Normal, Exponential and Pareto distributions, relies on the highly optimized Ziggurat algorithm @marsaglia2000ziggurat. This method is a form of rejection sampling that overlays the target probability density function (PDF) with a set of $n=256$ horizontal rectangles (named after the Mesopotamian ziggurat temples for their tiered resemblance) of equal area, constructed such that they tightly bound the distribution curve.

Our implementation in Zig heavily leverages compile-time evaluation (`comptime`) to specialize the algorithm identically for both `f32` and `f64` precision without runtime overhead. The core optimization focuses on minimizing calls to the pseudo-random number generator (PRNG). Instead of requiring two distinct random values—one to select a rectangle and another to sample a point within it—a single 64-bit random integer is generated (or 32-bit for `f32`).

From this single random word, two values are extracted with zero PRNG overhead:
1. The lowest 8 bits are masked (`bits & 0xff`) to uniformly select the index $i$ of one of the 256 precomputed rectangles.
2. The remaining 52 bits are shifted and directly utilized as the mantissa of an IEEE 754 floating-point number @ieee2019floating, @goldberg1991floating.

To construct the uniform floating-point value efficiently, the integer mantissa is bitwise OR-ed with a predefined exponent mask. For symmetric distributions like the Normal, the exponent is chosen such that the resulting float falls into the interval $[2, 3)$. Subtracting 3 then shifts the domain to $[-1, 1)$. For asymmetric distributions like the Exponential, the exponent mask places the float in $[1, 2)$, and subtracting an offset near 1 yields a uniform variate in $[0, 1)$.

This uniformly distributed value $u$ is scaled by the $x$-coordinate boundary of the selected rectangle $i$, producing a candidate sample $x = u \cdot x_i$. If the candidate falls strictly within the core of the rectangle ($|x| < x_{i+1}$), it is immediately accepted. This fast-path covers approximately 99% of all generation requests and bypasses costly mathematical operations.

When a candidate falls outside the fast-path core, two edge cases are handled:
- *Boundary Cases:* If $i > 0$ and the sample is in the wedge between rectangles, an additional random draw evaluates the exact PDF to deterministically accept or reject the candidate.
- *Tail Cases:* If $i = 0$, the sample lies in the infinite tail of the distribution. A specialized `zeroCase` function handles this tail recursively. 
 - *Exponential* distribution, it evaluates the inverse transform @devroye1986nonuniform shifted by the rightmost boundary $R$, yielding $R - \ln(U)$. 
 - *Normal* distribution, it implements Marsaglia's tail generation, looping to draw values until $-2y < x^2$ is satisfied, and appropriately shifting the result by $R$.


=== Categorical Distribution
<sec-method-rng-categorical>

The categorical distribution models discrete random variables that can take on one of $k$ possible categories, each with a specific probability. In our Zig implementation, a categorical distribution is initialized with an array of distinct items (`data`) and their corresponding probabilities (`weights`). During initialization, an accumulator array (`acc`) is computed that stores the cumulative sum of the
given probabilities.

To sample from this distribution, we employ a standard inverse transform method @devroye1986nonuniform: a uniform floating-point value $u in [0, 1)$ is drawn and compared linearly against the cumulative weights array until a value satisfying $u <= text("acc")[i]$ is found, at which point the category at index $i$ is returned.

While theoretically faster alternatives like the Alias Method @walker1977alias exist --—capable of sampling in $O(1)$ time after a linear $O(k)$ setup—-- they introduce additional memory overhead and initialization complexity. For the context of this simulation, where $k$ is typically very small (e.g., modeling a handful of user action types), the performance difference is strictly negligible. Thus, we have opted for the linear search approach due to its simplicity and cache locality.

However, to optimize the performance of the linear search, the following convention has been maintained when constructing the distributions: the categories must always be sorted by their probability in descending order. By placing the most probable outcomes at the beginning of the arrays, the cumulative sum grows rapidly, maximizing the chance that the linear search terminates in the very first iterations, thereby achieving near $O(1)$ empirical performance.


=== Pareto Distribution

The Pareto Distribution is fundamental when talking about social networks, as its the distribution associated with the power-law. It's defined by two parameters, scale $alpha$ and shape $x_m$, and has the following density and cumulative density functions:

$ f(x | alpha, x_m ) = cases(frac(alpha x_m^alpha, x^(alpha + 1)) & "if" x >= x_m, 0 & "if" x < x_m )  $

$ F(x | alpha, x_m) = cases(
  1 - (frac(x_m, x))^alpha & "if" x >= x_m,
  0 &"if" x < x_m
)
$ 

To sample from it we've used the following relationship @casella2002statistical: a random variable $X$ follows a $"Pareto"(alpha, x_m)$ distribution when $Y ~ "Exp"(1)$ and

$ X ~ x_m · exp{Y/alpha} $

therefore being as efficient as generating an exponential with the ziggurat algorithm.


== Time-Variyng Heterogeneous Graphs
<sec-method-graph>

#comment[Esteve, I don't fully understand what I need to write here. Like, why did I need a time heterogeneous graph to model the problem? Because the problem is simply like this]

Revise the articles from the beginning. This is not about the data (users and relationships) and data, but the model of the data.



