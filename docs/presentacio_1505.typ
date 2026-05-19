#import "@preview/typslides:1.3.2": *

#show: typslides.with(
  ratio: "16-9",
  theme: "bluey",
  font: "Fira Sans",
  font-size: 20pt,
  link-style: "color",
  show-progress: true,
)

// ================================================================
// TITLE
// ================================================================

#front-slide(
  title: "Information Diffusion on Bluesky",
  subtitle: [Discrete-Event Simulation of a Queue-Based, Activity Driven Continuous-Time Cascade Model],
  authors: "Pau Soler Valadés",
)

// ================================================================
// PART 1 — CONTEXT
// ================================================================

#slide(title: "What is a Social Network?")[
  #framed(title: "Definition: Social Network")[
    A social network is a social structure consisting of a set of social actors
    (individuals or organizations) and the social interactions between them.
  ]

  - Online Social Networks (OSN): users and posts as entities, relationships like
    follow, repost, like, reply, quote...
  - Complex systems: the micro (individual user decisions) and the macro (emergent
    platform behavior) shape each other bidirectionally
  - Massive influence on: politics, public opinion, consumption habits, mental health
]

#slide(title: "What is Information Diffusion?")[
  #framed(title: "Definition: Information Diffusion")[
    The process by which content spreads through a network — whether desired or not.
  ]

  - Information cascades: temporal graphs formed by chains of reposts
  - Each repost creates a new "generation" in the cascade
  - Two key ingredients:
    + The *topology* of the network (who follows whom)
    + The *diffusion model* (how users decide to share)
  - Goal of this work: understand the mechanics that make content travel far
]

#slide(title: "Social Network Characteristics")[
  Four key emergent properties define real OSN topologies:

  #v(0.3em)

  - *Scale-Free*: degree distribution follows a power law $P(k) ~ k^(-gamma)$. A few
    hubs have massive reach; most nodes have few connections.

  - *Small-World*: high local clustering + short average path lengths.
    "Six degrees of separation" — any two users are surprisingly close.

  - *Homophily*: users preferentially connect to similar others.
    "Birds of a feather flock together" — drives community formation.

  - *Community Structure*: dense clusters sparsely interconnected.
    Core-periphery patterns — a tightly connected core and a loose periphery.
]

#slide(title: "Traditional Diffusion Approaches")[
  Two classical paradigms for modeling information spread:

  #v(0.3em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      *Epidemic Models (SIR)*

      - Macroscopic: tracks population-level
        compartments over continuous time
      - Nodes: _Susceptible_ → _Infectious_ → _Recovered_
      - Governed by ODEs with global
        rates $beta$ (contact) and $gamma$ (recovery)
      - Elegant, computationally cheap
      - But: produces deep multi-generation
        cascades that don't match empirical
        OSN data
    ],
    [
      *Independent Cascade (IC)*

      - Microscopic: discrete stochastic
        activations per edge
      - A node becomes _active_ at time $t$ and
        attempts to activate each neighbor
        with probability $p_(u,v)$ — one shot per edge
      - Monotonic: once active, stays active
      - Order-independent: final result doesn't
        depend on activation sequence
      - Captures simple contagion (one
        exposure is enough)
    ]
  )

  Both approaches share the same core object of study: the *information cascade*.
]

#slide(title: "What is an Information Cascade?")[
  #framed(title: "Definition")[
    An information cascade is a phenomenon in which a number of people make
    the same decision in a sequential fashion. It can be modeled as a
    *temporal graph* — nodes are the users involved, edges are the relationships
    between them, and each new level is added when a propagation action
    (e.g. a repost) happens at time $t$.
  ]

  - Every cascade starts from a *single source* (the original post)
  - Grows through reposts: each new reposter becomes a parent for the next generation

  A diffusion model describes how *one* cascade unfolds.
  A real social network is a superposition of thousands of overlapping cascades
  competing for attention simultaneously.
]

#slide(title: "The Data Problem")[
  - Major platforms (X/Twitter, Meta) increasingly *restrict API access*
  - Session lengths, content views, engagement statistics → kept private
  - This limits independent academic research on a system that impacts millions

  #v(1em)

  - *Bluesky*: built on the ATP (Authenticated Transfer Protocol)
  - ATP decouples user data from platform infrastructure
  - Side effect: the firehose —all public data— is open and accessible
  - Data for this project: provided by the *CS² research group* (University of Graz)
]

