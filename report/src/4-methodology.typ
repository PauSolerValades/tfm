#import "utils.typ": *
#import "@preview/lovelace:0.3.0": pseudocode-list

This chapter justifies and methodology elections: why the use of a discrete-event simulation methodology in @sec-method-des, why the DES framework has been chosen over the _de-facto_ standar of Complex and Social Science, Agent-Based Modelling in @sec-method-abm, and which method has been used to create the sessions in @sec-method-session.

Due to lenght constraints of this report, some rellevant sections have been moved to @apx-method, specifically every aspect concerning the Random Number Generation algorithms in @apx-method-rng ---which is an in depth description of the tailored-made `distributions` package for this project @soler2025distributions ---, which methods have been used for the goodness-of-fit tests in every distribution in @apx-method-gof, and the decision process on picking DBSCAN as the sessionization algorithm in @apx-method-session.

== Event Scheduling Discrete-Event Simulation
<sec-method-des>

Discrete-event simulation is a methodology consisting of a collection of techniques that when applied to a discrete-event dynamical system, generates sequences called sample paths that characterize its behavior. In that system, one or more phenomena of interest change value or state at discrete points in time, rather than continuously in time. @fishman2001des

Discrete-event simulation usually share a set of key elements, which relate to certain behaviours. In general, there is always a future time event, which are already scheduled events by the system, which have to be retrieved according from the more recent to the furthest away in the future @ross2006simulation.

Information diffusion (@def-informationdiffusion in @sec-sota-diffusionmodels) models information cascades, which are created by the repost of a post in a specific instant of time. This is, as already discussed when justifying the Ensamble of Collective CTICs model (see @sec-model-incubation), a discrete-event dynamical system: the events are creation and propagation of a post, which can be reconstructed into the so called information cascades.


=== Event Scheduling Algorithm
<sec-method-des-es>

This project will use the Event Scheduling algorithm @fishman2001eventscheduling, as the input parameters of the simulation (see Design @sec-design, Calibration @sec-calibration) can be easily expressed as a density of the simulation $f$ and its cumulative density $F$.


The Event Scheduling algorithm main characteristic is the *event-list*, *future event set* or *queue $Q$*, a data structure that holds all the already scheduled events that come from an event source. An event source is characterized by sampling from a specific distribution $F$.

The main idea of the algorithm is represented in @proc-event-scheduling, shown here on a $M \/ M \/ 1$ queue: a producer and a consumer share the future event set, and each source reschedules itself every time one of its events is popped. $lambda$ is the generation rate and $mu$ the service rate, sampled from the rate-parameterized exponential used throughout this report.

#procedure(caption: flex-caption([Event scheduling], [Event Scheduling algorithm on a $M \/M \/ 1$ queue: the future event set drives the clock, and each event source reschedules itself when popped.]))[
  #pseudocode-list[
    + *procedure* $"EventScheduling"(lambda, mu)$
      + $Q arrow.l "FutureEventSet"()$
      + $"prod" arrow.l "Exp"(lambda)$
      + $"cons" arrow.l "Exp"(mu)$
      + $t_"clock" arrow.l 0$
      + $"push"(Q, "Event"{t_"clock" + "prod"."sample"(), "producer", 0})$
      + $"push"(Q, "Event"{t_"clock" + "cons"."sample"(), "consumer", 1})$
      + *while* $t_"clock" < "horizon"$ *and* $Q != emptyset$
        + $"event" arrow.l "pop"(Q)$
        + $t_"clock" arrow.l "event"."time"$
        + *if* $"event"."type" == "producer"$ *then*
          + $"client_dispatched"()$
          + $"push"(Q, "Event"{t_"clock" + "prod"."sample"(), "producer", "event"."id" + 1})$
        + *else if* $"event"."type" == "consumer"$ *then*
          + $"client_arrives"()$
          + $"push"(Q, "Event"{t_"clock" + "cons"."sample"(), "consumer", "event"."id" + 1})$
        + *end*
      + *end*
    + *end*
  ]
]<proc-event-scheduling>

