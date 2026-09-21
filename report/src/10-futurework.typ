#import "utils.typ": *

This chapter outlines directions for extending the simulation beyond its current scope, organized into two independent tracks. The first addresses computational performance — removing the remaining bottlenecks that limit scalability to tens of millions of users. The second addresses model fidelity — lifting the simplifying assumptions of content-agnostic, action-independent diffusion to capture the semantic and psychological drivers of real social network behavior.

== Performance Optimizations
<sec-future-performance>

Despite the excelent performance of the simulation, it is known with the profiler tool `perf`#footnote[`perf` is an excelent profiler that tracks how much time a program spends in the assembly of a lable, marking the most important optimization point.] #todo[cite] that the Event Queue is a performance critical point due to it importance, and every iteration of the loop appends or removes an element, as well as directly growing with the topology size.

The current implementation uses a 8-leaf heap for the global event queue $Q$ (see @apx-impl-queue). While the heap provides $O(log n)$ operations, the future event set remains the principal bottleneck as the simulation scales toward $N = 10^6$ users. With at most $4N$ events simultaneously in the queue and each event requiring two to four heap operations, the actual computational cost is several times the theoretical $log_8(4N) approx 6.643$ comparisons. The lack of batch insertion in a heap means there is no avenue for amortization.

The Future Event Set optimization is a known performance bottleneck in Discrete-Event Simulations, and there is plenty of literature addressing more optimal structures that theoretically achive $O(1)$ practical insertion, such as the Calendar Queue @brown1988calendar. Brown, in 1988, showed experimental hold times three times shorter than splay trees for 10,000 events. The standard dynamic Calendar Queue resizes its bucket array to maintain optimal density, but the simulation's known parameters (static user count, bounded events per user, known delay distributions) allow a static heuristic to determine the optimal configuration upfront, eliminating all resizing overhead. Apart from Calenar Queues, there are other more modern stuctures tought for DES such as the DSMList @kim2009mlist, that negate some of the cons of the Calendar Queue.

This has not been implemented in this work due to both time constranints, and that the every algorithm replacing the heap requires a well calibrated heuristic. It was the author concern that, with several changed to the simulation, the heuristic tuning would have consumed plenty of time to get right while at the same time degrading performance, and therefore was avoided by commodity.

Despite the heap being a known bottleneck, applying some kind of parallelization to the simulation itself (not just multiple simulations concurrently running) would be the best performance improving for the simulation. Currently, the simulation just uses a 0.2% of the server CPU, which means that is absolutely memory bottlenecked. There are known ways to parallelize a discrete-event simulation, as it is a very well research topic, called PDES. This has not been implemented for the same reason a specialized data structure has not been used for the Future Event Set: the work that such a feature would imply is enormous for the scope of this work.

== Evaluation Metrics
<sec-future-metrics>

The traces of the simulation allow far more quantites to be extracted from the trace data, and if compared with the empirical Bluesky data, it would provide far more information about the social network and the hits or misses of the model. This project originally included both the Gini coefficient and a Post Lifetime analysis as additional characteristic and desired quantities respectively.

Not only the addition of other metrics, but the current simulation extracts a lot more data than the one reported in Results (@sec-results), as can be seen in @apx-pipeline-datasets, which describes the different datasets that the simulation outputs, including more metrics on the cascade, post lifetime basic information an virality in subcascades, making able to identify in theory where exactly the virality exploded.

== Recalibration and Remaining Limits
<sec-future-boundary>

Most of the departure is already localized in @sec-finding-missing-tail and needs acting on, not re-deriving. The clearest change is the calibration itself: the session and creation parameters are fitted on the active tail of the data only (@sec-cal-acrossuser), so representing the inactive majority explicitly lowers the arrival rate onto every timeline, restores part of the width, and --- because the same composition depresses $R_0$ --- lifts the depth cap with it (@sec-missing-width). The orthogonal fix is an impression channel wider than the follower graph, which lifts the in-network ceiling without a new mechanism (@sec-width-cause); both, together with the content-aware policy of @sec-future-content, are the mechanism the model lacks.

