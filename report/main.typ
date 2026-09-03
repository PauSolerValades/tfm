#import "src/utils.typ": *

#let margins = (
  top: 3.5cm,
  bottom: 3cm,
  y: 1.8cm,
)
#let blue = rgb(43, 129, 173)
#let grey = rgb(100, 100, 100)

#set page(paper: "a4", margin: margins, numbering: "1")

#set text(size: 11pt, font: "New Computer Modern", lang: "en")

#set par(spacing: 0.7em, leading: 0.7em, justify: true, first-line-indent: 1.5em,)

#set heading(numbering: "1.")
#show heading.where(level: 1): set text(
  size: 20pt,
  weight: "bold",
)

#show heading.where(level: 2): set text(
  size: 14pt,
  weight: "bold",
)

#show heading.where(level: 3): set text(
  size: 12pt,
  weight: "bold",
)

#show heading.where(level: 4): set heading(outlined: false, numbering: none)
#show heading.where(level: 5): set heading(outlined: false, numbering: none)
#show heading.where(level: 4): set text(
  size: 11pt,
  weight: "bold",
)

#show heading: it => [
  #block(above: 1.5em, below: 1em, it)
]

#set math.equation(numbering: "(1)")

// Add a bit of breathing room after figure captions
#show figure: it => {
  it
  v(0.6em)
}

// Track when Typst is generating the outline (List of Figures/Tables/etc.)
#let in-outline = state("in-outline", false)

// Flip the state to true ONLY inside outlines
#show outline: it => {
  in-outline.update(true)
  it
  in-outline.update(false)
}

// Custom caption: short version in lists, long version in main body
#let flex-caption(short, long) = context if in-outline.get() { short } else { long }

// ----------------------------------------------------------
#include "src/cover.typ"

#counter(page).update(1)

#set page(numbering: "i")

#pagebreak()
#pagebreak()
#heading(outlined: false, numbering: none)[Abstract]
#include "src/0-abstract.typ"

#pagebreak()
#heading(outlined: false, numbering: none)[Acknowledgments]

#include "src/0-aknowledgments.typ"

#pagebreak()
#outline(title: "Table of Contents")

#show outline.entry.where(level: 1): it => {
  v(1em, weak: true)
  it
}

#pagebreak()
#heading(outlined: true, numbering: none)[List of Figures]
#outline(title: none, target: figure.where(kind: image))

#pagebreak()
#heading(outlined: true, numbering: none)[List of Tables]
#outline(title: none, target: figure.where(kind: table))

#pagebreak()
#heading(outlined: true, numbering: none)[List of Procedures]
#outline(title: none, target: figure.where(kind: "procedure"))

#pagebreak()
#heading(outlined: true, numbering: none)[List of Codes]
#outline(title: none, target: figure.where(kind: "code"))

#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
= Introduction
#todo[warning: this is not the final version, do not review.]

#include "src/1-introduction.typ"

#pagebreak()
= Social Networks State of the Art
<sec-sota>

#include "src/2-sota.typ"

#pagebreak()
= Problem Formulation 
<sec-model>

#include "src/3-model.typ"

#pagebreak()
= Methodology
<sec-method>

#include "src/4-methodology.typ"

#pagebreak()
= Design 
<sec-design>

#include "src/5-design.typ"

#pagebreak()
= Bluesky Data Analysis
<sec-data>

#include "src/6-data.typ"

#pagebreak()
= Calibration
<sec-calibration>

#include "src/7-calibration.typ"

#pagebreak()
= Results
<sec-results> 

#include "src/8-results.typ"

#pagebreak()
= Conclusions

#todo[warning: this is not the final version. Do not review]
#include "src/9-conclusions.typ"

#pagebreak()
= Future Work
<sec-future>

#include "src/10-futurework.typ"

#pagebreak()
#bibliography(
  ("refs/1-introduction.yml", "refs/2-context.yml", "refs/3-model.yml", "refs/4-methodology.yml", "refs/5-design.yml", "refs/6-data.yml", "refs/7-calibration.yml", "refs/8-futurework.yml", "refs/9-annex.yml", "refs/6-implementation.yml"),
  title: "References",
)

#pagebreak()
#counter(heading).update(0)
#set heading(numbering: "A.1", supplement: "Appendix")

= Disclaimer About Generative AI Use
<apx-ai>

#include "src/annex/ai.typ"

#pagebreak()
= Code Repositories
<apx-code>

#include "src/annex/code.typ"

#pagebreak()
= Methodology 
<apx-method>

#include "src/annex/methodology.typ"

#pagebreak()
= Examples
<apx-examples>

#include "src/annex/example.typ"

#pagebreak()
= Discarded Features
<apx-mechanics>

#include "src/annex/mechanics.typ"

#pagebreak()
= Implementation
<apx-impl>

#include "src/annex/implementation.typ"

#pagebreak()
= Data Analysis
<apx-data>

#include "src/annex/data.typ"

#pagebreak()
= Topology Ingestion and Sampling 
<apx-topology>

#include "src/annex/topology.typ"

#pagebreak()
= Sessions
<apx-sessions>

#include "src/annex/sessions.typ"

#pagebreak()
= Post Creation
<apx-creation>

#include "src/annex/postcreation.typ"

#pagebreak()
= Stability Plots
<apx-stability-plots>

#include "src/annex/stability-plots.typ"

#pagebreak()
= Pipeline
<apx-pipeline>

#include "src/annex/pipeline.typ"

#pagebreak()
= Content Aware Posts
<apx-content>

#include "src/annex/future-content.typ"

#pagebreak()
= Software Stack
<apx-software-stack>

#include "src/annex/software-stack.typ"

#pagebreak()
= Hardware Specifications
<apx-hardware>

#include "src/annex/hardware.typ"

// #pagebreak()
// = Branching-Process Derivation of the Missing Tail
// <apx-branching>

// #include "src/annex/branching-math.typ"

