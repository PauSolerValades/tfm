#import "utils.typ": *

This chapter highlights improvement points for the current state of the simulation #todo[section] and describes directions for extending it beyond its current scope to achive a better replication of a microbloggins social network.

This chapter outlines directions for extending the simulation beyond its current scope, organized into two independent tracks. The first addresses computational performance — removing the remaining bottlenecks that limit scalability to tens of millions of users. The second addresses model fidelity — lifting the simplifying assumptions of content-agnostic, action-independent diffusion to capture the semantic and psychological drivers of real social network behavior.

== Performance Optimizations
<sec-future-performance>

Despite the excelent performance of the simulation, it is known with the profiler tool `perf`#footnote[`perf` is an excelent profiler that tracks how much time a program spends in the assembly of a lable, marking the most important optimization point.] #todo[cite] that the Event Queue is a performance critical point due to it importance, and every iteration of the loop appends or removes an element, as well as directly growing with the topology size.

The current implementation uses a 8-leaf heap for the global event queue $Q$ (see @apx-impl-queue). While the heap provides $O(log n)$ operations, the future event set remains the principal bottleneck as the simulation scales toward $N = 10^7$ users. With at most $4N$ events simultaneously in the queue and each event requiring two to four heap operations, the actual computational cost is several times the theoretical $log_8(4N) approx 25$ #todo[this number is not okay lol] comparisons. The lack of batch insertion in a heap means there is no avenue for amortization.

The Future Event Set optimization is a known performance bottleneck in Discrete-Event Simulations, and there is plenty of literature addressing more optimal structures that theoretically achive $O(1)$ practical insertion, such as the Calendar Queue @brown1988calendar. Brown, in 1988, showed experimental hold times three times shorter than splay trees for 10,000 events. The standard dynamic Calendar Queue resizes its bucket array to maintain optimal density, but the simulation's known parameters (static user count, bounded events per user, known delay distributions) allow a static heuristic to determine the optimal configuration upfront, eliminating all resizing overhead. Apart from Calenar Queues, there are other more modern stuctures tought for DES such as the DSMList @kim2009mlist, that negate some of the cons of the Calendar Queue.

This has not been implemented in this work due to both time constranints, and that the every algorithm replacing the heap requires a well calibrated heuristic. It was the author concern that, with several changed to the simulation, the heuristic tuning would have consumed plenty of time to get right while at the same time degrading performance, and therefore was avoided by commodity.

Despite the heap being a known bottleneck, applying some kind of parallelization to the simulation itself (not just multiple simulations concurrently running) would be the best performance improving for the simulation. Currently, the simulation just uses a 0.2% of the server CPU, which means that is absolutely memory bottlenecked. There are known ways to parallelize a discrete-event simulation, as it is a very well research topic, called PDES. This has not been implemented for the same reason a specialized data structure has not been used for the Future Event Set: the work that such a feature would imply is enormous for the scope of this work.

== Evaluation Metrics
<sec-future-metrics>

The traces of the simulation allow far more quantites to be extracted from the trace data, and if compared with the empirical Bluesky data, it would provide far more information about the social network and the hits or misses of the model. This project originally included both the Gini coefficient and a Post Lifetime analysis as additional characteristic and desired quantities respectively.

Not only the addition of other metrics, but the current simulation extracts a lot more data than the one reported in Results (@sec-results), as can be seen in @apx-pipeline-datasets, which describes the different datasets that the simulation outputs, including more metrics on the cascade, post lifetime basic information an virality in subcascades, making able to identify in theory where exactly the virality exploded.

== The Boundary of the Model
<sec-future-boundary>

The comparison in @sec-results fixes the extent of what the model explains, and it is worth stating as a whole before listing what comes next: each mechanism below exists to relax a boundary identified there.

The calibrated core reproduces the bulk of the empirical cascades --- the same tiny, shallow, broadcast-dominated regime --- from exactly three mechanisms: an asymmetric follow graph, a reverse-chronological timeline and activity-driven sessions. The departure is equally well located, and it is two independent truncations. *Depth* is capped by the subcritical reproduction number that content-agnostic behaviour imposes on every cascade (@sec-finding-missing-tail), and *width* by a first hop bounded jointly by the post arrival rate, the conversion rate and the in-network impression budget (@sec-width-cause); the two do not lift one another, and the queue is not among the caps (@sec-queue-attention).

