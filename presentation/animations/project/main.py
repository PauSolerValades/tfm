from manim import *
import random


class BroadcastCascade(Scene):
    def construct(self):
        random.seed(42)

        # Central hub + 9 followers in a circle
        hub = Dot(point=ORIGIN, color=WHITE, radius=0.2)

        followers = VGroup()
        for i in range(9):
            angle = TAU * i / 9
            pos = 1.8 * np.array([np.cos(angle), np.sin(angle), 0])
            followers.add(Dot(point=pos, color=WHITE, radius=0.12))

        # Directed edges from hub to each follower
        edges = VGroup()
        for f in followers:
            edges.add(
                Arrow(
                    hub.get_center(),
                    f.get_center(),
                    color=WHITE,
                    stroke_width=1.5,
                    buff=0.2,
                    tip_length=0.15,
                )
            )

        # A few extra edges between followers (friendships)
        extra_edges = VGroup()
        friendships = [(0, 1), (2, 3), (4, 5), (6, 7), (1, 8)]
        for a, b in friendships:
            extra_edges.add(
                Arrow(
                    followers[a].get_center(),
                    followers[b].get_center(),
                    color=WHITE,
                    stroke_width=1,
                    stroke_opacity=0.4,
                    buff=0.15,
                    tip_length=0.1,
                )
            )

        graph = VGroup(edges, extra_edges, followers, hub)

        # Draw the full graph
        self.play(Create(graph))
        self.wait(1)

        # Split screen: graph to the left
        divider = Line(UP * 2.5, DOWN * 2.5, color=WHITE, stroke_width=1)

        title_graph = Text("Network", font_size=36, color=WHITE).move_to(
            LEFT * 2 + UP * 3.6
        )
        title_cascade = Text("Cascade", font_size=36, color=WHITE).move_to(
            RIGHT * 2 + UP * 3.6
        )

        self.play(
            graph.animate.scale(0.8).shift(LEFT * 2.0),
            Create(divider),
            Write(title_graph),
            Write(title_cascade),
        )
        self.wait(0.5)

        # Cascade: post from hub propagates to all followers
        CASCADE_BLUE = "#1a5276"

        # --- Right-side cascade tree nodes (built in sync) ---
        tree_root = Dot(point=RIGHT * 1.85 + UP * 0.8, color=CASCADE_BLUE, radius=0.15)
        tree_root_label = Text("root", font_size=20, color=CASCADE_BLUE).next_to(
            tree_root, UP, buff=0.1
        )

        tree_children = VGroup()
        for i in range(9):
            x = 0.85 + i * 0.25
            child = Dot(point=RIGHT * x + DOWN * 0.5, color=CASCADE_BLUE, radius=0.08)
            tree_children.add(child)

        # Edges from root to each child
        tree_edges = VGroup()
        for child in tree_children:
            tree_edges.add(
                Line(
                    tree_root.get_center(),
                    child.get_center(),
                    color=CASCADE_BLUE,
                    stroke_width=1,
                )
            )

        # --- Animate: post appears → tree root appears ---
        post = Dot(point=hub.get_center(), color=CASCADE_BLUE, radius=0.18)
        self.play(
            FadeIn(post, scale=1.5),
            FadeIn(tree_root, scale=1.3),
            Write(tree_root_label),
        )
        self.wait(0.3)

        # --- Animate: spread to followers → tree children appear ---
        copies = VGroup()
        anims = []
        for f in followers:
            copy = post.copy()
            copies.add(copy)
            anims.append(copy.animate.move_to(f.get_center()).set_opacity(0.7))

        self.play(
            AnimationGroup(*anims, lag_ratio=0),
            FadeIn(tree_edges),
            FadeIn(tree_children),
            run_time=0.8,
        )
        followers.set_color(CASCADE_BLUE)

        self.play(FadeOut(post))

        broadcast_text = Text("This is a Broadcast", font_size=32, color=WHITE).move_to(
            DOWN * 3.2
        )
        self.play(Write(broadcast_text))
        self.wait(4)


