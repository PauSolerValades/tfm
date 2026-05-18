#let todo(body) = {
  set text(red)
  
  upper[*TODO: #body*]
}

#let comment(body) = {
  set text(blue)
  [#body]
}

#let def(body, name: "") = {
  if name == "" {
    block(above: 1.3em, below: 1.3em)[_*Definition*_ : #body ]
  } else {
    block(above: 1.3em, below: 1.3em)[_ *Definition* - #name _: #body ]
  }
}
