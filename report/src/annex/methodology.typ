#import "../utils.typ": *
#import "@preview/lovelace:0.3.0": pseudocode-list

This sections addresses methodological issues and concerns that, while extremely important, had to be moved into the appendix due to lenght constraints.

== Random Number Generation
<apx-method-rng>

#comment[This takes too long, i think we can safly add a methodology appendix with this explained and treat the RNG as an external library, despite being written from scratch]

This section covers the implementations of the Random Number Generators needed in the main simulation, as Zig did not have a library of distributions. The distributions library has been published under the MIT license and its source available @soler2025distributions


=== Ziggurat Algorithm

The generation of random variates for continuous distributions, specifically the Normal, Exponential and Pareto distributions, relies on the highly optimized Ziggurat algorithm @marsaglia2000ziggurat. This method is a form of rejection sampling that overlays the target probability density function (PDF) with a set of $n=256$ horizontal rectangles (named after the Mesopotamian ziggurat temples for their tiered resemblance) of equal area, constructed such that they tightly bound the distribution curve.

Our implementation in Zig heavily leverages compile-time evaluation (`comptime`) to specialize the algorithm identically for both `f32` and `f64` precision without runtime overhead. The core optimization focuses on minimizing calls to the pseudo-random number generator (PRNG). Instead of requiring two distinct random values—one to select a rectangle and another to sample a point within it—a single 64-bit random integer is generated (or 32-bit for `f32`).

From this single random word, two values are extracted with zero PRNG overhead:
1. The lowest 8 bits are masked (`bits & 0xff`) to uniformly select the index $i$ of one of the 256 precomputed rectangles.
2. The remaining 52 bits are shifted and directly utilized as the mantissa of an IEEE 754 floating-point number @ieee2019floating, @goldberg1991floating.

To construct the uniform floating-point value efficiently, the integer mantissa is bitwise OR-ed with a predefined exponent mask. For symmetric distributions like the Normal, the exponent is chosen such that the resulting float falls into the interval $[2, 3)$. Subtracting 3 then shifts the domain to $[-1, 1)$. For asymmetric distributions like the Exponential, the exponent mask places the float in $[1, 2)$, and subtracting an offset near 1 yields a uniform variate in $[0, 1)$.

This uniformly distributed value $u$ is scaled by the $x$-coordinate boundary of the selected rectangle $i$, producing a candidate sample $x = u \cdot x_i$. If the candidate falls strictly within the core of the rectangle ($|x| < x_{i+1}$), it is immediately accepted. This fast-path covers approximately 99% of all generation requests and bypasses costly mathematical operations.

When a candidate falls outside the fast-path core, two edge cases are handled:
- *Boundary Cases:* If $i > 0$ and the sample is in the wedge between rectangles, an additional random draw evaluates the exact PDF to deterministically accept or reject the candidate.
- *Tail Cases:* If $i = 0$, the sample lies in the infinite tail of the distribution. A specialized `zeroCase` function handles this tail recursively. 
 - *Exponential* distribution, it evaluates the inverse transform @devroye1986nonuniform shifted by the rightmost boundary $R$, yielding $R - \ln(U)$. 
 - *Normal* distribution, it implements Marsaglia's tail generation, looping to draw values until $-2y < x^2$ is satisfied, and appropriately shifting the result by $R$.


=== Categorical Distribution
<sec-method-rng-categorical>

The categorical distribution models discrete random variables that can take on one of $k$ possible categories, each with a specific probability. In our Zig implementation, a categorical distribution is initialized with an array of distinct items (`data`) and their corresponding probabilities (`weights`). During initialization, an accumulator array (`acc`) is computed that stores the cumulative sum of the
given probabilities.

To sample from this distribution, we employ a standard inverse transform method @devroye1986nonuniform: a uniform floating-point value $u in [0, 1)$ is drawn and compared linearly against the cumulative weights array until a value satisfying $u <= text("acc")[i]$ is found, at which point the category at index $i$ is returned.

While theoretically faster alternatives like the Alias Method @walker1977alias exist --—capable of sampling in $O(1)$ time after a linear $O(k)$ setup—-- they introduce additional memory overhead and initialization complexity. For the context of this simulation, where $k$ is typically very small (e.g., modeling a handful of user action types), the performance difference is strictly negligible. Thus, we have opted for the linear search approach due to its simplicity and cache locality.

