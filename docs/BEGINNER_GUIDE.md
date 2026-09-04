# GROMACS_NA53 — Beginner's Guide
## From "what is an aptamer?" to a finished simulation — with zero assumed knowledge

> **Who this is for:** anyone who wants to understand this repository but has never
> run a molecular dynamics (MD) simulation. No biology or chemistry background
> beyond high school is assumed. If you already know MD, you only need the main
> [README](../README.md) and the technical docs in `docs/`.
>
> **What you will get out of this guide:**
> 1. The big idea behind the project (10-minute read).
> 2. A map of every file and folder (what it is, why it exists).
> 3. A stage-by-stage explanation of the pipeline — *what* each command does,
>    *why* it exists, and *what good output looks like*.
> 4. Three ways to actually run it, with copy-paste commands.
> 5. A sanity checklist for reading the results.
> 6. What to do when something breaks.

**New terms appear in bold** the first time — every one is explained in plain
words in the [GLOSSARY](GLOSSARY.md).

---

## Part A — The big idea (10 minutes)

### A.1 What is an aptamer, and why do we care?

Your body (and every living cell) stores information in **DNA** — a long chain
made of four repeating building blocks (nucleotides): **A**, **C**, **G**, **T**.

Under the right conditions, a *single* strand of DNA doesn't stay flat and
straight — it folds into a specific **3-dimensional shape** (like a piece of
string crumpling into a particular tangle, but *reproducibly*). That folded
shape is what lets the strand do a job.

An **aptamer** is a short piece of single-stranded DNA (or RNA) — usually 20–100
nucleotides — that has been evolved/selected to fold into a shape that **sticks
to one specific target molecule**, the way a lock fits a key. Aptamers are the
"antibodies of the test tube": cheap to make, stable, and programmable.

**Our aptamer is NA53** — a 55-nucleotide DNA strand:

```
AGCAGCACAGAGGTCAGATGGCGCTGGATAGCAAGATCACGTTATCATCGTAAACCCTATGCGTGCTACCGTGAA
```

**Our target is NGAL** — a small human protein (~25 kDa) that appears in urine
and blood early during **kidney injury**. NGAL is a clinically important
biomarker: catch it early and doctors can act early.

**The biosensor idea:** if NA53 genuinely folds into a shape that binds NGAL,
you can build a sensor that "catches" NGAL out of a patient sample and reports
how much is there. But before building any hardware, we must know NA53's folded
3D shape — and that is extremely hard to measure experimentally for a short DNA
strand (X-ray crystallography and NMR are slow and expensive).

### A.2 What is a molecular dynamics (MD) simulation?

**MD simulation = a physics movie of your molecule.**

Here is the recipe:

1. Build a 3D model of your molecule (atoms = balls, bonds = springs).
2. Define the **rules of physics** the atoms obey — how strongly each pair of
   atom types attracts/repels, how stiff bonds are, etc. (This rulebook is the
   **force field**.)
3. Put the molecule in a **box of water** at body temperature (310.15 K ≈ 37 °C),
   with a little salt (0.15 M NaCl, like your blood).
4. Let a computer solve Newton's equations of motion (`F = ma`) for **every
   atom**, in tiny **2 femtosecond** time steps, millions of times in a row.
   Between steps, record the positions.

Each time step moves every atom forward by a tiny amount, exactly as physics
dictates. After enough steps you have a **trajectory** — a movie of how the
molecule wiggles, breathes, and folds over time.

**What MD is *not*:** it is not a random guess and it does not "know" biology.
It is a physics calculation. Its quality depends entirely on (a) a good starting
structure and (b) a good force field — which is why this repo spends so much
effort documenting and validating both.

### A.3 Why run it on a supercomputer?

