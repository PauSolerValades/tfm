#import "utils.typ": def, flex-caption, comment, todo
#import "@preview/cetz:0.4.2"

This section introduces context to the project: what a microblogging social network is, how the phenomena of information diffusion has been studied, and why Bluesky is the chosen social network to simulate.

== Background
<sec-sota-background>

Let's provide the basic definitions and understanding of the Social Network subfield.

#def(name: "Network")[a network is a special case of a graph, where the vertices, edges or both, possess attributes @wiki-network-theory.]

#def(name: "Social Network")[a Social Network is a social structure consisting of a set of social actors (such as individuals or organizations) and social interactions between actors @wiki-social-network. They are studied by the SNA (Social Network Analysis field) which examines the structure of the relationships within those entities.]

According to the definition, any network that models any relationship between humans, groups of humans or human-made-organizations is a social network.

Online social networks (OSN) are a specific case of Social Networks, where the entities are users and posts, and the relationships are such as the following, inherent to an online context: follow, followee, mute, block, create, repost, like, comment, quote, reply...

A social network is also categorized as a complex system. To describe the behaviour of this fact, ---and given that the definition of complex system is still debated up to date, the Edgars Morin definition of complex system is used @choudhary2023impact as it showcases the complexity of the elements adequately.

#def(name: "Complex System")[A complex system is defined as the system where there is a bidirectional non-separability between the identities of the parts and the identity of the whole.] <def-complexsystem>

The unique identities of the parts (users and their individual posts) combine to create the overarching identity and emergent behaviors of the platform. In turn, this macro-structure dictates how information spreads and what content is amplified, which fundamentally alters the user's worldview, online identity, and subsequent behavior within the system.

To define and study content diffusion, the two most important factors are the topology of the actual network (see @sec-sota-topologies) and the chosen diffusion model (see @sec-sota-diffusionmodels).

== Social Network Topologies
<sec-sota-topologies>

This section aims to characterize the topology of social networks according to their main factors. To explain the features of the topology, we must introduce first a way to model the heterogeneity and multiple edge types of a Social Network rigorously, with the use of a mathematical construct called a Multilayer network.

=== Multilayer Network

Social networks can be seen, specially if dealing with multiple relationships and entities, as different networks linked together by some attributes. Kivela et al. @kivela2014multilayer introduces the concept of Multilayer Network, which fullfiles a mental model of what an OSN can be understood as:

#def(name: "Multilayer Network")[
A Multilayer Network is a quadruplet $M = (V_M, E_M, V, L)$, where:
- $V$ is the set of all nodes in the system
- $L = {L_a}_(a=1)^d$ is a sequence of sets of possible layers, where $d$ represents the number of distinct aspects (dimensions) of the network
- $V_M subset.eq V times product_(a=1)^d L_a$ is the set of node-layer tuples, representing exactly which node exists in which layer
- $E_M subset.eq V_M times V_M$ is the multilayer edge set connecting these tuples
]

In an online social network environment, we can define two primary aspects ($d=2$): node types (users, posts, profiles...) and interaction types (follows, likes, reposts...). This structure feels natural as $G_M = (V_M, E_M)$ is a graph, so a Multilayer Network can be interpreted as a graph with specific labels over the nodes and edges.

Natually, edges can be partitioned into _intra-layer edges_, connecting two nodes of the same type.

$ E_A = {((u, bold(alpha)), (v, bold(beta))) in E_M | bold(alpha) = bold(beta))} $

And the _inter-layer edges_, connecting two nodes of different types

$ E_C = E_M - E_A $.

The adjacency matrix for a fully interconnected multilayer network can be represented by an order-$2(d+1)$ adjacency tensor $cal(A)$ @eq-adj-mln. The tensor elements $cal(A)_(u v bold(alpha) bold(beta))$ have a value of $1$ if there is an edge between node $u$ in layer $bold(alpha)$ and node $v$ in layer $bold(beta)$, and $0$ otherwise.

$
cal(A)_(u v bold(alpha) bold(beta)) = cases(
  1 "if" ((u, bold(alpha)), (v, bold(beta))) in E_M,
  0 "otherwise"
)
$ <eq-adj-mln>