What remains genuinely unmeasured --- and therefore bounds the claimed generality of the agreement rather than the reported behaviour --- is short. The action policy ignores the impression history, so there is no fatigue, saturation or social proof (@sec-method-des-assumptions); the topology is static and every follow delivers every post, with mutes and blocks ignored (@sec-model); the calibration uncertainty is never propagated into the result tables; the stationarity evidence rests on one topology per size (@sec-cal-warmup); and all parameters come from a single platform and window, so portability is untested. Each is lifted by the mechanism named in @sec-future-content or by the additional runs and tests of @sec-future-metrics.

== A Content Aware Simulation
<sec-future-content>

This work originally was going to include this mechanism as its main study point, and the original section can be found in @apx-content. This section is a summary of the intent and the mechanisms this simulation could include.

Traditional information diffusion models (#todo[see section 2.3]) treat diffusion as purely structural mechanic, stemming just from the network topology: if the network has the appropriate properties, the system will behave as a social network. The Independent Cascades model assigns a fixed transmission probability to each edge, but that treats infection (reposting or not) as a binary thing unrelated to what is being transmitted. This section will aim to briefly discuss the model extension to support content.

A holistic description of the process a human goes through when deciding to interact with a specific piece of content could be understood as the following, very simplified: a user, with a finite amount of preferences and likes, reads/watches/observes a piece of content. If the preferences of the user are similar to the contents of the post, then the user is more likely to interact with it. If they profoundly disagree, it is going to be less likely to repost it.

We could represent both the post content and the user inner state as an embedding.

#def(name: "Embedding")[
  An embedding is a representation learning technique that maps complex, high-dimensional data into a lower dimensional vector space of numerical vectors. We formally define it as a mapping $phi: X -> RR^(n-1)$
] <def-embedding>

Specifically, for this purpose we are going to define an addendum as a property of that embedding: under a similarity function $rho: (X,X) -> [-1, 1]$, two embedding vectors of same-topic contents have high similitude, something resembling a Lipschitz property such as

$ d(phi (x_1), phi (x_2)) <= L · rho (x_1, x_2) quad L in RR $

=== Heterogeneous $pi$ policy

The definition of the embedding allows us to define a heterogeneous policy according to the user embedding state and the post it is acting upon. Let $c = rho(x_u, x_i)$ denote the similitude of the user embedding state $x_u$ and the post content $x_i$. Now, we can modify the current $pi$ homogeneous policy as

$ z_a = beta_a + theta_a dot c $

where $beta_a = ln(pi_a)$, in the next equation we'll show why. This equation represents a variation from the original quantity depending on a sensitivity parameter $theta_a$. If we normalize the new thresholds to be probabilities again, we can express the following:

