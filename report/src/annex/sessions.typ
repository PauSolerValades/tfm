#import "../utils.typ": *

This appendix serves as the sessions extra information.

== Current Sessions Validity
<apx-sessions-def>

Despite the utility of the Bluesky Firehose, it is definetly not the best dataset for figuring out what a meaningfull section is.

Firehose #todo[check appropiately] is an event register of all the information that updates the state of the user regarding the platform ---in more techincal terms, that it updates the database. From this information we have data points that confim us that the user is online, as it has interacted with the platform at the time of the event.

Lets now define the most specific type of session we would be interested in obtaining to highligh the limitations of the Firehose for the ideal data, as well as proposing an experiment to obtain real data from the users using the Bluesky current features and funcitonalities.

#def(name: "Interaction Session")[
  An Interactive Session is the time the user has been online (connected to the platform) and checking _any_ type of content feed.
]

For this work is not rellevant if the user has been updating its profile, or messaging another user: the important information is for how long did the user see posts, how many posts did the user not interact with, and which ones did he interact with. This project works with the underlying ---and now made explicit--- assumption that the meaningful session interval is a subset of the session defined in the calibraion section, despite being not true to the maximum extent:
- If a user connect, checks the timeline for 3 minutes but does not interact with any post.
- If a user just check the feed, we just know the session from the first meaningful (like, repost or reply) with the first post. If that user has been some time checking but not liking, out sessions will be shorter (consistently biased) than the real counterpart.

For the puroposes of this work, the meaningfull sessions are considered to be equivalent as the normal sessions due to two factos:
- *Availability*: The firehose is the data available at the time.
- *Similiariy*: As consuming content from feeds is the main feature of the social network, it is reasonable to assume that users will be the majority of time checking those feeds. Therefore, we treat them to be the same and just as consuming feeds and content as an approximation.


== Alternative Methods
<apx-sessions-method>

To create the sessions, apart from both DBSCAN and HDBSCAN, the Tukey Fence method has also been investigated. Specifically, apart from the inter-user global session ---known as a platform threshold #todo[cite the shitty twitter session article]--- which has been discarded from the beginnig, the following sweeps have been executed and tried in order to disect the most appropiate parameters per each method:
- *Tukey's Fence*: multiplier $k in {1.5, 1.2, 1.7}$ on the inter-quartile range.
- *DBSCAN*: threshold $epsilon in {300, 600, 1200, 1800}$ seconds.
- *HDBSCAN*: minimum cluster size $"mc"_s in {2, 3, 5}$, minimum samples $m_s in {1, 2, 3}$, and spatial neighborhood radius $epsilon in {0, 60, 180, 300}$ seconds. That's 36 total executions.

The different parameters sweep was performed over the 5% user sample, which consisted of 106,392 users with 11.8M events.

== Tukey Discard

Tukey's fences @apx-method-session-tukey seemed, at first, a sensible approach to sessionization: unlike a global threshold, the boundary adapts to each user's own activity pattern. The sweep over $k in {1.2, 1.5, 1.7}$ produced the results in @tbl-tukey-discard, which expose the fundamental limitations of the method.

