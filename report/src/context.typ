#import "utils.typ": todo, comment

This section introduces context to the project: what a microblogging social network is, the nature of the phenomenon we want to study, and why Bluesky is the chosen social network to simulate.

== Definitions and Prerequisites 

This section aims to provide with basic definitions and understanding of the Social Network subfield.

*Definition* (Network): a network is a special case of a graph, where the vertices, edges or both, possess attributes @wiki-network-theory. 

*Definition* (Social Network): a Social Network is a social structure consisting of a set of social actors (such as individuals or organizations) and social interactions between actors @wiki-social-network. They are studied by the SNA (Social Network Analysis field) which examines the structure of the relationships within those entities

So, any network that models any relationship between humans, groups or humans or human-made-organizations is classified as a social network.

Online social newtorks (OSN) are a specific case of Social Networks, where the entities are users and posts, and the relationships are follow, followee, mute, block, create, repost, like, comment, quote, reply...

[TODO: focus a little bit more on the other differences, which makes the content go flying and generates the cascades immediately]

A social network is also classified as a complex system. To describe the behaviour of this fact, ---and given that the definition of complex system is still debated up to date--- the Edgars Morin definition of complex system is used @choudhary2023impact.

*Definition* (Complex System): A complex system is defined as the system where there is a bidirectional non-separability between the identities of the parts and the identity of the whole.

Clearly, this definition applies to social networks. The unique identities of the parts (users and their individual posts) combine to create the overarching identity and emergent behaviors of the platform. In turn, this macro-structure dictates how information spreads and what content is amplified, which fundamentally alters the user's worldview, online identity, and subsequent behavior within the system.

To define and study content diffusion, the two most important factors are the topology of the actual network (see @sec-context-topologies) and model chosen to model the actual diffusion (see @sec-context-diffusionmodels).

== Social Network Topologies
<sec-context-topologies>

This section aims to characterize the topology of social networks according to their main factors. To explain the features of the topology, we must introduce first a way to model the heterogeneity and multiple edge types of a Social Network rigorously.

=== Multilayer Network

While a social network has been modeled traditionally as a graph, it's a very narrow model to reason about. Kivela et al @kivela2014multilayer introduces the concept of Multilayer Network, which perfectly encapsulates what a complex social network is:

*Definition* (Multilayer Network @kivela2014multilayer): A multilayer network is a quadruplet $M = (V_M, E_M, V, L)$, where:
- $V$ is the set of all nodes in the system
- $bold(L) = {L_a}_(a=1)^d$ is a sequence of sets of possible layers, where $d$ represents the number of distinct aspects (dimensions) of the network
- $V_M subset.eq V times product_(a=1)^d L_a$ is the set of node-layer tuples, representing exactly which node exists in which layer
- $E_M subset.eq V_M times V_M$ is the multilayer edge set connecting these tuples

In an online social network environment, we can define two primary aspects ($d=2$): node types (users, posts, ...) and interaction types (follows, likes, reposts...). The point of this definition is that $G_M = (V_M, E_M)$ is a graph, so a Multilayer Network can be interpreted as a graph with specific labelings over the nodes and edges.

We can also partition the edges into _intra-layer edges_ $E_A = {((u, bold(alpha), (v, bold(beta))) in E_M | bold(alpha) = bold(beta))}$ and the _inter-layer edges_ as E_C = E_M - E_A.

The adjacency matrix for a fully interconnected multilayer network can be represented by an order-$2(d+1)$ adjacency tensor $cal(A)$. The tensor elements $cal(A)_(u v bold(alpha) bold(beta))$ have a value of $1$ if there is an edge between node $u$ in layer $bold(alpha)$ and node $v$ in layer $bold(beta)$, and $0$ otherwise.

$
cal(A)_(u v bold(alpha) bold(beta)) = cases(
  1 "if" ((u, bold(alpha)), (v, bold(beta))) in E_M,
  0 "otherwise"
)
$

