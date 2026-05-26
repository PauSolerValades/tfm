This section covers the discarded metrics that were at some point considered to evaluate the simluation.

==== Gini Coefficient

Inequality ---defined as --- in a social system can be quantified using the Gini index @kwak2017centrality. Given a vector $X in RR^n$ of some wealth attribute (e.g., a node centrality), let $Y$ be $X$ sorted in increasing order. The Lorenz curve $L : [0,1] -> [0,1]$ is defined as the piecewise linear function connecting $(x(k), l(k))$ for $0 <= k <= n$, where

$ x(k) = k / n, quad l(k) = sum_(i=1)^k Y_i / sum_(i=1)^n Y_i $

The Gini index is then the area between the perfectly equal line ($y = x$) and the Lorenz curve:

$ GG(X) = 1 - 2 integral_0^1 L(x) - x $

A value of $0$ indicates perfect equality (all individuals are equal), while a value approaching $1$ indicates extreme inequality (the resource is centralized in a single metric). Unlike the power-law exponent, the Gini index requires no parametric assumptions about the underlying distribution, making it applicable to any network structure @kwak2017centrality.

In Online Social Networks, the Gini index can be applied to different node centralities to measure structural inequality from distinct perspectives @kwak2017centrality, and in this project it will be used to measure inequality in how much information a node directly receives from its neighbors. High degree-Gini indicates that a small set of users dominates the inflow of information, a typical signature of power-law follower distributions on platforms like Twitter or Bluesky.