$ pi_u (a | i) = frac(exp(z_a), sum_(k in cal(R)'_(cal(U)cal(I))) exp(z_k)) = frac(pi_a · exp(theta_a dot c), sum_k (pi_k · exp(theta_k · c))) $

making the policy depend on both the user and the current post $i$.

=== User Inner State

An obvious follow-up question is how to represent a user as an embedding, as what constitutes the representation of a user is not trivial. A straightforward option is to consider the user as an aggregation of the embeddings of the posts they see and produce. Let $x_i = phi(i)$ denote the embedding of a post $i$. Then every user is represented by two distinct states, each built by aggregating a different subset of posts with a function $Gamma$:

The *identity* state $S_"id"(u, t)$ summarizes what the user has _produced_, that is, their activity set $cal(A)_t(u)$ (@def-activity) of creations and reposts:

$ S_"id" (u, t) = Gamma_"id" ({ x_i | i in cal(A)_t (u) }) $

where $Gamma_"id"$ is an aggregation function --- for instance a recency-weighted mean with exponential decay, so that recent activity dominates the identity representation.

The *influenced* state $S_"inf"(u, t)$ summarizes what the user has _been exposed to_, that is, their timeline $cal(T)_t(u)$ of every post they have seen. Here the aggregation is not uniform: each post is weighted by how deeply the user engaged with it,

$ S_"inf" (u, t) = Gamma_"inf" ({ w(i) dot x_i | i in cal(T)_t (u) }) $

where the engagement weight $w(i)$ distinguishes reposts, likes, and passive exposure:

$ w(i) = cases(
  w_"repost" &"if" i in cal(A)_t(u),
  w_"like" &"if" i in cal(H)_t(u) "and" i in.not cal(A)_t(u),
  w_"seen" &"otherwise"
) $

with $w_"repost" > w_"like" > w_"seen" > 0$. The hierarchy acknowledges that posts the user actively engaged with leave a deeper imprint than those merely scrolled past. Critically, even content the user never liked or reposted contributes to $S_"inf"$: exposure alone, without endorsement, shapes what a user is likely to create next.

Taken together, $S_"id"$ and $S_"inf"$ capture the user in two complementary ways: what they are (their output identity) and what they are becoming (their exposure-driven drift). The user state $x_u$ appearing in the reactive policy above corresponds to the identity state $S_"id" (u, t)$.

=== Post Creation

Post creation then draws from both states: the user samples a candidate pool

$ C(u, t) = "sample"(cal(A)_t (u), cal(T)_t (u); alpha) $

where $alpha$ balances the proportion drawn from the user's own history versus their exposure, and sampling within $cal(T)_t (u)$ is biased by the engagement weight $w(i)$. The new post's embedding is a convex combination of the candidates,

$ x_(i_"new") = sum_(j=1)^K w_j dot x_(i_j) quad "with" bold(w) ~ "Dir"(bold(1)) $

which keeps the generated embedding inside the semantic convex hull of valid posts. At $alpha = 1$ this reduces to the spontaneous-creation limit of the current simulation.

=== Content Through an LLM
<sec-future-llm>

The embedding layer above describes what a content-aware extension must represent, but says nothing about where the content comes from. The most recent line of work in social-network simulation answers that with a large language model: instead of sampling an embedding from a convex hull, an LLM writes the post and, in the strongest form, decides the action as well. The generative-agent architecture of Park et al. @park2023generative opened this direction, S³ @gao2023s3 is its representative for social-network simulation, and the taxonomies of @gao2024llmabm, @fromindividualtosociety2026 and @llmagentssurvey2025 map what the agents are asked to do and how the resulting societies are evaluated. This work's engine is a natural host for that layer: its event loop already schedules creations and actions, so an LLM only has to supply the missing content and, optionally, the missing policy.

There are two integration depths, with very different costs.

- *Offline content generation.* The LLM is run once, outside the simulation, to produce a corpus of posts ---topics, texts and embeddings--- that is then replayed by the calibrated engine. The event loop keeps its deterministic, microsecond-scale behaviour and the content only changes what the embedding-based policy of @sec-future-content sees. This is the cheapest and most reproducible option: the expensive model runs a fixed number of times, the corpus is a dataset, and the same trace can be regenerated exactly.
- *Online agentic decisions.* The LLM is queried at simulation time, either to write a post when a creation event fires or to choose the action when an impression occurs. This captures the richest behaviour, but it couples the engine's throughput to an external service and makes the run non-reproducible by construction: identical seeds no longer give identical traces.

The online form is where the problems concentrate. *Cost and throughput*: at the scale reported in @sec-results ---up to a million users and tens of millions of actions--- one query per event is prohibitive, and even per-creation generation needs caching, batching and a small local model to stay within the hours-scale budget; embedding products can be SIMDed, but only once the text exists. *Reproducibility and validation*: the exact replication that makes this baseline trustworthy is lost, and open-ended text is hard to validate against the empirical cascades ---@validation2025 singles this out as the central open challenge of the generative-agent agenda, and the calibrated, non-generative DES built here is precisely the fixed reference against which a generative layer could be measured. *Action fidelity*: an LLM asked to emit a discrete action such as `repost` is a poor classifier ---verbose, biased and sycophantic--- so it is better cast as a content generator and kept out of the decision rule, which is exactly the split the embedding layer already assumes. *Calibration*: generated content has its own distribution, and nothing guarantees that the resulting cascades match Bluesky's; a generated corpus would need the same distribution-fitting and goodness-of-fit battery applied in @sec-calibration.

The pragmatic path is therefore the hybrid: an LLM as an offline content and embedding generator feeding the calibrated stochastic policy, with the online agent reserved for small-scale, interpretability-oriented studies where its cost and non-determinism can be afforded. The requirement this places on the engine is small --- an action record carrying a content id and an embedding, plus a loader for a generated corpus--- so the option stays open without committing the baseline to it.

