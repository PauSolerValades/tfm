#import "utils.typ": *

#todo[this is a combination of discarded parts from the sota and several no verified ideas and a quite good amount of llm unverified text.]


This section covers the ideas on how to circumvent the most limiting aspects of current simulations and models.

Traditional information diffusion models (see @sec-sota-diffusionmodels) typically treat diffusion as a purely structural mechanic. While this simplifies the modeling of information flow, it often ignores critical factors such as the semantic nature of the content or the transmission process itself. This abstraction serves as a trade-off to maintain mathematical tractability; however, in reality, Online Social Networks (OSNs) are driven by human psychology. This introduces significant "friction points" to pure structural diffusion, most notably finite cognitive attention and the requirement for cumulative exposure. This section explores the content-aware mechanics and human behaviors that are often omitted from traditional structural methods.

== Non-Agnostic Information Diffusion

Most classical diffusion models deliberately focus on the "container" rather than the "content." The justification for this approach lies in the unique topological properties of social networks (see @sec-sota-topologies), where the observed flow of information often mimics real-world data patterns regardless of the message being sent. For instance, basic structural models can effectively replicate the "Small World" effect or the heavy-tailed distribution of cascades found in empirical datasets. 

We see a tangential acknowledgment of content in the application of specific models: the Independent Cascade (IC) model is frequently utilized to simulate the viral spread of misinformation, whereas the Linear Threshold (LT) model is better suited for modeling belief changes on complex topics. These choices imply an underlying assumption about the *type* of content being transmitted, even if the model itself remains mathematically agnostic to the semantics.

The future of the field, however, lies in *content integration*. Recent advancements have leveraged Large Language Models (LLMs) to simulate how users generate and interpret posts, providing a more nuanced understanding of agent interaction (e.g., the OASIS framework). More conservative approaches utilize vector embeddings to represent content, where dimensionality reduction allows for a quantitative representation of a post's semantics.

By introducing content-aware variables, researchers can model the most critical driver of social interaction: *homophily* (see @sec-sota-topo-homophily). In content-agnostic models, the probability $p$ that a user $u$ reposts item $i$ is often treated as a constant $p in [0,1]$. A content-aware approach transforms this into a dynamic function proportional to the similarity between the item $i$ and the user's historical preferences or "history" $cal(H)_u$ at time $t$:

$ p(u, i) prop "sim"(i, cal(H)_u (t)) $

In LLM-based approaches, this is achieved by prompting the model with the user's context to determine interaction likelihood. In embedding-based models, "sim" is typically calculated using measures such as cosine similarity between feature vectors.

== Simple and Complex Contagion
<sec-sota-diffusion-contagions>

A significant limitation of many diffusion models is the failure to distinguish between—or allow for the coexistence of—simple and complex contagion mechanics. In a real-world social network, these two dynamics do not cannibalize one another; rather, they operate in parallel depending on the nature of the information.

*Simple contagions*, such as the spread of a viral meme or a breaking news headline, often require only a single exposure to "infect" a user. Conversely, *complex contagions*—such as the adoption of a new political belief or a lifestyle change—require reinforcement from multiple sources to overcome social inertia. 

=== Linear Threshold Model

The Linear Threshold model (LT) assumes that information spreading requires multiple expositions to the same content before activating the user. We call this behaviour complex contagion @wiki-complex-contagion.

*Definition* (Complex Contagion): is the phenomenon in which multiple sources to an innovation are required before an individual adopts the change of behaviour @centola2007complex.

The mechanisms both in Epidemics (see section @sec-sota-diffusion-epidemic) and in cascade (see @sec-sota-diffusion-cascade) models are classified as simple contagion due to just one exposition is enough to change the node state from inactive to active. This is used to model shifts in belief or costly sociopolitical behaviours, as opposite of simple, which could be more resembling a meme or fake news spreading. @centola2007complex @meng2025spreading. In contrast, LT modelizes the multiple exposures required of a complex contagion.

The (LT) model focuses on modeling the activation according to the neighbours of the user neighborhood, continual exposure to certain elements. The assumptions this model runs under are:
- Every node $i$ has a threshold $theta_i in [0, 1]$, their inherent resistance to change state. 
- Every directed edge from a neighbor $j$ to node $i$ is assigned a non-negative weight $w_(j i)$, the proportional degree of influence $j$ exerts on $i$ @zhang2014chapter1. 
- A node $i$ will only become active if the sum of the influence weights from its currently active neighbors meets or exceeds its personal threshold:

$ sum_(j in cal(N)(i)) w_(j i) >= theta_i $
 
Because it strictly requires simultaneous or accumulated exposures, the LT model very accurately meso-scale properties of a social network: information spreading process easily saturates dense communities (clusters of the network, see @sec-sota-topo-community e.g. forming echo chambers) as the information struggles to propagate through weak ties between communities due to it's inherent nature @centola2007complex.