A realistic system (DNA + ~15,000 water molecules + salt) contains **~35,000–
45,000 atoms**. Every time step is a calculation over every pair of nearby atoms.
One nanosecond of "movie" = 500,000 time steps. A useful run is 100+ nanoseconds.
That is trillions of calculations — hence the GPU workstation for test runs and
**Taiwania 3** (the Taiwanese national supercomputer, managed by NCHC) for the
real run. This repo is built so the *same* commands run on both.

### A.4 The pipeline in one sentence

> **Sequence → predicted 3D structure → atoms in a water box → calm the system
> down (equilibration) → simulate for a long time (production) → measure what
> happened (analysis) → make figures (visualization).**

The whole flow is divided into numbered "work packages" (00–05) that match the
numbered scripts. Each one consumes the previous one's output files — a strict
assembly line:

```
 00 PREDICT      01 PREP        02 EQUILIBRATE   03 PRODUCE        04 ANALYZE
 ──────────      ──────────     ─────────────    ────────────      ─────────────
 sequence ────▶ 3D model ─────▶ water box ─────▶ stable system ──▶ long movie ──▶
 (what we        (a .pdb         (atoms ready      (the system       (100+ ns of    figures
  know)           file)           to move)          relaxes,          trajectory)    & numbers
                                                     stepwise)
```

