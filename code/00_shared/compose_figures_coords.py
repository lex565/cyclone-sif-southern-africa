import os
#!/usr/bin/env python
"""
compose_figures_coords.py - compose_figures.py plus geographic coordinates.

A copy, not an import, and it writes to a different folder. `combined figures v2`
and compose_figures.py itself are the approved set and must stay byte-identical;
this variant exists so the coordinate treatment can be judged side by side
without putting them at risk.

The only change is that every map panel now declares where it is. Each panel's
axes are set to the true degree bounds carried in manifest.csv, so the ticks are
read off the data rather than drawn on by hand. Labels go on the outer edges
only: latitude on the leftmost map of each event block, longitude beneath every
map in the block. Panel interiors stay clean, with no graticule, so nothing
competes with the anomaly colours.

Within an event all three panels share one extent (verified against
manifest.csv), which is why one latitude axis per block is sufficient and
correct rather than a convenient approximation.

Everything downstream of that - palette, typography, layout maths, colour bar -
is unchanged from compose_figures.py.

Original header follows.

compose_figures.py - assemble publication-standard combined figures.

Consumes the text-free map panels written by pub_panels.R (+ manifest.csv) and
draws every piece of typography fresh, once, at the final figure size: column
headers, row labels, per-panel date ranges, the north arrow and a single shared
discrete colour bar. Nothing is scaled up from a baked-in raster, so no clipped
titles and no oversized legend.

Page: 180 mm full-page width (journal single-column full width), 400 dpi.

Usage:  python compose_figures.py
Output: <results>/combined figures v2/Figure_*.png  (+ captions.md)
"""
from pathlib import Path
import csv

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm
from matplotlib.cm import ScalarMappable
import matplotlib.image as mpimg
import matplotlib.font_manager as fm
from matplotlib.ticker import MaxNLocator

# ---------------------------------------------------------------- config
BUILD = Path(os.path.join(os.environ.get("CYCLONE_SIF_RESULTS", r"results"), r"_pub_build"))
OUT = Path(os.path.join(os.environ.get("CYCLONE_SIF_RESULTS", r"results"), r"combined figures v3"))
OUT.mkdir(parents=True, exist_ok=True)

MM = 1 / 25.4
PAGE_W = 180 * MM          # full page width
DPI = 400

# locked palette, mirrors clean_figures.R
BRK = [-200, -40, -20, -5, 5, 20, 40, 200]
COL = ["#8c2d04", "#d95f0e", "#f6a563", "#f7f7f7", "#a6d96a", "#5aae61", "#1a7e3f"]
CBAR_TITLE = "Change relative to normal (%)"

# Abadi is an Office *cloud* font: Word downloads it on demand, so it is not in
# C:/Windows/Fonts and matplotlib cannot find it by name. Register the cached
# faces directly. Falls back to a humanist sans if the cache is ever cleared.
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
if FAMILY is None:                       # graceful fallback, nearest humanist sans
    FAMILY = next((c for c in ("Candara", "Segoe UI", "Trebuchet MS", "DejaVu Sans")
                   if any(f.name == c for f in fm.fontManager.ttflist)), "DejaVu Sans")
    print(f"  !! Abadi unavailable; falling back to {FAMILY}")

# Abadi has no Greek capital Phi (U+03A6), so the Phi in "ΦF (efficiency)" is
# supplied by a chained fallback (matplotlib resolves missing glyphs per char).
# DejaVu's Phi is heavy and clashes with Abadi; Segoe UI (humanist Windows sans)
# has a Phi that blends, so prefer it and keep DejaVu only as a last resort.
_FALLBACKS = [f for f in ("Segoe UI", "DejaVu Sans")
              if any(fnt.name == f for fnt in fm.fontManager.ttflist)]
plt.rcParams.update({"font.family": [FAMILY] + _FALLBACKS,
                     "mathtext.fontset": "dejavusans"})

# Single knob: text is sized to match Abadi 12 pt body copy in the manuscript,
# which only holds if the figure is placed at its true 180 mm width.
BASE_PT = 12.0
FS_COLHEAD = BASE_PT
FS_ROWLAB = BASE_PT
FS_DATE = BASE_PT
FS_CBAR = BASE_PT
FS_TICK = BASE_PT

WIN_HEAD = {"pre7": "Before the storm", "acute": "Storm week",
            "recov3": "3–4 weeks after"}
