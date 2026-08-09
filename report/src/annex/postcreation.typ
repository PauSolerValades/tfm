#import "../utils.typ": *

This appendix reports the goodness-of-fit attempts on `inter_post_creation`: the global gaps (without sessionization) fit a battery of parametric families, while the within-session gaps do not and are kept as an empirical distribution.

== Global Creation Distributions

For some of the approches descibed in this section, we need to characterize the process of post creation without sessionization, just the gaps from a post creation to the next one, disregarding the user.

The Firehose data described in @sec-data contains post creation and replies to another post. Those two will be considered the exact same nature of post as the simulation does not implement replies. Additionally, quotes are missing from the dataset as a data ingerstion known error, so they have been been ignored.

The fitting reuses the 8-candidate battery of @sec-cal-dist (MLE fits, closed-form KS/CvM/AD statistics, AIC selection). The population is the $2.12 times 10^6$ users with at least one session (see @sec-cal-sessions). Among them, only users with at least two post creations produce gaps ---$N$ posts yield $N-1$ consecutive gaps--- #todo[count: users with at least two post creations], and applying the same $n_"obs" >= 30$ criterion as @sec-cal-dist, the global quantity is fitted on the $176,217$ users with at least 30 gaps. The measurement produces $25.2 times 10^6$ global gaps (124k exact same-μs post duplicates dropped). @tbl-cal-interpost-family reports the AIC-best family composition of the global quantity.
#figure(
  table(
    columns: 8,
    align: (left, center, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [], table.vline(stroke: 0.5pt), [*Lognorm*], [*Power-law*], [*Weibull*], [*Fisk*], [*Gamma*], [*Exp*], [*Total*],
    table.hline(stroke: 0.5pt),
    [*Users*], [83,197], [41,960], [36,419], [14,535], [102], [4], [*176,217*],
    [*%*], [47.2%], [23.8%], [20.7%], [8.3%], [0.06%], [0.00%], [*100%*],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Fitted distribution of the global inter-post gaps.],
    [Fitted distribution per user for global gaps, sorted by descending share.],
  )
) <tbl-cal-interpost-family>

Unlike the session quantities of @sec-cal-dist, the global composition is lognormal-dominated (47.2%) and almost no exponential or gamma users exist. The gap magnitudes are heavy-tailed: median $599$ s (about 10 min), mean $4.3$ h, p99 $2.6$ days.

#figure(
  image("../../images/calibration/interpost_aic_margins_global.png", width: 100%),
  caption: flex-caption(
    [Post creations per session.],
    [Distribtuion of the $Delta"AIC"$ margin (best minus second-best candidate) per user per non-sessionized distributions, percent normalized and truncated at P99 for ease of visibility.],
  )
) <fig-cal-interpost-posts-per-session>

== Within-Session Goodness-of-fit
<anx-create-gof>

The within-session distribution, cannot be reported as families. Within gaps are bounded by the session duration (median session: $110$ s, @tbl-cal-session-stats), and on such a window the light-tailed candidates are likelihood-near-identical.

The criterion to discern which is the best fit is the Akaike Information Criterion, with Anderson-Darling as a second opinion. @fig-cal-interpost-aic-margin shows the AIC margin between the best and the runner-up fit for both quantities: the within-session mass sits in the $Delta"AIC" < 2$ ----the guess between any two distributions is worse than a coin toss--- while the lgobal being a far longer tail..

#figure(
    image("../../images/calibration/interpost_aic_margins_within.png"),
    caption: flex-caption(
    [AIC margin between best and runner-up fit.],
    [Distribtuion of the $Delta"AIC"$ margin (best minus second-best candidate) per user per non-sessionized distributions, percent normalized and truncated at P99 for ease of visibility.],
  )
) <fig-cal-interpost-aic-margin>

$Delta"AIC" < 2$ ---the coin-flip zone--- holds for $56.9%$ of within users (median margin 1.6), and AIC-best agrees with AD-best for only $18.3%$ of them ($25%$ at family level). The global quantity is healthier: $48%$ in the coin-flip zone, but only $24.8%$ of that ambiguity is cross-family (the rest is power-law sibling shuffling, absorbed by the family grouping).

