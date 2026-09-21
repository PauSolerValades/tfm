#import "utils.typ": *


Online Social Networks (OSNs) have evolved from simple interpersonal communication utilities into complex, socio-technical ecosystems that fundamentally govern the modern information landscape. Among various configurations, the microblogging format—pioneered by Twitter in 2006 @arrington2006twttr —introduced unique structural constraints: strict character limitations and asymmetric follower-followee topologies. This format detonated a "before and after" in how social networks were perceived and used, as it broke from the paradigm of mutual friendship (where both users must agree to be connected) into one where any user can follow any other without explicit permission. Content consumption within these networks historically relied on chronological timelines, where information propagation is efectuated through user-driven amplification mechanisms such as reposts, the action of showing a specific post to your followers.

Every change made to a microblogging platform alters the dynamics of content diffusion: which posts reach further, are seen by more people, or go viral. The introduction of algorithmic feeds, recommendation systems, and notification delivery has reshaped what users see and when. Over time, the platforms that host public discourse have accumulated immense control over not only how information flows but the way that flows: as private-equity owned business, social media platforms greatest incentives is to maximize engagment, for their users be able to be exposed to more advertisment, the main source of income of online social platforms. Needless to say, none of those has neither the end user, the discourse quality on the platfrom nor the well-being of societies on their mind, at least as a first thought.  

As the data collected by social media platforms is of high economic value, usage data and patters of users have been been shared in rare ocasions and sparsely with researchers or non-profit entities; normally its used as proxies for internal R&D inside the same companies owning the platforms to change the experience under their own criteria. Luckly, the centralization of OSNs has prompted a paradigm shift toward open, decentralized alternatives in recent years, being the most prominent examples Mastodon @mastodon-social-network and Bluesky @bluesky-social-network. The latter was founded by ex-Twitter CEO Jack Dorsey @palmer2019twitter and it's build upon the Authenticated Transfer Protocol (AT Protocol), which makes the network open by specifiying the protocols that Bluesky internally uses for others to implement their own social media platforms with total compatibiliy, avoiding the users content vendor lock-in, and allowing them to migrate their data to the server of their choice. #footnote[A nice analogous for quick understanding is to compare the platform-content such as a web-domain and the physical server: you can swap the provider as the domain is yours, and the infrastructure to run it is open-source. @abramov2025opensocial] for the user, as well as an unprecedented transparency for network science researchers. As ATProto is open, the events created by the users are publicly availabe and collectable for anyone who's listening to the proper port (see @apx-data for more info). For the first time, researchers can access raw, unaggregated data detailing who follows whom, who posts what, and who interacts with which content, entirely free from the filtering mechanisms of a platform's internal analytics team. This work builds directly on top of that opportunity.

== Information Diffusion

Information diffusion is the study of how discrete pieces of content propagate through a network infrastructure over time. Within a modern microblogging environment, the mechanics of spread are governed by interactions on three primary axes:
- *Platform Affordances:* The architectural features of the system—user interfaces, chronological feeds, notification delivery, recommendation algorithms—that determine the structural pathways through which content can reach a user. A reverse-chronological timeline is not functionally equivalent to an algorithmic feed; a platform implementing an explicit repost mechanism creates distinct cascading trees compared to one without it. These are not neutral design choices; they actively shape what spreads and what dies.
- *User Dynamics:* The explicit behavior patterns of individuals: when they log in, how long they scroll, how frequently they create posts, and what actions they take when presented with content. Human activity in social media is highly bursty and intermittent @barabási2005bursts and these rhythms create narrow temporal windows of opportunity for content to be either prioritized or buried. 
- *User-Content Interaction:* The semantic alignment between a post's message and a user's latent preferences, rooted in homophilic dynamics. A user who likes sports cars will predictably engage more with content about sports cars. This is, intuitively, the most powerful driver of engagement—but it is also the most complex to model, as it requires representing both the semantic footprint of posts and the high-dimensional preferences of users in a computationally tractable way.

This work will focus on the Plaftorm Affordances ---what the model has--- and the User Dynamics ---how can we characterize a user behaviour--- as the User-Content interaction falls out of scope due to difficulty and time constraints.

When a piece of content traverses a network and users keep propagating it, it creates a cascade. The cascade is a graph, shaped as a tree, of users that have interacted with that post.Cascades are the main object of interest of this work, as they allow to trace the full path of a piece of content has followed, being able to deduce from it important characteristics of how did this post impact both the network and the users that have interacted with it.  

== Objectives

The aim of this work is to generate synthetic cascades resembling the ones extracted from empirical Bluesky Firehose data. To achieve that, a model to represent a microblogging social network platform minimal viable features will be introduced (a Continuous-Time Independent Cascade model, with a LIFO-based timeline and an activity-driven user behaviour) with the following scope limitations to make the work fit in a master thesis: homogeneous posts and user interaction with them and no new users while the simulation runs.