#figure(
  table(
    columns: 4,
    align: (center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*$k$*], [*Sessions*], [*Mean duration*], [*Sessions > 8 h*],
    table.hline(stroke: 0.5pt),
    [1.2], [1.81M], [6,594 s], [3.03%],
    [1.5], [3.38M], [7,669 s], [3.35%],
    [1.7], [1.63M], [8,340 s], [3.54%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Tukey's fence sweep over the multiplier $k$.],
    [Tukey's fence sweep over the multiplier $k$ on the full dataset. Session counts are not monotone in $k$ --- $k = 1.5$ yields nearly twice the sessions of $k = 1.2$, which is impossible on a fixed input --- and roughly 3--3.5% of sessions exceed 8 hours regardless of $k$.],
  )
) <tbl-tukey-discard>

The duration of the sessions is not compatible with expected session of microblogging social networks. Regardless of $k$, roughly 3--3.5% of the sessions produced exceed eight hours and the mean session duration hovers around two hours (6,594--8,340 s). This is structural, not a tuning artifact: for heavy and regular users ---precisely the population this work models--- the inter-event gaps are large, so their IQR spans hours or days and the threshold $Q_3 + k dot "IQR"$ reaches values at which nothing ever splits. Distinct visits are merged into single sessions of days-long duration, which no plausible interpretation of online/offline behaviour can justify.

The obvious remedy, capping the threshold, e.g. $tau = min(Q_3 + k dot "IQR", 1800)$ s, simply replaces the adaptive boundary with a constant one: for every user whose quartile-based threshold exceeds the cap ---exactly the heavy users that cause the problem--- the boundary collapses to the fixed cap, and the method degenerates into a global fixed threshold. In other words, the moment any minimum or maximum gap must be imposed, the method becames a DBSCAN directly, with that bound playing the role of $epsilon$ and the quartile machinery contributing nothing but computation. Since the adaptive component cannot survive without an external threshold, Tukey's fences offer no advantage over the density-based methods.

Tukey's fences were consequently discarded in favour of DBSCAN and HDBSCAN, the density-based methods described above.

== HDBSCAN Discard
<apx-session-hdbscan>

HDBSCAN was the most promisng one, and the one that had the most parameters to control. It was quckly found that $m_s >= 2$ and $"mc"_s >= 3$ degenerated the problem with very high singleton rates ($28-52%$), which essentially discards to much data as not sessionable. In the same reasoning, $epsilon=0$ are single-linkage event variants, which makes no sense for this problem once again.

The problem with the `mcs=2` and `ms=1` is that the second sweep to merge clusters overmerged regarding any value of $epsilon$. @tbl-hdbscan-overmerge shows the duration metrics obtained across the $epsilon$ sweep, and the over-merging is visible in every row: larger $epsilon$ merges progressively more distinct visits into single sessions.

#figure(
  table(
    columns: 6,
    align: (center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*$epsilon$ (s)*], [*Sessions*], [*Median*], [*Mean*], [*> 1 h*], [*> 8 h*],
    table.hline(stroke: 0.5pt),
    [0], [4.38M], [17 s], [1,049 s], [3.09%], [0.78%],
    [60], [2.53M], [83 s], [1,865 s], [5.66%], [1.42%],
    [180], [1.90M], [183 s], [2,609 s], [7.99%], [1.97%],
    [300], [1.70M], [250 s], [2,994 s], [9.23%], [2.25%],
    [600], [1.48M], [371 s], [3,567 s], [11.38%], [2.63%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [HDBSCAN ($"mc"_s = 2$, $m_s = 1$) duration metrics across the $epsilon$ sweep.],
    [HDBSCAN ($"mc"_s = 2$, $m_s = 1$) session duration metrics across the $epsilon$ sweep, computed over the 5% user sample],
  )
) <tbl-hdbscan-overmerge>


he over-merging is visible across every metric: as $epsilon$ grows, the number of sessions decreases monotonically, while the median duration, the mean duration, and the share of sessions exceeding one and eight hours all increase. At $epsilon = 600$ s, more than one in nine sessions exceeds an hour and the mean session duration approaches an hour --- figures as implausible as those produced by the Tukey fences. The trend holds at every value of $epsilon$ explored, including the smallest ones, so the choice of configuration must be validated against DBSCAN rather than taken from this sweep alone.


== DBSCAN Parameters
<apx-session-dbscanparams>

This sections argues why the selected parameters for DBSCAN are the following. On they contrary as Tukey's fences with the distance between events, DBSCAN is able to detect singletons with the `min_samples` parameter, which is set to 2 as well as HDBSCAN: a session must have at least two events.

The $epsilon$ ---on the contrary of HDBSCAN--- here represents an actual minimum session length: that is the reason why the values are relatively lower, as they represent real minimum resting periods between sessions. @tbl-dbscan-sweep shows the results per $epsilon$ value.

#figure(
  table(
    columns: 7,
    align: (center, center, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*$epsilon$ (s)*], [*Sessions*], [*Median*], [*Mean*], [*< 1 min*], [*> 1 h*], [*> 8 h*],
    table.hline(stroke: 0.5pt),
    [5], [8.37M], [3 s], [5 s], [99.97%], [0.00%], [0.00%],
    [15], [6.20M], [10 s], [14 s], [99.27%], [0.00%], [0.00%],
    [30], [4.85M], [19 s], [30 s], [95.35%], [0.00%], [0.00%],
    [60], [3.75M], [35 s], [60 s], [85.84%], [0.00%], [0.00%],
    [300], [2.25M], [109 s], [230 s], [62.77%], [0.07%], [0.00%],
    [600], [1.90M], [162 s], [383 s], [57.22%], [0.36%], [0.00%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [DBSCAN ($m_"pts" = 2$) duration metrics across the $epsilon$ sweep.],
    [DBSCAN ($m_"pts" = 2$) session duration metrics across the $epsilon$ sweep, computed over the 5% user sample (106,392 users, 11.8M events). At the burst scale (5--60 s) sessions are overwhelmingly shorter than one minute, with 52--80% flagged as singletons; only for $epsilon >= 300$ s do sessions reach plausible durations, and the share exceeding one hour remains negligible ($<= 0.36%$).],
  )
) <tbl-dbscan-sweep>

As is clearly seen in the table, the only parameters that satisfy every requirement are the last two rows, $epsilon in {300, 600}$, as all the others produce sessions either too small and fragmented or too big.

To check the veracity of such a big $epsilon$, table @tbl-short-sessions shows the distribution of the events in sessions of less than one minute.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Configuration*], [*1 event*], [*2 events*], [*3--4 events*], [*5--9 events*], [*10+ events*],
    table.hline(stroke: 0.5pt),
    [DBSCAN $epsilon = 300$], [63.2%], [21.6%], [11.3%], [3.5%], [0.5%],
    [DBSCAN $epsilon = 600$], [63.4%], [21.4%], [11.2%], [3.5%], [0.5%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [Event composition of sessions shorter than one minute.],
    [Share of sessions shorter than one minute containing 1, 2, 3--4, 5--9 or 10+ events, for the two DBSCAN plateau configurations. Sub-minute sessions are overwhelmingly isolated events and pairs; dense bursts of 10+ events are at most 0.5%.],
  )
) <tbl-short-sessions>

