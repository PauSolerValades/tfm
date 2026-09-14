#import "../utils.typ": *

== Simple and Complex Contagion
<sec-future-content-contagion>

Information diffusion models fall into two broad families based on how a node transitions from inactive to active.

*Simple contagions*, such as the spread of a viral meme or a breaking news headline, require only a single exposure to "infect" a user. The Independent Cascade (IC) model captures this elegantly: each newly activated node gets a single, independent chance to activate each of its outgoing neighbors, after which it becomes refractory and can never activate again @gomezrodriguez2011uncovering. This single-chance mechanic is well-suited for content that spreads impulsively --- a user sees a funny post, reposts it, and moves on.

*Complex contagions* ---such as the adoption of a new political belief, a lifestyle change, or trust in a controversial claim--- require reinforcement from multiple sources to overcome social inertia @centola2007complex. A user might ignore a claim the first time they see it, but after hearing it from three different friends in separate communities, the cumulative social proof becomes persuasive.

The Linear Threshold (LT) model formalizes the complex contagion dynamic: every node $i$ has a threshold $theta_i in [0, 1]$ representing their resistance to change, and every directed edge from neighbor $j$ to node $i$ carries an influence weight $w_(j i)$ @zhang2014chapter1. A node becomes active only when the cumulative influence from its currently active neighbors meets or exceeds its personal threshold:

$ sum_(j in cal(N)(i)) w_(j i) >= theta_i $

Because it strictly requires accumulated exposures, the LT model tends to accurately captures meso-scale properties of social networks: information easily saturates dense communities (clusters, echo chambers) but struggles to propagate through weak ties between communities @centola2007complex.

The LT model, like the IC model, is content-blind. The threshold $theta_i$ measures how many neighbors are active, not what they are saying. A node in the LT model will adopt a belief after enough neighbors adopt it, regardless of whether that belief aligns with or contradicts everything the node has previously expressed. Complex contagion ---and the LT model--- translate this fact, but is still content blind.

=== Integrating Complex Contagion

The work of Meng et al. @meng2025spreading introduces a paradigm shift in understanding information spreading dynamics, moving beyond simple linear reinforcement. Their empirical analysis demonstrates that the probability of retweeting follows a pattern of "first rising and then falling," typically peaking at around two to three exposures ($x^* in [2, 3]$). This is driven by two competing mechanisms: social reinforcement (multiple exposures increase perceived importance) and social weakening (diminishing returns as overlapping audiences saturate).

Meng et al. formalized this as:

$ beta_i(x) = alpha_i + x (1 - gamma)^(x^(omega_i)) $

where $alpha_i$ is the intrinsic spreading power of the information, $x$ is the exposure count, $gamma$ is the average proportion of common neighbors between users, and $omega_i$ calibrates the effective exposure rate.

The original formulation assumes a static, universal spreading power $alpha_i$ for each message. We propose replacing it with a dynamic softmax per user probability $pi_u("repost" | c)$, transitioning from how viral is this post globally to how resonant is this post for this specific user.

$ beta_(u,i)(x) = pi_u ("repost" | c) dot x  (1 - gamma)^(x^(omega_i)) $

Expanding the softmax policy with the cosine similarity $c$ between user identity embedding $S_"id" (u, t)$ and post embedding $f(i)$:

$ beta_(u,i)(x) = frac(exp(theta_"repost" dot c + beta_"repost"), sum_(k in cal(A)) exp(theta_k dot c + beta_k) dot x) (1 - gamma)^(x^(omega_i) $

This synthesis resolves the reinforcement paradox: even highly exposed posts (large $x$) will not trigger unrealistic, network-wide outbreaks unless they maintain high semantic alignment ($c$) with the viewing users. Cascades naturally fracture into topically relevant sub-communities, preserving both structural decay and semantic homophily.

Taken together, the proposals given in this section sketch a research path from a purely structural, content-agnostic simulation toward one where diffusion emerges from the interplay between semantics and topology. The result is a framework where who users are, what content says, and how communities reshape it are no longer orthogonal assumptions but continuous, entangled dynamics, making ---allegedly--- a worth exploring research topic.
