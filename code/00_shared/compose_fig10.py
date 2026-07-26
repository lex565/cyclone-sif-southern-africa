import os
#!/usr/bin/env python
"""
compose_fig10.py - rebuild Figure 10 (spatial-autocorrelation robustness of the
acute SIF suppression) in the publication-standard idiom of compose_figures.py.

Figure 10 was the last figure still carrying the 10 Jun ggplot build: 3300x1980
px, ggplot greys, a red accent that appears nowhere else in the paper, and type
sized for a different page width. Everything else in the figure set is drawn by
compose_figures.py at 180 mm / 400 dpi in Abadi against the locked seven-class
percent-change palette. This script brings Figure 10 into that system.

Substantively nothing changes. The estimates, both confidence intervals and the
Moran's I values are read verbatim from moran_forest_data.csv, which was cached
by moran_forest.R on 10 Jun. No resampling is rerun here, so the numbers in the
figure remain the numbers already quoted in the manuscript text and in Table 2.

Three deliberate departures from the June build:

  * Colour carries the effect size. The estimate marker and the block interval
    take their colour from the same BRK/COL scale as the map figures, so an
    event at -40 % is the same dark brown as a -40 % pixel in Figure 3. The
    June red carried no information at all.
  * Botswana is clipped, not spilled. At n = 15 its interval is +/-123 %, wider
    than any axis that still lets the reader see which of the other eleven
    intervals cross zero. It is drawn to the axis edge with arrowheads and
    labelled, so it reads as a stated limitation rather than a clipping bug.
  * n and Moran's I get their own labelled columns instead of a free-floating
    right-hand annotation, which is the conventional forest-plot arrangement.

Two layouts are written for comparison; pick one and delete the other.
  Figure_10_grouped.png  - events blocked by country, bold lowercase letters,
                           mirroring the block structure of Figures 5-8.
  Figure_10_ranked.png   - one column ranked by effect size, as in June.

Usage:  python compose_fig10.py
Output: <results>/combined figures v3/Figure_10_*.png  (+ captions.md)
"""
from pathlib import Path
import csv

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

# ---------------------------------------------------------------- config
DATA = Path(os.path.join(os.environ.get("CYCLONE_SIF_OUT", r"derived_data"), r"moran_forest_data.csv"))
OUT = Path(os.path.join(os.environ.get("CYCLONE_SIF_RESULTS", r"results"), r"combined figures v3"))
OUT.mkdir(parents=True, exist_ok=True)

MM = 1 / 25.4
PAGE_W = 180 * MM
DPI = 400

# locked palette, identical to compose_figures.py / clean_figures.R
BRK = [-200, -40, -20, -5, 5, 20, 40, 200]
COL = ["#8c2d04", "#d95f0e", "#f6a563", "#f7f7f7", "#a6d96a", "#5aae61", "#1a7e3f"]

NAIVE_COL = "#9e9e9e"
ZERO_COL = "#666666"

# Abadi is an Office cloud font, absent from C:/Windows/Fonts. Same registration
# dance as compose_figures.py so the two scripts cannot drift apart.
ABADI_CACHE = Path(os.path.join(os.environ.get("CYCLONE_SIF_HOME", r"."), r"AppData/Local/Microsoft/FontCache/4/CloudFonts/Abadi"))


def register_abadi():
    if not ABADI_CACHE.is_dir():
        return None
    n = 0
    for f in ABADI_CACHE.glob("*.ttf"):
        try:
            fm.fontManager.addfont(str(f)); n += 1
        except Exception:
            pass
    if not n:
        return None
    return "Abadi" if any(f.name == "Abadi" for f in fm.fontManager.ttflist) else None


FAMILY = register_abadi()
if FAMILY is None:
    FAMILY = next((c for c in ("Candara", "Segoe UI", "Trebuchet MS", "DejaVu Sans")
                   if any(f.name == c for f in fm.fontManager.ttflist)), "DejaVu Sans")
    print(f"  !! Abadi unavailable; falling back to {FAMILY}")

_FALLBACKS = [f for f in ("Segoe UI", "DejaVu Sans")
              if any(fnt.name == f for fnt in fm.fontManager.ttflist)]
plt.rcParams.update({"font.family": [FAMILY] + _FALLBACKS,
                     "mathtext.fontset": "dejavusans"})

# Twelve rows will not take 12 pt body type in 180 mm. Figure 3 has the same
# problem for the same reason and solves it at 0.72; matched here so the two
# twelve-event figures carry the same type size.
BASE_PT = 12.0
SCALE = 0.72
FS_LAB = BASE_PT * SCALE            # event labels, n, Moran's I
FS_HEAD = BASE_PT * SCALE           # column headers
FS_TICK = BASE_PT * SCALE
FS_AXTITLE = BASE_PT                # axis title, at colour-bar-title weight
FS_FOOT = BASE_PT * 0.62