The boundary is part model and part methodology. Uniform conversion, in-network reach and content-agnostic posts follow from the modelling choices, and lifting them requires new mechanisms. The inflated arrival rate, the unobserved impression term and the `via`-based cascade reconstruction are properties of the data and of the calibration: representing them differently relaxes them without adding anything. The subsections below take each boundary in turn --- model, data, methodology and analysis --- and name the mechanism that moves it.

== Model Limitations

This section collects the modelling choices that the experiments of @sec-results do not isolate. Their effect is not measured, so they bound the claimed generality of the agreement rather than the reported behaviour.

- *Content-agnostic posts.* Every post is a content-free commodity and every user draws from the same action policy, so conversion is one constant for the whole platform. This is the assumption behind the capped depth (@sec-finding-missing-tail) and one of the three caps on the width (@sec-width-cause); lifting it is the subject of @sec-future-content.
- *Homogeneous users.* A single policy $pi$ and a single creation rate $lambda$ describe every user, so the model has no notion of individual preference or posting propensity beyond the fitted temporal parameters. $arrow.r$ lifted together with the previous item by the heterogeneous, content-conditioned policy of @sec-future-content.
- *Action independence.* The decision over a post depends only on $pi$ and not on the impression history $cal(H)_t(u)$ (@sec-method-des-assumptions), so the model contains no fatigue, no saturation and no social proof: a post seen many times is as likely to be reposted on the last exposure as on the first. $arrow.r$ would need a history-dependent, non-Markovian policy carrying saturation or fatigue; not addressed further here.
- *Static topology and full delivery.* No user joins, leaves or changes their follow relationships during a run, and every follow is assumed to deliver every post --- mutes and blocks are ignored (@sec-model), so reach is never suppressed. $arrow.r$ would need a dynamic follow graph and explicit mute/block delivery rules; not addressed further here.
- *Omitted mechanics.* Replies, quotes and notifications are outside the model (@apx-mechanics). Each adds a diffusion path that is not mediated by the reverse-chronological timeline; notifications in particular would re-engage offline users and raise $R_0$. $arrow.r$ each is sketched in @apx-mechanics; adding them is a feature-completeness direction that also relaxes part of the width cap.
- *Uniform and constant propagation delay.* The per-edge transmission rate $alpha_(j,i)$ is flattened to a single $alpha$ for all edges (@sec-method-ctic) and set to a degenerate constant in the reported run (@tbl-res-config), removing both the edge-level heterogeneity and the heavy-tailed waiting times of the fitted transmission models. $arrow.r$ a recalibration rather than a rewrite: the simulator already samples `propagation_delay`, so a per-edge or heavy-tailed law can be fitted from cascade timings.
- *Hand-set delays.* The interaction and creation delays are fixed at one second with no empirical anchor (@tbl-res-config); they are the only parameters not measured from the data. $arrow.r$ measure them from within-session latencies, or sweep them as free parameters; neither is done here.
- *Binary presence.* A user is online or offline with no partial attention, and within a session always acts on the next post after a fixed inter-action time. $arrow.r$ requires an exposure record (see the data limitations below); without it, partial attention cannot be identified.

== Data Limitations

These are properties of the data itself: they bound what any calibration could recover, not only what this one did.

