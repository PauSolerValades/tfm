# Introduction - What's this all about?

Objective: build a Simulation of the Bluesky social network (aka a twitter-style network) to evaluate different recommender algorithms.


The main measure of interest in the simulation is **post spread and evaluation**. Thesis: the existence of _harmful content_ is not bad _per se_, the problem is when that harmful content gets recommended in a **cascade effect** (eg, user rt the content, which gets shown, which get to more rt... then the algorithm notices and recommends it to much more people) which generates a **viral outbreak** of the post. Narrowing down the behaviour and the context of when, how and why a viral outbreak happens is in itself a useful result, and is what we are aming for.

It is a deliberate decision to not focus on measuring user hidden-state changes at the moment. That is assuming the user has a series of characteristics that get influenced by the simulation, and measuring them could give information about how the recommender influences the user during the duration of the simulation. Furthermore (and despite not being actually relevant to this topic I need to write it down) I hypothesise that a _good_ recommender is one which leaves the main hidden-state of the user unchanged, that is that it does not radicalize you in any of your characteristics. Despite being a very interesting topic it is not feasible to measure due to current data inability to reflect user hidden-state; to do it it would require several hidden assumptions which will make the simulation not representative of real world behaviour unless very well fine-tuned. 


## What to measure?

Metrics to measure for a given post in the simulation:
+ How _far_ a post goes from it's origin? (number of edges jumped)
+ How many distinct users _engage_ with the post?
+ How many distinct users _saw_ the post? 


# Actionable plan to build the simulation

This presents a series of steps to build the first proof-of-concept simulation:

## 1. Understand Bluesky SN
Which features does bluesky has? We can split this in two main parts:
1. User features: What can a user do in relation with posts and other users. How does the user interact with others and the posts?
2. Platform features: how does actually bluesky implement those features? EG, how does the recommender work, what does it take into account. How does the "Following" tab show the information. It's needed to know to accurately replicate.

Note: there is the Bluesky dev page, which is not exhaustive by any means but seems to be a great introduction. A more concrete way is to stalk blog's of (ex-)workers of Bluesky to see what they have explained in the past. This needs several documentation and searching procedures.

## 2. Context User Performable Actions

From the upper section, we have to select which subset of user actions are relevant by the simulation. They are (probably) splited in two ways:
1. User-User: Follow, message, interact, stalk.
2. User-Post: RT, qRT, like, comment, interact...

## 3. Simulation Definition

The simulation needs to define all the actors involved (users, posts, algorithm) and how does the simulation play with them. This will be benefited of a very strict functional requirements definition including which data structures are going to be used to execute this.


## 4. Implementation of the Simulation Engine

Code whatever is defined in step 3. Easier said than done. This also requires evaluation of synthetic behaviours and some mathematical analysis to verify the implementation is correct.

Also, in order to not drown in complexity, steps 2, 3 and 4 should be iterated upon, starting with a very barebones simulation with restrictive assumptions which simplify the system and keep evolving.

## 5. Informed Behaviour

Given a somewhat finished simulation engine, we have to determine models for every action the simulation performs which are representative of a real setting. Then, evaluate this behaviour and obtain some conclusions.


# Big Picture
Past section describes a specific subset of stuff to be done, but not the big picture workflow. This would be:

1. Build the most barebones non complex but representative simulation we can. This should focus on the engine and viability evaluation, system descriptions and miscelaneous stuff. Use also the simplest recommender: chronologically followers recommendation.
2. When 1 is evaluated and the system works, the simple recommender strategy must be swapped for a different one, and analyze the simulation.
3. Compare the results with those two different strategies.



