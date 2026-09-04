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
| 2026-09-04 | **Postmortem + prevention layer** (docs/INCIDENT_ANALYSIS.md): all incidents classified into 5 root-cause classes — V version drift (6), P physics/config (4), S shell fragility (4), G group-index (1), K packaging (2). Prevention per class: `scripts/check_repo_integrity.sh` (static; runs in **CI on every push**) + `./run_simulation.sh doctor` (static + live gmx-flag/group probes); rules.md golden rules 9–13 + §2.4/§5.7/§7 git rules; memory §4.3 gotcha table. Doctor itself initially false-failed: gmx `-h` prints to **stderr** (needs `2>&1`) and `grep -q` early-exit SIGPIPEs under `set -o pipefail` (needs `grep -c`) — both fixed | docs/INCIDENT_ANALYSIS.md, scripts/check_repo_integrity.sh, doctor cmd, rules.md, validate.yml |
| 2026-09-04 | **Health reporting unified into status/monitor** — `scripts/health_report.sh` (H1 engine · H2 integrity summary · H3 live gmx probes · H4 run KPIs: stage, sim time ps from deffnm `.log`, ns/day measured or live-estimated, >600 s stale-log ⚠️) and shared `scripts/probe_gmx_compat.sh` (doctor + health call the same probes). `status`/`monitor` print the health block locally and over SSH → cluster jobs report health in the same ✅/⚠️/❌ vocabulary as doctor. KPI doc §8 documents the table→implementation map | docs/06_KPI_DASHBOARD.md §8, scripts/health_report.sh, scripts/probe_gmx_compat.sh |
| 2026-09-04 | **Master source register** — `docs/REFERENCES.md`: every external source used across the whole workflow (NA53 primary lit, aptamer in-silico methodology, FF/method papers, structure DBs & 3D tools, cluster/infra decision chain, software used, provenance records), each with URL + verification tag ([L]/[W]/[D]/[B]/[S]/[P]). Web-verified the two weak README rows → **corrections C1/C2 applied to README**: bsc1 was mis-attributed to Zgarbová 2011 (that is bsc0; bsc1 = Ivani 2016 Nat Methods 13:55) and CHAPERONg is CSBJ 2023 (DOI 10.1016/j.csbj.2023.09.024), not GigaScience. research/REFERENCES.md header now points to the master | docs/REFERENCES.md, README §References, research/REFERENCES.md |
| 2026-09-04 | **67-ref bibliography analysis** (research/reports/2026-09-04-aptamer-bibliography-analysis.md): opened 6 key sources — AF3-for-aptamers (Ochoa & Milam 2025; PDB has only 117 DNA aptamer structures → AF3 viable for Phase 5 incl. GQ/pseudoknot, low confidence non-PDB), cTnI ssDNA docking protocol (mFold→RNA-surrogate→100 ns relax→dock; picomolar Kd aptamers), **Dans 2017 B-DNA FF accuracy (only bsc1/bsc0OL15 predictive multi-µs → evidence for R2: switch DNA FF from parm99-era amber99sb-ildn to parmbsc1/OL15 via gmxOL15/intbio ports)**, TBA GQ folding MSM (Bian 2018; cMD can't fold even 15-nt → validates folded-input design), RNA-aptamer 3D+MD (RNAComposer ~1.7 Å; MD refines models), GROMACS mdrun-perf manual (Matom·steps/s metric; GPU-resident tuning). 61 screened-only, labeled. Run logged in research/deepsearch.log; ledger + master register synced | research/reports/2026-09-04-aptamer-bibliography-analysis.md |
| 2026-09-04 | **Beginner-friendly documentation pass** — new `docs/BEGINNER_GUIDE.md` (zero-knowledge walkthrough: science primer, repo map, stage-by-stage pipeline, 3 ways to run, results sanity checklist, troubleshooting) and `docs/GLOSSARY.md` (plain-language dictionary of every term). README rewritten beginner-first (plain intro, reading paths, annotated structure, one-glance pipeline) and its parameter table **corrected to the running truth**: FF row now states `amber99sb-ildn` + TIP3P (not AMBER99bsc1) with parmbsc1 flagged under evaluation; cutoffs **1.0 → 0.8 nm**; thermostat V-rescale (not Nosé–Hoover) — matching the ✅ configs and docs/INCIDENT_ANALYSIS class P | docs/BEGINNER_GUIDE.md, docs/GLOSSARY.md, README.md |

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
- **Session complete.** Beginner documentation pass finished (README +
  BEGINNER_GUIDE + GLOSSARY); nothing mid-edit in the repo.
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

### 4.3 GROMACS version gotchas (2025.3 build; full postmortem in docs/INCIDENT_ANALYSIS.md)
| Tool / area | Gotcha | Verified on |
|---|---|---|
| mdrun | flag is `-gpu_id` (underscore); `-gpu-id` aborts | 2025.3 `mdrun -h` |
| hbond | GROMACS 2024+ rewrite: selections via CLI `-r`/`-t`; `-life`/`-ghost`/stdin piping removed | `hbond -h` |
| covar | `-lpc` removed | `covar -h` |
| sasa | per-residue output is `-or` (duplicate `-o` aborts) | `sasa -h` |
| cluster | `-o` accepts only `.xpm` matrix output | `cluster -h` |
| anaeig | prompts for TWO groups (covar fit group + eigenvector group) via stdin | trial logs |
| Analysis group layout | pdb2gmx DNA+NaCl index: 0 System, **1 DNA**, 2 NA, 3 CL, 4 Water | `make_ndx` |
| Group indices are system-dependent | never assume tutorial numbering (group 4 = Water here!) | G1 incident |
| Version policy | verify any gmx flag via `gmx <tool> -h` on the actual build; `doctor` probes the pipeline's flags | V1–V6 incidents |

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
| Q7 | Switch DNA FF amber99sb-ildn → parmbsc1/OL15 (bibliography R2: Dans 2017)? Needs a pdb2gmx validation run + re-doctor before real prod | agent | Phase 6 |

---

## 8. Session Handoff Protocol

When a session ends (human or AI):
1. Move completed items to §2 with date.
2. Update §3 statuses (what changed, what is mid-edit).
3. Update §6 next actions to match reality.
4. Append any new decisions to §5.
5. Leave §1 TL;DR accurate.