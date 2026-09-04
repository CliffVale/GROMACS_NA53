# 🧬 GROMACS_NA53
### In silico 3D folding of the NA53 DNA aptamer for NGAL biosensing — a complete, documented GROMACS pipeline

| Project at a glance | |
|---|---|
| **The science** | Predict how the **NA53 aptamer** (55-nt DNA) folds in 3D, so it can be used in a biosensor for **NGAL** (a kidney-injury biomarker) |
| **The method** | Molecular dynamics (MD) simulation with **GROMACS** — build the system, equilibrate it, simulate ≥100 ns, analyze the folding |
| **The hardware** | Workstation GPU for tests · **Taiwania 3** (NCHC supercomputer, Taiwan) for real runs |
| **The guarantee** | Every parameter is verified and documented; automated checks (CI + `doctor`) catch mistakes before they waste compute |

> ### 🎓 New here?
> - **[`docs/BEGINNER_GUIDE.md`](docs/BEGINNER_GUIDE.md)** — *From "what is an
>   aptamer?" to a finished simulation*: the full pipeline explained stage by
>   stage, with zero assumed knowledge. **Start here if you've never run MD.**
> - **[`docs/GLOSSARY.md`](docs/GLOSSARY.md)** — every technical term in plain
>   language (force field? NPT? RMSD? PME? …).
> - Otherwise keep reading — this page is the front door to everything.

---

## 📋 1. What is this project? (30 seconds)

**NA53** is a 55-nucleotide single-stranded DNA aptamer
(`AGCAGCACAGAGGTCAGATGGCGCTGGATAGCAAGATCACGTTATCATCGTAAACCCTATGCGTGCTACCGTGAA`)
that binds **NGAL** — a protein that appears in body fluids early during kidney
injury. A sensor that catches NGAL with NA53 could detect kidney damage early.

But to build that sensor you must know NA53's **folded 3D shape**, and that
shape is hard to measure experimentally. So this project simulates it:

> **Sequence → 3D model → DNA in a water box with salt → relax the system
> (equilibration) → run a long physics "movie" (production) → measure the
> folding (analysis) → plots (visualization).**

The whole flow is automated in numbered scripts (`scripts/00–05`), each with a
strict input→output contract, plus a launcher (`run_simulation.sh`) that runs
and monitors everything on any machine — your workstation or the supercomputer.

---

## 🔄 2. The pipeline at a glance

```
00 PREDICT    →  01 PREP     →  02 EQUILIBRATE  →  03 PRODUCE  →  04/05 ANALYZE
sequence      →  3D .pdb     →  water box +     →  stable      →  long movie
(known)       →  (required   →  ions, ready to     system         → numbers +
                  input)         move           (EM→NVT→NPT)      figures
```

| WP | Script | Job | Key outputs |
|---|---|---|---|
| **00** | `00_predict_structure.sh` | Predict secondary structure from the NA53 sequence (seqfold/RNAfold). Refuses to fabricate a 3D model. | `structures/NA53.fasta`, `*.dbn`, `*.pairs.txt` |
| **01** | `01_system_prep.sh` | `pdb2gmx` (topology) → `editconf` (box) → `solvate` (water) → `genion` (0.15 M NaCl, neutral) | `topol.top`, `*_ionized.gro` |
| **02** | `02_equilibration.sh` | Energy minimization → NVT (100 ps) → NPT restrained (100 ps) → NPT free (500 ps) | `em.gro`, `nvt.gro`, `npt1.gro`, `npt2.gro` |
| **03** | `03_production.sh` | Unrestrained NPT at 310.15 K, 1 bar; checkpoints every 15 min | `prod.{tpr,xtc,edr,cpt,log}` |
| **04** | `04_analysis.sh` | RMSD, RMSF, Rg, H-bonds, SASA, PCA, clustering, free-energy landscape | `analysis/*.xvg` |
| **05** | `05_visualization.py` | Publication-quality figures | `results/figures/*.png` |

Each stage is a **file gate**: it refuses to run without its required input, and
fails loudly instead of silently producing garbage. Rough time budgets for a
55-nt system: predict ~1 h (mostly human) · prep ~5 min · equil ~2 h · prod
**~40–70 ns/day** on Taiwania 3 CPU (100 ns fits the 4-day queue) · analysis ~1 h.

