#import "utils.typ": *

This section introduces context to the project: what a microblogging social network is, how the phenomena of information diffusion has been studied, and why Bluesky is the chosen social network to simulate.

== Background

This section aims to provide with basic definitions and understanding of the Social Network subfield.

#def(name: "Network")[a network is a special case of a graph, where the vertices, edges or both, possess attributes @wiki-network-theory.]

#def(name: "Social Network")[a Social Network is a social structure consisting of a set of social actors (such as individuals or organizations) and social interactions between actors @wiki-social-network. They are studied by the SNA (Social Network Analysis field) which examines the structure of the relationships within those entities.]

According to the definition then, any network that models any relationship between humans, groups of humans or human-made-organizations is classified as a social network.

Online social newtorks (OSN) are a specific case of Social Networks, where the entities are users and posts, and the relationships are follow, followee, mute, block, create, repost, like, comment, quote, reply...

A social network is also considered a complex system. To describe the behaviour of this fact, ---and given that the definition of complex system is still debated up to date--- the Edgars Morin definition of complex system is used @choudhary2023impact as it showcases the complexity of the elements adequately.

#def(name: "Complex System")[A complex system is defined as the system where there is a bidirectional non-separability between the identities of the parts and the identity of the whole.]

The unique identities of the parts (users and their individual posts) combine to create the overarching identity and emergent behaviors of the platform. In turn, this macro-structure dictates how information spreads and what content is amplified, which fundamentally alters the user's worldview, online identity, and subsequent behavior within the system.

To define and study content diffusion, the two most important factors are the topology of the actual network (see @sec-sota-topologies) and the chosen diffusion model (see @sec-sota-diffusionmodels).

== Social Network Topologies
<sec-sota-topologies>

This section aims to characterize the topology of social networks according to their main factors. To explain the features of the topology, we must introduce first a way to model the heterogeneity and multiple edge types of a Social Network rigorously.

=== Multilayer Network

While a social network has been modeled traditionally as a graph, it's a very narrow model to reason about. Kivela et al @kivela2014multilayer introduces the concept of Multilayer Network, which perfectly encapsulates what a complex social network is:

#todo[Think how (and if) a figure explaing this could work]
==== Definition (Multilayer Network @kivela2014multilayer)

A multilayer network is a quadruplet $M = (V_M, E_M, V, L)$, where:
- $V$ is the set of all nodes in the system
- $L = {L_a}_(a=1)^d$ is a sequence of sets of possible layers, where $d$ represents the number of distinct aspects (dimensions) of the network
- $V_M subset.eq V times product_(a=1)^d L_a$ is the set of node-layer tuples, representing exactly which node exists in which layer
- $E_M subset.eq V_M times V_M$ is the multilayer edge set connecting these tuples

In an online social network environment, we can define two primary aspects ($d=2$): node types (users, posts, ...) and interaction types (follows, likes, reposts...). The point of this definition is that $G_M = (V_M, E_M)$ is a graph, so a Multilayer Network can be interpreted as a graph with specific labelings over the nodes and edges.

We can also partition the edges into _intra-layer edges_ $E_A = {((u, bold(alpha)), (v, bold(beta))) in E_M | bold(alpha) = bold(beta))}$ and the _inter-layer edges_ as $E_C = E_M - E_A$.

The adjacency matrix for a fully interconnected multilayer network can be represented by an order-$2(d+1)$ adjacency tensor $cal(A)$. The tensor elements $cal(A)_(u v bold(alpha) bold(beta))$ have a value of $1$ if there is an edge between node $u$ in layer $bold(alpha)$ and node $v$ in layer $bold(beta)$, and $0$ otherwise.

$
cal(A)_(u v bold(alpha) bold(beta)) = cases(
  1 "if" ((u, bold(alpha)), (v, bold(beta))) in E_M,
  0 "otherwise"
)
$

To isolate the topological properties of specific subsystems (or, more intuitively, to "slice" the adjacency tensor), we can apply structural constraints. If we restrict our analysis to interactions occurring strictly within the same layer (disallowing inter-layer edges), the network possesses only diagonal couplings. With this restriction, we can express the relevant subsystem as an intra-layer adjacency tensor with elements $cal(A)_(u v bold(alpha)) = cal(A)_(u v bold(alpha) bold(beta))$. 

