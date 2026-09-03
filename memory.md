# GROMACS_NA53 — Project Memory (living document)

| Field | Value |
|---|---|
| **Status** | Active |
| **Last updated** | 2026-09-03 |
| **Current phase** | Phase 4 (Environment) / Phase 5 (Structure) boundary |

> **Purpose:** the single source of truth for *what has been done, what is being
> worked on, and what comes next*. Any AI resuming this project must read this
> file first. Update it at the end of every work session.

---

## 1. Project State (TL;DR)

- ✅ Phases 0–3 complete: research, design decisions, trial-run analysis, and a
  fully scaffolded, syntax-validated pipeline (scripts 00–05, MDP configs,
  SLURM jobs, conda env, CI).
- 🔵 Phase 4 (Taiwania 3 setup) is scripted and **mostly verified live**; the
  env install itself still needs one run on the cluster.
- ⬜ **Phase 5 is next**: obtain `structures/NA53_initial.pdb` — the one file
  the pipeline will not fabricate.
- ⏸ Nothing is blocked; the pipeline is ready to execute once the PDB exists.

---

## 2. Completed Work (session log)

| Date | What was done | Artifacts |
|---|---|---|
| 2026-08-30 | 1BNA trial runs + 200 ns production + analysis (GROMACS_TEEP) | validated parameters source |
| 2026-08-31 | Deepsearch of APTAMD / APTAMD_TUTORIALS | docs/APTAMD_DEEP_ANALYSIS.md |
| 2026-08-31 | Deep analysis of 8 trial runs | docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md |
| 2026-08-31 | Taiwania 3 onboarding transcript analysis + hallucination audit | docs/TRANSCRIPTS_DEEP_ANALYSIS.md |
| 2026-09-02 | Full pipeline scaffold: scripts, configs, slurm, env, README | repo structure |
| 2026-09-03 | **Live Taiwania 3 verification** (sinfo, sacctmgr, module avail, scontrol) | VERIFIED FACTS §4 below |
| 2026-09-03 | Rebuilt all sbatch jobs for CPU conda-GROMACS path | slurm/*.sbatch |
| 2026-09-03 | Fixed latent bugs: fake-PDB fallback, conda gmx shadowing, GPU demands | scripts/00, environment.yml |
| 2026-09-03 | Created AI-reference layer: PRD, architecture, rules, phases, design, memory | root docs (this layer) |

## 3. Files — Current Ownership & Status

### 3.1 AI-reference layer (root) — all complete, maintained here
| File | Status | Notes |
|---|---|---|
| `PRD.md` | ✅ stable | requirements, features F-01..F-16, KPIs |
| `architecture.md` | ✅ stable | data flow, dir tree, tech stack |
| `rules.md` | ✅ stable | golden rules, allowlist/blocklist |
| `phases.md` | ✅ stable | P0–P11 plan; P5 next |
| `design.md` | ✅ stable | palette, typography, figure specs |
| `memory.md` | 🔵 living | this file — update every session |

### 3.2 Scripts (all `bash -n` validated 2026-09-03)
| File | Status | Notes |
|---|---|---|
| `00_predict_structure.sh` | ✅ complete | refuses to fabricate PDB; sanity-checks input |
| `01_system_prep.sh` | ✅ complete | pdb2gmx→editconf→solvate→genion |
| `02_equilibration.sh` | ✅ complete | EM→NVT→NPT(1,2) + validation plots |
| `03_production.sh` | ✅ complete | checkpointed, `-nb auto` default |
| `04_analysis.sh` | ✅ complete | 7-metric analysis suite |
| `05_visualization.py` | ✅ complete | publication figures per design.md |
| `run_pipeline.sh` | ✅ complete | master runner (--stage) |
| `install_dependencies.sh` | ✅ complete | conda env + tools |
| `install_gromacs_gpu.sh` | ✅ complete | **local GPU machines only** |

### 3.3 Configs (verified parameters, do not touch without evidence)
`em.mdp` `nvt.mdp` `npt.mdp` `npt_free.mdp` `prod.mdp` `ions.mdp` — all locked to
LESSONS_LEARNED values (0.8 nm cutoff, V-rescale, PR barostat, etc.).

### 3.4 SLURM (Taiwania 3)
| File | Status | Notes |
|---|---|---|
| `setup_taiwania3.sh` | ✅ ready | clone → conda env → validate gmx |
| `01_prep.sbatch` | ✅ ready | partition=ct56, account=mst115368 |
| `02_equil.sbatch` | ✅ ready | 4 hr walltime |
| `03_prod.sbatch` | ✅ ready | RESTART=1 resume path |
| `04_analysis.sbatch` | ✅ ready | 8 cores |

### 3.5 Currently being worked on
- **Nothing is mid-edit.** Last session closed with all files validated.
- Next edit is expected in **Phase 4** (setup run on cluster) or **Phase 5**
  (adding the PDB + any AptaFold glue).

---

## 4. VERIFIED FACTS (do not overwrite without a live source)

### 4.1 Taiwania 3 (verified live 2026-09-03)
| Fact | Value | Source |
|---|---|---|
| SSH | `u5662994@twnia3.nchc.org.tw`, 2FA app-OTP | live login |
| Account | `mst115368` | `sacctmgr show assoc user=u5662994` |
| MD partition | `ct56` — 56 cores/node, 754 GB RAM, 4-day max | `sinfo -s`, `scontrol show node cpn3001` |
| Other partitions | ct224, ct560, ct2k, ct8k, ctest (2 h default) | `sinfo -s` |
| Modules available | `gcc/13.2.0` and older gcc; **NO** cuda/cmake/openmpi/fftw | `module avail` |
| GPU partitions | `ngs1gpu/ngs*gput` = Tesla 8/node (restricted); `gpu-amd` A100 **down** | `sinfo -p ngs1gput,ngs1gpu,gpu-amd` |
| GROMACS | conda-forge 2024.4 CPU (thread-MPI); no source compile | environment.yml |
| Policy | login node: light work only; 15-min idle logout; no <30 s sinfo loops | motd 2026-08-14 |

### 4.2 Physics parameters (verified in trial runs)
| Parameter | Value | Evidence |
|---|---|---|
| Cutoff (rcoulomb/rvdw) | 0.8 nm | convergence study |
| vdw-modifier | Potential-shift-Verlet | AMBER-compat |
| DispCorr | EnerPres | AMBER-compat |
| T-coupling | V-rescale 310.15 K τ=0.1, 2 groups | trials 04–08 |
| P-coupling | Parrinello-Rahman 1.0 bar τ=2.0 | 200 ns run |
| comm-mode / nstcomm | Linear / 100 | 200 ns run |
| Production restraints | none | trial lesson |
| Checkpoint | `-cpo prod -cpt 900` | disconnect lesson |
| Expected rate (NA53 on ct56) | ~40–70 ns/day (est.) | scaled from 1BNA 257 ns/day |

---

## 5. Decision Log

| # | Date | Decision | Rationale | Reversible? |
|---|---|---|---|---|
| D1 | 08-31 | GROMACS over AMBER | free, portable; AMBER needs license | yes |
| D2 | 08-31 | CPU-only on Taiwania 3 | no CUDA module; GPUs restricted/down | yes (if GPUs appear) |
| D3 | 09-03 | conda GROMACS 2024.4, not source build | no cmake/fftw modules; prebuilt safe | yes |
| D4 | 09-03 | `-nb auto` default everywhere | CPU/GPU safe | yes |
| D5 | 09-03 | No fabrication of PDB; external model required | pdb2gmx needs complete residues | no (hard rule) |
| D6 | 09-03 | Restraints removed from production | froze DNA in trials | yes |
| D7 | 09-03 | 0.8 nm cutoff locked | correct for AMBER FF | yes (w/ evidence) |

---

## 6. Next Actions (priority order)

1. **User:** create GitHub repo `GROMACS_NA53` (or rename existing) and push this
   folder (commands in README §Deployment).
2. **User/Agent:** run Phase 4 on Taiwania 3: `bash slurm/setup_taiwania3.sh
   <repo-url>`, `conda activate na53_aptamer`, `gmx --version` → expect 2024.4.
3. **Agent (Phase 5):** generate `structures/NA53_initial.pdb` via AptaFold or
   w3DNA; validate with `bash scripts/00_predict_structure.sh`.
4. **Agent (Phase 6+):** `sbatch slurm/01_prep.sbatch` → `02_equil` → `03_prod`
   → `04_analysis`, checking gates between stages.
5. **Agent:** after each stage, update this file's §2/§3/§6.

---

## 7. Open Questions / Risks

| # | Question | Owner | Blocking? |
|---|---|---|---|
| Q1 | Will AptaFold run on Taiwania 3 CPU-only, or do we use w3DNA web? | agent | Phase 5 |
| Q2 | Storage quota on /work for 100+ ns trajectory (est. few GB .xtc)? | user/agent | Phase 8 |
| Q3 | Is 100 ns enough for convergence, or extend to 300–500 ns? | agent (Phase 9 data) | Phase 8 |
| Q4 | INF/DSSR analysis worth installing for publication? | user | Phase 9 |
| Q5 | Cluster rep structures → docking (AutoDock/HADDOCK)? | user | Phase 10 |

---

## 8. Session Handoff Protocol

When a session ends (human or AI):
1. Move completed items to §2 with date.
2. Update §3 statuses (what changed, what is mid-edit).
3. Update §6 next actions to match reality.
4. Append any new decisions to §5.
5. Leave §1 TL;DR accurate.