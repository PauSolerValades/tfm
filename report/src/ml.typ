
As the basic engine is finished it's time to take down the most constrictive axioms. Let's recall the rellevant axioms @.

1. User Homogeneity: Every user $u in cal(U)$ is indistinguishable in behavior and shares the exact same decision policy $pi$.
  
$ forall u_i, u_j in cal(U) : pi_(u_i) = pi_(u_j) = pi $

2. Post homogeneity: All post are the same content wise, as there is no post content.

$ i = j forall i,j in I $

3. Action Independence: A user's choice to interact with a post $i$ at time $t$ depends strictly on their static policy $pi$, independent of their historical impression history $cal(H)_u^"act"$. 

$ PP (e = (u, i, a, t) | cal(H)^"act"_u(t)) = pi(a) $

This section focuses on the decided approach on how to take down this axioms.


== Main Mechanics and match with DES

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

== Sampling Mechanisms
<sec-ml-sampling>
// This section has been AI Generated 

*Method 1 - Dirichlet Weighting*

The user's state $S(u)$ is defined not as a single statistical point (and with the use of the $Gamma$ function above), but as a bounded collection of the $N$ most recently liked posts:

$ S(u) = { i_1, i_2, dots, i_N } quad "where" i_j in cal(P)(u) $

To generate a new post $i_(N+1)$, we sample a set of random weights $w_j$ (approximating a Dirichlet distribution) such that their sum equals 1. The new post is the convex combination of the history:

$ sum_(i=1)^N w_i = 1 $

$ i_(N+1) = sum_(j=1)^N (w_j dot i_j) $

By changing with posts are in $S(u)$ we can also change user state, and according to the weight of that post it will have more or less impact.

*Method 2 - Gaussian Sampling*

The user's state consists of a continuously updated mean $mu$ and variance $sigma^2$ calculated independently for all dimensions. This can be obtained with the application of a $Gamma$ function combination of the embedded posts.

When a user interacts with a post $i$, we update their profile using a learning rate $alpha$. The variance calculation is adapted from Welford's online algorithm to maintain numerical stability:

$
  mu_(j+1) &= (1 - alpha) mu_j + alpha i \
  sigma^2_(j+1) &= (1 - alpha) sigma^2_j + alpha ( (P - mu_j) dot.o (P - mu_(j+1)) )
$
_Note: $dot.o$ represents the Hadamard product (element-wise multiplication)._

To create a new post, we draw standard normal noise $epsilon ~ cal(N)(0, 1)$ and scale it by the dynamic variance:

$
  i = mu + (sigma dot.o epsilon)
$

== Action Independence
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