XLIM = (-60.0, 60.0)
XTICKS = [-60, -40, -20, 0, 20, 40, 60]

PRETTY = {"Chalane_2020": "Chalane 2020", "Idai_2019": "Idai 2019",
          "Desmond_2019": "Desmond 2019", "Kenneth_2019": "Kenneth 2019",
          "Belna_2019": "Belna 2019", "Diane_2020": "Diane 2020",
          "Francisco_2020": "Francisco 2020"}

# Fig 3's caption orders the countries this way; kept so the reader meets the
# blocks in the order the text introduces them.
COUNTRY_ORDER = ["Mozambique", "Madagascar", "Zimbabwe", "Malawi", "Botswana"]

# Desmond's positive excursion is the rising-baseline artefact discussed in the
# text, not a real enhancement. Flagged in the figure so the one event pointing
# the wrong way cannot be read as a counter-result.
ARTEFACT = {("Mozambique", "Desmond_2019")}


def load():
    rows = []
    for r in csv.DictReader(open(DATA)):
        rows.append({
            "country": r["country"],
            "event": r["event"],
            "name": PRETTY.get(r["event"], r["event"].replace("_", " ")),
            "n": int(r["n_acute"]),
            "I": float(r["morans_I"]),
            "eff": float(r["effect"]),
            "nlo": float(r["naive_lo"]), "nhi": float(r["naive_hi"]),
            "blo": float(r["block_lo"]), "bhi": float(r["block_hi"]),
        })
    for r in rows:
        r["sig"] = not (r["blo"] <= 0.0 <= r["bhi"])     # block CI excludes zero
        r["off"] = r["blo"] < XLIM[0] or r["bhi"] > XLIM[1]
        r["art"] = (r["country"], r["event"]) in ARTEFACT
    return rows


def bin_colour(v):
    """Effect size -> the same seven-class colour the map figures would give it."""
    for i in range(len(BRK) - 1):
        if BRK[i] <= v < BRK[i + 1]:
            return COL[i]
    return COL[-1]


def draw_row(ax, y, r):
    """One event: naive interval, block interval, estimate marker."""
    c = bin_colour(r["eff"])
    lo, hi = max(r["blo"], XLIM[0]), min(r["bhi"], XLIM[1])

    # The -5..+5 class is near-white by design, which works against a coloured
    # map but vanishes against the page. Give only that class a grey keyline so
    # every event stays visible without recolouring the scale.
    if c == COL[3]:
        ax.plot([lo, hi], [y, y], color="#8a8a8a", lw=4.2,
                solid_capstyle="butt", zorder=1.5)

    # block interval first and thick, naive over it and thin, so the widening
    # reads as the block bar extending past both ends of the naive bar
    ax.plot([lo, hi], [y, y], color=c, lw=3.4, solid_capstyle="butt", zorder=2)
    ax.plot([max(r["nlo"], XLIM[0]), min(r["nhi"], XLIM[1])], [y, y],
            color=NAIVE_COL, lw=1.0, solid_capstyle="butt", zorder=3)

    # arrowheads only where the interval genuinely leaves the frame
    # solid triangles rather than an annotate arrow: at 3.4 pt bar weight an
    # arrowhead drawn on a zero-width tail disappears under the bar itself
    if r["blo"] < XLIM[0]:
        ax.plot([XLIM[0] + 1.2], [y], marker="<", ms=6.5, mfc=c, mec="black",
                mew=0.5, clip_on=False, zorder=6)
    if r["bhi"] > XLIM[1]:
        ax.plot([XLIM[1] - 1.2], [y], marker=">", ms=6.5, mfc=c, mec="black",
                mew=0.5, clip_on=False, zorder=6)

    if r["sig"]:
        ax.plot([r["eff"]], [y], marker="o", ms=4.6, mfc="white", mec="black",
                mew=0.9, zorder=5)
    else:
        ax.plot([r["eff"]], [y], marker="X", ms=5.2, mfc="black", mec="white",
                mew=0.6, zorder=5)


def style_axes(ax, nrows):
    ax.set_xlim(*XLIM)
    ax.set_ylim(nrows - 0.5, -0.5)          # first row at the top
    ax.set_yticks([])
    ax.set_xticks(XTICKS)
    ax.set_xticklabels([f"{v:+d}" if v else "0" for v in XTICKS], fontsize=FS_TICK)
    ax.tick_params(length=2.0, width=0.5, pad=1.5)
    ax.axvline(0, color=ZERO_COL, lw=0.7, zorder=1)
    for s in ax.spines.values():
        s.set_linewidth(0.6); s.set_edgecolor("black")