In other words, instead of analyzing the entire complex tensor $cal(A)$ simultaneously, we can fix the layer index $bold(alpha)$ to isolate a specific relationship. This extracts a standard 2D adjacency matrix $A^(bold(alpha))$ representing a single "slice" of the original tensor. This extraction process will be implicitly used in the following sections when describing the macroscopic topological properties of a single entity type and a single relationship.

=== Property Analysis by Scale
<sec-sota-topo-scale>

Social networks properties can be classified in three distinct levels of magnification: the micro-scale, the macro-scale, and the meso-scale @wiki-social-network.

- *Micro-scale* analysis focuses on the individual building blocks of the network: a single node and its immediate edges. Metrics at this level include a user's individual degree, their specific centrality.  
- *Meso-scale* sits directly between the individual and the global. It focuses on the intermediate, sub-graph structures that emerge when groups of nodes interact collectively. All the homophily based process affect
- *Macro-scale* analysis of the global properties of the entire system. This includes the overarching scale-free degree distribution or the small-world average path length of the whole platform, such as structural virality. Macro-scale metrics treat the network as a single, unified entity.

Because the formation of online social networks are very driven by human homophily (see @sec-sota-topo-homophily), they do not grow uniformly; they naturally self-organize into meso-scale substructures. The levels that contain the more know metrics and emergent properties rellevant to societal metrics ---an therefore rellevant for our case study--- are the meso and macro-scale of the network.

=== Scale-Free Distribution
<sec-sota-topo-scalefree>

Let $k$ be the degree of a node $i in V$. Then, the probability $PP$ of a random node to be $k$ follows a power law.

$ PP(k = "deg(i)") = k^(-gamma) $

where $gamma in [2,3]$, depending of the metric.

The value of $gamma$ is obtained from the actual data, and will change according to which "slice" of $M$ we pick. That means that both the degree of a user for the followers relationship and the degree of a post with the repost relationship will follow powerlaws, with different $gamma$ in every case.

Networks which follow this specific power law are called scale-free networks @wiki-scale-free-network @easley2010powerlaws.

Specifically, in the multilayer network, both the entity user with relationship follower and the entity post with the total number of reposts are going to follow power laws with different gamma values.

=== Small-World Phenomena
<sec-sota-topo-smallworld>

Let's consider now the graph $G$ induced by the tensor which slice $A = cal(A)_(bold(alpha))$ by users and followers. That is, $G$ is an homogeneous graph with one type of directed edge: users and followers.

Social Networks tend to organize themselves with clusters or friends or known people, with enough links between clusters (_weak links_) which make the distance between two nodes very small @easley2010smallworld. 

There are several ways to measure clustering, as for example the local clustering coefficient.

#def(name: "Clustering Coefficient")[the local clustering coefficient $C_i$ for a vertex $v_i$ is the proportion of the number of links that could possibly exist within them.]

$ C_i = frac(|{e_(j k): v_j, v_k in N_i, e_(j k) in E}|, k_i (k_i-1)) $

where $N_i$ is the neighborhood of the vertex $v_i$. The global clustering coefficient associated to the whole graph $G$ is the average of the locals $C = |V|^(-1) sum_(i=1)^(|V|) C_i$

Now, the small-world concept can be properly defined. @wiki-small-world-network.

#def(name: "Small-World Network")[A small-world network is a graph characterized by a high clustering coefficient and a low average path length.]

In a Small-World network, the average distance $L$ between two random nodes has to be proportional to the number of nodes of the network as in 

$ L prop log |V| $

In a small-world network, the edges can be classified into two types, according if they are edge inter-clustering or intra-clustering:
1. Strong Ties: edges that connect people with simililarity or strong connections, such as local communities or familiy members.
2. Weak Ties: casual acquaintances or work collogues form edges within the clusters, shortcuts between two potentially very different clusters.

The six-degree-separation theory is explained by this differentation. The theory states that any two individuals in a social network are, at most, separated by six other individuals. This fact is consequence of the existence of weak ties, as allows to move from a familiar homogeneous people to another cluster with very different individuals @centola2007complex.

=== Homophily Dynamics
<sec-sota-topo-homophily>

Humans tend to associate themselves with similar people, and this factor undelies all the connections within a social network. @easley2010contexts

#def(name: "Homophily")[homophily (or assortativity) is the core sociological principle wherein human actors preferentially attach to others who possess similar attributes. @wiki-assortativity]

Homophily can be understood at different levels. At a structural network level can be interpreted as a user will generally follow users with a similar amount of followers, such as a popularity index, which stems from the topology of the network. 

