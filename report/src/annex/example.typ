#import "@preview/cetz:0.4.2"

== Example of Degeneration and Content Teleporation
<anx-ex-teleport>

Consider a minimal microblogging network of three users forming a directed cycle:

#figure(
  cetz.canvas({
    import cetz.draw: *

    // ── Nodes (Users) ──
    circle((0, 2), radius: 0.4, name: "A", stroke: blue)
    content("A", [*A*])

    circle((-1.5, -0.5), radius: 0.4, name: "B", stroke: green)
    content("B", [*B*])

    circle((1.5, -0.5), radius: 0.4, name: "C", stroke: red)
    content("C", [*C*])

    // ── Edges (Out-Neighbors / Following) ──
    // A follows B
    line("A", "B", name: "a-b", mark: (end: ">", fill: black))
    // We can place the label roughly halfway along the line
    content((-1.0, 1.0), text(size: 0.8em, gray)[follows])

    // B follows C
    line("B", "C", name: "b-c", mark: (end: ">", fill: black))
    content((0, -0.8), text(size: 0.8em, gray)[follows])

    // C follows A
    line("C", "A", name: "c-a", mark: (end: ">", fill: black))
    content((1.0, 1.0), text(size: 0.8em, gray)[follows])
    
    // ── Optional: Show Propagation (In-Neighbors) ──
    // If you want to visually show propagation happening in reverse, 
    // you could add dashed lines flowing the opposite way:
    // line("B", "A", stroke: (dash: "dashed", paint: blue), mark: (end: ">", fill: blue))
    // content((-0.4, 0.4), text(size: 0.7em, blue)[propagation])
  }),
  caption: [
    Simple user network $cal(U) = {A, B, C}$. Arrows represent out-neighbor (following) relationships, forming a continuous cycle. Propagation naturally flows in reverse along the in-neighbor edges.
  ]
) <fig-simple-graph>

$ cal(U) = {A, B, C} $

$ cal(N)_"out" (A) = {B}, quad cal(N)_"out" (B) = {C}, quad cal(N)_"out" (C) = {A} $

Thus the follower (in-neighbor) sets ---the targets of propagation--- are:

$ cal(N)_"in" (A) = {C}, quad cal(N)_"in" (B) = {A}, quad cal(N)_"in" (C) = {B} $

Assume all three users are permanently online ($cal(O)(u) = T quad forall u in cal(U)$), and let user $A$ start a cascade by creating a post $p_0$ at $t = 0$. We trace the simulation under two regimes.

==== Without propagation delay ($Delta_p = 0$)

At creation time, the post is delivered directly to the creator's followers at the same timestamp:

1. $t = 0: quad Q = [(A, "create", 0)]$ Pop: $A$ creates $p_0$. Propagation fires over $cal(N)_"in" (A) = {C}$, scheduling an action event for $C$ at $t=0$:

$ Q = [(C, "action", 0)] $

2. $t = 0: quad$ Pop $(C, "action", 0)$. $C$ inspects $p_0$ in $cal(T)_0 (C)$ and, per policy $pi$, reposts. Propagation fires over $cal(N)_"in" (C) = {B}$:

$ Q = [(B, "action", 0)] $

3. $t = 0: quad$ Pop $(B, "action", 0)$. $B$ reposts $p_0$. Propagation over $cal(N)_"in" (B) = {A}$:

$ Q = [(A, "action", 0)] $

In a single instant $t=0$, three cascading actions have taken place. The post traverses the entire network without any notion of temporal distance: creation has the same timestamp as the last cascaded action. This degeneracy collapses any incremental diffusion process into an instantaneous event, and renders the queue $Q$ useless as a scheduling mechanism.

==== With propagation delay ($Delta_p > 0$)

Rather than delivering posts directly, the creation event pushes a propagate event into the future for each follower, at $t_c + Delta_p$:

1. $t = 0: quad Q = [(A, "create", 0)]$ Pop: $A$ creates $p_0$. For each $v in cal(N)_"in"(A) = {C}$, schedule propagation at $0 + Delta_p$:

$ Q = [(C, "propagate", Delta_p)] $

2. $t = Delta_p: quad$ Pop $(C, "propagate", Delta_p)$. $p_0$ arrives in $cal(T)_(Delta_p)(C)$. $C$ inspects it and reposts. Propagation for $C$'s followers at $Delta_p + Delta_p$:

$ Q = [(B, "propagate", 2Delta_p)] $

3. $t = 2Delta_p: quad$ Pop $(B, "propagate", 2Delta_p)$. $p_0$ appears in $cal(T)_(2Delta_p)(B)$. $B$ reposts:

$ Q = [(A, "propagate", 3Delta_p)] $

4. $t = 3Delta_p: quad$ Pop $(A, "propagate", 3Delta_p)$. $p_0$ lands in $A$'s timeline. Since $A$ created $p_0$, the already-interacted check $(A, p_0) in cal(H)_(3Delta_p)(A)$ prevents re-exposure. The cascade ends.

Each hop now costs $Delta_p$ units of time. The cascade unfolds as a genuine temporal process, with every user action tied to a distinct timestamp. The queue $Q$ regains its role as a proper temporal scheduler, and the resulting cascade graph reflects the incubation time that is central to the CTIC model (see @sec-sota-diffusion-ctic).

As it can be seen in the example, a delay is not a luxury, but a necessity for the model to not degenerate. Following DES best practices, instead of modifying the timelines of the user directly with the added delay, we create a `propagate` event, which will make the posts appear to the users timelines at $t + Delta_p$, when it's properly popped from the queue $Q$ and processed as an actual event.

== Session Gen Necessity Showcase
<anx-ex-session-gen>

To implement an activity based behavior, the concept of session had to be introduced in the model (see @sec-model-sessions), and while being very natural to implement, there are some potential contradictions with how the events are scheduled.

The introduction of sessions introduces several operational challenges to the discrete event simulation, specifically regarding the interruption of stochastic processes. Time between actions and creations are measured *within a session* rather than globally. 

Because DES relies on uninterrupted renewal processes to sample probability distributions correctly, pausing a user's activity when they go offline can mathematically invalidate the process. When a session ends mid-renewal, events that were scheduled to occur at a future time (sampled from, e.g., the inter-action distribution) remain in the queue—yet the user's timeline has been cleared and the session context destroyed. If those orphaned events were allowed to execute in a later session, the inter-action times would no longer follow the intended distribution: some would be effectively truncated by the offline interval, others would be shifted across session boundaries.

In @sec-method-des-mechanics it is explicitly stated that there are four types of events, and the session of a user $u$ is managed by an event $(u, t_1, "session.start")$ and $(u, t_2, "session.end")$. Let's showcase the potential problem with the following example.

The queue initially holds a single event:

$ Q = [(u, "session.end", 3)] $

1. $"pop"(Q) arrow.r (u, "session.end", 3)$. $t = 3$. $u$ is online.
   $"HandleGoOffline"$: $u$ goes offline, $"session.start"$ is scheduled at $t = 5$.

$ Q = [(u, "session.start", 5)] $

2. $"pop"(Q) arrow.r (u, "session.start", 5)$. $t = 5$. $u$ is offline.
   $"HandleGoOnline"$: $u$ goes online. Three events are queued for this session: $"session.end"$ at $t = 12$, $"action"$ at $t = 13$, $"create"$ at $t = 14$.

$ Q = [(u, "action", 6), (u, "create", 8), (u, "session.end", 12)] $

3. $"pop"(Q) arrow.r (u, "action", 6)$. $t = 6$. $u$ is online. The user acts over a post of its timeline, we skip the details as they are not relevant for the example, but another action is scheduled to keep the simulation loop running at $t=13$.

$ Q = [(u, "create", 8), (u, "session.end", 12), (u, "action", 13)] $