Short DBSCAN sessions are honestly flagged isolated events and pairs — not hidden dense activity (10+ event bursts ≤ 1%). HDBSCAN's short sessions, by contrast, are mostly 2–4 event micro-clusters carved from sparse regions (56% at e300) — the same gluing mechanism that produces its 20h tail.

Another very strong point in DBSCAN against HDBSCAN is that the first embraces the cutoff as a necessary part of the definition (left panel of @fig-session-gaps), while the latter has noise points arbitrarily close to the definitions (right panel of @fig-session-gaps). This would not be a problem if the sessions obtained with HDBSCAN showed a more clean behaviour, but it is not the case as showcased in @apx-session-hdbscan.

#figure(
  grid(
    columns: (1fr, 1fr),
    column-gutter: 1em,
    figure(
      image("../../images/annex/hist_gap_dbscan_e300_ms2.png", width: 100%),
      caption: [Inter-session gap histogram for DBSCAN ($epsilon = 300$ s, $m_"pts" = 2$).],
    ),
    figure(
      image("../../images/annex/hist_gap_hdbscan_mcs2_ms1_e300.png", width: 100%),
      caption: [Inter-session gap histogram for HDBSCAN ($"mc"_s = 2$, $m_s = 1$, $epsilon = 300$).],
    ),
  ),
  caption: flex-caption(
    [Inter-session gap distributions for the DBSCAN and HDBSCAN configurations.],
    [Inter-session gap histograms. DBSCAN exhibits a clean lower edge at the cutoff; HDBSCAN admits gaps arbitrarily close to zero, because noise points can sit directly adjacent to clusters.],
  )
) <fig-session-gaps>

== Stability

A sessionization parameter is only defensible if the output is stable under small perturbations of the parameter: a configuration that produces wildly different sessions for a slight change of $epsilon$ cannot support any downstream conclusion. To quantify this, @tbl-dbscan-stability compares the per-user session counts of the plateau and cliff configurations, using the stability analysis of the data-analysis repository @soler2025bskydata.

