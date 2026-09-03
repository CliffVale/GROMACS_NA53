# GROMACS_NA53 — Architecture

| Field | Value |
|---|---|
| **Status** | Active |
| **Last updated** | 2026-09-03 |

---

## 1. System Overview

GROMACS_NA53 is a **staged shell-pipeline** (bash + Python + GROMACS) orchestrated either interactively or via SLURM on Taiwania 3. Each stage consumes the previous stage's output files and emits strictly named artifacts. The pipeline is **linear with validation gates** — no stage proceeds unless its inputs exist and its sanity checks pass.

```
┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐
│  00        │ → │  01        │ → │  02        │ → │  03        │ → │  04        │
│ PREDICT    │   │ SYSTEM PREP│   │ EQUILIB.   │   │ PRODUCTION │   │ ANALYSIS   │
│ structure  │   │            │   │            │   │            │   │            │
└────────────┘   └────────────┘   └────────────┘   └────────────┘   └────────────┘
 fasta/dbn/pdb   ionized.gro     npt2.gro          prod.xtc        *.xvg + figures
       │              │              │                  │                │
       ▼              ▼              ▼                  ▼                ▼
  structures/     system/         equilibration/     production/      analysis/
                                                                        │
                                                                        ▼
                                                                 05_visualization.py
                                                                   results/figures/
```

## 2. Data Flow & Artifact Contract

| Stage | Input | Output | Gate |
|---|---|---|---|
| **00** predict | sequence (default: NA53) | `structures/NA53.fasta`, `NA53_secondary.dbn`, `NA53_pairs.txt`, `NA53_initial.pdb` | PDB sanity: ≥10 atoms/residue; refuses to fabricate |
| **01** prep | `NA53_initial.pdb` | `<base>_processed.gro`, `topol.top`, `<base>_boxed.gro`, `<base>_solvated.gro`, `<base>_ionized.gro` | topol.top exists; ions added |
| **02** equil | `<base>_ionized.gro` | `em.gro`, `nvt.gro`, `npt1.gro`, `npt2.gro` + `analysis/*.xvg` | Fmax<1000; T=310±2 K; ρ≈1000 kg/m³; P≈1 bar |
| **03** prod | `npt2.gro` | `prod.tpr`, `prod.xtc`, `prod.edr`, `prod.cpt`, `prod.log` | npt2.gro exists; checkpoint every 15 min |
| **04** analysis | `prod.xtc` + `prod.tpr` | `analysis/{rmsd,rmsf,gyrate,hbnum,proj,clusters,sasa}.xvg` | prod.xtc exists |
| **05** viz | `analysis/*.xvg` | `results/figures/*.png` (7+ figures) | xvg files exist |

**File naming**: stage prefixes `em_`, `nvt_`, `npt1_`, `npt2_`, `prod_`; suffix `_ionized.gro` marks the solvated+ionized system.

## 3. Directory Structure

```
GROMACS_NA53/
├── PRD.md                      # ← AI record: requirements
├── architecture.md             # ← AI record: this file
├── rules.md                    # ← AI record: do/don't for agents
├── phases.md                   # ← AI record: phase plan
├── design.md                   # ← AI record: visual identity
├── memory.md                   # ← AI record: live status
├── README.md                   # Public entry point
├── environment.yml             # conda env: gromacs 2024.4 CPU + analysis tools
├── .gitignore                  # excludes .gro/.xtc/.tpr/etc.
├── .github/workflows/validate.yml  # CI: bash -n + py syntax
│
├── docs/                       # Scientific/management documentation
│   ├── 01_PROJECT_CHARTER.md
│   ├── 02_PROJECT_SCOPE_STATEMENT.md
│   ├── 03_WORK_BREAKDOWN_STRUCTURE.md
│   ├── 04_RACI_MATRIX.md
│   ├── 05_BUDGET_TRACKER.md
│   ├── 06_KPI_DASHBOARD.md
│   ├── APTAMD_DEEP_ANALYSIS.md
│   ├── LESSONS_LEARNED_FROM_TRIAL_RUNS.md
│   └── TRANSCRIPTS_DEEP_ANALYSIS.md
│
├── configs/                    # MDP files (verified parameters)
│   ├── em.mdp  nvt.mdp  npt.mdp  npt_free.mdp  prod.mdp  ions.mdp
│
├── scripts/                    # Stage scripts (00–05) + installers + runner
│   ├── 00_predict_structure.sh
│   ├── 01_system_prep.sh
│   ├── 02_equilibration.sh
│   ├── 03_production.sh
│   ├── 04_analysis.sh
│   ├── 05_visualization.py
│   ├── run_pipeline.sh         # master runner (--stage all|prep|equil|prod|analysis)
│   ├── install_dependencies.sh
│   └── install_gromacs_gpu.sh  # OPTIONAL: local GPU machines only
│
├── slurm/                      # Taiwania 3 deployment
│   ├── setup_taiwania3.sh      # first-time: clone, conda env, validate
│   ├── 01_prep.sbatch
│   ├── 02_equil.sbatch
│   ├── 03_prod.sbatch          # RESTART=1 resumes from checkpoint
│   └── 04_analysis.sbatch
│
├── templates/posre.itp         # positional restraints template
├── structures/                 # INPUT PDB (the one file you must provide)
├── system/                     # processed/boxed/solvated/ionized
├── equilibration/              # em/nvt/npt outputs
├── production/                 # prod.* trajectory
├── analysis/                   # *.xvg analysis data
├── results/figures/            # final figures
└── logs/                       # per-stage .log files
```

