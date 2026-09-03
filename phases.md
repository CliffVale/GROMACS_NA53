# GROMACS_NA53 — Development Phases & Execution Plan

| Field | Value |
|---|---|
| **Status** | Phase 3 complete; Phase 5 is next |
| **Last updated** | 2026-09-03 |

> Each phase follows: **deepsearch → brainstorm → deepanalyse → plan → execute → verify**.
> No phase is "done" until its acceptance criteria pass. Statuses: ✅ done, 🔵 in
> progress, ⬜ pending, ⏸ blocked.

---

## Phase Map (summary)

| Phase | Name | Status | Key deliverable |
|---|---|---|---|
| 0 | Research & Deepsearch | ✅ | docs/APTAMD_DEEP_ANALYSIS.md + lit review |
| 1 | Brainstorm & Feasibility | ✅ | GROMACS-over-AMBER decision, hybrid protocol |
| 2 | Deep Analysis of prior runs | ✅ | docs/LESSONS_LEARNED + hallucination audit |
| 3 | Project Scaffolding & AI records | ✅ | this repo: 6 AI records + scripts + configs |
| 4 | Environment & HPC Deployment | 🔵 | conda env on Taiwania 3 (setup script ready) |
| 5 | Starting Structure Generation | ⬜ **next** | real all-atom NA53_initial.pdb |
| 6 | System Preparation | ⬜ | ionized.gro + topol.top |
| 7 | Equilibration & Validation | ⬜ | npt2.gro passing all KPIs |
| 8 | Production MD | ⬜ | 100 ns prod.xtc (+extensions) |
| 9 | Analysis & Visualization | ⬜ | 7 metrics + figures |
| 10 | Binding Studies (extension) | ⬜ | MM-PBSA / docking (optional) |
| 11 | Publication & Reproducibility | ⬜ | thesis-grade write-up + Zenodo |

---

## Phase 0 — Research & Deepsearch ✅

**Objective:** Ground the protocol in the aptamer-MD literature before writing code.

| Task | Done |
|---|---|
| Deepsearch APTAMD & APTAMD_TUTORIALS repos (Díaz-Fernández/Suárez) | ✅ |
| Compare APTAMD (AMBER, GaMD) vs GROMACS approach | ✅ |
| Survey aptamer–ligand MD protocols (Rodríguez Serrano 2022, CHAPERONg) | ✅ |
| Capture references (E2EDNA, AMBER99bsc1, GROMACS, truncation) | ✅ |

**Deliverables:** `docs/APTAMD_DEEP_ANALYSIS.md`, README references table.

**Acceptance criteria:**
- ✅ Protocol decision documented (AMBER GaMD is gold-standard but licensed → GROMACS hybrid).
- ✅ RNAComposer identified as RNA-only → rejected for DNA NA53.

---

## Phase 1 — Brainstorm & Feasibility ✅

**Objective:** Choose architecture & stack before coding. Record *why*.

| Decision | Chosen | Rationale |
|---|---|---|
| Engine | GROMACS (free) over AMBER (licensed) | Portability, cost |
| Initial 3D structure | AptaFold / w3DNA / 3dDNA | All-atom DNA; pdb2gmx-compatible |
| Enhanced sampling | Standard cMD first; GaMD revisit later | Scope; cMD suffices for 100 ns target |
| Analysis extras | INF/DSSR flagged as future | APTAMD feature; needs install |
| HPC | Taiwania 3 CPU (ct56) | Account mst115368 verified |

**Deliverables:** decision log in memory.md; scope in PRD §3.

**Acceptance criteria:** ✅ Every choice has a recorded reason.

---

## Phase 2 — Deep Analysis of Prior Runs ✅

**Objective:** Extract every validated parameter and every failure mode from the
1BNA trial runs and Taiwania 3 onboarding transcripts.

| Analysis | Outcome |
|---|---|
| 8 trial runs (GROMACS_TEEP) | 5 critical errors identified (cutoff, restraints, checkpoints, tc-grps, GUI) |
| 200 ns 1BNA production run | 10 validated parameters locked into configs |
| Free-energy / clustering studies | Two-state landscape; analysis scripts proven |
| Taiwania 3 onboarding transcripts | Hallucination audit: partition table, CUDA path, module versions all corrected |

