#import "utils.typ": *

This chapter highlights improvement points for the current state of the simulation #todo[section] and describes directions for extending it beyond its current scope to achive a better replication of a microbloggins social network.

This chapter outlines directions for extending the simulation beyond its current scope, organized into two independent tracks. The first addresses computational performance — removing the remaining bottlenecks that limit scalability to tens of millions of users. The second addresses model fidelity — lifting the simplifying assumptions of content-agnostic, action-independent diffusion to capture the semantic and psychological drivers of real social network behavior.

== Performance Optimizations
<sec-future-performance>

Despite the excelent performance of the simulation, it is known with the profiler tool `perf`#footnote[`perf` is an excelent profiler that tracks how much time a program spends in the assembly of a lable, marking the most important optimization point.] #todo[cite] that the Event Queue is a performance critical point due to it importance, and every iteration of the loop appends or removes an element, as well as directly growing with the topology size.

The current implementation uses a 8-leaf heap for the global event queue $Q$ (see @apx-impl-queue). While the heap provides $O(log n)$ operations, the future event set remains the principal bottleneck as the simulation scales toward $N = 10^7$ users. With at most $4N$ events simultaneously in the queue and each event requiring two to four heap operations, the actual computational cost is several times the theoretical $log_8(4N) approx 25$ #todo[this number is not okay lol] comparisons. The lack of batch insertion in a heap means there is no avenue for amortization.

The Future Event Set optimization is a known performance bottleneck in Discrete-Event Simulations, and there is plenty of literature addressing more optimal structures that theoretically achive $O(1)$ practical insertion, such as the Calendar Queue @brown1988calendar. Brown, in 1988, showed experimental hold times three times shorter than splay trees for 10,000 events. The standard dynamic Calendar Queue resizes its bucket array to maintain optimal density, but the simulation's known parameters (static user count, bounded events per user, known delay distributions) allow a static heuristic to determine the optimal configuration upfront, eliminating all resizing overhead. Apart from Calenar Queues, there are other more modern stuctures tought for DES such as the DSMList @kim2009mlist, that negate some of the cons of the Calendar Queue.

This has not been implemented in this work due to both time constranints, and that the every algorithm replacing the heap requires a well calibrated heuristic. It was the author concern that, with several changed to the simulation, the heuristic tuning would have consumed plenty of time to get right while at the same time degrading performance, and therefore was avoided by commodity.


== Model Limitations

This section aims to address the known limitations introduced to fit this work into a master thesis scope project.

First, all the characterization of the users in the Data section (@sec-data #todo[afine the specifc one]) charectarize a shy of 20% of users in the dataset: the majority of users on social networks are lurkers, just reading, not interacting nor creating. As the obtention of this data is difficult when talking (as discussed in #todo[appendix of better data]) and there is probably a correlation between the in-out degree of a user and their session duration/inter-session lenght, which probably needs of much more data and a more subtile analysis than the one conducted in this work to get right.

In other words, the simulation 1) ignores the users in-out degrees as in behvaiour _i.e_ a user with one follower has the same change to get a specific behaviour than a user with thousands of followers and 2) assumes every one is an active user, when in reality around 80% of the nodes in the simulation should just be lurking, which lot to see but not interacting at all.

In the same line, an effort to get real navigational data from users should be made in order to accurately calibrate the inter-action time variable. Is one of the more crucial variables not only in this work, but as a quantity in this field of study. Having it would remove a lot of the "feeling" chosen variables. 

#todo[I think i am missin something?]

== A Content Aware Simulation
<sec-future-content>

#todo[Appendix moved section is a mess of a lot of things. a cleaner shorten version of that goes there, as well as keeping in the appendix some ideas of how to implement mechanisms with the embedding]

This work originaly was going to include this mechanism as its main study point, and the original section can be found in @apx-content. This seciton is a summary of the intent and the mechanisms this simulation could include.

Traditional information diffusion models (#todo[see section 2.3]) treat diffusion as purely structual mechanic, stemming just from the network topolgy: if the network has the appropiate properties, the system will behave as a social network. The Independent Cascades model assigna a fixed transmission probability to each edge, but that treats infection (reposting or not) as a binary thing, as well as removing all content to the equation. The extension of the model is

