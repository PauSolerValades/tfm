#import "@preview/typslides:1.3.3": *

#import "@preview/cetz:0.5.2"
// ==========================================
// GLOBAL CONFIGURATION
// ==========================================
#show: typslides.with(
  ratio: "16-9",
  theme: "bluey",
  font: "New Computer Modern",
  font-size: 18pt,
  link-style: "color",
  show-progress: true,
)

#show heading: set text(font: "New Computer Modern", fill: rgb("#111111"))

// Image base path helper
#let img(path, width: auto) = {
  image("images/" + path, width: width)
}

// Simple grid column helper
#let col2(a, b) = grid(columns: 2, gutter: 2.5em, a, b)
#let col3(a, b, c) = grid(columns: 3, a, b, c)
#let col4(a, b, c, d) = grid(columns: 4, a, b, c, d)


// ==========================================
// PART 1: THE VISION & THE BOTTLENECK
// ==========================================

// --- TITLE SLIDE ---
#blank-slide[
  #v(4%)
  #set align(center)
  #text(size: 1.3em, weight: "bold", fill: rgb("#1a1a1a"))[
    Un Model de Cascada Independent en Temps Continu \ a Bluesky mitjançant Simulació d'Esdeveniments Discrets
  ]
  #v(0.6em)
  #text(size: 1.0em, style: "italic", fill: rgb("#4a4a4a"))[
    Treball de Fi de Màster — Màster en Estadística i Investigació Operativa
  ]
  #v(1em)
  #text(size: 1.0em, weight: "medium")[Pau Soler Valadés]

  #text(size: 0.85em, style: "italic", fill: rgb("#333333"))[
    Supervisat per Jana Lasser#super[2], Esteve Codina#super[1], i Pau Fontseca#super[1]
  ]
  #v(0.8em)
  #text(size: 0.75em, fill: rgb("#4a4a4a"))[
    #super[1] Universitat Politècnica de Catalunya #h(1em) #super[2] University of Graz
  ]
  #v(1.2em)
  #text(size: 0.75em, style: "italic", fill: rgb("#666666"))[
    23 de juliol de 2026 #sym.dash Facultat de Matemàtiques i Estadística 
  ]
]

// --- SLIDE: The Vision ---
#slide(title: "Context")[
  #set align(center)
  #text(size: 1.1em)[*Objectiu*: Estudiar la difusió d'informació en una xarxa social de microblogging.]

  #set align(left)
  #v(0.5em)
  
  *Definició*: La difusió d'informació és l'estudi de com peces discretes de contingut (d'ara endavant, publicacions) es propaguen a través d'una infraestructura de xarxa al llarg del temps.
  
  Quan les publicacions es propaguen, formen *cascades*, arbres formats pels usuaris que veuen i interactuen amb la publicació. Per tant,

  #v(0.3em)
  #set align(center)
  #text(size: 1.1em)[_La difusió d'informació_ és l'estudi de les _Cascades_ generades per la _Propagació de publicacions_.]

]

#slide(title: "Demostració de Cascades")[

  #set align(center)
  #text(size: 1.5em)[_Mostrar vídeo "Broadcast"_]

  #v(1.5em)
  #text(size: 1.5em)[_Mostrar vídeo "Cascade"_]
]

#slide(title: "Motivació")[
  L'anàlisi de cascades és *fonamental* per estudiar: la vida útil de les publicacions i la viralitat d'una publicació.

  *Definició* La _vida útil_ d'una publicació es defineix com el temps entre la creació de la publicació i l'última vegada que algú hi interactua.

  *Definició* La _Viralitat Estructural_ és la *distància mitjana entre dos nodes qualsevol d'una cascada* 

  $ nu(T) = frac(1, n(n-1)) sum_(i=1)^n sum_(j=1)^n d_(i j) $

  on $T$ és una cascada (un arbre) i $d_(i j)$ és la distància del camí més curt entre els nodes $i$ i $j$.
]

#slide(title: "Motivació")[
 
  Aquestes dues mètriques ens permeten detectar publicacions "rellevants":
  - Una publicació amb una vida útil alta és contagiosa: una idea que no mor mai i es segueix propagant en el temps.
  - Una publicació viral no és només aquella que molta gent veu ($|T|$ alt) sinó com es connecten: no ha de ser _superficial_ ni _estreta_ sinó profunda i àmplia *alhora*

  #v(1.0em)
  Ser capaços d'entendre i simular això pot jugar un paper important en problemes rellevants per a la societat com ara:
  + *Detecció de cambres de ressò.*
  + *Marcatge de difusors de desinformació.*
  + *Entendre la viralitat*: què diu una publicació vs qui l'ha escrit. 

]

#slide(title: "Aquest Projecte")[
  
  La difusió d'informació en una xarxa social de microblogging es pot caracteritzar per tres factors:
  - *Funcionalitats de la Plataforma:* característiques de la plataforma — feeds, timelines, recomendadors. \ _Com pot l'usuari interactuar amb el contingut_
  - *Dinàmica d'Usuari:* quan els usuaris es connecten — quant de temps fan scroll, amb quina freqüència creen contingut.\  _Com interactua l'usuari amb la plataforma_ 
  - *Interacció Usuari-Contingut:* alineació semàntica entre una publicació i les preferències de l'usuari. \ _Amb quin contingut interactua l'usuari_

  Aquest projecte aborda *Dinàmica d'Usuari* i *Funcionalitats de la Plataforma*, excloent específicament la _Interacció Usuari-Contingut_ per mantenir un abast raonable.

  #set align(center)
  #text(size: 1.3em)[*Proposta*: Simular múltiples cascades en una topologia de xarxa real per entendre com funciona la difusió d'informació.]
]

