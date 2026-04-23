
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

#include "cover.typ"

#counter(page).update(1)

#set page(numbering: "i")
#heading(outlined: false, numbering: none)[Abstract]
#include "abstract.typ"

#pagebreak()
#outline()

#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
= Introduction

#include "introduction.typ"

#pagebreak()
= Context

#include "context.typ"

#pagebreak()
= Model
<sec-model>

#include "model.typ"

#pagebreak()
= Methodology

#include "methodology.typ"

#pagebreak()
= Design 
<sec-design>

#include "des.typ"

#pagebreak()
= Content approach: Embeddings

#include "ml.typ"





