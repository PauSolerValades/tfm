#import "../utils.typ": *

This appendix collects the initial-condition convergence plots of the steady-state experiment (@sec-exec-stationary) for all four network sizes, in logarithmic and linear scale. In every figure the three initial conditions ($r_0$, $r_50$, $r_100$) collapse onto the same equilibrium online fraction.

== Logarithmic Scale

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    image("../../images/calibration/initial_conditions_10K_log.png", width: 100%),
    image("../../images/calibration/initial_conditions_100K_log.png", width: 100%),
  ),
  caption: flex-caption(
    [Stability plots (log): 10K and 100K.],
    [Online-user fraction over time for the three initial conditions, logarithmic scale. Left: 10K network; right: 100K network.],
  )
) <fig-apx-stable-log-10k-100k>

#pagebreak()

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    image("../../images/calibration/initial_conditions_500K_log.png", width: 100%),
    image("../../images/calibration/initial_conditions_1M_log.png", width: 100%),
  ),
  caption: flex-caption(
    [Stability plots (log): 500K and 1M.],
    [Online-user fraction over time for the three initial conditions, logarithmic scale. Left: 500K network; right: 1M network.],
  )
) <fig-apx-stable-log-500k-1m>

#pagebreak()

== Linear Scale

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    image("../../images/calibration/initial_conditions_10K.png", width: 100%),
    image("../../images/calibration/initial_conditions_100K.png", width: 100%),
  ),
  caption: flex-caption(
    [Stability plots: 10K and 100K.],
    [Online-user fraction over time for the three initial conditions, linear scale. Left: 10K network; right: 100K network.],
  )
) <fig-apx-stable-lin-10k-100k>

#pagebreak()

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8em,
    image("../../images/calibration/initial_conditions_500K.png", width: 100%),
    image("../../images/calibration/initial_conditions_1M.png", width: 100%),
  ),
  caption: flex-caption(
    [Stability plots: 500K and 1M.],
    [Online-user fraction over time for the three initial conditions, linear scale. Left: 500K network; right: 1M network.],
  )
) <fig-apx-stable-lin-500k-1m>
