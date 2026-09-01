#!/usr/bin/env python
"""
compose_figure3_uniform.py - Figure 3 redrawn so every panel shares one frame.

WHY THIS EXISTS
Second author's comment on the Figure 3 caption (2026-08-22, comment id 169):
"Your images should be similar, they should be in the same frame."

He is right. compose_figures_coords.py sizes each map from its own event's
geographic aspect ratio (dy/dx from manifest.csv), and across the nine non-Idai
corridors that ratio spans 0.559 (Botswana/Chalane, wide) to 2.124
(Madagascar/Belna, tall), a 3.8x range. Every block therefore gets a different
box, each row is as tall as its tallest member, and the page ends up ragged with
large white gaps. Figure 4 escapes this only because its three Idai corridors
happen to be similar and it draws one event per row.

WHAT CHANGED, AND ONLY THIS
1. One uniform panel box for all 27 maps. Each event's plotted extent is padded
   SYMMETRICALLY in longitude or latitude until its aspect matches a common
   target, so every map is drawn undistorted, keeps its true degree coordinates,
   and sits in an identically sized frame. Nothing is cropped, stretched or
   resampled; the padding is white space around the data.

   The target aspect is the geometric mean of the nine event aspects (~1.02),
   which minimises the mean log padding across the set rather than favouring the
   tallest or the widest corridor.

2. The four "no data" panels are relabelled from the true reason rather than an
   assumed one. The label is decided by looking in the TROPOSIF archive: if no
   L2B file exists for any day in that window the panel says the archive has no
   coverage; if files exist but no sounding passed QC it says cloud. All four
   currently fall in 16-27 January 2021, and the archive's first 2021 file is
   2021-04-25, so all four are archive gaps and none of them are cloud.

Everything else - palette, breaks, Abadi typography, colour bar, column headers,
date captions, north arrow, page width, dpi - is carried over unchanged so the
figure still matches Figures 4 to 8.

Writes to a NEW folder. compose_figures_coords.py and `combined figures v3` are
untouched.

Usage:  python compose_figure3_uniform.py
Output: G:/Alex/Results/combined figures v4/Figure_3_uniform.png (+ .pdf, audit)
"""
from pathlib import Path
from datetime import date, timedelta
import csv
import math
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm
from matplotlib.cm import ScalarMappable
import matplotlib.image as mpimg
import matplotlib.font_manager as fm
from matplotlib.ticker import MaxNLocator

# ---------------------------------------------------------------- config
BUILD = Path(os.path.join(os.environ.get("CYCLONE_SIF_RESULTS", "results"), "_pub_build"))
OUT = Path(os.path.join(os.environ.get("CYCLONE_SIF_RESULTS", "results"), "combined figures v4"))
OUT.mkdir(parents=True, exist_ok=True)
SIF_ROOT = Path(os.path.join(os.environ.get("CYCLONE_SIF_DATA", "data_raw"), "TROPOSIF"))

MM = 1 / 25.4
PAGE_W = 180 * MM
MAX_H = 238 * MM
DPI = 400

BRK = [-200, -40, -20, -5, 5, 20, 40, 200]
COL = ["#8c2d04", "#d95f0e", "#f6a563", "#f7f7f7", "#a6d96a", "#5aae61", "#1a7e3f"]
CBAR_TITLE = "Change relative to normal (%)"

ABADI_CACHE = Path(os.path.join(os.environ.get("CYCLONE_SIF_HOME", "."), "AppData/Local/Microsoft/FontCache/4/CloudFonts/Abadi"))


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

BASE_PT = 12.0
FS_CBAR = BASE_PT
FS_TICK = BASE_PT

WIN_HEAD = {"pre7": "Before the storm", "acute": "Storm week",
            "recov3": "3-4 weeks after"}

MOZ, MAD, ZW, BW = "Mozambique", "Madagascar", "Zimbabwe", "Botswana"