However, to optimize the performance of the linear search, the following convention has been maintained when constructing the distributions: the categories must always be sorted by their probability in descending order. By placing the most probable outcomes at the beginning of the arrays, the cumulative sum grows rapidly, maximizing the chance that the linear search terminates in the very first iterations, thereby achieving near $O(1)$ empirical performance.


=== Pareto Distribution

The Pareto Distribution is fundamental when talking about social networks, as its the distribution associated with the power-law. It's defined by two parameters, shape $alpha$ and scale $x_m$, and has the following density and cumulative density functions:

$ f(x | alpha, x_m ) = cases(frac(alpha x_m^alpha, x^(alpha + 1)) & "if" x >= x_m, 0 & "if" x < x_m )  $

$ F(x | alpha, x_m) = cases(
  1 - (frac(x_m, x))^alpha & "if" x >= x_m,
  0 &"if" x < x_m
)
$ 

To sample from it we've used the following relationship @casella2002statistical: a random variable $X$ follows a $"Pareto"(alpha, x_m)$ distribution when $Y ~ "Exp"(1)$ and

$ X ~ x_m · exp{Y/alpha} $

therefore being as efficient as generating an exponential with the ziggurat algorithm.

=== Empirical Cumulative Distirbution Function
<sec-method-rng-ecdf>

Explaination of the dual categorical or binned categorical

=== Lognormal

It's just $X = exp(Y) quad Y ~ N(mu, sigma^2)$

=== Weibull

We use the inverse sampling method (make a small menction) but instead of using expensive log we reuse ziggurat

$ X = lambda · -ln( U ) ^(1/k) = lambda · E^(1/k) $

=== Gamma

This is the only complicated algorithm to describe. It uses that a normal is almost a gamma most of the time, and it's a ziggurat style algorithm.
 
=== Goodness-of-fit Test

To test the implementations of the above distributions

#todo[to make this appropiately, i implemented the Kolmogorov-Smirnoff test for the upper distributions in zig.]


== Distribution Fitting
<apx-method-gof>

This section addresses tools and concepts used in distribution fitting and other related concerns.

== Pareto Family of Distributions

Pareto is not just a distribution, but a familiy of them. In the distribution fitting list we are including three types of Paretos, which we describe ---and argue the need of--- in this section.

Paretos are organized in 6 types of distributions: Paretos I to IV, with Pareto II with location 0 has a special name, and then the Generalized Pareto Distribution. This section will explain Pareto I ---the standard one parameter power-law---, Pareto II with $mu=0$ ---also known as Lomax--- and the Generalized Pareto Distribution.

=== Generalized Pareto Distribution

This section is sourced from the original article by James Pickands #todo[find the proper reference].

The Generalized Pareto Distribution ---GPD from now on--- is a family of continous probability distributions, and it's specified by three parameters: location $mu$, scale $theta$ and shape $alpha$, although it can be seen with several reparametrizations. It has a Cumulative Probablity Distribution

$

  F(x| mu, theta, alpha) = cases(
    1 - (1 + alpha frac(x - mu, theta))^(-1/alpha) "if" alpha != 0,
    1 - exp(- frac(x - mu, theta)) "if" alpha = 0
  )
$

where $mu, alpha in RR$ and $theta in RR^+$. The support changes according to the shape of the distribution: if $alpha >= 0$, $x >= mu$, and $mu <= x <= mu - theta/alpha$ otherwise.

The shape parameter $alpha$ also changes the interpretation of the data a lot:

$
  cases(
    "power-law" gamma = 1/alpha &"if" alpha > 0,
    "light tail" ~ "Exp" &"if" alpha -> 0,
    "bounded tail" x <= -theta/alpha "limit" &"if" alpha < 0,
  )
$

This function has Pareto and Lomax as specific cases, see their respective sections (@apx-method-gof-lomax and @apx-method-gof-lomax respectively) to know them.

=== Pareto
<apx-method-gof-pareto>

Pareto ---known as Type I Pareto--- has the following cumulative density funciton:

$
  F(x | theta, alpha) = 1 - (frac(x, theta))^(-alpha)
$

with $theta > 0, alpha > 0$, where the scale parameter is also sometimes referred to $x_"min"$. The support is $x in [theta, inf]$.

