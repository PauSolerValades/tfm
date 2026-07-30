#import "../utils.typ": *

This sections addresses methodological issues and concerns that, while extremely important, had to be moved into the appendix due to lenght constraints.

== Random Number Generation
<sec-method-rng>

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

The Pareto Distribution is fundamental when talking about social networks, as its the distribution associated with the power-law. It's defined by two parameters, scale $alpha$ and shape $x_m$, and has the following density and cumulative density functions:

$ f(x | alpha, x_m ) = cases(frac(alpha x_m^alpha, x^(alpha + 1)) & "if" x >= x_m, 0 & "if" x < x_m )  $

$ F(x | alpha, x_m) = cases(
  1 - (frac(x_m, x))^alpha & "if" x >= x_m,
  0 &"if" x < x_m
)
$ 

To sample from it we've used the following relationship @casella2002statistical: a random variable $X$ follows a $"Pareto"(alpha, x_m)$ distribution when $Y ~ "Exp"(1)$ and

$ X ~ x_m · exp{Y/alpha} $

therefore being as efficient as generating an exponential with the ziggurat algorithm.

=== Goodness-of-fit Test

#todo[to make this appropiately, i implemented the Kolmogorov-Smirnoff test for the upper distributions in zig.]

== Distribution Fitting

This section addresses tools and concepts used in distribution fitting and other related concerns.

=== Vulong's Test

In social networks, power-laws ---data following a Pareto distribution--- appears usually due to the networks own nature and growth. Despite appearing naturally, one must be carefull to classify them as another very common heavy-tail function: the lognormal.

The `powerlaw` @alstott2014powerlaw package provides `fit.distribution_compare()`, which implements Vuong's log-likelihood ratio test @vuong1989likelihood to discriminate between the Pareto and the lognormal distribution. @code-powerlaw-or-lognormal showcases how the function is used, where a negative $R$ indicated the lognormal is a better fit, and a positive one otherwise. The $p$-value determines whether the difference is statistically significant.

#code(caption: "Vuong's log-likelihood ratio test with the powerlaw package")[
```python
fit = powerlaw.Fit(data, discrete=True, xmin=1, verbose=False)
R, p = fit.distribution_compare("power_law", "lognormal_positive")
ln_better = R < 0 and p < 0.05
pl_better = R > 0 and p < 0.05
winner = "lognormal" if ln_better else ("powerlaw" if pl_better else "none")
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

=== General Distribution Fitting

For discriminating between several distribuitions, `distfit` @distfit-pypi is used with it's popular set of distribution, which are normal, genextreme, exponential, gamma, pareto, lognorm, dweibull, beta, t and uniform @distfit-parametric. The method compared the empirical shape with the distribution shape with Residual Sum of Squared by default.

The RSS describes the deviation predicted from actual empirical values of data. Or in other words, the differences in the estimates. It is a measure of the discrepancy between the data and an estimation model. A small RSS indicates a tight fit of the model to the data. RSS is computed by:

$"RSS" = sum_(i=1)^n (y_i - f(x_i))^2$

Where $y_i$ is the i-th value of the variable to be predicted, $x_i$ is the i-th value of the explanatory variable, and $f(x_i)$ is the predicted value of $y_i$ (also termed y-hat).

This method serves as a quick discrimination between several distributions, but obviously does not provide hypothesis testing between any two distributions.
