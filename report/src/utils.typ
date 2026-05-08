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
    [*Definition*: #body]
  } else {
    [*Definition* (#name): #body]
  }
}
