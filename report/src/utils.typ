#let todo(body) = {
  set text(red)
  
  upper[*TODO: #body*]
}

#let comment(body) = {
  set text(blue)
  [#body]
}