There are other factors much more affected by homophily, such as user attributes ---a user will follow other users with similar age, gender, political affiliation--- and its the main explanation of same interests following, as in users who like the same topics, will tend to aggregate together and produce similar content about those topics. For more information on, see @sec-future.

=== Community Structure 
<sec-sota-topo-community>

The intense, localized density inherent in social networks implies that graphs are not uniformly clustered. Instead, they exhibit complex meso-scale (see @sec-sota-topo-scale) structures that sit between microscopic node interactions and macroscopic network properties, being the community structure the most frequently analyzed meso-scale structure.

#def(name: "Community")[a community (or module) is defined as a subgraph exhibiting dense internal connection and sparse external connections.]

In massive online social networks, these frequently manifest as core-periphery structures, which partition the network into a densely interconnected "core" and a sparsely connected "periphery" that relies on the core for global reach.

The analysis of those communities is performed by an statistical analysis, the Stochastic Block Model (SBM). SBM assigns a latent group membership to each node and defines the probability of an edge existing between node $i$ and node $j$ strictly based on their respective group assignments @karrer2011stochastic.

=== Properties Classification by Origin

To consolidate the theoretical framework presented in the preceding sections, the metrics and emergent phenomena of social networks can be fundamentally categorized by their reliance on the underlying graph topology versus their dependence on external, non-topological attributes @wiki-social-network.

The vast majority of standard network properties are strictly topological; they are derived exclusively from the structural arrangement of nodes and edges within the adjacency tensor, requiring no additional user metadata. At the micro-scale, this encompasses a node's degree and local clustering coefficient, as well as the identification of structural holes via the constraint index. Moving to the meso-scale, community structures and core-periphery modules are delineated purely through the comparative density of internal and external edge formations. At the macro-scale, overarching phenomena such as the scale-free degree distribution and small-world properties—characterized by global clustering and logarithmic average path lengths—are entirely emergent from the global architectural topology. Furthermore, structural homophily falls into this category, as it describes preferential attachment based solely on network equivalences, such as degree centrality, rather than personal traits.

Conversely, the primary metric that cannot be explained by topology alone is homophily. While structural homophily remains strictly graph-dependent, understanding the human dynamics behind edge formation requires supplementary, non-topological data integrated into the multilayer model. Specifically, categorical homophily relies on external metadata, such as user demographics or geographic location, while semantic homophily necessitates a qualitative analysis of user-generated content and shared interests. Ultimately, while a network's foundational architecture is topological, contextualizing why these specific connections form relies entirely on these non-topological dimensions.

== Information Diffusion Models
<sec-sota-diffusionmodels>

Once that a given topology of a social network is defined and we know which properties it has (see @sec-sota-topologies), we can address the main point of this work: information diffusion, or how content propagates through a social network. 

#def(name: "Information Diffusion")[Information diffusion refers to the process of spreading information through a network, whether it is desired or not @nettleton2013diffusion.]

And what information diffusion tries to model are the information cascades the content produces when traversing the network topology. The form of this cascades is what inequivocally defines the social network 

#def(name: "Information Cascade")[An information cascade is a phenomena in which a number of people make the same decision in a sequential fashion. It can be modeled as a temporal graph.] @duan2009informational

Specifically, an information cascade can be defined as a graph, where the nodes are the actors (users) involved in the propagation, and the edges are the relationships of those users. A new level is added to the graph then the action of information propagation (_e.g_ a repost) happens at a certain time $t$. Despite most of them could be considered trees, some of the cascades may contain cycles.

#todo[Add a figure here with cascade types (broadcast, normal cascade, something with a cylce.)]

Traditionally, diffusion models are classified into three distinct mathematical paradigms based on their underlying mechanical rules: epidemic models driven by continuous global rates, cascading models driven by independent stochastic probabilities, and threshold models driven by cumulative fractional influence @singh2026survey. The latter is not used in the model of the work, so it's introduced as part of a proposed new architecture (see @sec-future).

=== Epidemic Models
<sec-sota-diffusion-epidemic>

Epidemic models focus on the macroscopic diffusion of information, and they are primary modeled using classic compartmental models adapted from epidemiology. Despite lots of flavours for epidemic models being available (SIR, SIS, SIRS and Competitive Influence Diffusion), this section explains the SIR model to be able to properly contextualize them in the social networks field.

An individual can be in three states
+ Susceptible (S): can be infected by the virus.
+ Infectious (I): are actively transmitting the virus to non infected nor recovered neighbors.
+ Recovered (R): have gained immunity and cannot contract the infection again.

