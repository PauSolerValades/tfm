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

// Shorthand for code listings. Caption is optional.
// Usage: #code(caption: "My listing")[```zig ... ```] <label>
#let code(body, caption: none) = {
  figure(
    kind: "code",
    supplement: [Code],
    caption: caption,
    body,
  )
}

// Shorthand for pseudocode / algorithm descriptions.
// Usage: #procedure(caption: "BFS")[Step 1: ...] <label>
#let procedure(body, caption: none) = {
  figure(
    kind: "procedure",
    supplement: [Procedure],
    caption: caption,
    body,
  )
}


