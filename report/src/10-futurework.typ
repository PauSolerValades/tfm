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

The traces of the simulation allow far more quantites to be extracted from the trace data, and if compared with the empirical Bluesky data, it would provide far more information about the social network and the hits or misses of the model. This project originally included both the Gini coefficient and a Post Lifetime analysis as additional characteristic and desired quantities respectively.

Not only the addition of other metrics, but the current simulation extracts a lot more data than the one reported in Results (@sec-results), as can be seen in @apx-pipeline-datasets, which describes the different datasets that the simulation outputs, including more metrics on the cascade, post lifetime basic information an virality in subcascades, making able to identify in theory where exactly the virality exploded.

== Model Limitations

This section aims to address the known limitations introduced to fit this work into a master thesis project scope.

First, all the characterization of the users in the Data section (@sec-data #todo[afine the specifc one]) charectarize a shy of 20% of users in the dataset: the majority of users on social networks are lurkers, just reading, not interacting nor creating. As the obtention of this data is difficult when talking (as discussed in #todo[appendix of better data]) and there is probably a correlation between the in-out degree of a user and their session duration/inter-session lenght, which probably needs of much more data and a more subtile analysis than the one conducted in this work to get right.

In other words, the simulation 1) ignores the users in-out degrees as in behvaiour _i.e_ a user with one follower has the same change to get a specific behaviour than a user with thousands of followers and 2) assumes every one is an active user, when in reality around 80% of the nodes in the simulation should just be lurking, which lot to see but not interacting at all.

In the same line, an effort to get real navigational data from users should be made in order to accurately calibrate the inter-action time variable. Is one of the more crucial variables not only in this work, but as a quantity in this field of study. Having it would remove a lot of the "feeling" chosen variables. 

#todo[I think i am missin something?]

== Data Limitations

#todo[finish]

Talk about need of either a far more complex sessionization methodology or much more rich data regarding the users actual engagement.

Talk about that computing structual virality is actually complicated, and the intrsection of the data with recomender alforithms is indeed complicated to distinguish true quality and relevant data.

As well talk as the data comparsion is well, weird, due to the nature of the extracted data. TL;DR: $nu (v)$ is a lower bound for the probably true structural virality of the data.

== Analyisis Limitations

There are plenty characteristic magnitudes that could be monitored if the simulation reproduces, as well as more evaluation metrics interesting to reproduce, such as post lifetime analysis.

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

