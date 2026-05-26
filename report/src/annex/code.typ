#import "../utils.typ": *

This annex explains what has been delivered with the thesis, as well as some instructions on how to run the code.

== Repositories

The simulation (see @sec-design and @sec-impl) is in the `ctic-des` folder. The project contains four versions of the simulation, following what @sec-impl-version describes
+ `v1-v2`: contains both the reverse chronological and the chronological order of the simulation. Both are contained in the same file, compiling with `zig build` will generate two binaries.
+ `v3`: the finished simulation.
+ `v4`: the simulation without `json` configuration, and the specific user session sampling defined in #todo[sec-data-sessions-whatever ]. This is the simulation that has been ran to report results .

The data analysis code can be found in `bsky-firehose-analysis`, which is structured in the following way:
+ EDA: main EDA, #todo[see section] on the original database tables ()
+ Sessions: contants the tukey fence method, the replication of the twitter method (see )
+ 


The database tables description can be found in @apx-database