def legend(fig, fx, fy, y, x0):
    """Key drawn by hand: matplotlib's legend box does not match the house style."""
    pt = 1 / 72
    def seg(x, col, lw):
        fig.add_artist(plt.Line2D([fx(x), fx(x + 5 * MM)], [fy(y), fy(y)],
                                  color=col, lw=lw, solid_capstyle="butt"))
    # three swatch segments, not one: the block bar takes its colour from the
    # effect size, so a single-colour key would imply a fixed category colour
    for k, cc in enumerate((COL[0], COL[2], COL[5])):
        fig.add_artist(plt.Line2D([fx(x0 + k * 1.67 * MM),
                                   fx(x0 + (k + 1) * 1.67 * MM)],
                                  [fy(y), fy(y)], color=cc, lw=3.4,
                                  solid_capstyle="butt"))
    fig.text(fx(x0 + 6 * MM), fy(y), "25 km block bootstrap 95 % CI",
             ha="left", va="center", fontsize=FS_LAB)
    x1 = x0 + 52 * MM
    seg(x1, NAIVE_COL, 1.0)
    fig.text(fx(x1 + 6 * MM), fy(y), "naive 95 % CI", ha="left", va="center",
             fontsize=FS_LAB)
    x2 = x1 + 32 * MM
    fig.add_artist(plt.Line2D([fx(x2 + 2 * MM)], [fy(y)], marker="o", ms=4.6,
                              mfc="white", mec="black", mew=0.9, ls="none"))
    fig.text(fx(x2 + 5 * MM), fy(y), "excludes zero", ha="left", va="center",
             fontsize=FS_LAB)
    x3 = x2 + 28 * MM
    fig.add_artist(plt.Line2D([fx(x3 + 2 * MM)], [fy(y)], marker="X", ms=5.2,
                              mfc="black", mec="white", mew=0.6, ls="none"))
    fig.text(fx(x3 + 5 * MM), fy(y), "includes zero", ha="left", va="center",
             fontsize=FS_LAB)


