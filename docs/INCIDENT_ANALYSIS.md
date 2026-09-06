# Incident Analysis — Every Bug the Pipeline Had, Why, and How It Can't Come Back

**Date:** 2026-09-04 · **Trigger:** local 1 ns end-to-end trials + a from-scratch
`git clone` test that mimicked the Taiwania 3 deployment path
**Scope:** all failures observed in `scripts/`, `configs/`, `slurm/`, and
`run_simulation.sh` between the initial scaffold and the passing clone-and-run.

> Read this together with `scripts/check_repo_integrity.sh` (the automated
> guard) and `./run_simulation.sh doctor` (the pre-run guard). CI runs the
> integrity checker on every push; the doctor runs it plus live gmx probes
> on the target machine. If a fix does not have a corresponding check here,
> it is not finished.

---

## 1. Failure taxonomy

Every incident fell into one of five root-cause **classes**. Class is what
matters: each class has one structural prevention, not a per-flag patch.

| Class | What it is | Incidents |
|---|---|---|
| **V — version drift** | Scripts written for a GROMACS era or tutorial, run on a different build | V1–V6 |
| **P — physics/config hallucination** | MDP parameters guessed or copy-pasted, not validated | P1–P5 |
| **S — shell fragility** | Backgrounding, exit-code masking, cwd-relative paths | S1–S4 |
| **G — group-index assumption** | Protein-tutorial group numbering applied to a DNA system | G1 |
| **K — packaging** | The *repo itself* can't reproduce from a fresh clone | K1–K2 |
| **E — energy-term extraction** | `gmx energy` term **IDs assumed stable**; they are per-`.edr` (added terms shift the numbering) and build-specific | E1–E3 |

---

## 2. Incident register

### V — version drift (stale / invented gmx CLI)

| # | Failure | Root cause | Fix |
|---|---|---|---|
| V1 | `mdrun` aborted: *Unknown command-line option `-gpu-id`* | Flag renamed `-gpu_id` (GROMACS 2021+); script used the old hyphen form | `03_production.sh` → `-gpu_id` |
| V2 | `gmx hbond` aborted: *Unknown option `-life`/`-ghost`* | hbond rewritten in GROMACS 2024; `-life`/`-ghost` removed | dropped; see V5 |
| V3 | `gmx covar` aborted: *Unknown option `-lpc`* | `-lpc` removed by 2025.3 | dropped (`-o`/`-v` retained) |
| V4 | `gmx sasa` aborted: *Option specified multiple times* | second `-o` for per-residue output; the real flag is `-or` | `-o` + `-or` |
| V5 | `gmx hbond` aborted: *Invalid selection '1 1'*, then *Too few selections, got 0* | 2024 rewrite takes selections as **CLI `-r`/`-t` args**, not piped stdin | `-r 'group DNA' -t 'group DNA'` |
| V6 | `gmx cluster` refused `clusters.xvg`: *only `.xpm` allowed* | `-o` output type is xpm matrix | `clusters.xpm` |

**Why they happened:** every stage script was written once against an assumed
GROMACS interface (or a tutorial written for one), and nothing verified the
flags against the actual build before burning a run. Errors were also masked
(S2), so several failed silently for an entire trial.

### P — physics / config hallucination

| # | Failure | Root cause | Fix |
|---|---|---|---|
| P1 | genion grompp fatal (net charge −22 on un-neutralized DNA) | `ions.mdp` kept PME; PME + nonzero net charge is invalid *before* counter-ions exist | `ions.mdp` → Cut-off electrostatics (PME lives in the real stage MDPs) |
| P2 | restrained-NPT grompp fatal: unused macro | MDP defined `-DPOSRES_BB` but pdb2gmx DNA topologies only carry `#ifdef POSRES` | `nvt/npt.mdp` → `-DPOSRES` |
| P3 | restrained-NPT mdrun fatal: `refcoord_scaling` unset | posres + Parrinello–Rahman requires reference coords to scale with the box | `refcoord_scaling = com` |
| P4 | configs drifted to 1.0 nm, no shift-Verlet | stage MDPs were written independently of the validated 0.8 nm standard (200 ns 1BNA run) | all stage MDPs unified to 0.8 nm + `Potential-shift-Verlet` |

**Why they happened:** MDP files were authored in isolation; the single
validated standard lived only in prose (memory.md), so nothing forced the
files to agree with it.

### S — shell fragility

| # | Failure | Root cause | Fix |
|---|---|---|---|
| S1 | production mdrun died right after grompp; "ok" logged anyway | `03_production.sh` backgrounded mdrun (`&`) with the `wait` commented out → killed on shell exit, and callers proceeded as if done | mdrun runs **foreground** in every stage script; launcher gates on real rc |
| S2 | silent deaths (S1, and 04_analysis steps) with rc masked | `set -e` + `cmd | tail` pipelines swallow failure | all trial re-runs capture rc (`cmd > log; echo RC=$?`); no output pipe around stage calls |
| S3 | `cmd_status`/`cmd_monitor` crashed on no-match `ls` | `set -o pipefail` + `ls *.log` glob with no matches | glob guarded (`ls ... 2>/dev/null || true`-style) |
| S4 | status log split across `logs/` + `scripts/logs/` | `STATUS_FILE` was cwd-relative while `cmd_start` `cd`s into `scripts/` | anchored to `$REPO_ROOT` (status + jobs dir) |

**Why they happened:** stage scripts favored "fire and forget" patterns and
the launcher trusted log-scraping over exit codes.

### G — analysis on the wrong molecule

| # | Failure | Root cause | Fix |
|---|---|---|---|
| G1 | RMSD/RMSF/PCA/cluster silently computed on **water** | group index `4` assumed from a protein tutorial; on this DNA+NaCl system `4 = Water`, `1 = DNA` | all solute analyses target group **1 (DNA)**; layout documented at the top of `04_analysis.sh` |