#figure(
  table(
    columns: 6,
    align: (left, center, center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Comparison*], [*Pearson $r$*], [*Exact match*], [*Median rel. diff*], [*P90 rel. diff*], [*Session $Delta$*],
    table.hline(stroke: 0.5pt),
    [$epsilon = 300$ vs $600$ s], [0.975], [54.9%], [0.000], [$<= 0.25$], [+18.5%],
    [$epsilon = 60$ vs $300$ s], [0.902], [27.7%], [0.231], [---], [+66.8%],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [DBSCAN parameter stability.],
    [Per-user session-count stability between DBSCAN configurations, computed over the 5% user sample. Pearson $r$, exact-match share and median/P90 relative difference of per-user session counts; the last column reports the session-count change of the first configuration relative to the second.],
  )
) <tbl-dbscan-stability>

Within the plateau, $epsilon = 300$ s and $epsilon = 600$ s produce nearly identical per-user session counts: Pearson $r = 0.975$, $54.9%$ of users have exactly the same number of sessions, and the median relative difference is zero. The remaining +18.5% of sessions at $epsilon = 300$ is the mechanical absorption of the gaps in the 300--600 s window: a gap in that range merges two sessions at $epsilon = 600$ but splits them at $epsilon = 300$. This is the intended behaviour of the parameter, not instability.

Crossing from the burst scale into the session scale, by contrast, reshapes the output: between $epsilon = 60$ s and $epsilon = 300$ s the exact-match share collapses to $27.7%$ and the median relative difference rises to 0.231, with $epsilon = 60$ s producing 66.8% more sessions. The discontinuity between 60 s and 300 s is the boundary between intra-burst structure (typing-speed micro-sessions) and true online/offline structure ---precisely the cliff observed in @tbl-dbscan-sweep.

As an internal consistency check, the DBSCAN clusters reproduce the fixed-threshold statistics of the same cutoffs to the decimal (median 109/162 s, mean 230/383 s, P99 1715/2932 s for 300/600 s). This confirms that DBSCAN with $m_"pts" = 2$ is, by construction, the fixed-gap method plus noise flagging: the global-threshold baseline dismissed earlier is DBSCAN with noise detection turned off, so no separate method needs to be justified.

Both plateau configurations are therefore stable, and the choice between them rests on error asymmetry. A split creates two short adjacent sessions ---visible and correctable downstream--- while a merge stitches a real absence into "online" time, silently corrupting every duration statistic. The conservative splitter is preferable, which selects $epsilon = 300$ s.

== Limitations of DBSCAN

As stated in the first paragraph of @sec-method-session, a density based approach is probably the most sophisicated method to apply here, and it carries some limitations.

*Global Threshold*: DBSCAN applies the same cutoff to every user: any two consecutive events closer than $epsilon = 300$ s always belong to the same session, for all users alike. This is an explicit tradeoff, not a per-user optimum: the only per-user adaptive attempt, Tukey's fences, failed empirically (see @apx-session-hdbscan), and HDBSCAN, despite its more sophisticated machinery, is as global as DBSCAN. A per-user boundary could probably be estimated in principle ---for instance with a two-state hidden Markov model over the inter-event gaps--- but that is a line of modelling deliberately not pursued in this work. $epsilon$ therefore represents the minimum resting period between sessions, identical for every user.

*Zero-duration sessions*: the zero-duration sessions observed in the metrics are almost entirely singletons (38.9% of sessions): a singleton is a single flagged event whose span is zero by construction. Genuine multi-event sessions of zero duration are essentially nonexistent (12 out of 3.9M sessions); the rare occurrences come from two events stamped within the same instant, a behaviour traced to scripted mass-follow actions that emit whole batches under one identical `createdAt` (1.1% of events, 95% of which are follows), which the clustering collapses to a single point and flags as a singleton. #todo[verify numbers with starrocks system, this is duckdb]

