#import "@preview/typslides:1.3.3": *

#let img(path, width: auto) = {
  image("images/" + path, width: width)
}

#let col2(a, b) = grid(columns: 2, gutter: 2.5em, a, b)
#let col3(a, b, c) = grid(columns: 3, a, b, c)
#let col4(a, b, c, d) = grid(columns: 4, a, b, c, d)

#blank-slide(back-color: rgb("#fff3e0"))[
  #set align(center)

  #text(size: 1.5em)[Appendix A: Structural Virality]
]

#slide(title: "Structural Virality — Definition")[
  Based on the Wiener index from mathematical chemistry, formalise structural virality $nu(T)$ for a cascade tree $T$ with $n > 1$ nodes:

  #v(0.3em)
  $ nu(T) = frac(1, n(n-1)) sum_(i=1)^n sum_(j=1)^n d_(i j) $

  where $d_(i j)$ is the shortest-path distance between nodes $i$ and $j$.

  #v(0.3em)
  *Three properties:*
  - For a fixed size, minimized on the star graph (pure broadcast, $nu approx 2$)
  - Increases with cascade depth for a fixed branching factor
  - Approximately independent of size for pure broadcasts

  #v(0.3em)
  #text(size: 0.8em)[Higher $nu$ → adopters are farther apart on average → multi-generational viral spread rather than one-to-many broadcast.]
]


#slide(title: "Structural Virality — Efficient Computation")[
  Naive computation of $nu(T)$ requires $O(n^2)$ time (all node pairs). Mohar & Pisanski (1988) showed a linear-time algorithm via subtree sizes.

  #v(0.3em)
  *Theorem 2 (Goel et al., Appendix A):* For tree $T$ with $n$ nodes, let $cal(S)$ be the set of all subtrees. Then:

  #v(0.15em)
  $ nu(T) = frac(2n, n-1) thin space bracket(frac(1, n) sum_(S in cal(S)) |S| - frac(1, n^2) sum_(S in cal(S)) |S|^2) $

  #v(0.25em)
  *Key insight — subtree moments:* A recursive DFS computes in $O(n)$:

  #v(0.15em)
  - `size` = total nodes in current subtree
  - `sum-sizes` = sum of sizes of all subtrees rooted within
  - `sum-sizes-sqr` = sum of squared sizes of all subtrees rooted within

  #v(0.25em)
  #text(size: 0.82em)[Algorithm 1 in the paper: `Subtree-Moments(T, r)` recurses over children, returns $(sigma, Sigma |S|, Sigma |S|^2)$, then `Average-Distance` applies the formula above. This enabled computing $nu(T)$ on cascades with millions of nodes.]
]

#blank-slide(back-color: rgb("#fff3e0"))[
  #set align(center)

  #text(size: 1.5em)[Appendix B: (3) - Data Analysis]
]

#slide(title: "Vuong's log-likelihood ratio test")[

  TODO: hi ha alguna chance de que ho preguntin

]

// --- SLIDE: Topology Extraction ---
#slide(title: "Topology Extraction", back-color: rgb("#fff3e0"))[
  #v(0.2em)
  #text(size: 0.9em, weight: "bold")[1.4 years of Bluesky follow events processed into a simulation-ready graph.]

  

  #v(0.3em)
  - $1.79 times 10^9$ raw firehose events consumed via Go producer-consumer pipeline
  - Filtered `app.bsky.graph.follow` events → $28.9$M users, $1.47 times 10^9$ active follow edges
  - Blocks excluded (moderation role, not information-propagation)

  #v(0.2em)
  *Forest Fire sampling* to preserve scale-free structure at tractable sizes:
  - $p_f = 0.5$, $p_b = 0.2$ — recursively burns outgoing and incoming neighbours
  - Preserves power-law degree distribution, community structure, and clustering
  - Output: induced subgraph (all edges between visited nodes) for simulation

  #v(0.2em)
  Three datasets used: *100K*, *500K*, and *1M* nodes (120M, 502M, 654M edges)
]


// --- SLIDE: Post Lifetime Analysis ---
#slide(title: "Post Lifetime Analysis", back-color: rgb("#fff3e0"))[
  #v(0.2em)
  #text(size: 0.9em, weight: "bold")[How long do posts live? Analysis over $15.3$M top-level posts.]

  #v(0.3em)
  #col2(
    [
      *Engagement counts*
      #v(0.15em)
      - 50.7% of posts receive *zero* engagement
      - Reposts: power-law with $alpha = 2.21$
      - Likes: $alpha = 2.15$, Replies: $alpha = 2.26$
      - All in the finite-mean, infinite-variance regime
    ],
    [
      *Lifetime distribution*
      #v(0.15em)
      - Two-component structure:
      - Body ($< 15.6$ h, ~75%): Weibull ($k = 0.53$)
      - Tail ($> 15.6$ h, ~25%): Pareto ($alpha = 2.16$)
      - Median lifetime: 3.8 h; $P_99$: 133 h (5.6 days)
    ],
  )

  #v(0.2em)
  #text(size: 0.8em)[Weibull $k < 1$ implies decreasing hazard rate — posts become *less* likely to die the longer they survive. Time-to-first engagement: replies fastest (median 5.9 min), reposts slowest (13.3 min).]
]

