# 🧬 GROMACS_NA53
## In Silico 3D Folding of NA53 DNA Aptamer for NGAL Biosensing

---

## 📋 Project Overview

| Parameter | Value |
|-----------|-------|
| **Aptamer** | NA53 (DNA, 55 nt) |
| **Sequence** | `AGCAGCACAGAGGTCAGATGGCGCTGGATAGCAAGATCACGTTATCATCGTAAACCCTATGCGTGCTACCGTGAA` |
| **Target** | NGAL (Neutrophil Gelatinase-Associated Lipocalin, ~25 kDa) |
| **Force Field** | AMBER99bsc1 (DNA) + TIP3P (water) |
| **Simulation** | NPT at 310.15 K, 1.0 bar |
| **Production** | 100 ns test run (expandable) |
| **Analysis** | Conformational switching: PCA, clustering, free energy landscape |
| **HPC** | Taiwania 3 (Taiwan) |

---

## 🧠 AI-Reference Records (read these first)

This repository is engineered so that any AI agent (or human) can continue the
project flawlessly. Six living records live at the repo root — **an agent should
read them in this order**:

| File | What it answers |
|------|-----------------|
| [`PRD.md`](PRD.md) | What we're building, target users, features (F-01..F-16), KPIs |
| [`architecture.md`](architecture.md) | Data flow, folder/file structure, tech stack, execution modes |
| [`rules.md`](rules.md) | What to use/avoid, library policy, error handling, **AI boundaries** |
| [`phases.md`](phases.md) | Phase plan P0–P11 (deepsearch → brainstorm → analyse → plan → execute) |
| [`design.md`](design.md) | Theme, color palette, typography, figure specs |
| [`memory.md`](memory.md) | What's completed, what's being worked on, next actions, verified facts |

> ⚠️ **Contract:** never fabricate data or cluster facts. Every parameter is
> verified (see `docs/`). If something is unverified, say so and run the command
> that would verify it. Full rules: [`rules.md`](rules.md).

---

## 🚀 Quick Start (Complete Pipeline)

```bash
# ─── On your local machine ────────────────────────────────
git clone https://github.com/YOUR_USERNAME/GROMACS_NA53.git
cd GROMACS_NA53

# ─── On Taiwania 3 ────────────────────────────────────────
# (VERIFIED: 2FA required — method 1 = app OTP)
ssh u5662994@twnia3.nchc.org.tw

# Clone your repo
git clone https://github.com/YOUR_USERNAME/GROMACS_NA53.git
cd GROMACS_NA53

# Setup environment (first time only): conda env WITH gromacs engine
# (account mst115368 + partition ct56 are already filled in slurm/*.sbatch)
bash slurm/setup_taiwania3.sh https://github.com/YOUR_USERNAME/GROMACS_NA53.git

# Activate
conda activate na53_aptamer     # gmx comes from this env (conda-forge 2024.4)

# Run pipeline
cd scripts/
bash 00_predict_structure.sh                   # Predict 3D fold
bash 01_system_prep.sh ../structures/NA53_initial.pdb  # Build system
bash 02_equilibration.sh ../system/*_ionized.gro -nb auto  # Equilibrate
bash 03_production.sh -nb auto 100             # 100 ns production
bash 04_analysis.sh prod 0                     # Analyze
python3 05_visualization.py ../analysis        # Plot results

# ─── OR submit via SLURM ──────────────────────────────────
cd slurm/
sbatch 01_prep.sbatch
# Wait for completion, then:
sbatch 02_equil.sbatch
# Wait, then:
sbatch 03_prod.sbatch
# Wait, then:
sbatch 04_analysis.sbatch
```

---

## 📁 Project Structure