**Deliverables:** `docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md`,
`docs/TRANSCRIPTS_DEEP_ANALYSIS.md`.

**Acceptance criteria:** ✅ Every MDP value in `configs/` traces to these docs.

---

## Phase 3 — Project Scaffolding & AI Records ✅

**Objective:** Make the project self-documenting so any AI (or human) can continue
it flawlessly.

| Task | Done |
|---|---|
| Create 6 AI-reference records (PRD, architecture, rules, phases, design, memory) | ✅ |
| Write stage scripts 00–05 + run_pipeline master | ✅ |
| Write MDP configs (em/nvt/npt/npt_free/prod/ions) with verified params | ✅ |
| Write SLURM jobs (setup + 4 sbatch) for Taiwania 3 | ✅ |
| Write environment.yml, .gitignore, README, CI workflow | ✅ |
| Fix latent bugs found during analysis (fake PDB, conda shadowing, GPU demands) | ✅ |
| Syntax-validate all shell scripts | ✅ |

**Deliverables:** this repository, ready to clone.

**Acceptance criteria:** ✅ `bash -n` passes on all scripts; no `CHANGE_ME_*` left
except intentional sbatch gates; README links all 6 AI records.

---

## Phase 4 — Environment & HPC Deployment 🔵 (mostly done, needs live run)

**Objective:** Stand up the exact runtime on Taiwania 3.

| Task | Status | Est. time |
|---|---|---|
| Push repo to GitHub (user action) | ⬜ | 5 min |
| SSH login (2FA OTP) | ✅ tested | — |
| `bash slurm/setup_taiwania3.sh <repo-url>` | ⬜ | ~10 min |
| `conda activate na53_aptamer && gmx --version` → 2024.4 | ⬜ | 1 min |
| `sbatch --test-only slurm/01_prep.sbatch` (access check) | ⬜ | 1 min |
| Fill any remaining CHANGE_ME values from live sacctmgr/sinfo | ⬜ | 5 min |

**Acceptance criteria:**
- `gmx --version` prints 2024.4 from the conda env.
- `sbatch --test-only` passes (account/partition accepted).
- `/work` scratch strategy decided (docs/05 budget).

**Exit:** nothing here is a guess — every value shown by live commands.

---

## Phase 5 — Starting Structure Generation ⬜ (NEXT)

**Objective:** Produce a real, complete all-atom ssDNA model of NA53.

| Task | Detail |
|---|---|
| Predict secondary structure | seqfold/RNAfold via 00 script |
| Build 3D coordinates | AptaFold (CLI, free) **or** w3DNA web (B-form ssDNA) **or** 3dDNA |
| Save as `structures/NA53_initial.pdb` | Must be DA/DT/DG/DC, ≥30 atoms/nt |
| Validate | 00 script's sanity check (≥10 atoms/residue) |

**Acceptance criteria:**
- ✅ PDB passes the sanity check (no "suspiciously few atoms" warnings).
- ✅ Residue naming is DNA (DA/DT/DG/DC) so pdb2gmx accepts it.
- ✅ pdb2gmx dry-run succeeds (topology generated without error).

**Risk:** AptaFold may need GPU/install — w3DNA web is the zero-install fallback.

---

## Phase 6 — System Preparation ⬜

**Objective:** Solvate + neutralize the aptamer.

| Task | Command |
|---|---|
| Topology | `gmx pdb2gmx -ff amber99sb-ildn -water tip3p -ignh` |
| Box | `gmx editconf -c -d 1.2 -bt dodecahedron` |
| Solvate | `gmx solvate -cs spc216.gro` |
| Ions | `gmx genion -pname NA -nname CL -neutral -conc 0.15` |

**Acceptance criteria:**
- ✅ `topol.top` generated; ✅ `<base>_ionized.gro` exists; ✅ charge neutral.
- ✅ Atom count recorded (~35–45k expected).

---

