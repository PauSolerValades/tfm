#import "utils.typ": todo, comment, def, flex-caption

This chapter presents the empirical evaluation of the Continuous-Time Independent Cascade (CTIC) model. 

== Execution


=== Final Calibration
<sec-results-config>

@tbl-res-config is the final configuration of the simulation, containing all the defined parameters (@sec-model) or the data informed results (@sec-calibration).

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Simulation field*], [*Calibrated value*], [*Source*],
    table.hline(stroke: 0.5pt),
    [`session_duration`], [1 of 16 fitted pairs, per-user empirical parameters], [@sec-cal-dist],
    [`inter_session_time`], [Same 16-pair table as `session_duration`], [@sec-cal-dist],
    [`inter_creation_time`], [ECDF of within-session post gaps], [@sec-cal-interpost],
    [`user_inter_action`], [$lambda = 1/3$ (mean 3 s)], [@sec-cal-interaction],
    [`user_policy`], [Weights $[0.915, 0.073, 0.012]$ on `ignore`, `like`, `repost`], [@sec-cal-policy],
    [`propagation_delay`], [1 s], [@sec-method-ctic],
    [`interaction_delay`], [1 s], [@sec-method-des-assumptions],
    [`creation_delay`], [1 s], [@sec-method-des-assumptions],
    [`offline_startup_ratio`], [0.5], [Assumption],
    [`warmup_post_inter_creation`], [$"Unif"(0, "warmup_time")$], [Synthetic warmup],
    [`warmup_time`], [], [Synthetic warmup],
    [`horizon`], [], [@sec-exec-stationary],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Final simulation parameters.],
    [Recap of the final simulation parameters, used in the resported execution.],
  )
) <tbl-res-config>



=== Datasets

Which datasets we have ran (all of them) and point toward the Firehose annex. as well as how many performance 100 runs

=== Performance

Talk scalability and run. This is just to be like "HELL YEAH THIS WORKS" and then point to the annex to make in depth there

== Results

#comment[
  I deleted everything here as i changed the simulation sustantially, soooo don't think they are appliable anymore.

  What to do:
  1. Check reposts powerlaw: is it a power-law? what's the gamma? how different is from blueskay?
  2. Check post lifetime metrics from the datasets. Compare them. Should I use the same censoring strategy for both? Proabbly should compute the h(t), but still have to decide what am I comparing here
  3. Check virality: this is pretty easy, it's just numbers with their CI, pretty elementary.

  Then, check out how the refreshes and boredom are playing out. When the runs are done this probably is going to be very streamlined.
]