class ThreeLayerCascade(Scene):
    def construct(self):
        random.seed(123)
        CASCADE_BLUE = "#1a5276"
        N = 50

        # --- Generate plausible 50-node social network ---
        # Position nodes: 3 clusters + scattered nodes
        positions = []
        for i in range(N):
            if i < 15:
                angle = random.uniform(0, 1.2)
                radius = random.uniform(0.3, 1.5)
            elif i < 30:
                angle = random.uniform(2.0, 3.5)
                radius = random.uniform(0.3, 1.5)
            elif i < 42:
                angle = random.uniform(4.0, 5.5)
                radius = random.uniform(0.5, 2.0)
            else:
                angle = random.uniform(0, TAU)
                radius = random.uniform(1.0, 2.5)
            pos = radius * np.array([np.cos(angle), np.sin(angle), 0])
            positions.append(pos)

        nodes = VGroup()
        for pos in positions:
            nodes.add(Dot(point=pos, color=WHITE, radius=0.04))

        # Edges: nearest-neighbor (1-3) + some random bridges
        edges = VGroup()
        adjacency = [set() for _ in range(N)]
        for i in range(N):
            dists = []
            for j in range(N):
                if i != j:
                    d = np.linalg.norm(positions[i] - positions[j])
                    dists.append((d, j))
            dists.sort()
            k = random.randint(1, 3)
            for _, j in dists[:k]:
                if j not in adjacency[i]:
                    adjacency[i].add(j)
                    adjacency[j].add(i)
                    edges.add(
                        Arrow(
                            positions[i],
                            positions[j],
                            color=WHITE,
                            stroke_width=0.6,
                            buff=0.06,
                            tip_length=0.06,
                            stroke_opacity=0.5,
                        )
                    )
        for _ in range(15):
            i = random.randint(0, N - 1)
            j = random.randint(0, N - 1)
            if i != j and j not in adjacency[i] and len(adjacency[i]) < 6:
                adjacency[i].add(j)
                adjacency[j].add(i)
                edges.add(
                    Arrow(
                        positions[i],
                        positions[j],
                        color=WHITE,
                        stroke_width=0.6,
                        buff=0.06,
                        tip_length=0.06,
                        stroke_opacity=0.35,
                    )
                )

        graph = VGroup(edges, nodes)
        graph.scale(1.6)
        self.play(Create(edges, run_time=1.5), Create(nodes, run_time=0.8))
        self.wait(1)

        source_a, source_b = 3, 28

        # --- Split screen ---
        divider = Line(UP * 2.5, DOWN * 2.5, color=WHITE, stroke_width=1)
        title_net = Text("Network", font_size=36, color=WHITE).move_to(
            LEFT * 1.8 + UP * 3.6
        )
        title_cas = Text("Cascade", font_size=36, color=WHITE).move_to(
            RIGHT * 2 + UP * 3.6
        )

        self.play(
            graph.animate.scale(0.9).shift(LEFT * 3.2),
            Create(divider),
            Write(title_net),
            Write(title_cas),
        )
        self.wait(0.5)

        # --- Compute BFS layers from source_a ---
        layers = [[source_a]]
        visited = {source_a}
        while True:
            nxt = set()
            for node in layers[-1]:
                for nb in adjacency[node]:
                    if nb not in visited:
                        nxt.add(nb)
                        visited.add(nb)
            if not nxt:
                break
            layers.append(sorted(nxt))

        # --- Build cascade tree on the right ---
        tree_layers = []
        y_positions = [UP * 2.0, UP * 0.8, DOWN * 0.4, DOWN * 1.6]
        for li, layer in enumerate(layers[:4]):  # max 4 layers shown
            count = len(layer)
            y = y_positions[li]
            spacing = min(0.22, 1.2 / max(count, 1))
            start_x = 0.95 - (count - 1) * spacing / 2
            vg = VGroup()
            for i in range(count):
                x = start_x + i * spacing
                vg.add(Dot(point=RIGHT * x + y, color=CASCADE_BLUE, radius=0.07))
            tree_layers.append(vg)

        # Edges between tree layers
        tree_edges = []
        for li in range(len(layers) - 1):
            if li >= 3:
                break
            parent_layer = layers[li]
            child_layer = layers[li + 1]
            vg = VGroup()
            # Map child index to its parents in the layer above
            child_parents = {}
            for ci, child in enumerate(child_layer):
                for pi, parent in enumerate(parent_layer):
                    if parent in adjacency[child]:
                        child_parents.setdefault(ci, []).append(pi)
            for ci, parents in child_parents.items():
                for pi in parents:
                    vg.add(
                        Line(
                            tree_layers[li][pi].get_center(),
                            tree_layers[li + 1][ci].get_center(),
                            color=CASCADE_BLUE,
                            stroke_width=0.8,
                        )
                    )
            tree_edges.append(vg)

        # --- Animate cascade layer by layer ---
        # Layer 0: source post (use transformed position)
        post = Dot(point=nodes[source_a].get_center(), color=CASCADE_BLUE, radius=0.12)
        self.play(
            FadeIn(post, scale=1.5),
            FadeIn(tree_layers[0], scale=1.3),
        )
        self.wait(0.2)

        # Subsequent layers
        active_copies = [post]
        for li in range(1, min(len(layers), 4)):
            new_copies = []
            anims = []
            for child in layers[li]:
                # Find which parent(s) to copy from
                for prev_idx, prev_node in enumerate(layers[li - 1]):
                    if prev_node in adjacency[child]:
                        copy = active_copies[prev_idx].copy()
                        copy.set_opacity(0.5)
                        new_copies.append(copy)
                        anims.append(
                            copy.animate.move_to(nodes[child].get_center()).set_opacity(
                                0.6
                            )
                        )
                        break

            self.play(
                AnimationGroup(*anims, lag_ratio=0),
                FadeIn(tree_edges[li - 1]),
                FadeIn(tree_layers[li]),
                run_time=0.7,
            )
            # Color the reached nodes
            for child in layers[li]:
                nodes[child].set_color(CASCADE_BLUE)
            active_copies = new_copies
            self.wait(0.2)

        self.play(*[FadeOut(c) for c in active_copies + [post]])

        label = Text(
            "This is a three layer cascade, assuming everyone reposts",
            font_size=24,
            color=WHITE,
        ).move_to(DOWN * 3.2)
        self.play(Write(label))
        self.wait(2)

        # --- Now compare with p_repost = 1/2 ---
        prob_text = MathTex(
            r"p_{\text{repost}} = \frac{1}{2}", font_size=48, color=RED
        ).move_to(ORIGIN)
        self.play(FadeIn(prob_text, scale=1.5))
        self.wait(0.5)
        self.play(
            prob_text.animate.scale(0.5).move_to(RIGHT * 1.8 + UP * 2.8),
            FadeOut(label),
        )
        self.wait(0.3)

        # --- Probabilistic BFS (only layer 2+ uses 1/2, layer 1 identical) ---
        random.seed(789)
        prob_layers = [[source_a]]
        prob_visited = {source_a}
        # Layer 1: identical to blue (all neighbours)
        layer1 = sorted(adjacency[source_a])
        prob_layers.append(layer1)
        prob_visited.update(layer1)
        # Layer 2+: probabilistic with 1/2
        for _ in range(2):
            nxt = set()
            for node in prob_layers[-1]:
                for nb in adjacency[node]:
                    if nb not in prob_visited and random.random() < 0.5:
                        nxt.add(nb)
                        prob_visited.add(nb)
            if not nxt:
                break
            prob_layers.append(sorted(nxt))

        # --- Build red cascade tree (same y as blue, to the RIGHT of blue) ---
        red_tree_layers = []
        red_y = [UP * 2.0, UP * 0.8, DOWN * 0.4, DOWN * 1.6]
        for li, layer in enumerate(prob_layers[:4]):
            count = len(layer)
            y = red_y[li]
            spacing = min(0.18, 1.2 / max(count, 1))
            start_x = 2.5 - (count - 1) * spacing / 2
            vg = VGroup()
            for i in range(count):
                x = start_x + i * spacing
                vg.add(Dot(point=RIGHT * x + y, color=RED, radius=0.05))
            red_tree_layers.append(vg)

        red_tree_edges = []
        for li in range(len(prob_layers) - 1):
            if li >= 3:
                break
            parent_layer = prob_layers[li]
            child_layer = prob_layers[li + 1]
            vg = VGroup()
            child_parents = {}
            for ci, child in enumerate(child_layer):
                for pi, parent in enumerate(parent_layer):
                    if parent in adjacency[child]:
                        child_parents.setdefault(ci, []).append(pi)
            for ci, parents in child_parents.items():
                for pi in parents:
                    vg.add(
                        Line(
                            red_tree_layers[li][pi].get_center(),
                            red_tree_layers[li + 1][ci].get_center(),
                            color=RED,
                            stroke_width=0.7,
                        )
                    )
            red_tree_edges.append(vg)

        # --- Animate red cascade ---
        red_post = Dot(point=nodes[source_a].get_center(), color=RED, radius=0.1)
        self.play(
            FadeIn(red_post, scale=1.5),
            FadeIn(red_tree_layers[0], scale=1.3),
        )
        self.wait(0.2)

        red_copies = [red_post]
        for li in range(1, min(len(prob_layers), 4)):
            new_copies = []
            anims = []
            for child in prob_layers[li]:
                for prev_idx, prev_node in enumerate(prob_layers[li - 1]):
                    if prev_node in adjacency[child]:
                        copy = red_copies[prev_idx].copy()
                        copy.set_opacity(0.5)
                        new_copies.append(copy)
                        anims.append(
                            copy.animate.move_to(nodes[child].get_center()).set_opacity(
                                0.6
                            )
                        )
                        break

            self.play(
                AnimationGroup(*anims, lag_ratio=0),
                FadeIn(red_tree_edges[li - 1]),
                FadeIn(red_tree_layers[li]),
                run_time=0.7,
            )
            for child in prob_layers[li]:
                nodes[child].set_color(RED)
            red_copies = new_copies
            self.wait(0.2)

        self.play(*[FadeOut(c) for c in red_copies + [red_post]])

        # Show node counts under each cascade tree
        blue_count = Text(
            f"{len(visited)} nodes", font_size=22, color=CASCADE_BLUE
        ).move_to(RIGHT * 0.95 + DOWN * 2.8)
        red_count = Text(
            f"{len(prob_visited)} nodes", font_size=22, color=RED
        ).move_to(RIGHT * 2.5 + DOWN * 2.8)
        self.play(Write(blue_count), Write(red_count))
        self.wait(0.5)

        final_label = Text(
            "Full cascade vs 1/2 probability", font_size=24, color=WHITE
        ).move_to(DOWN * 3.6)
        self.play(Write(final_label))
        self.wait(4)


