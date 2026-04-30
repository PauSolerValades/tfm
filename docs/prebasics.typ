#import "@preview/lovelace:0.3.0": *

#set text(font: "New Computer Modern")

#set par(justify: true)

#set heading(numbering: "1.")

#set page(numbering: "1")

#let maketitle(title, name, course, bachelor, uni, date) = {
  align(center, text(18pt)[
    #strong(title)
  ])

  align(center, text(11pt)[
    #emph(name) \
    #emph(course) \
    #emph([#bachelor - #uni]) \
    #emph(date)
  ])
}

#maketitle(
  [Context and Research about Social Networks],
  [Pau Soler Valadés],
  [M.Sc on Statistics and Operation Research],
  [Final Thesis ],
  [Universitat Politècnica de Catalunya and University of Graz],
  [April 27, 2026]
)

= Introduction

This document aims to cover the basics for my MSc Thesis, as I neglected the important research to the end of the works and I should not have done that, I apologize. This is my attempt at making things right (and will probably need to be included into the report regardless, so not even that bad)

= Social Networks

In this section we are going to narrow down what a social network and an online social network are. Let's start from the beginning:

*Definition* (Network): a network is a special case of a graph, where the vertices, edges or both, possess attributes @wiki-network-theory. 

*Definition* (Social Network): a Social Network is a social structure consisting of a set of social actors (such as individuals or organizations) and social interactions between actors @wiki-social-network. They are studied by the SNA (Social Network Analysis field) which examines the structure of the relationships within those entities

So, any network that models any relationship between humans, groups or humans or human-made-organizations is classified as a social network.

Online social newtorks (OSN) are of course a specific case of Social Networks, where the entities are users and posts, and the relationships are follow, followee, mute, block, create, repost, like, comment, quote, reply...

[TODO: focus a little bit more on the other differences, which makes the content go flying and generates the cascades immediately]

A social network is also a complex system. In this case, I am using the Edgars Morin definition of complex system @choudhary2023impact.

*Definition* (Complex System): A complex system is defined as the system where there is a bidirectional non-separability between the identities of the parts and the identity of the whole.

Clearly, this definition applies to social networks. The unique identities of the parts (users and their individual posts) combine to create the overarching identity and emergent behaviors of the platform. In turn, this macro-structure dictates how information spreads and what content is amplified, which fundamentally alters the user's worldview, online identity, and subsequent behavior within the system.


= Social Networks Topologies
<sec-context-topologies>

This section aims to characterize the topology of social networks according to their main factors. To explain the features of the topology, we need a model of what is a social network.

== Multilayer Network

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

== Scales of a Social Network 
<sec-context-scale>

Social networks properties can be classified in three distinct levels of magnification: the micro-scale, the macro-scale, and the meso-scale @wiki-social-network.

- *Micro-scale* analysis focuses on the individual building blocks of the network: a single node and its immediate edges. Metrics at this level include a user's individual degree, their specific centrality, or the clustering coefficient of their immediate friends. 
- *Meso-scale* sits directly between the individual and the global. It focuses on the intermediate, sub-graph structures that emerge when groups of nodes interact collectively. 
- *Macro-scale* analysis zooms all the way out to look at the global properties of the entire system. This includes the overarching scale-free degree distribution or the small-world average path length of the whole platform. Macro-scale metrics treat the network as a single, unified entity.

Because online social networks are very driven by human homophily (see @sec-context-homophily), they do not grow uniformly; they naturally self-organize into these meso-scale substructures. 

The levels that contain the more know metrics and emergent properties are the meso and macro-scale of the network, which usually combine metrics from the micro level to explain the bigger phenomena.


== Scale-Free Distribution

Let $k$ be the degree of a node $i in V$. Then, the probability $PP$ of a random node to be $k$ follows a power law.

$ PP(k) ~ k^(-gamma) $

where $gamma in [2,3]$, depending of the metric. Equivalently, it can also be expressed as: 

$ PP(k = "deg(i)") = k^(-gamma) $

The value of $gamma$ is calibrated from the data, and will change according to which "slice" of $M$ we pick. That means that both the degree of a user for the followers relationship and the degree of a post with the repost relationship will follow powerlaws, with different $gamma$ in every case.

Networks which follow this specific power law are called scale-free networks @wiki-scale-free-network @easley2010powerlaws.

== Small-World Phenomena
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

== Homophily Dynamics
<sec-context-homophily>

Humans tend to associate themselves with similar people. This concept is known as Homophily. @easley2010contexts