#slide(title: "Parts del Projecte")[
  #set text(size: 1.3em) 
  (1) - *Descripció del Problema*: \ Què volem avaluar i quin model utilitzem
  #v(0.1em)
  (2) - *Avaluació del Model*: \ Construir una simulació per avaluar el model
  #v(0.1em)
  (3) - *Anàlisi de Dades de Bluesky*: \ Mostreig i creació de topologies i calibració 
  #v(0.1em)
  (4) - *Calibració de la Simulació*: \ Quins valors han de tenir els paràmetres d'entrada
  #v(0.1em) 
  (5) - *Resultats de la Simulació*: \ Similitud amb dades reals i interpretació de resultats
  #v(0.1em)
]

#slide(title: "(1) - Protocol AT")[
  Bluesky és una plataforma de microblogging descentralitzada — un clon de Twitter, però construït sobre una especificació oberta, l'Authenticated Transfer Protocol, *ATProto*.

  #v(0.7em)
  L'ATP desacobla les dades de l'aplicació, separant la vista (AppView) de les dades — el *Firehose*.

  #v(0.7em)
  És fàcil escoltar tots els esdeveniments del firehose: creació de publicacions, republicacions, likes, follows, unfollows, bloquejos...
]


#slide(title: "(1) - Abast del Problema")[
  #v(0.2em)
  Modelem una plataforma de microblogging sota les següents simplificacions:

  #v(0.3em)
      - *Només el Feed de Seguits:* timelines cronològiques inverses (sense recomendadors)
      - *Usuaris i Seguidors Estàtics:* no hi ha usuaris ni follows nous mentre la simulació s'executa.
      - *Sense Silenciar ni Bloquejar:* seguir un usuari implica rebre totes les seves publicacions
      - *Sense Cites ni Respostes:* només likes i republicacions
      - *Sense Perfils d'Usuari:* els usuaris es limiten a la seva timeline, sense navegar per altres perfils

  #v(0.4em)
  #set align(center)
  #text(size: 1.3em)[Un usuari només pot fer dues coses amb una publicació: \ fer *like* o *republicar*, o simplement ignorar-la.]

]

#slide(title: "(1) - Intuïció del Model")[

  Donat un usuari $u in cal(U)$, té una timeline $cal(T)_t (u)$ plena de publicacions $i in cal(I)$. 

  Idea principal: l'usuari està en línia, fa *scroll* per la seva timeline, i pot interactuar amb una publicació fent *like* o *republicant*, o simplement *ignorar-la* i seguir fent scroll.

  Quan $u$ republica $i$, $i$ es *propaga* als seguidors de $u$, $cal(N)_"out" (u)$:

  $"per a" v "en" cal(N)_"out" (u): "push"(cal(T)_t (v), i) $

  Però $v in cal(N)_"out" (u)$ no veurà immediatament el contingut republicat $i$ si porta una estona fent scroll, ja que l'usuari veu contingut _passat_, així que s'encua a $cal(T)_t (v)$.

  Quan $v$ es connecta de nou i comença a fer scroll, eventualment veurà $i$ si el temps que $v$ ha estat en línia no és massa llarg: altrament $i$ mai tindrà l'oportunitat de propagar-se. 
]

#slide(title: "(1) - Escena d'Intuïció")[
  
  #set align(center)
  #text(size: 1.5em)[_Mostrar vídeo "Queue"_]
]


#slide(title: "(1) - Cascada Independent en Temps Continu")[
  #v(0.3em)
  #text(size: 0.9em, weight: "bold")[*Definició.*] El model CTIC preserva la transmissió independent a través de les arestes però substitueix probabilitats fixes per passos per una probabilitat de transmissió dependent del temps. Cada aresta té una taxa de transmissió per parells $alpha_(j,i)$ 
  #v(0.5em)
  #set align(center)
  Un cop l'usuari $u$ ha propagat una publicació $i$ a $t_u$ —assumint que $v$ també la propagarà—, el seguidor $v$ republicarà $v$ en un temps posterior $t_v > t_u$ assu
  #v(2em)

 #cetz.canvas({
    import cetz.draw: *
    // Your drawing code goes here
    line((0, 0), (12, 0), stroke: 1pt)
    content((0, -.25), [$t_u$], anchor: "north")
    
    // first tick
    line((0, -0.15), (0, 0.15), stroke: 1pt)
    content((0, .75), [$"prop"(u, i)$], anchor: "south")
    
    // last tick
    line((12, -0.15), (12, 0.15), stroke: 1pt)
    content((12, -.25), [$t_v$], anchor: "north")
    content((12, .75), [$"prop"(v, i)$], anchor: "south")
    
    line((3, -0.15), (3, 0.15), stroke: 1pt)
    content((3, .75), [$i in cal(T)(v)$], anchor: "south")
  
    content((1.5, -.25), [$Delta_p$], anchor: "north")

    content((5, -.25), [$X$], anchor: "north")

    line((7, -0.15), (7, 0.15), stroke: 1pt)
    content((7, .75), [$v$ sees $i$], anchor: "south")

    content((9.5, -.25), [$Delta_a$], anchor: "north")
  })
  
  #text(size: .75em)[Exemple de línia temporal de la propagació CTIC. El temps entre $t_u$ i $t_v$ depèn de la xarxa, representat per la VA $X$.]
]

#slide(title: "(1) - Basat en Activitat i en Cues")[

  #v(0.3em)
  *Basat en Activitat.* els usuaris no estan sempre en línia interactuant. Cada usuari alterna entre sessions en línia i períodes fora de línia:

  $ cal(O)(u) = union.big_(k=1)^oo [t_k, t_k + Delta_k) $

  on $Delta_k$ és la durada de la sessió.

  #v(0.3em)
  
  *Basat en Cues.* La timeline de cada usuari $cal(T)_t(u)$ és una cua de prioritat ordenada per temps d'arribada ---la publicació més recent arriba a dalt de tot. Si l'usuari està en línia, les consumirà; si no, es quedaran pendents.
]