It can clearly be divided into three steps: the initialization of the events of each source, which starts the simulation; then, in the main loop, every time an event is processed a new one is scheduled by sampling again from its source ---in the example an exponential for both consumer and producer, as the process is Markovian--- which advances the simulation clock and ends the loop once the clock ---the timestamp of the last processed event--- reaches the simulation horizon.

=== Description
<sec-method-des-mechanics>

The propose of the simulation is the information diffusion, specifically the cascades generated when the content traverses the network. When a post $i$ is propagated, gets appended to the timeline of all the followers the propagator of $i$ has (and will be formalized with @proc-propagate in @sec-design-sources-propagate).

$ "procedure propagate"(u, i) quad : quad  "push"( cal(T)_(t+Delta) (v) ) quad forall v in cal(N)_"in" (u) $ <eq-proc-propagate>

There are four distinct actions that a user can do in the simulation, which translate into four different types of entities that can be in the Future Event Set at the same time.
1. Create post: creates a new post $j$ and adds it to the simulation. This propagates the created post $j$
2. Action: $"pop"(cal(T)_t (u))$ and makes one action according to the policy $pi_u$, which can take three possible values:
 - view: the user just reads or views the post, no action is taken.
 - like: the user marks the post as liked, and then it can't be liked anymore, but can be reposted.
 - repost: the user reposts the post $i$, which propagates it.
3. Go online: puts the user back online. When online can do any of the actions mentioned above.
4. Go offline: changes user state from online to offline. Now it cannot interact with any posts, nor create new ones.

As every user acts as an independent entity, it is convenient to make them act independently from one another; the queue $Q$ always contains an event of each type per user always prescheduled (see @sec-design-datastructures-queue).


To comply with the Continuous-Time Independent Cascade, we have to allow reexposition to a content the user has already ignored but coming from another edge (another of it's followees). It is considered then an interaction as a like or a post, so a user can propagate or not propagate a post but interact with it. A user cannot interact nor see again their own posts.

Therefore, we can give a more abstract expression of an event ---which is an element of the queue $Q$--- such as the tuple of $(u, e, t)$, where user $u$ at time $t$ has the event $e$, which can be either "create", "action", "connect" or "disconnect".


=== Assumptions
<sec-method-des-assumptions>

To simplify both implementation and evaluation of the simulation, we assume the following simplifications in respect of how a real online social networks behaves.

1. *User Homogeneity Policy:* Every user $u in cal(U)$ is indistinguishable in behavior and shares the exact same decision policy $pi$ and creation rate $lambda$.
 $ forall u, v in cal(U) : pi^(u) = pi^(v) = pi quad "and" quad lambda^(u) = lambda^(v) = lambda $

2. *Post Homogeneity:* All posts are treated as content-agnostic commodities. A user's probability of executing an action $a$ is completely independent of the specific item being evaluated:
$ pi(a | i) = pi(a | j) = pi(a) quad forall i, j in cal(I), forall a in cal(R)'_(cal(U)cal(I)) $

3. *Action Independence (Markovian Behavior):* A user's choice to interact with a post $i$ at time $t$ depends strictly on the static policy $pi$ and is independent of their historical impression history $cal(H)_t (u)$. 

$ PP ( rho((u, i, a), t) = 1 quad cal(H)_t (u) ) = pi(a) $

This simplifications must be added to stratify complexity and to provide an accurate management of time and scope for this project.

=== Parameters

Taking into account the simplifying assumptions (see @sec-method-des-assumptions), the main parameters ---quantities or distributions decided at the beginning of the simulation process that serve as input--- of the simulation are:
1. How often does a user sees a post: this is modeled as the time between every post.
2. Actions: the probability associated to every action the user can do when sees a post.
3. Sessions: how often does a user connect (time between sessions) and the session duration of the user. Additionally, from the whole user population, we start with a fraction of the user offline, which is a controllable parameter.
4. Propagation delay: time it takes for a post to be reposted or created and then be propagated.
5. Interaction and Creation delay: when a user decides which decision takes, the delay on realizing the action is implemented into the simulation. Additionally, there is a bigger delay when the user decides to create a post, which simulates the actual writing of the post.

@tbl-method-params list the bullet points main parameters with a small descritpion. Note: this is not the final configuration file of for the configuration (the final config is @tbl-res-config in @sec-results-execution) but to convey the main parameters that define the configuration.

#figure(
  table(
    columns: (1.1fr, 2fr),
    align: (left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Parameter*], [*Description*],
    table.hline(stroke: 0.5pt),
    [Interaction time], [Time between two consecutive actions of the same user: how often they check their timeline.],
    [Action policy], [Probability of each reaction to an inspected post: `view`, `like` or `repost`.],
    [Session duration], [How long a user stays online in a session.],
    [Gaps between sessions], [How long a user stays offline between two consecutive sessions.],
    [Initial offline fraction], [Share of the population that starts the simulation offline.],
    [Propagation delay], [Time for a post to travel from its author's action to a follower's timeline.],
    [Interaction delay], [Time a user takes to realise an action once decided.],
    [Creation delay], [Extra time needed to write a created post before it enters the simulation.],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Main parameters of the simulation],
    [The parameters that define the simulation, once the simplifying assumptions are in place.],
  )
) <tbl-method-params>