class RhomboidGraph(Scene):
    def construct(self):
        # Node positions (rhomboid)
        pos_C = UP * 2.5
        pos_A = LEFT * 1.5
        pos_B = RIGHT * 1.5
        pos_D = DOWN * 2.5

        dot_a = Dot(point=pos_A, color=GREY, radius=0.18)
        lbl_a = Text("A", font_size=32, color=WHITE).next_to(dot_a, UP, buff=0.3)
        tsa_lbl = MathTex(r"t_s = 1", font_size=26, color=WHITE).next_to(dot_a, DOWN, buff=0.3)
        dot_b = Dot(point=pos_B, color=GREY, radius=0.18)
        lbl_b = Text("B", font_size=32, color=WHITE).next_to(dot_b, UP, buff=0.3)
        tsb_lbl = MathTex(r"t_s = 4", font_size=26, color=WHITE).next_to(dot_b, DOWN, buff=0.3)
        dot_c = Dot(point=pos_C, color=WHITE, radius=0.18)
        lbl_c = Text("C", font_size=32, color=WHITE).next_to(dot_c, UP, buff=0.3)
        dot_d = Dot(point=pos_D, color=WHITE, radius=0.18)
        lbl_d = Text("D", font_size=32, color=WHITE).next_to(dot_d, DOWN, buff=0.3)

        # A <-> B
        edge_ab = Arrow(pos_A, pos_B, color=WHITE, stroke_width=2, buff=0.25, tip_length=0.18)
        edge_ba = Arrow(pos_B, pos_A, color=WHITE, stroke_width=2, buff=0.25, tip_length=0.18)
        # C -> A
        edge_ca = Arrow(pos_C, pos_A, color=WHITE, stroke_width=2, buff=0.25, tip_length=0.18)
        # C -> B
        edge_cb = Arrow(pos_C, pos_B, color=WHITE, stroke_width=2, buff=0.25, tip_length=0.18)
        # A -> D
        edge_ad = Arrow(pos_A, pos_D, color=WHITE, stroke_width=2, buff=0.25, tip_length=0.18)
        # B -> D
        edge_bd = Arrow(pos_B, pos_D, color=WHITE, stroke_width=2, buff=0.25, tip_length=0.18)

        nodes = VGroup(dot_a, dot_b, dot_c, dot_d)
        labels = VGroup(lbl_a, lbl_b, lbl_c, lbl_d)
        edges = VGroup(edge_ab, edge_ba, edge_ca, edge_cb, edge_ad, edge_bd)

        self.play(
            Create(edges, run_time=1.5),
            Create(nodes, run_time=0.8),
            Write(labels, run_time=0.8),
        )

        # t = 0 counter
        t_counter = MathTex(r"t = 0", font_size=36, color=WHITE).move_to(LEFT * 2 + UP * 3.5)
        self.play(Write(t_counter))

        # Legend
        legend_online = Dot(point=LEFT * 2 + UP * 2.8, color=WHITE, radius=0.1)
        legend_online_txt = Text("online", font_size=20, color=WHITE).next_to(legend_online, RIGHT, buff=0.2)
        legend_offline = Dot(point=LEFT * 2 + UP * 2.3, color=GREY, radius=0.1)
        legend_offline_txt = Text("offline", font_size=20, color=WHITE).next_to(legend_offline, RIGHT, buff=0.2)
        self.play(
            FadeIn(legend_online), Write(legend_online_txt),
            FadeIn(legend_offline), Write(legend_offline_txt),
        )

        # Stacks next to A and B
        self.play(Write(tsa_lbl), Write(tsb_lbl))

        set_a = MathTex(r"\mathcal{T}_0(A) = \{\}", font_size=24, color=WHITE).next_to(dot_a, LEFT, buff=1.0)
        set_b = MathTex(r"\mathcal{T}_0(B) = \{\}", font_size=24, color=WHITE).next_to(dot_b, RIGHT, buff=1.0)
        self.play(Write(set_a), Write(set_b))
        self.wait(1)

        # --- 4 posts from C to A and B ---
        colors = [RED, BLUE, YELLOW, GREEN]
        # repost_a[t] = does A repost the post that arrived at time t?
        repost_a = [True, False, True, False]

        queue_b_dots = VGroup()
        pending_dot_a = None  # the dot in A's queue waiting to be processed

        for t_idx in range(5):  # 0 to 4
            t_val = t_idx  # t = 0, 1, 2, 3, 4

            # Advance t counter
            new_counter = MathTex(r"t = " + str(t_val), font_size=36, color=WHITE).move_to(t_counter)
            state_changes = []

            # t=1: A goes online
            if t_val == 1:
                state_changes.append(dot_a.animate.set_color(WHITE))
                new_tsa = MathTex(r"t_s = 4", font_size=26, color=WHITE).move_to(tsa_lbl)
                state_changes.append(Transform(tsa_lbl, new_tsa))
            # t=4: A goes offline, B goes online
            if t_val == 4:
                state_changes.append(dot_a.animate.set_color(GREY))
                state_changes.append(dot_b.animate.set_color(WHITE))
                new_tsa = MathTex(r"t_s = \infty", font_size=26, color=WHITE).move_to(tsa_lbl)
                state_changes.append(Transform(tsa_lbl, new_tsa))

            self.play(Transform(t_counter, new_counter), *state_changes)

            # Step 1: Process pending post from previous tick
            if pending_dot_a is not None:
                prev_color = pending_dot_a.get_color()
                # Was this one marked for repost at the previous tick?
                if t_val >= 1 and t_val <= 4 and repost_a[t_val - 1]:
                    # Repost it: send to B and D
                    repost_b = Dot(point=pos_A, color=prev_color, radius=0.08)
                    repost_d = Dot(point=pos_A, color=prev_color, radius=0.08)
                    self.add(repost_b, repost_d)
                    self.play(
                        repost_b.animate.move_to(pos_B),
                        repost_d.animate.move_to(pos_D),
                        run_time=0.5,
                    )
                    dot_b_from_a = Dot(color=prev_color, radius=0.10)
                    dot_b_from_a.next_to(set_b, DOWN, buff=0.15 + len(queue_b_dots) * 0.2)
                    queue_b_dots.add(dot_b_from_a)
                    self.play(FadeIn(dot_b_from_a), FadeOut(repost_b), FadeOut(repost_d), run_time=0.3)
                # Remove from A's queue (processed)
                self.play(FadeOut(pending_dot_a), run_time=0.2)
                pending_dot_a = None

            # Step 2: Receive new post from C (skip at t=4)
            if t_val < 4:
                color = colors[t_val]
                post = Dot(point=pos_C, color=color, radius=0.12)
                post_a = post.copy()
                post_b = post.copy()
                self.add(post_a, post_b)
                self.play(
                    post_a.animate.move_to(pos_A),
                    post_b.animate.move_to(pos_B),
                    run_time=0.6,
                )

                # A: store in queue
                dot_a_q = Dot(color=color, radius=0.10)
                dot_a_q.next_to(set_a, DOWN, buff=0.15)
                pending_dot_a = dot_a_q
                self.play(FadeIn(dot_a_q), FadeOut(post_a), run_time=0.3)

                # B: always queues (offline until t=4)
                dot_b_q = Dot(color=color, radius=0.10)
                dot_b_q.next_to(set_b, DOWN, buff=0.15 + len(queue_b_dots) * 0.2)
                queue_b_dots.add(dot_b_q)
                self.play(FadeIn(dot_b_q), FadeOut(post_b), run_time=0.3)

            # Update set labels
            new_set_a = MathTex(
                r"\mathcal{T}_{" + str(t_val) + r"}(A)",
                font_size=24, color=WHITE
            ).move_to(set_a)
            new_set_b = MathTex(
                r"\mathcal{T}_{" + str(t_val) + r"}(B)",
                font_size=24, color=WHITE
            ).move_to(set_b)
            self.play(
                Transform(set_a, new_set_a),
                Transform(set_b, new_set_b),
                run_time=0.2,
            )

        # --- B goes online at t=4, starts processing queue ---
        seen_colors = set()
        for i, b_dot in enumerate(queue_b_dots):
            t_val = 5 + i
            color = b_dot.get_color()

            new_counter = MathTex(r"t = " + str(t_val), font_size=36, color=WHITE).move_to(t_counter)
            self.play(Transform(t_counter, new_counter))

            if color in seen_colors:
                ignore_txt = Text("already seen, ignore", font_size=18, color=YELLOW).next_to(set_b, DOWN, buff=1.8)
                self.play(Write(ignore_txt), FadeOut(b_dot), run_time=0.5)
                self.play(FadeOut(ignore_txt), run_time=0.3)
            else:
                seen_colors.add(color)
                repost_a2 = Dot(point=pos_B, color=color, radius=0.08)
                repost_d2 = Dot(point=pos_B, color=color, radius=0.08)
                self.add(repost_a2, repost_d2)
                self.play(
                    repost_a2.animate.move_to(pos_A),
                    repost_d2.animate.move_to(pos_D),
                    FadeOut(b_dot),
                    run_time=0.5,
                )
                self.play(FadeOut(repost_a2), FadeOut(repost_d2), run_time=0.3)

            new_set_b = MathTex(
                r"\mathcal{T}_{" + str(t_val) + r"}(B)",
                font_size=24, color=WHITE
            ).move_to(set_b)
            self.play(Transform(set_b, new_set_b), run_time=0.2)

        # B goes offline
        t_val += 1
        new_counter = MathTex(r"t = " + str(t_val), font_size=36, color=WHITE).move_to(t_counter)
        self.play(
            Transform(t_counter, new_counter),
            dot_b.animate.set_color(GREY),
        )
        bored_text = Text("B is bored\nand disconnects", font_size=24, color=WHITE, line_spacing=0.5).next_to(dot_b, DOWN, buff=1.0).shift(RIGHT * 0.3)
        self.play(Write(bored_text))

        self.wait(4)