*Edges Censored*: we cannot count the time the user spends before and after interacting, more than a dataset problem, but worth menctioning  that the algorithm does not try to correct that. The assumption is that is such a small time that can be considered negligible.

== Best-Fit Family Composition vs. Observation Cutoff

#todo[Reread and review]
The choice of the "active enough user" threshold is not neutral. @tbl-composition-cutoff shows how the best-fit distribution family composition changes with the minimum number of observations required per user, for session durations and for inter-session gaps. Below roughly 20 observations the model selection is unreliable and systematically inflates the power-law family: with three points, a power law can fit anything, so it wins AIC spuriously. For session durations the composition stabilises around 15--16% power-law once the cutoff reaches 20--30 observations, which justifies the $n_"obs" > 30$ criterion applied throughout the distribution analysis. The gap side, by contrast, keeps shifting with the cutoff ---power-law resurges for very active users (65.2% at $n_"obs" > 200$), and the lognormal family dominates at the extreme cutoffs, where the number of qualifying users collapses to a handful (78 at $n_"obs" > 500$, 9 at $> 1000$ on the duration side). The composition therefore describes the activity stratum under study, not a single universal law.

#figure(
  [
  #align(center, text(weight: "bold")[Session duration])
  #table(
    columns: 17,
    align: (left, center, center, center, center, center, center, center, center, center, center, center, center, center, center, center, center),
    stroke: none,
    inset: (x: 2pt, y: 1.5pt),
    table.hline(stroke: 0.8pt),
    [*Family*], [*0*], [*5*], [*10*], [*15*], [*20*], [*25*], [*30*], [*40*], [*50*], [*75*], [*100*], [*200*], [*300*], [*500*], [*750*], [*1000*],
    table.hline(stroke: 0.5pt),
    [*Power-law*], [59.1], [34.1], [21.7], [17.6], [16.0], [15.2], [14.8], [14.2], [14.0], [13.7], [13.4], [12.3], [16.5], [25.6], [25.0], [22.2],
    [*Weibull*], [6.5], [11.1], [15.1], [18.1], [20.6], [22.8], [24.7], [28.2], [31.1], [37.4], [42.3], [54.5], [44.9], [12.8], [5.0], [0],
    [*Lognorm*], [6.4], [11.2], [14.7], [15.7], [15.7], [15.3], [14.7], [13.8], [12.8], [11.1], [9.8], [9.0], [24.0], [43.6], [55.0], [66.7],
    [*Gamma*], [5.5], [9.5], [12.9], [14.9], [16.3], [17.4], [18.3], [19.4], [20.4], [21.8], [22.4], [20.6], [13.8], [17.9], [15.0], [11.1],
    [*Exp*], [22.4], [34.0], [35.6], [33.6], [31.4], [29.4], [27.5], [24.4], [21.6], [16.0], [12.2], [3.6], [0.8], [0], [0], [0],
    table.hline(stroke: 0.8pt),
  )
  #v(0.8em)
  #align(center, text(weight: "bold")[Inter-session gap])
  #table(
    columns: 17,
    align: (left, center, center, center, center, center, center, center, center, center, center, center, center, center, center, center, center),
    stroke: none,
    inset: (x: 2pt, y: 1.5pt),
    table.hline(stroke: 0.8pt),
    [*Family*], [*0*], [*5*], [*10*], [*15*], [*20*], [*25*], [*30*], [*40*], [*50*], [*75*], [*100*], [*200*], [*300*], [*500*], [*750*], [*1000*],
    table.hline(stroke: 0.5pt),
    [*Power-law*], [46.9], [30.3], [21.7], [17.9], [16.2], [15.8], [16.1], [17.9], [20.7], [29.0], [37.7], [65.2], [66.7], [39.5], [24.6], [11.6],
    [*Weibull*], [40.5], [52.7], [58.1], [59.6], [59.2], [57.8], [55.7], [50.9], [45.4], [32.1], [21.2], [4.0], [5.7], [10.7], [8.1], [4.3],
    [*Lognorm*], [12.5], [16.9], [20.1], [22.5], [24.6], [26.4], [28.1], [31.1], [33.8], [38.7], [40.9], [30.0], [24.4], [37.3], [44.6], [52.4],
    [*Gamma*], [0], [0], [0], [0], [0], [0.1], [0.1], [0.1], [0.1], [0.2], [0.3], [0.8], [3.3], [12.5], [22.7], [31.7],
    [*Exp*], [0], [0], [0], [0], [0], [0], [0], [0], [0], [0], [0], [0], [0], [0], [0], [0],
    table.hline(stroke: 0.8pt),
  ),
  ],
  caption: flex-caption(
    [Best-fit family composition vs observation cutoff.],
    [Share of users (in %) whose best-fit family wins at each observation cutoff $c$ (columns; users with $n_"obs" > c$), for session durations (top) and inter-session gaps (bottom); values below 0.05% are shown as 0. The number of qualifying users collapses from $1.46 times 10^6$ to 9 (duration) as $c$ grows.],
  )
) <tbl-composition-cutoff>