The value used for each of them in the reported execution is listed in @tbl-res-config (see @sec-results-execution).

=== Evaluation Metrics
<sec-method-des-metrics>

When designing a simulation, one must distinguish between evaluation metrics and characteristic magnitudes:
- *Evaluation metrics* are the metrics the simulation is built to observe, replicate or study.
- *Characteristic magnitudes* are the magnitudes the simulation must produce to verify its behaviour: the system is expected to show them, but they are not the objective of the study.

The following paragraphs list every magnitude the simulation observes, classified as evaluation metrics or characteristic magnitudes.

==== Repost Count Distribution

The first magnitude is the distribution of the number of reposts a post receives. Ordering all posts from most to least reposted, the counts should follow a heavy-tailed distribution whose log-log plot decays approximately as a straight line, the same scale-free behaviour introduced in @sec-sota-topo-scalefree. The tail is summarised by two fitted parameters: the exponent $alpha$, which sets how fast the tail decays ---a larger $alpha$ means fewer extremely popular posts--- and the lower cutoff $x_"min"$, the repost count above which the power law is fitted.  This is a characteristic magnitude of the simulation.

==== Cascade Metrics

A post together with its reposts forms an information cascade, naturally represented as a tree rooted at the post's author: every edge is a repost, directed from a reposter to the user they reposted from (@fig-sota-cascade). Let $T$ be such a cascade tree. Its size, depth and width are the characteristic magnitudes compared against the empirical data, and are defined as follows.

#def(name: "Cascade Size")[
  The number of distinct users that reposted the post, the author included:
  $ S(T) = |T|. $
]

#def(name: "Cascade Depth")[
  The number of generations of reposters, measured as the length in edges of the longest path from the root to any node of the tree:
  $ D(T) = max_(v in T) "depth"(v). $
  The root sits at depth $0$, its direct reposts at depth $1$, and so on, so a broadcast cascade has $D(T) = 1$ and any repost-of-a-repost forces $D(T) >= 2$.
]

#def(name: "Cascade Width")[
  The largest number of direct reposts attributed to a single node, i.e. the maximum out-degree of the tree:
  $ W(T) = max_(v in T) "out-degree"(v). $
  For a broadcast cascade the widest node is the root, so the width is exactly the first hop, the number of users the post reached directly. This is the magnitude reported as the *max out-degree* of a cascade.
]

A post whose tree is a single node (no repost) is a trivial cascade; the *cascade rate* is the share of posts that receive at least one repost, and only these non-trivial cascades enter the statistics above. Following @goel2016structural, cascades are further split into *broadcast* ($D(T) = 1$, a star) and *viral* ($D(T) >= 2$), and the broadcast share is reported alongside the tree metrics.

==== Structural Virality