To isolate the topological properties of specific subsystems (or, more intuitively, to "slice" the adjacency tensor), we can apply structural constraints. If we restrict our analysis to interactions occurring strictly within the same layer (disallowing inter-layer edges), the network possesses only diagonal couplings. With this restriction, we can express the relevant subsystem as an intra-layer adjacency tensor with elements $cal(A)_(u v bold(alpha)) = cal(A)_(u v bold(alpha) bold(alpha))$. 

In other words, instead of analyzing the entire complex tensor $cal(A)$ simultaneously, we can fix the layer index $bold(alpha)$ to isolate a specific relationship. This extracts a standard 2D adjacency matrix $A^(bold(alpha))$ representing a single "slice" of the original tensor. This extraction process will be implicitly used in the following sections when describing the macroscopic topological properties of a single entity type and a single relationship.



=== Property Analysis by Scale
<sec-context-scale>

Social networks properties can be classified in three distinct levels of magnification: the micro-scale, the macro-scale, and the meso-scale @wiki-social-network.

- *Micro-scale* analysis focuses on the individual building blocks of the network: a single node and its immediate edges. Metrics at this level include a user's individual degree, their specific centrality, or the clustering coefficient of their immediate friends. 
- *Meso-scale* sits directly between the individual and the global. It focuses on the intermediate, sub-graph structures that emerge when groups of nodes interact collectively. 
- *Macro-scale* analysis zooms all the way out to look at the global properties of the entire system. This includes the overarching scale-free degree distribution or the small-world average path length of the whole platform. Macro-scale metrics treat the network as a single, unified entity.

Because online social networks are very driven by human homophily (see @sec-context-homophily), they do not grow uniformly; they naturally self-organize into meso-scale substructures. The levels that contain the more know metrics and emergent properties are the meso and macro-scale of the network, which usually combine metrics from the micro level to explain the bigger phenomena.


=== Scale-Free Distribution
Let $k$ be the degree of a node $i in V$. Then, the probability $PP$ of a random node to be $k$ follows a power law.

$ PP(k) ~ k^(-gamma) $

where $gamma in [2,3]$, depending of the metric. Equivalently, it can also be expressed as: 

$ PP(k = "deg(i)") = k^(-gamma) $

The value of $gamma$ is calibrated from the data, and will change according to which "slice" of $M$ we pick. That means that both the degree of a user for the followers relationship and the degree of a post with the repost relationship will follow powerlaws, with different $gamma$ in every case.

Networks which follow this specific power law are called scale-free networks @wiki-scale-free-network @easley2010powerlaws.

=== Small-World Phenomena
<sec-context-smallworld>

Let's consider now the graph $G$ induced by the tensor which slice $A = cal(A)_(bold(alpha))$ by users and followers. That is, $G$ is an homogeneous graph with one type of directed edge: users and followers.

Social Networks tend to organize themselves with clusters or friends or known people from real life, with enough links between clusters (_weak links_) which make the distrance between two nodes very small @easley2010smallworld. This is formalized with the small-world network concept @wiki-small-world-network.

*Definition* (Small-World Network): A small-world network is a graph characterized by a high clustering coefficient and a low average path lengths.

There are several ways to measure clustering, but the small-world property refears to local clustering coefficient.

*Definition* (Clustering Coefficient): the local clustering coefficient $C_i$ for a vertex $v_i$ is the proportion of the number of links that could possibly exist within them.

$ C_i = frac(|{e_(j k): v_j, v_k in N_i, e_(j k) in E}|, k_i(k_i-1)) $

The global clustering coefficient associated to the whole graph G is the average of the locals $C = |V|^(-1) sum_(i=1)^(|V|) C_i$

In a Small-World network, the average distance between two random nodes $L$ has to be proportional to the number of nodes of the network as in 

$ L prop log |V| $

Lastly, we will highlight a difference between the types of edges in a small-world network, concepts that explain the famous theory of six-degree-separation. 
1. Strong Ties: friends or family members which form the thigtly couppled clusters on the network.
2. Weak Ties: casual acquintances or work collegues form edges within the clusters, shortcuts between two potentially very different clusters.

The six-degree-separation theory is absolutely based on the existance of weak ties, as allows to move from a familiar homogeneous people to another cluster with very different individuals @centola2007complex.