And the individual must go through them in the following specific order:

$ S --> I --> R $

Now, if we acknowledge that all the individuals in the system can be in one of the states, we can define, at a given instant $t$ that $V(t) = S(t) union I(t) union R(t)$ and if we choose to model the amount of individuals of each group, this can be easily written as the following dynamical system:

$ 
frac(d S(t), d t) = - beta S(t) I(t) \
frac(d I(t), d t) = beta S(t) I(t) - gamma I(t) \
frac(d R(t), d t) = gamma I(t)
$

where $beta$ is the contact rate from $S$ to $I$ and $1 / gamma$ the avergae infectious period. $R$ is the critical value, if $R>1$ implies that an epidemic is possible.

This models a single cascade of information, and there are ways to combine epidemiologic models to describe multiple cascades of information.

While this type of models being elegant and computationally inexpensive compared with the alternatives (and being useful to model news spreading or rumours) @singh2026survey, they are usually not adequate to model diffusion in general in social network due to the cascades produced by the model differing from empirical data. In the article "The structural virality of online diffusion", Goel et al. introduced the concept of Structural Virality, quantified using the Wiener index of cascade trees @goel2016structural. Their analysis of real OSN data demonstrates that the vast majority of massive information cascades are actually incredibly shallow. Instead of spreading via deep contagion across dozens of generations (as SIS or SIRS models generated cascades), most large cascades are driven by massive hubs (e.g., users with millions of followers) broadcasting a single message that primarily propagates only one degree deep. Consequently, traditional epidemic models fail to accurately capture microblogging dynamics.

The two other alternatives covered in the next sections reject the differential equations (which can be described as a macroscropic description) and embrace the discrete event mechanic (which can be described as microscropic approaches), where the OSNs are dirven by discrete individual user decisions to model interactions chronologically.

=== Cascade Models
<sec-sota-diffusion-cascade>

The Cascade model is an stochastic process that describes the flow of information with discrete events at a time $t$. It has the following rules:
+ States: at a time $t$ a node can be inactive (not spreading the information) or active (spreading the information).
+ Monotonicity: Once a node $v$ activates, it cannot go back to inactive.
+ One shot: every node can attempt the change of it's neighbors state once per edge.
+ Probability: every edge has a probability $p_(u,v)$ for $u$ to successfully activate $v$.
+ Independence: given a node $u$, multiple attempts to change node $u$ from their neigbours do not affect the probability of $u$ changing state.

The process then goes as follows: for every active node $v$ at step $t$, it attempts to change state of every inactive neighbors $u$ with probability $p_(u,v)$. If the attempt succeeds, $u$ will be active and transmit the information at time $t+1$. Regardless of the result of that operation, the edge gets discarded from future information spread.

According how the probability is defined, we will have different cascade models. The most simple one, is the _Independent Cascade Model_, where the probability of $v$ activating $u$ at time $t$ $p_u (v)$ is constant, independent of the history of the history process so far. Another characteristic feature of the IC model is its order independence: the final integrated probability of a node being activated remains strictly invariant regardless of the temporal sequence in which its neighbors attempt transmission @zhang2014chapter1, or in other words, what matters is not the order of activations, but the amount of them.

