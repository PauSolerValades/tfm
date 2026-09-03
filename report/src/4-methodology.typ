#import "utils.typ": *

This chapter justifies and methodology elections: why the use of a discrete-event simulation methodology in @sec-method-des, why the DES framework has been chosen over the _de-facto_ standar of Complex and Social Science, Agent-Based Modelling in @sec-method-abm, and which method has been used to create the sessions in @sec-method-session.

Due to lenght constraints of this report, some important sections have been moved to @apx-method, specifically every aspect concerning the Random Number Generation algorithms in @apx-method-rng ---which is an in depth description of the tailored made for this project `distribution` library @soler2025distributions ---, which methods have been used for the goodness-of-fit tests in every distribution in @apx-method-gof, and the decision process on picking DBSCAN as the session algorithm in @apx-method-session.


== Discrete-Event Simulation
<sec-method-des>

Discrete-event simulation is a methodology consisting of a collection of techniques that when applied to a discrete-event dynamical system, generates sequences called sample paths that characterize its behavior. In that system, one or more phenomena of interest change value or state at discrete points in time, rather than continuously in time. @fishman2001des

Discrete-event simulation usually share a set of key elements, which relate to certain behaviours. In general, there is always a future time event, which are already scheduled events by the system, which have to be retrieved according from the more recent to the furthest away in the future @ross2006simulation.

Information diffusion (see @sec-sota-diffusionmodels) models information cascades, which are created by the repost of a post in a specific instant of time. This is, as already discussed when justifying the Continuous-Time Independent Cascade model (see @sec-method-ctic), a discrete-event dynamical system: the events are creation and propagation of a post, which can be reconstructed into the so called information cascades.

=== Description
<sec-method-des-mechanics>

The propose of the simulation is the information diffusion, specifically the cascades generated when the content traverses the network. When a post $i$ is propagated, gets appended to the timeline of all the followers the propagator of $i$ has.

$ "procedure propagate"(u, i) quad : quad  "push"( cal(T)_(t+Delta) (v) ) quad forall v in cal(N)_t (u) $ <eq-proc-propagate>

There are three distinct actions that a user can do in the simulation, which are three different types of entities that can be simultaneously queues at the same time.
1. Create post: creates a new post $j$ and adds it to the simulation. This propagates the created post $j$
2. Action: $"pop"(cal(T)_t (u))$ and makes one action according to the policy $pi_u$, which can take three possible values:
 - nothing: the user ignores the post, no action is taken.
 - like: the user marks the post as liked, and then it can't be liked anymore, but can be reposted.
 - repost: the user reposts the post $i$, which propagates it.
3. Go online: puts the user back online. When online can do any of the actions mentioned above.
4. Go offline: changes user state from online to offline. Now it cannot interact with any posts, nor create new ones.

As every user acts as an independent entity, it is convenient to make them act independently from one another; the queue $Q$ always contains an event of each type per user always prescheduled (see @sec-design-datastructrues-queue).