F3 = [(MOZ, "Kenneth_2019", "Kenneth (Apr 2019) \u00b7 Mozambique"),
      (MOZ, "Desmond_2019", "Desmond (Jan 2019) \u00b7 Mozambique"),
      (MOZ, "Chalane_2020", "Chalane (Dec 2020) \u00b7 Mozambique"),
      (MAD, "Belna_2019", "Belna (Dec 2019) \u00b7 Madagascar"),
      (MAD, "Chalane_2020", "Chalane (Dec 2020) \u00b7 Madagascar"),
      (MAD, "Diane_2020", "Diane (Jan 2020) \u00b7 Madagascar"),
      (MAD, "Francisco_2020", "Francisco (Feb 2020) \u00b7 Madagascar"),
      (ZW, "Chalane_2020", "Chalane (Dec 2020) \u00b7 Zimbabwe"),
      (BW, "Chalane_2020", "Chalane (Dec 2020) \u00b7 Botswana")]

COLS = [("sif", "pre7"), ("sif", "acute"), ("sif", "recov3")]


# ---------------------------------------------------------------- manifest
def load_manifest():
    man = {}
    for r in csv.DictReader(open(BUILD / "manifest.csv")):
        r["has_data"] = r["has_data"].strip().upper() == "TRUE"
        man[(r["country"], r["label"], r["signal"], r["window"])] = r
    return man


MAN = load_manifest()


def event_extent(country, label):
    """True degree bounds for an event. All its panels share one extent."""
    for (c, l, s, w), r in MAN.items():
        if c == country and l == label and r["has_data"]:
            return (float(r["xmin"]), float(r["xmax"]),
                    float(r["ymin"]), float(r["ymax"]))
    return None


def pad_to_aspect(ext, target):
    """Grow the window symmetrically until dy/dx == target.

    Padding, never cropping: the map keeps every pixel it had and keeps its
    true shape, it just gains blank margin on two sides so the frame matches
    every other frame in the figure."""
    x0, x1, y0, y1 = ext
    dx, dy = x1 - x0, y1 - y0
    if dy / dx > target:                 # too tall, widen in longitude
        want = dy / target
        p = (want - dx) / 2.0
        return x0 - p, x1 + p, y0, y1
    want = dx * target                   # too wide, heighten in latitude
    p = (want - dy) / 2.0
    return x0, x1, y0 - p, y1 + p


