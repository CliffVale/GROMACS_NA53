# GROMACS_NA53 — Glossary
## Every term used in this project, explained in plain language

> Companion to [BEGINNER_GUIDE.md](BEGINNER_GUIDE.md). Terms are alphabetical.
> Each entry gives the **plain meaning**, then **why it matters here**. Where a
> term maps to a real file or value in this repo, that is named so you can go
> look at the actual thing.

---

### A

**Aptamer** — A short piece of single-stranded DNA or RNA (usually 20–100
nucleotides) that folds into a specific 3D shape and binds one target molecule
selectively. Ours is **NA53** (75-nt DNA) targeting **NGAL**. *Why it matters:
the whole project exists to predict NA53's folded shape for a biosensor.*

**All-atom** — A simulation in which every single atom (including every
hydrogen) is modeled explicitly. *Why it matters: the most accurate (and most
expensive) kind of MD; used throughout this pipeline.*

### B

**Barostat** — The mathematical device that keeps **pressure** constant during a
simulation (like a thermostat does for temperature). This repo uses
**Parrinello–Rahman** at 1.0 bar (see `configs/prod.mdp`). *Why it matters: real
experiments run at ambient pressure; matching it makes the simulation physical.*

**Biomarker** — A measurable molecule in the body whose level signals a
condition. **NGAL** rises early in kidney injury, making it a valuable
diagnostic biomarker. *Why it matters: it is the "target" our aptamer sensor
must catch.*

**Box (simulation box)** — The imaginary container that holds the system (DNA +
water + ions). This repo uses a **dodecahedron** with ≥1.2 nm padding between
solute and wall (`scripts/01_system_prep.sh`). *Why it matters: with periodic
boundary conditions, atoms near one wall interact with atoms near the opposite
wall, so the box behaves like an infinite fluid — but only if it is big enough
that the DNA never "sees" its own periodic image.*

**bsc1 / parmbsc1** — A refined DNA force field (Ivani et al., *Nat. Methods*
2016) that fixes backbone-angle artifacts found in older force fields during
long simulations. *Why it matters: our literature review (report
`research/reports/2026-09-04-aptamer-bibliography-analysis.md`) recommends
evaluating a switch to it; the pipeline currently runs `amber99sb-ildn` and the
switch is a tracked decision.*

### C

**Checkpoint (`.cpt`)** — A file (`prod.cpt`) GROMACS writes every 15 minutes
with the full system state. *Why it matters: if a supercomputer job is killed at
the wall-time limit, the run resumes from the checkpoint with `RESTART=1`
instead of restarting from zero.*

**CI (Continuous Integration)** — Automated checks that run on GitHub every time
code is pushed (`.github/workflows/validate.yml`). *Why it matters: it catches
broken scripts before they ever reach the supercomputer.*

**Cluster / clustering** — In analysis: grouping the thousands of trajectory
frames into a few "families" of similar shapes, then reporting the most
populated ones. *Why it matters: it answers "which shapes does the aptamer
actually adopt most of the time?" — the binding-competent conformations.*

**Constraints vs. restraints** — Both limit motion but differently:
**constraints** (LINCS) rigidly fix bond lengths (e.g. all H-bonds) so a bigger
time step is safe; **restraints** (position restraints, `-DPOSRES`) attach weak
springs that *gently hold* atoms near their starting place during equilibration,
then are removed. *Why it matters: constraints make the run faster; restraints
protect the DNA while the water settles.*

**Cutoff** — The distance beyond which two atoms no longer interact directly.
Here 0.8 nm for both electrostatics and van der Waals, with the Verlet scheme
(`configs/*.mdp`, ✅ VALIDATED). *Why it matters: computing every atom pair is
impossible; cutoffs make the calculation feasible — but long-range
electrostatics still need PME to stay accurate.*

### D

**DNA** — Deoxyribonucleic acid: a chain of four nucleotide building blocks
(A, C, G, T). In cells it stores genetic information; here a **single strand**
is used as a folding molecule (the aptamer).

**Doctor** — `./run_simulation.sh doctor`: the pre-flight health check that must
run before any real run. It verifies repo integrity *and* probes the installed
GROMACS to confirm it understands every command the pipeline uses. *Why it
matters: GROMACS versions silently change command syntax; doctor catches that
before you waste compute hours (see `docs/INCIDENT_ANALYSIS.md`).*

**Dodecahedron** — A 12-faced box shape. *Why it matters: for a given amount of
water it is the "roundest" (most sphere-like) tiling shape, so it wastes the
least volume on corners — fewer water molecules, faster runs.*

**Dot-bracket notation** — A text way to write secondary structure:
`(((...)))` where `(` marks a paired base and `.` an unpaired one
(e.g. `NA53_secondary.dbn`). *Why it matters: a compact, standard way to record
which parts of the aptamer pair up.*

