# GROMACS_NA53 — Project Memory (living document)

| Field | Value |
|---|---|
| **Status** | Active |
| **Last updated** | 2026-09-04 |
| **Current phase** | Phase 4/5 — local 1 ns end-to-end trial PASSED; commit+push pending |

> **Purpose:** the single source of truth for *what has been done, what is being
> worked on, and what comes next*. Any AI resuming this project must read this
> file first. Update it at the end of every work session.

---

## 1. Project State (TL;DR)

- ✅ Phases 0–3 complete: research, design decisions, trial-run analysis, and a
  fully scaffolded pipeline (scripts 00–05, MDP configs, SLURM jobs, conda env, CI).
- ✅ **2026-09-04: local 1 ns end-to-end trial PASSED** through the launcher
  (`local_gpu` profile, GTX 1650 Ti, substitute 1BNA PDB): prep → EM → NVT →
  NPT → 1 ns prod (~5 min) → all 8 analyses → 8 figures. Zero warnings.
- 🔵 Phase 4 (Taiwania 3 setup) scripted + mostly verified live; env install
  still needs one run on the cluster.
- ⬜ **Phase 5**: obtain the real `structures/NA53_initial.pdb` (NA53 sequence).
- ⏸ Nothing blocked; trial-driven bug fixes below are staged for commit.

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
| 2026-09-04 | Imported the Research SOP (deep-search workflow) from the AI_setup env: spec, report template, references ledger, run log, helper scripts, and 2 seed reports (incl. founding NA53 litreview w/ Taiwania reconciliation banner) | research/ |
| 2026-09-04 | Deep-analyzed the AI_setup folder; critical finding F1: its NCHC §4–§5 are Taiwania-2 (GPU) — this repo's slurm/configs are the verified Taiwania-3 truth | AI_setup/docs/DEEP_ANALYSIS.md |
| 2026-09-04 | GPU platform research: **TWCC offline 2026-08-31**; T2 now commercial TWAI; recommend T3-GPU via iService (A100) as primary | docs/HPC_GPU_OPTIONS.md |
| 2026-09-04 | Fixed chain-breaking bugs: 02_equil ionized lookup, 03_prod/04_analysis artifact mismatch (`../production` vs `scripts/`) → workspace standardized on `scripts/` | slurm/02,03,04 + scripts/run_pipeline.sh |
| 2026-09-04 | Added profile system + clone-and-run launcher + remote monitoring | profiles/, run_simulation.sh |
| 2026-09-04 | **Local 1 ns trial run exposed config-level bugs → fixed:** ions.mdp kept PME for the pre-neutralization grompp (net charge −22 → fatal); `POSRES_BB` macro never defined by pdb2gmx (→ unused-macro fatal) so NPT1 used plain `POSRES`; missing `refcoord_scaling = com` (PR + posres fatal); MDPs drifted from the locked standard (rcoulomb/rvdw 1.0 vs 0.8 nm, missing shift-Verlet) → unified all stages to the validated 0.8 nm pattern | configs/ions.mdp, nvt.mdp, npt.mdp, npt_free.mdp, prod.mdp |
| 2026-09-04 | **Trial run, 2nd wave — production & analysis bugs → fixed:** `-gpu-id` invalid in mdrun 2021+ (→ `-gpu_id`); prod mdrun was backgrounded w/o wait → died on shell exit → foreground (all stages consistent); analysis group indices targeted group 4 = **Water** → group 1 = **DNA** for RMSD/RMSF/covar/anaeig/cluster; hbond rewritten in GROMACS 2024+ (stdin piping dead, `-life`/`-ghost` removed) → modern `-r 'group DNA' -t 'group DNA'` selections; sasa duplicate `-o` → `-o` + `-or`; covar `-lpc` removed (2025.3); anaeig needs 2 stdin answers (fit + eigenvector group); cluster `-o` requires `.xpm`; STATUS_FILE/JOBS_DIR anchored to repo root (was split across logs/ + scripts/logs/) | scripts/03_production.sh, scripts/04_analysis.sh, run_simulation.sh |
| 2026-09-04 | **End-to-end trial re-run PASSED** (post-fix): 0 ⚠️, DNA H-bonds 30–38 (~30 WC bonds for 12 bp — sanity ✓), 1 ns in ~5 min GPU | analysis/, results/figures/ (gitignored, kept locally) |
| 2026-09-04 | **From-scratch clone-and-run test** (`NA53_1ns_trial_from scratch/`, fresh `git clone` from GitHub = server mimic): **2 packaging bugs caught** — (a) all files committed mode 100644 so `./run_simulation.sh` → Permission denied on a real Linux clone (fixed via `git update-index --chmod=+x`, commit 95eb74b, verified 755 materializes on clone); (b) `.gitignore` globs `em.*`/`nvt.*`/`npt*.*` (meant for grompp/mdrun OUTPUTS) silently swallowed the **stage MDP configs** → fresh clone lacked em/nvt/npt/npt_free.mdp and equil died at EM grompp (`../configs/em.mdp does not exist`) (fixed with `!em.mdp` etc. negations, commit aadddb9). After fixes the clone ran prep→equil→1 ns prod→analysis→8 figures with 0 ⚠️ | commits 95eb74b, aadddb9 |

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