To comply with the Continuous-Time Independent Cascade, we have to allow reexposition to a content the user has already ignored but coming from another edge (another of it's followees). It is considered then an interaction as a like or a post, so a user can propagate or not propagate a post but interact with it. A user cannot interact nor see again their own posts.

Therefore, we can give a more abstract expression of an event ---which is an element of the queue $Q$--- such as the tuple of $(u, e, t)$, where user $u$ at time $t$ has the event $e$, which can be either "create", "action", "go_online" or "go_offline".


=== Assumptions
<sec-method-des-assumptions>

To simplify both implementation and evaluation of the simulation, we assume the following simplifications in respect of how a real online social networks behaves to adapt to the scope of the project.

1. *User Homogeneity Policy:* Every user $u in cal(U)$ is indistinguishable in behavior and shares the exact same decision policy $pi$ and creation rate $lambda$.
 $ forall u, v in cal(U) : pi^(u) = pi^(v) = pi quad "and" quad lambda^(u) = lambda^(v) = lambda $

2. *Post Homogeneity:* All posts are treated as content-agnostic commodities. A user's probability of executing an action $a$ is completely independent of the specific item being evaluated:
$ pi(a | i) = pi(a | j) = pi(a) quad forall i, j in cal(I), forall a in cal(R)'_(cal(U)cal(I)) $

3. *Action Independence (Markovian Behavior):* A user's choice to interact with a post $i$ at time $t$ depends strictly on the static policy $pi$ and is independent of their historical impression history $cal(H)_t (u)$. 

$ PP ( rho((u, i, a), t) = 1 mid cal(H)_t (u) ) = pi(a) $

As it's been discussed until now, the proposed model is a dynamical system in which its solution cannot be found analytically due to it's complexity. In a DES implementation, the system's state only changes at discrete points in time when a specific event occurs, allowing the simulation engine to jump efficiently from one event to the next without calculating the time in between. 

=== Parameters

The main parameters that define the simulation, once the simplificating assumptions are in place (see @sec-method-des-assumptions).
1. How often does a user sees a post: this is modeled as the time between every post.
2. Actions: the probability associated to every action the user can do when sees a post.
3. Sessions: how often does a user connect (time between sessions) and the session duration of the user. Additionally, from the whole user population, we start with a fraction of the user offline, which is a controllable parameter.
4. Propagation delay: time it takes for a post to be reposted or created and then be propagated.
5. Interaction and Creation delay: when a user decides which decision takes, the delay on realizing the action is implemented into the simulation. Additionally, there is a bigger delay when the user decides to create a post, which simulates the actual writing of the post.

To see the parameter calibration and results, see @sec-cal-policy

=== Evaluation Metrics
<sec-method-des-metrics>

When designing a simulation, one must have a good distinction between desired quantities ---which metrics is the simulation being build to observe--- and characteristic quantities ---which metrics will the simulation produce. The reposts power-law is a characteristic quantity, as must be reproduced by the simulation to verify its behaviour. Post Lifetimes and Structural Virality are in fact desired quantities to replicate, as in how the input changes will change the output.

==== Reposts Power-law

According to the CTIC model, the number of reposts of a post should follow a power law, with $gamma in [2,3]$. That is, the log-log plot of the most to least sorted repost different post has should be drawn as a line. This is the same concept introduced in @sec-sota-topo-scalefree.


==== Structural Virality

Virality is a concept that is more nuanced than it first appears. While content is said to have "gone viral" when it rapidly becomes popular through person-to-person contagion, popularity alone does not imply virality: a piece of content may reach a large audience through a single broadcast event (e.g., a post by a celebrity with millions of followers) just as easily as through multi-generational peer-to-peer propagation @goel2016structural. Distinguishing between these two mechanisms requires examining the fine-grained structure of the diffusion cascade itself, not just its aggregate size.

Intuitively, the shape of the cascade matters: a "broadcast" cascade reaches many users but remains extremely shallow (all adoptions occur within one hop from the source), whereas a genuinely "viral" cascade propagates through multiple generations, with each individual responsible for only a fraction of the total adoptions. However, simple metrics like cascade depth are fragile ---a single long chain in an otherwise flat broadcast can inflate the depth without indicating true viral spread @goel2016structural. The @fig-broadcast-vs-viral-2 showcases this differences.

#figure(
  image("../images/sota/broadcast-vs-viral.jpg", width: 80%),
  caption: flex-caption(
    [Broadcast vs viral cascade structures.],
    [Broadcast vs viral cascade structures. A broadcast cascade (right) radiates directly from a single source to many followers. A viral cascade (left) propagates through multiple generations of reposts, forming a deeper tree structure. Image from Goel et. al @goel2016structural]
  )
) <fig-broadcast-vs-viral-2>

