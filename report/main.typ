
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

#show heading: it => [
  #block(above: 1.5em, below: 1em, it)
]

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
= Context & Background

#include "src/context.typ"

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

#include "src/des.typ"

#pagebreak()
= Data Analysis and Calibration

#include "src/calibration.typ"


#pagebreak()
= Results

// #include "src/results.typ"

#pagebreak()
= Conclusions

// #include "src/conclusions.typ"

#pagebreak()
= Future Work

// #include "src/ml.typ"


#bibliography(
  ("refs/context.yml"),
  title: "References",
)