Virality is a concept that is more nuanced than it first appears. While content is said to have "gone viral" when it rapidly becomes popular through person-to-person contagion, popularity alone does not imply virality: a piece of content may reach a large audience through a single broadcast event (e.g., a post by a celebrity with millions of followers) just as easily as through multi-generational peer-to-peer propagation @goel2016structural. Distinguishing between these two mechanisms requires examining the fine-grained structure of the diffusion cascade itself, not just its aggregate size.

Intuitively, the shape of the cascade matters: a "broadcast" cascade reaches many users but remains extremely shallow (all adoptions occur within one hop from the source), whereas a genuinely "viral" cascade propagates through multiple generations, with each individual responsible for only a fraction of the total adoptions. However, simple metrics like cascade depth are fragile ---a single long chain in an otherwise flat broadcast can inflate the depth without indicating true viral spread @goel2016structural. The @fig-broadcast-vs-viral-2 showcases this differences.

#figure(
  image("../images/sota/broadcast-vs-viral.jpg", width: 70%),
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

All magnitudes listed in this section will be computed from the traces collected during simulation execution. The trace schema (see @sec-design-traces) captures every state transition as structured records, and the buffered I/O mechanism (see @apx-impl-trace-io) writes them to disk without stalling the simulation loop. These traces are then parsed once all replications are done into a dataset to analyze and compute the desired metrics.


== Simulation Paradigm Choice
<sec-method-abm>

The topic of this project is clearly in the Complex Social Science field @miller2007complex, a field that, when needs to simulate human behaviour, defaults to Agent Based Modeling. This paradigm feels as the opposite methodological procedure than DES. Operational Research (OR) usually relies on Discrete-Event Simulation (DES) @maidstone2012discrete, while Complex Social Science defaults to Agent-Based Modeling (ABM) to study collective behavior and contagion @bonabeau2002agent. While simulating information cascades on a social network conceptually aligns with more with ABM, this section aims to give an insight why DES is the most appropriate mathematical and structural fit for this specific work, not only due to the model election (see @sec-model-ctic).

Let's first define what both paradigms should be used for: ABM is a bottom-up paradigm where autonomous agents follow behavioural rules and interact with their environment @bonabeau2002agent, while in DES entities are typically passive tokens moving trough a system's process logic @siebers2010discrete. However, Siebers et al. argue that "true ABS models in OR do not exist" in his article, making the previously defined theoretical distinction usless in practice, as none can adhere fully in one paradigm. Following Siebers descritpion, practicioners build combined models where a DES backbone is _augmented_ with entity-specific states. This is a very accurate description of what the _User_ entity has become in the simulation this work offers, as will be explained in @sec-design - Design, as every user carries personalized and empirical calibrated parameters.

So, one could argue that this simulation is nothing but an ABM in with a DES paint of coat over it, where the user entity exist but has not been designed. Luckly, this is not the case, as Sumari et al. adds another criterion for an Agent Based Simulation to have: every single user should be an autonomous agent with the hability to make decisions, and the implemented simulation _does not model individual cognitive decision-making_. This fact is even more reinforced by the chosen algorithm used in the implementation, the Event-Scheduling @sec-method-des-es. In another article, Sumari's et al. warns of DES being less suited to analyze complex human behaviour as its focus is on process flows @sumari2013comparing, but the simulation specificaly has a content agnostic model, which converts the "autonomy" of the agents in a fixed $pi$ policy (see @sec-method-des-assumptions), uniform regardless of the agent.

Without _user preferences_, the remaining of its behaviour can be explained with just density and cumulative functions from empirical data, which supports the Event Scheduling algorithm deeply, as it's almost its main use case. DES natively excels at routing entities thorught networks of queues and servers @fishman2001des. Additionally, the concept of queue is difficult to find on standars ABM frameworks @siebers2010discrete, and the design of the dynamics of the simulation deeply require queues (the timeline of a user, and this would be necessary with more sophisticated recommender algorithms other than reverse-chronological timeline) this makes DES a perfect fit. 