To address these shortcomings, Goel et al. @goel2016structural propose a formal measure of structural virality based on the Wiener index, a classical graph invariant from mathematical chemistry @wiener1947structural. For a cascade represented as a tree $T$ with $n > 1$ nodes, the structural virality $nu(T)$ is defined as the average distance between all pairs of nodes:

$ nu(T) = frac(1, n(n-1)) sum_(i=1)^n sum_(j=1)^n d_(i j) $

where $d_(i j)$ is the length of the shortest path between nodes $i$ and $j$. Equivalently, $nu(T)$ is the average depth of nodes, averaged over all nodes in turn acting as root @goel2016structural. The measure satisfies three desirable criteria:

1. For a fixed cascade size, structural virality is minimized on the star graph (pure broadcast), where $nu(T) approx 2$, and increases with the branching factor of the structure.
2. For a fixed branching factor, structural virality increases with the number of generations (depth) of the cascade.
3. In the extreme case of a pure broadcast, structural virality remains approximately independent of size, meaning larger broadcasts are not falsely classified as more viral.

#def(name: "Structural Virality")[
  A continuous measure of how "viral" a cascade is, defined as the average distance between all pairs of nodes in the cascade tree. Higher values indicate that adopters are, on average, farther apart, suggesting a multi-generational diffusion process rather than a single broadcast event. @goel2016structural
]


All evaluation metrics listed in this section will be computed from the traces collected during simulation execution. The trace schema (see @sec-design-traces) captures every state transition as structured records, and the buffered I/O mechanism (see @apx-impl-trace-io) writes them to disk without stalling the simulation loop. These traces are then parsed once all replications are done into a dataset to analyze and compute the desired quantities.


== Simulation Paradigm Choice
<sec-method-abm>

The topic of this project is clearly in the Complex Social Science field @miller2007complex, but its author comes from an OR and Statistics master: two disciplines that default to two different paradigms with opposing methodological defaults. Operational Research (OR) heavily relies on Discrete-Event Simulation (DES) @maidstone2012discrete, while Complex Social Science defaults to Agent-Based Modeling (ABM) to study collective behavior and contagion @bonabeau2002agent. While simulating information cascades on a social network conceptually aligns with ABM, this section justifies why DES is the most appropriate mathematical and structural fit for this specific work.

ABM is a bottom-up paradigm where autonomous agents follow behavioral rules and interact with their environment @bonabeau2002agent. In contrast, DES entities are typically passive tokens moving through a system's process logic @siebers2010discrete. However, the distinction in practice is rarely absolute. As Siebers et al. observe, "true ABS models in OR do not exist"; rather, practitioners build combined models where a DES backbone is augmented with entity-specific states @siebers2010discrete. The present simulation fits this description precisely, as it utilizes a classical DES architecture, yet each user carries personalized, empirically calibrated temporal parameters (e.g., session durations, inter-creation times and the degree in the network topology). Users are heterogeneous, but they are not fully autonomous agents because the simulation _does not model individual cognitive decision-making_.

This lack of cognition is the key in the paradigm choice. Sumari et al. warn that DES is less suitable for analyzing complex human behavior because its focus is on process flows @sumari2013comparing. If this research explored *why* a user reposts based on emotional or semantic factors, ABM would be a better fit. However, in this content-agnostic model, the user action policy $pi$ is a global categorical distribution sampled independently of the post itself (see @sec-method-des-assumptions). The human element is deliberately abstracted into a stochastic process, removing the cognitive autonomy that ABM is designed to simulate.

By removing user preferences, the model remains more akind to DES territory. DES natively excels at routing entities through networks of queues and servers @fishman2001des, and cucially, while DES is inherently built around queuing structures, the concept of queues does not natively exist in standard ABM frameworks @siebers2010discrete. Because the CTIC model relies on reverse-chronological timelines that function strictly as queues, DES provides the exact architectural infrastructure required to simulate them.