To isolate the topological properties of specific subsystems (more intuitively, to "slice" the adjacency tensor into a graph restricting the entites and the edges to just one), we can apply structural constraints. If we restrict our analysis to interactions occurring strictly within the same layer (disallowing inter-layer edges), the network possesses only diagonal couplings. With this restriction, we can express the relevant subsystem as an intra-layer adjacency tensor with elements $cal(A)_(u v bold(alpha)) = cal(A)_(u v bold(alpha) bold(beta))$. 

In other words, instead of analyzing the entire complex tensor $cal(A)$ simultaneously, we can fix the layer index $bold(alpha)$ to isolate a specific relationship. This extracts a standard 2D adjacency matrix $A^(bold(alpha))$ representing a single "slice" of the original tensor. This extraction process will be implicitly used in the following sections when describing the macroscopic topological properties of a single entity type and a single relationship.

To ground this structure, @fig-sota-multilayer shows a minimal two-layer network. The _user layer_ $L_1$ (red) contains the users ($V times L_1$) and their mutual _follow_ relationships (red arrows), whereas the _post layer_ $L_2$ (blue) contains the posts ($V times L_2$). Cross-layer edges encode the remaining interactions: in this example $A$ creates ---and therefore owns--- $P_1$ and $P_2$, while $C$ creates $P_3$ (black arrows), and $B$ reposts $P_1$ and likes $P_2$ (green and purple arrows, respectively). Edges within the post layer encode relations between posts: $P_3$ quotes $P_1$ (orange arrow) and $P_2$ replies to $P_1$ (teal arrow). Each relationship type thus defines its own edge set ---its own slice--- of the multilayer network.