SIG_HEAD = {"sif": "SIF (photosynthesis glow)", "nirvr": "NIRvR (canopy structure)",
            "phif": "ΦF (efficiency)"}


def load_manifest():
    rows = list(csv.DictReader(open(BUILD / "manifest.csv")))
    man = {}
    for r in rows:
        r["has_data"] = r["has_data"].strip().upper() == "TRUE"
        man[(r["country"], r["label"], r["signal"], r["window"])] = r
    return man


MAN = load_manifest()


def ev(country, label):
    """Aspect ratio (h/w) and display name for an event."""
    for (c, l, s, w), r in MAN.items():
        if c == country and l == label and r["has_data"]:
            dx = float(r["xmax"]) - float(r["xmin"])
            dy = float(r["ymax"]) - float(r["ymin"])
            return dy / dx, r
    return 1.0, None


def draw_north(ax):
    """Small north arrow inside the top-right map."""
    ax.annotate("", xy=(0.90, 0.94), xytext=(0.90, 0.78), xycoords="axes fraction",
                arrowprops=dict(arrowstyle="-|>", color="black", lw=1.0,
                                mutation_scale=7))
    ax.text(0.90, 0.955, "N", transform=ax.transAxes, ha="center", va="bottom",
            fontsize=6.0, fontweight="bold")


def compact_date(s):
    """'18 Apr - 24 Apr 2019' -> '18-24 Apr'; cross-month keeps both, drops year.
    The year is already in the event title, so it is redundant per panel and the
    main reason the date string overflows a narrow (packed-layout) column."""
    try:
        a, b = [p.strip() for p in s.split(" - ")]
        d1, m1 = a.split()[0], a.split()[1]
        d2, m2 = b.split()[0], b.split()[1]
        return f"{d1}-{d2} {m1}" if m1 == m2 else f"{d1} {m1}-{d2} {m2}"
    except Exception:
        return s


def fmt_lon(v):
    return f"{abs(v):.0f}°{'E' if v >= 0 else 'W'}"


def fmt_lat(v):
    return f"{abs(v):.0f}°{'N' if v >= 0 else 'S'}"


def coord_ticks(lo, hi, nbins):
    """Sparse round degrees, with anything sitting on the frame dropped.

    A tick within a few percent of the panel edge collides with the corner of
    the frame and, at these column widths, with the neighbouring panel's first
    tick. Cheaper to drop it than to fight the layout."""
    ticks = MaxNLocator(nbins=nbins, steps=[1, 2, 2.5, 5, 10]).tick_values(lo, hi)
    pad = 0.04 * (hi - lo)
    keep = [t for t in ticks if lo + pad <= t <= hi - pad]
    # a lone tick states a coordinate but gives no sense of scale, so relax the
    # edge rule rather than ship a one-tick axis
    if len(keep) < 2:
        keep = [t for t in ticks if lo <= t <= hi]
    return keep


def draw_panel(ax, rec, date_label, north=False, fs_date=None,
               show_x=False, show_y=False, fs_coord=None):
    """Place one map image, tight frame, optional date caption above.

    The image is drawn into true degree coordinates rather than pixel indices,
    so the ticks come from the data extent in manifest.csv. `aspect="auto"` is
    kept: the axes box is already sized to the event aspect by compose(), and
    letting matplotlib enforce the aspect again would fight that and reintroduce
    the whitespace the packed layout exists to remove."""
    fs_date = FS_DATE if fs_date is None else fs_date
    fs_coord = fs_date * 0.92 if fs_coord is None else fs_coord
    for sp in ax.spines.values():
        sp.set_linewidth(0.6); sp.set_edgecolor("black")

    if rec is not None:
        x0, x1 = float(rec["xmin"]), float(rec["xmax"])
        y0, y1 = float(rec["ymin"]), float(rec["ymax"])
    else:
        x0, x1, y0, y1 = 0.0, 1.0, 0.0, 1.0

    if rec is not None and rec["has_data"]:
        img = mpimg.imread(rec["file"])
        ax.imshow(img, aspect="auto", interpolation="antialiased",
                  extent=(x0, x1, y0, y1))
    else:
        ax.set_facecolor("#fafafa")
        ax.text(0.5, 0.5, "no data\n(cloud blackout)", transform=ax.transAxes,
                ha="center", va="center", fontsize=fs_date, style="italic",
                color="grey")
    # limits after imshow: the no-data branch never called it, and imshow would
    # otherwise leave the shared extent unset for those panels
    ax.set_xlim(x0, x1); ax.set_ylim(y0, y1)

    ax.set_xticks(coord_ticks(x0, x1, 3) if show_x else [])
    ax.set_yticks(coord_ticks(y0, y1, 3) if show_y else [])
    if show_x:
        ax.set_xticklabels([fmt_lon(t) for t in ax.get_xticks()], fontsize=fs_coord)
    if show_y:
        ax.set_yticklabels([fmt_lat(t) for t in ax.get_yticks()], fontsize=fs_coord)
    ax.tick_params(length=1.8, width=0.5, pad=1.2, colors="#333333")

    if date_label:
        ax.set_title(date_label, fontsize=fs_date, pad=1.6, color="#222222")
    if north:
        draw_north(ax)


