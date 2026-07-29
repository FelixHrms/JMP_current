"""Draft money chart: amplification per bp of shock, by shock size and type.

Coefficients are the Log HF Intensity x Shock interactions from the Stata runs
of July 2026 (release_shocks.do Sections 3.1/3.2, tail_shocks.do Sections 2/2.2,
and the paper's Table IV Col 4 for the intraday MP benchmark), corrected panel
(478,483 obs). 95% CIs = +/- 1.96 x clustered SE. Update the numbers below when
specifications change, then rerun:  python make_size_profile.py
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BLUE, ORANGE, AQUA = "#2a78d6", "#eb6834", "#1baf7a"   # validated 3-slot palette
INK, MUTED = "#1a1a1a", "#666666"

# (x, x_lo, x_hi, coef, se, filled)  x = |shock| placement in bp (log axis)
releases = [  # shock-size buckets, release_shocks.do 3.2
    (0.55, 0.30, 1.00, -0.099, 0.081, True),   # dead zone 0-1bp
    (1.41, 1.00, 2.00,  0.102, 0.068, True),   # 1-2bp
    (2.83, 2.00, 4.00,  0.054, 0.029, True),   # 2-4bp
    (6.80, 4.00, 11.5,  0.091, 0.042, True),   # >4bp
]
mp = [        # monetary events; x-range = p25-p75 of |surprise| (Table I)
    (5.00, 3.30, 7.60, 0.132, 0.024, True),    # daily-measured (tail_shocks.do 2.2a)
    (5.75, None, None, 0.164, 0.032, False),   # intraday EA-MPD (paper Table IV c4)
]
tail = [      # tail days, 10.8-33bp
    (16.0, 10.8, 33.0, 0.081, 0.017, True),    # all 41 tail days
    (18.4, None, None, 0.093, 0.017, False),   # episode-start days only (2.2b)
]

fig, ax = plt.subplots(figsize=(9.2, 5.4), dpi=200)
fig.patch.set_facecolor("white")
ax.set_facecolor("white")

# dead zone band
ax.axvspan(0.3, 1.0, color="#000000", alpha=0.05, zorder=0)
ax.text(0.545, 0.315, "adjustment-cost\ndead zone (<1bp)", ha="center", va="top",
        fontsize=8.5, color=MUTED, linespacing=1.3)

ax.axhline(0, color=MUTED, lw=1, ls=(0, (4, 3)), zorder=1)

def draw(points, color, marker):
    for x, xlo, xhi, b, se, filled in points:
        if xlo is not None:
            ax.plot([xlo, xhi], [b, b], color=color, lw=1.2, alpha=0.35, zorder=2)
        ax.plot([x, x], [b - 1.96 * se, b + 1.96 * se], color=color, lw=2,
                alpha=0.85, zorder=3, solid_capstyle="round")
        face = color if filled else "white"
        ax.scatter([x], [b], s=64, marker=marker, facecolor=face, edgecolor=color,
                   linewidth=1.8, zorder=4)

draw(releases, BLUE, "o")
draw(mp, AQUA, "s")
draw(tail, ORANGE, "^")

# direct labels (relief rule: identity never color-alone; shapes differ too)
ax.text(1.65, 0.265, "Macro releases\n(fundamental news)", color=INK, fontsize=9.5,
        ha="center", linespacing=1.3)
ax.text(5.3, -0.065, "Monetary policy\n(policy news)", color=INK, fontsize=9.5,
        ha="center", linespacing=1.3)
ax.text(17.5, 0.285, "Tail days\n(risk shocks)", color=INK, fontsize=9.5,
        ha="center", linespacing=1.3)
ax.annotate("intraday\nmeasurement", xy=(5.75, 0.164), xytext=(9.2, 0.205),
            fontsize=8.5, color=MUTED, ha="left", va="center", linespacing=1.2,
            arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8))
ax.annotate("episode-start\ndays only", xy=(18.4, 0.093), xytext=(26.0, 0.035),
            fontsize=8.5, color=MUTED, ha="left", va="center", linespacing=1.2,
            arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8))

ax.set_xscale("log")
ax.set_xlim(0.3, 45)
ax.set_ylim(-0.30, 0.34)
ax.set_xticks([0.5, 1, 2, 4, 8, 16, 32])
ax.set_xticklabels(["0.5", "1", "2", "4", "8", "16", "32"])
ax.tick_params(colors=MUTED, labelsize=9)
for s in ["top", "right"]:
    ax.spines[s].set_visible(False)
for s in ["left", "bottom"]:
    ax.spines[s].set_color("#cccccc")
ax.grid(axis="y", color="#000000", alpha=0.06, lw=0.8)
ax.set_axisbelow(True)

ax.set_xlabel("Absolute shock size (bp of 2y OIS, log scale)", fontsize=10, color=INK)
ax.set_ylabel("Amplification per bp of shock\n(Log HF Intensity × Shock)", fontsize=10, color=INK)
ax.set_title("Hedge fund amplification by shock size and type — DRAFT",
             fontsize=12, color=INK, loc="left", pad=14)
ax.text(0, 1.015, "Interaction coefficients with 95% CIs. Filled markers: daily "
        "measurement basis; open: refinements. Horizontal bars: shock-size range.",
        transform=ax.transAxes, fontsize=8.5, color=MUTED, va="bottom")
fig.text(0.065, 0.012, "Sample 2021–2025, DE+IT sovereign bonds. Sources: "
         "release_shocks.do, tail_shocks.do, Table IV col. 4. SEs two-way clustered.",
         fontsize=7.5, color=MUTED)

fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig("size_profile_draft.png", bbox_inches="tight")
print("wrote size_profile_draft.png")