#figure(
  cetz.canvas({
    import cetz.draw: *

    // Label helper: white background so text stays legible above crossing edges.
    let lbl(pos, body, c: black) = content(pos,
      box(fill: white, inset: 0.08em, outset: 0.02em,
        text(size: 0.72em, fill: c)[#body]))

    // ── Layer backgrounds ──
    rect((-3.4, 0.9), (3.4, 3.8), radius: 0.15,
      stroke: (paint: red, dash: "dashed"),
      fill: red.transparentize(95%))
    content((-2.5, 3.55), text(size: 0.8em, fill: red)[*User layer*])

    rect((-3.4, -3.6), (3.4, -1.0), radius: 0.15,
      stroke: (paint: blue, dash: "dashed"),
      fill: blue.transparentize(95%))
    content((-2.5, -1.2), text(size: 0.8em, fill: blue)[*Post layer*])

    // ── Nodes: user layer (red) ──
    circle((0, 3.0), radius: 0.32, name: "A", stroke: red, fill: red.transparentize(80%))
    content("A", [*A*])
    circle((-2.2, 1.6), radius: 0.32, name: "B", stroke: red, fill: red.transparentize(80%))
    content("B", [*B*])
    circle((2.2, 1.6), radius: 0.32, name: "C", stroke: red, fill: red.transparentize(80%))
    content("C", [*C*])

    // ── Nodes: post layer (blue) ──
    circle((-1.6, -2.2), radius: 0.32, name: "P1", stroke: blue, fill: blue.transparentize(80%))
    content("P1", [*P1*])
    circle((1.6, -2.2), radius: 0.32, name: "P2", stroke: blue, fill: blue.transparentize(80%))
    content("P2", [*P2*])
    circle((0, -3.05), radius: 0.32, name: "P3", stroke: blue, fill: blue.transparentize(80%))
    content("P3", [*P3*])

    // ── Follow (intra-layer, mutual, red) ──
    line("A", "B", mark: (start: ">", end: ">", fill: red), stroke: red)
    line("B", "C", mark: (start: ">", end: ">", fill: red), stroke: red)
    line("C", "A", mark: (start: ">", end: ">", fill: red), stroke: red)
    lbl((1.35, 1.75), [follows], c: red)

    // ── Create / owns (black) ──
    line("A", "P1", mark: (end: ">", fill: black), stroke: black)
    line("A", "P2", mark: (end: ">", fill: black), stroke: black)
    line("C", "P3", mark: (end: ">", fill: black), stroke: black)
    lbl((0.0, 0.7), [creates])

    // ── Repost (green) ──
    line("B", "P1", mark: (end: ">", fill: green), stroke: green)
    lbl((-2.3, -0.05), [reposts], c: green)

    // ── Quote / reply (intra-layer, post to post) ──
    line("P3", "P1", mark: (end: ">", fill: orange), stroke: orange)
    lbl((-1.15, -2.72), [quotes], c: orange)

    line("P2", "P1", mark: (end: ">", fill: teal), stroke: teal)
    lbl((0.0, -1.95), [replies], c: teal)

    // ── Like (purple) ──
    line("B", "P2", mark: (end: ">", fill: purple), stroke: purple)
    lbl((-0.5, -0.65), [likes], c: purple)
  }),
  caption: flex-caption(
    [Multilayer network example.],
    [A minimal two-layer network. The red user layer holds the users $A$, $B$, $C$ and their mutual _follow_ edges; the blue post layer holds the posts $P_1$, $P_2$, $P_3$. Inter-layer edges carry the cross-type interactions: $A$ _creates_ (and therefore owns) $P_1$ and $P_2$ and $C$ _creates_ $P_3$, while $B$ _reposts_ $P_1$ and _likes_ $P_2$. Intra-layer edges carry post-to-post relations: $P_3$ _quotes_ $P_1$ and $P_2$ _replies to_ $P_1$. Each relationship type corresponds to a different edge set ---and therefore a different slice--- of the multilayer network.]
  )
) <fig-sota-multilayer>

=== Property Analysis by Scale
<sec-sota-topo-scale>

As a complex system, social networks properties can be classified in three distinct levels of magnification: the micro-scale, the macro-scale, and the meso-scale @wiki-social-network.

- *Micro-scale* analysis focuses on the individual building blocks of the network: a single node and its immediate edges. Metrics at this level include a user's individual degree or their specific centrality.  
- *Meso-scale* sits directly between the individual and the global. It focuses on the intermediate, sub-graph structures that emerge when groups of nodes interact collectively. All the homophily based process affect this layer.
- *Macro-scale* analysis of the global properties of the entire system. This includes the overarching scale-free degree distribution or the small-world average path length of the whole platform, such as structural virality. Macro-scale metrics treat the network as a single, unified entity.

Because the formation of online social networks are very driven by human homophily (see @sec-sota-topo-homophily), they do not grow uniformly; they naturally self-organize into meso-scale substructures. The levels that contain the more know metrics and emergent properties relevant to societal metrics ---an therefore relevant for this work--- are the meso and macro-scale of the network.

Beyond the scale of analysis, the metrics and emergent phenomena of social networks can also be classified by their origin: their reliance on the underlying graph topology versus their dependence on external, non-topological attributes @wiki-social-network. The vast majority of standard network properties are strictly topological ---degree and local clustering coefficient, the identification of structural holes, community and core-periphery structure, scale-free and small-world behaviour, and structural homophily--- derived exclusively from the structural arrangement of nodes and edges, and requiring no additional user metadata at any scale.

Conversely, the primary metric that cannot be explained by topology alone is homophily. While structural homophily remains strictly graph-dependent, understanding the human dynamics behind edge formation requires supplementary, non-topological data integrated into the multilayer model. Specifically, categorical homophily relies on external metadata, such as user demographics or geographic location, while semantic homophily necessitates a qualitative analysis of user-generated content and shared interests. Ultimately, while a network's foundational architecture is topological, contextualizing why these specific connections form relies entirely on these non-topological dimensions.

=== Scale-Free Distribution
<sec-sota-topo-scalefree>

Given a Multilayer network  $M$, let $k$ be the degree of a node $i in V$. Then, the probability $PP$ of a random node to be $k$ follows a power law.

$ PP(k = "deg(i)") = k^(-gamma) $

where $gamma in [2,3]$, depending of the metric.

The value of $gamma$ is obtained from the actual data, and will change according to which "slice" of $M$ we pick. That means that both the degree of a user for the followers relationship and the degree of a post with the repost relationship will follow powerlaws, with different $gamma$ in every case.

Networks which follow this specific power law are called scale-free networks @wiki-scale-free-network @easley2010powerlaws. Specifically, with the multilayer network framework in mind, both the entity user with relationship follower and the entity post with the total number of reposts are going to follow different power laws with different gamma values.

=== Small-World Phenomena
<sec-sota-topo-smallworld>

Let's consider now the graph $G$ induced by the tensor which slice $A = cal(A)_(bold(alpha))$ by users and followers over M. That is, $G$ is an homogeneous graph with one type of directed edge: users and followers.

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
1. Strong Ties: edges that connect people with similarity or strong connections, such as local communities or family members.
2. Weak Ties: casual acquaintances or work colleagues form edges within the clusters, shortcuts between two potentially very different clusters.

The six-degree-separation theory is explained by this differentiation. The theory states that any two individuals in a social network are, at most, separated by six other individuals. This fact is consequence of the existence of weak ties, as allows to move from a familiar homogeneous people to another cluster with very different individuals @centola2007complex.

=== Homophily Dynamics
<sec-sota-topo-homophily>

Humans tend to associate themselves with similar people, and this factor underlies all the connections within a social network. @easley2010contexts

#def(name: "Homophily")[homophily (or assortativity) is the core sociological principle wherein human actors preferentially attach to others who possess similar attributes. @wiki-assortativity]

Homophily can be understood at different levels. At a structural network level can be interpreted as a user will generally follow users with a similar amount of followers, such as a popularity index, which stems from the topology of the network. 

There are other factors much more affected by homophily, such as user attributes ---a user will follow other users with similar age, gender, political affiliation--- and its the main explanation of same interests following, as in users who like the same topics, will tend to aggregate together and produce similar content about those topics. For more information on, see @sec-future.

// === Community Structure 
// <sec-sota-topo-community>

// #comment[if this does not show up in the dataset analysis, let's just remove it!]
// The intense, localized density inherent in social networks implies that graphs are not uniformly clustered. Instead, they exhibit complex meso-scale (see @sec-sota-topo-scale) structures that sit between microscopic node interactions and macroscopic network properties, being the community structure the most frequently analyzed meso-scale structure.

// #def(name: "Community")[a community (or module) is defined as a subgraph exhibiting dense internal connection and sparse external connections.]

// In massive online social networks, these frequently manifest as core-periphery structures, which partition the network into a densely interconnected "core" and a sparsely connected "periphery" that relies on the core for global reach.

// The analysis of those communities is performed by an statistical analysis, the Stochastic Block Model (SBM). SBM assigns a latent group membership to each node and defines the probability of an edge existing between node $i$ and node $j$ strictly based on their respective group assignments @karrer2011stochastic.

== Information Diffusion Models
<sec-sota-diffusionmodels>

Once that a given topology of a social network is defined and we know which properties it has (see @sec-sota-topologies), we can address the main point of this work: information diffusion, or how content propagates through a social network. 

#def(name: "Information Diffusion")[Information diffusion refers to the process of spreading information through a network, whether it is desired or not @nettleton2013diffusion.] <def-informationdiffusion>

And what information diffusion tries to model are the information cascades the content produces when traversing the network topology. The form of this cascades is what unequivocally defines the social network 

#def(name: "Information Cascade")[An information cascade is a phenomena in which a number of people make the same decision in a sequential fashion. It can be modeled as a temporal graph.] @duan2009informational

Specifically, an information cascade can be defined as a graph, where the nodes are the actors (users) involved in the propagation, and the edges are the relationships of those users. A new level is added to the graph when the action of information propagation (_e.g_ a repost) happens at a certain time $t$, as @fig-sota-cascade depicts. 

#figure(
  cetz.canvas({
    import cetz.draw: *

    // Label helper: white background so text stays legible above crossing edges.
    let lbl(pos, body, c: black) = content(pos,
      box(fill: white, inset: 0.08em, outset: 0.02em,
        text(size: 0.72em, fill: c)[#body]))

    // ── Generation guides: time advances downwards ──
    for (i, y) in (3.0, 1.6, 0.2, -1.2).enumerate() {
      line((-3.2, y), (3.4, y), stroke: (paint: gray, dash: "dashed"))
      lbl((-3.45, y), [$t_#i$], c: gray)
    }

    // ── Users ──
    circle((0, 3.0), radius: 0.32, name: "A", stroke: red, fill: red.transparentize(80%))
    content("A", [*A*])
    circle((-1.6, 1.6), radius: 0.32, name: "B", stroke: blue, fill: blue.transparentize(80%))
    content("B", [*B*])
    circle((1.6, 1.6), radius: 0.32, name: "C", stroke: blue, fill: blue.transparentize(80%))
    content("C", [*C*])
    circle((-2.8, 0.2), radius: 0.32, name: "D", stroke: blue, fill: blue.transparentize(80%))
    content("D", [*D*])
    circle((-0.6, 0.2), radius: 0.32, name: "E", stroke: blue, fill: blue.transparentize(80%))
    content("E", [*E*])
    circle((1.6, 0.2), radius: 0.32, name: "F", stroke: blue, fill: blue.transparentize(80%))
    content("F", [*F*])
    circle((2.4, -1.2), radius: 0.32, name: "G", stroke: blue, fill: blue.transparentize(80%))
    content("G", [*G*])

    // ── Reposts ──
    line("A", "B", mark: (end: ">", fill: black), stroke: black)
    line("A", "C", mark: (end: ">", fill: black), stroke: black)
    line("B", "D", mark: (end: ">", fill: black), stroke: black)
    line("B", "E", mark: (end: ">", fill: black), stroke: black)
    line("C", "F", mark: (end: ">", fill: black), stroke: black)
    line("F", "G", mark: (end: ">", fill: black), stroke: black)
    lbl((-1.7, 2.45), [reposts])
  }),
  caption: flex-caption(
    [Information cascade example.],
    [A single information cascade as a tree. User $A$ (red) creates the post at generation 0; each following generation (blue) is a user who reposted the post from a user of the previous generation, so every edge is a repost event. The depth of the cascade is its number of generations and its width the number of reposts per generation.]
  )
) <fig-sota-cascade>

Traditionally, diffusion models are classified into three distinct mathematical paradigms based on their underlying mechanical rules: epidemic models driven by continuous global rates, cascading models driven by independent stochastic probabilities, and threshold models driven by cumulative fractional influence @singh2026survey. The latter is not used in the model of the work, so it's introduced as part of a proposed new architecture (see
 @apx-content).

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

where $beta$ is the contact rate from $S$ to $I$ and $1 / gamma$ the average infectious period. $R$ is the critical value, if $R>1$ implies that an epidemic is possible.

This models a *single cascade of information* or contagion, and there are ways to combine epidemiologic models to describe multiple cascades of information.

While this type of models being elegant and computationally inexpensive compared with the alternatives (and being useful to model news spreading or rumours) @singh2026survey, they are usually not adequate to model diffusion in general in social network due to the cascades produced by the model differing from empirical data. The analysis conducted by Goel et al. @goel2016structural of real OSN data demonstrates that the vast majority of massive information cascades are actually incredibly shallow. Instead of spreading via deep contagion across dozens of generations (as SIS or SIRS models generated cascades), most large cascades are driven by massive hubs (e.g., users with millions of followers) broadcasting a single message that primarily propagates only one degree deep. Consequently, traditional epidemic models fail to accurately capture microblogging dynamics.

The two other alternatives covered in the next sections reject the differential equations (which can be described as a macroscopic description) and embrace the discrete event mechanic (which can be described as microscopic approaches), where the OSNs are driven by discrete individual user decisions to model interactions chronologically.

=== Cascade Models
<sec-sota-diffusion-cascade>

The Cascade model is a stochastic process that describes the flow of information with discrete events at a time $t$. It has the following rules:
+ States: at a time $t$ a node can be inactive (not spreading the information) or active (spreading the information).
+ Monotonicity: Once a node $v$ activates, it cannot go back to inactive.
+ One shot: every node can attempt the change of its neighbors state once per edge.
+ Probability: every edge has a probability $p_(u,v)$ for $u$ to successfully activate $v$.
+ Independence: given a node $u$, multiple attempts to change node $u$ from their neighbors do not affect the probability of $u$ changing state.

The process then goes as follows: for every active node $v$ at step $t$, it attempts to change state of every inactive neighbors $u$ with probability $p_(u,v)$. If the attempt succeeds, $u$ will be active and transmit the information at time $t+1$. Regardless of the result of that operation, the edge gets discarded from future information spread.

According to how the probability is defined, we will have different cascade models. The most simple one defines the probability of $v$ activating $u$ at time $t$ as a constant, independent of the process history:

#def(name: "Independent Cascade Model")[a cascade model where the probability $p_u (v)$ of $v$ activating $u$ at time $t$ is constant, independent of the history of the process so far. Its final integrated probability of a node being activated remains strictly invariant regardless of the temporal sequence in which its neighbors attempt transmission @zhang2014chapter1 ---what matters is not the order of activations, but the amount of them.] <def-ic>

Crucially, regardless of whether the neighbor adopts the information, the original node can never attempt to activate that neighbor with that specific post again. This permanent refractory state perfectly encapsulates a simple contagion (see @sec-future-content-contagion), where a single exposure is entirely sufficient to trigger adoption @centola2007complex.


=== Continuous-Time Independent Cascade Model
<sec-sota-diffusion-ctic>

While the standard Independent Cascade (IC) model (@def-ic) operates in discrete epochs, real-world information and disease propagation occurs continuously over time. In many scenarios we observe the exact timestamps when a node adopts a piece of information, necessitating a shift from discrete steps to a continuous temporal dynamic. @gomezrodriguez2012inferring

The Continuous-Time Independent Cascade model is generalization of the Independent Cascade Model, as it preserves the core assumption of independent transmission across edges but replaces fixed step-based probabilities with a time-dependent transmission likelihood. Rather than assuming a neighbor attempts activation in the immediate next time step, the continuous formulation models the incubation time, which is the delay between a node $j$ becoming infected at time $t_j$ and subsequently infecting an uninfected neighbor $i$ at time $t_i > t_j$. @gomezrodriguez2011uncovering @gomezrodriguez2012inferring

Each directed edge $j -> i$ is governed by a pairwise transmission rate $alpha_(j,i)$ that fixes the distribution of incubation times. Making the transmissoin rate follow different distributions (memoryless exponential to heavy-tailed power-law forms @gomezrodriguez2011uncovering) makes the model behave completely different, modeling different "costs" for the information to arrive from user to user. In its original form, these rates are fitted to observed cascades by maximizing the per-edge transmission likelihood, in order to reconstruct hidden networks; this work uses the CTIC generatively instead, the incubation time is not sampled per edge but realized by the timeline dynamics (see @sec-model-incubation)

== Social Networks Simulations
<sec-sota-simulations>

This section aims to cover how research has approached the simulations of social networks historically and offer comparisons to what this project objectives are. Historically, it has been approached from two complementary lenses: Agent-Based Modeling (ABM) @taylor2014introducing, a bottom-up paradigm in which every actor of the system is modelled as an autonomous agent that holds its own state and follows its own behavioural rules, so the global phenomenon is expected to emerge from the interactions of many of these agents. The second one is Discrete-Event Simulation (DES) @fishman2001des, a top-down paradigm in which the system is understood as a state machine that only changes at discrete, chronologically ordered events, and the simulation advances by jumping from one event to the next instead of by fixed time steps. The two are not mutually exclusive ---a DES can embed agent logic and an ABM can be executed over an event queue--- and the comparison of their output accuracy on the same model has been studied on its own @despachedcomparison2010, as well as addressed in @sec-method-abm in this report. This section positions the two traditions before the following chapters narrow the discussion down to the DES one, which is the one this work implements.

=== Agent-Based Modeling

ABM is the _de facto_ paradigm of social simulation, and its roots predate the modern social web. Schelling's segregation model @schelling1971 and the Sugarscape artificial society @sugarscape1996 already showed, in the last decades of the past century, that non-trivial macro-level structure can arise from simple local rules without any central coordination, which is the core promise of the paradigm. From there, the approach transferred naturally to opinion dynamics, where every agent holds an opinion and updates it by interacting with a subset of its neighbours. Mastroeni, Vellucci and Naldi @mastroeni2019agentbased offer a bibliographic survey of this family, mapping how the updating rules, the interaction structure and the validation strategies have evolved over time. A recurring difficulty of the whole family is evaluation: an agent-based model is cheap to build and easy to tune until it tells a convincing story, and there is no single accepted protocol to decide when a simulated society is faithful to its empirical counterpart. This concern is what motivates paradigm-agnostic taxonomies such as the review and assessment of digital twin-oriented social network simulators @digitaltwinsimulators2023, which tries to compare simulators by their intended purpose instead of by the paradigm they subscribe to. What all of this work shares is the consolidation of ABM as the dominant classical paradigm for social simulation.

=== Generative Agent-Based Modeling

The most recent pivot inside ABM replaces the hand-written decision rule of the agent with a large language model. In this generative-agent setting the agent perceives the environment and produces behaviour in natural language, which allows for much richer and more human-like responses than a fixed rule ever could. The line opened by the Generative Agents architecture @park2023generative set this direction, and S³ @gao2023s3 is a representative system of it for social-network simulation. The first years of the field have already been consolidated into surveys, with "From Individual to Society" @fromindividualtosociety2026 and the survey of Gao et al. @gao2024llmabm on LLM-empowered agent-based modeling and simulation covering the taxonomies of what the agents are asked to do and how the resulting societies are evaluated, and a third one broadening the map with an evaluation-oriented taxonomy of agents for social simulation @llmagentssurvey2025. The catch is that a more expressive agent is also a harder one to trust: the very openness that makes the behaviour convincing makes the model impossible to validate by exact replication, and validation has been singled out as the central open challenge of this research agenda @validation2025. This is precisely the point where a rigorously calibrated, non-generative baseline ---such as the DES presented in this work--- keeps its relevance: it fixes the mechanism and the parameters, so the agreement (or disagreement) with the empirical cascades can be attributed to the model instead of to the prompt.

=== Discrete-Event Simulation

The DES paradigm, in contrast, asks a narrower question: given a population of actors and a set of possible timed actions, which event happens next and what does it change? The following works answer it at different levels of abstraction.
 
Bouanan et al. @bouanan2019devs propose a formal framework, based on the Discrete Event System Specification (DEVS) formalism, for the modelling and simulation of propagation phenomena in social networks, and apply it to information spreading in a multi-layer network. This is the strongest conceptual anchor of the present work: it establishes that information diffusion can be expressed rigorously as a set of coupled atomic models whose interactions are triggered by events, instead of as differential equations or as a synchronous step-based process, and it does so while keeping the different layers of the network explicit. The proposal is not isolated, as the same group had already explored the DEVS formalism for multi-dimensional social networks @bouanan2015wip and the CELL-DEVS variant to model the impact of information on individuals @bouanan_celldevs, which together make the 2019 paper a consolidation of a line of work.

At a lower level of abstraction, Gatti et al. @gatti2013smsim present SMSim, a simulation-based approach to analyse information diffusion in a microblogging online social network. SMSim executes a DES over a follower graph sampled from Twitter, where users publish, repost and reply following behavioural rules, and it compares the resulting cascades against the diffusion observed in the platform. Structurally it is the closest precedent to the setup of this work: a platform-specific, follower-graph-based DES whose validation target is the shape of the empirical cascades. It also illustrates the main limitation of its time, namely that both the topology and the behaviour had to be kept small enough to fit the compute of the moment, which is the gap that the next generation of engines tries to close.

Hou et al. @hou2013supenet address exactly that gap with SUPE-Net, a parallel discrete-event simulation platform for large-scale social networks. The work distributes the execution of a DES across a high-performance cluster and hybridizes the event-driven core with agent-based components, so that the behavioural side of the model stays tractable once the population grows. This is where the scalability angle enters the narrative of this section: DES is not only a modelling choice but also an execution model that parallelizes naturally, and SUPE-Net is direct evidence that large-scale social simulations were already reachable years before the present work.

A parallel lineage of DES comes from computational epidemiology, where the substrate is a contact network instead of an information network but the machinery is the same. EpiSimdemics @barrett2008episimdemics is the canonical example: it propagates a disease over a large realistic social network and reaches populations of over a hundred million individuals, an order of magnitude beyond what information-diffusion simulators of the time could attempt. Loimos @kitson2024loimos continues this line more than a decade later as a modern, open discrete-event epidemic framework, and works such as DESSABNeT @stapelberg2021dessabnet show the same design applied at a smaller and more agile scale. The relevance for this work is the proven scalability pedigree: DES over a realistic social graph has been demonstrated to sustain the population sizes that a microblogging simulation requires, even though the propagated entity is a disease instead of a post.

The DES works above share one simplifying assumption that this work cannot make, as they all run over a static network. Real microblogging platforms do not have a fixed topology: users join, follow and unfollow, and the graph over which diffusion happens is itself a function of time. Serena et al. @serena2021temporal close this gap by simulating dissemination strategies over temporal networks, where the edges carry the times at which they are active and the dissemination process can only use an edge while it is available. This dynamic-topology view bridges directly into the model of this work, whose follower graph is built from a time-windowed sample of the ATProto firehose (see @sec-data-topology) and whose sessions make the interaction between a user and the platform explicit.

Across all of these, the space that remains is well defined: a DES that is platform-specific like SMSim, formally grounded like the DEVS frameworks, scalable like the parallel engines, and evaluated against the empirical cascade distribution of a live microblogging network instead of against a synthetic contagion model. That is the position this work aims to occupy.

== Description of Microblogging Social Media 
<sec-sota-description>

Despite social networks being a relatively new addition to modern life, they have fundamentally changed how information is consumed and spread in the modern age. To adequately understand the aims of this project, some definitions and context regarding social networks are provided.


A *Microblogging Social Network* (e.g., Twitter/$bb(X)$ or Bluesky @bluesky-social-network) is a specialized type of social network where users publish and exchange short-form content. This is enforced by a limit on the maximum number of characters per entry, known as microblogs or posts. A post, while traditionally text-based, can also include up to four multimedia elements.

Bluesky, as an open platform, allows for user-made feeds with diverse rules and categories dictating which posts are shown. These include feeds focused on highly specific topics (such as technology, local events, or art). The two primary feeds provided by default are the _Discover_ feed and the _Following_ feed.

The Discover feed uses a recommendation algorithm to suggest the most relevant posts to a user based on their tastes and the network of people they follow. This criterion usually excludes the temporal component of when posts were created or reposted, focusing instead on content similarity and engagement.

The Following feed is a traditional social network timeline. It displays creations and reposts exclusively from the accounts the user follows, showing them in strict reverse-chronological order, from newest to oldest. 

To model a microblogging social network, it is imperative to understand and describe all the features that compose the application. Specifically, the following description is of the microblogging platform Bluesky @wiki-bluesky, as it is the platform chosen to simulate (see @sec-sota-bluesky).

The post is the fundamental building block of Bluesky, acting as the primary vehicle for the information that will be spread. A user sees these posts in a feed, which is a sorted collection of posts categorized by specific rules. For the feed to contain posts, we must explain the other fundamental relationship in a social network: the follow.

A user can follow other users, allowing the content of those users to appear to the "follower". That is, if user $u$ follows user $v$, all the posts that user $v$ creates will appear in the feed of user $u$. This is one mechanism for a user's feed to populate with posts. The other way for content to travel is how a user interacts with a post once it appears in their feed, this being the main source of post appearance in the user feed. Conversely, there are some actions a user can perform over other users which limit the posts that can appear on a user's feed: a user can block (preventing both users from seeing each other's activity) or mute (activity of a muted user is not shown to the user) another user, which will alter the posts that can appear on the timeline of the user who performed that action.


A user can meaningfully act on a post in four different ways:
- *Like:* If a user likes a post, it won't show in their followers' feeds, but it will be stored in the user's profile (discussed later).
- *Quote:* This is a direct answer attached to a post. It is shown together with the original post in the followers' timeline, acting as commentary on the original content.
- *Reply:* This is a direct response to an original post. The reply will be shown in the followers' feed and clearly marked as a reply, though the original post usually won't be shown alongside it unless the follower also follows the original author.
- *Repost:* If user $u$ reposts a post in their feed, that post will subsequently appear in the feeds of user $u$'s followers. 


Among these actions, the repost is the primary engine of information diffusion. 

Lastly, every user has a profile, which is customizable with a profile picture, a description, and a background image. The profile acts as a public ledger containing all posts the user has written or reposted, all replies made to other posts, and all likes given.

== Why Bluesky? 
<sec-sota-bluesky>

Bluesky @wiki-bluesky is a microblogging social network, built on the Authenticated Transfer Protocol, ATP for short @atproto-overview. 

The ATP is a protocol and set of open standards for decentralized publishing and distribution of self-authenticating data within the social web @abramov2025opensocial. Adhering to the protocol separates the content produced by the user on a social media platform from the infrastructure of the social media platform, essentially defining a format for the characteristics of the data to be usable in any social media app that implements the ATP protocol. In other words: by establishing an existing format defining all the characteristics of how data should be structured and which data should be publicly available, the implementation of the application Bluesky (the program that runs on the browser or phone) is decoupled from where and how the data the user creates is stored. 

The relevant side effect of this design decision is that the server that stores the Bluesky data, the firehose @atproto-repo, is open and all the data that is sent and received can be accessed and stored. Data for this study (see @sec-data) was collected and provided for analysis by the CS^2 research group at University of Graz . 

Alternative microblogging platforms to X @x-platform (previously known as Twitter), such as Bluesky and Mastodon @mastodon-social-network, remain less widely adopted than mainstream platforms, despite their steady growth @blueskyfeeds-user-growth.

A significant challenge in contemporary social media research is the increasing privatization of user data by major platforms. Proprietary metrics with high commercial value, such as session length, content views, and granular engagement statistics, are rarely published or made accessible to independent researchers. This trend toward restricted data access limits academic inquiry and the broader understanding of social media ecosystems—systems that impact millions of users. Initiatives like the ATP are a very welcomed change of pace, which gains more relevance the more users adopt Bluesky as their primary social network.