*Definition* (Homophily): homophily (or assortativity) is the core sociological principle wherein human actors preferentially attach to others who possess similar attributes. @wiki-assortativity

Homophily will be split for categorization purposes acording to the slices of $M$ which can be computed.
- Structural similarity: Just users and follows: the only similitude applicable is the degree of the nodes. In this context homophily can directly be interpreted as "well-connected users should follow other very well-connected users". This can be measured in different ways
- Categorical attributes: if the multilayer network contains plains of categorical information about a node ---such as age, nationality, gender, location, political affiliation--- they can be used to compute homophily with a meaning regaring as the user nature; it can be interpreted as "similar users will be connected to also similar users"
- Semantic Similarity: we could consider similar users regarding the content of the posts the user post and similarity of the users post content with other users. This could be interpreted as "a user follows users with similar output content and interest as himself", which could be used to explain content related phenomena.


== Structural Holes

Apart from the clustering from the small-world effect (see @sec-context-smallworld) which defines the network as a merge of clusters with weak ties between some of them, the empty topological spaces between these dense communities are equally vital to the analysis of information flow. 

Structural holes refer to the explicit absence of ties between two alters who are both independently connected to an ego (Burt et al @burt1992structural). These structural deficits act as absolute insulators in network information flows, preventing redundant circulation.

The severity of structural holes is quantified mathematically by the network constraint index $C_i$. This index measures the extent to which an ego's network time and social capital are concentrated in a single, highly redundant cluster. The dyadic constraint $c_(i j)$ that a specific contact $j$ exerts on node $i$ is calculated by integrating both the direct investments and the indirect dependencies flowing through mutual third-party contacts $q$.

//TODO: no crec que faci falta, però l'artícle té la formula. Just després dic que no es pot calcular perque computacionalment és molt costosa.

A high constraint score severely limits an actor's access to heterogeneous information, trapping the ego in an echo chamber. Conversely, a low constraint score signifies a radial, spanning network topology crossing numerous structural holes, allowing the actor to exploit non-redundant information cascades.

The obtention of $C_i$ is computationally very expensive, and its an active topic on data mining and computer science @lou2013mining.

== Community Structure 

The intense, localized density inherent in social networks implies that graphs are not uniformly clustered. Instead, they exhibit complex meso-scale (see @sec-context-scale) structures that sit between microscopic node interactions and macroscopic network properties, being the community structure the most frequently analyzed meso-scale structure.

*Definition* (Community): a community (or module) is defined as a subgraph exhibiting dense internal connection and sparse external connections.

In massive online social networks, these frequently manifest as core-periphery (CP) structures, which partition the network into a densely interconnected "core" and a sparsely connected "periphery" that relies on the core for global reach.

The analysis of those communities is performed by an statistical analysis, the Stochastic Block Model (SBM). SBM assigns a latent group membership to each node and defines the probability of an edge existing between node $i$ and node $j$ strictly based on their respective group assignments @karrer2011stochastic.

== Topological versus Attribute-Dependent Properties

To consolidate the theoretical framework presented in the preceding sections, the metrics and emergent phenomena of social networks can be fundamentally categorized by their reliance on the underlying graph topology versus their dependence on external, non-topological attributes @wiki-social-network.

The vast majority of standard network properties are strictly topological; they are derived exclusively from the structural arrangement of nodes and edges within the adjacency tensor, requiring no additional user metadata. At the micro-scale, this encompasses a node's degree and local clustering coefficient, as well as the identification of structural holes via the constraint index. Moving to the meso-scale, community structures and core-periphery modules are delineated purely through the comparative density of internal and external edge formations. At the macro-scale, overarching phenomena such as the scale-free degree distribution and small-world properties—characterized by global clustering and logarithmic average path lengths—are entirely emergent from the global architectural topology. Furthermore, structural homophily falls into this category, as it describes preferential attachment based solely on network equivalences, such as degree centrality, rather than personal traits.

Conversely, the primary metric that cannot be explained by topology alone is homophily. While structural homophily remains strictly graph-dependent, understanding the human dynamics behind edge formation requires supplementary, non-topological data integrated into the multilayer model. Specifically, categorical homophily relies on external metadata, such as user demographics or geographic location, while semantic homophily necessitates a qualitative analysis of user-generated content and shared interests. Ultimately, while a network's foundational architecture is topological, contextualizing why these specific connections form relies entirely on these non-topological dimensions.

= Information Diffusion Models on Social Networks

Once that a given topology of a social network is defined and we know which properties it has (see @sec-context-topologies), we can address the main point of this work: information transmission. 