### E

**EDR (`.edr`)** — GROMACS's energy file: every energy term (kinetic, potential,
temperature, pressure…) at every reporting step. *Why it matters: the raw data
behind the "is the system stable?" checks.*

**Electrostatics** — Forces between charged parts of atoms (positive attracts
negative). Long-range electrostatics are handled with **PME** here. *Why it
matters: DNA is highly charged (negative backbone); getting electrostatics right
is the single most important accuracy choice in nucleic-acid simulation.*

**EM (Energy minimization)** — Stage 02's first step: a "relaxation" that slides
atoms downhill in energy to remove bad overlaps created while building the box.
No temperature yet. *Why it matters: starting production MD with bad contacts
would explode the simulation instantly.*

**Ensemble** — The set of physical conditions held constant during a run. See
**NVT** and **NPT**. *Why it matters: the ensemble defines what experiment you
are mimicking.*

**Equilibration** — The gradual "warm-up" (EM → NVT → NPT1 → NPT2) that brings a
freshly built system to the target temperature and pressure without shocks.
*Why it matters: it separates "settling the water" from "real dynamics", so the
production data measures biology, not setup artifacts.*

### F

**FASTA** — The standard plain-text format for sequences: a `>` header line,
then the letters (e.g. `structures/NA53.fasta`). *Why it matters: the universal
input format for sequence tools.*

**FEL (Free Energy Landscape)** — A 2D energy map (often built from PCA
projections) showing valleys (stable states) and hills (barriers).
`results/figures/fel_2d.png`. *Why it matters: it shows the folding funnel — does
NA53 have one dominant stable shape (good for a sensor) or many?*

**Force field** — The "physics rulebook": the equations and parameters that
define how every atom type bonds, bends, and attracts/repels others. Ours:
`amber99sb-ildn` for DNA + `tip3p` for water. *Why it matters: MD is only as
good as its rulebook — this is why the choice is documented and why the
literature recommends evaluating `parmbsc1`.*

**Femtosecond (fs)** — 10⁻¹⁵ seconds. Our time step is 2 fs = 0.002 ps. *Why it
matters: atomic vibrations happen on this timescale; the step must be small
enough to resolve them.*

### G

**genion** — The GROMACS tool that replaces some water molecules with ions
(Na⁺/Cl⁻) to reach 0.15 M NaCl and neutral charge (stage 01, step 4). *Why it
matters: biological salt concentration + charge neutrality (required by PME).*

**GROMACS** — The free, open-source molecular dynamics engine this whole project
runs on. Version 2024.4 on Taiwania 3 (conda), 2025.3 on the local GPU build.
*Why it matters: it provides both the engine (`mdrun`) and the analysis tools.*

**grompp** — GROMACS's "compiler": it merges the topology (`topol.top`), the
structure, and a settings file (`.mdp`) into a run input (`.tpr`). *Why it
matters: the `.tpr` is the single source of truth for a run — reproducible and
self-describing.*

**gro (`.gro`)** — GROMACS's structure file format: atom coordinates (and
velocities) in a simple text table. *Why it matters: the format the pipeline
uses to pass structures between stages (`*_processed.gro` → `*_ionized.gro` →
`npt2.gro`).*

### H

**H-bond (hydrogen bond)** — A weak directional attraction between an
electronegative atom, a hydrogen, and another electronegative atom. *Why it
matters: H-bonds hold DNA base pairs together (Watson–Crick) — counting them
(`hbnum.xvg`) tells you if the duplex/fold is intact.*

### I

**Ions** — Charged atoms/molecules dissolved in the water (Na⁺, Cl⁻). *Why it
matters: DNA's backbone is negative; ions screen it and are required for stable
DNA simulations — at 0.15 M to mimic biology.*

**itp (`.itp`)** — "Include topology parameter" files: the force-field
parameter blocks `#include`d by the main topology. *Why it matters: keeps the
rulebook modular.*

### K

**KPI** — Key Performance Indicator. In this project: ns/day (speed), storage
per nanosecond, energy drift, temperature/pressure stability — reported by
`./run_simulation.sh status` / `monitor` via `scripts/health_report.sh`. *Why it
matters: the "dashboards" that tell you a running job is healthy or dying.*

### L

**LINCS** — The algorithm that constrains bond lengths (especially H-bonds). *Why
it matters: lets us use a 2 fs time step safely — bonds vibrating at higher
frequency would otherwise force a much smaller (10× slower) step.*

**Log (`.log`)** — GROMACS writes a detailed text diary of every run
(`prod.log`, `mdrun_nvt.log`…). *Why it matters: the first place to look when
something fails or when checking convergence (max force, temperature drift…).*

### M