=== Homophily Dynamics
<sec-context-homophily>

Humans tend to associate themselves with similar people. This concept is known as Homophily. @easley2010contexts

*Definition* (Homophily): homophily (or assortativity) is the core sociological principle wherein human actors preferentially attach to others who possess similar attributes. @wiki-assortativity

Homophily will be split for categorization purposes acording to the slices of $M$ which can be computed.
- Structural similarity: Just users and follows: the only similitude applicable is the degree of the nodes. In this context homophily can directly be interpreted as "well-connected users should follow other very well-connected users". This can be measured in different ways
- Categorical attributes: if the multilayer network contains plains of categorical information about a node ---such as age, nationality, gender, location, political affiliation--- they can be used to compute homophily with a meaning regaring as the user nature; it can be interpreted as "similar users will be connected to also similar users"
- Semantic Similarity: we could consider similar users regarding the content of the posts the user post and similarity of the users post content with other users. This could be interpreted as "a user follows users with similar output content and interest as himself", which could be used to explain content related phenomena.


=== Structural Holes
<sec-context-properties-holes>

Apart from the clustering from the small-world effect (see @sec-context-smallworld) which defines the network as a merge of clusters with weak ties between some of them, the empty topological spaces between these dense communities are equally vital to the analysis of information flow. 

Structural holes refer to the explicit absence of ties between two alters who are both independently connected to an ego (Burt et al @burt1992structural). These structural deficits act as absolute insulators in network information flows, preventing redundant circulation.

The severity of structural holes is quantified mathematically by the network constraint index $C_i$. This index measures the extent to which an ego's network time and social capital are concentrated in a single, highly redundant cluster. The dyadic constraint $c_(i j)$ that a specific contact $j$ exerts on node $i$ is calculated by integrating both the direct investments and the indirect dependencies flowing through mutual third-party contacts $q$.

//TODO: no crec que faci falta, però l'artícle té la formula. Just després dic que no es pot calcular perque computacionalment és molt costosa.

A high constraint score severely limits an actor's access to heterogeneous information, trapping the ego in an echo chamber. Conversely, a low constraint score signifies a radial, spanning network topology crossing numerous structural holes, allowing the actor to exploit non-redundant information cascades.

The obtention of $C_i$ is computationally very expensive, and its an active topic on data mining and computer science @lou2013mining.

=== Community Structure 
<sec-context-properties-community>

The intense, localized density inherent in social networks implies that graphs are not uniformly clustered. Instead, they exhibit complex meso-scale (see @sec-context-scale) structures that sit between microscopic node interactions and macroscopic network properties, being the community structure the most frequently analyzed meso-scale structure.

*Definition* (Community): a community (or module) is defined as a subgraph exhibiting dense internal connection and sparse external connections.

In massive online social networks, these frequently manifest as core-periphery (CP) structures, which partition the network into a densely interconnected "core" and a sparsely connected "periphery" that relies on the core for global reach.

The analysis of those communities is performed by an statistical analysis, the Stochastic Block Model (SBM). SBM assigns a latent group membership to each node and defines the probability of an edge existing between node $i$ and node $j$ strictly based on their respective group assignments @karrer2011stochastic.

=== Properties Classification by Origin

To consolidate the theoretical framework presented in the preceding sections, the metrics and emergent phenomena of social networks can be fundamentally categorized by their reliance on the underlying graph topology versus their dependence on external, non-topological attributes @wiki-social-network.

The vast majority of standard network properties are strictly topological; they are derived exclusively from the structural arrangement of nodes and edges within the adjacency tensor, requiring no additional user metadata. At the micro-scale, this encompasses a node's degree and local clustering coefficient, as well as the identification of structural holes via the constraint index. Moving to the meso-scale, community structures and core-periphery modules are delineated purely through the comparative density of internal and external edge formations. At the macro-scale, overarching phenomena such as the scale-free degree distribution and small-world properties—characterized by global clustering and logarithmic average path lengths—are entirely emergent from the global architectural topology. Furthermore, structural homophily falls into this category, as it describes preferential attachment based solely on network equivalences, such as degree centrality, rather than personal traits.