#slide(title: "(2) - Avaluació del Model")[
  El model proposat és massa complex per ser avaluat analíticament: l'ús d'una simulació és obligatori.

  #v(3em)
  #set align(center)
  #text(size: 1.5em)[_Mostrar vídeo "Visualization"_]

]

// --- SLIDE: ABM vs DES ---
// #slide(title: "Why not Agent-Based Modeling?", back-color: rgb("#fff3e0"))[
//   #col2(
//     [
//       #text(size: 0.9em, weight: "bold")[Agent-Based Modeling]
//       #v(0.2em)
//       - Bottom-up: each user is an autonomous agent with its own perception, state, and decision-making
//       - Even when event-driven, every agent's individual state must still be maintained and evaluated
//       - The agent-centric architecture means effort inherently scales with $N$
//       - High development cost: perception, individual cognition, inter-agent communication
//     ],
//     [
//       #text(size: 0.9em, weight: "bold")[Discrete-Event Simulation]
//       #v(0.2em)
//       - Top-down: entities flow through processes and queues — behavior dictated by system logic, not agent autonomy
//       - Jumps from event to event, bypassing idle intervals entirely
//       - No work for offline users — exploits the *intrinsic sparsity* of human activity
//       - Lean: probability distributions and routing rules, not individual cognition
//     ],
//   )
//
//   #v(0.4em)
//   #text(size: 0.8em)[
//     Both can be event-driven. The difference is philosophical: ABM models *who decides*, DES models *what happens*.
//     When the question is *aggregate diffusion dynamics*, DES routes effort where it matters —
//     the propagation events that actually drive the dynamics — rather than maintaining agent autonomy.
//   ]
// ]



// --- SLIDE: Simulation Rules ---
#slide(title: "(2) - Normes de la Simulació")[
  #v(0.2em)
  Enunciem explícitament les *normes* que segueix la simulació (recull del que hem vist fins ara)

  1. Un usuari només pot actuar de tres maneres sobre una publicació: *ignorar*, *like* i *republicar*.
  2. Un usuari està en línia o fora de línia.
  3. Un usuari fora de línia no pot fer cap acció.
  4. Una propagació es dispara amb una creació de publicació o una republicació.
  5. Una propagació per $u$ afegeix totes les publicacions a $cal(N)_"out" (u)$
  6. Cada usuari té una timeline $cal(T)_t (u)$ que és cronològica inversa (cua de prioritat, max)
  7. Un usuari no pot interactuar amb una publicació amb la qual ja ha interactuat.
  8. Si $cal(T)_t (u) = emptyset$, l'usuari torna a fora de línia (avorriment).
]

// --- SLIDE: Input Parameters ---
#slide(title: "(2) - Paràmetres d'Entrada")[
  
  Tots aquests paràmetres seguiran una distribució especificada: 
  
  #col2(
    [
      *Paràmetres globals*
      #v(0.15em)
      - Retard de propagació $Delta_p$ — temps perquè una publicació arribi als seguidors
      - Retard d'interacció — temps cognitiu abans de reaccionar a una publicació
      - Retard de creació — temps per compondre i publicar
      - Temps entre accions — interval entre comprovacions consecutives de la timeline
      - Política $pi$: $p_"ignore"$, $p_"like"$, $p_"repost"$
      - Horitzó $t_h$ i escalfament $t_w$
      - Ràtio d'inici fora de línia — fracció d'usuaris que comencen fora de línia
    ],
    [
      *Paràmetres dependents de l'usuari* (mostrejats per usuari)
      #v(0.15em)
      - Durada de sessió $Delta_k$ — quant de temps roman en línia
      - Interval entre sessions — temps fora de línia entre sessions consecutives
      - Interval entre publicacions — temps entre publicacions del mateix usuari
      #v(0.3em)
    ],
  )
]

// --- SLIDE: Event Sources ---
#slide(title: "(2) - Disseny de la Simulació")[
  La cua global $Q$ és un min-heap, retorna l'esdeveniment amb el timestamp més petit (següent esdeveniment a processar)

  Un sol usuari pot tenir dos conjunts d'esdeveniments:
  - `session.start`: quan l'usuari tornarà a estar en línia.
  - `create`, `action`, `session.end` i `propagate`: Action és interactuar amb una publicació, create és generar una publicació. Si és una creació o una republicació, un esdeveniment `propagate` es dispararà en el futur i l'últim és `session.end`, que fa que l'usuari passi a fora de línia.

  $Q$ conté *tots* els esdeveniments de *cada* usuari. Pitjor cas, 4 esdeveniments per usuari, per tant $|Q| approx 4N$.

  Per tant, com *més usuaris* a la simulació, més carregada estarà $Q$.

]