# ------------------------------------------------- why a panel has no data
MONTHS = {m: i + 1 for i, m in enumerate(
    ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"])}


def parse_window(subtitle):
    """'20 Jan - 26 Jan 2021' -> (date, date). Handles a Dec->Jan rollover,
    where the printed year belongs to the END of the window."""
    m = re.match(r"\s*(\d{1,2})\s+(\w{3})\s*-\s*(\d{1,2})\s+(\w{3})\s+(\d{4})\s*$",
                 subtitle or "")
    if not m:
        return None
    d1, m1, d2, m2, yr = int(m.group(1)), m.group(2), int(m.group(3)), m.group(4), int(m.group(5))
    if m1 not in MONTHS or m2 not in MONTHS:
        return None
    y2 = yr
    y1 = yr - 1 if MONTHS[m1] > MONTHS[m2] else yr
    try:
        return date(y1, MONTHS[m1], d1), date(y2, MONTHS[m2], d2)
    except ValueError:
        return None


def archive_days(a, b):
    """How many TROPOSIF L2B files actually exist between two dates."""
    n = 0
    d = a
    while d <= b:
        if (SIF_ROOT / f"{d.year}" / f"TROPOSIF_L2B_{d:%Y-%m-%d}.nc").exists():
            n += 1
        d += timedelta(days=1)
    return n


def nodata_label(rec):
    """The honest reason, read from the archive rather than assumed.

    The published figure said 'cloud blackout' on every empty panel. Four of
    them sit in the 2021-01-01 to 2021-04-24 hole in the TROPOSIF archive,
    where there is no file to be clouded.

    Pre-wrapped short so it starts inside a 24 mm panel; fit_labels() then
    measures it against its own axes and shrinks anything still overhanging."""
    win = parse_window(rec["subtitle"]) if rec else None
    if win is None:
        return "no data", "unknown", 0
    n = archive_days(*win)
    if n == 0:
        return "no data\n(no archive\ncoverage)", "archive gap", 0
    return "no data\n(no cloud-free\nretrievals)", "cloud", n


def fit_labels(fig, labels):
    """Shrink any no-data caption that overhangs its own panel.

    The caption is centred in the axes, so a string wider than the box spills
    symmetrically over both frame edges and collides with the neighbouring map.
    Measure the drawn text against the axes rectangle and step the point size
    down until it clears, with a small margin so it never touches the frame."""
    fig.canvas.draw()
    r = fig.canvas.get_renderer()
    for t, ax in labels:
        box = ax.get_window_extent(renderer=r)
        for _ in range(24):
            ext = t.get_window_extent(renderer=r)
            if (ext.width <= 0.86 * box.width and ext.height <= 0.62 * box.height):
                break
            t.set_fontsize(t.get_fontsize() * 0.92)
        else:
            print("  !! caption still oversized after 24 steps")


# ---------------------------------------------------------------- drawing
def draw_north(ax):
    ax.annotate("", xy=(0.90, 0.94), xytext=(0.90, 0.78), xycoords="axes fraction",
                arrowprops=dict(arrowstyle="-|>", color="black", lw=1.0,
                                mutation_scale=7))
    ax.text(0.90, 0.955, "N", transform=ax.transAxes, ha="center", va="bottom",
            fontsize=6.0, fontweight="bold")


def compact_date(s):
    try:
        a, b = [p.strip() for p in s.split(" - ")]
        d1, m1 = a.split()[0], a.split()[1]
        d2, m2 = b.split()[0], b.split()[1]
        return f"{d1}-{d2} {m1}" if m1 == m2 else f"{d1} {m1}-{d2} {m2}"
    except Exception:
        return s


def fmt_lon(v):
    return f"{abs(v):.0f}\u00b0{'E' if v >= 0 else 'W'}"


def fmt_lat(v):
    return f"{abs(v):.0f}\u00b0{'N' if v >= 0 else 'S'}"


def coord_ticks(lo, hi, nbins):
    ticks = MaxNLocator(nbins=nbins, steps=[1, 2, 2.5, 5, 10]).tick_values(lo, hi)
    pad = 0.04 * (hi - lo)
    keep = [t for t in ticks if lo + pad <= t <= hi - pad]
    if len(keep) < 2:
        keep = [t for t in ticks if lo <= t <= hi]
    return keep


def draw_panel(ax, rec, true_ext, box_ext, date_label, north, fs_date,
               show_y, fs_coord, audit, labels):
    """One map, drawn at its TRUE extent inside a padded, uniform frame."""
    for sp in ax.spines.values():
        sp.set_linewidth(0.6); sp.set_edgecolor("black")

    X0, X1, Y0, Y1 = box_ext
    if rec is not None and rec["has_data"]:
        img = mpimg.imread(rec["file"])
        ax.imshow(img, aspect="auto", interpolation="antialiased",
                  extent=true_ext)
    else:
        ax.set_facecolor("#fafafa")
        txt, why, nfiles = nodata_label(rec)
        t = ax.text(0.5, 0.5, txt, transform=ax.transAxes, ha="center",
                    va="center", fontsize=fs_date * 0.95, style="italic",
                    color="grey", linespacing=1.25, clip_on=False)
        labels.append((t, ax))
        if rec is not None:
            audit.append((rec["country"], rec["label"], rec["window"],
                          rec["subtitle"], why, nfiles))

    ax.set_xlim(X0, X1); ax.set_ylim(Y0, Y1)
    ax.set_xticks(coord_ticks(X0, X1, 3))
    ax.set_yticks(coord_ticks(Y0, Y1, 3) if show_y else [])
    ax.set_xticklabels([fmt_lon(t) for t in ax.get_xticks()], fontsize=fs_coord)
    if show_y:
        ax.set_yticklabels([fmt_lat(t) for t in ax.get_yticks()], fontsize=fs_coord)
    ax.tick_params(length=1.8, width=0.5, pad=1.2, colors="#333333")

    if date_label:
        ax.set_title(date_label, fontsize=fs_date, pad=1.6, color="#222222")
    if north:
        draw_north(ax)


def add_colorbar(fig, y, h, w=0.46):
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


# ---------------------------------------------------------------- compose
def compose(events, per_row=2, text_scale=0.72, compact_dates=True):
    n = len(events)
    letters = [chr(ord("a") + i) for i in range(n)]

    exts = [event_extent(c, l) for c, l, _ in events]
    aspects = [(e[3] - e[2]) / (e[1] - e[0]) for e in exts]
    # geometric mean: minimises the mean log padding over the set
    target = math.exp(sum(math.log(a) for a in aspects) / len(aspects))
    boxes = [pad_to_aspect(e, target) for e in exts]

    fs_colhead = fs_rowlab = fs_date = BASE_PT * text_scale
    band_pt = BASE_PT * text_scale

    PT = 1 / 72
    margin_l, margin_r = 5 * MM, 4 * MM
    gap_col, gap_row, gap_blk = 1.6 * MM, 2.6 * MM, 6 * MM
    hdr_row = band_pt * 1.45 * PT
    date_h = band_pt * 1.35 * PT
    hdr_top = band_pt * 1.7 * PT
    cbar_zone = BASE_PT * 3.4 * PT + 6 * MM

    fs_coord = fs_date * 0.92
    lat_w = fs_coord * 2.9 * PT
    lon_h = fs_coord * 1.9 * PT

    content_w = PAGE_W - margin_l - margin_r
    block_w = (content_w - (per_row - 1) * gap_blk) / per_row
    col_w = (block_w - lat_w - 2 * gap_col) / 3

    # every row is now the same height, because every panel is the same shape
    row_h = col_w * target
    groups = [list(range(k, min(k + per_row, n))) for k in range(0, n, per_row)]
    nr = len(groups)

    fixed = (hdr_top + cbar_zone + nr * (hdr_row + date_h + lon_h)
             + (nr - 1) * gap_row)
    fig_h = fixed + nr * row_h
    if fig_h > MAX_H:
        row_h = (MAX_H - fixed) / nr
        fig_h = MAX_H

    fig = plt.figure(figsize=(PAGE_W, fig_h), dpi=DPI)
    fig.patch.set_facecolor("white")
    FX = lambda v: v / PAGE_W
    FY = lambda v: v / fig_h

    def col_x(b, j):
        return (margin_l + b * (block_w + gap_blk) + lat_w
                + j * (col_w + gap_col))

    for b in range(per_row):
        for j in range(3):
            fig.text(FX(col_x(b, j) + col_w / 2), 1 - FY(hdr_top * 0.62),
                     WIN_HEAD[COLS[j][1]], ha="center", va="center",
                     fontsize=fs_colhead, fontweight="bold")

    audit = []
    labels = []
    y = fig_h - hdr_top
    for g in groups:
        y -= hdr_row
        for b, i in enumerate(g):
            fig.text(FX(col_x(b, 0) - lat_w), FY(y + 0.7 * MM),
                     f"{letters[i]}   Cyclone {events[i][2]}", ha="left",
                     va="bottom", fontsize=fs_rowlab, fontweight="bold")
        y -= date_h
        y -= row_h
        for b, i in enumerate(g):
            country, label, _ = events[i]
            for j, (sig, win) in enumerate(COLS):
                rec = MAN.get((country, label, sig, win))
                # identical box for every panel in the figure
                ax = fig.add_axes([FX(col_x(b, j)), FY(y),
                                   FX(col_w), FY(row_h)])
                d = rec["subtitle"] if rec else ""
                if d and compact_dates:
                    d = compact_date(d)
                draw_panel(ax, rec, exts[i], boxes[i], d,
                           north=(i == 0 and j == 2), fs_date=fs_date,
                           show_y=(j == 0), fs_coord=fs_coord, audit=audit,
                           labels=labels)
        y -= lon_h
        y -= gap_row

    add_colorbar(fig, y=FY(5.5 * MM), h=FY(3.2 * MM))
    fit_labels(fig, labels)

    png = OUT / "Figure_3_uniform.png"
    fig.savefig(png, dpi=DPI, facecolor="white")
    fig.savefig(OUT / "Figure_3_uniform.pdf", facecolor="white")
    plt.close(fig)

    # ---- audit -------------------------------------------------------------
    lines = ["FIGURE 3 - UNIFORM FRAME REBUILD",
             "Built by compose_figure3_uniform.py from the same _pub_build/manifest.csv",
             "panels as the published version. No value, pixel or colour changed.",
             "",
             f"Page: {PAGE_W/MM:.0f} x {fig_h/MM:.0f} mm at {DPI} dpi, {per_row} event blocks per row.",
             f"Common panel aspect (height/width): {target:.4f}  "
             f"(geometric mean of the nine event aspects)",
             f"Every panel box: {col_w/MM:.1f} x {row_h/MM:.1f} mm - identical for all 27 maps.",
             "",
             "PER-EVENT PADDING (extent grown symmetrically; nothing cropped or stretched)",
             f"{'event':34s} {'true aspect':>11s} {'padded':>8s} {'lon pad':>9s} {'lat pad':>9s}"]
    for (c, l, _), e, bx, a in zip(events, exts, boxes, aspects):
        lonpad = ((bx[1] - bx[0]) - (e[1] - e[0])) / 2
        latpad = ((bx[3] - bx[2]) - (e[3] - e[2])) / 2
        lines.append(f"{c+'/'+l:34s} {a:11.3f} {target:8.3f} "
                     f"{lonpad:8.3f}\u00b0 {latpad:8.3f}\u00b0")
    lines += ["",
              "EMPTY PANELS - REASON READ FROM THE ARCHIVE, NOT ASSUMED",
              "The published figure labelled every empty panel 'cloud blackout'.",
              "Each one below was re-checked by counting TROPOSIF L2B files on disk",
              "for the days in its window.",
              f"{'event':30s} {'window':8s} {'dates':24s} {'files':>6s}  reason"]
    for c, l, w, sub, why, nf in audit:
        lines.append(f"{c+'/'+l:30s} {w:8s} {sub:24s} {nf:6d}  {why}")
    lines += ["",
              "TROPOSIF archive: first 2021 file is 2021-04-25, so 2021-01-01 to",
              "2021-04-24 contains no files at all. All four empty panels fall in",
              "16-27 January 2021 and are archive gaps, not cloud.",
              "",
              "UNCHANGED FROM THE PUBLISHED FIGURE: colour breaks "
              f"{BRK[1:-1]}, palette, Abadi typography,",
              "column headers, per-panel date captions, north arrow, shared colour bar,",
              "180 mm page width, 400 dpi, and the source panel rasters themselves."]
    (OUT / "Figure_3_uniform_audit.txt").write_text("\n".join(lines), encoding="utf-8")

    print(f"  target aspect {target:.4f}")
    print(f"  panel box {col_w/MM:.1f} x {row_h/MM:.1f} mm")
    print(f"  {png.name}  {PAGE_W/MM:.0f} x {fig_h/MM:.0f} mm")
    for c, l, w, sub, why, nf in audit:
        print(f"  empty: {c}/{l} {w} {sub} -> {why} ({nf} files)")
    return png


if __name__ == "__main__":
    print("composing Figure 3 with uniform panel frames:")
    compose(F3)
    print("done ->", OUT)
