# GROMACS_NA53 — Project Memory (living document)

| Field | Value |
|---|---|
| **Status** | Active |
| **Last updated** | 2026-09-04 |
| **Current phase** | Phase 6 (T3 cluster run) IN PROGRESS — env CREATED + doctor PASSED on T3. **Prep failure 2031187 ROOT CAUSE CONFIRMED + fixed (2026-09-04-6)**: the AF3-staged PDB carried a 5'-phosphate (P/OP1/OP2) and OP1/OP2 spelling, but GROMACS amber99sb-ildn `DA5` is a **5'-OH terminus (no phosphate)** with phosphate oxygens named **O1P/O2P** → pdb2gmx died (0-byte topol.top). `validate_na53_pdb.py --stage` now drops the whole 5'-phosphate + renames to O1P/O2P; launcher now submits from `slurm/` (SLURM_SUBMIT_DIR fix, logs → repo `logs/`). PDB re-staged (1541 atoms, BLESSED). **Resume = pull → doctor → 1 ns smoke** |

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
- ✅ **Phase 4 COMPLETE (2026-09-04, live on T3)**: `na53_aptamer` conda env
  **created on Taiwania 3** (GROMACS 2024.4 conda_forge) after fixing two live
  blockers — viennarna is bioconda-only (removed, `fa1f52e`) and the gromacs
  conda activation hook aborts under `set -u` (guarded, `f0c8340`).
  `doctor` → **ALL PASS** on the cluster.