This distribution is rellevant due to the defined support. If the data to be fitted can start at a certain distance of zero, will be detected by this distribution easily.

Pareto is a specific case of $"GPD"(mu, sigma, xi)$ with $mu = theta, xi = 1/alpha, sigma = theta / alpha$.

=== Lomax (Pareto II)
<apx-method-gof-lomax>

Pareto II is in essence the same as Pareto I, but with the support depending on the location parameter instead of the scale. It has the following cumulative density function:

$
  F(x | mu, theta, alpha) = 1 - (1 + frac(x-mu, theta))^(-alpha)
$

with $mu in RR$ and $alpha > 0, theta > 0$. The support is $x >= mu$. We call this a Lomax distribution when $mu=0$, and therefore it's cdf is

$
  F(x | theta, alpha) = 1 - (1 + frac(x, theta))^(-alpha)
$

and the support is $x>=0$, which makes is a perfect candidate to fit processes that generate only positive quantities, such is the case of this project with time intervals.


Lomax is a specific case of $"GPD"(mu, sigma, xi)$ with $mu=0, xi = 1/alpha, sigma = theta / alpha$

=== Vuong's Test
<apx-method-gof-vuong>

In social networks, power-laws ---data following a Pareto distribution--- appears usually due to the networks own nature and growth. Despite appearing naturally, one must be carefull to classify them as another very common heavy-tail function: the lognormal.

The `powerlaw` @alstott2014powerlaw package provides `fit.distribution_compare()`, which implements Vuong's log-likelihood ratio test @vuong1989likelihood to discriminate between the Pareto and the lognormal distribution. @code-powerlaw-or-lognormal showcases how the function is used, where a negative $R$ indicated the lognormal is a better fit, and a positive one otherwise. The $p$-value determines whether the difference is statistically significant.

#code(caption: "Vuong's log-likelihood ratio test with the powerlaw package")[
```python
fit = powerlaw.Fit(data, discrete=True, xmin=1, verbose=False)
R, p = fit.distribution_compare("power_law", "lognormal_positive")
ln_better = R < 0 and p < 0.05
pl_better = R > 0 and p < 0.05
```
] <code-powerlaw-or-lognormal>

#comment[If i copied pasted this from the r-vuong-test explanation, which is the appropiate way to say it?]

Vulong's test statistic @vuong1989likelihood for comparing two non-nested models with densities $f$ and $g$ is, as extracted from the original documentation @r-vuong-test:

$
  T = 1 / (hat(omega) sqrt(n))
      sum_(i=1)^n
      log frac(f(y_i | x_i, hat(theta)), g(y_i | x_i, hat(gamma)))
$

where

$
  hat(omega)^2 =
  1/n sum_(i=1)^n
  (log frac(f(y_i | x_i, hat(theta)), g(y_i | x_i, hat(gamma))))^2
  -
  [1/n sum_(i=1)^n
   log frac(f(y_i | x_i, hat(theta)), g(y_i | x_i, hat(gamma)))]^2
$

is an estimator for the variance of the log-likelihood ratio; $f(y_i | x_i, hat(theta))$ and $g(y_i | x_i, hat(gamma))$ are the competing densities evaluated at their maximum likelihood estimates.

As $n -> infinity$, $T$ converges in distribution to $cal(N)(0, 1)$. At significance level $alpha$, the null hypothesis of equivalence is rejected when $|T| > z_(alpha/2)$, where $z_(alpha/2)$ is the $alpha/2$ quantile of the standard normal distribution.

=== Distributions and Goodness-of-fit
<apx-method-gof-dist>

#todo[recite and cite R and `fitdistplus`, `actuar` (paretoI, paretoII) and `edv` for `genpareto`]

There is two types of procedures of goodness-of-fit in this work: finding the $gamma$ of a power-law and fitting distributions.

==== Power-law

To find if some data follows a power-law behaviour, we use the highly competent `powerlaw` package, which implements Vuong's Test, already described in @apx-method-gof-vuong. This has been used to fit the events of the firehose #todo[section data first] and to fit the total reposts of the users #todo[section data powerlaw and results powerlaw]

==== Distributions Fittings