*Definition* (Information Diffusion): Information diffusion refers to the process of spreading information through a network, whether it is desired or not @nettleton2013diffusion. 

Traditionally, diffusion models are classified into three distinct mathematical paradigms based on their underlying mechanical rules: epidemic models driven by continuous global rates, cascading models driven by independent stochastic probabilities, and threshold models driven by cumulative fractional influence @singh2026survey.

== Epidemic Models

[TODO: HA de ser una miqueta més matemàtic això jo crec]

Epidemic models focus on the macroscopic diffusion of information, and they are primarly modeled using classic compartmental models adapted from epidemiology, such as the SIR (Susceptible-Infected-Recovered) and SIS models @zhang2014chapter1. In these frameworks, nodes transition between states based on continuous-time differential equations and global transmission rates. 

#text(blue)[Val la pena posar les fòrmules aquí?]

An infected node continuously attempts to infect its neighbors for as long as it remains in the infected state. These models are highly appealing because they are mathematically elegant and can be easily calculated for massive populations without the computational burden of simulating every individual edge.

Despite epidemic models being used in some information diffusion (such as news spreading or rumours) @singh2026survey, they are usually not adequate to model diffusion in general in social network due to the cascades produced by the model differing from empirical data. In the article "The structural virality of online diffusion", Goel et al. introduced the concept of Structural Virality, quantified using the Wiener index of cascade trees @goel2016structural. Their analysis of real OSN data demonstrates that the vast majority of massive information cascades are actually incredibly shallow. Instead of spreading via deep contagion across dozens of generations (as SIS or SIRS models generated cascades), most large cascades are driven by massive hubs (e.g., users with millions of followers) broadcasting a single message that primarily propagates only one degree deep. Consequently, traditional epidemic models fail to accurately capture microblogging dynamics.


If instead of modeling the information as diferntial equations and loosing the insperation from epidemiology, the information diffusion is modeled as a discrete event mechanic (events happening independently) the microscopic paradigm treats OSNs as systems driven by discrete, individual user decisions, using discrete event mechanics to model individual interactions chronologically.

== The Independent Cascade Model

The Independent Cascade model works with the following main mechanic: when a node $u$ becomes active (e.g. by retweeting a post) has a single opportunity to activate each of its inactive neighbors $v$ (followees) with a specific probability $p_(u,v)$ If it succeeds, the neighbor becomes active; if it fails, the neighbor ignores the content. 

A defining mathematical feature of the IC model is its order-independence: the final integrated probability of a node being activated remains strictly invariant regardless of the temporal sequence in which its neighbors attempt transmission @zhang2014chapter1. Crucially, regardless of whether the neighbor adopts the information, the original node can never attempt to activate that neighbor with that specific post again. This permanent refractory state perfectly encapsulates a simple contagion (see @sec-context-diffusion-contagions), where a single exposure is entirely sufficient to trigger adoption @centola2007complex.

This "one-shot" evaluation directly mimics the behavior of a user scrolling through a timeline. A user sees a post once, decides instantaneously to retweet it or ignore it, and then scrolls past it forever.