**Kitchen analogy** (used throughout this guide):
- **00 Predict** = writing the recipe from memory.
- **01 Prep** = buying ingredients, measuring them into bowls.
- **02 Equilibrate** = preheating the oven slowly (so the cake doesn't crack).
- **03 Produce** = baking for real.
- **04/05 Analyze** = tasting, photographing, and writing up.

---

## Part B — The repository map

```
GROMACS_NA53/
│
├── README.md               ← START HERE (this project's front page)
├── PRD.md                  ← "Product Requirements": what we are building & why
├── architecture.md         ← How the pieces connect (data flow, tech stack)
├── rules.md                ← Golden rules for anyone (human or AI) touching this repo
├── phases.md               ← The 12-phase project plan (P0–P11)
├── design.md               ← Visual identity: colors, fonts, figure style
├── memory.md               ← Live log: what's done, what's next, verified facts
├── environment.yml         ← The exact software list (conda) for reproducing the env
├── .gitignore              ← Files git must NOT track (big trajectory files, etc.)
├── .github/workflows/      ← Automated checks that run on every git push
├── run_simulation.sh       ← ⭐ The "launcher": one command to run/monitor the pipeline
│
├── structures/             ← 3D starting structures (the .pdb input lives here)
├── system/                 ← Processed/boxed/solvated/ionized system files
├── equilibration/          ← Energy-minimization & equilibration outputs
├── production/             ← Production trajectory files
├── analysis/               ← Numbers extracted from the trajectory (.xvg files)
├── results/figures/        ← Final publication-style plots (.png)
├── logs/                   ← Every step logs here + run_status.txt (the run trail)
│
├── configs/                ← GROMACS "settings files" (.mdp) — one per stage
│     em.mdp                ←   settings for energy minimization
│     ions.mdp              ←   settings for adding salt ions
│     nvt.mdp               ←   settings for the NVT equilibration step
│     npt.mdp               ←   settings for the NPT equilibration step (restrained)
│     npt_free.mdp          ←   settings for NPT with restraints released
│     prod.mdp              ←   settings for the long production run
│
├── scripts/                ← The numbered stage scripts (the assembly line)
│     00_predict_structure.sh    ← sequence → secondary structure hints
│     01_system_prep.sh          ← .pdb → topology + water box + ions
│     02_equilibration.sh        ← EM → NVT → NPT1 → NPT2
│     03_production.sh           ← the long MD run
│     04_analysis.sh             ← extract RMSD, H-bonds, PCA, clusters, ...
│     05_visualization.py        ← turn .xvg numbers into .png figures
│     run_pipeline.sh            ← runs 01→05 back-to-back (older runner)
│     check_repo_integrity.sh    ← "is the repo healthy?" static checks
│     health_report.sh           ← engine + integrity + KPIs, one screen
│     probe_gmx_compat.sh        ← checks the installed GROMACS understands our commands
│
├── slurm/                  ← Job scripts for the Taiwania 3 supercomputer
│     setup_taiwania3.sh    ← one-time environment setup on Taiwania 3
│     01_prep.sbatch … 04_analysis.sbatch  ← one job per pipeline stage
│
├── profiles/               ← Machine settings (which computer, which GROMACS)
│     local_gpu.env         ←   your own GPU workstation
│     taiwania3_cpu.env     ←   Taiwania 3 CPU partition (✅ verified)
│     taiwania3_gpu.env / taiwania2_twai_gpu.env  ← GPU templates (⚠️ fill in)
│
├── docs/                   ← All the documentation (this file lives here)
│     01_PROJECT_CHARTER.md … 06_KPI_DASHBOARD.md   ← the 6 management docs
│     INCIDENT_ANALYSIS.md      ← every bug ever found + how it's prevented
│     LESSONS_LEARNED_FROM_TRIAL_RUNS.md
│     HPC_GPU_OPTIONS.md        ← supercomputer GPU options, researched
│     APTAMD_DEEP_ANALYSIS.md   ← comparison with a published aptamer-MD protocol
│     REFERENCES.md             ← master list of every source used (audited)
│     GLOSSARY.md               ← plain-language dictionary of terms
│     BEGINNER_GUIDE.md         ← ⭐ the file you are reading
│
└── research/               ← The "literature wing": how we study papers rigorously
      WORKFLOW.md                ← the research procedure
      reports/                   ← finished literature reports
      REFERENCES.md              ← ledger of actually-opened sources
      scripts/s2_search.py       ← search scholarly papers (no API key needed)
```

> **Work-location note:** the numbered scripts are executed *from inside*
> `scripts/`, so most working files (e.g. `topol.top`, `*_ionized.gro`,
> `prod.xtc`) are produced right there in `scripts/`. Analysis numbers go to
> `../analysis/` and figures to `../results/figures/`. If you ever wonder what
> happened, read `logs/run_status.txt` — the launcher writes one line per event.

---

## Part C — The pipeline, stage by stage

### C.0 Stage 00 — Predict (`00_predict_structure.sh`)

**What it does.** Takes the NA53 sequence and predicts its **secondary
structure** — the local folding pattern (which regions pair with which, e.g.
stem-loops) — using `seqfold` (or RNAfold as a fallback).

**What it does *not* do.** It refuses to invent a fake 3D structure. Producing a
real all-atom 3D model of a 75-nt DNA aptamer is genuinely hard (that is a big
part of the science), so the script **fails loudly with instructions** rather
than silently writing a wrong `.pdb`. Honest failure is a design principle of
this repo (see `rules.md`).

**Realistic 3D model sources** (external tools, all documented in
`docs/REFERENCES.md` and the research reports): w3DNA / 3dDNA (build B-form DNA
helix models from sequence), AptaFold, and AlphaFold 3 — each with caveats.

**Inputs / Outputs**

| | File | Meaning |
|---|---|---|
| in | (NA53 sequence, hard-coded default) | our 75 nt |
| out | `structures/NA53_secondary.dbn` | dot-bracket notation: `(((...)))` shows pairing |
| out | `structures/NA53.fasta` | sequence in FASTA format |
| required | `structures/NA53_initial.pdb` | **the real 3D starting structure** — see box below |

> ⚠️ **The one missing ingredient.** As of 2026-09-04 the *real* NA53 3D model
> has not been placed in `structures/NA53_initial.pdb` yet — it is the project's
> single remaining required input. The pipeline was fully tested end-to-end with
> a stand-in structure (a 12-base-pair DNA duplex from the PDB, entry 1BNA) to
> prove the machinery works. To run the *real* simulation, drop a genuine NA53
> 3D model at `structures/NA53_initial.pdb` and rerun. Every script then works
> unchanged.

---

### C.1 Stage 01 — System prep (`01_system_prep.sh`)

**Goal:** turn one bare DNA structure into a complete, physics-ready "universe":
DNA + water + salt, with a rulebook (topology) describing every atom.

It runs **4 GROMACS sub-tools** in order. Each is one step of the recipe:

```
  pdb2gmx        editconf          solvate           genion
 ─────────      ──────────        ──────────        ─────────
 DNA .pdb   →   put DNA in a  →   flood box    →   replace some water
 + force        box with room     with water        with Na+/Cl- ions
 field rulebook (1.2 nm margin)   molecules         (0.15 M, neutral charge)
 ─────────      ──────────        ──────────        ─────────
 topol.top      *_boxed.gro       *_solvated.gro    *_ionized.gro
```

| Step | Tool | What happens | Why it matters |
|---|---|---|---|
| 1 | `gmx pdb2gmx` | Reads the `.pdb`, adds missing hydrogens, and writes the **topology** (`topol.top`) — the force-field rulebook describing every atom, bond, and charge. | Without the topology, GROMACS doesn't know the physics. |
| 2 | `gmx editconf` | Defines the simulation **box** — a dodecahedron with ≥1.2 nm of space between the DNA and the box wall. | Atoms must never "feel" the box edge. Space = room to move; the dodecahedron shape wastes the least water. |
| 3 | `gmx solvate` | Fills the box with pre-equilibrated TIP3P water molecules. | Biology happens in water; DNA is only stable in water. |
| 4 | `gmx genion` | Swaps some water molecules for Na+ and Cl- ions to reach **0.15 M NaCl** and **zero net charge**. | (a) Real biological conditions; (b) the simulation math (PME, see Glossary) demands a neutral box. |

**Force field choice (default).** `amber99sb-ildn` for the DNA + `tip3p` for
water — a widely used, well-validated combination that GROMACS ships with. Our
literature research recommends evaluating a DNA-specialist upgrade (`parmbsc1`,
which fixes known DNA backbone artifacts in long simulations) — that is a
tracked, documented decision, not yet applied.

**Inputs / Outputs** (run from `scripts/`)

| | File | Meaning |
|---|---|---|
| in | `../structures/NA53_initial.pdb` | the 3D structure from stage 00 |
| out | `topol.top` (+ `*.itp`) | topology rulebook |
| out | `NA53_processed.gro` → `NA53_boxed.gro` → `NA53_solvated.gro` → `NA53_ionized.gro` | the system at each step |
| sanity | ~22,000 atoms for the small test duplex; ~45–65k for real 75-nt NA53 | more atoms = longer compute |

---

### C.2 Stage 02 — Equilibration (`02_equilibration.sh`)

**Goal:** take the freshly built system (which contains *unphysical* starting
conditions — water overlapping the DNA, bad angles) and gently bring it to the
target temperature and pressure **without blowing it up**.

If you started the production run immediately, the enormous initial forces
would explode the simulation (atoms flying apart → "NaN" errors). Equilibration
ramps up gradually, in 4 sub-stages:

```
 EM             NVT (100 ps)         NPT1 (100 ps)         NPT2 (500 ps)
 ─────────      ──────────────       ──────────────        ───────────────
 remove         heat to 310 K        fix volume→           release the
 bad contacts   at fixed volume      allow pressure        restraints,
 (minimize      (DNA gently          to reach 1 bar        let the system
  energy)        held in place)      (DNA still held)      fully relax
```

| Sub-stage | Full name | What happens | Success check |
|---|---|---|---|
| **EM** | Energy minimization | Slides atoms downhill on the energy landscape (steepest descent) to remove bad overlaps. No temperature yet. | Force < 1000 kJ/mol/nm (`em.log`) |
| **NVT** | constant **N**umber, **V**olume, **T**emperature | Heats the system to 310.15 K. The DNA is held in place with **position restraints** (weak springs) so it doesn't flail while the water warms. | Temperature stable at 310 ± 2 K |
| **NPT1** | constant **N**, **P**ressure, **T**emperature | Turns on the barostat so the box volume can adjust to reach 1 bar. DNA still restrained. | Density ≈ 1000 kg/m3; pressure ≈ 1 bar |
| **NPT2** | NPT, restraints released | Removes the springs. The DNA is free — this is the final "pre-flight" check that it survives on its own. | Everything stable; this structure seeds production |

**Why "NVT" and "NPT"?** In a real experiment you control temperature and
pressure (they're measurable). MD uses mathematical "couplers" — the thermostat
(V-rescale) keeps temperature at 310.15 K, the barostat (Parrinello–Rahman)
keeps pressure at 1.0 bar. The letter codes just state which quantities stay
constant. (Full definitions: GLOSSARY.)

**Outputs:** `em.gro`, `nvt.gro`, `npt1.gro`, `npt2.gro` — each one a valid
starting point for the next stage. The final one, **`npt2.gro`, is the exact
system state that production continues from** (that continuity is why results
are trustworthy).

---

### C.3 Stage 03 — Production (`03_production.sh`)

**Goal:** the actual experiment — an **unrestrained NPT run** at 310.15 K and
1 bar for a long time (target ≥100 ns), recording a compressed movie
(`prod.xtc`) of the DNA's every move.

Key settings (all in `configs/prod.mdp`, each carrying a ✅ VALIDATED comment —
these values were proven in a 200 ns control run):

| Setting | Value | Plain meaning |
|---|---|---|
| Time step | 0.002 ps (2 fs) | fine enough to be accurate, big enough to finish |
| Cutoffs | 0.8 nm, Verlet scheme | only atoms within 0.8 nm interact directly |
| Long-range electrostatics | PME | charged atoms far apart still feel each other (correctly, and fast) |
| Temperature | 310.15 K (V-rescale) | body temperature, held constant |
| Pressure | 1.0 bar (Parrinello–Rahman) | ambient pressure, held constant |
| H-bonds | constrained (LINCS) | allows the 2 fs step safely |
| Recording | trajectory every 10 ps; energy every 10 ps | small, manageable files |
| Checkpoint | every 15 min | if the job dies, restart from the last checkpoint (costs ≤15 min, not the whole run) |

**Outputs:** `prod.tpr` (the run's "input binary" — the exact system + settings,
so runs are reproducible), `prod.xtc` (trajectory movie), `prod.edr`
(energy log), `prod.cpt` (checkpoint), `prod.log` (detailed diary).

**Timing reality check** (measured on our test system):
- Workstation GPU test (22k atoms, 1 ns): **~5–6 minutes**.
- Taiwania 3 CPU (real 75-nt system, ~45–65k atoms): **measure ns/day from the smoke run** (planning band ~15–45 ns/day on 56 AVX2 cores; 100 ns ≈ 2–6 days wall → checkpointed)
  → 100 ns ≈ 1.5–2.5 days, inside the 4-day partition limit. If the queue
  kills the job at the wall-time, restart with `RESTART=1` — it resumes from the
  checkpoint automatically.

---

### C.4 Stage 04 + 05 — Analysis & visualization

**Goal:** turn the raw movie into *meaningful biology*: numbers (`.xvg` files)
and publication-quality figures (`.png`).

| Analysis | Tool | Question it answers | Biosensing relevance |
|---|---|---|---|
| **RMSD** | `gmx rms` | "How far has the structure drifted from where it started?" | Flat, converged RMSD = the fold is stable |
| **RMSF** | `gmx rmsf` | "Which parts wiggle the most?" | Flexible loops often = the binding site |
| **Rg** (radius of gyration) | `gmx gyrate` | "How compact/spread out is the molecule?" | folded (compact) vs unfolded (extended) |
| **H-bonds** | `gmx hbond` | "How many hydrogen bonds hold the structure together?" | base-pairing stability |
| **SASA** | `gmx sasa` | "How much surface is exposed to water?" | folding/aggregation proxy |
| **PCA** | `gmx covar` + `anaeig` | "What are the dominant large-scale motions?" | conformational switching (the sensor mechanism!) |
| **Clustering** | `gmx cluster` | "What are the most common shapes visited?" | dominant binding-competent conformations |
| **Free-energy landscape** | 2D histogram of PCA axes | "Energy valleys = stable states, hills = barriers" | folding funnel topology |

**Outputs:** `analysis/{rmsd,rmsf,gyrate,hbnum,sasa,proj,clusters}.xvg`
(numbers) → `results/figures/*.png` (8 figures).

**The 30-second sanity check:** for the *test duplex* (12 base pairs, ~30
Watson–Crick bonds), intra-DNA H-bond count should sit around 30–40. It did —
which is how we know the analyses measure the DNA and not the water (a real bug
was once found here; see `docs/INCIDENT_ANALYSIS.md`, class G).

---

## Part D — Running it (three ways)

### Before anything: one-time environment

```bash
# Local (GPU workstation) — needs GROMACS 2025.3+ and conda:
bash scripts/install_dependencies.sh          # or install_gromacs_gpu.sh

# Taiwania 3 (first login only):
bash slurm/setup_taiwania3.sh https://github.com/CliffVale/GROMACS_NA53.git
conda activate na53_aptamer                   # GROMACS 2024.4 lives in this env
```

### The launcher (recommended for everyone)

`run_simulation.sh` is a friendly wrapper that knows which computer you are on
and runs the whole chain with safety gates between stages. Its commands:

| Command | What it does | Beginner translation |
|---|---|---|
| `./run_simulation.sh profile` | show/choose the machine profile | "tell me which computer I'm configured for" |
| `./run_simulation.sh doctor` | pre-flight health check | "check everything before I burn hours of compute" — **mandatory** |
| `./run_simulation.sh start --ns 1` | run the full pipeline now | "do a 1 ns smoke test" (add `--stage equil` etc. to run only part) |
| `./run_simulation.sh submit` | submit to the supercomputer queue | "put my jobs in the SLURM queue with dependencies" |
| `./run_simulation.sh status` | one-screen snapshot | "what's happening right now?" (includes a health report) |
| `./run_simulation.sh monitor` | live follow | "watch the log grow, live" |

Example — full smoke test on your own GPU machine:

```bash
./run_simulation.sh doctor --profile local_gpu     # 1. pre-flight
./run_simulation.sh start --profile local_gpu --ns 1 --stage all   # 2. tiny run
./run_simulation.sh status                         # 3. look at the results
```

Example — the real thing on Taiwania 3:

```bash
./run_simulation.sh profile --set taiwania3_cpu    # pick the verified profile
./run_simulation.sh doctor                         # pre-flight on the cluster
./run_simulation.sh submit --profile taiwania3_cpu # chain 01→02→03→04 via SLURM
./run_simulation.sh status                         # snapshot anytime
```

### Manual mode (educational — what the launcher does under the hood)

From inside `scripts/`:

```bash
bash 00_predict_structure.sh                                   # stage 00
bash 01_system_prep.sh ../structures/NA53_initial.pdb          # stage 01
bash 02_equilibration.sh ../system/*_ionized.gro -nb auto      # stage 02
bash 03_production.sh -nb auto 100                             # stage 03 (100 ns)
bash 04_analysis.sh prod 0                                     # stage 04
python3 05_visualization.py ../analysis                        # stage 05
```

(`-nb auto` = "use the GPU if present, otherwise the CPU" — safe everywhere.)

### On the supercomputer, manually (SLURM)

```bash
cd slurm/
sbatch 01_prep.sbatch      # wait for it to finish, then…
sbatch 02_equil.sbatch     # wait, then…
sbatch 03_prod.sbatch      # RESTART=1 sbatch 03_prod.sbatch to resume after a kill
sbatch 04_analysis.sbatch
```

---

## Part E — Reading the results (sanity checklist)

Good science = checking *every* stage looks right before trusting the next:

| Check | Where | Healthy sign | Red flag |
|---|---|---|---|
| Energy minimized | `em.log` | max force < 1000 kJ/mol/nm | "did not converge" |
| Temperature | `nvt.log` / KPI report | 310 ± 2 K, flat | drift, oscillation |
| Pressure / density | `npt*.log` / KPI report | ~1 bar, ~1000 kg/m3 | box collapsing/exploding |
| Restraints released cleanly | `npt2` → `prod` handoff | no jump in energy/RMSD | sudden distortion |
| Production progressing | `prod.log` / `./run_simulation.sh monitor` | steady ns/day, growing `.xtc` | "NaN", crash, 0 ns/day |
| Structure stayed sane | `analysis/rmsd.xvg` | plateaus (converged) | never stops climbing |
| Physics plausible | H-bond count, Rg | H-bonds ≈ expected for the fold | wildly off |
| Job health | `./run_simulation.sh status` | all ✅ H1–H4 | ⚠️/❌ with reason |

---

## Part F — When something breaks

1. **Don't guess.** Every stage writes a log into `logs/` (`pdb2gmx.log`,
   `mdrun_nvt.log`, …). Read the *last 30 lines* of the failing log.
2. **Run the doctor:** `./run_simulation.sh doctor` — it checks repo integrity
   and that your installed GROMACS understands every command the pipeline uses
   (GROMACS versions change command syntax!).
3. **Check the run trail:** `cat logs/run_status.txt` — each stage logs
   `start … ok` or the failure point.
4. **Common fixes** (full table in the README → Troubleshooting):
   - `gmx: command not found` → `conda activate na53_aptamer`
   - Job killed at wall-time → `cd slurm && RESTART=1 sbatch 03_prod.sbatch`
     (resumes from checkpoint)
   - `Fatal error: GPU` → you are on a CPU machine; use `-nb auto`, never
     `-nb gpu`
   - `pdb2gmx` fails → the PDB must use DNA residue names (DA/DT/DG/DC), not
     protein ones (A/T/G/C)
5. **Still stuck?** The full history of every bug ever hit — and the prevention
   for each class — is in `docs/INCIDENT_ANALYSIS.md`. It reads like a
   "things that will go wrong and why they can't anymore" manual.

---

## Part G — Where the project records live & next steps

| To know… | Read |
|---|---|
| What we're building & KPIs | `PRD.md` |
| How the pieces fit / tech stack | `architecture.md` |
| Rules for safe changes | `rules.md` |
| Project phase plan | `phases.md` |
| What's done / in progress | `memory.md` |
| The science decisions & evidence | `docs/01_…`–`docs/06_…`, `research/reports/` |
| Every source used (audited) | `docs/REFERENCES.md` |

**The honest current state** (from `memory.md`, 2026-09-04): the entire
machinery is built, debugged, CI-protected, and proven end-to-end with a test
structure. **The single remaining step for the real science** is obtaining a
genuine 3D model of NA53 (via AlphaFold 3, w3DNA/3dDNA, or an experimental
structure) and placing it at `structures/NA53_initial.pdb` — then launching the
real run on Taiwania 3.

---

*Part of the GROMACS_NA53 documentation set — plain-language companion to the
[README](../README.md) and the [GLOSSARY](GLOSSARY.md). Written 2026-09-04; all
parameters and timings are quoted from the repo's verified records
(`configs/*.mdp`, `memory.md`, `docs/INCIDENT_ANALYSIS.md`), not from memory.*