The root cause is structural: the session truncation leaves the observable gaps too short and too few for a parametric fit ---the median session lasts $110$ s, within gaps have p90 = 281 s, and light-tailed families only separate at $T >= 900$ s.

Therefore, we cannot fit any distribution to this data with statistical verification. The within-session quantity is described by shape only, and @tbl-cal-interpost-within gives the pooled quantiles.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [], table.vline(stroke: 0.5pt), [*P25*], [*Median*], [*P90*], [*P99*],
    table.hline(stroke: 0.5pt),
    [*Value*], [33 s], [86 s], [281 s], [663 s],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Within-session inter-post gap quantiles.],
    [Quantiles of the pooled `interpost_within` distribution (11.1M gaps, 1M uniform subsample). The p99 approaches the longest sessions: the quantity is intrinsically ceiling-bound.],
  )
) <tbl-cal-interpost-within>


== Per-Pair Posts per Session and Within ECDFs
<apx-create-pairs>

Given a user's (session-duration, inter-session-gap) family pair, how do the count and the shape of within-session posting look? The following figures collect, for the 16 pairs of @tbl-cal-pair-dist with enough users, the posts-per-session distribution and the pooled within-gap ECDF of the pair (sorted by number of users).

This pair split is the fine-grained input of the simulation: a parametric law for the pooled within gaps of a pair is formally rejected, so the empirical per-pair ECDF is kept ---it already encodes exactly what the fits miss (the burst floor at 1--10 s and the kink at the session ceiling)--- and replaces the coarser per-global-family ECDFs: the simulation assigns each user their (duration, gap) pair and loads the matching `results/within_ecdf__<dur>__<gap>.txt`.

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__expon__weibull_min.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__expon__weibull_min.png"), 
  ),
  caption: [Exp $times$ Weibull (39,334 users)],
) <fig-interpost-pair-expon-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__weibull_min__weibull_min.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__weibull_min__weibull_min.png"), 
  ),
  caption: [Weibull $times$ Weibull (24,541 users)],
) <fig-interpost-pair-weibull-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__weibull_min__lognorm.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__weibull_min__lognorm.png"), 
  ),
  caption: [Weibull $times$ Lognorm (20,523 users)],
) <fig-interpost-pair-weibull-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__gamma__weibull_min.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__gamma__weibull_min.png"), 
  ),
  caption: [Gamma $times$ Weibull (20,371 users)],
) <fig-interpost-pair-gamma-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__lognorm__weibull_min.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__lognorm__weibull_min.png"), 
  ),
  caption: [Lognorm $times$ Weibull (19,570 users)],
) <fig-interpost-pair-lognorm-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__expon__lognorm.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__expon__lognorm.png"), 
  ),
  caption: [Exp $times$ Lognorm (19,078 users)],
) <fig-interpost-pair-expon-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__gamma__lognorm.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__gamma__lognorm.png"), 
  ),
  caption: [Gamma $times$ Lognorm (14,397 users)],
) <fig-interpost-pair-gamma-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__power_tail__weibull_min.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__power_tail__weibull_min.png"), 
  ),
  caption: [Power-law $times$ Weibull (13,825 users)],
) <fig-interpost-pair-power-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__lognorm__lognorm.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__lognorm__lognorm.png"), 
  ),
  caption: [Lognorm $times$ Lognorm (10,953 users)],
) <fig-interpost-pair-lognorm-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__weibull_min__power_tail.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__weibull_min__power_tail.png"), 
  ),
  caption: [Weibull $times$ Power-law (10,751 users)],
) <fig-interpost-pair-weibull-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__power_tail__lognorm.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__power_tail__lognorm.png"), 
  ),
  caption: [Power-law $times$ Lognorm (8,421 users)],
) <fig-interpost-pair-power-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__lognorm__power_tail.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__lognorm__power_tail.png"), 
  ),
  caption: [Lognorm $times$ Power-law (7,651 users)],
) <fig-interpost-pair-lognorm-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__gamma__power_tail.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__gamma__power_tail.png"), 
  ),
  caption: [Gamma $times$ Power-law (7,331 users)],
) <fig-interpost-pair-gamma-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__expon__power_tail.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__expon__power_tail.png"), 
  ),
  caption: [Exp $times$ Power-law (7,271 users)],
) <fig-interpost-pair-expon-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__power_tail__power_tail.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__power_tail__power_tail.png"), 
  ),
  caption: [Power-law $times$ Power-law (3,815 users)],
) <fig-interpost-pair-power-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/posts_per_session__weibull_min__fisk.png"), 
    image("../../images/annex/interpost_pairs/interpost_ecdf__weibull_min__fisk.png"), 
  ),
  caption: [Weibull $times$ Fisk (3,736 users)],
) <fig-interpost-pair-weibull-fisk>


