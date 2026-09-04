# GROMACS_NA53 — Rules of Engagement (for AI agents & contributors)

| Field | Value |
|---|---|
| **Status** | Active — bindings for any AI working in this repo |
| **Last updated** | 2026-09-04 |

> Read this file **before** modifying anything. It encodes every hard lesson from
> the GROMACS_TEEP trial runs and the Taiwania 3 hallucination audit.

---

## 1. The Golden Rules (non-negotiable)

1. **Never fabricate data.** No invented PDB coordinates, no invented cluster
   facts, no invented benchmark numbers. If it wasn't measured or verified, say
   "unverified" and produce the command that would verify it.
2. **Never invent cluster resources.** Partition names, module versions, GPU
   types, and paths must come from live output (`sinfo`, `module avail`,
   `sacctmgr`, `scontrol`), not from memory or another cluster's docs.
3. **Never write a partial PDB.** `gmx pdb2gmx` cannot build DNA topology from
   incomplete nucleotides. A real all-atom model is required; the pipeline
   refuses to fabricate one (and so do we).
4. **Never change physics parameters without evidence.** Every MDP value must
   trace to `docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md` or a cited publication.
5. **Fail loudly, fail early.** Prefer an error message over a silent wrong
   value. `CHANGE_ME_*` placeholders are intentional — they force rejection
   rather than guessing.
6. **Verify before you claim.** "Verified" means: ran the command and saw the
   output. "Probably" means: check it.
7. **One engine, one source of truth.** On Taiwania 3 the conda env owns `gmx`.
   Never mix a source-compiled GROMACS into that env (two binaries shadow each
   other).
8. **CPU-first on Taiwania 3.** GPU partitions are restricted (`ngs*`) or down
   (`gpu-amd`); there is no CUDA module. Default everything to `-nb auto`.
9. **Version-check every gmx flag against the live build** (`gmx <tool> -h`)
   before first use. CLI drift has broken mdrun (`-gpu_id`), hbond (2024
   rewrite: `-r`/`-t` selections, no `-life`/`-ghost`/stdin), covar (`-lpc`
   gone), sasa (`-or`), cluster (`.xpm`). Gotchas live in `memory.md §4.3`.
10. **Never assume group numbering from a tutorial.** Index groups are
    system-dependent — on this DNA+NaCl system group 1 = DNA, group 4 = Water
    (analyzing water instead of DNA produced silent nonsense). `doctor`
    re-verifies group 1 = DNA against the real structure.
11. **mdrun runs in the foreground of stage scripts.** No fire-and-forget
    backgrounding without an explicit wait; gate stages on real exit codes,
    never on log-scraping or output pipes (they mask failures).
12. **Every runtime input must ship in a fresh clone.** A required file that is
    gitignored is a bug (`.gitignore` once swallowed `em/nvt/npt/npt_free.mdp`).
    CI enforces this on every push; run the fresh-clone acceptance test after
    significant changes.
13. **MDP configs must match the validated standard** (0.8 nm, shift-Verlet,
    PME only in real stages, `-DPOSRES`, `refcoord_scaling=com`, no prod
    restraints). The static checker enforces it — do not edit an MDP without
    re-running `scripts/check_repo_integrity.sh`.

---

## 2. What to USE (allowlist)

### 2.1 MD engine & parameters
| Item | Value | Rationale |
|---|---|---|
| GROMACS | 2024.4 (conda-forge, CPU, thread-MPI) | Prebuilt, zero compile risk |
| Force field | amber99sb-ildn (DNA) | Validated in trial runs |
| Water model | TIP3P | AMBER-standard; validated |
| Cutoff | rcoulomb=rvdw=0.8 nm | Convergence study |
| vdw-modifier | Potential-shift-Verlet | Required for AMBER in GROMACS |
| DispCorr | EnerPres | Required for AMBER |
| T-coupling | V-rescale, 310.15 K, τ=0.1, two groups (DNA, Water_and_ions) | Trials 04–08 |
| P-coupling | Parrinello-Rahman, 1.0 bar, τ=2.0 | 200 ns run |
| Timestep | 2 fs, LINCS H-bonds | Standard |
| PME | order 4, 0.12 nm spacing | Long-range electrostatics |
| Box | dodecahedron, 1.2 nm padding | Minimal volume |
| Ions | Na⁺/Cl⁻, neutral + 0.15 M | Physiological |
| Production restraints | **none** (`define = ""`) | Trial lesson: restraints froze the DNA |
| Checkpoints | `-cpo prod -cpt 900` (15 min) | Session-disconnect lesson |
| mdrun offload | `-nb auto` default; explicit GPU flags only on known GPU hardware | Portability |

### 2.2 Tooling
- bash scripts with `set -euo pipefail`
- conda env `na53_aptamer` (defined in `environment.yml`)
- Python 3.10 + matplotlib, seaborn, numpy, pandas, MDAnalysis, biopython, seqfold
- gmx modules: `pdb2gmx`, `editconf`, `solvate`, `genion`, `grompp`, `mdrun`,
  `energy`, `rms`, `rmsf`, `gyrate`, `hbond`, `cluster`, `covar`, `anaeig`, `mindist`
- SLURM: `sbatch`, `squeue`, `scontrol`, `sacctmgr`, `sinfo`

### 2.3 Sources of truth (in priority order)
1. Live command output on the target machine
2. `docs/TRANSCRIPTS_DEEP_ANALYSIS.md` (verified cluster facts)
3. `docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md` (validated parameters)
4. `docs/INCIDENT_ANALYSIS.md` (bug classes V/P/S/G/K + prevention map)
5. `docs/APTAMD_DEEP_ANALYSIS.md` (protocol comparisons)
6. Cited literature (AMBER99bsc1, TIP3P, aptamer–ligand MD refs in README)