Crucially, regardless of whether the neighbor adopts the information, the original node can never attempt to activate that neighbor with that specific post again. This permanent refractory state perfectly encapsulates a simple contagion (see #todo[future work]), where a single exposure is entirely sufficient to trigger adoption @centola2007complex.


=== Continuous-Time Independent Cascade Model
<sec-sota-diffusion-ctic>

While the standard Independent Cascade (IC) model operates in discrete epochs, real-world information and disease propagation occurs continuously over time. In many scenarios we observe the exact timestamps when a node adopts a piece of information, necessitating a shift from discrete steps to a continuous temporal dynamic. @gomezrodriguez2012inferring

The Continuous-Time Independent Cascade model preserves the core assumption of independent transmission across edges but replaces fixed step-based probabilities with a time-dependent transmission likelihood. Rather than assuming a neighbor attempts activation in the immediate next time step, the continuous formulation models the incubation time, which is the delay between a node $j$ becoming infected at time $t_j$ and subsequently infecting an uninfected neighbor $i$ at time $t_i > t_j$. @gomezrodriguez2011uncovering @gomezrodriguez2012inferring

This temporal dynamic is mathematically expressed through survival analysis @gomezrodriguez2011uncovering. For every directed edge from $j$ to $i$, we define a pairwise transmission rate $alpha_{j,i}$. The transmission likelihood $f(t_i | t_j; alpha_{j,i})$ is governed by two primary functions:
- *Survival Function* $S(t_i | t_j; alpha_{j,i})$: The probability that node $i$ is not infected by node $j$ by time $t_i$.
- *Hazard Function* $H(t_i | t_j; alpha_{j,i})$: The instantaneous infection rate of the edge.

The total conditional likelihood of transmission is computed using both the survival and hazard functions [cite: 1438, 1465] (Accessed: 2026-04-29). Because each edge operates independently, the probability that a node survives up to time $T$ without being infected by any of its already infected neighbors is the product of the individual survival functions across all infected nodes targeting it. @gomezrodriguez2011uncovering

By varying the parametric model of the transmission likelihood, the continuous-time IC model can capture drastically different propagation behaviors: @gomezrodriguez2011uncovering
- *Exponential Model*: A monotonic model that assumes a constant hazard rate, well-suited for standard memoryless diffusion. 
- *Power-Law Model*: Captures infections with "long-tails," where the likelihood of transmission decays heavily over time but can still trigger late adoptions.
- *Rayleigh Model*: A non-monotonic model where the infection likelihood rises to a peak and then drops extremely rapidly, often used to model fads.

By allowing transmission at different rates $alpha_{j,i}$ across different edges, this continuous model can uncover the temporally heterogeneous interactions within a network using only the observed time-stamps of the cascades.@gomezrodriguez2011uncovering

#comment[There is much more content here (simplex vs complex contagion, recent behaviour change findings in social network, attention competitive behaviour on a timeline) which has been moved as background in the Future Work section. I can add it back here, but i feel the Chekhov applies: if I talk about complex contagion, the read will expect my model to conatin it, which it does not in the end.
]

== Description of Microblogging Social Media 
<sec-sota-description>

#comment[I don't totally see this section here. Like, it feels weird in a way to talk about Bluesky and The description in the State of the Art section. But I also do not see an easy generalizable solution.]

Despite social networks being a relatively new addition to normal modern life, they have fundamentally changed how information is consumed and spread in the modern age. To adequately understand the aims of this project, some definitions and context regarding social networks are provided.

==== Definition

A *Microblogging Social Network* (e.g., Twitter/$bb(X)$ or Bluesky) is a specialized type of social network where users publish and exchange short-form content. This is enforced by a limit on the maximum number of characters per entry, known as microblogs or posts. A post, while traditionally text-based, can also include up to four multimedia elements.

#comment[The upper definitons are mine, should i search a definition of this? Is there a good source or am I overthinking this?]

To model a microblogging social network, it is imperative to understand and describe all the features that compose the application. Specifically, the following description is of the microblogging platform Bluesky @wiki-bluesky, as it is the platform chosen to simulate (see @sec-sota-bluesky).

The post is the fundamental building block of Bluesky, acting as the primary vehicle for the information that will be spread. A user sees these posts in a feed, which is a sorted collection of posts categorized by specific rules. For the feed to contain posts, we must explain the other fundamental relationship in a social network: the follow.

#todo[picture of the bluesky feed]

