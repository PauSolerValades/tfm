This annex contains the full derivation behind @sec-finding-missing-tail. The main text uses only the first-moment argument; here we derive the exact tail exponent and the constraint it places on any future content model.

=== Setup and notation

A cascade is a Galton–Watson tree: a root (the post) whose descendants are the reposters. Let $T$ be the total progeny and $X$ the offspring distribution with mean $m = EE(X)$. The root seed is treated separately in the two-stage model below.

=== Dwass's identity

The total progeny of a Galton–Watson process satisfies the exact identity @otter1949 @dwass1969

$
  PP(T = n) = frac(1, n) PP(X_1 + dots + X_n = n - 1),
$

where $X_i$ are independent copies of $X$.

=== Poisson offspring

Under the homogeneous model the offspring of a reposter is approximately $"Poisson"(m)$ (a binomial with small repost probability and many followers, in its Poisson limit). Then $X_1 + dots + X_n ~ "Poisson"(n m)$, so

$
  PP(T = n | m) = frac(1, n) e^(-n m) frac((n m)^(n-1), (n-1)!).
$

Stirling's formula gives

$
  PP(T = n | m) ~ frac(1, m sqrt(2 pi)) n^(-3/2) (m e^(1-m))^n.
$

Since $m e^(1-m) < 1$ for every $0 <= m < 1$, a fixed subcritical $m$ yields an exponential tail. This is the homogeneous case.

=== Mixture over per-post reproduction numbers

Let the reproduction number be random, $m ~ F$, with density $f(m)$ and $EE(m) = R_0 < 1$. The annealed (content-averaged) size distribution is

$
  PP(T = n) = integral_0^1 PP(T = n | m) f(m) d m.
$

Suppose $f(m) ~ c (1-m)^(beta-1)$ as $m arrow.up 1$ for some $beta > 0$ (a fitness density with mass near criticality). Substituting the asymptotic form and applying Laplace's method around $m = 1$,

$
  PP(T = n) ~ frac(c, sqrt(2 pi)) n^(-3/2) integral_0^1 (1-m)^(beta-1) e^(-n(1-m)^2/2) d m
  ~ C n^(-(beta+3)/2).
$

Therefore the tail is a power law,

$
  PP(T > s) ~ C' s^(-(beta+1)/2).
$

A fixed reproduction number gives an exponential tail; a mixed one gives a power-law tail with index $(beta+1)/2$. Same mean, different tail, purely from where the randomness sits.

=== Two-stage model and the root seed

The root is not part of the reposter Galton–Watson process. Write the cascade size as

$
  S = 1 + S_0 + sum_(i=1)^(S_0) T_i,
$

where $S_0$ is the root seed (direct reposts, mean $mu_0 approx 1.2$) and $T_i$ are independent copies of the reposter total progeny. Then

$
  EE(S) = 1 + frac(mu_0, 1 - R_0) approx 2.54,
$

matching the simulated mean, unlike a naive single-stage model that would feed $"Poisson"(R_0)$ to the root.

=== Matching the observed exponent

The Bluesky repost-count exponent $alpha = 2.05$ means $PP("reposts" > x) ~ x^(-(alpha-1))$. Equating tail indices gives

$
  frac(beta+1, 2) = alpha - 1, quad "i.e." quad beta = 2 alpha - 3 approx 1.1.
$

The fitness density must therefore diverge like $(1-m)^(0.1)$ near $m = 1$: a large fraction of posts must sit almost-critical. This is a concrete, checkable constraint on any future content model.

=== Terminology caveats

The heterogeneous process is a *mixture of Galton–Watson processes* (equivalently a branching process in random environment), not a Galton–Watson process: offspring of different nodes in the same cascade are not independent because they share the same $m$. A "temporarily supercritical" post is likewise outside the fixed-$m$ classification; it would require a time-varying reproduction number or a finite-audience ceiling, which is the width story of @sec-missing-width. The discarded Monte-Carlo toy in the repository attempted these comparisons with a truncated fitness and a Poisson-lognormal "heavy offspring" arm; both were removed because the truncation forced the offspring rate below one and destroyed the heavy tail the arm was meant to test.