== Inside the Power-Law Family
<apx-powerlaw-breakdown>

The power-law family of @tbl-cal-dist-family groups three sibling candidates: the Generalized Pareto Distribution (GPD), the Lomax (Pareto Type II), and the Pareto Type I. The GPD and the Lomax are exact reparametrizations of one another on a zero-based support, so the AIC choice between them is partly arbitrary ---on simulated data the two cross-confuse freely--- and their split should not be interpreted. The Pareto Type I, by contrast, frees the lower bound: its threshold is fixed at the observed minimum $hat(theta) = min(x)$ (the boundary MLE, counted as an estimated parameter in the AIC penalty), so it can represent data bounded away from zero that a zero-based family cannot express. @tbl-powerlaw-breakdown reports how the power-law users of @tbl-cal-dist-family split among the three siblings.

#figure(
  table(
    columns: 5,
    align: (left, right, right, right, right),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Sibling*], [*Duration users*], [*%*], [*Gap users*], [*%*],
    table.hline(stroke: 0.5pt),
    [GPD], [19,955], [55.4%], [10,216], [22.0%],
    [Lomax], [7,070], [19.6%], [35,454], [76.3%],
    [Pareto I], [8,996], [25.0%], [774], [1.7%],
    table.hline(stroke: 0.5pt),
    [*Total*], [*36,021*], [*100%*], [*46,444*], [*100%*],
    table.hline(stroke: 0.8pt),
  ),
  caption: flex-caption(
    [AIC-winner split inside the power-law family.],
    [Number and share of power-law users whose AIC winner is each sibling distribution, for session durations and inter-session gaps. The GPD/Lomax split is not interpretable (reparametrizations of one another); the Pareto I column is, through its non-zero threshold.],
  )
) <tbl-powerlaw-breakdown>

The Pareto I column carries information about the support of the data. On gaps ---shifted by $-epsilon$ and therefore zero-based by construction--- the Pareto I almost never wins (1.7% of power-law users): the non-zero threshold has nothing to explain, confirming that shifted gaps really do start at zero. On durations it wins for a quarter of power-law users (9.0k users): those sessions are genuinely bounded away from zero. This asymmetry is the empirical justification for keeping all three siblings in the battery instead of collapsing them into a single GPD candidate: the redundant pair costs nothing to fit, and the third sibling answers a question the other two cannot.

== Per-Pair Parameter Histograms
<anx-session-pairhist>

For reference, this section collects the per-pair parameter histograms of all 22 observed (duration, gap) family pairs, sorted by the share of users they represent. No analysis is intended here; the interpretation is given in @sec-cal-acrossuser.

#figure(
  image("../../images/annex/pair_params/expon__weibull_min.png", width: 100%),
  caption: [Exp $->$ Weibull (16.3%)],
) <fig-hist-expon-weibull>

#figure(
  image("../../images/annex/pair_params/weibull_min__weibull_min.png", width: 100%),
  caption: [Weibull $->$ Weibull (10.0%)],
) <fig-hist-weibull-weibull>

#figure(
  image("../../images/annex/pair_params/weibull_min__lognorm.png", width: 100%),
  caption: [Weibull $->$ Lognorm (8.7%)],
) <fig-hist-weibull-lognorm>