**Why it happened:** index numbers are system-dependent and were hard-coded
from memory. Worse, they *worked* (water is a valid group), so nothing
complained — only domain sense (30–40 H-bonds on a 12-bp duplex) caught it.

### K — packaging (clone-and-run)

| # | Failure | Root cause | Fix |
|---|---|---|---|
| K1 | `./run_simulation.sh` → *Permission denied* on a fresh clone | everything committed mode 100644 | `git update-index --chmod=+x` (recorded in the index; verified 755 materializes on a Linux clone) |
| K2 | equilibration died: *`../configs/em.mdp` does not exist* on a fresh clone | `.gitignore` globs `em.*`/`nvt.*`/`npt*.*` (meant for grompp/mdrun **outputs**) also matched the **input** MDP configs → never committed | `!em.mdp !nvt.mdp !npt.mdp !npt_free.mdp` negations |

### E — energy-term extraction

| # | Failure | Root cause | Fix |
|---|---|---|---|
| E1 | `energy_Density.xvg` oscillated around ~0 bar; report "density 2.6 kg/m³" | term **36 = Pres-XY** (pressure-tensor element) on gmx 2024.4 conda, assumed to be Density (= 23) | terms looked up **by name** from each `.edr`'s own list |
| E2 | `nvt_temperature.xvg` held Conserved-En (−4.1e6), not ~310 K | NVT `.edr` gains a `Position-Rest.` entry that shifts every later term (Temperature = 16, not 15) | same name-based lookup; verified live on T3 |
| E3 | `em_potential.xvg` held Coul.-recip (+8.4e4); `npt2_density`/`npt2_pressure` swapped (pV/Density) | hardcoded IDs that match *some other* run's numbering | name-based lookup **+ physical sanity gates** (below) |

**Why they happened (3 separate times):** energy term numbering is an
implementation detail of each `.edr`, so any hardcoded ID is fragile — and
the failure is *silent* because `gmx energy` happily writes whichever term
the ID names. Physical sense is the only reliable detector, which is why the
fix is two layers: look the term up by name (correct file) **and** verify the
result is physically possible (correct content).

**Why they happened:** validation happened only in the working directory,
where the files existed and exec bits were cosmetic. The only true test is a
fresh clone — which is why the clone-and-run trial is now part of the
acceptance procedure (§5).

---

## 3. Detection gaps (why these survived earlier review)

1. **No version probe** — nothing ever asked the installed gmx which flags it
   supports before using them (V1–V6).
2. **No cross-file reference check** — nothing asserted that every file a
   script opens actually exists *in git* (K2, and partially K1).
3. **Exit codes discarded** — pipes and `|| true` hid every silent failure
   (S1/S2), turning "fails loudly" bugs into "fails quietly" ones.
4. **Wrong-target analyses are silent** — selecting water instead of DNA
   produces valid plots (G1). Only a group-name assertion catches it.
5. **No physical assertion on extracted terms** — `gmx energy` writes
   whatever term the ID names, so a wrong ID yields a *plausible-looking*
   xvg that only physics can refute (E1–E3). The post-extraction sanity
   gates (steady-state mean in a physical window) close this.
6. **Working-tree-only validation** — syntax and even successful runs in the
   author's checkout prove nothing about a fresh clone (K1/K2).

---

## 4. Prevention (structural, per class)

| Class | Prevention | Where enforced |
|---|---|---|
| V | `doctor` probes the **live** build's help for every flag the pipeline uses (`-gpu_id`, hbond `-r/-t`, sasa `-or`); gotcha table in `memory.md §4.3` | `./run_simulation.sh doctor` (pre-run) |
| P | MDP consistency scan asserts the validated standard: 0.8 nm, shift-Verlet, PME only in real stages, `-DPOSRES`, `refcoord_scaling=com`, no restraints in prod | `scripts/check_repo_integrity.sh` (CI + doctor) |
| S | stage scripts run mdrun foreground; launcher gates on real rc; paths anchored to `$REPO_ROOT` | code review + rules.md R7 |
| G | analysis targets the named group via the documented index layout; doctor cross-checks group 1 = **DNA** against any existing `.tpr` | `04_analysis.sh` header + doctor |
| K | static checker asserts every runtime file is present **and not gitignored**, and entry points are 100755 in the index | `scripts/check_repo_integrity.sh` in **CI** (every push) |
| E | terms extracted **by name** per `.edr` (`gmx_energy_lib.sh`) **and** every extracted xvg passes a post-extraction physical sanity gate: steady-state mean must be T ∈ [300,320] K, ρ ∈ [950,1050] kg/m³, P ∈ [−100,100] bar, potential < −1000 kJ/mol — wired into stages 02 and 04 so a wrong term **aborts the job** (`set -e`) instead of corrupting figures | `scripts/gmx_energy_lib.sh` + `02_equilibration.sh` + `04_analysis.sh` |

**One extra habit that caught K1/K2 and would have caught everything else:**
run the flow from a **fresh clone** (`git clone` → run) at least once per
release. That is the acceptance test for "clone-and-run".

---

## 5. Acceptance procedure (regression gate)

Before any commit is called "ready":

```bash
bash scripts/check_repo_integrity.sh     # static: runs in CI too
./run_simulation.sh doctor               # static + live gmx probes (target machine)
# and, once per significant change:
git clone <repo> /tmp/fresh_check && cd /tmp/fresh_check
# place a test PDB at structures/NA53_initial.pdb, then:
./run_simulation.sh start --profile local_gpu --ns 1 --stage all   # end-to-end
```

If the fresh-clone run or either checker fails, the change is not done.
