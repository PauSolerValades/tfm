#import "../utils.typ": *
#import "@preview/lovelace:0.3.0": pseudocode-list

This sections addresses methodological issues and concerns that, while extremely important, had to be moved into the appendix due to lenght constraints.

== Random Number Generation
<apx-method-rng>

This section covers the implementations of the Random Number Generators needed in the main simulation, as Zig did not have a library of distributions. The distributions library has been published under the MIT license and its source available @soler2025distributions.


=== Ziggurat Algorithm
<sec-method-rng-ziggurat>

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


=== Weibull Distribution

The Weibull Distribution is a two parameter distribution, with a shape and scale parameter with the following cumulative density:

$ F(x) = cases( 1 - exp{- (frac(x, lambda))^k} &"if" x >= 0, 0 &"else" x < 0), $

To sample from it, we use the standard Inverse Sampling Method @devroye1986nonuniform, in which we invert $F$ to obtain:

$ X = lambda · ( -ln(1-U))^(1/k) $

And to save some CPU cycles and avoid the expensive logarithm, we can rewrite it while using that $Y ~ "Exp"(1)$ with aknowleding that $1-U ~ "Unif"((0,1]) => U ~ "Unif"((0,1))$, therefore:

$ X = lambda · -ln( U ) ^(1/k) = lambda  Y^(-k) $

and as we generate exponentials with the efficent ziggurat algorithm, generating a $"Exp"(1)$ is almost $O(1)$, making this algorithm almost $O(1)$.

=== Lognormal Distribution

The Lognormal is defined as $X = exp(Y) quad Y ~ N(mu, sigma^2)$, which is the result of applying an exponential to a Normal distribution. The method to generate it is to generate a number following $Y$ with the Ziggurat algorithm and apply the exponential over it.


=== Generalized Pareto Distribution

The Generalized Pareto Distribution ---GPD from now on--- is a three-parameter family, specified by location $mu$, scale $theta$ and shape $alpha$ (the same `location`, `scale` and `shape` fields of the Zig implementation). Its cumulative density functions is:

$ F(x | mu, theta, alpha) = cases(
  1 - (1 + alpha frac(x - mu, theta))^(-1/alpha) & "if" alpha != 0,
  1 - exp(-frac(x - mu, theta)) & "if" alpha = 0,
) $

with $mu, alpha in RR$ and $theta in RR^+$. The support changes with the sign of the shape: $x >= mu$ when $alpha >= 0$, and $mu <= x <= mu - theta/alpha$ otherwise.

To sample from it we use the Inverse Sampling Method @devroye1986nonuniform: inverting $F$ gives the quantile

$ X = mu + theta frac((1 - U)^(-alpha) - 1, alpha), quad U ~ "Unif"([0, 1)), $

for $alpha != 0$, and $X = mu - theta ln(1 - U)$ for $alpha = 0$, the exponential special case.

Again, to avoid a logarithm (and a power) per sample, we use the exponential trick: since $1 - U = exp(-Y)$ for $Y ~ "Exp"(1)$, we have $(1 - U)^(-alpha) = exp(alpha Y)$, and the sampler becomes

$ X = cases(
  mu + theta Y & "if" alpha = 0,
  mu + theta frac(exp(alpha Y) - 1, alpha) & "if" alpha != 0,
) $

where $Y$ is drawn with the Ziggurat algorithm.


=== Gamma

The Gamma Distribution is a two-parameter family with shape $k$ and rate $beta$ (following the R convention), and has the following density and cumulative distribution functions:

$ f(x | k, beta) = frac(beta^k x^(k-1) e^(-beta x), Gamma(k)), quad x > 0 $

$ F(x | k, beta) = frac(gamma(k, beta x), Gamma(k)) $

where $Gamma(k)$ is the gamma function and $gamma(k, beta x)$ the lower incomplete gamma function. The rate is the reciprocal of the scale, $beta = 1 slash theta$.

Gamma is the only distribution in the library that is not sampled directly with a Ziggurat. It uses the Marsaglia & Tsang method @marsaglia2000gamma ---from the same authors of the Ziggurat---, which recycles the Normal distribution (itself generated with the Ziggurat, see @sec-method-rng-ziggurat): a Gamma variate is a Normal variate that survives a rejection test. For $k >= 1$, with

$ d = k - 1/3, quad c = 1 / sqrt(9 d), $

the algorithm repeatedly draws $X ~ cal(N)(0, 1)$ and $U ~ "Unif"(0, 1)$ and builds the candidate $V = (1 + c X)^3$:

- If $V <= 0$ the candidate has no meaning and is discarded.
- A cheap squeeze test accepts whenever $U < 1 - 0.0331 X^4$, which covers almost all samples without evaluating any transcendental function.
- Otherwise an exact test $ln U < X^2 / 2 + d (1 - V + ln V)$ decides.