// ================================================================
// PART 2 — PROBLEM & MODEL
// ================================================================

#slide(title: "What Are We Modeling?")[
  - Bluesky's *Following feed*: reverse-chronological timeline
  - Core mechanics we care about:
    + Users *create* posts
    + Users *see* posts from accounts they follow
    + Users *interact*: repost or like
  - The repost is the *engine of information diffusion*

  #v(0.5em)

  #framed(title: "Why the Following feed?")[
    The Discover feed uses a recommender algorithm — a hard problem in itself.
    The Following feed lets us isolate the *structural* diffusion dynamics
    without conflating them with recommendation effects.
  ]
]

#slide(title: "Scope: What's In")[
  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      *In the model:*
      - Follow relationships (static)
      - Post creation
      - Repost and like actions
      - Reverse-chronological timeline
      - User sessions (online/offline)
      - Propagation delays
    ],
    [
      *Out of scope:*
      - Discover feed (recommender)
      - Replies and quotes
      - Blocks and mutes
      - User profiles
      - Dynamic graph growth
    ]
  )

  #v(0.5em)
  A focused subset lets us isolate the core diffusion mechanics.
]

#slide(title: "Formalizing the Problem")[
  Model the system as a *Time-Varying Heterogeneous Graph*:

  - *Two entity types*:
    + Users $cal(U)$ — the actors
    + Posts $cal(I)$ (items) — the information units

  - *Two edge families*:
    + User → User: _follow_
    + User → Post: _create_, _like_, _repost_, _ignore_

  - This captures the dual nature of the network: a social graph with an
    overlaid information layer
]

#slide(title: "Time-Varying Heterogeneous Graph")[
  #framed(title: "Formal Definition")[
    A Time-Varying Heterogeneous Graph is a tuple
    $cal(G) = (V, E, T, rho, psi, eta)$ where:

    - $V$ is the universal set of all nodes (users and posts)
    - $E$ is the universal set of all possible edges
    - $T = RR^+$ is the continuous time domain
    - $psi : V times T -> {0, 1}$ — node presence: does a node exist at time $t$?
    - $rho : E times T -> {0, 1}$ — edge presence: is an edge active at time $t$?
    - $eta : E times T -> T$ — edge latency: the delay before an edge takes effect
  ]

  #v(0.3em)

  Why this formalism?
  - Captures *heterogeneity*: users and posts are different kinds of nodes,
    follows and reposts are different kinds of edges
  - Captures *time-variance*: posts don't exist before creation; actions are punctual
  - Embeds *delays* as first-class citizens — propagation, interaction, and
    creation delays are baked into the model
]

#slide(title: "Temporal Dynamics")[
  - *Posts* don't exist before their creation time $t_c$:
    $ psi(i, t) = cases(1 "if" t >= t_c, 0 "otherwise") $

  - *Follow* edges are static once established

  - *Interaction* edges are punctual events at specific timestamps

  - *Delays* are a first-class concept:
    + Propagation delay: time for a post to reach a follower's timeline
    + Interaction delay: cognitive time before reacting
    + Creation delay: time to compose a new post
]

#slide(title: "User Sessions")[
  - Users are not always online — they alternate between:
    + Active *sessions* (browsing, posting, interacting)
    + Offline *gaps* (not on the platform)

  - This is the *Activity-Driven* framework:
    bursts of activity separated by inactivity

  #v(0.5em)

  #framed(title: "Why does this matter?")[
    While a user is offline, new posts continue arriving.
    When they log back in, newer content has piled on top
    of what they missed — *older posts may never be seen*.
  ]
]

#slide(title: "The Timeline as a Queue")[
  - Each user has a *timeline*: a reverse-chronological queue (LIFO)
  - When a followed user creates or reposts → the post lands at the *top*
  - The user consumes from newest to oldest

  #v(0.5em)

  This creates a *survival competition*:

  - A post's chance of being seen depends on:
    + How many *newer* posts pile on top (influx rate $mu_v$)
    + How long the user was *offline* ($Delta_"idle"$)
    + Whether the *session is long enough* to scroll through the backlog
]

