#import "@preview/typslides:1.3.2": *

#show: typslides.with(
  ratio: "16-9",
  theme: "bluey",
  font: "Fira Sans",
  font-size: 20pt,
  link-style: "color",
  show-progress: true,
)

// The front slide is the first slide of your presentation
#front-slide(
  title: "What did I do until now",
  subtitle: [Regarding my thesis, not all my life],
  authors: "Pau Soler Valadés",
)

#slide(title: "Bluesky simulation")[
  *Objective*: create a bluesky simulation to analyze behavious over it.

  *Approach*: Bottom to Top - start simple, build up until the features the simulation contains is similar enough to it's real counterpart (EG conclusion are _extrapolable_)

  *Methodology* Using a Discrete Event Simulation (DES) to simulate a social network actions. Starting from a simplified version up to a version which resembles a real one. 
]

#slide(title: "Discrete Event Simulation")[
  #framed(title: "Definition: DES")[
    A Discrete Event Simulation models the operation of a system as a (discrete) sequence of events in time [...] and marks a change of the state of the system.
  ]

  This type of simulation is characterized for:
  - Event queue: events are stored in a processing queue, and the simulation retrieves the next event to process.
  - Discrete Time: the simulation jumps forward in time to when exactly an event is occurring.
  - Future Events: when an event is processed, another will be created in the future to make the simulation loop not stop.

]

#slide(title: "Small pseudocode (python) example")[

  ```python
  queue = heap()
  t_clock, horizon = 0.0, 10000
  ET = Enum([A, B])
  X,Y = distribution(), distribution()
  queue.push(create_new_event(time=X.sample(), type = ET.A))
  queue.push(create_new_event(time=Y.sample(), type = ET.B))
  while (t_clock <= horizon):
    current_event = queue.pop()
    t_clock = current_event.time
    if (current_event.type == EventType.A): 
      process_event_A(current_event)
      queue.push(create_new_event(t_clock + X.sample(), ET.A))
    elif (current_event.type == EventType.B):
      process_event_B(current_event)
      queue.push(create_new_event(t_clock + Y.sample(), type = ET.B)
  ```
]

#slide(title: "Compared with ABM")[
  _[Disclaimer: learnt about this today, my b if something is wrong]_

  Advantages:
  + Faster Performance: ABM delegates the decision to the agents, that means asking them at every tick. DES just skips to the next scheduled event.
  + Easier *Calibration*: DES directly uses real-world statistical data (like average posts per hour) instead of forcing you to reverse-engineer human psychology.

  Disadvantages:
  + Rigid Behavior: Entities in DES are mostly passive and rely on programmed dice rolls, missing the organic, autonomous decisions of real users.
  + Misses Emergence: DES struggles to model complex, peer-to-peer social ripple effects where users dynamically change their minds based on their environment.

  _Note: there exists hybrid approaches in OR, I found a paper_
]

#slide(title: "Back to what did I do")[
  + Mathematical modelization of the problem and Markov Chain analysis (stopped rn)
  + Simplification of the network as a proof of concept (v1: barebones)
  + Trace v1 analysis (propagation actions barplot, power law (histogram) and top reposted posts growth rate) and structural viralty metric.
  + Generation of Social Network topologies
  + V2: ReverseChronological thanks to sessions.
]

#slide(title: "V1")[
  *Objective*: is our implementation feasible and possible?

  Strong simplifications in place:
  1. User Homogenity: every user has the same policy $pi$
  2. Action Independence: current action is not influenced by past actions.
  3. Static Entities: Same amount of users, followers and a maximum amount of posts
  4. Actions allowed: repost, like, ignore.
  5. Chronological timelines
  6. User cannot see it's own post.
  7. User cannot see a post twice.
]

#slide(title: "V1 Dynamics")[
  There are two ways of implementing this simulation:
  1. *Diffusion simulation (partial Event Scheduling)*: posts are generated stochastically at the beggining of the function and scheduled while the simulation duration. This is the one that has been implemented.
  2. *Standard Event Scheduling*: Create is an action on the simulation and the posts keep appearing as the simulation runs, but are not scheduled.

  The simulation contains just one event: Action over a post. The user gets shown a post, and can repost, like or ignore it; post creation is handeled by pre-scheduling.

]

#slide(title: "Simulation Configuration Overview")[
  *General Simulation Limits:*
  - *Horizon:* 10,001 ticks
  - *Duration:* 9,000 ticks
  - *Warmup Time:* 1,000 ticks

  *User Behavior & Actions:*
  - *Action Policy:* 50% chance to Ignore, 30% to Like, 20% to Repost
  - *Time Between Actions:* Exponentially distributed (Mean: 3 ticks)
  - *Post Limit:* Max 10 posts per user

  *Network Delays & Scheduling:*
  - *Post Diffusion:* Scheduled between 0 and 10,000 ticks
  - *Delays:* 1 tick constant delay for both user interactions and post propagation
]

#slide(title: "V2")[
  It's acknowledged that v1 simplifications do not resemble at all a social network.

  V2 aims to introduce a small subset of user behaviour and correct the timeline algorithm.
  + User Homogenity: every user has the same policy $pi$
  + Action Independence: current action is not influenced by past actions.
  + Static Entities: Same amount of users, followers and a maximum amount of posts per user.
  + Sessions (vacancy): a user can be online or offline.
  + Sessions Indendence: each user goes into a vacation independently of others.
  + Actions (user-to-post) allowed: repost, like, ignore only when the user is online.
  + Algorithm: Reverse-Chronological timeline.
  + Catch-up: if a user timeline is empty when is online, goes offline.
  + User cannot see it's own post.
  + User cannot see a post twice.
]

#slide(title: "V2 Implementation")[
  This algorithm can be implemented in three differnet ways:
  + Diffusion model: all post creation pre-scheduled, but the reverse-chonological approximation makes it trickier than other options.
  + Standard Event Scheduling: Normal implementation. A warmup phase can be added to not observe simulations startup time. This requires several parameter tweaking and assumes the parameters are the same at early stage and latter stage.
  + Staged simulation: Using the warmup concept, but with a different policy. There can be as many stages added into the simulation and start tracking them at a prefered point in time.

  A checkpoining system can be added to the Standerd Event Simluation, where a specific pre-saved (onto disk) state is loaded into memory.
]

#slide(title: "V2 implementation Mechanics")[
  Modelization: Three possible events in the simulation:
  - Create a post: Propagates the post to the user followers.
  - Action over a post: ignore, like and repost. Repost propagates the post to the user followers.
  - Session: start or end a session.

  Mechanics:
  + *Stage One*: The simulation only allows users to create posts until the warmup time is surpased or max posts are exhausted. Now timelines are populated.
  + *Stage Two*: normal event scheduling algorithm. When a user goes offline, it cannot act. When goes online, an action and a creation are scheduled.

]

#slide(title: "Detailed Simulation Parameters")[
  #grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      *Global & Post Rules*
      - *Phases:* 1k Warmup, 9k Duration, 10k Horizon
      - *Max Posts/User:* 10
      - *Post Creation (Warmup):* Uniform (0 to 100)
      - *Post Creation (Main):* Exp (Mean: 20)
      - *Network Delays:* 1 tick (Constant)
    ],
    [
      *User Behavior & Sessions*
      - *Action Weights:* 50% Ignore, 30% Like, 20% Repost
      - *Action Frequency:* Exp (Mean: 3)
      - *Start State:* 50% Offline at Startup
      - *Session Length:* Exp (Mean: 60)
      - *Offline Gap:* Exp (Mean: 120)
    ]
  )
]
