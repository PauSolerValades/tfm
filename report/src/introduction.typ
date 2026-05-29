#import "utils.typ": *

== Background

Online Social Networks (OSNs) have evolved from simple interpersonal communication utilities into complex, socio-technical ecosystems that fundamentally govern the modern information landscape. Among various configurations, the microblogging format—pioneered by Twitter in 2006 @arrington2006twttr —introduced unique structural constraints: strict character limitations and asymmetric follower-followee topologies. This format detonated a "before and after" in how social networks were perceived and used, as it broke from the paradigm of mutual friendship (where both users must agree to be connected) into one where any user can follow any other without explicit permission. Content consumption within these networks historically relied on chronological timelines, where information propagation is mediated through user-driven amplification mechanisms such as reposts.

Every change made to a microblogging platform alters the dynamics of content diffusion: which posts reach further, are seen by more people, or go viral. The introduction of algorithmic feeds, recommendation systems, and notification delivery reshapes what users see and when. Over time, the platforms that host public discourse have accumulated immense control over how information flows, and with it, over the shape of public conversation itself.

In recent years, the structural centralization of mainstream OSNs has prompted a paradigm shift toward open, decentralized alternatives. A prominent manifestation of this movement is Bluesky, built upon the Authenticated Transfer Protocol (AT Protocol)[cite: 1]. By separating data storage from the application layer, the AT Protocol presents unprecedented transparency for network science. It provides researchers with open access to full behavioral telemetry—capturing macroscopic topology alongside discrete user actions—at a scale previously obscured by corporate data privatization. This is not a minor detail: for the first time, researchers can access raw, unaggregated data detailing who follows whom, who posts what, and who interacts with which content, entirely free from the filtering mechanisms of a platform's internal analytics team. This work builds directly on top of that opportunity.

== The Problem of Information Diffusion

Information diffusion is the study of how discrete pieces of content propagate through a network infrastructure over time. Within a modern microblogging environment, the mechanics of spread are governed by an intricate interplay of three primary axes:

- *Platform Affordances:* The architectural features of the system—user interfaces, chronological feeds, notification delivery, recommendation algorithms—that determine the structural pathways through which content can reach a user. A reverse-chronological timeline is not functionally equivalent to an algorithmic feed; a platform implementing an explicit repost mechanism creates distinct cascading trees compared to one without it. These are not neutral design choices; they actively shape what spreads and what dies.

- *User Dynamics:* The explicit behavior patterns of individuals: when they log in, how long they scroll, how frequently they create posts, and what actions they take when presented with content. Human activity in social media is highly bursty and intermittent @barabási2005bursts —users reside offline far more than they are online— and these rhythms create narrow temporal windows of opportunity for content to be either prioritized or buried.

- *User-Content Interaction:* The semantic alignment between a post's message and a user's latent preferences, rooted in homophilic dynamics. A user who likes sports cars will predictably engage more with content about sports cars. This is, intuitively, the most powerful driver of engagement—but it is also the most complex to model, as it requires representing both the semantic footprint of posts and the high-dimensional preferences of users in a computationally tractable way.

Mathematical modelization of these combined factors quickly becomes analytically intractable due to the non-linear emergent feedback loops inherent to complex systems. Consequently, researchers must rely on programmatic simulations. The current state of the art primarily utilizes Agent-Based Modeling (ABM) —-a bottom-up paradigm where each user is modeled as an autonomous agent with its own internal state and decision-making logic @bonabeau2002agent. This one-to-one mapping between users and agents is conceptually appealing, and it has led to ABM being widely adopted in the study of online social networks.

Despite this conceptual fit, ABM carries a substantial computational cost at scale. In ABM, agents are "active" —-each maintains its own state and behavioral autonomy @siebers2010discrete. This means that even when an agent is offline and doing nothing, the simulation must still account for its presence, maintain its state, and determine whether it is eligible to participate. Maidstone @maidstone2012discrete observes that ABS models tend to take significantly more development time than their DES counterparts, and that this added complexity is difficult to justify when the research question concerns aggregate diffusion dynamics rather than heterogeneous individual cognition.