- *No exposure record.* The Firehose logs actions, never views, so the impression term that governs the width (@sec-width-cause) is unobservable and the inter-action time that sets the conversion baseline has no empirical counterpart (@sec-cal-interaction). This is the single most consequential data gap. $arrow.r$ lifted only by serving the feed, which turns the impression matrix into a measurement (@apx-sessions-dataset).
- *`via` is optional.* Only about 20% of likes and 32% of reposts carry the discovery attribution (@anx-data-via). Reposts without it flatten onto the cascade root, so the empirical structural virality is a *lower bound*, and its absence is not at random: non-official clients never set the field. $arrow.r$ lifted by the same serving path: with exposure as the parent of every action, `via` stops being the only trace of discovery (@apx-sessions-dataset).
- *Censored cascades.* The cascade data spans six days, so long chains are truncated by the observation window rather than by the diffusion process, and part of the measured tail is a lower bound by construction (@sec-data-virality). $arrow.r$ lifted by a longer or streaming observation window; the six-day ceiling is a collection choice, not a platform limit.
- *Topology gaps and window mismatch.* The follower graph spans fourteen months with 54 missing days (11.6%, @tbl-topo-gaps); edges created and deleted inside a gap are lost, and the graph is a Forest Fire sample of that graph (@apx-topology-forestfire), not the graph itself, so the largest hub in any run is a sampling artefact. $arrow.r$ lifted by continuous collection and by comparing runs across sampling parameters ($p_f$, $p_b$) and across snapshots.
- *Active-tail cohort.* The session and creation parameters are fitted on the most active users only (@sec-cal-acrossuser), so the simulated population is not the real population and the arrival rate onto every timeline is inflated by roughly two orders of magnitude (@sec-width-cause). $arrow.r$ lifted by representing the inactive majority explicitly, which lowers the arrival rate and restores part of the width; it is the single most valuable calibration change.
- *Sessionization is a proxy.* Sessions are reconstructed from action timestamps, not from presence (@apx-sessions-def), so a user reading without engaging is invisible and the recovered sessions are a lower bound on real visits. $arrow.r$ lifted by richer telemetry, or bounded more tightly by a per-user session model (see the methodological limitations below).
- *Single platform and population.* All parameters come from Bluesky over one window, whose user base is not a neutral sample of microblogging behaviour, and empirical cascades mix organic diffusion with algorithmic amplification, which the reverse-chronological assumption cannot separate. $arrow.r$ lifted only by replication on another platform; the model is otherwise portable because its mechanisms are not Bluesky-specific.

== Methodological Limitations

These concern how the parameters above were chosen or estimated.

- *Global session threshold.* DBSCAN applies the same $epsilon = 300$ s boundary to every user; the per-user alternative (a two-state hidden Markov model) was deliberately not pursued, and both Tukey's fences and HDBSCAN degenerated empirically (@apx-session-dbscanparams). $arrow.r$ lifted by the per-user two-state HMM over the inter-event gaps, the natural next estimation step.
- *Goodness-of-fit fragility.* The per-user family is chosen by AIC over five candidates; the Pareto family wins spuriously below roughly twenty observations (@tbl-composition-cutoff) and its Generalized-Pareto and Lomax members are exact reparametrizations that cross-confuse (@apx-session-pareto), so the fitted composition is partly a model-selection artefact. $arrow.r$ lifted by validating the family choice above a defensible observation cutoff and on held-out users, or by staying non-parametric (ECDF) throughout.
- *Circular conversion.* $pi$ is not measured but derived from the assumed dwell time of three seconds per post, and the user heterogeneity of the sixteen family pairs is dropped in the process (@sec-cal-policy). Uncertainty in the dwell time propagates directly into the central behavioural constant. $arrow.r$ lifted by measuring the dwell time directly (it needs the exposure record) or by propagating its uncertainty as a calibrated free parameter.
- *Estimated reproduction number.* $R_0$ is read from the traces rather than derived, and only on the 10K and 100K datasets (@tbl-res-r0); the subcriticality that underpins the depth argument is measured under the active-tail composition, so a realistic population would move the number even if not the mechanism. $arrow.r$ lifted by estimating $R_0$ on every dataset and across activity compositions, so the number is read as a function of the population.
- *Comparison asymmetry.* The simulated metrics pool up to one hundred runs of a sampled topology, while the reference is a single six-day window of the full network, and no two-sample test is applied between the two distributions. $arrow.r$ lifted by two-sample tests between the empirical and simulated distributions, matched for comparison size.
- *Unpropagated uncertainty.* The calibration confidence intervals never reach the result tables, and no study re-runs the pipeline under resampled topologies or parameters. $arrow.r$ lifted by bootstrapping the calibration and topology resampling through the whole pipeline.
- *Thin stationarity and single-topology experiments.* Convergence rests on three replications per initial condition on one topology per size, and the random-drain control was run at three sizes without bootstrap intervals (@sec-cal-warmup, @sec-queue-attention). $arrow.r$ lifted by more replications and by running the control on multiple topologies per size.
- *Unobserved trace.* The trace records the parent of each repost, not the impressions that produced it (@sec-width-cause), so the width decomposition is inferred from the in-degree ceiling rather than measured. $arrow.r$ already cheap on the simulation side: recording impressions per post turns the decomposition into a measurement.

== Analysis Limitations