#slide(title: "User Decision Policy")[
  - When a user sees a post, they decide probabilistically:

  #v(0.5em)

  $ pi = { "ignore", "like", "repost" } $

  $ sum_(a in {"ignore", "like", "repost"}) pi(a) = 1 $

  #v(0.5em)

  - The policy is *static* and *shared* by all users (homogeneity assumption)
  - Decision is *Markovian*: depends only on the current post, not on history
  - This is the simplest form — content-aware policies are left for future work
]

// ================================================================
// PART 3 — METHODOLOGY
// ================================================================

#slide(title: "The Diffusion Model: CTIC")[
  #framed(title: "Continuous-Time Independent Cascade")[
    Events happen at continuous timestamps, not in discrete rounds.
    Each edge has a time-dependent transmission likelihood governed by
    survival and hazard functions.
  ]

  - Perfect fit for microblogging: users don't consume in lock-step
  - Posts compete in continuous time — being "new" is an advantage
  - *Homogeneous simplification*: same transmission rate across
    all edges (given user homogeneity assumption
]

#slide(title: "Activity + Queue Dynamics")[
  - Standard diffusion: nodes are always available — not true for humans
  - *Activity-Driven* adds sessions (bursty human behavior)
  - *Reverse-chronological queue* adds attention competition

  #v(0.5em)

  A post's survival depends on the convolution of:

  #v(0.3em)

  $ PP("seen") = PP( sum_(m=1)^(N_"newer") D_"action"^((m)) < Delta_k ) $

  #v(0.3em)

  - $N_"newer"$: posts that arrived while the user was offline
  - $D_"action"^((m))$: time to process each newer post
  - $Delta_k$: duration of the current session
]

#slide(title: "Why Not Analytical?")[
  To find a closed-form solution, we would need to convolve:
  - The stochastic arrival process ($N_"newer"$)
  - The distribution of individual reading times ($D_"action"$)
  - The distribution of session durations ($Delta_k$)

  #v(0.5em)

  This is *mathematically intractable*.

  #v(0.5em)

  #framed(title: "Therefore: simulation")[
    We resolve the reverse-chronological consumption step-by-step,
    natively, by simulating the system.
  ]
]

#slide(title: "Why Discrete-Event Simulation?")[
  #framed(title: "Definition: DES")[
    A DES models a system as a sequence of events in time.
    State changes happen at discrete points; the simulation
    jumps from one event to the next.
  ]

  - *Event queue*: all future events stored, processed chronologically
  - *Discrete time jumps*: no computation for idle intervals
  - *Future events*: processing one event schedules the next
]

#slide(title: "DES vs Agent-Based Modeling")[
  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      *Agent-Based Modeling:*
      - Every agent evaluated every tick
      - Offline agents still consume compute
      - Scales with $N$ users
      - Developmentally complex
    ],
    [
      *Discrete-Event Simulation:*
      - Only scheduled events processed
      - Offline users cost nothing
      - Scales with active events
      - Leaner model, top-down design
    ]
  )

  #v(0.5em)
  OSNs are *bursty*: most users are idle at any instant → DES exploits this sparsity.
]

#slide(title: "Simulation Mechanics: Events")[
  Four event types live in the central priority queue $Q$:

  #v(0.3em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      *create*
      User authors a new post.
      Propagates to followers.

      *action*
      User reacts to the next post
      in their timeline.
      Outcome: ignore / like / repost.
    ],
    [
      *session.start*
      User comes online.
      Scheduling of actions resumes.

      *session.end*
      User goes offline.
      Timeline is cleared.
    ]
  )

  #v(0.3em)
  At most 3 events per user in $Q$ at any time (action, create, session boundary).
]

