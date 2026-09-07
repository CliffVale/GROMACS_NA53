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

---

## 6. Pipeline audit (post-15ns-pilot, 2026-09-07)

The 15 ns run exposed **5 structural defects** in the pipeline that the
earlier incident register did not fully cover. Each is now classified and
prevented.

| # | Defect | Evidence | Class | Prevention |
|---|---|---|---|---|
| 1 | **Flat workspace** — every run writes `scripts/em.* nvt.* npt* prod.* topol.top`, so run N+1 silently overwrites run N | The 15 ns pilot data was nearly lost; user had to manually rescue it as `Raw_Result_15ns/` | S (shell fragility — no workspace isolation) | `cmd_archive` moves finished runs into `archive/<RUN_ID>__<verified>ns/`; new-run guard refuses fresh chains while un-archived prod.* data exists |
| 2 | **No run identity** — no RUN_ID tying requested ns → submitted job → produced .tpr | "100 ns report" published on a 15 ns run | S/K (no tracking + no verification) | `scripts/run_state.sh` registry: every chain gets a RUN_ID row recording requested ns at submit, VERIFIED ns from prod.log at finish, archive state, SLURM job IDs |
| 3 | **NS generation bug** — `generate_jobs` only overrode `NS_LENGTH` when ns ≠ 100; a drifted template default sailed through | The 15 ns mystery: requested 100 ns, got 15 ns, every report said 100 ns | S (conditional logic that silently skips the fix) | `_pin_ns_length()` unconditionally rewrites the template's NS_LENGTH default to the requested value, verified by grep; fails loudly if the pin doesn't land |
| 4 | **No verified-length check** — nothing parsed prod.log/.tpr to confirm what actually ran | Audit had to prove 7.5 M steps post-hoc from .tpr + prod.log | S/K (no post-run verification) | `ns_from_log()` parses nsteps from prod.log → verified ns; displayed in health_report H5 and live_dashboard VERIFIED LENGTH section; registry records both requested and verified |
| 5 | **Silent chain death** — prep job died in ~2 min; only an empty squeue hinted at it | Job 2031187 vanished with no error message | S (no stall/death detection) | `live_dashboard.sh` STALE check: flags an active stage log with no job running (died/killed); health_report detects stale logs (>600s old while not finished) |
| 6 | **Analysis/ + results/ written to repo root, not scripts/** — archive command initially missed them | The archive moved scripts/* but left analysis/ and results/ behind in the repo root | S (layout assumption — scripts/ is not the only output location) | `cmd_archive` explicitly moves both `analysis/` and `results/` from repo root + documents the layout in a comment |

---

## 7. New capabilities added (post-pilot)

| Capability | What it does | Why it matters |
|---|---|---|
| `./run_simulation.sh runs` | Shows the run registry (RUN_ID, profile, mode, requested vs verified ns, state, archive dir) | You can always see what runs happened and what they actually produced |
| `./run_simulation.sh archive` | Preserves a finished run into `archive/<RUN_ID>__<verified>ns/` before the next run | Prevents the flat-workspace overwrite; named from VERIFIED ns so the name is always truthful |
| `./run_simulation.sh extend --to N` | Continues a finished run from its checkpoint: convert-tpr -until N + mdrun -cpi prod.cpt | Extends 15 ns → 30 ns (or any length) without re-equilibration; no data loss; no re-running prep/equil |
| Verified-length display (H5 in health_report, VERIFIED LENGTH in dashboard) | Shows the ACTUAL ns from prod.log, flags mismatches with the requested ns | The 100-vs-15 naming bug cannot recur — the truth is always visible |
| New-run guard | Refuses `start --stage all` or `submit` while un-archived prod.* data exists | You must explicitly archive or extend before starting a fresh run |
| `doctor` extended | Now includes the static integrity checker (C1-C6) + live gmx probes | Pre-run gate catches repo problems and flag drift before burning a job |
| Energy sanity gates (E-class) | `gmx_energy_check()` asserts density ≈ 1000, P ≈ 1 bar, T ≈ 310 K after every extraction; wired into 02 and 04 | Wrong energy terms abort the job instead of corrupting figures |

---

## 8. What is still NOT prevented (known gaps)

1. **GPU partition still not working** — the ngs1gpu/ngs1gput partitions exist but no CUDA module loads; the GPU profile is a template. Until this is resolved, all runs are CPU-only at ~18 ns/day.
2. **Extend path has no SLURM submit** — `extend --submit` is not implemented; extension must run as an interactive foreground job (or a manually crafted sbatch). This is acceptable for now (extension is a manual step) but should be automated for routine 100 ns production.
3. **No automated replica management** — running 3× replicas requires 3 manual submits. A `--replicas N` flag that scaffolds multiple independent runs would help but is not implemented.
4. **No provenance chain from AF3 → PDB → TPR → XTC** — the AF3 model is stored but there's no machine-readable link listing which AF3 fold produced which PDB which produced which TPR. Adding a provenance manifest at predict time would close this.
5. **The 1 ns smoke test is not automated in CI** — CI runs static checks but not a real mdrun. A full end-to-end test requires GROMACS on the CI runner, which is not set up.

These are future work items, not current bugs. The pipeline is now **correct** for what it does; the gaps are about scope, not integrity.
