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


== Justification & Societal Impact

== Objectives & Scope

== Hypotheses & Research Questions

== Thesis Structure

The remainder of this report is organized as follows:

*Chapter 2 — State of the Art:* Outlines the theoretical background of Social Network Analysis, continuous-time cascade dynamics, the Activity-Driven network model, and the architectural mechanics of the Bluesky ecosystem.

*Chapter 3 — Problem Formulation:* Formalizes the unified mathematical model of the microblogging platform using time-varying graph principles. Introduces the explicit delay parameters, the session mechanics, and the structural metrics used to evaluate the simulation output.

*Chapter 4 — Methodology:* Justifies the selection of the Discrete-Event Simulation paradigm over Agent-Based Modeling, establishes the core engine rules, and details the Ziggurat algorithm used for high-performance random variate generation.

*Chapter 5 & 6 — Design and Implementation:* Detail the engineering decisions that enable the simulation to execute effectively at scale. Chapter 5 covers the architectural design: event types, queue mechanics, propagation delays, and structural entities. Chapter 6 covers concrete implementation: Data-Oriented Design memory layouts, Compressed Sparse Row (CSR) topology storage, power-of-two indexing optimizations, and the buffered binary I/O trace pipeline.

*Chapter 7 & 8 — Data Analysis and Calibration:* Present the empirical extraction of user parameters from the Bluesky Firehose dataset. Chapter 7 documents the exploratory data analysis; Chapter 8 maps those analytical findings into the calibrated parameter sets used to configure the final evaluation runs.

*Chapter 9 & 10 — Execution and Results:* Analyze the simulation performance and emergent behaviors. Chapter 9 covers warm-up dynamics, steady-state convergence, and computational scalability. Chapter 10 evaluates systemic results: cascade size distributions, burstiness coefficients, structural virality metrics, lifetime profiles, and timeline congestion patterns.

*Chapter 11 & 12 — Conclusions and Future Work:* Summarize the operational achievements of the baseline model and detail expansion pathways. The final chapter presents a concrete mathematical roadmap for content-aware integration—spanning embedding-based similarity spaces and Large Language Model generative agents—while addressing the computational trade-offs involved.