Conversely, the primary metric that cannot be explained by topology alone is homophily. While structural homophily remains strictly graph-dependent, understanding the human dynamics behind edge formation requires supplementary, non-topological data integrated into the multilayer model. Specifically, categorical homophily relies on external metadata, such as user demographics or geographic location, while semantic homophily necessitates a qualitative analysis of user-generated content and shared interests. Ultimately, while a network's foundational architecture is topological, contextualizing why these specific connections form relies entirely on these non-topological dimensions.

== Information Diffusion Models
<sec-context-diffusionmodels>

Once that a given topology of a social network is defined and we know which properties it has (see @sec-context-topologies), we can address the main point of this work: information diffusion, or how content propagates through a social network. 

*Definition* (Information Diffusion): Information diffusion refers to the process of spreading information through a network, whether it is desired or not @nettleton2013diffusion. 

And what information diffusion tries to model are the information cascades the content produces when traversing the network topology. The form of this cascades is what inequivocally defines the social network 


Traditionally, diffusion models are classified into three distinct mathematical paradigms based on their underlying mechanical rules: epidemic models driven by continuous global rates, cascading models driven by independent stochastic probabilities, and threshold models driven by cumulative fractional influence @singh2026survey.


=== Epidemic Models
<sec-context-diffusion-epidemic>

Epidemic models focus on the macroscopic diffusion of information, and they are primarly modeled using classic compartmental models adapted from epidemiology. Despite lots of flavours for epidemic models being available (SIR, SIS, SIRS and Competitive Influence Diffusion), this section explains the SIR model to be able to properly contextualize them in the social networks field.


An individual can be in three states
+ Susceptible (S): can be infected by the virus (content).
+ Infectious (I): are actively transmitting the virus to non infected nor recovered neighbors.
+ Recovered (R): have gained immunity and cannot contract the infection again.

And the individual must go through them in the following specific order:

$ S --> I --> R $

Now, if we aknowledge that all the individuals in the system can be in one of the states, we can define, at a given instant $t$ that $V(t) = S(t) union I(t) union R(t)$ and if we choose to model the amount of individuals of each group, this can be easily written as the following dynamical system:

$ 
frac(d S(t), d t) = - beta S(t) I(t) \
frac(d I(t), d t) = beta S(t) I(t) - gamma I(t) \
frac(d R(t), d t) = gamma I(t)
$

where $beta$ is the contact rate from $S$ to $I$ and $1 / gamma$ the avergae infectious period. $R$ is the critical value, if $R>1$ implies that an epidemic is possible.

This models a single cascade of information, and there are ways to combine epidemiologic models to describe multiple cascades of information.

While this type of models being elegant and computaionally inexpensive compared with the alternatives (and being useful to model news spreading or rumours) @singh2026survey, they are usually not adequate to model diffusion in general in social network due to the cascades produced by the model differing from empirical data. In the article "The structural virality of online diffusion", Goel et al. introduced the concept of Structural Virality, quantified using the Wiener index of cascade trees @goel2016structural. Their analysis of real OSN data demonstrates that the vast majority of massive information cascades are actually incredibly shallow. Instead of spreading via deep contagion across dozens of generations (as SIS or SIRS models generated cascades), most large cascades are driven by massive hubs (e.g., users with millions of followers) broadcasting a single message that primarily propagates only one degree deep. Consequently, traditional epidemic models fail to accurately capture microblogging dynamics.

The two other alternatives covered in the next sections reject the differential equations (which can be described as a macroscropic description) and embrace the discrete event mechanic (which can be described as microscropic approaches), where the OSNs are dirven by discrete individual user decisions to model interactions chronologically.

=== Cascade Models
<sec-context-diffusion-cascade>

The Cascade model is an stochastic process that describes the flow of information with discrete events at a time $t$. It makes has the following rules:
+ States: at a time $t$ a node can be inactive (not spreading the information) or active (spreading the information).
+ Monotonicity: Once a node $v$ becames active, it cannot go back to inactive.
+ One shot: every node can attempt the change of it's neighbors state once per edge.
+ Probability: every edge has a probability $p_(u,v)$ for $u$ to successfully activate $v$.
+ Independence: given a node $u$, multiple attempts to change node $u$ from their neigbours do not affect the probability of $u$ changing state.