def add_colorbar(fig, y, h=0.012, w=0.46):
    """Single shared discrete colour bar, centred."""
    cax = fig.add_axes([(1 - w) / 2, y, w, h])
    cmap = ListedColormap(COL)
    norm = BoundaryNorm(BRK, cmap.N)
    cb = fig.colorbar(ScalarMappable(norm=norm, cmap=cmap), cax=cax,
                      orientation="horizontal", spacing="uniform",
                      ticks=BRK[1:-1])
    cb.ax.set_xticklabels([f"{v:+d}" for v in BRK[1:-1]], fontsize=FS_TICK)
    cb.ax.tick_params(length=2.0, width=0.5, pad=1.5)
    cb.outline.set_linewidth(0.5)
    cax.set_title(CBAR_TITLE, fontsize=FS_CBAR, fontweight="bold", pad=3.0)


MAX_H = 238 * MM        # keep every figure within a journal full page


def compose(figname, events, mode, letters=None, per_row=1,
            text_scale=1.0, compact_dates=False):
    """
    events  : list of (country, label, display_name)
    mode    : 'time' -> columns are windows pre7/acute/recov3 of SIF
              'trip' -> columns are signals sif/nirvr/phif in the acute window
    per_row : event blocks side by side. Each block is a 3-map strip, so
              per_row=2 gives 6 aligned map columns. Needed when many events of
              very different aspect must share one page: at per_row=1 a 55 mm
              column can never be filled by a 2:1-tall Madagascar map without a
              ~700 mm page, which is what strands all the horizontal space.
    text_scale   : shrink header/label/date type (and their bands). At per_row=2
                   the columns are only ~26 mm, too narrow for 12 pt text, so a
                   packed figure sets this < 1 to stop titles/dates overlapping.
    compact_dates: use '18-24 Apr' instead of '18 Apr - 24 Apr 2019' so the date
                   caption fits a narrow column. Pairs with a packed layout.
    """
    if mode == "time":
        cols = [("sif", "pre7"), ("sif", "acute"), ("sif", "recov3")]
        heads = [WIN_HEAD[w] for _, w in cols]
    else:
        cols = [("sif", "acute"), ("nirvr", "acute"), ("phif", "acute")]
        heads = [SIG_HEAD[s] for s, _ in cols]

    n = len(events)
    letters = letters or [chr(ord("a") + i) for i in range(n)]
    aspects = [ev(c, l)[0] for c, l, _ in events]

    # per-figure typography scale (colour bar stays at full body size)
    fs_colhead = FS_COLHEAD * text_scale
    fs_rowlab = FS_ROWLAB * text_scale
    fs_date = FS_DATE * text_scale
    band_pt = BASE_PT * text_scale

    # --- geometry, all in inches, then normalised to figure fractions ---------
    PT = 1 / 72                     # bands scale with the type size
    margin_l, margin_r = 5 * MM, 4 * MM
    gap_col, gap_row, gap_blk = 1.6 * MM, 2.6 * MM, 6 * MM
    hdr_row = band_pt * 1.45 * PT   # event label band
    date_h = band_pt * 1.35 * PT    # per-panel date band (axes titles live here)
    hdr_top = band_pt * 1.7 * PT    # column headers
    cbar_zone = BASE_PT * 3.4 * PT + 6 * MM

    # coordinate bands. lat_w is charged once per block, not per column, since
    # only the leftmost map of a block carries latitude; lon_h is charged once
    # per row of blocks, below the tallest map in that row.
    fs_coord = fs_date * 0.92
    lat_w = fs_coord * 2.9 * PT
    lon_h = fs_coord * 1.9 * PT

    content_w = PAGE_W - margin_l - margin_r
    block_w = (content_w - (per_row - 1) * gap_blk) / per_row
    col_w = (block_w - lat_w - 2 * gap_col) / 3

    # group events into rows of `per_row`; a row is as tall as its tallest map
    groups = [list(range(k, min(k + per_row, n))) for k in range(0, n, per_row)]
    rows_h = [max(col_w * aspects[i] for i in g) for g in groups]
    nr = len(groups)

    fixed = (hdr_top + cbar_zone + nr * (hdr_row + date_h + lon_h)
             + (nr - 1) * gap_row)
    fig_h = fixed + sum(rows_h)
    if fig_h > MAX_H:                       # shrink map rows to fit the page
        k = (MAX_H - fixed) / sum(rows_h)
        rows_h = [h * k for h in rows_h]
        fig_h = MAX_H

    fig = plt.figure(figsize=(PAGE_W, fig_h), dpi=DPI)
    fig.patch.set_facecolor("white")
    FX = lambda v: v / PAGE_W               # inches -> x fraction
    FY = lambda v: v / fig_h                # inches -> y fraction

    def col_x(b, j):
        return (margin_l + b * (block_w + gap_blk) + lat_w
                + j * (col_w + gap_col))

    # column headers, written once per block position
    for b in range(per_row):
        for j in range(3):
            fig.text(FX(col_x(b, j) + col_w / 2), 1 - FY(hdr_top * 0.62),
                     heads[j], ha="center", va="center", fontsize=fs_colhead,
                     fontweight="bold")

    y = fig_h - hdr_top
    for g, rh in zip(groups, rows_h):
        y -= hdr_row
        for b, i in enumerate(g):
            country, label, disp = events[i]
            rec0 = next((MAN.get((country, label, s, w)) for s, w in cols
                         if MAN.get((country, label, s, w))), None)
            hdr = f"{letters[i]}   Cyclone {disp}"
            if mode == "trip" and rec0:
                hdr += f"  ·  storm week {rec0['subtitle']}"
            # headers keep their old flush-left alignment with the block, so the
            # latitude column is inset under them rather than pushing them right
            fig.text(FX(col_x(b, 0) - lat_w), FY(y + 0.7 * MM), hdr, ha="left",
                     va="bottom", fontsize=fs_rowlab, fontweight="bold")
        y -= date_h
        y -= rh
        for b, i in enumerate(g):
            country, label, _ = events[i]
            aspect = aspects[i]
            for j, (sig, win) in enumerate(cols):
                rec = MAN.get((country, label, sig, win))
                map_h = min(rh, col_w * aspect)
                map_w = map_h / aspect
                cx = col_x(b, j) + (col_w - map_w) / 2
                # top-align: a short block stays directly under its own header
                # instead of floating in the middle of a row set by a tall one
                ax = fig.add_axes([FX(cx), FY(y + rh - map_h),
                                   FX(map_w), FY(map_h)])
                date = rec["subtitle"] if (rec and mode == "time") else ""
                if date and compact_dates:
                    date = compact_date(date)
                draw_panel(ax, rec, date, north=(i == 0 and j == 2),
                           fs_date=fs_date, show_x=True, show_y=(j == 0),
                           fs_coord=fs_coord)
        y -= lon_h                      # band the longitude labels drop into
        y -= gap_row

    add_colorbar(fig, y=FY(5.5 * MM), h=FY(3.2 * MM))
    p = OUT / f"{figname}.png"
    fig.savefig(p, dpi=DPI, facecolor="white")
    plt.close(fig)
    print(f"  {p.name}  {PAGE_W/MM:.0f} x {fig_h/MM:.0f} mm")
    return p