This work challenges that paradigm. Instead of ABM, this project adopts a Discrete-Event Simulation (DES) approach. In DES, entities are "passive" —-their behavior is dictated by the system's process logic @siebers2010discrete. Rather than advancing time in uniform steps, the simulator maintains a chronologically ordered event queue and jumps directly from one scheduled timestamp to the next, bypassing inactive intervals entirely. Processing an event —-a user logging in, creating a post, or executing a repost-— involves work proportional to the local network degree, but no computational effort is spent on the silent majority of offline users. Fishman @fishman2002simulation characterizes DES as a top-down approach in which entities flow through networks of queues according to probability distributions and predefined routing rules —-a leaner framework that remains expressive enough to capture population-level propagation behavior without the overhead of individual agent cognition.

== Justification & Societal Impact

Understanding information diffusion is deeply tied to safeguarding civic discourse and maintaining a healthy democracy. Modern populations increasingly rely on decentralized media as their primary vehicle for establishing shared realities. When communication networks fracture into self-reinforcing echo chambers, or when users experience systemic timeline starvation—where content is buried faster than anyone can see it—the capacity for citizens to engage with collective topics simultaneously is severely degraded.

This research aligns directly with the underlying motivations of the DeSiRe (Democracies Need Functioning Civic Discourse) project @lasser2025desire[cite: 1]. The core argument is straightforward: democracies require their citizens to be able to act on the same topic at the same time, and the primary channel of information for a vast majority of individuals has transitioned to social media. To audit, understand, and ultimately improve these digital spaces, researchers require robust computational sandboxes—environments where structural platform changes can be isolated and their effects on discourse observed without experimenting on live populations.

Building these analytical tools necessitates establishing a controlled structural baseline. Before we can accurately evaluate the sociological impact of recommendation engines, semantic polarization, or content-aware viral dynamics, we must first isolate and understand the fundamental baseline dictated by platform infrastructure and human activity rhythms. This thesis aims to establish that foundational benchmark, proving how structural constraints limit content diffusion before content characteristics are introduced.

== Objectives & Scope

The overarching objective of this thesis is to challenge the traditional simulation paradigm by designing, calibrating, and executing a high-performance Discrete-Event Simulation capable of evaluating a continuous-time cascade model at a scale matching a real microblogging network within practical execution times.

To achieve this, the project encompasses the following specific operational objectives:

+ *Model Formalization:* Define a unified mathematical framework modeling a microblogging platform as a Time-Varying Heterogeneous Graph. The relational scope is explicitly restricted to chronological following feeds and static topologies—the graph does not grow, shrink, or rewire during the simulation run.

+ *Calibrated Implementation:* Implement a high-performance simulation engine from scratch using the Zig systems programming language @zig. The engine must handle networks exceeding $10^6$ users while maintaining execution latencies that allow for extensive statistical replication—hundreds of independent runs across the parameter space.

+ *Empirical Extraction:* Conduct an exploratory data analysis on real-world Bluesky Firehose telemetry to map human activity distributions. Specifically, we extract empirical session lengths, inter-session gaps, post-creation cycles, and discrete action probabilities. These distributions serve as the structural framework of the simulation; without them, the execution relies entirely on arbitrary approximations.

+ *Validation:* Empirically validate the resulting simulation traces against observed structural virality metrics and cascade size distributions, verifying model accuracy while explicitly documenting structural constraints—such as timeline starvation—that emerge from the interplay of platform mechanics and user behavior.