The process then goes as follows. For each active node $v$ at step $t$, it attempts to change state of every inactive neighbors $u$ with probability $p_(u,v)$. If the attempt succeeds, $u$ will be active and transmit the information at time $t+1$. Regardless of the result of that operation, the edge gets discarded from future information spread.

According how the probability is defined, we will have different cascade models. The most simple one, is the _Independent Cascade Model_, where the probability of $v$ activating $u$ at time $t$ $p_u (v)$ is constant, independent of the history of the history process so far. Another characteristic feature of the IC model is its order independence: the final integrated probability of a node being activated remains strictly invariant regardless of the temporal sequence in which its neighbors attempt transmission @zhang2014chapter1, or in other words, what matters is not the order of activations, but the amount of them.

Crucially, regardless of whether the neighbor adopts the information, the original node can never attempt to activate that neighbor with that specific post again. This permanent refractory state perfectly encapsulates a simple contagion (see @sec-context-diffusion-contagions), where a single exposure is entirely sufficient to trigger adoption @centola2007complex.


=== Continuous-Time Independent Cascade Model

While the standard Independent Cascade (IC) model operates in discrete epochs, real-world information and disease propagation occurs continuously over time [cite: 7] (Accessed: 2026-04-29). In many scenarios, such as blog networks or viral marketing, we observe the exact timestamps when a node adopts a piece of information, necessitating a shift from discrete steps to a continuous temporal dynamic [cite: 1358, 1359] (Accessed: 2026-04-29).

The Continuous-Time Independent Cascade model preserves the core assumption of independent transmission across edges but replaces fixed step-based probabilities with a time-dependent transmission likelihood [cite: 1361, 1383] (Accessed: 2026-04-29). Rather than assuming a neighbor attempts activation in the immediate next time step, the continuous formulation models the *incubation time*, which is the delay between a node $j$ becoming infected at time $t_j$ and subsequently infecting an uninfected neighbor $i$ at time $t_i > t_j$ [cite: 154, 1421, 1422] (Accessed: 2026-04-29).

This temporal dynamic is mathematically expressed through survival analysis [cite: 1434] (Accessed: 2026-04-29). For every directed edge from $j$ to $i$, we define a pairwise transmission rate $alpha_{j,i}$ [cite: 1420] (Accessed: 2026-04-29). The transmission likelihood $f(t_i | t_j; alpha_{j,i})$ is governed by two primary functions [cite: 1430] (Accessed: 2026-04-29):

- *Survival Function* $S(t_i | t_j; alpha_{j,i})$: The probability that node $i$ is not infected by node $j$ by time $t_i$ [cite: 1436] (Accessed: 2026-04-29).
- *Hazard Function* $H(t_i | t_j; alpha_{j,i})$: The instantaneous infection rate of the edge [cite: 1438] (Accessed: 2026-04-29).

The total conditional likelihood of transmission is computed using both the survival and hazard functions [cite: 1438, 1465] (Accessed: 2026-04-29). Because each edge operates independently, the probability that a node survives up to time $T$ without being infected by any of its already-infected neighbors is the product of the individual survival functions across all infected nodes targeting it [cite: 1441, 1442] (Accessed: 2026-04-29).

By varying the parametric model of the transmission likelihood, the continuous-time IC model can capture drastically different propagation behaviors [cite: 1423, 1716] (Accessed: 2026-04-29):

- *Exponential Model*: A monotonic model that assumes a constant hazard rate, well-suited for standard memoryless diffusion [cite: 1427, 1430] (Accessed: 2026-04-29).
- *Power-Law Model*: Captures infections with "long-tails," where the likelihood of transmission decays heavily over time but can still trigger late adoptions [cite: 1432, 1430] (Accessed: 2026-04-29).
- *Rayleigh Model*: A non-monotonic model where the infection likelihood rises to a peak and then drops extremely rapidly, often used to model fads [cite: 1432, 1433] (Accessed: 2026-04-29).