# ---------------------------------------------------------------- figure specs
MOZ, MAD, ZW, BW, MW = "Mozambique", "Madagascar", "Zimbabwe", "Botswana", "Malawi"

F3 = [(MOZ, "Kenneth_2019", "Kenneth (Apr 2019) · Mozambique"),
      (MOZ, "Desmond_2019", "Desmond (Jan 2019) · Mozambique"),
      (MOZ, "Chalane_2020", "Chalane (Dec 2020) · Mozambique"),
      (MAD, "Belna_2019", "Belna (Dec 2019) · Madagascar"),
      (MAD, "Chalane_2020", "Chalane (Dec 2020) · Madagascar"),
      (MAD, "Diane_2020", "Diane (Jan 2020) · Madagascar"),
      (MAD, "Francisco_2020", "Francisco (Feb 2020) · Madagascar"),
      (ZW, "Chalane_2020", "Chalane (Dec 2020) · Zimbabwe"),
      (BW, "Chalane_2020", "Chalane (Dec 2020) · Botswana")]

F4 = [(ZW, "Idai_2019", "Idai (Mar 2019) · Zimbabwe"),
      (MOZ, "Idai_2019", "Idai (Mar 2019) · Mozambique"),
      (MW, "Idai_2019", "Idai (Mar 2019) · Malawi")]

