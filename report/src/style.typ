#let page_style(body) = {
  let margins = (
    top: 3.5cm,
    bottom: 3cm,
    y: 1.8cm,
  )
  let blue = rgb(43, 129, 173)
  let grey = rgb(100, 100, 100)

  set page(paper: "a4", margin: margins, numbering: "1")
  set text(size: 11pt, font: "New Computer Modern", lang: "en")
  set par(spacing: 0.7em, leading: 0.7em, justify: true, first-line-indent: 1.5em)

  // Add a bit of breathing room after figure captions
  show figure: it => {
    it
    v(0.6em)
  }

  body
}