#slide(title: "Simulation Mechanics: Main Loop")[
  #set text(size: 17pt)

  ```python
  while t_clock <= horizon:
      event = queue.pop()          # nearest event
      t_clock = event.time

      if event.type == "create":
          create_post(event.user)
          propagate_post(event.user, new_post)
          queue.push(next_create(event.user))

      elif event.type == "action":
          post = peek(event.user.timeline)
          act = sample(event.user.policy)   # ignore / like / repost
          if act == "repost":
              propagate_post(event.user, post)
          queue.push(next_action(event.user))

      elif event.type == "session.start":
          event.user.online = true
          queue.push(session_end(event.user))
          queue.push(next_action(event.user))

      elif event.type == "session.end":
          event.user.online = false
          clear(event.user.timeline)
          queue.push(session_start(event.user))
  ```
]

#slide(title: "The Propagate Mechanic")[
  When a post is created or reposted by user $u$:

  #v(0.3em)

  #framed(title: "Propagation")[
    For every follower $v in cal(N)_"in"(u)$:
    push the post into $v$'s timeline after a delay $tau$.
  ]

  #v(0.3em)

  - Follower sees the post in reverse-chronological order
  - At their next *action* event, they pop the newest post and decide
  - *Propagation delay* $tau$ prevents instantaneous transmission
    (a post cannot be reposted at the exact same time it was created)

  #v(0.3em)

  This is the core loop that builds information cascades.
]

#slide(title: "Session Integrity")[
  #set text(size: 18pt)
  Sessions introduce a subtle problem:

  #v(0.3em)

  - A user is online → events are scheduled into the future
  - The user goes offline → timeline cleared, session ends
  - But the *stale events* are still in $Q$!

  #v(0.3em)

  If processed, they would corrupt the renewal processes
  (inter-action times would no longer follow the intended distribution).

  #v(0.3em)

  #framed(title: "Solution: session_gen")[
    Every user has a `session_gen` counter that increments on
    each new session. Events are stamped with the counter value at
    scheduling time. On pop, if `event.session_gen != user.session_gen`,
    the event is *discarded*.
  ]
]

#slide(title: "Simulation Parameters")[
  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      *User behavior:*
      - Action weights: ignore / like / repost
      - Time between actions: Exponential
      - Max posts per user

      *Sessions:*
      - Session duration: Exponential
      - Inter-session gap: Exponential
      - Fraction starting offline
    ],
    [
      *Delays:*
      - Propagation delay
      - Interaction delay
      - Creation delay

      *Simulation limits:*
      - Warmup time
      - Horizon
    ]
  )

  #v(0.5em)
  These parameters are *calibrated* against real Bluesky data.
]

#slide(title: "Key Assumptions")[
  1. *User homogeneity*: all users share the same policy $pi$ and creation rate $lambda$
  2. *Post homogeneity*: content does not influence the decision — all posts are equal
  3. *Action independence (Markovian)*: current decision depends only on $pi$, not on history

  #v(0.5em)

  These are deliberate simplifications:
  - Keep the model *tractable* and *verifiable*
  - Establish a *baseline* before adding complexity
  - Future work: relax each one with content-aware mechanics
]

// ================================================================
// PART 4 — EVALUATION
// ================================================================

#slide(title: "Evaluation: Four Metrics")[
  To validate the simulation, we compare against known empirical patterns:

  #v(0.3em)

  1. *Reposts power-law*
  2. *Post lifetime*
  3. *Gini coefficient*
  4. *Structural Virality*

  #v(0.3em)

  If the simulation reproduces these patterns, it captures the essential
  mechanics of a real microblogging social network.
]

#slide(title: "Metric 1: Reposts Power-law")[
  In real OSNs, the number of reposts per post follows a power law:

  $ P(k) ~ k^(-gamma), quad gamma in [2, 3] $

  #v(0.3em)

  - The vast majority of posts get few (or zero) reposts
  - A tiny fraction of posts go viral
  - This is a signature of *scale-free* networks

  #v(0.3em)

  A valid simulation must reproduce this heavy-tailed distribution.
]

#slide(title: "Metric 2: Post Lifetime")[
  *Post lifetime*: the time elapsed from the first repost to the last repost.

  #v(0.3em)

  - Expected to follow a heavy-tailed distribution
  - Most interactions happen shortly after creation
  - After the initial burst, attention decays rapidly

  #v(0.3em)

  This captures the *temporal* dimension of diffusion:
  how long does content remain "alive" in the network?
]