By allowing transmission at different rates $alpha_{j,i}$ across different edges, this continuous model can uncover the temporally heterogeneous interactions within a network using only the observed time-stamps of the cascades [cite: 1363, 1396] (Accessed: 2026-04-29).

=== Linear Threshold Model
#todo[If we drop the content aware part, it means that there is no need to explain this but to just flex]

The Linear Threshold model (LT) assumes that information spreading requires multiple expositions to the same content before activating the user. We call this behaviour complex contagion @wiki-complex-contagion.

*Definition* (Complex Contagion): is the phenomenon in which multiple sources to an innovation are required before an individual adopts the change of behaviour @centola2007complex.

The mechanisms both in Epidemics (see section @sec-context-diffusion-epidemic) and in cascade (see @sec-context-diffusion-cascade) models are classified as simple contagion due to just one exposition is enough to change the node state from inactive to active. This is used to model shifts in belief or costly sociopolitical behaviours, as opposite of simple, which could be more resembling a meme or fake news spreading. @centola2007complex @meng2025spreading. In contrast, LT modelizes the multiple exposures required of a complex contagion.

The (LT) model focuses on modeling the activation according to the neighbours of the user neighborhood, continual exposure to certain elements. The assumptions this model runs under are:
- Every node $i$ has a threshold $theta_i in [0, 1]$, their inherent resistance to change state. 
- Every directed edge from a neighbor $j$ to node $i$ is assigned a non-negative weight $w_(j i)$, the proportional degree of influence $j$ exerts on $i$ @zhang2014chapter1. 
- A node $i$ will only become active if the sum of the influence weights from its currently active neighbors meets or exceeds its personal threshold:

$ sum_(j in cal(N)(i)) w_(j i) >= theta_i $
 
Because it strictly requires simultaneous or accumulated exposures, the LT model very accurately meso-scale properties of a social network: information spreading process easily saturates dense communities (clusters of the network, see @sec-context-properties-communities e.g. forming echo chambers) but frequently fails to cross structural holes (see @sec-context-properites-holes), as the information struggles to propagate through weak ties between communities due to it's inherent nature @centola2007complex.


== Content Diffusion Mechanics

While the traditional information diffusion covered until now (see @sec-context-diffusionmodels) models the content as a mechanic, which knowingly heavily simplifies main factors on content propagation, such as the actual content of the post or the transmission mechanic itself, which does not mimics human nature enough as a known trade off to model the information. In reality, OSN are driven by human psychology, introducing major friction points to pure structural diffusion: finite attention and cumulative exposure requirements. This section covers the main mechanics and known human behaviour that do not get modeled into the traditional information diffusion methods.

=== Non-Agnostic Information Diffusion
#todo[Explain why the content here is what really matters, and what opens up a hole lot of stuff. Need to look up papers for this]

// hey this is an actual good draft, but maybe nothing more!
To accurately capture these advanced dynamics, modeling the network strictly through its topology and mechanical pipes is insufficient. A simulation must become reactive to the semantics of the content itself.

Implementing attention competition, homophily, and complex contagion requires giving posts a measurable identity. This necessitates transitioning to a semantic simulation where posts and user preferences are represented as continuous vectors (embeddings) in a latent multidimensional space. Only by measuring the geometric distance between a user's preference vector and a post's semantic vector can a model dynamically adjust interaction thresholds, simulate content fatigue, and accurately replicate the competitive attention economy observed in real platforms.


=== Simple and Complex Contagion 
<sec-context-diffusion-contagions>

#todo[Actually explain that in a real social network both simple and complex mechanics need to coexist and do not cannibalize themselves]

This has t

Furthermore, while the standard Independent Cascade model strictly dictates a "single-chance" refractory state suited for simple contagions, the diffusion of opinions or rumors often operates as a complex contagion. Meng et al. explicitly quantify this spreading dynamic, demonstrating that the probability of a user adopting or retweeting information scales dynamically with the number of times they are exposed to it by different neighbors @meng2025spreading (Accessed April 28, 2026). A user might ignore a topic the first time it appears in their feed, but multiple exposures from disjoint clusters in their network will significantly lower their threshold for interaction.