Furthermore, human activity in microblogging is highly bursty @barabási2005bursts; the vast majority of users are offline at any given instant. DES natively exploits this by jumping chronologically from scheduled event to event, bypassing idle intervals entirely. This computational efficiency is critical for scaling to bigger networks, serving as a powerful empirical benefit of the chosen paradigm.

Ultimately, DES was selected because the core research question ---aggregate diffusion dynamics under stochastic user activity--- does not require cognitive agent autonomy. The model operates as a combined DES/ABS architecture, using DES for process flow and ABS principles for heterogeneous parametrization. If future iterations lift the content-agnostic assumption and introduce semantic decision-making (see @sec-future-content), the architectural constraints of the model would need to be carefully re-evaluated, potentially prompting a paradigm shift toward a more traditional ABM framework.

== Sessions Creation
<sec-method-session>

In order to find the both `session_lenght` and `inter_session_duration` variables, data from the Bluesky Firehose will be processed to obtain when the user is online or offline, replicating the $cal(O) (u)$ structure defined in @sec-model.

As Barbási states in @barabási2005bursts, this won't be approximable by a Poission distirbution. In fact, this problem is known as the Burst Detection problem or State Detection Over an Event Stream in Data Mining @kleinberg2003bursty   or, in a more simple form, a sessionization problem @kooti2016twitter.

The data to obtain the sessions is a series of timestamps of events that mark the user performed one action at a timestamp $t$ (see @sec-data for a more in depth explanation of the events) in which we want to aggregate them into two states: the user being online and interacting with the platform of offline.

It is believed by the author that the most theoretically grounded approach would be ---following the spirit of the two-state model in Kleinberg et al. @kleinberg2003bursty --- a hidden Markov model over the inter-arrival gaps. This method, however, is sophisticated and difficult to implement correctly, and was judged unjustified for this project given time and scope constraints.

Regaring the alternative methods, Kleinberg @kleinberg2003bursty identifies the central weakness of fixed-threshold approaches to this problem: because activity rate is locally "rugged," a single global cutoff fragments long, low-intensity bursts into spurious short ones, therefore a more nuanced method than global threshold ---despite being used in some studies @kooti2016twitter --- uniform across all users. Instead, this work explores density-based clustering methods such as DBSCAN @ester1996dbscan  as a more tractable alternative for session creation.


*DBSCAN*

DBSCAN (Density-Based Spatial Clustering of Applications with Noise ) is a density-based clustering paradigm that provides a non-hierarchical labeling of data objects based on a global density threshold @mcinnes2017hdbscan. 

The algorithm operates on a few key concepts, which are often formalized as DBSCAN\* to remain consistent with statistical models of continuous density level sets @ester1996dbscan :
- *Core Object*: An object is considered a core object with respect to a radius $epsilon$ and a smoothing parameter $m_"pts"$ if its $epsilon$-neighborhood contains at least $m_"pts"$ objects @mcinnes2017hdbscan. Objects that fail to meet this density criterion are labeled as noise @mcinnes2017hdbscan.
- *$epsilon$-Reachable*: Two core objects are considered $epsilon$-reachable if they fall within each other's $epsilon$-neighborhood @ester1996dbscan.
- *Density-Connected*: Two core objects are density-connected if they are either directly or transitively $epsilon$-reachable @ester1996dbscan.
- *Cluster*: A cluster is defined as a non-empty, maximal subset of objects where every pair is density-connected @ester1996dbscan.

While highly effective, DBSCAN's primary limitation lies in its reliance on a single, global density threshold ($epsilon$) @mcinnes2017hdbscan. This makes it difficult to properly characterize datasets containing nested clusters or clusters of widely varying densities @mcinnes2017hdbscan. This is the case with the sessionization problem this work tackles, as even within the same user events, the density of the clusters can vary according to certain external factors: user might be less engaged at night therefore there is less signal but the session is equally large, the short "checking a notification session" might have a very different density than more lengthy sessions. DBSCAN, despite using a different threshold per user $epsilon$ would not be able to detect distinct types of sessions inside the same user.