To figure out the `session_duration`, `inter_session_time` and `inter_creation_time`, as they are positive heavy/light tail positive quantities, the following distributions are the ones usually picked from the list.
- Exponential: `exp` from `fitdistplus`
- Gamma from `fitdistplus`
- Lognormal: `lognorm` from `fitdistplus`
- Weibull: `weibull_min` from `fitdistplus`
- Pareto: `paretoI` from `actuar`
- Lomax: `paretoII` from `acutar`
- GPD: `genpareto` from `edv`

It is rellevant to outline the reasoning to why include three distributions from the pareto family.This responds to the change of the support previously described. Despite both the sessions or creations being positive, to know about the support they have if Pareto o Lomax have might be very informative for the data. Also, it is expected (and has been validated by results) that GPD shape $alpha$ is negative, that is, bounded behaviour. This is repored under `pareto` in the Calibration @sec-calibration and sampled by an implementation of the General Pareto Distribution, with the conversions explicitly stated already in sections @apx-method-gof-pareto and @apx-method-gof-lomax.

The non pareto families distribution are the most common distributions for heavy-tail data, which are the ones listed above. 


=== Goodness-of-fit Strategy

#todo[Here we have to discuss anderson-darling vs ks for the heavy tail, or even wassermann. THis was a lot of the python version lol, dunno if even rellevant. ]

#todo[cite some of this papers in the discussion ks vs anderson and RSS vs wasserbank]
ks vs anderson:
- Stephens, M. A. (1974). "EDF Statistics for Goodness of Fit and Some Comparisons." Journal of the American Statistical Association, 69(347), 730-737
- Engmann, S., & Cousineau, D. (2011). "Comparing distributions: The two-sample Anderson-Darling test as an alternative to the Kolmogorov-Smirnov test." Journal of Applied Quantitative Methods, 6(3), 1-17
Powerlaw fitting:
- Clauset, A., Shalizi, C. R., & Newman, M. E. (2009). "Power-Law Distributions in Empirical Data." SIAM Review, 51(4), 661-703
Wasserstain:
- Panaretos, V. M., & Zemel, Y. (2019). "Statistical Aspects of Wasserstein Distances." Annual Review of Statistics and Its Application, 6, 405-431
- Rüschendorf, L. (2001). "Wasserstein metric." Encyclopedia of Mathematics

== Session Creation
<apx-method-session>

This section covers the Tukey Fences method, which is the only method not described in @sec-method-session for the sake of this document brevity

=== Tukey's Fences
<apx-method-session-tukey>

The Tukey Fences @tukey1977eda is an outlier detection method that consist of defining the inner and outer fence. Every point inside the fence is not an outlier, and every other one it is classified an outlier.

$
"Tukey"(k) = [Q_1 - k dot "IQR", Q_3 + k dot "IQR"]
$

For the sessions creation, we use the upper part of the fence to define the threshold per user

$
  "tukey"(k) = Q_3 + k dot (Q_3 - Q_1)
$

Algorithm @proc-tukey-sessions summarises the procedure. The fence is recomputed for each user from their own inter-event gap distribution, so the threshold adapts to the user's cadence. So, if the distance to the next event is bigger than $epsilon$ it is classified in the next session.

#procedure(caption: flex-caption(
  [Tukey session clustering.],
  [Tukey session clustering: per-user adaptive gap threshold $epsilon$ followed by a linear scan over the user's sorted, deduplicated event timestamps.],
))[
  #pseudocode-list[
    + *procedure* $"TukeySessions"(u: "User", k: "float")$
      + $E <- u."events"$
      + *if* $|E| < 3$ *then*
        + *return* $emptyset$
      + *end*
      + $T <- "sort"(E)$
      + $"gaps" <- (T_2 - T_1, dots, T_n - T_(n-1))$
      + $epsilon <- "tukey"(k, "gaps")$
      + $"sessions" <- emptyset$
      + $"start" <- T_1$
      + $"cur_end" <- T_1$
      + *for* $i <- 2 "to" n$ *do*
        + *if* $T_i - T_(i-1) > epsilon$ *then*
          + $"sessions" <- "sessions" union {("start", "cur_end")}$ $"//"$ gap exceeds the fence
          + $"start" <- T_i$
        + *end*
        + $"cur_end" <- T_i$
      + *end*
      + $"sessions" <- "sessions" union {("start", "cur_end")}$
      + *return* $"sessions"$
    + *end*
  ]
] <proc-tukey-sessions>

