import numpy as np
import matplotlib.pyplot as plt

# 1. Define our Softmax parameters
# Beta = Baseline Habit, Theta = Sensitivity
beta_N, theta_N = 2.0, -1.0  # Nothing
beta_L, theta_L = 0.0, 2.0  # Like
beta_R, theta_R = -1.0, 4.0  # Repost


# 2. Function to calculate the CDF staircase for a specific c
def get_cdf_staircase(c):
    z_N = theta_N * c + beta_N
    z_L = theta_L * c + beta_L
    z_R = theta_R * c + beta_R

    exp_N, exp_L, exp_R = np.exp(z_N), np.exp(z_L), np.exp(z_R)
    denominator = exp_N + exp_L + exp_R

    p_N = exp_N / denominator
    p_L = exp_L / denominator
    p_R = exp_R / denominator

    # Return the cumulative steps: [Nothing, Nothing+Like, 1.0]
    # We append a final 1.0 to make the last step draw cleanly to the edge
    return [p_N, p_N + p_L, 1.0, 1.0]


# 3. Calculate the staircases for 3 different scenarios
# c = 0.0 proves that the middle state is PURELY the Betas!
c_neg = get_cdf_staircase(-0.8)  # Irrelevant post
c_zero = get_cdf_staircase(0.0)  # Neutral post (Baseline)
c_pos = get_cdf_staircase(0.8)  # Highly relevant post

# X-axis positions for our 3 actions (adding a 3rd for visual step completion)
x_ticks = [0, 1, 2, 3]
x_labels = ["Nothing", "Like", "Repost", ""]

# 4. Plotting the Step Functions
plt.figure(figsize=(9, 6))

# Plot the three staircases
plt.step(
    x_ticks,
    c_neg,
    where="post",
    linewidth=2.5,
    linestyle=":",
    color="red",
    label="c = -0.8 (Irrelevant)",
)
plt.step(
    x_ticks,
    c_zero,
    where="post",
    linewidth=3.5,
    linestyle="-",
    color="black",
    label="c =  0.0 (Baseline/Betas)",
)
plt.step(
    x_ticks,
    c_pos,
    where="post",
    linewidth=2.5,
    linestyle="--",
    color="green",
    label="c = +0.8 (Relevant)",
)

# Add dots at the actual data points to make the categories clear
plt.plot(x_ticks[:-1], c_neg[:-1], "ro", markersize=8)
plt.plot(x_ticks[:-1], c_zero[:-1], "ko", markersize=8)
plt.plot(x_ticks[:-1], c_pos[:-1], "go", markersize=8)

# Formatting the graph
plt.title(
    "Categorical CDF Step Functions across different $c$ values", fontsize=14, pad=15
)
plt.ylabel("Cumulative Probability (Random Dice Roll $r$)", fontsize=12)
plt.xlabel("Categorical Action", fontsize=12)

# Set the ticks and limits
plt.xticks([0.5, 1.5, 2.5], ["Nothing", "Like", "Repost"], fontsize=12)
plt.ylim(0, 1.05)
plt.xlim(0, 3)
plt.grid(axis="y", linestyle="--", alpha=0.7)


plt.legend(loc="lower right", fontsize=11)
plt.tight_layout()
plt.savefig(f"img/logit.png")
plt.close()