// --- SLIDE: Single User Event Timeline ---
// #slide(title: "(2) - Single User Session Timeline")[
//   #v(0.3em)
//   #text(size: 0.85em, weight: "bold")[A single user's session is a chain of events — no propagation, just the user's own activity.]
//
//   #v(2em)
//
//   #cetz.canvas({
//     import cetz.draw: *
//
//     // Main timeline
//     line((0, 0), (18, 0), stroke: 1.4pt)
//
//     // ---- Tick 1: session.start ----
//     line((0, -0.2), (0, 0.2), stroke: 1.2pt)
//     content((0, -.45), [$e_(s)$], anchor: "north")
//     content((0, .85), [*session.start*], anchor: "south")
//     content((0, 1.6), [user goes online], anchor: "south")
//
//     // ---- Tick 2: create ----
//     line((4.5, -0.2), (4.5, 0.2), stroke: 1.2pt)
//     content((4.5, -.45), [$e_c$], anchor: "north")
//     content((4.5, .85), [*create*], anchor: "south")
//     content((4.5, 1.6), [user authors a post], anchor: "south")
//
//     // ---- Tick 3: first action ----
//     line((9.0, -0.2), (9.0, 0.2), stroke: 1.2pt)
//     content((9.0, -.45), [$e_(a_1)$], anchor: "north")
//     content((9.0, .85), [*action*], anchor: "south")
//     content((9.0, 1.6), [like / repost / ignore], anchor: "south")
//
//     // ---- Tick 4: second action ----
//     line((13.5, -0.2), (13.5, 0.2), stroke: 1.2pt)
//     content((13.5, -.45), [$e_(a_2)$], anchor: "north")
//     content((13.5, .85), [*action*], anchor: "south")
//     content((13.5, 1.6), [like / repost / ignore], anchor: "south")
//
//     // ---- Tick 5: session.end ----
//     line((18.0, -0.2), (18.0, 0.2), stroke: 1.2pt)
//     content((18.0, -.45), [$e_(e)$], anchor: "north")
//     content((18.0, .85), [*session.end*], anchor: "south")
//     content((18.0, 1.6), [user goes offline], anchor: "south")
//
//     // ---- Random variable labels below ----
//     content((2.25, -.8), [$Delta_"create"$], anchor: "north")
//     content((6.75, -.8), [$X tilde "Exp"(lambda)$], anchor: "north")
//     content((11.25, -.8), [$Y tilde "Exp"(lambda)$], anchor: "north")
//     content((15.75, -.8), [$Delta_"session"$], anchor: "north")
//
//     // ---- Session span bracket above ----
//     line((0, 1.85), (0, 2.15), stroke: .6pt)
//     line((18.0, 1.85), (18.0, 2.15), stroke: .6pt)
//     line((0, 2.15), (18.0, 2.15), stroke: .6pt)
//     content((9.0, 2.4), [*one session*], anchor: "south")
//   })
//
//   #v(0.8em)
//   #text(size: 0.75em)[
//     Events $e_(s)$, $e_c$, $e_(a_1)$, $e_(a_2)$, and $e_(e)$ form a single user session.
//     Inter-action times $X, Y tilde "Exp"(lambda)$ are i.i.d. between consecutive actions.
//     The session ends at $e_(e)$ — by boredom (empty timeline) or session duration limit.
//   ]
// ]

// --- SLIDE: Simulation Lifecycle ---
#slide(title: "(2) - Cicle de Vida de la Simulació")[

  Per assegurar que les timelines no comencen buides, la simulació té tres etapes:

  #v(0.4em)
  #col3(
    framed(title: [Etapa 1: Escalfament], back-color: rgb("#e8f5e9"))[
      $t in [0, 1000]$ \
       Tots els usuaris en línia \
       Només creació de publicacions \
       Omple les timelines \
    ],
    framed(title: [Etapa 2: Arrencada], back-color: rgb("#fff8e1"))[
      $t = 1000$ \
       Assignar en línia/fora de línia \
       Preparar la cua d'esdeveniments \
       Sessió i acció \
    ],
    framed(title: [Etapa 3: Bucle Principal], back-color: rgb("#e3f2fd"))[
      $t in [1000, 5000]$ \
       Extreure min-time de $Q$ \
       Enviar al gestor \
       Programar seguiments \
    ],
  )
]

// --- SLIDE: Implementation ---
#slide(title: "(2) - Implementació")[
  
  La simulació s'ha escrit en Zig, un llenguatge de programació de sistemes. Pensa en C però amb seguretat integrada i millores de qualitat de vida.

  *Per què?*
  1. Assegurar un temps d'execució raonable per executar la simulació múltiples vegades, per garantir significança estadística, fins i tot per a grans conjunts de dades.
  2. Em preocupo per la qualitat i el meu ofici; és responsabilitat del programador oferir un programa d'alt rendiment, sota _qualsevol_ circumstància.
  3. Dubtes raonables sobre el rendiment d'altres programes de simulació ja existents.

  S'han aplicat principis de *Disseny Orientat a Dades* per fer el programa tan òptim com sigui possible.
]

#slide(title: "(3) - Anàlisi de Dades de Bluesky")[
  `IDea_lab` de la UniGraz ha recopilat 1.4 anys de dades del Firehose.

  1. Obtenció de Topologia: processament dels 1.4 anys complets de dades, filtrar els follows, unfollows i bloquejos per reconstruir una xarxa de ($28.2 times 10^6$) usuaris amb $1.4 times 10^9$ follows. Obtenció de 7 conjunts de dades diferents amb l'algorisme *Forest Fire*: 10K, 50K, 100K, 250K, 500K, 750K, 1M. 

  2. Comparació de Resultats i Calibració: per *obtenir el valor dels paràmetres d'entrada* s'han analitzat 6 dies complets de dades: 
  - *Definició de sessió* per usuari per determinar la majoria de paràmetres d'entrada. 
  - Distribució de l'anàlisi de vida útil de publicacions.
  - Reconstrucció de cascades per a cada publicació creada aquests 6 dies i anàlisi de viralitat estructural.

  Vides útils i Cascades es tractaran conjuntament a (5) - Resultats.
]

// --- SLIDE: Session Building ---
#slide(title: "(4) - Construcció de Sessions")[

  El conjunt de dades de 6 dies conté $1.63 times 10^6$ usuaris amb almenys una acció. El càlcul de sessió és diferent per a cada un d'aquests usuaris.

  *Enfocament:* Detecció d'outliers IQR de Tukey aplicada per usuari sobre els intervals entre els seus esdeveniments. 
  
  $ "Tukey"(u) = Q_3(u) + 1.5 · (Q_3 (u) - Q_1 (u)) $


  Degut a vàries sessions molt petites (un o dos esdeveniments), calculem la sessió definint que una sessió té *almenys* 60s de durada:

  $ delta(u) = max(120 s, thin space Q_3(u) + 1.5 dot "IQR"(u) ) $

  #v(1.0em)
  #set align(center)
  