#figure(
  image("../../images/annex/pair_params/gamma__weibull_min.png", width: 100%),
  caption: [Gamma $->$ Weibull (8.3%)],
) <fig-hist-gamma-weibull>

#figure(
  image("../../images/annex/pair_params/expon__lognorm.png", width: 100%),
  caption: [Exp $->$ Lognorm (8.1%)],
) <fig-hist-expon-lognorm>

#figure(
  image("../../images/annex/pair_params/power_tail__weibull_min.png", width: 100%),
  caption: [Power-law $->$ Weibull (7.5%)],
) <fig-hist-power-weibull>

#figure(
  image("../../images/annex/pair_params/lognorm__weibull_min.png", width: 100%),
  caption: [Lognorm $->$ Weibull (7.1%)],
) <fig-hist-lognorm-weibull>

#figure(
  image("../../images/annex/pair_params/gamma__lognorm.png", width: 100%),
  caption: [Gamma $->$ Lognorm (6.1%)],
) <fig-hist-gamma-lognorm>

#figure(
  image("../../images/annex/pair_params/weibull_min__power_tail.png", width: 100%),
  caption: [Weibull $->$ Power-law (5.6%)],
) <fig-hist-weibull-power>

#figure(
  image("../../images/annex/pair_params/power_tail__lognorm.png", width: 100%),
  caption: [Power-law $->$ Lognorm (4.5%)],
) <fig-hist-power-lognorm>

#figure(
  image("../../images/annex/pair_params/lognorm__lognorm.png", width: 100%),
  caption: [Lognorm $->$ Lognorm (4.4%)],
) <fig-hist-lognorm-lognorm>

#figure(
  image("../../images/annex/pair_params/gamma__power_tail.png", width: 100%),
  caption: [Gamma $->$ Power-law (3.7%)],
) <fig-hist-gamma-power>

#figure(
  image("../../images/annex/pair_params/expon__power_tail.png", width: 100%),
  caption: [Exp $->$ Power-law (3.6%)],
) <fig-hist-expon-power>

#figure(
  image("../../images/annex/pair_params/lognorm__power_tail.png", width: 100%),
  caption: [Lognorm $->$ Power-law (3.4%)],
) <fig-hist-lognorm-power>

#figure(
  image("../../images/annex/pair_params/power_tail__power_tail.png", width: 100%),
  caption: [Power-law $->$ Power-law (2.8%)],
) <fig-hist-power-power>

#figure(
  image("../../images/annex/pair_params/power_tail__gamma.png", width: 100%),
  caption: [Power-law $->$ Gamma (0.01%)],
) <fig-hist-power-gamma>

#figure(
  image("../../images/annex/pair_params/lognorm__gamma.png", width: 100%),
  caption: [Lognorm $->$ Gamma ($<$0.01%)],
) <fig-hist-lognorm-gamma>

#figure(
  image("../../images/annex/pair_params/weibull_min__gamma.png", width: 100%),
  caption: [Weibull $->$ Gamma ($<$0.01%)],
) <fig-hist-weibull-gamma>

#figure(
  image("../../images/annex/pair_params/gamma__gamma.png", width: 100%),
  caption: [Gamma $->$ Gamma ($<$0.01%)],
) <fig-hist-gamma-gamma>

#figure(
  image("../../images/annex/pair_params/weibull_min__expon.png", width: 100%),
  caption: [Weibull $->$ Exp ($<$0.01%)],
) <fig-hist-weibull-expon>

#figure(
  image("../../images/annex/pair_params/lognorm__expon.png", width: 100%),
  caption: [Lognorm $->$ Exp ($<$0.01%)],
) <fig-hist-lognorm-expon>

#figure(
  image("../../images/annex/pair_params/expon__gamma.png", width: 100%),
  caption: [Exp $->$ Gamma ($<$0.01%)],
) <fig-hist-expon-gamma>

== How to Obtain a Better Dataset
<apx-sessions-dataset>

Explain that if you create a better appview, you can get information from everything, and the second next thing (and more feasible) is to create a feed that is served by you, therfore you will know exactly what's happening there.

#todo[actually finish]