To achive this, the thesis can be seen as three different parts:
1. *Evaluating the model*: as the complexity of multiple users is extremly high, it needs to be simulated. The simulation must be designed, implemented and evaluated to ensure correct and scalable functioning.
2. *Informing the simulation*: from empirical Bluesky data, we must extract the behaviours of the users to use the simulation with adequate data. The simulation will also need a network topology to ran over, which will be extracted from empirical Bluesky data as well.
3. *Objective Quantites*: to evaluate the simulation we need both quantities to replicate and quantities to observe. The quantities to replicate allows to judge the accuracy of the simulation, and the quantites to reproduce are the characteristics the simulation is built to study, but to be able to compare them they must be found in the first place, extracted again from empirical data.
4. *Execution, Comparison and Evaluation*: compare the emprical with the synthetic cascades, asses if there are any rellevant differences and if any, explicitly mark the model limitaitons on why the cascades differ.

== Hypotheses & Research Questions
<sec-hypotheses>

A microblogging platform in full is intractable to reproduce one-to-one: dozens of interactions, features and ranking mechanisms act at once. This work does not attempt that. It asks instead whether the _core_ of the process can be built, calibrated and verified on its own, as a foundation on which the rest can later be assembled. That question can fail, which is what makes it a hypothesis:

*Hypothesis.* A model built from a minimal set of features of a microblogging platform --- an asymmetric follow graph, a reverse-chronological timeline and repost amplification, driven by the users' own activity rhythms --- calibrated end-to-end from openly available data and executed at network scale, is sufficient to reproduce the underlying mechanics of information diffusion: it recovers the bulk of the empirical cascade structure, and it accounts measurably, rather than by assumption, for where it does not.

Two things follow if the hypothesis holds, and together they are the claim of this work. First, the agreement in the bulk validates the modelled mechanisms as the load-bearing part of the phenomenon. Second, the quantified residual is not a shortcoming to be hidden but a result: it identifies the mechanisms still missing, and where they enter the process. On both counts the contribution is a _verified baseline_ for information-diffusion simulation --- a first step that is solid because its limits are measured, not a toy that simply stops where it stops.

The following questions operationalize this, mirroring the structure of the conclusions:

*RQ1 --- Measurability.* Can the platform's user dynamics (session durations, inter-session gaps, inter-post intervals, action rates) and a representative follower topology be recovered from openly available ATProto data, at the per-user resolution the model requires?

*RQ2 --- Executability.* Can a discrete-event implementation of the model run at the scale of the real network --- up to $10^6$ nodes --- with feasible time and memory, and reach a stationary regime independent of the initial condition?

*RQ3 --- Core validity.* Does the calibrated core reproduce the qualitative shape of the empirical cascades --- the same tiny, shallow, broadcast-dominated regime, with matching bulk statistics for size, depth, out-degree and structural virality --- with the non-trivial-cascade rate the one bulk quantity that stays off by roughly a factor of two?

*RQ4 --- Boundary.* Where the model departs --- the extreme tail of cascade size, depth and width --- is the deviation attributable, mechanism by mechanism, to what the model does not yet contain? Concretely: does content-agnostic behaviour force a subcritical reproduction number $R_0 < 1$, and does in-network-only impression delivery with a uniform conversion rate cap the first hop below the follower count?

*RQ5 --- Specification of the missing mechanism.* Can the measured residual be translated into a minimal, implementation-independent specification of what the model lacks --- the necessary properties the missing mechanism must have, rather than one particular way of building it?

RQ1--RQ2 establish that the construction is possible; RQ3 verifies the core; RQ4 measures the boundary; RQ5 turns that boundary into a specification of the next layer. Together they are what makes this a first step rather than a final answer.

== Thesis Structure

The remainder of this report is organized as follows:

*Section 2 — State of the Art:* Outlines the theoretical background of Social Network Analysis, continuous-time cascade dynamics, the Activity-Driven network model, and the architectural mechanics of the Bluesky ecosystem, as well as a history of social networks simulations with different paradigms and current attempts to execute this endevaour.

*Section 3 — Problem Formulation:* Formalizes the unified mathematical model of the microblogging platform using time-varying graph principles. Introduces the explicit delay parameters, the session mechanics, and the structural metrics used to evaluate the simulation output.

*Section 4 — Methodology:* Justifies the selection of the Discrete-Event Simulation paradigm over Agent-Based Modeling, establishes the core engine rules. #todo[all the appendix that talk about this]

*Section 5 — Design:* Details the engineering decisions that enable the simulation to execute effectively at scale. event types, queue mechanics, propagation delays, and structural entities. Appendix F covers concrete implementation: Data-Oriented Design memory layouts, Compressed Sparse Row (CSR) topology storage, power-of-two indexing optimizations, and the buffered binary I/O trace pipeline.

*Section 7 — Data Analysis:*

*Section 8 - Calibration*: maps those analytical findings into the calibrated parameter sets used to configure the final evaluation runs.

*Section 9 — Results:* Analyze the simulation performance and emergent behaviors. Chapter 9 covers warm-up dynamics, steady-state convergence, and computational scalability.

*Sections 10 & 11 - Conclusions & Future Work:* Summarize the operational achievements of the baseline model and detail expansion pathways. The final chapter presents a concrete mathematical roadmap for content-aware integration—spanning embedding-based similarity spaces and Large Language Model generative agents—while addressing the computational trade-offs involved.