- *Two quantities only.* The evaluation rests on the repost distribution and the structural virality; the Gini coefficient and the post-lifetime analysis were built (@apx-pipeline-datasets) and are not reported, so inequality and temporal spread are not compared against the data. $arrow.r$ lifted by the additional metrics of @sec-future-metrics.
- *Pooled statistics.* Run-level variance is collapsed into pooled means, so the spread between replications is not visible in @sec-results. $arrow.r$ lifted by reporting per-run distributions and confidence intervals alongside the pooled means.
- *Scale-bound tail.* Maximum cascade size grows with the topology size (from $32$ at 10K to $1,697$ at 1M), so part of the tail comparison measures the input size rather than the model. $arrow.r$ lifted by comparing only at matched sizes, or by expressing the tail relative to the topology ceiling.
- *No sensitivity or ablation.* Apart from the timeline-order control, no mechanism is switched off or swept, and the topology-sampling parameters are not varied, so the reported agreement is not stress-tested. $arrow.r$ lifted by switching off or sweeping each mechanism, a direct extension of the timeline-order control.

== A Content Aware Simulation
<sec-future-content>

This work originaly was going to include this mechanism as its main study point, and the original section can be found in @apx-content. This seciton is a summary of the intent and the mechanisms this simulation could include.

Traditional information diffusion models (#todo[see section 2.3]) treat diffusion as purely structual mechanic, stemming just from the network topolgy: if the network has the appropiate properties, the system will behave as a social network. The Independent Cascades model assigns a fixed transmission probability to each edge, but that treats infection (reposting or not) as a binary thing non related to what's being transmitted. This section will aim to briefly discuss the model extension to support content.

An hollistic description of the process a human goes by when deciding to interact with a specific piece of content could be understood as the following, very simplified: a user, with a finite amount of preferences and likes, reads/watches/observes a piece of content. If the preferences of the user are similar to the contents of the post, then the user more likely to interact with it. If they profoundly disagree, it is going to be less likely to repost it.

We could represent both the post content and the user inner state as an embedding.

#def(name: "Embedding")[
  An embedding is a representation learning techinque that maps complex, high-dimensional data into a lower dimensional vector space of numerical vectors. We formally define it as the a mapping $phi: X -> RR^n-1$
] <def-embedding>

Specifically, for this puropose we are going to define an addendum needed as a property of that embedding, which is that under a similarity function $rho: (X,X) -> [-1, 1]$, if the two embedding vectors of same topic contents will have high similitude, something resembling a Lipzistch property such as

$ d(phi (x_1) - phi (x_2)) <= L · rho (x_1, x_2) quad L in RR $

=== Heterogeneous $pi$ policy

The definitions of the embedding allows us to define an heterogeneous according to the user embedding state and the post is actuating over. Let's say $c = rho(x_u, x_i)$ as the similitude of the user embedding state $x_u$ and the post content $x_i$. Now, we can modify the current $pi$ homogeneous policy as

$ z_a = beta_a + theta_a dot c $

where $beta_a = ln(pi_a)$, in the next equation we'll show why. This equation represents a variation from the original quantity depending on a sensitivity parameter $theta_a$. If we normalize the new thresholds to be probabilities again, we can express the following:

$ pi_u (a | i) = frac(exp(z_a), sum_(k in cal(R)'_(cal(U)cal(I))) exp(z_k)) = frac(pi_a · exp(theta_a dot c), sum_k (pi_k · exp(theta_k · c))) $

making the policy depend on both the user and the current post $i$.

=== User Inner State

An obvious follow-up question is how to represent a user as an embedding, as what constitutes the representation of a user is not trivial. A straight forward option is to consider the user as an aggregation of the embeddings of the posts they see and produce. Let $x_i = phi(i)$ denote the embedding of a post $i$. Then every user is represented by two distinct states, each built by aggregating a different subset of posts with a function $Gamma$:

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

#todo[Rewrite later]

The latest developements in social network simulation are using Large Language Models in order to generate content and to handle everything related to content: generating the post contents, deciding to perform an action over a post, or deciding if a post is interesting to the user profiled.

This is a promising idea that is being currently explored in the literatrue, and could definielty be used as a content generator over the simulation engine basis this work offers with the simulation engine implemented. Although this approach would have some problems with the nature of LLM technologies:
- Biased decision making: an LLM is bad at chosing an option such as repost.
- Performance: to generate the contents for a user needs a good enough LLM running, and will hurt performance on the long run. Embedding products can be SIMDed to make the extra product a far less cycles.

Despite the caveats, this is probably an very promising line of reasearch that is worth to look into.