#cetz.canvas({
  import cetz.draw: *
  
  // -----------------------------------------------------------------
  // 1. TIMELINE BASE
  // -----------------------------------------------------------------
  let timeline-y = 0
  line((0, timeline-y), (17, timeline-y), stroke: 0.75pt + luma(100))
  content((17.2, timeline-y), [$t$], anchor: "west")
  
  // -----------------------------------------------------------------
  // SESSION A: Short Cluster (3 events)
  // -----------------------------------------------------------------
  let ev1 = 0.5; let ev2 = 1.2; let ev3 = 2.2
  
  line((ev1, timeline-y - 0.1), (ev1, timeline-y + 0.1), stroke: 1pt)
  content((ev1, timeline-y + 0.2), [Lk], anchor: "south", size: 9pt)
  
  line((ev2, timeline-y - 0.1), (ev2, timeline-y + 0.1), stroke: 1pt)
  content((ev2, timeline-y + 0.2), [Rp], anchor: "south", size: 9pt)
  
  line((ev3, timeline-y - 0.1), (ev3, timeline-y + 0.1), stroke: 1pt)
  content((ev3, timeline-y + 0.2), [Cr], anchor: "south", size: 9pt)
  
  // Red Session A Span
  let s1-y = timeline-y - 0.8
  line((ev1, s1-y), (ev3, s1-y), stroke: 2pt + red)
  line((ev1, s1-y - 0.1), (ev1, s1-y + 0.1), stroke: 1.5pt + red)
  line((ev3, s1-y - 0.1), (ev3, s1-y + 0.1), stroke: 1.5pt + red)
  content(((ev1 + ev3)/2, s1-y - 0.1), [Session $A$], anchor: "north", text-color: red)

  // -----------------------------------------------------------------
  // INTER-SESSION GAP (Massive blue gap before Session B)
  // -----------------------------------------------------------------
  let ev4 = 11.0 // Large jump to start next session
  let gap-y = timeline-y - 1.8
  
  line((ev3, gap-y), (ev4, gap-y), stroke: 2pt + blue)
  line((ev3, gap-y - 0.1), (ev3, gap-y + 0.1), stroke: 1.5pt + blue)
  line((ev4, gap-y - 0.1), (ev4, gap-y + 0.1), stroke: 1.5pt + blue)
  content(((ev3 + ev4)/2, gap-y - 0.1), [Gap $>= delta(u)$ (Min 120s)], anchor: "north", text-color: blue)
  
  // Dotted vertical project line to align with the gap start/end
  line((ev3, s1-y), (ev3, gap-y), stroke: (paint: blue, dash: "dashed", thickness: 0.5pt))
  line((ev4, timeline-y), (ev4, gap-y), stroke: (paint: blue, dash: "dashed", thickness: 0.5pt))

  // -----------------------------------------------------------------
  // SESSION B: Long Cluster (5 events)
  // -----------------------------------------------------------------
  let ev5 = 12.0; let ev6 = 13.2; let ev7 = 14.5; let ev8 = 16.0
  
  line((ev4, timeline-y - 0.1), (ev4, timeline-y + 0.1), stroke: 1pt)
  content((ev4, timeline-y + 0.2), [Lk], anchor: "south", size: 9pt)
  
  line((ev5, timeline-y - 0.1), (ev5, timeline-y + 0.1), stroke: 1pt)
  content((ev5, timeline-y + 0.2), [Rp], anchor: "south", size: 9pt)
  
  line((ev6, timeline-y - 0.1), (ev6, timeline-y + 0.1), stroke: 1pt)
  content((ev6, timeline-y + 0.2), [Fl], anchor: "south", size: 9pt)

  line((ev7, timeline-y - 0.1), (ev7, timeline-y + 0.1), stroke: 1pt)
  content((ev7, timeline-y + 0.2), [Cr], anchor: "south", size: 9pt)

  line((ev8, timeline-y - 0.1), (ev8, timeline-y + 0.1), stroke: 1pt)
  content((ev8, timeline-y + 0.2), [Lk], anchor: "south", size: 9pt)
  
  // Red Session B Span
  line((ev4, s1-y), (ev8, s1-y), stroke: 2pt + red)
  line((ev4, s1-y - 0.1), (ev4, s1-y + 0.1), stroke: 1.5pt + red)
  line((ev8, s1-y - 0.1), (ev8, s1-y + 0.1), stroke: 1.5pt + red)
  content(((ev4 + ev8)/2, s1-y - 0.1), [Session $B$], anchor: "north", text-color: red)
})

]

#slide(title: "(4) - Anàlisi de Sessions")[
#figure(
  table(
    columns: 2,
    align: (left, center),
    stroke: none,
    table.hline(stroke: 0.8pt),
    [*Mètrica*], [*sessions_all*],
    table.hline(stroke: 0.5pt),
    [Sessions], [$47.4 times 10^6$],
    [Durada mediana], [23 s],
    [Durada mitjana], [882 s],
    [Interval medià entre sessions], [36.5 min],
    [Sessions de durada zero], [33.2%],
    [Interval medià per usuari], [2.4 min],
    [Sessions només likes], [59.2%],
    table.hline(stroke: 0.8pt),
  ),
  caption: [Resum estadístic a nivell de sessió per `sessions_all` ($47.4 times 10^6$ sessions, $2.3 times 10^6$ usuaris).]
)
]

