import os
#!/usr/bin/env python
"""
compose_fig9.py - rebuild Figure 9 (attribution scatters) from the per-pixel
data in <evdir>/attribution/attribution_pixels.csv, in the same typographic
style as compose_figures.py.

Equation label: METHODS_FINAL.md section 3.9 defines the attribution model as
Eq 9, and attribution_engine.R documents itself as "Eq 9 spatial attribution" —
but its plot labels (lines 147/166) say "Eq 13", which is what the previous
Figure_9 carried. Labelled Eq 9 here to match the methods.

Usage:  python compose_fig9.py
"""
from pathlib import Path
import csv

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

ROOT = Path(os.environ.get("CYCLONE_SIF_OUT", ros.environ.get("CYCLONE_SIF_OUT", r"derived_data")))
OUT = Path(os.path.join(os.environ.get("CYCLONE_SIF_RESULTS", r"results"), r"combined figures v2"))
OUT.mkdir(parents=True, exist_ok=True)

MM = 1 / 25.4
PAGE_W = 180 * MM
DPI = 400

SERIF = "Times New Roman" if any(
    "Times New Roman" == f.name for f in fm.fontManager.ttflist) else "DejaVu Serif"
plt.rcParams.update({"font.family": "serif", "font.serif": [SERIF]})

FS_ROWLAB, FS_AX, FS_TICK, FS_R = 7.0, 6.4, 6.0, 6.8
PT_COL, LINE_COL = "#6aa9dc", "#c0392b"

DRIVERS = [("ante_moist", "Antecedent 60-day rainfall (mm)"),
           ("acute_rain", "Storm-week rainfall (mm)"),
           ("wind_stress", "Wind exposure (proximity to track)")]
YLAB = "Acute SIF anomaly (de-meaned)"

EVENTS = [("Zimbabwe/Idai_2019", "a", "Cyclone Idai (Mar 2019) · Zimbabwe"),
          ("Malawi/Idai_2019", "b", "Cyclone Idai (Mar 2019) · Malawi"),
          ("Zimbabwe/Chalane_2020", "c", "Cyclone Chalane (Dec 2020) · Zimbabwe")]


def load(ev):
    p = ROOT / ev / "attribution" / "attribution_pixels.csv"
    rows = list(csv.DictReader(open(p)))
    return {k: np.array([float(r[k]) for r in rows])
            for k in ("dSIF", "wind_stress", "ante_moist", "acute_rain")}


def main():
    # margin_l must clear the y label *and* its tick labels, else the minus
    # signs on negative ticks fall off the canvas
    margin_l, margin_r = 13 * MM, 3 * MM
    gap_col, gap_row = 10 * MM, 5 * MM
    hdr_row, ax_h = 4.2 * MM, 30 * MM
    r_h = 3.2 * MM                      # band for the "r = ..." axes titles
    lab_h = 9 * MM                      # x label + ticks under each axes
    top_pad, bot_pad = 3 * MM, 3 * MM

    content_w = PAGE_W - margin_l - margin_r
    col_w = (content_w - 2 * gap_col) / 3
    nr = len(EVENTS)
    fig_h = (top_pad + bot_pad + nr * (hdr_row + r_h + ax_h + lab_h)
             + (nr - 1) * gap_row)

    fig = plt.figure(figsize=(PAGE_W, fig_h), dpi=DPI)
    fig.patch.set_facecolor("white")
    FX = lambda v: v / PAGE_W
    FY = lambda v: v / fig_h

    y = fig_h - top_pad
    for ev, letter, disp in EVENTS:
        d = load(ev)
        n = len(d["dSIF"])
        y -= hdr_row
        fig.text(FX(margin_l * 0.25), FY(y + 0.8 * MM),
                 f"{letter}   {disp}  ·  Eq 9 attribution, n = {n} pixels",
                 ha="left", va="bottom", fontsize=FS_ROWLAB, fontweight="bold")
        y -= r_h + ax_h
        for j, (key, xlab) in enumerate(DRIVERS):
            ax = fig.add_axes([FX(margin_l + j * (col_w + gap_col)), FY(y),
                               FX(col_w), FY(ax_h)])
            x, yv = d[key], d["dSIF"]
            ax.axhline(0, color="grey", lw=0.5, zorder=1)
            ax.scatter(x, yv, s=4.5, facecolor=PT_COL, edgecolor="none",
                       alpha=0.85, zorder=2)
            b, a = np.polyfit(x, yv, 1)             # OLS fit
            xs = np.linspace(x.min(), x.max(), 100)
            ax.plot(xs, a + b * xs, color=LINE_COL, lw=1.6, zorder=3)
            r = np.corrcoef(x, yv)[0, 1]
            ax.set_title(f"r = {r:+.2f}", fontsize=FS_R, fontweight="bold", pad=2.0)
            ax.set_xlabel(xlab, fontsize=FS_AX, labelpad=2.0)
            if j == 0:
                ax.set_ylabel(YLAB, fontsize=FS_AX, labelpad=2.0)
            ax.tick_params(labelsize=FS_TICK, length=2.0, width=0.5, pad=1.5)
            for s in ax.spines.values():
                s.set_linewidth(0.6)
        y -= lab_h + gap_row

    p = OUT / "Figure_9.png"
    fig.savefig(p, dpi=DPI, facecolor="white")
    plt.close(fig)
    print(f"  {p.name}  {PAGE_W/MM:.0f} x {fig_h/MM:.0f} mm")


if __name__ == "__main__":
    print("composing:")
    main()