## 4. Tech Stack

| Layer | Technology | Version | Why |
|---|---|---|---|
| MD engine | GROMACS (conda-forge, CPU, thread-MPI) | 2024.4 | Free; prebuilt; no compile risk on Taiwania 3 |
| Force field | amber99sb-ildn (+ TIP3P water) | — | Validated for DNA aptamers in trial runs |
| Structure tools | seqfold (primary), RNAfold/ViennaRNA (fallback) | — | Secondary structure prediction |
| 3D model source | AptaFold / w3DNA / 3dDNA (external) | — | All-atom ssDNA; pipeline validates, never fabricates |
| Analysis | gmx built-ins (rms, rmsf, gyrate, hbond, cluster, gmx covar/anaeig) | 2024.4 | Native, scripted |
| Python viz | matplotlib, seaborn, numpy, pandas, MDAnalysis | py3.10 | Publication figures |
| Python env mgmt | conda (conda-forge) | env `na53_aptamer` | Pinned & reproducible |
| Scheduler | SLURM (Taiwania 3) | — | sbatch chain, ct56 |
| CI | GitHub Actions | — | syntax validation per push |
| SCM | git + GitHub | — | versioned records & scripts |

## 5. Execution Modes

### 5.1 Interactive (local machine, GTX 1650 Ti optional GPU)
```bash
conda activate na53_aptamer
bash scripts/00_predict_structure.sh
bash scripts/01_system_prep.sh structures/NA53_initial.pdb
bash scripts/02_equilibration.sh system/*_ionized.gro -nb auto
bash scripts/03_production.sh -nb auto 100
bash scripts/04_analysis.sh prod 0
python3 scripts/05_visualization.py analysis
```

### 5.2 SLURM (Taiwania 3, primary) — job chain
```bash
sbatch slurm/01_prep.sbatch   # partition=ct56 account=mst115368
sbatch slurm/02_equil.sbatch  # after 01 completes
sbatch slurm/03_prod.sbatch   # after 02 completes; RESTART=1 to resume
sbatch slurm/04_analysis.sbatch
```

### 5.3 Restart path (walltime kill)
```bash
RESTART=1 sbatch slurm/03_prod.sbatch   # gmx mdrun -cpi prod.cpt
```

## 6. Key Design Decisions (traceable)

| Decision | Choice | Evidence |
|---|---|---|
| Cutoff 0.8 nm (not 1.0) | rcoulomb=rvdw=0.8 | Convergence study in GROMACS_TEEP; AMBER-compatible |
| vdw-modifier = Potential-shift-Verlet, DispCorr=EnerPres | Required for AMBER FFs in GROMACS | Trial runs |
| T-coupling V-rescale, τ=0.1; P-coupling Parrinello-Rahman τ=2.0 | Two tc-grps (DNA, Water_and_ions) | Trials 04–08 |
| comm-mode=Linear, nstcomm=100 | Momentum removal for finite systems | 200 ns run |
| CPU-only on Taiwania 3 | No CUDA module; GPU partitions restricted/down | Live SSH session 2026-09-03 |
| conda GROMACS (not source compile) | No cmake/fftw/openmpi modules → compile risk | module avail output |
| `-nb auto` default | GPU if present, else CPU — safe everywhere | Portability |
| Checkpoint every 15 min | `-cpo prod -cpt 900` | Session-disconnect lessons |

## 7. Reproducibility Controls

- `environment.yml` pins engine + analysis stack (gromacs=2024.4, python=3.10).
- MDP files are static in `configs/`; only `nsteps` is templated at runtime.
- Random seeds: fixed `gen-vel = yes` with deterministic seed in nvt/npt/prod MDPs.
- Version banner: `gmx --version` captured into logs at pipeline start.
- Raw trajectories never committed (`.gitignore`); figures + xvg summaries are the committed artifacts.

## 8. Failure Handling Architecture

- **Fail-fast**: `set -euo pipefail` in every bash script.
- **File gates**: each stage verifies its required input exists (`topol.top`, `npt2.gro`, `prod.xtc`) before acting.
- **Loud unknowns**: sbatch files carry `CHANGE_ME_*` placeholders that force SLURM rejection rather than silent wrong values; setup script validates `sinfo`/`sacctmgr` before use.
- **No fabrication**: `00_predict_structure.sh` exits with instructions instead of writing a fake PDB.
- **Human checkpoints**: equilibration prints an explicit checklist before production is allowed.