// --- SLIDE: Cascade Analysis (1) ---
#slide(title: "Cascade Analysis", back-color: rgb("#fff3e0"))[
  #v(0.2em)
  #text(size: 0.9em, weight: "bold")[Structural virality $nu$: distinguishing broadcast from genuine viral spread.]

  #v(0.3em)
  - Bluesky's AT Protocol includes a `via` field — the *exact* parent repost is known, no inference needed
  - $4.41$M cascades reconstructed from $25.4$M repost events ($approx 3$ min runtime)
  - Direct reposts (69.3%): user saw the original post
  - Via reposts (30.7%): user saw someone else's repost — the chain link

  #v(0.2em)
  *Three regimes:*
  #col3(
    align(center)[
      #text(size: 0.85em, weight: "bold")[Broadcast]
      $nu = 1.0$ — 54.7%
    ],
    align(center)[
      #text(size: 0.85em, weight: "bold")[Mixed]
      $1 < nu <= 3$ — 42.7%
    ],
    align(center)[
      #text(size: 0.85em, weight: "bold")[Viral]
      $nu > 3$ — 2.6%
    ],
  )
]

// --- SLIDE: Cascade Analysis (2) ---
#slide(title: "Cascade Analysis (2)", back-color: rgb("#fff3e0"))[
  #v(0.2em)
  #text(size: 0.9em, weight: "bold")[Bluesky is predominantly broadcast — but the viral tail is real.]

  #v(0.3em)
  #col2(
    [
      - Median $nu = 1.0$, mean $nu = 1.35$
      - Max $nu = 80.74$ (12,720 nodes, depth 235)
      - 73.4% of cascades have depth 1 — every reposter saw the original
      - $nu$ grows sub-linearly with cascade size: 1,000× larger cascade → only ~15× more viral
    ],
    [
      - Extreme virality is exponentially rare: above $nu = 2$, probability drops ~10× per unit
      - At $nu = 10$, fewer than 1 in 10,000 cascades remain
      - Deepest cascade: 235 hops — but even this is only $nu = 80$
      - *Bluesky cascades are wide, shallow trees — not long chains.*
    ],
  )

  #v(0.2em)
  #text(size: 0.8em)[These empirical distributions — repost $alpha = 2.21$, lifetime shape, and the $nu$ distribution — are the *calibration targets* the simulation must reproduce.]
]

// --- SLIDE: Parameter Densities ---
#slide(title: "Pareto — Session Duration")[
  #align(center)[
    #img("calibration/7-1_duration_pareto_params.png", width: 85%)
  ]
  #text(size: 0.75em)[Pareto $alpha$ (left) and $x_min$ (right) for session durations. Median $alpha = 2.47$, $x_min = 98$ s (1.6 min).]
]

#slide(title: "Pareto — Inter-Session Gap")[
  #align(center)[
    #img("calibration/7-1_gap_pareto_params.png", width: 85%)
  ]
  #text(size: 0.75em)[Pareto $alpha$ (left) and $x_min$ (right) for inter-session gaps. Median $alpha = 2.05$, $x_min = 5,806$ s (1.6 h).]
]

#slide(title: "Lognormal — Session Duration")[
  #align(center)[
    #img("calibration/7-1_duration_lognormal_params.png", width: 85%)
  ]
  #text(size: 0.75em)[Lognormal $mu$ (left) and $sigma$ (right) for session durations. Median $mu = 5.21$, $sigma = 0.63$ ($approx 3.1$ min central tendency).]
]

#slide(title: "Lognormal — Inter-Session Gap")[
  #align(center)[
    #img("calibration/7-1_gap_lognormal_params.png", width: 85%)
  ]
  #text(size: 0.75em)[Lognormal $mu$ (left) and $sigma$ (right) for inter-session gaps. Median $mu = 9.84$, $sigma = 0.96$ ($approx 5.2$ h central tendency).]
]

#slide(title: "Weibull — Session Duration")[
  #align(center)[
    #img("calibration/7-1_duration_weibull_params2.png", width: 85%)
  ]
  #text(size: 0.75em)[Weibull shape $k$ (left) and scale $lambda$ (right) for session durations. Median $k = 1.58$, $lambda = 258$ s (4.3 min). 24% have $k < 1$ (decreasing hazard).]
]

#slide(title: "Weibull — Inter-Session Gap")[
  #align(center)[
    #img("calibration/7-1_gap_weibull_params2.png", width: 85%)
  ]
  #text(size: 0.75em)[Weibull shape $k$ (left) and scale $lambda$ (right) for inter-session gaps. Median $k = 1.08$, $lambda = 35,229$ s (9.8 h). 46% have $k < 1$ (decreasing hazard — abandonment).]
]

#slide(title: "Power-Law — Inter-Post Creation Gaps")[
  #align(center)[
    #img("calibration/7-2_interpost_alpha_hist2.png", width: 85%)
  ]
  #text(size: 0.75em)[Power-law exponent $alpha$ for inter-post creation gaps ($N = 50{,}000$ users). Global mode: median $alpha = 1.80$ (infinite variance). Within-session mode: median $alpha = 2.39$.]
]