def compose(figname, grouped):
    rows = load()
    if grouped:
        blocks = []
        for c in COUNTRY_ORDER:
            evs = sorted([r for r in rows if r["country"] == c],
                         key=lambda r: r["eff"])
            if evs:
                blocks.append((c, evs))
    else:
        blocks = [(None, sorted(rows, key=lambda r: r["eff"]))]

    n_ev = sum(len(e) for _, e in blocks)
    n_blk = len(blocks) if grouped else 0

    PT = 1 / 72
    margin_l, margin_r = 5 * MM, 4 * MM
    lab_w = 46 * MM                     # event label column
    n_w, i_w = 13 * MM, 17 * MM         # right-hand statistic columns
    gap = 2.5 * MM
    row_h = 5.0 * MM
    blk_h = BASE_PT * 1.45 * PT         # country header band, as compose_figures
    hdr_top = BASE_PT * 1.7 * PT
    legend_h = 6 * MM
    axlab_h = BASE_PT * 2.6 * PT
    foot_h = 0.0                        # footnote lives in the caption
    top_pad, bot_pad = 3 * MM, 3 * MM

    plot_w = PAGE_W - margin_l - margin_r - lab_w - n_w - i_w - 2 * gap
    fig_h = (top_pad + hdr_top + legend_h + n_blk * blk_h + n_ev * row_h
             + axlab_h + foot_h + bot_pad)

    fig = plt.figure(figsize=(PAGE_W, fig_h), dpi=DPI)
    fig.patch.set_facecolor("white")
    FX = lambda v: v / PAGE_W
    FY = lambda v: v / fig_h

    plot_x = margin_l + lab_w
    n_x = plot_x + plot_w + gap
    i_x = n_x + n_w + gap

    # ---- column headers
    y = fig_h - top_pad - hdr_top * 0.5
    fig.text(FX(margin_l), FY(y), "Event", ha="left", va="center",
             fontsize=FS_HEAD, fontweight="bold")
    fig.text(FX(n_x + n_w), FY(y), "n", ha="right", va="center",
             fontsize=FS_HEAD, fontweight="bold")
    fig.text(FX(i_x + i_w), FY(y), "Moran's I", ha="right", va="center",
             fontsize=FS_HEAD, fontweight="bold")

    y = fig_h - top_pad - hdr_top - legend_h * 0.5
    legend(fig, FX, FY, y, margin_l)

    # ---- one axes per block, all sharing XLIM so the columns line up
    y = fig_h - top_pad - hdr_top - legend_h
    for letter_i, (country, evs) in enumerate(blocks):
        if grouped:
            y -= blk_h
            fig.text(FX(margin_l), FY(y + 0.7 * MM),
                     f"{chr(ord('a') + letter_i)}   {country}", ha="left",
                     va="bottom", fontsize=FS_LAB, fontweight="bold")
        h = len(evs) * row_h
        y -= h
        ax = fig.add_axes([FX(plot_x), FY(y), FX(plot_w), FY(h)])
        style_axes(ax, len(evs))
        ax.set_xticklabels([])
        for k, r in enumerate(evs):
            draw_row(ax, k, r)
            ry = y + h - (k + 0.5) * row_h
            lab = r["name"] if grouped else f"{r['name']}  ·  {r['country']}"
            if r["art"]:
                lab += " *"
            fig.text(FX(margin_l + (4 * MM if grouped else 0)), FY(ry), lab,
                     ha="left", va="center", fontsize=FS_LAB)
            fig.text(FX(n_x + n_w), FY(ry), f"{r['n']:,}", ha="right",
                     va="center", fontsize=FS_LAB)
            fig.text(FX(i_x + i_w), FY(ry), f"{r['I']:.2f}", ha="right",
                     va="center", fontsize=FS_LAB)
            if r["off"]:
                # sits inside the axes on an opaque patch: the bar spans the
                # full width here, so anything drawn over it needs its own
                # background to stay legible
                ax.text(XLIM[1] - 4.0, k, f"CI +/-{(r['bhi'] - r['blo']) / 2:.0f} %",
                        ha="right", va="center", fontsize=FS_FOOT,
                        color="#333333", style="italic", zorder=7,
                        bbox=dict(facecolor="white", edgecolor="none",
                                  boxstyle="square,pad=0.28"))

    # ---- shared tick labels, drawn once under the last block
    tick_ax = fig.add_axes([FX(plot_x), FY(y - 0.001), FX(plot_w), FY(0.001)])
    tick_ax.set_xlim(*XLIM); tick_ax.set_yticks([])
    tick_ax.set_xticks(XTICKS)
    tick_ax.set_xticklabels([f"{v:+d}" if v else "0" for v in XTICKS],
                            fontsize=FS_TICK)
    tick_ax.tick_params(length=2.0, width=0.5, pad=1.5)
    for s in tick_ax.spines.values():
        s.set_visible(False)

    fig.text(FX(plot_x + plot_w / 2), FY(y - axlab_h * 0.72),
             "Acute SIF change relative to baseline (%)", ha="center",
             va="center", fontsize=FS_AXTITLE, fontweight="bold")

    # No burned-in footnote. compose_figures.py keeps explanatory text in the
    # manuscript caption rather than the raster, so the palette note, the
    # Moran's I definition and the Desmond asterisk are carried in captions.md.

    p = OUT / f"{figname}.png"
    fig.savefig(p, dpi=DPI, facecolor="white")
    plt.close(fig)
    print(f"  {p.name}  {PAGE_W / MM:.0f} x {fig_h / MM:.0f} mm")
    return p


def write_captions():
    txt = """# Figure 10 caption

Generated by `compose_fig10.py`. Estimates and intervals are read verbatim from
`moran_forest_data.csv` (cached by `moran_forest.R`, 10 Jun); nothing is
recomputed here.

**Figure 10.** Spatial-autocorrelation robustness of the acute SIF suppression.
For each observable event the corridor-mean acute SIF anomaly is shown with its
naive (independent-sounding) and 25 km spatial-block bootstrap 95 % confidence
intervals, with the number of contributing soundings and Moran's I
(k-nearest-neighbour, k = 8) at right. Events are grouped by country:
(a) Mozambique; (b) Madagascar; (c) Zimbabwe; (d) Malawi; (e) Botswana. Bar
colour follows the percent-change scale shared with Figures 3 to 8. Open circles
mark events whose block interval excludes zero, crosses those whose interval
includes it. Block resampling widens the intervals by a median factor of about
two, yet the suppression stays significant for the well-sampled events and loses
significance only for the most sparsely sampled corridors. Cyclone Chalane over
Botswana rests on 15 soundings and its interval extends beyond the axis, marked
by triangles. The asterisk on Cyclone Desmond denotes the rising-baseline
artefact discussed in the text.
"""
    # named per figure: compose_figures_coords.py writes into the same folder
    (OUT / "captions_figure_10.md").write_text(txt, encoding="utf-8")
    print("  captions_figure_10.md")


if __name__ == "__main__":
    print("composing:")
    compose("Figure_10", grouped=True)
    write_captions()
    print("done ->", OUT)
