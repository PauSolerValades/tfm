#import "utils.typ": *

#todo[this is a draft of what the contents should be. Done the last thing, together with conclusions]

#comment[So right now its contents accurate, format inaccurate]



*Context*: 
- what is the state of the art in OSN simulations. Mainly, LLM AMB.
- Why the different approach (DES) is and will be useful with the extension of the work

*Justification*:
- study information diffusion on social networks is necessary as they exerce a strong influence on lots of people in several aspects of life.


*Objectives*
- Define a model that resembles a subset of the characterisitcs of an microblogging social network.
- Implement a simulation according to the model. Verify it's correctness on four key metrics.
- Find out which characteristics of the post makes it travel further away
#comment[How should I frame this now that we are dropping the embedding? should I change the objectives or frame it as a small step to a bigger stone.]

*Hypothesis*
A discrete event simulation is a good model for a real social network 
There are some post characteristics of the content of the posts that they make them much more likely to be shared.
#comment[all hypothesis were regarding content, now what?]

*Research Question*
- Is a DES a good way to model a microblogging social network?
- How can we introduce a meaningful way to detect similarities of posts and users?
- Which are appropiate mechanism to make user behaviour (when seeing a post) change according to the contents of the post?
- Are some post contents influential to how far is the post going to travel? 

*Report structure*
- Chapter 1: This chapter, introduction.
- Chapter 2: Theoretical needed background on social networks and state of the art.
- Chapter 3: Problem definition and mathematical modelization of the subset of features that conform a microblogging social network.
- Chapter 4: Methodology: justificaiton of the model election, the strategy of implementation, the algorithms used in random selection sampling.
- Chapter 5: Simulation design decision and implementation performance details
- Chapter 6: Bluesky data analysis and calibration prodedure of the simulation.
- Chapter 7: Results of the calibration, comparison with theoretical and real social networks.
- Chapter 8: conclusions
- Chapter 9: future work, how to build this into a content aware simulation.