While the standard IC model dictates a "single-chance" refractory state suited for simple contagions, the diffusion of opinions often operates under complex logic. Meng et al. explicitly quantify this dynamic, demonstrating that the probability of a user adopting or retweeting information scales dynamically with the number of exposures from different neighbors @meng2025spreading. A user might ignore a topic upon its first appearance in their feed, but multiple exposures from disjoint clusters in their network significantly lower the threshold for interaction.

== The proposal

We had the following assumptions when implementing the simulation.

1. User Homogeneity: Every user $u in cal(U)$ is indistinguishable in behavior and shares the exact same decision policy $pi$.
  
$ forall u_i, u_j in cal(U) : pi_(u_i) = pi_(u_j) = pi $

2. Post homogeneity: All post are the same content wise, as there is no post content.

$ i = j forall i,j in I $

3. Action Independence: A user's choice to interact with a post $i$ at time $t$ depends strictly on their static policy $pi$, independent of their historical impression history $cal(H)_u^"act"$. 

$ PP (e = (u, i, a, t) | cal(H)^"act"_u(t)) = pi(a) $


DES main strength are the scalability of the simulations, which is able to process milions of elements in very few minutes. That limits our options of using posts as something that needs to not to be a heavy computational task in the middle of the simulations (_e.g._, we cannot wait for any GPU computations on the fly to generate text, discarding LLM's use both in generation and understanding) so we have to settle for the next best thing: an embedding.

An embedding (definition of embedding)

Given a user $u in U$ we can consider its historic ($cal(H) (u)$) as a good way to define who the user is. Let's consider the posts created by the user $cal(P) (u, 0)$, before the simulation starts. Considering the embedding $f$, we can define the user state as

$ S(u) = Gamma({f(i) | i in cal(P) (u, 0)}) $

where $Gamma$ is an aggregation function. Of course, it's trivial that $S(u)$ is an embedding in itself.


Once the state of the user is done its just a vector in a space. This means that we have a representation of user opinions and characteristics through a post in a single vector. With that, we can sample from this vector to generate posts with similar characteristics the user would have done, removing the way to use actual words, but the embedding being representative of the user opinions, see @sec-ml-sampling.

Now, every user can generate semantically relevant posts according to their inner state, as the embedding combination $S(u)$ allow us to represent a user as a easy-to-work-with numerical vector.

This allows to address each axiom one by one
1. User Homogeneity: we just need a series of posts to create our user. Semantic analysis of the embedding might allow for synthetic data to not need empirical data.
2. Post homogeneity: as every user samples posts now, there will be no identical posts.
3. Action Independence: see @sec-ml-action-independence

=== Content Aware Post Creation
<sec-ml-sampling>
// This section has been AI Generated 

The user's state $S(u)$ is defined not as a single statistical point (and with the use of the $Gamma$ function above), but as a bounded collection of the $N$ most recently liked posts:

$ S(u) = { i_1, i_2, dots, i_N } quad "where" i_j in cal(P)(u) $

To generate a new post $i_(N+1)$, we sample a set of random weights $w_j$ (approximating a Dirichlet distribution) such that their sum equals 1. The new post is the convex combination of the history:

$ sum_(i=1)^N w_i = 1 $

$ i_(N+1) = sum_(j=1)^N (w_j dot i_j) $

By changing with posts are in $S(u)$ we can also change user state, and according to the weight of that post it will have more or less impact.

== Action Independence or Homophily
<sec-ml-action-independence>

This section adapts based on the sampling approach defined in @sec-ml-sampling.

Action independence asserts that a user's current action does not depend on their chronological sequence of past actions, but is instead sampled independently from a behavioral policy:

$ P(e = (u, i, a, t) | cal(H)^"act"_u(t)) = pi_u(a) $

However, rather than using static probabilities for every interaction, we want this policy to dynamically react to the actual content the user is viewing. For example: if a post perfectly aligns with a user's interests, the probability of doing "Nothing" should drop drastically, while "Like" and "Repost" should rise. Conversely, if the post is completely irrelevant, "Nothing" should become the overwhelmingly likely outcome. That is, we want the thresholds of the categorical distribution to change when according to the semantics of the post

We define this alignment by calculating the cosine similarity $c$ between the user's current state $S(u)$ and the post's embedding $f(i)$:

$ c = S_C (S(u), f(i)) = frac(bold(S(u)) dot bold(f(i)), ||bold(S(u))|| ||bold(f(i))||) $

*2. Defining Action Parameters (Bias and Sensitivity)* \
To map this similarity score $c$ into a concrete decision, we calculate a raw mathematical score (a "logit", denoted as $z_a$) for every possible action $a in cal(A)$ (e.g., Nothing, Like, Repost). This score is built using two intuitive parameters:

- *Base Bias ($beta_a$):* This represents the default tendency of the user to take this action, regardless of the content. Because users naturally scroll past the vast majority of posts, the "Nothing" action is assigned a very high base bias, while "Repost" is assigned a low base bias.
- *Sensitivity ($theta_a$):* This acts as a multiplier, determining how strongly the action reacts to the content similarity $c$. "Like" and "Repost" will have high positive sensitivities (meaning a high $c$ rapidly drives up their score), whereas "Nothing" has a negative sensitivity (a high $c$ actively reduces its likelihood).

$ z_a = theta_a dot c + beta_a $

*3. The Activation Function (Softmax)* \
Finally, these raw scores ($z_a$) are unbounded numbers and do not represent true probabilities. To convert them into a valid probability distribution—where all options are between 0% and 100% and sum exactly to 1.0—we pass them through an *activation function* called Softmax:

$ pi_u (a | c) = frac(exp(z_a), sum_(k in cal(A)) exp(z_k)) $

This formulation avoids the rigidity of deterministic thresholds. It ensures that a high similarity $c$ exponentially boosts the likelihood of engagement, while preserving the stochastic, random noise inherent to authentic human browsing behavior.

=== Modeling Further Complex Contagion

The work of Meng et al. @ meng2025spreading introduces a paradigm shift in understanding information spreading dynamics, moving beyond simple linear reinforcement. Their empirical analysis of large-scale social networks demonstrates that the probability of retweeting follows a ubiquitous pattern of "first rising and then falling," typically peaking at around two to three exposures ($x^* in [2, 3]$). This phenomenon is driven by two competing mechanisms: social reinforcement (which increases the perceived importance of a message with multiple exposures) and social weakening (where the proportion of potential "fresh audiences" decreases as more overlapping friends have already seen the post).

Meng et al. formalized this propagation dynamic with the following equation:

$ beta_i (x) = alpha_i x (1 - gamma)^{x^(omega_i)} $

Where $alpha_i$ represents the intrinsic spreading power of the information, $x$ is the basic linear reinforcement effect (exposure count), $gamma$ is the average proportion of common neighbors between users, and $omega_i$ calibrates the effective exposure rate based on user uncertainty.

While highly effective for macroscopic modeling, the original formulation assumes a static, universal spreading power ($alpha_i$) for each message. In our simulation, we must account for user heterogeneity and semantic homophily. Therefore, this structural dynamic can be seamlessly integrated with our content-aware decision policy detailed in @sec-ml-action-independence.

We propose substituting the static intrinsic spreading power ($alpha_i$) with our dynamic, personalized Softmax probability, $pi_u ("Repost" | c)$. This transitions the model from evaluating how viral a post is *globally*, to how resonant a post is *individually*.

The merged content-aware spreading probability for a specific user $u$ and post $i$ at exposure $x$ becomes:

$ beta_{u, i} (x) = pi_u ("Repost" | c) dot x (1 - gamma)^{x^(omega_i)} $

Expanding the Softmax policy, the full function incorporates the cosine similarity $c$ between the user's state $S(u)$ and the post embedding $f(i)$:

$ beta_{u, i} (x) = frac(exp(theta_"Repost" dot c + beta_"Repost"), sum_(k in cal(A)) exp(theta_k dot c + beta_k)) dot x (1 - gamma)^{x^(omega_i)} $

This synthesis elegantly resolves the reinforcement paradox: even highly exposed posts (high $x$) will not trigger unrealistic, network-wide outbreaks unless they maintain high semantic alignment ($c$) with the viewing users. It naturally fractures cascades into topically relevant sub-communities, preserving both structural decay and semantic homophily.


The continuous nature of our embedding-based architecture opens several avenues for modeling complex sociological phenomena as vector operations. By treating both users and content as coordinate points, we can expand the simulation beyond static homophily. We outline two primary extensions for future research: semantic mutation and semantic repulsion.

=== Semantic Mutation: Modeling Content Drift
Currently, the model assumes that once a post $i$ is sampled, its embedding $f(i)$ remains static throughout the contagion process. However, empirical social media interactions heavily feature mechanisms like the "quote-retweet," where a user appends their own commentary and context to an existing post. 

We can model this "content drift" by having the retweet action synthesize a new post embedding $i'$. This new embedding is calculated as a convex combination of the original post's vector and the retweeting user's internal state:

$ f(i') = lambda f(i) + (1 - lambda) S(u) $

Where $lambda in (0, 1)$ dictates the fidelity of the retweet. Under this mechanism, as a post travels further from its source, its semantic meaning actively shifts. This allows the simulation to capture how information mutates—for instance, how a benign post might absorb the bias of a highly polarized network cluster over successive diffusion steps.

=== Semantic Repulsion: Outrage Contagion
Our foundational Softmax policy assumes that engagement scales strictly with semantic alignment (where a high cosine similarity $c -> 1$ drives interaction). Yet, sociological phenomena such as "rage-bait" and hate-reading demonstrate that users frequently engage with content that diametrically opposes their worldview ($c -> -1$).

To capture this adversarial engagement, the linear sensitivity parameter can be expanded into a non-linear, parabolic function for specific actions (such as a "Quote Repost"). The raw action score $z_a$ is modified to:

$ z_"Repost" = theta_1 c + theta_2 c^2 + beta_"Repost" $

By tuning $theta_2 > 0$, the probability of engagement forms a U-curve, rising at both extremes of the similarity spectrum. This mathematically models outrage contagion, ensuring that severe semantic clashes trigger as much virality as perfect homophily, bypassing traditional structural friction.