[TODO: el seguent paragraf no té cita perque estic introduint el que s'ha programat a la simulació.]

An underlying assumption of the standard IC model is the discrete generations, assuming all nodes evaluate information instantly. In a real OSN, the network topology dictates the potential highways for information, but time dictates the traffic. To recreate observed structural virality accurately, the IC model must be extended with temporal constraints. Introducing temporal delays, session durations (when users log off), and interaction delays ensures that if a user receives a retweet but logs off before scrolling far enough to see it, that branch of the cascade dies. Incorporating these realistic temporal mechanics is needed for accurate simulations of platform-specific transmission (see [sec-results o sec-design]).

== The Linear Threshold Model

The Linear Threshold (LT) model focuses on modeling the activation according to the neighbours of the user neighborhood, allowing the modelization of complex social phenomena as social pressure or continual exposure to certain elements. This behaviour can be classified as complex contagion (see @sec-context-diffusion-contagions).

Complex contagions---such as shifts in belief or costly sociopolitical behaviors---require multiple reinforcing exposures from overlapping network clusters to overcome a user's resistance @centola2007complex @meng2025spreading. In the LT model, every node $i$ is assigned a personal, latent threshold $theta_i in [0, 1]$, representing their inherent resistance to adopting a new behavior. Concurrently, every directed edge from a neighbor $j$ to node $i$ is assigned a non-negative weight $w_(j i)$, representing the proportional degree of influence $j$ exerts on $i$ @zhang2014chapter1. The core mechanical rule dictates that a node $i$ will only become active if the sum of the influence weights from its currently active neighbors meets or exceeds its personal threshold:

$ sum_(j in "ActiveNeighbors"(i)) w_(j i) >= theta_i $

Unlike the IC model, where each exposure acts as an independent probability event, the LT model is fundamentally cumulative. A user might be exposed to a controversial opinion by one friend and ignore it because the single edge weight $w_(j i)$ does not overcome their high internal threshold $theta_i$. However, if three different friends from disjoint clusters within their ego-network adopt the opinion, their aggregate influence might finally breach the threshold, triggering adoption. 

Because it strictly requires simultaneous or accumulated exposures, the LT model's diffusion is heavily dictated by meso-scale topology. Information spreading via a Linear Threshold process easily saturates dense communities (forming echo chambers) but frequently fails to cross structural holes, as a single "weak tie" acting as a bridge rarely provides enough cumulative weight to overcome a receiving node's threshold @centola2007complex.

== Diffusion Mechanics

While the traditional information diffusion covered until now (see @sec . In reality, OSN are driven by human psychology, introducing major friction points to pure structural diffusion: finite attention and cumulative exposure requirements.

=== The Attention Economy

In a microblogging platform, a user's chronological timeline is a highly competitive ecosystem. Users possess finite cognitive bandwidth and temporal limits per session. The probability of a user interacting with (or liking) a specific post is not an isolated independent variable; it is heavily dependent on the competition from other content presented simultaneously within their feed @hirakura2023method (Accessed April 28, 2026). As a timeline fills, posts must compete for visibility, meaning that the diffusion of one cascade actively cannibalizes the potential diffusion of another. 

=== Complex Contagion and Multiple Exposures
<sec-context-diffusion-contagions>

[TODO: Definition of complex vs simple conagions]

Furthermore, while the standard Independent Cascade model strictly dictates a "single-chance" refractory state suited for simple contagions, the diffusion of opinions or rumors often operates as a complex contagion. Meng et al. explicitly quantify this spreading dynamic, demonstrating that the probability of a user adopting or retweeting information scales dynamically with the number of times they are exposed to it by different neighbors @meng2025spreading (Accessed April 28, 2026). A user might ignore a topic the first time it appears in their feed, but multiple exposures from disjoint clusters in their network will significantly lower their threshold for interaction.

=== Content Semantics

To accurately capture these advanced dynamics, modeling the network strictly through its topology and mechanical pipes is insufficient. A simulation must become reactive to the semantics of the content itself.

Implementing attention competition, homophily, and complex contagion requires giving posts a measurable identity. This necessitates transitioning to a semantic simulation where posts and user preferences are represented as continuous vectors (embeddings) in a latent multidimensional space. Only by measuring the geometric distance between a user's preference vector and a post's semantic vector can a model dynamically adjust interaction thresholds, simulate content fatigue, and accurately replicate the competitive attention economy observed in real platforms.

= Methodology

Aquesta secció no està pensada per anar a la memòria, així que la faig en català.

Sembla que la simulació programada és una IC on la probababilityat de que un esdeveniment salti d'un a l'altre és una categòrica amb tres passos. El fet de que un usuari només vegi un post un sol cop és cenyeix absolutament a aquest model. A més a més, afegir els delays i les sessions sembla que hi fa una bona sinergia.

Per la versió amb continguts, s'haurà d'adoptar quelcom més semblant a un LT, on les probabilitats de la categòrica canviaran segons la similitud amb el contingut, juntament amb l'addició del que hi ha a Meng et al @meng2025spreading, juntament amb una mecànica de competitivitat/fatiga de l'usuari. Dit això, no sé si és possible per tema temps i que s'han d'evaluar moltes coses, però ja ho sentirem més tard.

Per acabar, això ens demostra que, en essència, aquest treball ha fet dues simulacions, i per tant les mètriques a mirar són senzillament, differents segons a quina estiguem.

v1:
- Cascade Size Distribution: els reposts, un cop calibrada, han de seguir una power-law.
- Structural Virality: un cop calibrada, han d'haver-hi structural virality sobre els reposts.
- Temporal Burstiness: Temps entre els reposts d'una mateixa cascada. Això en les dades reals és una non possonian distribution, es disparen als primers minuts i després acaben morint.
- Gini coefficient: mesura la structural inequality - un repost d'un don nadie no hauria d'arribar a tanta gent com un repost d'un influencer.

v2: 
A definir segons el que acabi sent la implementació.
- Diferència mitjana entre el que l'usuari publica i veu.
- fatiga
- Gini coefficient.

#pagebreak()
#bibliography("prebasics.yml")
