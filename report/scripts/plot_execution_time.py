import matplotlib.pyplot as plt
import numpy as np
from scipy import stats

plt.style.use("ggplot")

# Data: users (in thousands) vs execution time (mean of range, in seconds)
users_k = np.array([100, 500, 1000])
time_mean = np.array([(70+92)/2, (600+700)/2, (1320+1390)/2])
time_low  = np.array([70, 600, 1320])
time_high = np.array([92, 700, 1390])
time_err  = np.array([time_mean - time_low, time_high - time_mean])

# Linear regression
slope, intercept, r_value, p_value, std_err = stats.linregress(users_k, time_mean)
r2 = r_value ** 2
x_fit = np.linspace(0, 1050, 200)
y_fit = slope * x_fit + intercept

fig, ax = plt.subplots(figsize=(6, 4.5))

# Error bars
ax.errorbar(users_k, time_mean, yerr=time_err,
            fmt='o', color='#2B81AD', ecolor='#888888',
            elinewidth=1.2, capsize=6, markersize=8,
            markeredgewidth=0.8, markeredgecolor='#1a5c7a',
            label='Measured (mean ± range)')

# Regression line
ax.plot(x_fit, y_fit, '--', color='#E07030', linewidth=1.5,
        label=f'Linear fit ($R^2 = {r2:.4f}$)')

# Annotations
for i in range(len(users_k)):
    ax.annotate(f'{time_mean[i]:.0f} s',
                (users_k[i], time_mean[i]),
                textcoords="offset points", xytext=(12, -12),
                fontsize=9, color='#333333')

ax.set_xlabel('Number of users (thousands)')
ax.set_xticks([100, 500, 1000])
ax.set_xticklabels(['100K', '500K', '1M'])
ax.set_ylabel('Execution time (s)')
ax.set_title('Simulation execution time vs. network size')
ax.legend(loc='upper left', framealpha=0.9, edgecolor='#cccccc')
ax.set_xlim(0, 1050)
ax.set_ylim(0, 1550)
ax.grid(True, alpha=0.3, linestyle='--')

plt.tight_layout()
plt.savefig('src/images/results/execution_time_scaling.png')
print(f"Saved. Slope: {slope:.4f} s/Kuser, Intercept: {intercept:.1f} s, R²: {r2:.4f}")
print(f"Time per user: {slope*1000:.2f} ms")
