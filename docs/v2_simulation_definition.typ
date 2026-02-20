#set text(font: "Liberation Sans")

#set par(justify: true)

= Definition of the V2 Simulation.

We build from the [v1 simulation][v1_simulation_definition.typ] and enhance it to further resemble more a simulation.

== Scope of v2

The main concerns of v2 is to implement a Reverse Chronological Order algorithm (instead of a Chronological Order) with the introduction of user sessions.

A user now can be in two states:
- active: will see its feed and interact according to a policy $pi_u$.
- inactive: its offline touching grass :)


== Axioms

1. User/Agent Homogeneity: every user is indistinguishable from the other users, they behave absolutely the same, that is, they have the exact same decision policy $pi$.

$ forall u, v in U : pi_(u) = pi_(v) = pi $

2. Action Independence: The agent (user) is memoryless regarding past actions:

$ PP (a_(u,i)^t | cal(H)_u ) = PP (a_(u,i)^t ) $

3. Structure Stability: the underliying structure of the Graph is not going to change during the simulation.
- User Population: no new users are added in the simulation duration.
- Post Population: no new posts are going to be created during the simulation duration.
- User Relationships: no new following/followers are going to be added.

4. Sessions: user won't be active during all the simulation, but will be on and of

5. Algorithm: User $u$ sees its followers posts $Gamma_("out")(u)$ in a reverse-chronological order.



== Notation