**mdp (`.mdp`)** — "Molecular dynamics parameters": the plain-text settings file
for one stage (in `configs/`: `em.mdp`, `nvt.mdp`, `npt.mdp`, `npt_free.mdp`,
`prod.mdp`, `ions.mdp`). *Why it matters: all the physics choices (temperature,
pressure, cutoffs, what to record) live here — documented with ✅ VALIDATED
comments.*

**mdrun** — The GROMACS engine itself: executes the run defined by the `.tpr`
and writes trajectory/energy/log files. *Why it matters: this is the long,
compute-heavy step that runs on GPUs / supercomputer nodes.*

**MD (Molecular Dynamics)** — See BEGINNER_GUIDE §A.2: a physics simulation of
atoms moving under Newton's laws.

**Molar (M)** — Concentration unit: moles per liter. 0.15 M NaCl ≈ blood salt
level. *Why it matters: physiological ionic strength stabilizes real DNA.*

### N

**NaN / blow-up** — A simulation failure where a number becomes "Not a Number"
(energies explode). *Why it matters: the classic symptom of bad starting
conditions — which is exactly what the equilibration stages exist to prevent.*

**Nanosecond (ns)** — 10⁻⁹ seconds. Runs are measured in ns (target ≥100 ns);
speed in ns/day. *Why it matters: useful DNA motions take tens to hundreds of ns
— hence supercomputers.*

**ns/day** — The performance metric: how many nanoseconds of simulation the
hardware completes per wall-clock day. *Why it matters: predicts job duration
(see KPI/health reports).*

**NPT** — An ensemble with constant **N**umber of particles, **P**ressure, and
**T**emperature. *Why it matters: production MD runs NPT at 310.15 K, 1.0 bar —
matching real experimental conditions (open container at body temperature).*

**Nucleotide** — The building block of DNA/RNA (A/C/G/T for DNA). NA53 is 55
nucleotides long. *Why it matters: aptamer length is counted in nucleotides.*

**NVT** — An ensemble with constant **N**umber, **V**olume, and **T**emperature
(heating step before pressure is switched on). *Why it matters: the first
equilibration stage warms the water with the DNA restrained.*

### O

**OPLS / GROMOS / AMBER / CHARMM** — Families of force fields (different
"rulebook" traditions). This project uses an **AMBER-family** force field
(`amber99sb-ildn`), which is the best-validated family for DNA. *Why it matters:
mixing families (e.g. building the DNA with AMBER but a ligand with OPLS) causes
subtle errors — the rules (`rules.md`) forbid it.*

### P

**Padding** — The empty space left between the molecule and the box wall
(1.2 nm). *Why it matters: prevents the molecule from interacting with its own
periodic image across the box boundary.*

**Parrinello–Rahman** — The barostat used here (pressure coupling at 1.0 bar,
τ = 2 ps) during NPT and production. *Why it matters: allows the box volume to
change so pressure equilibrates realistically.*

**PBC (Periodic Boundary Conditions)** — The trick of wrapping the box like
Pac-Man: an atom leaving the right side enters from the left. *Why it matters:
simulates an infinite, bulk-like fluid with a finite number of atoms.*

**PCA (Principal Component Analysis)** — A math method that finds the dominant
large-scale motions in the trajectory (via `gmx covar`/`anaeig`), compressing
thousands of atom motions into a few "modes". *Why it matters: reveals the big
conformational motions — e.g. an aptamer opening/closing like a hinge — and
feeds the free-energy landscape.*

**pdb2gmx** — The tool that reads a `.pdb`, adds hydrogens, and writes the
topology (stage 01, step 1). *Why it matters: the first and most error-prone
step — a malformed PDB (e.g. wrong residue names) fails here.*

**PDB (file, `.pdb`)** — The standard text format for 3D structures of
biomolecules. `structures/NA53_initial.pdb` is the required input. *Why it
matters: the starting 3D model everything else builds on.*

**PME (Particle Mesh Ewald)** — The fast, accurate method used for long-range
electrostatics (order 4, spacing 0.12 nm). *Why it matters: without it, charged
DNA in water would be computed incorrectly or too slowly. Note: PME requires a
charge-neutral box — one reason ions are added.*

**Position restraints** — See **constraints vs. restraints**.

**Production run** — The long, unrestrained NPT simulation (stage 03) that
produces the data actually analyzed. *Why it matters: the "real experiment".*

**Profile** — A small settings file (`profiles/*.env`) that tells the launcher
which machine you're on, where GROMACS is, and (for clusters) which SLURM queue
to use. *Why it matters: one repo, many machines — the same command works
locally and on Taiwania 3.*

### R

**Rg (radius of gyration)** — A single number describing how spread out the
molecule is (like the average distance of atoms from the center). *Why it
matters: distinguishes compact (folded) from extended (unfolded) states
(`gyrate.xvg`).*