- ✅ **Phase 5 COMPLETE (2026-09-04)**: real 75-nt NA53 structure staged from **AlphaFold 3 model_0** (job 2026-09-04_19:14) via `validate_na53_pdb.py --stage` (new mmCIF support + 5'-triphosphate→monophosphate normalization). Provenance (raw model CIF + confidences + job request + pTM caveat) in `structures/raw_af3/PROVENANCE.md`. pTM 0.19 is expected-low for unbound ssDNA — not a defect signal (has_clash 0, disordered 0).
- 🔵 **Phase 6 (T3 cluster run) IN PROGRESS**: 1 ns smoke chain submitted
  (jobs 2031187–90, afterok deps, 19:54) — **prep 2031187 FAILED ~2 min in**
  (0-byte `topol.top` = pdb2gmx died). Diagnosis pending: job logs landed in
  `~/logs/` (outside the repo) because the launcher submits from the repo root
  while templates assume `cd slurm`. Resume: `cat ~/logs/na53_prep_2031187.out/.err`
  → fix → resubmit smoke.
- 🟦 **2026-09-04 correction: NA53 is 75 nt, not 55 nt** — the pasted sequence and the Hong-2019 primary-source transcription (lit-review C2) both give 75 nt (20 fixed + 35 random + 20 fixed); the '55-nt' figure was a miscount that had propagated through README/PRD/GLOSSARY/BEGINNER_GUIDE/HPC docs. All corrected; canonical seq in `structures/NA53.fasta`; `validate_na53_pdb.py` enforces it (rejects the 55-nt impostor).

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
| 2026-09-04 | **Gap-audit round after the beginner pass** — restored 4 troubleshooting rows dropped in the README rewrite (EM/NVT/NPT/crash-resume) with config-consistent wording (validated tau-t 0.1 not the old 2.0 advice); added ✅-config validation banners to docs/01 charter + docs/02 scope (they still carried pre-validation 1.0 nm / Nosé–Hoover / AMBER99bsc1 values) pointing to configs/*.mdp as running truth + INCIDENT_ANALYSIS class P; registered BEGINNER_GUIDE + GLOSSARY in architecture.md docs tree; added the 09-04 bibliography report to research/README 'Current reports'; corrected guide timing math (100 ns ≈ 1.5–2.5 d at 40–70 ns/day). Repo-wide dead-link audit: 0 dead relative links | README.md §9, docs/01, docs/02, architecture.md, research/README.md, docs/BEGINNER_GUIDE.md |
| 2026-09-04 | **Beginner-friendly documentation pass** — new `docs/BEGINNER_GUIDE.md` (zero-knowledge walkthrough: science primer, repo map, stage-by-stage pipeline, 3 ways to run, results sanity checklist, troubleshooting) and `docs/GLOSSARY.md` (plain-language dictionary of every term). README rewritten beginner-first (plain intro, reading paths, annotated structure, one-glance pipeline) and its parameter table **corrected to the running truth**: FF row now states `amber99sb-ildn` + TIP3P (not AMBER99bsc1) with parmbsc1 flagged under evaluation; cutoffs **1.0 → 0.8 nm**; thermostat V-rescale (not Nosé–Hoover) — matching the ✅ configs and docs/INCIDENT_ANALYSIS class P | docs/BEGINNER_GUIDE.md, docs/GLOSSARY.md, README.md |

| 2026-09-04 | **Cluster-run readiness + 75-nt correction** — NA53 proven **75 nt** (pasted sequence + lit-review C2 both 75; '55-nt' was a propagated miscount) → corrected README/PRD/GLOSSARY/BEGINNER_GUIDE/HPC_GPU_OPTIONS/LESSONS_LEARNED/TRANSCRIPTS/bibliography/profiles/00 script; added `structures/NA53.fasta` (canonical, provenance-header) + `scripts/validate_na53_pdb.py` (AF3/3D-model gate: length/identity/completeness incl. sugar atoms, altLoc, chain; in-memory `--selftest`; rejects the 55-nt impostor); **fixed launcher bug: `submit --ns N` was ignored** (generate_jobs never templated it — smoke would have silently run 100 ns) → ns threaded into generated 03 job (dry-run verified: `--ns 1` → `NS_LENGTH="${1:-1}"`); wrote `docs/CLUSTER_RUNBOOK.md` (75-nt-aware T3 walkthrough: validate→setup→doctor→1 ns smoke→measure ns/day→archive→100 ns prod→RESTART→fetch) | structures/NA53.fasta, scripts/validate_na53_pdb.py, docs/CLUSTER_RUNBOOK.md, run_simulation.sh, docs sweep |
| 2026-09-04 (2) | **APTAMD adoption round** — added `validate_na53_pdb.py --stage` (APTAMD-style auto edition: model-1 keep, drop water/protein/H/altLoc, merge chains, renumber 1..75, re-bless, atomic stage; fails leave no file) + `scripts/dssr_inf.sh` (optional DSSR/INF vs seqfold 2D; auto-skip rc0 when x3dna-dssr absent — DSSR is Columbia-licensed, NOT conda-installable). Caught+fixed 2 real stage bugs via selftest (MODEL-serial column overlap dropped atoms past serial 9; per-atom residue counter made every atom its own residue). Negatives green on real 1BNA (24 nt, 2 chains, 80 waters) + trial stand-in (12 nt). Updated runbook §0 to one-liner, APTAMD_DEEP_ANALYSIS.md banner+addendum, architecture.md, Q4 answered | `scripts/validate_na53_pdb.py`, `scripts/dssr_inf.sh`, runbook §0 |
| 2026-09-04 (3) | **Phase 5 COMPLETE — real AF3 structure staged** — user's AlphaFold 3 zip (job 2026-09-04_19:14, 5 models) found at repo root; model_0 (best pTM 0.19) staged via the new `validate_na53_pdb.py --stage` mmCIF path → `structures/NA53_initial.pdb` BLESSED (75 nt, seq-identical, 1544 atoms; OP3 gamma-P dropped → amber DA5 monophosphate terminus). Provenance (model CIF + confidences + full_data + job_request + pTM caveat) committed under `structures/raw_af3/`. Integrity all-PASS. **Cluster run is now unblocked** — next: T3 env → doctor → smoke | `structures/NA53_initial.pdb`, `structures/raw_af3/` |
| 2026-09-04 (4) | **T3 LIVE RUN attempt (interactive, user-driven)** — env `na53_aptamer` CREATED on T3 + doctor ALL PASS (gmx 2024.4 conda_forge live). Two more setup bugs found+fixed live: (a) `viennarna` is bioconda-only, NOT conda-forge → env create PackagesNotFoundError → removed from environment.yml (fa1f52e); (b) conda-forge gromacs activation hook sources GMXRC.bash which reads unset vars → `set -u` killed `conda activate` right after successful env create → guarded with set +u/-u in setup script + profile ENV_SETUP + legacy installer (f0c8340). Setup then ran clean to SETUP COMPLETE. Submitted 1 ns smoke chain (jobs 2031187-90, afterok deps) via launcher — **prep 2031187 FAILED in ~2 min**: topol.top 0 bytes (pdb2gmx died). Suspected launcher cwd bug: templates assume `cd slurm && sbatch` (output `../logs/`, `cd ${SLURM_SUBMIT_DIR}/../scripts`) but launcher submits from repo root → job logs landed in `~/logs/` outside repo. **Logs NOT yet retrieved** (user paused) | slurm/setup_taiwania3.sh, profiles/taiwania3_cpu.env, environment.yml |
| 2026-09-04 (5) | **PAUSED mid-diagnosis** — resume point: on T3 run `cat ~/logs/na53_prep_2031187.out/.err` + `sacct -j 2031187` to get the pdb2gmx error; then fix (likely: make launcher `cd slurm` before sbatch OR make templates cwd-agnostic via `cd "$(dirname "$0")"`); also confirm whether the AF3-staged PDB (DA5 5'-monophosphate terminus) is what pdb2gmx rejected | — |
| 2026-09-04 (6) | **Prep-failure root cause CONFIRMED + fixed (off-cluster, from the GROMACS v2024.4 amber99sb-ildn dna.rtp)** — (a) `DA5` in this ff is a **5'-OH terminus — it contains NO phosphate atoms** (the stage code only dropped OP3, wrongly assuming DA5 = 5'-monophosphate), so residue 1's P/OP1/OP2 could never match pdb2gmx; (b) phosphate oxygens are **O1P/O2P** in this ff, not AF3's OP1/OP2 (the 1BNA trial worked because PDB files use O1P/O2P). Fixed `validate_na53_pdb.py --stage`: drops the ENTIRE 5'-terminal phosphate (P/OP1/OP2) and renames OP1/OP2 → O1P/O2P; `assess()` exempts the 5' terminus from phosphate checks; BASE_HEAVY T now uses C7 (this ff's thymine-methyl name, not C5M). Also fixed the launcher submit-cwd bug: `cmd_submit` now cds to `slurm/` before `sbatch` → SLURM_SUBMIT_DIR=slurm → `--output=../logs/` lands in repo `logs/` and `cd ${SLURM_SUBMIT_DIR}/../scripts` resolves inside the repo (the `~/logs/` scatter). Re-staged `structures/NA53_initial.pdb` from the AF3 CIF: 1541 atoms, res 1 = DA5 5'-OH (18 atoms), 74× O1P/O2P, 0× OP1/OP2; selftest ALL PASS; validate BLESSED. Confirm on T3: `repo/logs/pdb2gmx.log` from the failed run should show the DA5/P mismatch | scripts/validate_na53_pdb.py, structures/NA53_initial.pdb, run_simulation.sh, memory.md |
| 2026-09-04 (7) | **T3 smoke chain VERIFIED on the cluster** — after the (6) fixes: duplicate-chain incident (an earlier submit left jobs 2033887-89 running while the new chain 2034005-08 was submitted from the same workspace → would collide on topol.top/prod.* files; cancelled the new chain, kept the advanced one). Prep log `SYSTEM PREP COMPLETE`, `topol.top` 671 KB, `grep -c O1P` = 74 (exactly the internal phosphates → pdb2gmx accepted the re-staged PDB), system 290,578 atoms (ssDNA ~50 nm long → ~96k waters; the 35-45k-atom ns/day estimate is obsolete — smoke prod will give the real number; 100 ns on ct56 likely needs GPU or RESTART chaining). Also found+fixed monitor bug: `status`/`monitor` compared `$(hostname)` to SSH_HOST (lgn301 vs twnia3.nchc.org.tw never equal) → on-cluster use SSH'd back into T3 and 2FA-hung; now they run locally when `squeue` exists (1258e96) | run_simulation.sh, logs on T3 |
| 2026-09-04 (8) | **Live dashboard for monitor** — new `scripts/live_dashboard.sh` (polling, default 30 s, override `MONITOR_EVERY`): SLURM job state (state/elapsed/limit), current MD stage + progress bar, live Temp/Pres parsed from the gmx .log energy table, measured ns/day + steps/s (mdrun's "step N, will finish" implied rate with log-age fallback), ETAs (current stage · prod target at measured rate), verdict ✅/⏳/⚠️/❌ (kept >600 s stale-log hang detection). `monitor` (non-`--once`) now runs the loop locally when on the cluster and in a SINGLE ssh session remotely (no per-poll 2FA); `monitor --once` keeps the health-report + tail snapshot. Parsing verified against synthetic em/nvt/npt2/prod log formats | scripts/live_dashboard.sh, run_simulation.sh |
| 2026-09-04 (9) | **Textual TUI dashboard (impressive-af upgrade)** — deepsearched GitHub for terminal/HPC monitoring patterns: squid-tui (Textual Slurm TUI — the winning pattern: pure Python, pip-installable in the conda env), slurm-tui (Rust/Ratatui — log-tail + keyboard actions ideas), Sampler (Go — gauges/sparklines from shell commands), deeplook/sparklines (Tufte unicode sparklines). Built `scripts/na53_metrics.py` (stdlib-only data layer: squeue jobs, gmx-log parser for step/time/T/P/mdrun-ETA, artifact/pipeline states; `--selftest` JSON) + `scripts/dashboard_textual.py` (Textual app: JOBS panel, STAGE with animated ProgressBar, PHYSICS with session T/P Sparklines, PERFORMANCE ns/day+ETAs, PIPELINE checklist, LOG trail/md-tail, keybindings q/r/d dark-light theme). `monitor` now prefers the Textual TUI when `textual` is importable (local: python3 check; remote: activates na53_aptamer in one ssh session) and falls back to the bash dashboard otherwise. Headless-verified with textual 8.2.8 `run_test()` + SVG text extraction (fake npt2 log: 88% bar, step 220000/250000, ns/day+ETA, pipeline icons all render). `textual>=0.50` added to environment.yml pip section — on T3: `pip install textual` | scripts/dashboard_textual.py, scripts/na53_metrics.py, run_simulation.sh, environment.yml |
| 2026-09-04 (10) | **Live-run fixes on T3** — (a) TUI crashed in the "between stages" window (active_log() → None → unpack error) — fixed in na53_metrics.snapshot (55ca649); (b) C2 integrity failure because scripts/live_dashboard.sh was committed 100644 — chmod +x (55ca649, doctor now all PASS); (c) bash fallback dashboard crashed when $stage was EMPTY (unquoted arg shifted icon()'s $3 → unbound under set -u) plus `${fmt_bytes …}` typo = runtime "bad substitution" (bash -n can't catch it) — fixed; (d) **user asked for no box — live_dashboard.sh rewritten as simple line-based output** (no width/alignment issues from wide glyphs); (e) local `monitor` now retries with the profile's ENV_SETUP (conda env) when the bare python3 lacks textual, so being in `(base)` still gets the TUI. Live T3 data: equil NPT2 finished, real measured **15.885 ns/day on 28 cores**; prod 2033888 queued waiting for ct56 capacity | scripts/live_dashboard.sh, scripts/na53_metrics.py, scripts/dashboard_textual.py, run_simulation.sh |
| 2026-09-04 (11) | **Textual experiment REMOVED — monitor is now one lightweight pure-bash viewer** (user: "undo these monitoring experiments … keep it easy on the system, no textual, just give me everything while monitoring"). Deleted `scripts/dashboard_textual.py` + `scripts/na53_metrics.py`, dropped `textual>=0.50` from environment.yml, stripped all TUI/conda-activation branches from `cmd_monitor` (local AND remote paths now run `scripts/live_dashboard.sh` only — zero deps, works in any shell, no conda/python needed; remote = one ssh session running the loop on the cluster). Enhanced the bash dashboard while at it: (a) new **LOG section** — tail of the newest `logs/mdrun_*.log` so raw mdrun output is on screen; (b) **stale-stage verdict** — an unfinished stage log (no "Finished mdrun") with NO job in queue now prints "⚠️ stage log stopped Xs ago with no job — likely died/killed; check sacct" instead of a misleading "idle". That check exists because the 1 ns smoke prod (2033888) appears to have DIED ~180 ps in: dashboard showed PRODUCTION 180 ps / step 90,000 open with an empty queue and analysis never ran — sacct/err diagnosis still outstanding | scripts/live_dashboard.sh, run_simulation.sh, environment.yml, memory.md |
## 3. Files — Current Ownership & Status
| 2026-09-04 | **T3 etiquette research** (user request: common Taiwania-3 usage violations to avoid) — consolidated `docs/TAIWANIA3_ETIQUETTE.md`: login-banner enforcement `[P]` (login-node misuse; squeue <30 s hammering = attack; 1-week suspension per repeat), official manual `[W]` (crypto/weapons/cyber → suspension; 2FA no-bypass), official FAQ `[W]` (no `--mem` = whole-node memory grab; core scatter; PartitionTimeLimit; requeue/PREEMPTED; /tmp cleanup). Confirmed our profile already sets `--mem`/`--nodes`/`--cpus-per-task` correctly. Repo made **PUBLIC** this session (was private — clone on T3 needed anonymous access) | docs/TAIWANIA3_ETIQUETTE.md, docs/REFERENCES.md §5 |

| 2026-09-04 | **Live T3 setup session (interactive, user-driven)** — repo made PUBLIC (clone needed anonymous access); setup_taiwania3.sh self-nesting bug found live (cloned GROMACS_NA53/GROMACS_NA53 when run from inside a clone) → fixed with repo-root guard (4e9657f); conda 25.x **ToS gate** (CondaToSNonInteractiveError on repo.anaconda.com pkgs/main+r) blocked env creation twice → environment.yml made pure conda-forge (4dc64b2) + setup script now auto-accepts ToS (guarded). **Env `na53_aptamer` NOT yet created on T3** — resume = fresh clone + setup script (now one-shot). SSH 2FA bridge prepared on the local machine: ~/.ssh/config `Host twnia3` with ControlMaster auto + ControlPersist 12h — user authenticates once (password+OTP), master socket ~/.ssh/cm-t3.sock lets the agent drive all follow-up commands without re-auth. Next: env → doctor → 1BNA machinery smoke (decide) → real AF3 structure gates Phase 5 | slurm/setup_taiwania3.sh, environment.yml, docs/CLUSTER_RUNBOOK.md, ~/.ssh/config |
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
| Q4 | ~~INF/DSSR analysis worth installing for publication?~~ **ANSWERED 2026-09-04:** `scripts/dssr_inf.sh` exists (optional; DSSR is Columbia-licensed so it stays OUT of environment.yml — install later only if the paper needs INF) | user (optional) | Phase 9 |
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