---

## 🚀 3. Quick start

### A. Try it on your own GPU workstation (1 ns smoke test)

```bash
git clone https://github.com/CliffVale/GROMACS_NA53.git && cd GROMACS_NA53
bash scripts/install_dependencies.sh          # one-time: conda env + GROMACS
./run_simulation.sh profile --set local_gpu   # or: profiles/local_gpu.env
./run_simulation.sh doctor                    # 🩺 pre-flight — mandatory
./run_simulation.sh start --ns 1 --stage all  # prep → equil → 1 ns prod → analysis
./run_simulation.sh status                    # one-screen health report
```

> Needs a real 3D structure at `structures/NA53_initial.pdb` (see ⚠️ box in
> §8). Until the genuine NA53 model exists, use a stand-in duplex (PDB `1BNA`)
> — the machinery is proven end-to-end; only the structure is missing.

### B. Real run on Taiwania 3 (HPC)

```bash
ssh u5662994@twnia3.nchc.org.tw              # 2FA (app OTP, method 1)
git clone https://github.com/CliffVale/GROMACS_NA53.git && cd GROMACS_NA53
bash slurm/setup_taiwania3.sh https://github.com/CliffVale/GROMACS_NA53.git
conda activate na53_aptamer                  # gmx 2024.4 ships in this env
./run_simulation.sh profile --set taiwania3_cpu   # ✅ verified profile
./run_simulation.sh doctor                    # 🩺 pre-flight on the cluster
./run_simulation.sh submit                    # sbatch 01→04 with afterok deps
./run_simulation.sh status                    # squeue + health + log tail
./run_simulation.sh monitor                   # live follow (from your machine)
```

**If a job dies at the wall-time:** `cd slurm && RESTART=1 sbatch 03_prod.sbatch`
— it resumes from the 15-min checkpoint, so a kill costs ≤15 minutes.

---

## 📁 4. Repository structure (annotated)

```
GROMACS_NA53/
├── PRD.md · architecture.md · rules.md · phases.md · design.md · memory.md
│     └─ the 6 "living records" — see §6
├── run_simulation.sh         ⭐ launcher: profile / doctor / start / submit / status / monitor
├── environment.yml           exact conda software list (gromacs 2024.4 CPU, py3.10)
├── .github/workflows/        CI — syntax + repo-integrity checks on every push
├── configs/                  one settings file (.mdp) per stage — ✅-annotated, validated
├── scripts/                  00–05 pipeline + doctor/health/integrity tooling
├── slurm/                    Taiwania 3 job scripts (01_prep … 04_analysis.sbatch)
├── profiles/                 machine settings (local_gpu · taiwania3_cpu ✅ · gpu templates)
├── structures/               ⭐ the 3D input .pdb goes here (the one missing ingredient)
├── system/ · equilibration/ · production/ · analysis/ · results/figures/ · logs/
│     └─ pipeline outputs (working files live in scripts/; logs/run_status.txt is the trail)
├── docs/                     01–06 management docs · INCIDENT_ANALYSIS · HPC_GPU_OPTIONS
│     · BEGINNER_GUIDE.md (🎓) · GLOSSARY.md (📖) · REFERENCES.md (master source register)
├── research/                 the literature wing: SOP, reports, reference ledger, s2_search
└── templates/                reusable parameter templates
```

---

## 🧠 5. Science parameters (all verified — ✅ in `configs/*.mdp`)

| Parameter | Value | Note |
|---|---|---|
| Force field | `amber99sb-ildn` (DNA) + `tip3p` (water) | defaults used by `01_system_prep.sh`; **parmbsc1** upgrade under evaluation (§8) |
| Temperature | 310.15 K — V-rescale thermostat | physiological; ✅ validated |
| Pressure | 1.0 bar — Parrinello–Rahman | ✅ validated (NPT + production) |
| Time step | 2 fs (LINCS-constrained H-bonds) | standard |
| Cutoffs | **0.8 nm** (rvdw = rcoulomb), Verlet scheme | ✅ validated in a 200 ns control run — *not* the 1.0 nm of older drafts |
| vdW / electrostatics | `Potential-shift-Verlet` + DispCorr + **PME** (order 4, spacing 0.12 nm) | required for AMBER-family FFs in GROMACS |
| Box | dodecahedron, 1.2 nm padding, PBC | minimal water volume |
| Salt | 0.15 M NaCl, charge-neutral | physiological |
| Restraints | `-DPOSRES` during NVT + NPT₁ (released in NPT₂) | gentle warm-up |
| Production | NPT, trajectory every 10 ps, checkpoint every 15 min | target ≥100 ns |