On acceptance the sample is $frac(d V, beta)$. For $k < 1$ the algorithm samples shape $k + 1$ and thins the result with an independent $U^(1 slash k)$, which recovers the correct Gamma.

Only the exact test pays for a logarithm, so the sampler stays close to the cost of a single Normal draw from the Ziggurat.



=== Empirical Cumulative Distribution Function
<sec-method-rng-ecdf>

The Empirical Cumulative Distribution Function is the very intuitive definition of what is a cumulative distribution function, and it has the following definition, where $X_i$ is a sample from the data.

$ hat(F)_n (x) =  frac(1, n) sum_(i=1)^n bb(1)_(X_i <= x) $

The ECDF is a step function that jumps at every observation, so it can be used directly as a sampler for distributions that are not known in closed form ---such as the offsets and inter-post creation times of this project (see @sec-cal-dist)--- without fitting any parametric law.

In our Zig implementation, `init` receives the data slice, sorts it, and collapses it into `Bin` entries `(value, cump)` ---the distinct values together with their cumulative probability--- stored in a `MultiArrayList(Bin)`, so the sorted values and their cumulative probabilities live in separate, cache-friendly arrays.

Sampling follows the Inverse Sampling Method over the empirical CDF: draw $U ~ "Unif"([0, 1))$ and return the first value whose cumulative probability is at least $U$. Since the bins are sorted, that value is found with a binary search in $O(log n)$:

#code(caption: [Binary search over the cumulative probabilities used to sample an ECDF.])[
```zig
while (lower < upper) {
    const i = lower + @divFloor(upper - lower, 2);
    const p = self.bins.items(.cump)[i];

    if (u <= p) {
        upper = i;
    } else if (u > p) {
        lower = i + 1;
    }
}
```
]

The `cdf` method mirrors this: a binary search finds how many bins have a value $<= x$ and returns the cumulative probability of the last one, so $P(X <= x)$ is answered in $O(log n)$ as well.

The implementation is deliberately simple rather than optimal. A more sophisticated non-parametric representation could shave the constant, but the ECDF is only queried during simulation setup and its bins are small, so a binary search over a contiguous array was judged good enough.#footnote[The ECDF files needed for `offset_post_creation` and `inter_post_creation` are already sorted when loaded.]


=== Goodness-of-fit Test

To test the implementations of the above distributions, a Kolmogorov-Smirnoff test has been implemented in the library, and can be ran with `zig build gof`, which will ran it against all implementations.

Knowing that the author is fallible, this has also been ran aganist well estabilshed R funcitons with a big enough sample, to check the implementations matched.


== Distribution Fitting
<apx-method-gof>

This section addresses tools and concepts used in distribution fitting and other related concerns.

== Pareto Family of Distributions

Pareto is not just a distribution, but a familiy of them. In the distribution fitting list we are including three types of Paretos, which we describe ---and argue the need of--- in this section.

Paretos are organized in 6 types of distributions: Paretos I to IV, with Pareto II with location 0 has a special name, and then the Generalized Pareto Distribution. This section will explain Pareto I ---the standard one parameter power-law---, Pareto II with $mu=0$ ---also known as Lomax--- and the Generalized Pareto Distribution.

=== Generalized Pareto Distribution

This section is sourced from the original article by James Pickands @pickands1975statistical.

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

The distribution fits are performed in R with `fitdistrplus` @fitdistrplus-cran for maximum-likelihood estimation, `actuar` @actuar-cran for the Pareto family, and `evd` @evd-cran for the Generalized Pareto Distribution.

There is two types of procedures of goodness-of-fit in this work: finding the $gamma$ of a power-law and fitting distributions.

==== Power-law

To find if some data follows a power-law behaviour, we use the highly competent `powerlaw` package @alstott2014powerlaw, which implements Vuong's Test, already described in @apx-method-gof-vuong.

==== Distributions Fittings

To figure out the `session_duration`, `inter_session_time` and `inter_creation_time`, as they are positive heavy/light tail positive quantities, the following distributions are the ones usually picked from the list.
- Exponential: `exp` from `fitdistrplus` @fitdistrplus-cran
- Gamma: `gamma` from `fitdistrplus` @fitdistrplus-cran
- Lognormal: `lognorm` from `fitdistrplus` @fitdistrplus-cran
- Weibull: `weibull_min` from `fitdistrplus` @fitdistrplus-cran
- Pareto: `paretoI` from `actuar` @actuar-cran
- Lomax: `paretoII` from `actuar` @actuar-cran
- GPD: `genpareto` from `evd` @evd-cran

It is rellevant to outline the reasoning to why include three distributions from the pareto family.This responds to the change of the support previously described. Despite both the sessions or creations being positive, to know about the support they have if Pareto o Lomax have might be very informative for the data. Also, it is expected (and has been validated by results) that GPD shape $alpha$ is negative, that is, bounded behaviour. This is repored under `pareto` in the Calibration @sec-calibration and sampled by an implementation of the General Pareto Distribution, with the conversions explicitly stated already in sections @apx-method-gof-pareto and @apx-method-gof-lomax.