=== HDBSCAN
<apx-method-session-hdbscan>

Hierarchical Density-Based Spatial Clustering of Applications with Noise (HDBSCAN) amplifies DBSCAN (introduced in @sec-method-session) by generating a complete density-based clustering hierarchy @mcinnes2017hdbscan. Instead of relying on a fixed global threshold, HDBSCAN conceptually performs DBSCAN over varying $epsilon$ values and integrates the results to find a clustering structure that offers the best stability over $epsilon$ @campello2013hdbscan. This allows the algorithm to detect clusters of varying densities and makes it significantly more robust to parameter selection @campello2013hdbscan.

HDBSCAN fundamentally relies on a single input parameter, $m_"pts"$, which acts as a smoothing factor for the density estimates @mcinnes2017hdbscan. The algorithm operates by computing a core distance for each object and defining a symmetric mutual reachability distance between object pairs @ester1996dbscan. These distances are used to conceptually construct a mutual reachability graph, from which a Minimum Spanning Tree (MST) is extracted and simplified to build a hierarchical dendrogram @mcinnes2017hdbscan.

To provide a usable flat partition from this hierarchy, HDBSCAN employs a simplification process based on cluster stability @mcinnes2017hdbscan. By tracking how long clusters "survive" as the density threshold changes—a metric derived from the relative excess of mass—the algorithm optimally extracts the most significant clusters through local cuts across different density levels in the cluster tree @ester1996dbscan.

== Reproducibility of the Distribution Fits
<apx-method-repro>

#todo[reread and reload]
All the scripts and intermediate outputs behind @sec-cal-dist and the parameter histograms are available in the `bsky-data-analysis` repository @soler2025bskydata, under `sessions/distribution-fit/`. The pipeline runs in five stages, each with a single entry point:

1. *Extraction* (`dump_data.py`): per-user session durations and inter-session gaps are dumped from the production table `pau_db.sessions` (DBSCAN $epsilon = 300$ s, $m_"pts" = 2$, see @apx-session-dbscanparams) into ten strided parquet chunks. Durations are non-singleton sessions only; gaps are the intervals between the end of a session and the start of the next.
2. *Per-user fitting* (`fit_chunk.R`, `fit_lib.R`): each user--column unit is fitted by maximum likelihood against the eight candidate distributions of @apx-method-gof-dist; KS, Cramér--von Mises and Anderson--Darling statistics are computed in closed form. Writes `results/gof__chunk{0..9}.tsv` and `results/params__chunk{0..9}.tsv`.
3. *Model selection* (`step2_build_best.py`): AIC winner per user and column, with the Pareto/Lomax/GPD siblings grouped under the `power_tail` family. Produces `results/best_per_user.tsv`, `results/best_params.tsv` and `results/family_summary.tsv` ---the source of @tbl-cal-dist-family.
4. *Canonical power-law parameters* (`step3_powerlaw_canonical.py`): every `power_tail` winner is converted to the canonical GPD($xi$, $sigma$, $mu$) parametrization, verified to $|Delta "CDF"| <= 10^(-16)$.
5. *Meta-fits and plots* (`step4_fit_parameters.R`, `step5_plot_param_distributions.R`): the across-user parameter series are themselves fitted ---AIC selection among exponential, gamma, lognormal, Weibull and normal, restricted to $n_"obs" >= 30$--- producing `results/param_distributions.tsv`, `results/param_correlations.tsv` and the parameter histograms (a subset is shown in ). The meta-fits themselves are deliberately not used in the simulation: @sec-cal-acrossuser argues that they are unreliable (too few users in several families, multimodal parameter series) and that the per-user parameters are sampled empirically instead.

The complete methodological write-up lives in `sessions/distribution-fit/METHODOLOGY.md` of the same repository, and the sessionization decision behind the input table in `sessions/final_parameters.md`.

Two caveats bound full reproducibility. First, the input `pau_db.sessions` table derives from the Bluesky Firehose dataset, which is not redistributed: stage 1 requires access to the private database, so the pipeline can only be re-run end-to-end by the authors. Second, the per-unit result files are large ---the ten `gof__chunk*.tsv` alone occupy about 3 GB--- and are excluded from the repository; the compact derived tables (`family_summary.tsv`, `param_distributions.tsv`, `param_correlations.tsv`) suffice to verify every figure reported in this chapter.
