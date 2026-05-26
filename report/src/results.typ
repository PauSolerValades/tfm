This chapter will cover the trace analysis from the simulation.

== Stationary Behaviour

This is the basic metrics the simulation should satisfy.

Let's compute the batch means of the global metrics, such as 
- `avg_online_frac`
- `empty_timeline_pct`

== Queued Content Congestion 

Let's discuss and aggregate the median backlog mean for users in the simulation and the queues.
- how many user/(total users) did log in with the queues at zero? histogram
- how many times/(total users) left bored (no content to check). Histogram across all runs.
- how was timeline backlog (when the user logged off how filled it was in general) -> batch mean (mean per simulation, mean per runs) seems interesting
- relationship bursiness.
- Compute a post seen per session approximate (would need to run the processing again)

== Lifetimes and Scale 

Approximate the power law $gamma$ and the post lifetimes $alpha$ for both parts. This tells us how far the information dies.

Scatter plot: lifetime_norm vs total_reposts. Does a post need to get big to live, or can it just die

// this feels like when the protagonist says the name of the movie outloud
== Cascades Analysis

First of all: batch means of % of viral posts in all the simulations, as well as all the other submetrics of the cascades.

Influencer effect network: whcih users can go viral, are the ones with more followers? htis is the gini coefficient, which i discarded.

=== Micro-Macro Coupling

Relate input and output quantities, as they are very important.

The pace ration
$
rho = frac("mean inter-action-time", "mean inter-repost time")
$

Session persistance
$
pi = frac("mean post lifetime", "mean time online per session")
$

The saturation index

$
sigma = frac("avg time between reposts", "mean time offline")
$

== Simulation _versus_ Reality

Compare the metrics in @sec-data to our findings


