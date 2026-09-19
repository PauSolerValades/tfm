// Official UPC-FME cover page for the MESIO master's thesis.
//
// Source of truth: the Word original,
//   Portades 2025/Portades format DOC (MS Word)/english/report_MESIO_en.docx
//
// Every number below is taken from that file or its render:
//   - page size / margins : word/document.xml <w:sectPr><w:pgMar>
//   - blue bar, images    : <wp:anchor><wp:posOffset>/<wp:extent> (EMU, exact)
//   - text baselines      : text runs in the DOCX PDF export
//   - fonts / sizes       : word/styles.xml + word/fontTable.xml
//
// Do NOT use the ODT for this. Its "Arial MT" face is declared
// style:font-family-generic="roman" and lost the DOCX's <w:altName w:val="Arial"/>,
// so LibreOffice renders several runs in Times by mistake. The DOCX is correct.
//
// The cover is a fixed layout, not a text flow: everything is placed absolutely
// on the page, so `y` is always an exact baseline.

#import "utils.typ": todo

#let cover-sans = "Liberation Sans" // DOCX "Arial" / "Arial MT" (both resolve to Liberation Sans)
#let cover-blue = rgb("#0077c7") // <a:srgbClr val="0077C7"/>

// ---------------------------------------------------------------- data ----
#let thesis-title = [
  A Continuous-Time Independent Cascade Model on Bluesky using Discrete-Event Simulation
]
#let thesis-author = [Pau Soler Valadés]
#let thesis-director = [Esteve Codina, Jana Lasser and Pau Fontseca]
#let thesis-department = [#todo[confirm the official department name]]
#let thesis-city-date = [Barcelona, 22nd of September, 2026]
#let thesis-title-max-size = 33.5pt // "Ttulo" style: w:sz 67 half-points
// --------------------------------------------------------------------------

// Place text so that `y` is exactly the baseline (Word measures from baselines).
#let at(x, y, body) = place(top + left, dx: x, dy: y, body)
#let baseline(size, body) = text(top-edge: "baseline", size: size, body)

// The template's title is one line at 33.5pt; a real title is long, so shrink it
// until it fits between the header block and the drawing.
#let title-width = 16.04cm // text width, right of the blue bar
#let title-height = 2.9cm // ~3 lines at the template's size
#let title-block(size) = {
  set par(leading: 1.2em)
  text(
    font: cover-sans,
    weight: "bold",
    size: size,
    top-edge: "baseline",
    bottom-edge: "baseline",
    thesis-title,
  )
}
#let fitted-title() = context {
  let s = thesis-title-max-size
  while s > 12pt and measure(width: title-width, title-block(s)).height > title-height {
    s -= 0.25pt
  }
  title-block(s)
}

#page(paper: "a4", margin: 0pt, header: none, footer: none)[
  // Never justify, hyphenate or indent: the cover inherits nothing from the body.
  #set par(justify: false, first-line-indent: 0pt)
  #set text(hyphenate: false)

  // Left blue bar, full bleed.
  #place(top + left, rect(width: 2.3089cm, height: 29.7004cm, fill: cover-blue))

  // FME building sketch.
  #place(
    top + left,
    dx: 2.7207cm,
    dy: 10.9946cm,
    image("../images/cover/fme-building.png", width: 18.125cm, height: 7.8624cm),
  )

  // Bottom logos.
  #place(
    top + left,
    dx: 3.0053cm,
    dy: 26.242cm,
    image("../images/cover/upc-fme.png", width: 5.5764cm, height: 1.4552cm),
  )
  #place(
    top + left,
    dx: 9.3639cm,
    dy: 26.271cm,
    image("../images/cover/ub.jpg", width: 9.1122cm, height: 1.4076cm),
  )

  // Header block.
  #at(2.503cm, 2.8187cm)[
    #baseline(12pt)[
      #text(font: cover-sans)[UNIVERSITAT POLITÈCNICA DE CATALUNYA - BarcelonaTech (UPC)]
    ]
  ]
  #at(2.503cm, 3.3285cm)[
    #baseline(12pt)[
      #text(font: cover-sans, weight: "bold")[
        FME - FACULTAT DE MATEMÀTIQUES I ESTADÍSTICA
      ]
    ]
  ]
  #at(2.503cm, 4.4944cm)[
    #baseline(12pt)[
      #text(font: cover-sans, weight: "bold")[
        MASTER'S DEGREE IN STATISTICS AND OPERATIONS RESEARCH (MESIO UPC-UB)
      ]
    ]
  ]
  #at(2.503cm, 5.0042cm)[
    #baseline(12pt)[#text(font: cover-sans)[MASTER’S THESIS]]
  ]

  // Thesis title.
  #at(2.462cm, 7.3431cm)[#block(width: title-width, fitted-title())]

  // Author / director / department / place-date block.
  #at(2.487cm, 21.3625cm)[
    #baseline(12pt)[
      #text(font: cover-sans, weight: "bold")[Author:] #thesis-author
    ]
  ]
  #at(2.499cm, 22.0821cm)[
    #baseline(12pt)[
      #text(font: cover-sans, weight: "bold")[Director:] #thesis-director
    ]
  ]
  #at(2.499cm, 22.8018cm)[
    #baseline(12pt)[
      #text(font: cover-sans, weight: "bold")[Department:] #thesis-department
    ]
  ]
  #at(2.499cm, 23.5215cm)[
    #baseline(12pt)[#text(font: cover-sans)[#thesis-city-date]]
  ]
]
