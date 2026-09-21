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

// Main sections (level-1 headings) always start on the same side of the
// sheet. `pagebreak(to: "odd")` forces the page parity and inserts a blank
// page when needed; it is measured on the physical page, so the front-matter
// and body counter resets below do not disturb it.
#show heading: it => [
  #if it.level == 1 { pagebreak(to: "odd", weak: true) }
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
// Official UPC-FME cover, then the styled title page.
// Covers are not part of the page numbering.
#set page(numbering: none)
#include "src/cover-official.typ"
#pagebreak()
#pagebreak()
#include "src/cover.typ"

// Front matter starts here, in roman numerals, at the abstract (i).
#pagebreak(to: "odd")
#set page(numbering: "i")
#counter(page).update(1)

#heading(outlined: false, numbering: none)[Abstract]
#include "src/0-abstract.typ"

#heading(outlined: false, numbering: none)[Acknowledgments]

#include "src/0-aknowledgments.typ"

#outline(title: "Table of Contents")

#show outline.entry.where(level: 1): it => {
  v(1em, weak: true)
  it
}

#heading(outlined: true, numbering: none)[List of Figures]
#outline(title: none, target: figure.where(kind: image))

#heading(outlined: true, numbering: none)[List of Tables]
#outline(title: none, target: figure.where(kind: table))

#heading(outlined: true, numbering: none)[List of Procedures]
#outline(title: none, target: figure.where(kind: "procedure"))

#heading(outlined: true, numbering: none)[List of Codes]
#outline(title: none, target: figure.where(kind: "code"))

#pagebreak(to: "odd")
#set page(numbering: "1")
#counter(page).update(1)

= Introduction

#include "src/1-introduction.typ"

= Social Networks State of the Art
<sec-sota>

#include "src/2-sota.typ"

= Problem Formulation 
<sec-model>

#include "src/3-model.typ"

= Methodology
<sec-method>

#include "src/4-methodology.typ"

= Design 
<sec-design>

#include "src/5-design.typ"

= Bluesky Data Analysis
<sec-data>

#include "src/6-data.typ"

= Calibration
<sec-calibration>

#include "src/7-calibration.typ"

= Results
<sec-results> 

#include "src/8-results.typ"

= Conclusions
<sec-conclusions>

#include "src/9-conclusions.typ"

= Future Work
<sec-future>

#include "src/10-futurework.typ"

#bibliography(
  ("refs/1-introduction.yml", "refs/2-context.yml", "refs/3-model.yml", "refs/4-methodology.yml", "refs/5-design.yml", "refs/6-data.yml", "refs/7-calibration.yml", "refs/8-futurework.yml", "refs/9-annex.yml", "refs/6-implementation.yml"),
  title: "References",
  style: "ieee",
)

#counter(heading).update(0)
#set heading(numbering: "A.1", supplement: "Appendix")

= Disclaimer About Generative AI Use
<apx-ai>

#include "src/annex/ai.typ"

= Code Repositories
<apx-code>

#include "src/annex/code.typ"

= Methodology 
<apx-method>

#include "src/annex/methodology.typ"

= Examples
<apx-examples>

#include "src/annex/example.typ"

= Discarded Features
<apx-mechanics>

#include "src/annex/mechanics.typ"

= Implementation
<apx-impl>

#include "src/annex/implementation.typ"

= Data Analysis
<apx-data>

#include "src/annex/data.typ"

= Topology Ingestion and Sampling 
<apx-topology>

#include "src/annex/topology.typ"

= Sessions
<apx-sessions>

#include "src/annex/sessions.typ"

= Post Creation
<apx-creation>

#include "src/annex/postcreation.typ"

= Stability Plots
<apx-stability-plots>

#include "src/annex/stability-plots.typ"

= Random Timeline Experiment
<apx-random-timeline>

#include "src/annex/random-timeline.typ"

= Pipeline
<apx-pipeline>

#include "src/annex/pipeline.typ"

= Content Aware Posts
<apx-content>

#include "src/annex/future-content.typ"

= Hardware Specifications
<apx-hardware>

#include "src/annex/hardware.typ"

// = Software Stack
// <apx-software-stack>

// #include "src/annex/software-stack.typ"

// #pagebreak()

// #pagebreak()
// = Branching-Process Derivation of the Missing Tail
// <apx-branching>

// #include "src/annex/branching-math.typ"

