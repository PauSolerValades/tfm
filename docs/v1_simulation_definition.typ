#set text(font: "Liberation Sans")

This document contains the reorganized notes with Esteve's meeting at 10-02-26.

= Definition of the Bare-bones Simulation.

We are going to define the bare-bones simulation. The objective of this is to build an engine which does not take into account _real data_ but only all the concepts that are going to interact and test if the theoretical idea makes sense.

== Scope of v1

This first version of the engine simulation should be used to verify and stablish a solid implementation basis which are verifiable - that is to be as certain as possible of bug's absence. The document _specification_bluesky_ specifies what features compose the features Bluesky social network has, which we'll describe (hollisticaly) a subset in the following paragraph.

The main objective of the simulation is to analyze how do posts behave: how far they travel, how many distinct users interact with that post within the timeline and no custom recommender in action. For that, we need to implement *Posts* and the relations with themselves (a post can be a reply of a post). Posts are shown to *users* according to the post creation time and which set of users is the user *following* at a given time. A user can interact with a post in several ways, so we must define *actions* that a user can perform over a post. In the bluesky case those are to like, reply, repost and quote another post. Replying, reposting and quoting will influence user's timeline as well as timelines of all other users, but not linking a post, which will be added to the liked tab.


== Notation

To not lose hours and sanity, I will specify the notation to be used in all the document here. If it's in anyway unorthodox, it's because I asked to an LLM to give me an idea.
- User from the set of users: $u in U$, and $|U| = N$.
- Post (item) from the set of posts (items): $i in I$, and $|I| = M$.

A user has several actions to perform in the simulation. We denote the set of possible actions as 

$ cal(A) = { emptyset, "like/"l, "reply/"c, "repost/"r, "quote/"q } $

And we denote user $u$ doing action $t$ over item $i$ as:

$ a_(u,i)^((k)) in cal(A) $

As a user can perform more than one option over a post, we must denote the action as a vector:

$ bold(a)_(u,i) in {0,1}^(|cal(A)| - 1) $

where each index corresponds to an action type with the order Like, Reply, Repost and Quote. E.g, $y = [1,0,1,0]$ would be a like and a repost.

Each user follows other users. We call the set of users a given user follows as $Gamma"out"(u)$, which are the sources of its timeline. $Gamma$ has been chosen due to this being the neighbours of user $u$. For the sake of completion, we call the set of users that follow our user $Gamma"in" (u)$.

Every user creates (or has created) posts. We denote the list of posts created by user $v$ as $P_v = { i in I : "author"(i) = u }$. We define $A_u$ as the activity stream, which is all the posts that will end up in the timeline by user $u$.

$ A_u (t) = P_u (t) union { i in I | exists tau < t : a_(u, i)^((tau)) in {c, r, q} } $

The timeline of a user $u$ is all the posts created, replied, reposted and quoted by all the users the user $u$ follows.

$ cal(T)_u (t) = union.big_(v in Gamma_"out" (u)) A_v (t) $

Regarding evaluation metrics, we have to distinguish between several traces of the simulation, one for what the user has seen, another for what the user has done, and the last one for what has happened to the post.

- Impression history of a user: $H^"imp"_u (t) = epsilon_u (t) = (i_1, i_2, ..., i_k) $. It is essentially a subset of $cal(T)_u$, but allows us to review in order what has the used seen. will be needed to count how many users have seen each post.
- User historic activity: $H^"act"_u (t) = cal(H)_u (t)= {(i,a, tau) : a != emptyset, tau < t } $. What exactly did the user do, at which time.
- Item trajectory: $T_i (t) = {(u, {c,r,q}, tau)  | tau < t } $. That is a list with all the users who have reposted at given time time $tau$.


== Axioms

This lists what the simulations assumes (several simplifications) in order to simplify the implementations. This are not immutable, some of them will be torn down in more advanced versions of the simulation.

1. User/Agent Homogeneity: every user is indistinguishable from the other users, they behave absolutely the same, that is, they have the exact same decision policy $pi$.

$ forall u_i, u_j in U : pi_(u_i) = pi_(u_j) = pi $

2. Action Independence: The agent (user) is memoryless regarding past actions:

$ PP (a_(u,i)^t | cal(H)_u ) = PP (a_(u,i)^t ) $

3. Stable User Population: no new users are added in the simulation duration.
4. Stable Post Population: no new posts are going to be created during the simulation duration.
5. Algorithm: chronologically followers recommendation.

== Pseudo Algorithm

We can simulate the networks with a Discrete Event Simulation with the Event Scheduling Algorithm. The steps are

1. Create the simulation graph. That is
- Users and followers.
- Posts and ownership of those posts with given timesteps.
- probability vector of a user doing an action.
2. Set up iter-time distributions: every how often should a user "awake" and do something
2. Add first event: user actuates over a post.
3. while (t < horizon)
4. if user awakes, generate another action
5. if action is reply, repost or quote, for every user who is following that user, update their timelines. else nothing
6. Update traces.


== Implementation details

There must be a list with all the posts, and then each user has a min-heap with a index (or a pointer) to the post the user has to see (the oldest one). 

Each user must have both which posts has he written, which posts has he interacted and what action did the user performed (well, that's the trace)

Regarding the time between actions of the user, we will assume a exponential distribution, such as an interarrival time.

Due to axiom 1, user will have all the same weights $pi$, but which action is performed is a weighted probability (uniform from zero to one and in which interval falls)

== Algorithm evaluation using Markov properties

Social networks are path-dependent (user action depends on past actions performed in different posts), we can formalize the Simulation Engine as a Markov Chain to prove convergence.

Markov chains are usually characterized as _memoryless_ process, meaning that the probability of going to the next state does not depend on previous states:

$ PP (s_j | s_1,...,s_(j-1), s_j) = PP (s_j | s_(j-1)) $

This does not behave at all as a social network nor is not the statement of the first axiom. The tricky fact is that we can characterize the user history of impressions $cal(H)_u$ and the item states $cal(C)_i$ as a Markov chain with the memoryless property by defining the state as $S$:

$ cal(S)_t = {cal(H)^t_(u_1), ..., cal(H)^t_(u_N)} union {cal(C)^t_(i_1),...,cal(C)^t_(i_M)} $

Given $n$ the number of posts seen until now, we can consider all the posts until that point, so we can express the memoryless like this:

$ PP ( cal(S)_n | cal(S)_(n-1),...,cal(S)_1) =  PP ( cal(S)_n | cal(S)_(n-1) ) $

Considering this fact gives us all the nice Markov chain properties, such as, giving an explicit probability distribution of changing between states, our simulation will converge to the stationary distribution $pi$ of the Markov Chain. Therefore, if the code produces a distribution of interactions that matches $pi$ then the code is bug-free. Let's narrow it down with an example.

A user $i$ has it's policy defined by $pi_u$, which is essentially a probability distribution which has to add up to 1.

$ pi_u = (pi_emptyset, p_l, p_r, p_q, p_c); sum pi_j = 1 $

We can do that by axiom 1, which tells us that every user has the same policy.

Let's invoke the other axioms to guarantee that this is a markov chain. Axiom 2 makes $pi_u$ not change with $t$ (what a user has seen depends on the time it has been seen) which makes the system time-homogenous. Axioms of stability (3 and 4) also makes it homogenous. Axiom 5 ensures that all users see all posts of the users they follow, so defines the state transitions, the topology of the chain. A more sophisticated recommender would change that, and it would not be a markov chain anymore. The definition of memoryless given in this section is the final nail in the coffin, the system can be modelized as a markov chain, therefore it will converge to it's analitical distribution.

As a final note, the User Homogeneity axiom is _not needed_ for the system to be modelized as a Markov chain, but it's needed to find an analytical expression to test the code against.

As a final final note, axiom 5 _i think_ could be rephrased. That is, imagine that user i sees posts ${1,2,3}$, a simple markov chain. Now, assume user $j$ reposts post $3$, and that's why user $i$ is seeing that. Despite this not seeming markovian, i think it still is? State of user $i$ depends on user $j$, that means that the path (current state $cal(S)_t$) depends on the state of the user $j$, so it is still a markov chain with a bigger state which encompasses all users of the social network.
