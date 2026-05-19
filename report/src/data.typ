#import "utils.typ": todo, comment

This section covers the analysis of the Bluesky Firehose dataset in order to find the rellevant statistical quantites for the calibration of the simulation.

== Technology Stack

#comment[What did we actually use as software, please finish]
- StartRocksDB: a statistical database that stores by columsn instead of rows.
- Python 3.13: main tool for data analytics. rellevant packages apart from numpy and polars are powerlaw and scipy
- R 4.5.3: Used for the session analytics, it's just one script but uses a whole tone of packages #todo[Fill those packages from the R script]

== Firehose Data 
<sec-data-firehose>

#comment[
This section has to explain what is the firehose, it's relation with the ATProto, how the data is organized and why, which events are there.
]


1. How many users does the data set have? How many events?
2. Which subset of users is interessting, which subset is degenerated?


== Topology Obtention

The simulation has been executed until now over a synthetic social network data set for testing purposes (see @sec-impl-topology). The first objective is to extract a subset of the Bluesky graph first.

== Session Analysis

The most important simulation quantities are session duration, time between session and the Categorical distribution of the $pi$ policy: which is the probability that a user likes or reposts a piece of content. 

The objective of this section is to explain the means used to obtain all of the quantities stated in the above paragraph: 
1. Session Lengths (`session_duration` in the configuration)
2. Time between sessions (`inter_session_time` in the cofiguration)
3. The $pi$ policy: $pi_("ignore"), pi_"like", pi_"repost"$

=== Methodology

This section covers and justifies the methodology that allowed to obtain the threshold of how long a session is from the Firehose dataset (@sec-data-firehose). 

Narrowing down on specifics, what needs to be obtained is a quantity we will call $delta$, which represent the maximum amount of time between events in which the user is considered to still be online. In other words, let's assume the following timestamps of a single user $t_1, t_2, t_3$. If $t_2 - t_1 < delta$ and $t_3 - t_2 < delta$, then the user session will be spand from $[t_1, t_3]$. If instead, $t_3 - t_2 > delta$, the session will spand from $[t_1, t_2]$, and $t_3$ not be in the session, as the distance between it's past event is greater as $delta$.

Two methods have been used in obtain the sessions data: 1) replicating the methodology of the article "Twitter Session Analytics: Profiling Users' Short-Term Behavioral Changes" @kooti2016twitter, which found out the mean session time on Twitter is around 10 minutes and 2) using the Tukey method with interquartilc range.

==== Twitter Session Analytics Replication

// TODO from the database
//

==== Tukey Range per User



=== Exploratory Data Analy 

==== Whatever

== Lifetime Analysis

== Structural Virality