## Phase 7 — Equilibration & Validation ⬜

**Objective:** Relax the system to 310.15 K / 1 bar without artifacts.

| Stage | MDP | Length | Gate |
|---|---|---|---|
| EM | em.mdp | — | Fmax < 1000 kJ/mol/nm |
| NVT | nvt.mdp | 100 ps | T = 310.15 ± 2 K |
| NPT restrained | npt.mdp | 100 ps | ρ stable |
| NPT free | npt_free.mdp | 500 ps | P ≈ 1.0 bar, ρ ≈ 1000 kg/m³ |

**Acceptance criteria:** the 4-point checklist printed by 02_equilibration.sh all
passes (EM converged, T stable, ρ stable, P stable).

**Human checkpoint:** review `analysis/*.xvg` before production is allowed.

---

## Phase 8 — Production MD ⬜

**Objective:** 100 ns unrestrained NPT; extendable to 300–500 ns.

| Task | Detail |
|---|---|
| Generate tpr | `gmx grompp -f prod.mdp -c npt2.gro` |
| Run | `gmx mdrun -deffnm prod -nb auto -ntomp 56 -cpo prod -cpt 900` (via sbatch) |
| Monitor | `squeue`, mdrun log `Performance` line |
| Walltime resume | `RESTART=1 sbatch slurm/03_prod.sbatch` (from prod.cpt) |
| Expected rate | ≥40 ns/day on 56 cores → 100 ns ≤ 4 days |

**Acceptance criteria:**
- ✅ prod.xtc complete (or resumed to completion); ✅ checkpoints exist;
- ✅ Performance ≥ 40 ns/day; ✅ no NaN/instability in log.

---

## Phase 9 — Analysis & Visualization ⬜

**Objective:** Structural + conformational characterization.

| Metric | Tool | Biosensing meaning |
|---|---|---|
| RMSD | `gmx rms` | fold convergence |
| RMSF | `gmx rmsf` | flexible binding regions |
| Rg | `gmx gyrate` | compactness / folded vs unfolded |
| H-bonds | `gmx hbond` | base-pairing stability |
| SASA | `gmx sasa` | solvent exposure |
| PCA | `gmx covar` + `anaeig` | dominant motions |
| Clustering | `gmx cluster` (gromos) | representative conformers |
| FEL | 2D histogram of PCs | folding funnel |

**Deliverables:** `analysis/*.xvg`, `results/figures/*.png` (design.md styles).

**Acceptance criteria:** all 7 metrics produce sensible plateau/trend plots;
cluster representatives extracted for docking (Phase 10).

---

## Phase 10 — Binding Studies (extension, optional) ⬜

**Objective:** NA53–NGAL complex prediction (biosensing relevance).

| Option | Tool | Status |
|---|---|---|
| Ensemble docking | AutoDock4 / HADDOCK on cluster representatives | research only |
| MM-PBSA binding free energy | gmx_MMPBSA (needs install) | flagged in APTAMD analysis |
| Per-residue decomposition | gmx_MMPBSA | flagged |

**Gate:** only start after Phase 9 convergence is demonstrated. Uses the
validated 1BNA MM-PBSA experience as template (docs/04).

---

## Phase 11 — Publication & Reproducibility ⬜

**Objective:** thesis-grade, citable, rerunnable.

| Task | Detail |
|---|---|
| Full methods write-up | FF/water/box/ions/thermostat/barostat/cutoffs w/ citations |
| Figures | design.md-compliant, 300 dpi, colorblind-safe |
| Zenodo DOI | via GitHub release (ZENODO_SETUP pattern from 1BNA study) |
| Data archive | trajectory on /work + backup; analysis artifacts committed |
| Final memory.md close-out | full decision log + reproduction checklist |

---

## Execution Order (dependency-aware)

```
P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → (P10) → P11
                        ↑
              P5 needs a REAL PDB (blocked until user provides/AptaFold runs)
```

**Current standing:** Phases 0–3 complete. Phase 4 pending one live setup run on
Taiwania 3. **Phase 5 is the immediate next action** — obtain
`structures/NA53_initial.pdb`.