== Per-Pair First-Post Offset ECDFs
<apx-offset-pairs>

Beyond the within-gap cadence, the first post of a session lands at a short offset from the session start (see @sec-cal-interpost and @fig-cal-offset-hist). The following figures collect, for the same 16 pairs of @tbl-cal-pair-dist with enough users, the pooled first-post offset ECDF of the pair, the empirical counterpart the simulation samples the first post of a session from.

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__expon__weibull_min.png"), 
  ),
  caption: [Exp $times$ Weibull (39,334 users)],
) <fig-offset-pair-expon-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__weibull_min__weibull_min.png"), 
  ),
  caption: [Weibull $times$ Weibull (24,541 users)],
) <fig-offset-pair-weibull-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__weibull_min__lognorm.png"), 
  ),
  caption: [Weibull $times$ Lognorm (20,523 users)],
) <fig-offset-pair-weibull-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__gamma__weibull_min.png"), 
  ),
  caption: [Gamma $times$ Weibull (20,371 users)],
) <fig-offset-pair-gamma-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__lognorm__weibull_min.png"), 
  ),
  caption: [Lognorm $times$ Weibull (19,570 users)],
) <fig-offset-pair-lognorm-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__expon__lognorm.png"), 
  ),
  caption: [Exp $times$ Lognorm (19,078 users)],
) <fig-offset-pair-expon-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__gamma__lognorm.png"), 
  ),
  caption: [Gamma $times$ Lognorm (14,397 users)],
) <fig-offset-pair-gamma-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__power_tail__weibull_min.png"), 
  ),
  caption: [Power-law $times$ Weibull (13,825 users)],
) <fig-offset-pair-power-weibull>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__lognorm__lognorm.png"), 
  ),
  caption: [Lognorm $times$ Lognorm (10,953 users)],
) <fig-offset-pair-lognorm-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__weibull_min__power_tail.png"), 
  ),
  caption: [Weibull $times$ Power-law (10,751 users)],
) <fig-offset-pair-weibull-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__power_tail__lognorm.png"), 
  ),
  caption: [Power-law $times$ Lognorm (8,421 users)],
) <fig-offset-pair-power-lognorm>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__lognorm__power_tail.png"), 
  ),
  caption: [Lognorm $times$ Power-law (7,651 users)],
) <fig-offset-pair-lognorm-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__gamma__power_tail.png"), 
  ),
  caption: [Gamma $times$ Power-law (7,331 users)],
) <fig-offset-pair-gamma-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__expon__power_tail.png"), 
  ),
  caption: [Exp $times$ Power-law (7,271 users)],
) <fig-offset-pair-expon-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__power_tail__power_tail.png"), 
  ),
  caption: [Power-law $times$ Power-law (3,815 users)],
) <fig-offset-pair-power-power>

#figure(
  grid(
    columns: 1,
    column-gutter: 0.8em,
    image("../../images/annex/interpost_pairs/offset_ecdf__weibull_min__fisk.png"), 
  ),
  caption: [Weibull $times$ Fisk (3,736 users)],
) <fig-offset-pair-weibull-fisk>