4. $"pop"(Q) arrow.r (u, "create", 8)$. $t = 8$. $u$ is online. A post gets created, it will get propagated at $8 + Delta_p$, and another creation gets scheduled at $t=14$.


$ Q = [(u, i, "propagate", 9), (u, "session.end", 12), (u, "action", 13), (u, "create", 14)] $

5. $"pop"(Q) arrow.r (u, "propagate", 9)$. $t = 14$. $u$ is online, and the post gets propagated and removed from the queue.

6. $"pop"(Q) arrow.r (u, "session.end", 12)$. $t = 12$. $u$ is online, but it gets marked as offline, and a new session start is scheduled at $t=16$.

$ Q = [(u, "action", 13), (u, "create", 14), (u, "session.start", 16)] $

Now, the problem becomes obvious. The next pop will process the action at $t=13$, but user $u$ is not online at that moment $13 in.not cal(O)(u)$, so the simulation cannot process either of $(u, "action", 13), (u, "create", 14)$. The naive solution would be to implement a procedure called after every go to online to just eliminate all the events between the time the user goes offline $t_e$ and the time it comes back online $t_s$ but this implies reallocating and copying large portions of the event queue on every session boundary (see @sec-impl-memory), so what is done instead is to count the amount of sessions the user has had so far and establish the following rule: an event can just be processed by the simulation if the session it has been generated is the same as the user current session.

The mechanism assigns a number to every session, and the user keeps track of how many sessions he has been active so far. Now, whenever any event is popped from the $Q$, the simulation will check the `session_gen` id. If they coincide with `user_session_id`, it will get processed, if not, it will get discarded.

Let's rerun the example with an added element to the event tuples, representing the session the user has been in so far. The queue initially holds a single event:

$ Q = [(u, "session.end", 3, 0)] $

1. $"pop"(Q) arrow.r (u, "session.end", 3, 0)$. $t = 3$. $u$ is online.
   $"HandleGoOffline"$: $u$ goes offline, $"session.start"$ is scheduled at $t = 5$, and user session id augments by one.

$ Q = [(u, "session.start", 5, 1)] $

2. $"pop"(Q) arrow.r (u, "session.start", 5)$. $t = 5$. $u$ is offline.
   $"HandleGoOnline"$: $u$ goes online. Three events are queued for this session: $"session.end"$ at $t = 12$, $"action"$ at $t = 13$, $"create"$ at $t = 14$. They all belong to `session_gen` 1 

$ Q = [(u, "action", 6, 1), (u, "create", 8, 1), (u, "session.end", 12, 1)] $


3. $"pop"(Q) arrow.r (u, "action", 6, 1)$. $t = 6$. $u$ is online. The user acts over a post of its timeline, we skip the details as they are not relevant for the example, but another action is scheduled to keep the simulation loop running at $t=13$. This new event will have the current `session_id` the user finds himself in, so $1$.

$ Q = [(u, "create", 8, 1), (u, "session.end", 12, 1), (u, "action", 13, 1), ] $

For the sake of brevity, we will skip two pops from the past example, until the queue looks as 

$ Q = [(u, "session.end", 12, 1), (u, "action", 13, 1), (u, "create", 14, 1)] $

5. $"pop"(Q) arrow.r (u, "session.end", 12, 1)$. $t = 12$. $u$ is online, but it gets marked as offline, the `user_session` augments by 1, and a new session start is scheduled at $t=16$.

$ Q = [(u, "action", 13, 1), (u, "create", 14, 1), (u, "session.start", 16, 2)] $

6. $"pop"(Q) arrow.r (u, "action", 13, 1)$. Current time $t=13$, user is offline and `user_session_id` is 2. Before processing the event, the `session_gen` from the event is 1, but the `user_session_id` is 2, therefore the event does not get processed, and it gets dropped. The same will happen with the create event, but not with the session.start event, as has the same, so it will keep the loop running. From now on, an event that can't be processed will be called a stale event.


