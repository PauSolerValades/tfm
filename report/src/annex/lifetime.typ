#import "../utils.typ": def 

This annex contains discarded material of the post lifetime analysis. Specifically, the following two sections cover the analysis of how the three main parts of the model (the CTIC, the queue and the activity) will influence the lifetime, and how could we explain them analytically. This sections were discarded despite it's research interest due to three facts:
1. Length: as the report was getting unbearably long, it was decided to cut some detail
2. Specificity: this reads more as a mathematical idea than a formal lifetime analysis.
3. Time: with more time it could have been framed as one crucial part of the work.

== Lifetime Description

To mathematically capture this cognitive bottleneck within our formal model, information diffusion is modeled as a reverse-chronological queueing process. As established in @sec-model-ctic, this is resolved by the timeline subset $cal(T)_t (u)$, which functions as a time-descending priority queue where propagated posts are stored.

Let us assume a post $i$ is created (or reposted) by user $u$ at time $t$, and $v in cal(N)_"out"(u)$ is a follower of user $u$. The exact time user $v$ is actually exposed to this post, denoted as $tau$, can be modeled as:

$ tau = t_a + X $

where $t_a = t + eta((u,v,"follow"), t)$ is the exact arrival time of the post in the timeline (incorporating the structural platform delay), and $X$ is a dynamic random variable representing the user-side consumption delay. 

Because the timeline is sorted in reverse-chronological order (newest first), $X$ is a complex convolution of the user's offline status and their scrolling behavior, structured as:

$ X = Delta_"idle" + Delta_"scroll" $

These components behave strictly according to the LIFO (Last-In, First-Out) nature of the timeline:
+ *Offline Penalty ($Delta_"idle"$)*: If the post arrives at time $t_a$ while the user is offline ($t_a in.not cal(O)(v)$), it sits unseen until the user's next active session interval $I_k$ begins at $t_k$. Therefore, $Delta_"idle" = t_k - t_a$. If the user is already online when the post arrives, it appears at the top of the feed, meaning $Delta_"idle"$ is effectively just the time until the user's next immediate action tick.
+ *Reverse-Chronological Processing ($Delta_"scroll"$)*: Once the user is online, they consume the feed from newest to oldest. Therefore, the "backlog" obstructing post $i$ does not consist of older posts, but of $N_"newer"$ posts that arrived *after* $t_a$ (e.g., while the user was still offline). $Delta_"scroll"$ represents the cumulative inter-action time required for the user to evaluate and scroll past all $N_"newer"$ posts positioned above post $i$ in $cal(T)_t (v)$.

This reverse-chronological dynamic introduces a somewhat survival mechanism for the posts, perfectly mirroring the hazard functions of the CTIC model. If a post arrives early in a long offline period, a massive volume of newer posts will pile on top of it. When the user logs in, the required $Delta_"scroll"$ to reach the post will be exceptionally high. 

If the user's active session duration $Delta_k$ is shorter than the time required to scroll past the newer content ($Delta_"scroll" > Delta_k$), the transmission opportunity is lost entirely. In our simulation, timelines are purged upon session termination, meaning buried, unread posts fail to propagate ($tau -> oo$). Because $X$ dynamically depends on the instantaneous influx of competing posts and overlapping temporal session boundaries, it is mathematically intractable to solve via closed-form equations, which justifies the use of a Discrete Event Simulation (DES), which allows us to natively resolve $X$ by simulating reverse-chronological consumption step-by-step.

== Post Lifetime Analysis

To formally synthesize this dynamic, the probability of post $i$ surviving the queue and being seen by user $v$ is fundamentally dictated by the volume of competing information. We can define a timeline influx rate, $mu_v$:

#def(name: "Influx Rate")[The influx rate $mu_v$ is the expected number of posts arriving per unit of time in user $v$'s timeline.]

As a macroscopic variable, $mu_v$ is an aggregation of the network topology (the out-degree $|cal(N)_"out"(v)|$), the generative creation rates of those followees ($lambda$), and their reactive repost probabilities ($pi("repost")$), for which we do not attempt to derive a closed-form analytical expression.

If post $i$ arrives at time $t_a$ while the user is offline, it will sit idle until the next session begins at $t_k$, resulting in an offline penalty $Delta_"offline" = t_k - t_a$. During this exact temporal window, newer posts continue to arrive at rate $mu_v$. 

To find the exact probability of the post being seen, we must consider the processing time of every single newer post. Let $D_"action"^((m))$ be the random variable representing the time taken by user $v$ to process the $m$-th newer post. For post $i$ to be successfully seen, the cumulative time required to evaluate the $N_"newer"$ posts positioned above it must be strictly less than the user's active session duration $Delta_k$. The exact survival probability is therefore:

$ PP ("seen") = PP  ( sum_(m=1)^(N_"newer") D_"action"^((m)) < Delta_k ) $

Evaluating this strict probability analytically requires convolving the distributions of the arrival process ($N_"newer"$), the individual reading times ($D_"action"^((m))$), and the session durations ($Delta_k$). Because this is a very complex system, finding a closed-form solution is computationally intractable. This intractability fundamentally justifies the reliance on the Discrete Event Simulation (DES) (see @sec-method-des) to natively resolve these reverse-chronological interactions.

However, to establish an intuitive macroscopic understanding of the system's core mechanism, we can apply a first-order mean-value approximation. The expected number of newer posts positioned above post $i$ when the user finally logs in can be approximated by:

$ EE[N_"newer"] approx mu_v dot Delta_"idle" = mu_v dot (t_k - t_a) $

Let $EE[D_"action"]$ denote the expected inter-action delay (the average time user $v$ spends processing a single post). Applying Wald's Equation, the expected continuous time required to scroll past the newer backlog is:

$ EE[Delta_"scroll"] approx EE[N_"newer"] dot EE[D_"action"] = mu_v dot (t_k - t_a) dot EE[D_"action"] $

In this deterministic mean-value framework, the condition for a post to likely survive is that the expected scrolling time must be bounded by the user's active session duration:

$ EE[Delta_"scroll"] < Delta_k $

Together, the theoretical probability and its mean-value approximation define the core mechanism of the simulation: the likelihood of a post surviving the queue is *inversely proportional* to both the timeline influx rate $mu_v$ and the elapsed idle time.