#slide(title: [(4) - `session_duration`, `inter-session-gap` i `inter-post creation`])[
  #figure(
    table(
      columns: 4,
      align: (left, center, center, center),
      stroke: none,
      table.hline(stroke: 0.8pt),
      [*Distribució*], [*Durada de sessió*], [*Interval entre sessions*], [*Interval entre accions*],
      table.hline(stroke: 0.5pt),
      [Power-law], [53.0%], [50.6%], [63.1%],
      [Lognormal], [9.0%], [25.9%], [21.3%],
      [Weibull], [9.5%], [22.3%], [13.8%],
      [Exponencial], [12.6%], [$< 0.01$%], [-],
      [Gamma], [2.1%], [$< 0.01$%], [0.2%],
      table.hline(stroke: 0.8pt),
    ),
    caption: [Millor ajust de distribució per $1.16 times 10^6$ usuaris amb $>= 10$ sessions de `sessions_all`. La power-law domina totes les quantitats. Test de raó de log-versemblança de Vuong amb desempat AIC.]
  )

  #set align(center)
  #v(1em)
  Els paràmetres de cada distribució també s'han modelat, tot i que no es mostren.
]

// --- SLIDE: Calibration ---
#slide(title: [(4) - Temps entre accions])[

  #set align(center)
  #text(size: 1.15em)[Únic paràmetre d'entrada realment lliure: *no es pot obtenir de les dades*.]
  
  #set align(left)

  Modelar "quantes publicacions veu un usuari per unitat de temps". Hauria d'ignorar la majoria de publicacions, simulant lectura ràpida i saltar-se contingut quan s'avorreix.

  #set align(center)
  #text(size: 1.3em)[*Resposta*: $"Exp"(lambda), space lambda = 1/3$]
  #set align(left)

  De mitjana, un usuari veu una publicació cada tres segons. Intervals exponencials $=>$ procés de Poisson, bona suposició per defecte, aproximadament 20 publicacions/minut.

]

#slide(title: [(4) - Política d'Usuari $pi$])[
  Amb la quantitat "publicacions/temps", podem estimar *quantes publicacions per sessió* veu un usuari i quina *taxa d'interacció*: *amb quantes interactua*.


  $ "Engagement"(s) = frac("interaccions"(s), "posts_vistos_per_sessió"(s)) $

  La distribució d'interacció té la mediana al *$20%$* de la densitat, per tant *un usuari interactua amb 1 de cada 5 publicacions que veu.*

  Sabent que $1/5$ de les publicacions s'interactuen, i que de totes les interaccions al conjunt de dades
  - likes són el 93.8%
  - republicacions són el 6.2%

  Podem definir la *Política d'Usuari* com
  
  $ pi = (p_"ignore", p_"like", p_"repost") = (1 - 1/5, 1/5 · 0.938, 1/5 · 0.062) = (0.8, 0.188, 0.012) $

]

// --- SLIDE: Statistical Reproducibility ---
#slide(title: "(4) - Horitzó")[

  #v(0.2em)
  #figure(
    image("images/results/100K_session_trace_stationary.png", width: 80%),
    caption: [Mitjana mòbil dels recomptes de sessió sobre l'horitzó del dataset 100K, utilitzada per verificar l'estacionarietat de la distribució.]
  )

  Amb 1000 ticks d'escalfament, i una durada de 5000 ticks, estem definitivament assolint l'estacionarietat.
]

#slide(title: "(5) - Paràmetres")[

  Paràmetres d'entrada:
  - horizon: 6001,
  - duration: 5000
  - warm-up: 1000
  - $pi = (p_"ignore", p_"like", p_"repost") = (0.8, 0.188, 0.012)$
  - user_inter_action: $X ~ "Exp" space E[X] = 3$
  - warmup_post_inter_creation: $U ~ "Unif"(0, 1000)$
  - propagation, interaction and creation delay: $Delta_({p, i, c})= 1$
  - offline_startup_ratio: $1/2$
  
  Per usuari:
  - inter_session_time: $I ~ "Pareto"(alpha, x_min)$
  - session_length: $I ~ "Pareto"(alpha, x_min)$
  - inter_post_creation: $I ~ "Pareto"(alpha, x_min)$
  

]

#slide(title: "(4) - Experiments")[

  Hem executat tres datasets: 100K, 500K i 1M.

  #figure(
    table(
      columns: 3,
      align: (left, center, center),
      stroke: none,
      table.hline(stroke: 0.8pt),
      [*Dataset*], [*Users*], [*Runs*],
      table.hline(stroke: 0.5pt),
      [100K], [100,000], [1,600],
      [500K], [500,000], [136],
      [1M],   [1,000,000], [10],
      table.hline(stroke: 0.8pt),
    ),
    caption: [Execucions de simulació per dataset. Menys execucions per a topologies més grans degut al cost computacional.]
  )

  Assumeu que les figures són del dataset 100K llevat que s'indiqui el contrari, ja que els resultats estan en la mateixa línia pels tres datasets.
]

#slide(title: "(4) - Creixement")[
  #v(0.2em)
  #grid(
    columns: (3fr, 1fr),
    gutter: 2.5em,
    [
      #img("results/execution_time_scaling.png", width: 90%)
    ],
    [
      #v(0.15em)
      - $R^2 = 1.000$
      - pendent = 1.42. 
      - 100K: ~1.4 min/execució
      - 500K: ~10.8 min/execució
      - 1M: ~22.6 min/execució
    ],
  )
]

