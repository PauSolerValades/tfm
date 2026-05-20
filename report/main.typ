
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

// ----------------------------------------------------------
#include "src/cover.typ"

#counter(page).update(1)

#set page(numbering: "i")
#heading(outlined: false, numbering: none)[Abstract]
#include "src/abstract.typ"

#pagebreak()
#outline()

#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
= Introduction

#include "src/introduction.typ"

#pagebreak()
= Social Networks State of the Art

#include "src/sota.typ"

#pagebreak()
= Problem Formulation 
<sec-model>

#include "src/model.typ"

#pagebreak()
= Methodology

#include "src/methodology.typ"

#pagebreak()
= Simulation Design 
<sec-design>

#include "src/design.typ"

#pagebreak()
= Implementation
<sec-impl>

#include "src/implementation.typ"

#pagebreak()
= Data Analysis and Calibration
<sec-data>

#include "src/data.typ"


#pagebreak()
= Simulation Execution 

#include "src/results.typ"

#pagebreak()
= Conclusions

// #include "src/conclusions.typ"

#pagebreak()
= Future Work
<sec-future>

#include "src/futurework.typ"

#pagebreak()
#bibliography(
  ("refs/context.yml", "refs/methodology.yml", "refs/design.yml", "refs/implementation.yml", "refs/data.yml", "refs/futurework.yml"),
  title: "References",
)

#pagebreak()

// TODO: figure out how to do this properly

// #counter(heading).update(0)
// #set heading(numbering: none)
//
// = Appendix
//
// #set heading(numbering: "A")
//
// == Additional Mechanics 
// #include "src/mechanics.typ"
//