```
GROMACS_NA53/
├── README.md                      # This file
├── PRD.md                         # Project requirements (AI record)
├── architecture.md                # System architecture (AI record)
├── rules.md                       # Agent rules & boundaries (AI record)
├── phases.md                      # Phase plan P0–P11 (AI record)
├── design.md                      # Design system (AI record)
├── memory.md                      # Live project memory (AI record)
├── environment.yml                # Conda environment specification
├── .gitignore                     # Git ignore rules
├── .github/workflows/validate.yml # CI: syntax validation
│
├── docs/                          # Project management documents
│   ├── 01_PROJECT_CHARTER.md      # Mission directive & system definition
│   ├── 02_PROJECT_SCOPE_STATEMENT.md  # System boundary & force field matrix
│   ├── 03_WORK_BREAKDOWN_STRUCTURE.md # GROMACS pipeline architecture
│   ├── 04_RACI_MATRIX.md          # Script dependencies & responsibilities
│   ├── 05_BUDGET_TRACKER.md       # Storage & GPU core-hour ledger
│   ├── 06_KPI_DASHBOARD.md        # Real-time MD performance monitor
│   ├── APTAMD_DEEP_ANALYSIS.md    # Protocol comparison vs APTAMD (GaMD, INF)
│   └── TRANSCRIPTS_DEEP_ANALYSIS.md # Verified Taiwania 3 facts + hallucination audit
│
├── configs/                       # GROMACS MDP parameter files
│   ├── em.mdp                     # Energy minimization
│   ├── nvt.mdp                    # NVT equilibration
│   ├── npt.mdp                    # NPT equilibration (restrained)
│   ├── npt_free.mdp               # NPT equilibration (unrestrained)
│   ├── prod.mdp                   # Production MD
│   └── ions.mdp                   # Pre-processing for genion
│
├── scripts/                       # Automation scripts
│   ├── 00_predict_structure.sh    # 3D structure prediction from sequence
│   ├── 01_system_prep.sh          # pdb2gmx → editconf → solvate → genion
│   ├── 02_equilibration.sh        # EM → NVT → NPT
│   ├── 03_production.sh           # Production MD
│   ├── 04_analysis.sh             # RMSD, RMSF, Rg, H-bonds, PCA, clustering
│   ├── 05_visualization.py        # Publication-quality plots
│   ├── run_pipeline.sh            # Master pipeline runner
│   ├── install_dependencies.sh    # Install GROMACS + AmberTools + Python deps
│   └── install_gromacs_gpu.sh     # Compile GROMACS with GPU support
│
├── slurm/                         # Taiwania 3 SLURM scripts
│   ├── setup_taiwania3.sh         # First-time setup on Taiwania 3
│   ├── 01_prep.sbatch             # System preparation job
│   ├── 02_equil.sbatch            # Equilibration job
│   ├── 03_prod.sbatch             # Production MD job
│   └── 04_analysis.sbatch         # Analysis job
│
├── templates/                     # Reusable templates
│   └── posre.itp                  # Position restraints template
│
├── structures/                    # PDB files (input + processed)
├── system/                        # System files (.gro, .top)
├── equilibration/                 # EM, NVT, NPT outputs
├── production/                    # Production trajectory
├── analysis/                      # Analysis .xvg files
├── results/                       # Final results
│   └── figures/                   # Generated plots
└── logs/                          # Execution logs
```

---

## 🔄 Pipeline Workflow (5 Work Packages)

```
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ WP0:     │→│ WP1:     │→│ WP2:     │→│ WP3:     │→│ WP4:     │
│ PREDICT  │ │ SYSTEM   │ │ EQUILIB. │ │ PRODUC.  │ │ ANALYSIS │
│ 3D FOLD  │ │ PREP     │ │          │ │          │ │          │
└──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘
 ~1 hr        ~5 min       ~2 hr       ~6-12 hr     ~1 hr
```

### WP0: Structure Prediction
```bash
bash 00_predict_structure.sh
```
- Secondary structure: seqfold / RNAfold (ViennaRNA)
- 3D fold: B-form DNA helix model → refined by MD

### WP1: System Preparation
```bash
bash 01_system_prep.sh ../structures/NA53_initial.pdb amber99sb-ildn tip3p
```
- `gmx pdb2gmx` → topology (AMBER99bsc1 + TIP3P)
- `gmx editconf` → dodecahedral box (1.2 nm padding)
- `gmx solvate` → explicit water
- `gmx genion` → Na⁺/Cl⁻ (neutral + 0.15 M)

### WP2: Equilibration
```bash
bash 02_equilibration.sh ../system/*_ionized.gro -nb auto
```
1. **Energy Minimization** (steepest descent, Fmax < 1000 kJ/mol/nm)
2. **NVT** (100 ps, Nosé-Hoover 310.15 K, heavy atom restraints)
3. **NPT** (100 ps restrained + 500 ps free, Parrinello-Rahman 1.0 bar)

### WP3: Production MD
```bash
bash 03_production.sh -nb auto 100
```
- Unrestrained NPT, 100 ns (adjustable)
- Compressed trajectory (.xtc) every 10 ps
- Checkpoints every 15 min

### WP4: Analysis
```bash
bash 04_analysis.sh prod 0
python3 05_visualization.py ../analysis
```
- RMSD, RMSF, Rg, H-bonds, SASA
- PCA + Free Energy Landscape (conformational switching)
- Clustering (representative structures)

---

## ⚙️ Force Field & Parameters

| Parameter | Value | Reference |
|-----------|-------|-----------|
| Force field | AMBER99bsc1 | Zgarbová et al. *JCTC* 2011 |
| Water model | TIP3P | Jorgensen et al. *JCP* 1983 |
| Temperature | 310.15 K (Nosé-Hoover) | Physiological |
| Pressure | 1.0 bar (Parrinello-Rahman) | Ambient |
| Timestep | 2 fs (LINCS H-bonds) | Standard |
| PME | 4th order, 0.12 nm spacing | Long-range electrostatics |
| Cutoff | 1.0 nm | VDW + Coulomb |
| Box | Dodecahedral (1.2 nm padding) | Minimal volume |