The non pareto families distribution are the most common distributions for heavy-tail data, which are the ones listed above. 


=== Goodness-of-fit Strategy

Each unit ---one user, one quantity--- is fitted independently by maximum likelihood under the natural support of the candidate, deliberately without a free location parameter: an unconstrained location collapses onto $min(x) - epsilon$, buying likelihood without modelling the data. The one support-bound candidate, Pareto Type I, is treated in @apx-session-pareto. Inter-session gaps are fitted after subtracting the sessionization horizon $epsilon = 300$ s, since DBSCAN merges events closer than $epsilon$ into the same session and a gap can only be observed above it: this is a location change of the whole law, not a truncated-likelihood correction.

Goodness of fit is then measured with the three classical EDF statistics, computed in closed form against the fitted CDF @stephens1974: Kolmogorov--Smirnov, Cramér--von Mises and Anderson--Darling. The `gofstat` helper is not used ---its internal chi-square binning fails at the small per-user sample sizes--- and the closed-form implementation was verified against it to six decimals on the units where both work.

Selection is made with the Akaike Information Criterion @akaike1974: the lowest AIC wins, ties broken by the lower Anderson--Darling statistic and then by name, so the choice is deterministic. Anderson--Darling is deliberately not the selector ---it weights precisely the tail, where a single user has the fewest observations--- and is kept only as the heavy-tail descriptor.

The three Pareto siblings ---Type I, Lomax and the GPD--- are grouped under one family for the reported composition, since successive AIC preferences among near-identical siblings are not evidence; the sibling split and the boundary case are discussed in @apx-session-pareto.

To say not just which family wins but how safely, the $Delta "AIC"$ margin $"AIC"_(2"nd") - "AIC"_"best"$ is reported, values below two meaning the leading families are indistinguishable; for the within-session inter-post gaps it is small for most users, which is what rules out a parametric law there and routes that quantity to the empirical distribution (@anx-create-gof).

Two bounds close the strategy: units with fewer than 30 observations are excluded, the cutoff justified by the composition sweep of @tbl-composition-cutoff, and ---because the statistics are evaluated on the same data that fitted the parameters--- they are descriptive ordering criteria, not calibrated $p$-value tests.

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

== Stability & Execution
<apx-method-exec>

This section documents how the performance figures of @tbl-res-time and @tbl-res-ram in @sec-results Results were measured, and states the caveats that bound their interpretation. All measurements come from the final runs of @tbl-res-finalbatch, executed on the dedicated server _artemis_ (@tbl-hardware).

=== Data collection

RAM usage is recorded by an external monitor script ---`des-ctic/python-utils/ram-monitor.sh`--- that runs approximately every 10 s and appends one line per sample:
+ cnt: number of live `bskysim` proceesses
+ maxrss: largest resident set among them in MB

The `cnt` field comes from `pgrep -x bskysim`, and `maxrss` is the largest `VmRSS` (resident set size, converted from KB to MB) across those processes. Each line is therefore a 10 s snapshot of the biggest `bskysim` process, not a per-run measurement. Every dataset size runs as a single `bskysim` process (launched as `bskysim -w<workers> -n100 …`), so all of a size's runs share one address space.

Execution time is read from the simulation's own bookkeeping, `execution_times.ssv`, which records one `worker run_idx duration_ms` tuple per run. Each duration is measured with `Io.Timestamp` @zig-std-io under the `.cpu_thread` clock option, that is, CPU time of the calling thread rather than wall-clock time.

=== RAM Usage Reconstruction

The RAM per run reported in @tbl-res-ram is reconstructed in two steps. First, the time window of each size is delimited by two mtimes the process writes itself: the first write of `used_config.json` (start) and the newest `*.bin` trace (end). Second, within that window the peak `maxrss` is taken over each individual run's time slice ---reconstructed from the `duration_ms` column of `execution_times.ssv`--- and divided by the worker count to approximate a single isolated run.

Execution time is summarized directly from `execution_times.ssv`: mean, 95% confidence interval, median, minimum and maximum (@tbl-res-time).

=== Known Problems

Three limitations bound the RAM figures. First, 10 s sampling of instantaneous RSS misses the true peak between samples, so every value is a lower-bound approximation. Second, with more than one worker the runs overlap and share a single process, so a per-run slice still contains concurrent and accumulated memory; the worker-normalized value is an upper bound on a truly isolated run. Third, RSS accumulates across runs because state is reused rather than freed, so the per-run peak grows run-over-run.

Finally, the server was not an isolated environment: _artemis_ is a shared 2× AMD EPYC 9654 machine with 1.1 TB of RAM (@tbl-hardware), and other jobs may have been resident during the runs. The measurements are therefore not to be takes as an exact data point, but as an strong intuition of what the actual data would behave as.