### 2.4 Automated guards (run, don't skip)
- `bash scripts/check_repo_integrity.sh` — static integrity (runs in CI on every push)
- `./run_simulation.sh doctor` — static + live gmx/group probes on the target machine

---

## 3. What to AVOID (blocklist)

| Item | Why |
|---|---|
| `-nb gpu` on Taiwania 3 | CPU-only build → fatal GPU error |
| `--gres=gpu:*` in sbatch | Partition has no GPUs; job rejected |
| cuda/cmake/openmpi/fftw `module load` | **These modules do not exist** on Taiwania 3 (verified) |
| Source-compiling GROMACS on Taiwania 3 | No cmake/fftw modules; pointless; login-node policy |
| RNAComposer for NA53 | **RNA-only tool**; NA53 is DNA |
| Writing a 2-atom-per-nucleotide PDB fallback | Guaranteed `pdb2gmx` crash (bug found & fixed) |
| Conda `gromacs` + compiled `gmx` in the same PATH | Binary shadowing (bug found & fixed) |
| 1.0 nm cutoff with AMBER FF | Wrong electrostatics; 170 ns/day artifact in trial 01 |
| Position restraints in production MDP | Frozen dynamics (trial lesson) |
| GUI-mode mdrun | 5.8% slower, 65% more RAM (trial 06) |
| Committing large binaries (.xtc/.gro/.tpr/.trr) | Git bloat; GitHub 100 MB limit |
| Running production on the login node | Policy violation; auto-logout at 15 min idle |
| `make -j56` / heavy compile on login | Shared resource abuse |
| Inventing `CHANGE_ME_*` values | Fill from live `sacctmgr`/`sinfo` output only |

---

## 4. Library & Version Policy

- **Pinned**: `gromacs=2024.4`, `python=3.10`, `ambertools=23` (in environment.yml).
- **Analysis deps**: only packages already in `environment.yml`. If a new library
  is needed, add it to `environment.yml` **and** record why in `memory.md`.
- **Prefer gmx built-ins** for analysis (rms/rmsf/gyrate/hbond/cluster) over
  reimplementing in Python; use MDAnalysis only where gmx lacks the metric.
- **No new conda envs** without a reason recorded in memory.md (env sprawl breaks
  reproducibility).

---

## 5. Error Handling Conventions

1. Every bash script: `set -euo pipefail` at the top.
2. Every stage checks its required input exists, with an actionable message:
   `❌ ERROR: npt2.gro not found. Run 02_equilibration.sh first.`
3. Any command whose output is consumed later is redirected to `logs/<stage>.log`
   so failures are diagnosable (`tail -f logs/mdrun_prod.log`).
4. Unverified cluster values stay as `CHANGE_ME_*` — a rejected sbatch job is a
   **feature** (loud failure) not a bug.
5. On any non-zero exit, report the stage, the log file, and the last ~10 lines
   of that log. Do not "fix forward" blindly — read the error first.
6. Checkpoint discipline: never delete `prod.cpt`; it is the resume point.
7. Never evaluate a stage through an output pipe (`cmd | grep | tail` masks the
   exit code). Capture to a log and check `$?` (see S2 in INCIDENT_ANALYSIS.md).

---

## 6. AI Agent Boundaries

### 6.1 May do (no permission needed)
- Read any file, run any read-only command (`gmx --version`, `sinfo`, `module avail`).
- Edit scripts/configs/docs to fix bugs or add features per this rules file.
- Run syntax checks (`bash -n`, `python -m py_compile`) and CI locally.
- Run `bash scripts/check_repo_integrity.sh` and `./run_simulation.sh doctor`.
- Stage/commit changes when explicitly asked (git commit only, no push).

### 6.2 Must ask first
- **Any `git push`** (breaks production if unrequested).
- Any command with irreversible effects (deleting trajectories, `scancel` of
  running jobs, `sbatch` submissions on the shared cluster).
- Changing force field / water model / physics parameters.
- Installing packages outside the conda env or system-wide.
- Provisioning services/accounts or running anything against production systems.

### 6.3 Never do
- Never run long MD on the login node.
- Never fabricate a PDB, cluster fact, or result to "complete" a task.
- Never overwrite raw data (`prod.xtc`, `prod.edr`, `prod.cpt`, backups).
- Never edit `memory.md`'s "verified facts" without a live source.

### 6.4 Update discipline
- After any meaningful change, update `memory.md` (completed/current/next).
- If a decision changes physics or cluster usage, append to the decision log in
  `memory.md` and cross-reference `rules.md` if a rule changes.

---

## 7. Commit & Git Rules

- Commit messages: imperative, one line, context in body (e.g., "Lock production
  MDP to verified 0.8 nm cutoff").
- Never commit: `*.gro *.xtc *.tpr *.trr *.edr *.cpt *.log *.xvg` (see .gitignore).
- Keep `structures/NA53_initial.pdb` committed (it's the one real input).
- Do not commit `.conda/` or `__pycache__/`.
- Entry-point scripts must be mode 100755 in the git index (`git update-index
  --chmod=+x` on filesystems that can't store exec bits); CI enforces.
- Never add a gitignore pattern that matches a runtime **input** file — verify
  with `git check-ignore` (see K2 in INCIDENT_ANALYSIS.md); CI enforces.

---

*This file is the contract between the human, the AI, and the cluster. When in
doubt, re-read §1.*