#slide(title: "(4) - Rendiment")[
  *El creixement en temps lineal és excepcional.*
  #v(0.15em)
  - Doblar usuaris simplement "dobla" el temps ($R^2 = 1.000$)
  - 100K en ~1.4 min, 500K en ~10.8 min, 1M en ~22.6 min
  - *Permet replicació massiva sense explotar el temps d'execució* Objectiu Aconseguit!

  *La memòria quadràtica és el coll d'ampolla.*

  #v(0.2em)
  - Dues instàncies `PagedBitSet` registren publicacions vistes i interactuades: $N times M$ bits cadascuna
  - $M$ creix amb $N$ (més usuaris → més publicacions) → $O(N^2)$ pitjor cas
  - $100K -> 32 "GB", 500K -> 200 "GB", 1M -> 1000 "GB" approx 1"TB"$
  - Definitivament solucionable amb una heurística d'alliberament de memòria per publicacions mortes!

  #v(0.4em)
  *Hardware*: 2× AMD EPYC 9654 (192c / 384t), 1.1 TB DDR5
]


#slide(title: "(4) - Power-law de republicacions totals")[
  #set text(0.85em)
  En una simulació, si ordenem les publicacions per nombre de republicacions, seguiran una power-law.
  Bluesky: $gamma = 2.21$ Simulació: $gamma = 1.73$

  #v(0.2em)
  #align(center)[
    #img("results/repost_comparison.png", width: 65%)
  ]

]

// --- SLIDE: Structural Virality — Simulation vs Bluesky ---
#slide(title: "(4) - Viralitat Estructural — Model vs Dades")[
  #v(0.1em)
  #figure(
    table(
      columns: 4,
      align: (left, center, center, center),
      stroke: none,
      table.hline(stroke: 0.8pt),
      [*Mètrica*], [*Simulació (100K)*], [*Dades Bluesky*], [*Coincideix?*],
      table.hline(stroke: 0.5pt),
      [Mitjana $nu$], [1.90], [1.35], [Més alt],
      [Mediana $nu$], [1.67], [1.00], [Més alt],
      [$P_95$ $nu$], [3.33], [2.98], [$approx$ igual],
      [Màx $nu$], [26.9], [80.7], [Més baix],
      [% broadcast pur ($nu = 1.0$)], [0% (mín 1.33)], [54.7%], [Falta],
      [% cadenes mínimes ($nu <= 1.34$)], [$approx 39%$], [—], [—],
      table.hline(stroke: 0.8pt),
    ),
    caption: [Simulació (100K, $n = 1600$ execucions) vs Bluesky ($4.4 times 10^6$ cascades).]
  )
]

#slide(title: "(4) - Viralitat Estructural — Interpretació")[
  *Què reprodueix bé el model:*
  #v(0.1em)
  - Els valors $P_95$ de viralitat són consistents ($3.33$ vs $2.98$)
  - La cua dreta pesada — existeixen cascades virals rares en ambdós
  - $approx 39%$ de les cascades són cadenes mínimes — estructuralment simples

  #v(0.25em)
  *Què no aconsegueix el model:*
  #v(0.1em)
  - Cascades broadcast pures ($nu = 1.0$): 54.7% en la realitat, però el mínim de la simulació és $approx 1.33$ degut a la reconstrucció de l'arbre
  - El $nu$ màxim és més baix ($26.9$ vs $80.7$) — no arriba a la cua viral extrema
  - $p_"repost" = 0.012$ homogeni aplana la distribució: massa arbres moderadament ramificats, massa poques estrelles planes
]

#slide(title: "(4) - Viralitat Estructural — Comparació")[
  #v(0.1em)
  #col2(
    align(center)[
      #image("figures/s4_virality_hist_100K.png", width: 100%)
      #text(size: 0.55em)[Simulació (100K)]
    ],
    align(center)[
      #image("images/data/6-4_virality_distribution.png", width: 100%)
      #text(size: 0.55em)[Dades Bluesky]
    ],
  )
]

// --- SLIDE: Post Lifetimes — Simulation vs Bluesky ---
#slide(title: "Vida Útil de Publicacions — Model vs Dades")[
  #v(0.1em)
  #figure(
    table(
      columns: 4,
      align: (left, center, center, center),
      stroke: none,
      table.hline(stroke: 0.8pt),
      [*Mètrica*], [*Simulació (100K)*], [*Dades Bluesky*], [*Coincideix?*],
      table.hline(stroke: 0.5pt),
      [% publicacions sense interacció], [$29.1%$], [$50.7%$], [Més baix],
      [% publicacions amb interacció i $>= 1$ repost], [$32$–$35%$], [$33.1%$], [$approx$ igual],
      [Vida útil mediana (amb reposts)], [471 ticks], [3.8 h], [—],
      [Vida útil mitjana (amb reposts)], [843 ticks], [cua: Pareto $alpha = 2.16$], [—],
      [Cua de vida útil], [Pesada (power-law)], [Pareto $alpha = 2.16$], [$approx$ igual],
      table.hline(stroke: 0.8pt),
    ),
    caption: [Simulació (100K, $n = 1600$ execucions) vs Bluesky ($15.3 times 10^6$ publicacions).]
  )
]

#slide(title: "Vida Útil de Publicacions — Interpretació")[
  *Què reprodueix bé el model:*
  #v(0.15em)
  - Forma de la cua de vida útil: ambdues segueixen decaïment power-law
  - Entre publicacions que reben interacció, la fracció amb $>= 1$ repost coincideix ($32$–$35%$ vs $33.1%$)

  #v(0.3em)
  *Què no aconsegueix el model:*
  #v(0.15em)
  - Publicacions mortes: només 29% sense interacció a la simulació vs 51% en la realitat
  - $p_"repost" = 0.012$ homogeni dona a cada publicació la mateixa probabilitat de sobreviure — el contingut real té atractiu heterogeni
  - La simulació produeix massa publicacions *moderadament* interactuades i massa poques de realment mortes
  - Solució: introduir qualitat / atractiu heterogeni de les publicacions (treball futur)
]