---

## 📊 Taiwania 3 SLURM Configuration

### ✅ VERIFIED Environment (live sessions 2026-08-31 & 2026-09-03)
| Item | Value |
|---|---|
| SSH host | `twnia3.nchc.org.tw` (2FA mandatory — app OTP) |
| Username / Account | `u5662994` / `mst115368` |
| **MD partition** | `ct56` — 56 cores, **754 GB RAM**, 4-day max |
| Other partitions | `ct224` `ct560` `ct2k` `ct8k` (larger), `ctest` (default, 2 h) |
| Compute node | Xeon 8280-class, 56 cores, Gres = none |
| Modules | `gcc/13.2.0` — **NO cuda / cmake / openmpi / fftw modules exist** |
| GPUs | `ngs*` Tesla 8/node (genomics service, restricted); `gpu-amd` A100 (DOWN) |
| GROMACS | conda-forge **2024.4 CPU** from env `na53_aptamer` (no compile needed) |
| Storage | `/home` + `/work` on GPFS |

> **GPU is not viable on this cluster** (partitions restricted/down, no CUDA
> module) → all jobs are CPU on `ct56`. Expected throughput for the 55-nt
> aptamer system (~35–45k atoms): **~40–70 ns/day on 56 threads** → 100 ns
> production fits within the 4-day `ct56` limit; restart via checkpoint
> (`RESTART=1 sbatch 03_prod.sbatch`) if a job hits the wall.

---

## 🔧 Installation (First Time on Taiwania 3)

```bash
# ONE command does it all — conda env (WITH gromacs engine) + dirs:
bash slurm/setup_taiwania3.sh https://github.com/YOUR_USERNAME/GROMACS_NA53.git
conda activate na53_aptamer
gmx --version    # should print GROMACS 2024.4

# Manual equivalent:
bash scripts/install_dependencies.sh

# NOT needed on Taiwania 3: install_gromacs_gpu.sh compiles from source and is
# kept for GPU-equipped clusters / your local GTX machine only.
```

---

## 📈 Key Analysis Outputs

| File | What it Shows | Biosensing Relevance |
|------|---------------|---------------------|
| `rmsd.xvg` | Structural convergence | Confirms stable fold |
| `rmsf.xvg` | Per-residue flexibility | Identifies flexible binding loops |
| `gyrate.xvg` | Compactness | Folded vs. unfolded state |
| `hbnum.xvg` | H-bond count | Base-pairing stability |
| `proj.xvg` | PCA projection | Conformational landscape |
| `clusters.xvg` | Cluster analysis | Dominant binding-competent conformations |
| `fel_2d.png` | Free energy landscape | Folding funnel topology |

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| `pdb2gmx` fails on NA53 | Ensure PDB uses DA/DT/DG/DC (not A/T/G/C) |
| EM not converging | Reduce `emstep` to 0.001 in em.mdp |
| NVT temp drift | Increase `tau-t` to 2.0 in nvt.mdp |
| NPT density unstable | Extend NPT to 1000 ps |
| Production crashes | Restart: `gmx mdrun -deffnm prod -cpi prod.cpt` |
| SLURM job rejected | Check `--account=mst115368` and `--partition=ct56` match your association (`sacctmgr show assoc user=$USER`) |
| SSH: `[FAIL] The account doesn't exist` | OTP device not registered — iService → 會員資訊 → 主機帳號資訊 → 建立OTP載具 |
| `gmx: command not found` | `conda activate na53_aptamer` (GROMACS ships in the conda env on Taiwania 3) |
| `Fatal error: GPU ...` | You're on a CPU-only node/build — use `-nb auto`, never `-nb gpu` |
| Job killed at walltime | Normal for `ct56` (4-day). Re-submit: `cd slurm && RESTART=1 sbatch 03_prod.sbatch` (continues from `prod.cpt`) |

---

## 📚 References

| # | Citation |
|---|----------|
| 1 | E2EDNA: Kilgour et al. *JCIM* 2021, 61, 4139 |
| 2 | AMBER99bsc1: Zgarbová et al. *JCTC* 2011, 7, 2886 |
| 3 | Aptamer–ligand MD: Rodríguez Serrano et al. *JCISD* 2022, 62, 4799 |
| 4 | Aptamer truncation: Díaz-Fernández et al. *ChemRxiv* 2025 |
| 5 | GROMACS: Abraham et al. *SoftwareX* 2015, 1–2, 19 |
| 6 | CHAPERONg: Yekeen et al. *GigaScience* 2023 |

---

*Generated: 2026-09-03 | Project: GROMACS_NA53 | Target: NGAL Biosensing*