#slide(title: "Metric 3: Gini Coefficient")[
  The Gini coefficient measures *inequality* in information inflow
  across users:

  #v(0.3em)

  - 0 = perfect equality (everyone receives the same information)
  - 1 = extreme inequality (a few hubs dominate)

  #v(0.3em)

  In real OSNs: high degree-Gini → a small set of users dominates
  the inflow of information (signature of power-law follower distributions).

  #v(0.3em)

  Advantage over power-law exponent: requires *no parametric assumptions*
  about the underlying distribution.
]

#slide(title: "Metric 4: Structural Virality")[
  #framed(title: "Definition")[
    Average distance between all pairs of nodes in a cascade tree.
    $ nu(T) = frac(1, n(n-1)) sum_(i=1)^n sum_(j=1)^n d_(i j) $
  ]

  #v(0.3em)

  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      *Broadcast* ($nu approx 2$):
      - One hub, one hop
      - Celebrity posts
      - Shallow, wide cascade
    ],
    [
      *Viral* ($nu >> 2$):
      - Multi-generational
      - Peer-to-peer spread
      - Deep, branching cascade
    ]
  )
]

#slide(title: "Calibration Strategy")[
  - *Data source*: Bluesky firehose from CS² (University of Graz)
  - *Process*:
    1. Extract empirical distributions from real data
    2. Tune simulation parameters to match observed patterns
    3. Validate against the four evaluation metrics

  #v(0.5em)

  Goal: the simulation should reproduce the same *structural signatures*
  observed in real Bluesky data — not just aggregate numbers, but the
  shape of the distributions.
]

// ================================================================
// PART 5 — DESIGN (high-level)
// ================================================================

#slide(title: "Simulation Lifecycle")[
  Three distinct phases:

  #v(0.5em)

  *Phase 1 — Load topology*
  - Read the social graph (users, follow relationships)
  - Allocate data structures

  *Phase 2 — Warmup*
  - Only post creation events are active
  - Fills every user's timeline before tracking begins
  - Avoids degenerate empty-timeline behavior at $t = 0$

  *Phase 3 — Main loop*
  - All event types active
  - Metrics recorded from here until the horizon
]

#slide(title: "Technology & Performance")[
  - *Implemented in Zig*: a modern systems programming language
  - Manual memory management → no garbage collection pauses
  - *Data-Oriented Design*: fields stored contiguously, cache-friendly layouts
  - Goal: simulate millions of users, hundreds of replications

  #v(0.5em)

  #framed(title: "Why not Python/R?")[
    Interpreted languages cannot handle CPU-bound loops at this scale.
    For statistical significance, we need *speed* and *determinism*.
  ]
]

#slide(title: "Key Data Structures")[
  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      *Event Queue and Timelines*
      Min-Heap per future event queue.

      Per-user Max-Heap —
      instant access to the
      newest post (LIFO).
      Cleared on session end.
    ],
    [
      *Graph Topology*
      Compressed Sparse Row (CSR) —
      all follower relations in one
      contiguous array.
      Zero pointer overhead,
      maximum cache hit rate.

      *Post Storage*
      Segmented arrays —
      handles unbounded growth
      without reallocation.
    ]
  )
]

// ================================================================
// PART 6 — CLOSING
// ================================================================

#slide(title: "Where are we now?")[
  - Report writing, lots of things :(
  - Calibration:
    - Topology obtention: kinda difficult
    - Real life parameters.

  - Results: will be kinda similar, but not at all, as the simplifications made will actually be very influential.

]

#slide(title: "Future Work (discarded work)")[
  *Content-aware simulation:*
  - Post embeddings → semantic similarity between users and posts
  - Homophily-driven interaction probabilities (instead of static $pi$)
  - Users more likely to engage with content similar to their interests

  *Complex contagion:*
  - Linear Threshold model: multiple exposures needed to trigger action
  - Move beyond "one exposure is enough" (simple contagion)

  *Additional mechanics:*
  - Quotes, replies, notifications, content mutation over re-shares
]

#slide(title: "Thank You")[
  #set text(size: 24pt)
  #align(center)[
    *Questions?*

    #v(1em)

    Pau Soler Valadés

    #v(0.5em)

    TFM — Máster en Bioinformática y Bioestadística

    Universitat Oberta de Catalunya
  ]
]