+ *Scope Restriction:* This work deliberately enforces strict post homogeneity and action independence. Every post is treated as identical in content; every user follows an identical decision policy when encountering a post. Semantic features—what the post actually says, and whether the user agrees with it—are treated as out of scope. This restriction is not a limitation of the work but a deliberate isolation strategy: by removing content awareness, we isolate the fundamental contributions of platform architecture and basic user behavior to information spread. The result establishes a clean, high-performance structural baseline upon which semantic and content-aware layers can be rigorously evaluated.

== Hypotheses & Research Questions

This thesis is guided by the core hypothesis that a highly optimized Discrete-Event Simulation, structured around continuous-time mechanics, can accurately reproduce the macro-scale emergent diffusion signatures of an empirical microblogging network while utilizing uniform, content-agnostic user actions.

In other words, it is hypothesized that with a rigorous empirical calibration, the simulation will produce cascade patterns that fundamentally mirror real Bluesky behavior—even when every post is treated as interchangeable and every user is modeled with identical decision-making policies. If this holds, it exposes how much of systemic virality is structural and behavioral rather than purely semantic. If it diverges, it highlights exactly where semantic content-awareness becomes an irreplaceable necessity for accurate modeling.

To test this hypothesis, the following research questions are addressed:

+ *RQ1 — Paradigm Suitability:* Is a discrete-event framework an algorithmically and computationally scalable approach to simulate continuous-time independent cascades at a massive scale?

+ *RQ2 — Empirical Distributions:* What are the empirical distributions of user action frequencies on Bluesky regarding session duration, inter-session gaps, and post-creation cycles? How can we adequately define an active session boundary to extract these parameters?

+ *RQ3 — Baseline Accuracy:* To what extent can a uniform, content-agnostic action policy replicate the power-law cascade distributions and structural virality patterns observed in empirical platform data?

+ *RQ4 — Structural Bottlenecks:* How does the structural interaction between active sessions and reverse-chronological timeline queues affect content congestion and timeline starvation? 

== Thesis Structure

The remainder of this report is organized as follows:

*Chapter 2 — State of the Art:* Outlines the theoretical background of Social Network Analysis, continuous-time cascade dynamics, the Activity-Driven network model, and the architectural mechanics of the Bluesky ecosystem.

*Chapter 3 — Problem Formulation:* Formalizes the unified mathematical model of the microblogging platform using time-varying graph principles. Introduces the explicit delay parameters, the session mechanics, and the structural metrics used to evaluate the simulation output.

*Chapter 4 — Methodology:* Justifies the selection of the Discrete-Event Simulation paradigm over Agent-Based Modeling, establishes the core engine rules, and details the Ziggurat algorithm used for high-performance random variate generation.

*Chapter 5 & 6 — Design and Implementation:* Detail the engineering decisions that enable the simulation to execute effectively at scale. Chapter 5 covers the architectural design: event types, queue mechanics, propagation delays, and structural entities. Chapter 6 covers concrete implementation: Data-Oriented Design memory layouts, Compressed Sparse Row (CSR) topology storage, power-of-two indexing optimizations, and the buffered binary I/O trace pipeline.

*Chapter 7 & 8 — Data Analysis and Calibration:* Present the empirical extraction of user parameters from the Bluesky Firehose dataset. Chapter 7 documents the exploratory data analysis; Chapter 8 maps those analytical findings into the calibrated parameter sets used to configure the final evaluation runs.

*Chapter 9 & 10 — Execution and Results:* Analyze the simulation performance and emergent behaviors. Chapter 9 covers warm-up dynamics, steady-state convergence, and computational scalability. Chapter 10 evaluates systemic results: cascade size distributions, burstiness coefficients, structural virality metrics, lifetime profiles, and timeline congestion patterns.

*Chapter 11 & 12 — Conclusions and Future Work:* Summarize the operational achievements of the baseline model and detail expansion pathways. The final chapter presents a concrete mathematical roadmap for content-aware integration—spanning embedding-based similarity spaces and Large Language Model generative agents—while addressing the computational trade-offs involved.
