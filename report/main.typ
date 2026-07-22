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
= Implementation
<sec-impl>

#include "src/6-implementation.typ"

#pagebreak()
= Bluesky Data Analysis
<sec-data>

#include "src/7-data.typ"

#pagebreak()
= Calibration
<sec-calibration>

#include "src/8-calibration.typ"

#pagebreak()
= Execution 
<sec-exec>

#include "src/9-execution.typ"

#pagebreak()
= Results
<sec-results> 

#include "src/10-results.typ"

#pagebreak()
= Conclusions

#include "src/11-conclusions.typ"

#pagebreak()
= Future Work
<sec-future>

#include "src/12-futurework.typ"

#pagebreak()
#bibliography(
  ("refs/1-introduction.yml", "refs/2-context.yml", "refs/3-model.yml", "refs/4-methodology.yml", "refs/5-design.yml", "refs/6-implementation.yml", "refs/7-data.yml", "refs/8-calibration.yml", "refs/9-futurework.yml", "refs/10-annex.yml"),
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
= Data Analysis
<apx-data>

#include "src/annex/data.typ"
#pagebreak()
= Post Lifetime Analysis
<apx-lifetime>

#include "src/annex/lifetime.typ"

#pagebreak()
= Additional Evaluation Metrics
<apx-metrics>

#include "src/annex/metrics.typ"

#pagebreak()
= Additional Mechanics 
<apx-mechanics>

#include "src/annex/mechanics.typ"

#pagebreak()
= Software Stack
<apx-software-stack>

#include "src/annex/software-stack.typ"

#pagebreak()
= Twitter Session Mechanics Threshold 
<apx-threshold>

#include "src/annex/threshold.typ"

#pagebreak()
= Database Specification
<apx-database>

#include "src/annex/database.typ"

#pagebreak()
= Topology Ingestion and Sampling 
<apx-topology>

#include "src/annex/topology.typ"

#pagebreak()
= Performance Analysis 
<apx-performance>

#include "src/annex/hardware.typ"

<apx-space>

#include "src/annex/space-analysis.typ"


