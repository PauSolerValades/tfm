# /// script
# requires-python = ">=3.10"
# dependencies = ["matplotlib", "numpy"]
# ///
"""Generate a Bluesky vs Simulation repost CCDF comparison plot."""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

x = np.linspace(1, 100, 500)
xmin = 1

bluesky = (x / xmin) ** (-(2.21 - 1))
sim = (x / xmin) ** (-(1.73 - 1))

fig, ax = plt.subplots(figsize=(8, 5))

ax.plot(x, bluesky, color="#1d9bf0", linewidth=2.5, label=r"Bluesky ($\gamma = 2.21$)")
ax.plot(x, sim, color="#e53935", linewidth=2.5, label=r"Simulation ($\gamma = 1.73$)")
ax.set_xlim(0, 100)
ax.set_ylim(0, 1)

ax.set_xlabel("Reposts", fontsize=12)
ax.set_ylabel("CCDF  P(X > x)", fontsize=12)
ax.set_title("Repost Distribution: Bluesky vs Simulation", fontsize=14, fontweight="bold")
ax.legend(fontsize=11, loc="upper right")
ax.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig("../images/results/repost_comparison.png", dpi=150, bbox_inches="tight")
print("Done.")