> **Why some older files say 1.0 nm / Nosé–Hoover:** early drafts. The *running*
> configs are the ✅-marked 0.8 nm / V-rescale values above; `docs/INCIDENT_ANALYSIS.md`
> (class P) explains how that drift happened and how CI + `doctor` now prevent it.

---

## 📌 6. The "living records" (AI & human continuation layer)

This repo is engineered so any agent (human or AI) can continue it flawlessly.
Six records live at the root — **read them in this order**:

| File | What it answers |
|---|---|
| [`PRD.md`](PRD.md) | What we're building, target users, features (F-01…F-16), KPIs |
| [`architecture.md`](architecture.md) | Data flow, folder/file structure, tech stack, execution modes |
| [`rules.md`](rules.md) | What to use/avoid, error handling, **AI boundaries** (no fabrication, etc.) |
| [`phases.md`](phases.md) | Phase plan P0–P11 (deepsearch → brainstorm → analyse → execute) |
| [`design.md`](design.md) | Theme, palette, typography, figure specs |
| [`memory.md`](memory.md) | ✅ what's completed · 🚧 in progress · ⏭ next actions · verified facts |

> ⚠️ **The contract** (full text in `rules.md`): never fabricate data, URLs, or
> cluster facts. Every parameter is verified somewhere in `docs/` or
> `memory.md`. If something is unverified, say so and run the command that
> would verify it.

Literature work follows the **Research SOP** in [`research/`](research/README.md)
(frame → search → verify → synthesize → log) — see its `WORKFLOW.md`,
`reports/`, and the audited `REFERENCES.md`.

---

## 📊 7. Verified Taiwania 3 environment (live SSH sessions)

| Item | Value |
|---|---|
| SSH / 2FA | `twnia3.nchc.org.tw` — app OTP (method 1) |
| User / account | `u5662994` / `mst115368` |
| **MD partition** | `ct56` — 56 cores, ~754 GB RAM, 4-day limit |
| Larger partitions | `ct224` `ct560` `ct2k` `ct8k` |
| GROMACS | conda-forge **2024.4 CPU** from env `na53_aptamer` (no compile needed) |
| GPU reality | `ngs*` = restricted genomics service; `gpu-amd` down; **no CUDA module** → CPU jobs on `ct56` (expected ~40–70 ns/day) |
| Storage | `/home` + `/work` (GPFS); check with `hfs-quota` |

> **GPU path:** TWCC is offline; Taiwania 3 GPU partitions or TWAI (Taiwania 2)
> are the researched options — see [`docs/HPC_GPU_OPTIONS.md`](docs/HPC_GPU_OPTIONS.md)
> and fill the `profiles/*gpu*.env` templates. The code is GPU-ready (`-nb auto`).

---

## 🩺 8. Quality assurance + the one missing ingredient

| Guard | What it does | Run when |
|---|---|---|
| **`doctor`** | Static repo checks **+ live probes** of the installed GROMACS (verifies every CLI flag the pipeline uses — GROMACS versions silently change syntax) | `./run_simulation.sh doctor` before **every** run, on **every** machine |
| **CI** | Same static checks (file inventory vs `.gitignore`, exec bits, MDP consistency, syntax) on GitHub | automatically, every push |
| **File gates** | Each stage refuses to start without its required input | every run |
| **Checkpoints** | `prod.cpt` every 15 min → `RESTART=1` resumes after any kill | every production run |

Every bug ever found (version drift, physics drift, shell fragility, wrong
group indices, packaging) is classified with its prevention in
**[`docs/INCIDENT_ANALYSIS.md`](docs/INCIDENT_ANALYSIS.md)** and
[`docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md`](docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md).

