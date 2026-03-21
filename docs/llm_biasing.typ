#set document(title: "LLM Action Probability Calibration")
#set page(width: auto, height: auto, margin: 2cm)
#set text(font: "New Computer Modern", size: 12pt)


= Background: Conditioned Bayes' Theorem

Standard Bayes' theorem for events $A$ and $B$ states:
$ P(A | B) = (P(B | A) dot P(A)) / P(B) $

Let $A = a$ (the action) and $B = c$ (the context). Substituting these gives:
$ P(a | c) = (P(c | a) dot P(a)) / P(c) $

In our model, every event is inherently conditioned on the specific user $u$. By applying this background conditioning to every term in the equation above, we arrive at the starting point for our LLM calibration:
$ P(a | c, u) = (P(c | a, u) dot P(a | u)) / P(c | u) $

Def:
- Content $c$ is a temporal sequence of tokens $(t_n)_n$ regarding the post content the LLM ingest.
- User $u$ is a temporal sequence of tokens $(t_n)_n$ describing the personality of a user.

= LLM Action Probability Calibration

Using Bayes' theorem, we express the probability of an action $a$ given context $c$ and user $u$.

$ PP_"LLM" (a | c, u) =^"Bayes" (PP_"LLM" (c | a, u) dot PP_"LLM" (a | u)) / ( PP_"LLM" (c | u) ) $

Assume $PP_"LLM" (c | u)$ is constant therefore:
$ PP_"LLM" (a | c, u) prop PP_"LLM" (c | a, u) dot PP_"LLM" (a | u) 
=> PP_"LLM" (c | a, u) prop ( PP_"LLM" (a | c, u) ) / ( PP_"LLM" (a | u) ) $

*DEF:* We want something that combines the LLM with calibration, ergo:

$ PP(a | c, u) prop^"Bayes" PP(c | a, u) dot PP(a | u) $

Mapping these general terms to our calibrated model:
- $PP (a | c, u) arrow.squiggly PP_"cal" (a | c, u)$
- $PP (c | a, u) arrow.squiggly PP_"LLM" (c | a, u)$
- $PP (a | u) arrow.squiggly pi_a$

Ergo, the final calibrated probability is approximated by biasing it with the user's empirical distribution:

$ PP_"cal" (a | c, u) prop PP_"LLM" (c | a, u) dot pi_a $