**RMSD** — Root-mean-square deviation: "on average, how far is the current
shape from a reference shape?" (usually the starting structure, in nm). *Why it
matters: if RMSD rises forever, the structure is unstable/unfolding; if it
plateaus, the fold is stable (`rmsd.xvg`).*

**RMSF** — Root-mean-square fluctuation: "how much does *each residue* wiggle
around its average position?" *Why it matters: pinpoints flexible regions —
often the loops that bind the target (`rmsf.xvg`).*

**Restart / resume** — Continuing a run from a checkpoint after an interruption.
On Taiwania 3: `RESTART=1 sbatch slurm/03_prod.sbatch`. *Why it matters: wall-time
kills are normal on shared clusters; checkpoints make them cost ≤15 minutes.*

### S

**SASA** — Solvent-Accessible Surface Area: how much of the molecule's surface
touches water. *Why it matters: changes in SASA track folding/unfolding and
aggregation (`sasa.xvg`).*

**Secondary structure** — The local pairing pattern of the strand (stems,
loops), written in dot-bracket notation. *Why it matters: the intermediate step
between sequence and 3D shape (stage 00).*

**SLURM** — The job scheduler on Taiwania 3: you submit a job with `sbatch`, it
runs when nodes are free; `squeue` shows the queue. *Why it matters: the
"traffic controller" for supercomputer time.*

**Solvate** — The tool that fills the box with water (stage 01, step 3). *Why it
matters: explicit water is required for realistic DNA behavior.*

**ssDNA** — Single-stranded DNA. NA53 is ssDNA (it folds on its own, unlike the
famous double helix). *Why it matters: folding a single strand is harder to
predict than a duplex — the core scientific challenge here.*

### T

**Thermostat** — The mathematical device that keeps **temperature** constant
(here **V-rescale**, τ = 0.1 ps, at 310.15 K). *Why it matters: mimics contact
with a heat bath at body temperature.*

**Time step** — The interval between simulation steps (2 fs here). *Why it
matters: smaller = more accurate but slower; 2 fs with LINCS-constrained bonds is
the standard compromise.*

**TIP3P** — The water model used (3-site water: one O, two H). *Why it matters:
water is half the system; the water model must be compatible with the force
field — TIP3P is the standard AMBER companion.*

**Topology (`topol.top`)** — The master rulebook file listing every atom, bond,
angle, and charge in the system. *Why it matters: `grompp` compiles it with the
settings into the run file; a wrong topology = wrong physics.*

**tpr (`.tpr`)** — The compiled run-input file (structure + topology + settings,
merged). *Why it matters: the run is 100% reproducible from this one file — and
analysis later reads it to know what it's looking at.*

**Trajectory (`.xtc`)** — The "movie": compressed coordinates of the system at
every recorded frame (every 10 ps here). *Why it matters: the raw data for all
analysis (stage 04).*

### V

**V-rescale** — The thermostat used in this project (a stochastic rescaling
thermostat; validated as more robust than older choices at 310.15 K). See
`configs/nvt.mdp` / `prod.mdp`.

**van der Waals (vdW)** — The weak attraction/repulsion between atoms that are
close but not bonded. Handled here with a 0.8 nm cutoff and
`Potential-shift-Verlet` + dispersion correction — the settings AMBER force
fields require in GROMACS.

**Verlet scheme** — The neighbor-search method (cutoff-scheme = Verlet) that
efficiently tracks which atoms are within the cutoff each step. *Why it matters:
GPU-friendly and standard for modern GROMACS.*

### W

**Watson–Crick pairing** — The canonical DNA base pairing: A–T and C–G, held by
hydrogen bonds. *Why it matters: a duplex of N base pairs has ~2–3 H-bonds per
pair — the quick "is the structure intact?" sanity check (~30–40 bonds for the
12-bp test duplex).*

**Water model** — The simplified physics of a water molecule used in the force
field (here TIP3P). *Why it matters: must match the force field; wrong pairing
gives wrong folding.*

**WBS** — Work Breakdown Structure: the decomposition of the project into
ordered work packages (see `docs/03_WORK_BREAKDOWN_STRUCTURE.md`).

### X

**xvg (`.xvg`)** — GROMACS's plain-text plot-data format (columns of numbers +
`@`/`#` metadata). *Why it matters: every analysis result lands here
(`analysis/*.xvg`) before visualization turns it into figures.*

**xpm (`.xpm`)** — An image format GROMACS writes for 2D matrices (e.g. cluster
contact maps). *Why it matters: some analysis tools require `.xpm` output names
in recent GROMACS versions (a version-drift bug class — see
`docs/INCIDENT_ANALYSIS.md`).*

---

*Alphabetized plain-language dictionary for GROMACS_NA53. Values quoted are the
repo's verified settings (`configs/*.mdp`, `scripts/*`, `memory.md`). Written
2026-09-04 as the companion to [BEGINNER_GUIDE.md](BEGINNER_GUIDE.md).*