=== The Attention Economy

In a microblogging platform, a user's chronological timeline is a highly competitive ecosystem. Users possess finite cognitive bandwidth and temporal limits per session. The probability of a user interacting with (or liking) a specific post is not an isolated independent variable; it is heavily dependent on the competition from other content presented simultaneously within their feed @hirakura2023method. As a timeline fills, posts must compete for visibility, meaning that the diffusion of one cascade actively cannibalizes the potential diffusion of another. 

== Description of Microblogging Social Media 
<sec-context-definition>

Despite social networks being a relatively new addition to normal modern life, they have fundamentally changed how information is consumed and spread in the modern age. To adequately understand the aims of this project, some definitions and context regarding social networks are provided.

*Definition:* A *Microblogging Social Network* (e.g., Twitter/$bb(X)$ or Bluesky) is a specialized type of social network where users publish and exchange short-form content. This is enforced by a limit on the maximum number of characters per entry, known as microblogs or posts. A post, while traditionally text-based, can also include up to four multimedia elements.

[TODO: buscar sources per aquestes dues definitions]

To model a microblogging social network, it is imperative to understand and describe all the features that compose the application. Specifically, the following description is of the microblogging platform Bluesky (TODO: Cite bluesky), as it is the platform chosen to simulate (see @sec-context-bluesky).

The post is the fundamental building block of Bluesky, acting as the primary vehicle for the information that will be spread. A user sees these posts in a feed, which is a sorted collection of posts categorized by specific rules. For the feed to contain posts, we must explain the other fundamental relationship in a social network: the follow.

[TODO: Picture of the feed of Bluesky]

A user can follow other users, allowing the content of those users to appear to the "follower". That is, if user $u$ follows user $v$, all the posts that user $v$ creates will appear in the feed of user $u$. This is one mechanism for a user's feed to populate with posts. The other way for content to travel is how a user interacts with a post once it appears in their feed, this being the main source of post appearance in the user feed. Conversely, there are some actions a user can perform over other users which limit the posts that can appear on a user's feed: a user can block (preventing both users from seeing each other's activity) or mute (activity of a muted user is not shown to the user) another user, which will alter the posts that can appear on the timeline of the user who performed that action.

A user can meaningfully act on a post in four different ways:
- *Repost:* If user $u$ reposts a post in their feed, that post will subsequently appear in the feeds of user $u$'s followers.
- *Like:* If a user likes a post, it won't show in their followers' feeds, but it will be stored in the user's profile (discussed later).
- *Quote:* This is a direct answer attached to a post. It is shown together with the original post in the followers' timeline, acting as commentary on the original content.
- *Reply:* This is a direct response to an original post. The reply will be shown in the followers' feed and clearly marked as a reply, though the original post usually won't be shown alongside it unless the follower also follows the original author.

[TODO: Show pictures of how a quote is shown, how a reply is shown]

Lastly, every user has a profile, which is customizable with a profile picture, a description, and a background image. The profile acts as a public ledger containing all posts the user has written or reposted, all replies made to other posts, and all likes given.

Bluesky, as an open platform, allows for user-made feeds with diverse rules and categories dictating which posts are shown. These include feeds focused on highly specific topics (such as technology, local events, or art). The two primary feeds provided by default are the _Discover_ feed and the _Following_ feed.

The Discover feed uses a recommendation algorithm to suggest the most relevant posts to a user based on their tastes and the network of people they follow. This criterion usually excludes the temporal component of when posts were created or reposted, focusing instead on content similarity and engagement.

The Following feed is a traditional social network timeline. It displays creations and reposts exclusively from the accounts the user follows, showing them in strict reverse-chronological order, from newest to oldest.


#todo[Picture of the tabs showing the different feeds the Bluesky app has]


== Why Bluesky?
<sec-context-bluesky>

TBD: Bluesky is open, talk about ATProto, and talk about how the firehose works to obtain the data

Bluesky is ...

Say also which disadvantages we have against using twitter.

== Problem Description

The problems with social networks are bla bla and I did all of this to try to solve them.
