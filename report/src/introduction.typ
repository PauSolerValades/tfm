#import "utils.typ": *

#todo[this is a draft of what the contents should be. Done the last thing, together with conclusions]

#comment[So right now its contents accurate, format inaccurate]


==== Context

- Introduce what a OSN is, and make the following distinction about content diffusion. Factors that affect the content diffusion:
 - User behaviour: posting frequencies, session lenghts...
 - Technical setup: (affordances): what does the platform do for the user to see content, such as recommender algorithms, notifications and stuff.
 - User-content interaction: a user is more likely to engage with similar content to him.
- what is the state of the art in OSN simulations, which are AMB. (note, LLM are just too new and far away from this, lets just ingnore them)
- Why the different approach (DES) is and will be useful with the extension of the work

==== Justification

- study information diffusion on social networks is necessary as they exerce a strong influence on lots of people in several aspects of life.
- Same as DeSiRe @lasser2025desire project: democracies need functioning civic discourse to enable its citizends to act on the same topic at the same time. They get their main info from social media, therefore, it is very important to understand how the discourse actually works.


==== Objectives

- Define a model that resembles the main subset of the característics of an microblogging social network.
- Implement a simulation according to the model. Verify it's correctness on four key metrics.
- How does information diffuses with content aware posts in a real topology network? This is the first stepping stone in having a more realistic simulation with content-aware posts and non users homogeneity.


==== Hypothesis

How accurate and good a social network simulation with not taking into account the third one, as the third is out of scope and future work? So what we show is not necessarily #comment[adapt this exact wording to results] (realistic) behaviour but isolates the contribution of (simple) user behaviour and platform affordances to information spread.

==== Research Question

- Is a DES a good way to model a microblogging social network?
- How can we introduce a meaningful way to detect similarities of posts and users?
- Which are appropiate mechanism to make user behaviour (when seeing a post) change according to the contents of the post?
- Are some post contents influential to how far is the post going to travel? 
- what are user action frequencies on BlueSky, such as creation, reposting, liking and session lengths?
- what information diffusion patterns do we observe under realistic user action frequencies and social-graph based content recommendation?
#comment[I have to come back here when results is done to actually ask the proper quesitons, or at least have them be much more accurate]

==== Report structure

- Chapter 1: This chapter, introduction.
- Chapter 2: Theoretical needed background on social networks and state of the art.
- Chapter 3: Problem definition and mathematical modelization of the subset of features that conform a microblogging social network.
- Chapter 4: Methodology: justificaiton of the model election, the strategy of implementation, the algorithms used in random selection sampling.
- Chapter 5: Simulation design decision and implementation performance details
- Chapter 6: Bluesky data analysis and calibration prodedure of the simulation.
- Chapter 7: Results of the calibration, comparison with theoretical and real social networks.
- Chapter 8: conclusions
- Chapter 9: future work, how to build this into a content aware simulation.