F6 = [(MOZ, "Kenneth_2019", "Kenneth (Apr 2019) · Mozambique"),
      (MOZ, "Desmond_2019", "Desmond (Jan 2019) · Mozambique"),
      (MOZ, "Chalane_2020", "Chalane (Dec 2020) · Mozambique")]

F7 = [(MAD, "Belna_2019", "Belna (Dec 2019) · Madagascar"),
      (MAD, "Chalane_2020", "Chalane (Dec 2020) · Madagascar"),
      (MAD, "Diane_2020", "Diane (Jan 2020) · Madagascar"),
      (MAD, "Francisco_2020", "Francisco (Feb 2020) · Madagascar")]

F8 = [(ZW, "Chalane_2020", "Chalane (Dec 2020) · Zimbabwe"),
      (BW, "Chalane_2020", "Chalane (Dec 2020) · Botswana")]

def write_captions():
    """
    Full captions belong in the manuscript text, not burned into the raster, so
    the figures carry only short panel labels. Figures 3 and 4 previously read
    "corridor-mean SIF time series" over panels that are in fact spatial anomaly
    maps; that wording is corrected here.
    """
    def panels(evts, mode, letters=None):
        letters = letters or [chr(ord("a") + i) for i in range(len(evts))]
        what = ("SIF anomaly maps for the pre-storm, storm-week and 3–4 week "
                "recovery windows" if mode == "time" else
                "storm-week SIF, NIRvR and ΦF anomaly maps")
        return "\n".join(
            f"- **{L}** — Cyclone {d.replace(' · ', ', ')}: {what}."
            for L, (_, _, d) in zip(letters, evts))

    lead_t = ("Spatial SIF anomaly, expressed as percent change relative to the "
              "pooled baseline climatology, across the baseline–event–recovery "
              "sequence. Each row is one event; columns are the pre-storm week, "
              "the storm week and the 3–4 week recovery window. The black line "
              "is the cyclone track segment. Panels marked *no data (cloud "
              "blackout)* had no retrievals passing QC in that window.")
    lead_p = ("Structure versus physiology in the storm week. For each event, "
              "SIF (photosynthesis), NIRvR (canopy structure) and ΦF "
              "(fluorescence efficiency) anomalies are shown as percent change "
              "relative to the pooled baseline climatology, over the same "
              "corridor and colour scale.")

    txt = ["# Corrected figure captions\n",
           "Generated by `compose_figures_coords.py`. Percent-change colour "
           "scale is shared across Figures 3–8. Axes are in degrees; latitude "
           "is labelled on the leftmost map of each event block and longitude "
           "beneath every map.\n"]
    for name, lead, evts, mode, L in [
            ("Figure 3", lead_t, F3, "time", None),
            ("Figure 4", lead_t, F4, "time", None),
            ("Figure 5", lead_p, F4, "trip", None),
            ("Figure 6", lead_p, F6, "trip", None),
            ("Figure 7", lead_p, F7, "trip", None),
            ("Figure 8", lead_p, F8, "trip", None)]:
        txt += [f"\n## {name}\n", lead + "\n", panels(evts, mode, L) + "\n"]
    # named per figure range: compose_fig10.py writes into the same folder and
    # a bare captions.md would have the two scripts clobbering each other
    (OUT / "captions_figures_3-8.md").write_text("\n".join(txt), encoding="utf-8")
    print("  captions_figures_3-8.md")


if __name__ == "__main__":
    print("composing:")
    compose("Figure_3", F3, "time", per_row=2, text_scale=0.72,
            compact_dates=True)
    compose("Figure_4", F4, "time")
    compose("Figure_5", F4, "trip")
    compose("Figure_6", F6, "trip")
    compose("Figure_7", F7, "trip")
    compose("Figure_8", F8, "trip")
    write_captions()
    print("done ->", OUT)