A user can follow other users, allowing the content of those users to appear to the "follower". That is, if user $u$ follows user $v$, all the posts that user $v$ creates will appear in the feed of user $u$. This is one mechanism for a user's feed to populate with posts. The other way for content to travel is how a user interacts with a post once it appears in their feed, this being the main source of post appearance in the user feed. Conversely, there are some actions a user can perform over other users which limit the posts that can appear on a user's feed: a user can block (preventing both users from seeing each other's activity) or mute (activity of a muted user is not shown to the user) another user, which will alter the posts that can appear on the timeline of the user who performed that action.


A user can meaningfully act on a post in four different ways:
- *Like:* If a user likes a post, it won't show in their followers' feeds, but it will be stored in the user's profile (discussed later).
- *Quote:* This is a direct answer attached to a post. It is shown together with the original post in the followers' timeline, acting as commentary on the original content.
- *Reply:* This is a direct response to an original post. The reply will be shown in the followers' feed and clearly marked as a reply, though the original post usually won't be shown alongside it unless the follower also follows the original author.
- *Repost:* If user $u$ reposts a post in their feed, that post will subsequently appear in the feeds of user $u$'s followers. 

#todo[pictures of a quote, a reply and a repost]

Among these actions, the repost is the primary engine of information diffusion. 

Lastly, every user has a profile, which is customizable with a profile picture, a description, and a background image. The profile acts as a public ledger containing all posts the user has written or reposted, all replies made to other posts, and all likes given.

Bluesky, as an open platform, allows for user-made feeds with diverse rules and categories dictating which posts are shown. These include feeds focused on highly specific topics (such as technology, local events, or art). The two primary feeds provided by default are the _Discover_ feed and the _Following_ feed.

The Discover feed uses a recommendation algorithm to suggest the most relevant posts to a user based on their tastes and the network of people they follow. This criterion usually excludes the temporal component of when posts were created or reposted, focusing instead on content similarity and engagement.

The Following feed is a traditional social network timeline. It displays creations and reposts exclusively from the accounts the user follows, showing them in strict reverse-chronological order, from newest to oldest. 

#todo[Picture of the tabs showing the different feeds the Bluesky app has]

#comment[
  Here I need to add this two citations @hodas2014simple for the queue and simple contagion and @pozzana2017epidemic for the activity driven idea network, but this two paragraphs feel very not natural at the end of this section.

As an alternative, I've added the sections 4.1.1 and 4.2.2, which explain the same without being based on this part of information. If you could give me feedback on which makes more sense would be nice :)
]

The literature usually approaches this strict chronological structure through the lens of attention economy @hirakura2023method, which is governed by queue-based visibility. Users possess finite cognitive bandwidth and temporal limits per session, and because the feed acts as a LIFO (Last In, First Out) queue, posts must constantly compete for screen space @hodas2014simple. As new creations and reposts arrive, older posts are pushed down the queue, causing their visibility to decay rapidly. Therefore, the probability of a user interacting with a cascade is not a static variable; it is heavily dependent on the competition from other content presented simultaneously, meaning the diffusion of one cascade actively cannibalizes another @hirakura2023method.

Furthermore, because users interact with the platform in discrete, time-limited sessions—logging on, scrolling, posting, and logging off—they cannot be modeled simply as passive consumers waiting to be infected . To accurately simulate this environment, the literature utilizes Activity-Driven Dynamics @pozzana2017epidemic. In this framework, each user possesses an intrinsic activity rate that dictates how often they initiate a session to generate new original posts and consume the content that was generated when there were not on the platform. The Activity-Driven dynamic in an OSN is essentially allowing users to be offline or online, resembling the usage patters of real users, or at least a reasonable approach. When a user is offline, it does not see content, but this allows other content on the platform to be generated by other users, so when the user comes back, will have new content derived from the information diffusion mechanics. 

== Why Bluesky? 
<sec-sota-bluesky>

Bluesky @wiki-bluesky is a microblogging social network, built on the Authenticated Transfer Protocol, ATP for short @atproto-overview. 

The ATP is a protocol and set of open standards for decentralized publishing and distribution of self-authenticating data within the social web. Adhering to the protocol separates the content produced by the user on a social media platform from the infrastructure of the social media platform, essentially defining a format for the characteristics of the data to be usable in any social media app that implements the ATP protocol. In other words: by establishing an existing format defining all the characteristics of how data should be structured and which data should be publicly available, the implementation of the application Bluesky (the program that runs on the browser or phone) is decoupled from where and how the data the user creates is stored. 

The relevant side effect of this design decision is that the server that stores the Bluesky data, the firehose @atproto-repo, is open and all the data that is sent and received can be accessed and stored. Data for this study was collected and provided for analysis by the CS^2 research group at Universtiy of Graz (see @sec-data). 
#comment[Idk how to cite the lab, I should keep the reference to lab here, cite them any other way or how to do it]

Alternative microblogging platforms to X (formerly Twitter), such as Bluesky and Mastodon @mastodon-social-network, remain less widely adopted than mainstream platforms, despite their steady growth #todo[Cite a recent statistics database or tech report detailing active user counts to support the growth claim or change the sentence].

A significant challenge in contemporary social media research is the increasing privatization of user data by major platforms. Proprietary metrics with high commercial value, such as session length, content views, and granular engagement statistics, are rarely published or made accessible to independent researchers. This trend toward restricted data access limits academic inquiry and the broader understanding of social media ecosystems—systems that impact millions of users. Initiatives like the ATP are a very welcomed change of pace, which gains more relevance the more users adopt Bluesky as their primary social network.
