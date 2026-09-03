# GROMACS_NA53 — Design System

| Field | Value |
|---|---|
| **Status** | Active |
| **Last updated** | 2026-09-03 |

> Design here means: consistent visual identity for **documentation**, **terminal
> output**, and **publication figures** — so every artifact in this repo looks
> like it came from one project, whether produced by a human or an AI.

---

## 1. Theme & Mood

- **Theme:** Scientific / molecular-bio / HPC technical.
- **Mood:** precise, calm, data-first. No decorative noise.
- **Concept:** "nucleic-acid gel" — cool blues for structure/stability, warm
  amber as the single accent (biosensing signal), neutral graphite for text.

## 2. Color Palette

### 2.1 Brand colors
| Name | Hex | Usage |
|---|---|---|
| **Nucleic Blue** (primary) | `#1F5F8B` | Headings, links, primary accents, brand elements |
| **Amber Signal** (accent) | `#E8A33D` | Warnings, highlights, the "biosensing signal" accent |
| **Graphite** (neutral) | `#2E3440` | Body text, code, tables |
| **Silver** (neutral light) | `#ECEFF4` | Table headers, code blocks background |
| **Paper** (background) | `#FFFFFF` / `#F9FAFB` | Page / card backgrounds |

### 2.2 Semantic (status) colors — used in docs & terminal
| Status | Hex | Emoji | Meaning |
|---|---|---|---|
| Success | `#2E8B57` | ✅ | done, verified, passing |
| Info | `#1F5F8B` | ℹ️ | neutral note |
| Warning | `#E8A33D` | ⚠️ | caution, needs attention |
| Error | `#C0392B` | ❌ | failure, blocked |
| In-progress | `#5B8FB9` | 🔵 | active |
| Pending | `#8D99AE` | ⬜ | not started |

### 2.3 Figure data palette (colorblind-safe, print-friendly)
For plots: a **sequential blue** for single-metric trends and **categorical
5-color** set for multi-series:
- Sequential: `#EFF6FB → #9CC3E5 → #1F5F8B → #0E3A57`
- Categorical: `#1F5F8B #E8A33D #2E8B57 #8E44AD #C0392B`
- Free-energy landscapes: `viridis` or the sequential blue ramp (never `jet`).
- Consistent across RMSD, Rg, RMSF, H-bond, SASA, PCA, clustering figures.

## 3. Typography

### 3.1 Documentation (GitHub-rendered markdown)
| Element | Font | Size | Weight |
|---|---|---|---|
| H1 | Inter / system sans | 32 px | 700 |
| H2 | Inter / system sans | 24 px | 600 |
| H3 | Inter / system sans | 20 px | 600 |
| Body | Inter / system sans | 16 px | 400 |
| Code / commands | JetBrains Mono / monospace | 14 px | 400 |
| Tables | system sans | 14 px | 400 |

Fallback rule: docs render on GitHub → rely on `-apple-system`/system fonts;
never require a webfont. Headings use `#` hierarchy only, no bold-H1 duplication.

### 3.2 Terminal output (scripts)
- Banners: box-drawing characters (`╔ ═ ╗ ║ ╠ ╣ ╚`) with `cyan`/`bold` styling
  where TTY supports color; ASCII fallback is acceptable.
- Stage markers: `▶ Step N/M:` for progress, `✓` for success, `❌` for errors.
- **Note:** avoid heavy box art inside SLURM logs (non-TTY) — the .sbatch files
  intentionally use plain text sections.

### 3.3 Figures (matplotlib)
| Property | Value |
|---|---|
| Font family | DejaVu Sans (default; no custom font install on HPC) |
| Font size | 11 pt axis, 12 pt labels, 14 pt titles |
| DPI | 300 for publication, 150 for preview |
| Figure size | single: (8, 5); two-panel: (12, 5) |
| Grid | light `#E5E9F0`, behind data |
| Line width | 1.5–2.0 |
| Axis labels | `Metric (units)` — always include units |

## 4. Documentation Conventions

### 4.1 Status legend (consistent across all docs)
```
✅ done/verified      🔵 in progress      ⬜ pending      ⏸ blocked
```

### 4.2 Markdown style rules
1. Every doc starts with a metadata table (Field/Value): Status, Last updated.
2. Tables for parameter/data matrices (GitHub renders them well); no images of tables.
3. Commands in fenced code blocks with `bash` annotation.
4. File paths referenced relative to repo root.
5. "Verified" claims carry a date + source (e.g., `verified via sinfo 2026-09-03`).
6. Long docs use `---` section separators and numbered headings (`## 1.`, `## 2.`).

### 4.3 Emoji usage (restrained)
- ✅/❌/⚠️/ℹ️/🔵/⬜ in status tables only.
- 🧬 for the project brand in README title only.
- No decorative emoji in scientific content.

## 5. Figure Templates

| Figure | Style |
|---|---|
| RMSD / Rg / H-bonds time series | line plot, sequential blue, shaded ±σ |
| RMSF | line/bar per residue, amber highlight on flexible regions |
| PCA projection | scatter, categorical colors per cluster |
| Free-energy landscape | 2D contour/imshow, viridis, labeled minima |
| Clustering | bar/table of cluster populations |
| Summary panel | 2×2 grid of the above at 150 dpi preview |

## 6. Naming Conventions

| Artifact | Convention | Example |
|---|---|---|
| MDP configs | lowercase, stage name | `prod.mdp` |
| Scripts | `NN_stage_name.sh` | `03_production.sh` |
| SLURM | `NN_stage.sbatch` | `03_prod.sbatch` |
| Analysis outputs | lowercase metric | `rmsd.xvg`, `gyrate.xvg` |
| Figures | `metric_description.png` | `rmsd_convergence.png` |
| AI records | lowercase, root level | `PRD.md`, `memory.md` |
| Conda env | snake_case | `na53_aptamer` |

## 7. README & Repo Polish

- README hero: title + one-line purpose + status badges (CI passing).
- Badge style: flat, `#1F5F8B` for brand, green when passing.
- Repo topics (GitHub): `gromacs`, `molecular-dynamics`, `dna-aptamer`,
  `biosensing`, `hpc`, `slurm`, `ngal`, `biomarker`.
- `docs/` = scientific/management docs (numbered 01–06); root = AI records (6 files).