#let margins = (
  top: 3.5cm,
  bottom: 3cm,
  y: 1.8cm,
)
#let blue = rgb(43, 129, 173)
#let grey = rgb(100, 100, 100)

#set page(paper: "a4", margin: margins)

#set text(size: 11pt, font: "New Computer Modern", lang: "en")

#set par(spacing: 0.7em, leading: 0.7em, justify: true)

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

#include "cover.typ"

#counter(page).update(1)

= Abstract

#include "abstract.typ"


#pagebreak()
#outline()

#pagebreak()
= Introduction

#lorem(30)

#lorem(10)
- #lorem(30)
- #lorem(5)
- #lorem(50)

== Sub Introduction

#lorem(100)


= Section

#lorem(150)

= Another Section