Ultimately, DES was selected because the designed model suited an Event Scheduling algorithm almost perfectly: several queues to model, empircal data measurements adequate for the current form, and avoidance of modelization of the autonomy of the users. Regardless, the simulation can be argued to have ABM influence, as heterogeneous parametrization of users, viewed as in purely "event sources" framework, would mean that every user three sources of its own, which would came out as a weird modeling choice. If more development on this project is done and more autonomy given to the user entity, probably the architectural constrains should be evaluated if giving more autonomy to the agent might improve overall clarity. Despite that, a good conclusion for this section is that theoretical rigidiy on the paradigm will probably not offer the best results as in simplicty and performance, and that hybrid architectures such as the one this simulation presents ---even if it's more DES than ABM--- will yield better results overall.


== Sessions Creation
<sec-method-session>

In order to find both `session_lenght` and `inter_session_duration` variables, data from the Bluesky Firehose will be processed, analyzed to obtain when the user is online or offline, replicating the $cal(O) (u)$ structure defined in @sec-method-activity.

As Barbási states in @barabási2005bursts, this won't be approximable by a Poission distribution. In fact, this problem is known as the Burst Detection problem or State Detection Over an Event Stream in Data Mining @kleinberg2003bursty   or, in a more simple form, a sessionization problem @kooti2016twitter.

The data to obtain the sessions is a series of timestamps of events that mark the user performed one action at a timestamp $t$ (see @sec-data for a more in depth explanation of the events) in which we want to aggregate them into two states: the user being online and interacting with the platform of offline.

It is believed by the author that the most theoretically grounded approach would be ---following the spirit of the two-state model in Kleinberg et al. @kleinberg2003bursty --- a hidden Markov model over the inter-arrival gaps. This method, however, is sophisticated and difficult to implement correctly, and was judged unjustified for this project given time and scope constraints.

Regaring the alternative methods, Kleinberg @kleinberg2003bursty identifies the central weakness of fixed-threshold approaches to this problem: because activity rate is locally "rugged," a single global cutoff fragments long, low-intensity bursts into spurious short ones, therefore a more nuanced method than global threshold ---despite being used in some studies @kooti2016twitter --- uniform across all users. Instead, this work explores density-based clustering methods such as DBSCAN @ester1996dbscan  as a more tractable alternative for session creation.


==== DBSCAN

DBSCAN (Density-Based Spatial Clustering of Applications with Noise) is a density-based clustering paradigm that provides a non-hierarchical labeling of data objects based on a global density threshold @mcinnes2017hdbscan. 

The algorithm operates on a few key concepts, which are often formalized as DBSCAN\* to remain consistent with statistical models of continuous density level sets @ester1996dbscan :
- *Core Object*: An object is considered a core object with respect to a radius $epsilon$ and a smoothing parameter $m_"pts"$ if its $epsilon$-neighborhood contains at least $m_"pts"$ objects @mcinnes2017hdbscan. Objects that fail to meet this density criterion are labeled as noise @mcinnes2017hdbscan.
- *$epsilon$-Reachable*: Two core objects are considered $epsilon$-reachable if they fall within each other's $epsilon$-neighborhood @ester1996dbscan.
- *Density-Connected*: Two core objects are density-connected if they are either directly or transitively $epsilon$-reachable @ester1996dbscan.
- *Cluster*: A cluster is defined as a non-empty, maximal subset of objects where every pair is density-connected @ester1996dbscan.

While highly effective, DBSCAN's primary limitation lies in its reliance on a single, global density threshold ($epsilon$) @mcinnes2017hdbscan that does not adapt user-base. This makes it difficult to properly characterize datasets containing nested clusters or clusters of widely varying densities @mcinnes2017hdbscan. This is the case with the sessionization problem this work tackles, as even within the same user events, the density of the clusters can vary according to certain external factors: user might be less engaged at night therefore there is less signal but the session is equally large, the short "checking a notification session" might have a very different density than more lengthy sessions. DBSCAN, despite using a different threshold per user $epsilon$ would not be able to detect distinct types of sessions inside the same user.