> ⚠️ **The one missing ingredient:** the genuine 3D model of NA53 at
> `structures/NA53_initial.pdb`. Everything else is built, tested, and CI-protected.
> Candidate model sources (researched, with caveats): **AlphaFold 3** (handles
> G-quadruplex/pseudoknot topologies), w3DNA / 3dDNA (B-form builders), or an
> experimental structure — see `docs/REFERENCES.md` and the research reports.

---

## 🔧 9. Troubleshooting (top rows)

| Problem | Solution |
|---|---|
| `gmx: command not found` | `conda activate na53_aptamer` (GROMACS ships in the env) |
| Job killed at wall-time | Normal for `ct56` (4-day). `cd slurm && RESTART=1 sbatch 03_prod.sbatch` (resumes from `prod.cpt`) |
| `Fatal error: GPU…` | You're on CPU — use `-nb auto`, never `-nb gpu` |
| `pdb2gmx` fails on your PDB | Residue names must be DNA (DA/DT/DG/DC), not protein (A/T/G/C) |
| EM not converging | `emtol`/`emstep` live in `configs/em.mdp` (defaults: 1000 kJ/mol/nm, 0.01 nm) — lower `emstep` to 0.001 for stubborn cases |
| NVT temperature drifting | Check `ref-t` (310.15 K) and `tc-grps` (DNA + Water_and_ions) in `configs/nvt.mdp`; the validated `tau-t` 0.1 ps is locked — first rerun EM if contacts were bad, then extend NVT |
| NPT density unstable | Extend NPT — raise `nsteps` in `configs/npt.mdp` / `npt_free.mdp` (validated schedule: 100 ps restrained + 500 ps free) |
| Production crashes mid-run | Manual resume: `gmx mdrun -deffnm prod -cpi prod.cpt` · SLURM resume: `RESTART=1 sbatch slurm/03_prod.sbatch` |
| `doctor` flags something | Read its message; each check names the exact file/flag to fix |
| SLURM job rejected | `sacctmgr show assoc user=$USER` → match account/partition in `slurm/*.sbatch` |
| SSH "account doesn't exist" | Register your OTP device via iService (會員資訊 → 主機帳號資訊 → 建立OTP載具) |

> More help: [`docs/INCIDENT_ANALYSIS.md`](docs/INCIDENT_ANALYSIS.md) (every bug
> class + prevention), [`docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md`](docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md),
> and each stage's own log in `logs/` (start with the last 30 lines).

---

## 📚 10. Key references

> Full audited register (URLs, usage, verification status for **every** source):
> **[`docs/REFERENCES.md`](docs/REFERENCES.md)** — read that one for citations.

| # | Paper | Used for |
|---|---|---|
| 1 | E2EDNA — Kilgour et al., *JCIM* 2021, 61, 4139 | end-to-end aptamer simulation protocol |
| 2 | bsc0 — Zgarbová *JCTC* 2011 (DOI 10.1021/ct200326x) · bsc1 — Ivani *Nat Methods* 2016 (DOI 10.1038/nmeth.3658) | DNA force-field backbone corrections |
| 3 | Rodríguez Serrano et al., *JCISD* 2022, 62, 4799 | aptamer–small-molecule interaction MD |
| 4 | Díaz-Fernández et al., *ChemRxiv* 2025 (DOI 10.26434/chemrxiv-2025-k5mzk) | aptamer truncation via MD |
| 5 | Abraham et al., *SoftwareX* 2015 | GROMACS |
| 6 | CHAPERONg — Yekeen et al., *Comput Struct Biotechnol J* 2023 (DOI 10.1016/j.csbj.2023.09.024) | automated GROMACS analysis |

**Open research reports** (evidence-graded): NA53/NGAL founding review,
aptamer-in-silico toolchain survey, and the 67-reference bibliography analysis
(force-field & structure-prediction recommendations) — all in
[`research/reports/`](research/reports/).

---

*Generated 2026-09-03 · Rewritten beginner-first 2026-09-04 · Project:
GROMACS_NA53 · Target: NGAL biosensing. All values verified — see `memory.md`
and the ✅ comments in `configs/*.mdp`.*