### 3.5 Research SOP (imported 2026-09-04)
| File | Status | Notes |
|---|---|---|
| `research/README.md` | ✅ | SOP index |
| `research/WORKFLOW.md` | ✅ | adapted paths (`research/scripts/`, `research/deepsearch.log`) |
| `research/REPORT-TEMPLATE.md` | ✅ | verbatim |
| `research/REFERENCES.md` | ✅ | provenance note added |
| `research/deepsearch.log` | ✅ | 5 historical runs (2026-09-03); tracked via gitignore negation |
| `research/scripts/s2_search.py` | ✅ | paths adapted; stdlib-only, keyless |
| `research/scripts/log_run.py` | ✅ | now appends to `research/deepsearch.log` |
| `research/reports/2026-09-03-ngal-na53-gromacs-litreview.md` | ✅ | **founding review** + F1/F2 reconciliation banner |
| `research/reports/2026-09-03-aptamer-biosensor-deepsearch.md` | ✅ | toolchain survey |

### 3.6 Launcher & profiles (added 2026-09-04)
| File | Status | Notes |
|---|---|---|
| `run_simulation.sh` | ✅ | profile detect, start (interactive chain + gates), submit (generates jobs, afterok chain), status, monitor (local + SSH); `--dry-run` tested |
| `profiles/README.md` | ✅ | variable contract + auto-detect table |
| `profiles/taiwania3_cpu.env` | ✅ | VERIFIED ct56/mst115368/conda env |
| `profiles/taiwania3_gpu.env` | ⚠️ template | PARTITION/GRES/ENV_SETUP = CHANGE_ME; engine must be CUDA-enabled (conda gmx is CPU-only) |
| `profiles/taiwania2_twai_gpu.env` | ⚠️ template | TWAI (T2 commercial V100) |
| `profiles/local_gpu.env` | ✅ | GTX 1650 Ti, full offload, PROD_NS=20 dev default |
| `docs/HPC_GPU_OPTIONS.md` | ✅ | platform evidence + §5 on-node checklist |

### 3.7 Currently being worked on
- **Session complete.** Clone-and-run test in
  `../NA53_1ns_trial_from scratch/` (sibling dir, outside repo) passed after
  the two packaging fixes; nothing mid-edit in the repo.
- Next: Phase 4 (cluster setup run) and Phase 5 (real NA53 PDB).

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
| Local engine (verified 09-04) | gmx 2025.3 GPU build at `~/gromacs-2025.3/build/bin` | trial runs |
| Local GPU mdrun flags | `-nb gpu -pme gpu -bonded gpu -update gpu -gpu_id 0` — **`-gpu_id`** (underscore), not `-gpu-id` | `gmx mdrun -h` on 2025.3 |
| Local measured rate | 1 ns in ~5 min on GTX 1650 Ti (~66k atoms system) | trial log 09-04 |
| pdb2gmx index layout (DNA+NaCl+water) | 0 System, **1 DNA**, 2 NA, 3 CL, 4 Water, 5 SOL, 6 non-Water, 7 Ion | `gmx make_ndx` on trial tpr |
| gmx hbond (2024+) | selections via `-r`/`-t` CLI; `-life`/`-ghost`/stdin-piping gone | `gmx hbond -h` 2025.3 |

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
| D8 | 09-04 | Stage artifacts colocate in `scripts/` (both interactive + SLURM) | kills the `../production` vs `scripts/` chain mismatch | yes (bigger refactor later) |
| D9 | 09-04 | GPU strategy: request T3-GPU via iService first; TWAI T2 fallback; TWCC dead | TWCC shutdown 2026-08-31; T3 = same account/infra | yes |

---

## 6. Next Actions (priority order)

1. **User/Agent:** run Phase 4 on Taiwania 3: `bash slurm/setup_taiwania3.sh
   <repo-url>`, `conda activate na53_aptamer`, `gmx --version` → expect 2024.4,
   then `./run_simulation.sh submit --profile taiwania3_cpu`. (Clone-and-run is
   verified end-to-end locally — no packaging surprises expected.)
2. **User:** request GPU access on T3 via iService (see docs/HPC_GPU_OPTIONS.md);
   when granted, run the §5 checklist and paste back → fill `taiwania3_gpu.env`.
3. **Agent (Phase 5):** generate `structures/NA53_initial.pdb` via AptaFold or
   w3DNA; validate with `bash scripts/00_predict_structure.sh`.
4. **Agent (Phase 6+):** submit the chain and gate each stage
   (`./run_simulation.sh status` between jobs).
5. **Agent:** after each stage, update this file's §2/§3/§6.
6. **Agent:** next research task goes through `research/WORKFLOW.md` (new report
   in `research/reports/`, sources in `REFERENCES.md`, one line in
   `research/deepsearch.log`).

---

## 7. Open Questions / Risks

| # | Question | Owner | Blocking? |
|---|---|---|---|
| Q1 | Will AptaFold run on Taiwania 3 CPU-only, or do we use w3DNA web? | agent | Phase 5 |
| Q2 | Storage quota on /work for 100+ ns trajectory (est. few GB .xtc)? | user/agent | Phase 8 |
| Q3 | Is 100 ns enough for convergence, or extend to 300–500 ns? | agent (Phase 9 data) | Phase 8 |
| Q4 | INF/DSSR analysis worth installing for publication? | user | Phase 9 |
| Q5 | Cluster rep structures → docking (AutoDock/HADDOCK)? | user | Phase 10 |
| Q6 | Will NCHC grant/rent GPU to mst115368 on T3 (gpu-amd A100)? | user | Phase 3/4 |

---

## 8. Session Handoff Protocol

When a session ends (human or AI):
1. Move completed items to §2 with date.
2. Update §3 statuses (what changed, what is mid-edit).
3. Update §6 next actions to match reality.
4. Append any new decisions to §5.
5. Leave §1 TL;DR accurate.