// --- SLIDE: Timeline Starvation ---
#slide(title: "Fam de Timeline")[
  #v(0.2em)
  #text(size: 1em, weight: "bold")[Un fenomen emergent: ~50% de les sessions acaben buides.]

  #v(0.3em)
  #col2(
    align(center)[
      #image("figures/s2_backlog_hist_100K.png", width: 100%)
      #text(size: 0.65em)[Distribució del backlog (100K): el zero domina]
    ],
    [
      *El mecanisme d'avorriment:* quan un usuari esgota \
      la seva timeline, la sessió s'acaba.

      - 50.9% (100K) / 45.9% (500K) / 53.0% (1M) \
        de les sessions acaben buides
      - 19–27% de les sessions tenen *zero accions*
      - Causa arrel: la timeline es buida quan l'usuari \
        passa a fora de línia
    ],
  )

  #v(0.3em)
  #text(size: 0.8em)[*Troballa clau:* El nombre de seguidors *no té efecte* sobre la fam — és un efecte temporal, no topològic. Les sessions durant períodes tranquils pateixen fam independentment del grau.]
]

// --- SLIDE: Session Engagement ---
#slide(title: "Interacció a les Sessions")[
  #v(0.2em)
  #text(size: 1em, weight: "bold")[L'avorriment bifurca la població d'usuaris.]

  #v(0.3em)
  #col2(
    align(center)[
      #image("figures/s2_duration_vs_empty_100K.png", width: 95%)
      #text(size: 0.65em)[Buides vs no buides (100K): 9.5× de diferència]
    ],
    [
      *Dos règims:*
      - *Famolencs:* mediana 12 ticks, surten buits
      - *Interactuadors:* mediana 105 ticks, es queden pel contingut

      Els republicadors tenen sessions 2–3× més llargues \
      que els que mai republicen.

      *Bucle de retroalimentació:* els usuaris que impulsen \
      la propagació de cascades són els mateixos que sostenen la interacció a la plataforma.
    ],
  )
]

// --- SLIDE: Limitations ---
#slide(title: "Limitacions")[
  #v(0.2em)
  #col2(
    [
      *Model*
      #v(0.15em)
      - Fam de timeline (~50% de sortides buides) — _probablement_ el mecanisme d'avorriment és massa agressiu, necessita un mecanisme de reinici complementari
      - Homogeneïtat de publicacions — totes les publicacions són mercaderies sense semàntica; sense consciència de contingut
      - Política d'acció $pi$ idèntica per a tots els usuaris — tot i que els paràmetres de sessió són heterogenis
      - $gamma_"sim" = 1.73$ vs $gamma_"real" = 2.21$ — la política de republicació uniforme aplana la cua de la cascada
    ],
    [
      *Enginyeria*
      #v(0.15em)
      - Memòria $O(N^2)$ per a matrius d'impressions — domina a escala (1M → 800 GB)
      - Cua d'esdeveniments $O(log n)$ — heap binari; una Calendar Queue donaria $O(1)$ amortitzat
      - Execució d'un sol fil amb recàrrega repetida de topologia per procés
      - Sense perfilat rigorós — els colls d'ampolla reals s'hipotetitzen, no es mesuren
    ],
  )
]

#slide(title: "Conclusions")[
  *Contribució del model.*
  #v(0.1em)
  - Model CTIC + retard basat en cues + xarxa basada en activitat replica amb èxit la dinàmica de difusió d'informació
  - Motor DES d'alt rendiment (temps $O(N)$) va permetre 1700+ replicacions a través d'escales de fins a 1M usuaris

  #v(0.3em)
  *Què va funcionar.*
  #v(0.1em)
  - La simulació assoleix un equilibri d'estat estacionari robust a totes les escales
  - Les cues d'interacció power-law i la viralitat estructural $P_95$ coincideixen estretament amb les dades empíriques
  - La fracció de republicació entre publicacions amb interacció coincideix amb la realitat ($32$–$35$% vs $33.1$%)
  - L'escalabilitat lineal va fer factible la replicació a gran escala
]

#slide(title: "Conclusions")[
  #v(0.3em)
  *Què ens costen les suposicions.*
  #v(0.1em)
  - L'homogeneïtat de publicacions infla la interacció moderada, suprimeix les publicacions realment mortes ($29$% vs $51$%)
  - La fam de timeline afecta ~50% de les sessions a totes les escales
  - Falten cascades broadcast pures degut a la reconstrucció de l'arbre

  #v(0.3em)
  *Idea central.*
  #v(0.1em)
  - Les simplificacions no són limitacions — són eines que aïllen quins factors importen més en la difusió
  - Aquesta línia base validada proporciona un full de ruta: relaxar l'homogeneïtat de publicacions, introduir embeddings de contingut, incorporar homofília
]

#slide(title: "Treball Futur")[
  *Simulació conscient del contingut.*
  #v(0.1em)
  - Substituir publicacions homogènies per embeddings ML (text, tema, sentiment)
  - Modelar homofília: els usuaris interactuen preferentment amb contingut alineat amb els seus interessos
  - Permetre l'estudi de cambres de ressò, polarització i qualitat de la informació

  #v(0.3em)
  *Millores del motor.*
  #v(0.1em)
  - Heurística d'alliberament de memòria per publicacions mortes → eliminar el coll d'ampolla $O(N^2)$
  - Topologia de xarxa dinàmica: follows/unfollows durant la simulació
  - Polítiques d'usuari heterogènies: probabilitats de republicació variables per usuari
]

#blank-slide[
  #set align(center)

  #text(size: 2em, weight: "bold", fill: rgb("#1a1a1a"))[Gràcies]


]

#include "appendix.typ"
