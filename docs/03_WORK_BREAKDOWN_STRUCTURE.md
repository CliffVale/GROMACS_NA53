# 🏗️ WORK BREAKDOWN STRUCTURE (WBS)
## MD Translation: The GROMACS Pipeline Architecture (Sequential Work Packages)

---

**Project ID:** GROMACS_NA53
**Version:** 1.0
**Date:** 2026-09-02

---

## Pipeline Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    APTAMER 3D FOLDING PIPELINE                      │
│                                                                     │
│  INPUT: FASTA sequence + ligand (optional)                          │
│  OUTPUT: Stable 3D structure + biosensing analysis                   │
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ WP1:     │→│ WP2:     │→│ WP3:     │→│ WP4:     │→│ WP5:     │ │
│  │ STRUCT.  │ │ SYSTEM   │ │ EQUILIB. │ │ PRODUC.  │ │ ANALYSIS │ │
│  │ PREP     │ │ PREP     │ │          │ │          │ │          │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │
│   ~1 hr        ~5 min       ~2 hr        hours-days   ~1 hr        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Level 1: WORK PACKAGES

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### WP1: STRUCTURE PREPARATION
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Objective:** Generate initial 3D aptamer structure from sequence
**Duration:** ~1 hour
**Dependencies:** Input FASTA file

#### 1.1 Secondary Structure Prediction

| Task ID | Task | Tool | Command / Script | Output | Validation |
|---------|------|------|-------------------|--------|------------|
| 1.1.1 | Parse FASTA input | Python/BioPython | `parse_fasta.py` | `.fasta` | Check sequence length, valid characters (ATCG/U) |
| 1.1.2 | Predict minimum-free-energy structure | NUPACK | `nupack -T 310.15 -salt 0.15 -material dna` | `.ct` / `.bpseq` | Check no pseudoknots unless expected |
| 1.1.3 | Alternative: seqfold prediction | seqfold (Python) | `seqfold --temp 310.15` | dot-bracket string | Cross-validate with NUPACK |
| 1.1.4 | Generate dot-bracket + base pairs | Custom script | `generate_structure.py` | `.dbn` | Visualize in Nview/VARNA |

**Acceptance Criteria:** Secondary structure has ≥80% confidence for predicted pairs

#### 1.2 3D Structure Generation

| Task ID | Task | Tool | Command / Script | Output | Validation |
|---------|------|------|-------------------|--------|------------|
| 1.2.1 | Generate 3D coordinates from secondary structure | MMB / AlphaFold2-RNA / RNAComposer | `fold_aptamer.py` | `.pdb` | No steric clashes (WHAT IF) |
| 1.2.2 | OR: Build from existing PDB | pdb4amber / editpdb | `pdb4amber -i aptamer.pdb` | Clean `.pdb` | Check residue naming (DNA vs RNA) |
| 1.2.3 | Remove water/heteroatoms | pdb4amber | `pdb4amber -i raw.pdb -o clean.pdb` | Clean `.pdb` | Verify no missing atoms |

**Acceptance Criteria:** Structure has sensible geometry, no steric clashes

#### 1.3 Structure Inspection

| Task ID | Task | Tool | Command | Output |
|---------|------|------|---------|--------|
| 1.3.1 | Visual inspection | VMD / PyMOL / ChimeraX | Load `.pdb` | Visual check |
| 1.3.2 | Structure validation | PROCHECK核酸 / 3DNA | `analyze_structure.py` | Ramachandran-like validation |
| 1.3.3 | Save checkpoint | cp | `cp clean.pdb structures/01_initial.pdb` | Checkpoint |

---

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### WP2: SYSTEM PREPARATION (GROMACS Setup)
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Objective:** Build complete solvated, ionized simulation system
**Duration:** ~5 minutes
**Dependencies:** WP1 complete (clean PDB)
**Scripts:** `01_system_prep.sh`

#### 2.1 Topology Generation

| Task ID | Task | GROMACS Command | Parameters | Output | Validation |
|---------|------|-----------------|------------|--------|------------|
| 2.1.1 | Generate topology | `gmx pdb2gmx` | `-ff amber99sb-ildn` (DNA) or `-ff amber99bsc1` (custom) `-water tip3p -ignh` | `topol.top`, `posre.itp`, `conf.gro` | Check total charge ≈ 0 (after genion) |
| 2.1.2 | Verify force field | Manual check | Inspect `topol.top` header | — | Correct FF, water model, ion params |
| 2.1.3 | Handle modified residues (if any) | acpype / antechamber | `acpype -i mod_res.mol2 -b mod_res -a gaff2` | `.itp`, `.mol2` | Validate against GAFF2 |

**⚠️ CRITICAL NOTE:** GROMACS pdb2gmx uses residue naming. For DNA aptamers:
- **DNA residues:** DA, DT, DG, DC (standard DNA names)
- **RNA residues:** A, U, G, C (standard RNA names)
- Ensure PDB uses correct naming before pdb2gmx!

#### 2.2 Box Definition

| Task ID | Task | GROMACS Command | Parameters | Output |
|---------|------|-----------------|------------|--------|
| 2.2.1 | Define simulation box | `gmx editconf` | `-f conf.gro -o boxed.gro -c -d 1.2 -bt dodecahedron` | `boxed.gro` |
| 2.2.2 | Verify box dimensions | `gmx editconf -f boxed.gro -box` | Check ≥ 1.2 nm padding | Box vector check |

**Parameters Explained:**
- `-c`: Center molecule in box
- `-d 1.2`: Minimum distance from solute to box edge (nm)
- `-bt dodecahedron`: Most efficient box shape for solvation

#### 2.3 Solvation

| Task ID | Task | GROMACS Command | Parameters | Output | Validation |
|---------|------|-----------------|------------|--------|------------|
| 2.3.1 | Solvate with water | `gmx solvate` | `-cp boxed.gro -cs spc216.gro -o solvated.gro -p topol.top` | `solvated.gro` | Water molecules added (N_water = V_box / V_mol) |

#### 2.4 Ionization & Neutralization

| Task ID | Task | GROMACS Command | Parameters | Output | Validation |
|---------|------|-----------------|------------|--------|------------|
| 2.4.1 | Create ions topology | Edit `topol.top` | Add: `#include "ions.itp"` | Modified `topol.top` | — |
| 2.4.2 | Generate ion configuration | `gmx grompp` | `-f ions.mdp -c solvated.gro -p topol.top -o ions.tpr` | `ions.tpr` | Pre-processing OK |
| 2.4.3 | Replace water with ions | `gmx genion` | `-s ions.tpr -o ionized.gro -p topol.top -pname NA -nname CL -neutral -conc 0.15` | `ionized.gro` | Net charge = 0, [NaCl] = 0.15 M |

**⚠️ CRITICAL:** Select "SOL" group when prompted by genion!

#### 2.5 System Prep Checklist

```bash
# Verification commands after WP2:
gmx editconf -f ionized.gro -box          # Check box dimensions
gmx grompp -f ions.mdp -c ionized.gro -p topol.top -o check.tpr  # Topology check
grep "Number of atoms" ionized.gro         # Atom count
grep -c "NA\|CL" ionized.gro              # Ion count
```

---

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### WP3: EQUILIBRATION
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Objective:** Bring system to target temperature and pressure with stable density
**Duration:** ~2 hours
**Dependencies:** WP2 complete (ionized.gro, topol.top)
**Scripts:** `02_equilibration.sh`

#### 3.1 Energy Minimization

| Task ID | Task | GROMACS Command | Parameters | Output | Validation |
|---------|------|-----------------|------------|--------|------------|
| 3.1.1 | Run steepest-descent EM | `gmx grompp -f em.mdp -c ionized.gro -p topol.top -o em.tpr` | max_steps=50000, emtol=1000, emstep=0.01 | `em.tpr` | Converged (< Fmax 1000 kJ/mol/nm) |
| 3.1.2 | Execute EM | `gmx mdrun -v -deffnm em` | GPU: `-nb gpu` | `em.gro`, `em.edr`, `em.log` | Converged in <50000 steps |
| 3.1.3 | Check EM convergence | `gmx energy -f em.edr -o potential.xvg` | Select "Potential" | `potential.xvg` | Final Epot < -1e5 kJ/mol |

**EM Parameters (em.mdp):**
```ini
integrator  = steep
emtol       = 1000.0        ; Stop when max force < 1000 kJ/mol/nm
emstep      = 0.01          ; Energy step size (nm)
nsteps      = 50000         ; Max steps
nstlist     = 1
cutoff-scheme = Verlet
ns_type     = grid
coulombtype = PME
rcoulomb    = 1.0
rvdw        = 1.0
pbc         = xyz
```

#### 3.2 NVT Equilibration (Temperature)

| Task ID | Task | GROMACS Command | Duration | Restraints | Output |
|---------|------|-----------------|----------|------------|--------|
| 3.2.1 | NVT with heavy atom restraints | `gmx grompp -f nvt.mdp -c em.gro -p topol.top -r em.gro -o nvt.tpr` | — | Heavy atoms: 1000 kJ/mol/nm² | `nvt.tpr` |
| 3.2.2 | Execute NVT | `gmx mdrun -deffnm nvt -nb gpu` | 100 ps (50000 steps × 2 fs) | — | `nvt.gro`, `nvt.xtc` |
| 3.2.3 | Check temperature | `gmx energy -f nvt.edr -o temperature.xvg` | — | Select "Temperature" | T ≈ 310.15 K ± 2 K |

**NVT Parameters (nvt.mdp):**
```ini
; Run control
integrator  = md
nsteps      = 50000          ; 100 ps
dt          = 0.002

; Temperature coupling
tcoupl      = nose-hoover
tc-grps     = System
tau-t       = 1.0
ref-t       = 310.15

; Position restraints on heavy atoms (non-hydrogen)
define      = -DPOSRES

; Bond constraints
continuation    = no
constraint_algorithm = lincs
constraints     = h-bonds
lincs_iter      = 1
lincs_order     = 4

; Electrostatics
coulombtype     = PME
rcoulomb        = 1.0
rvdw            = 1.0
pme_order       = 4
fourierspacing  = 0.12

; Neighbor searching
cutoff-scheme   = Verlet
ns_type         = grid
nstlist         = 10
rcoulomb        = 1.0
rvdw            = 1.0

; PBC
pbc             = xyz

; VDW modification
DispCorr        = EnerPres

; Output
nstxout-compressed = 1000
nstenergy        = 1000
nstlog           = 1000

; Velocity generation
gen_vel         = yes
gen_temp        = 310.15
gen_seed        = -1
```

#### 3.3 NPT Equilibration (Pressure + Density)

| Task ID | Task | GROMACS Command | Duration | Restraints | Output |
|---------|------|-----------------|----------|------------|--------|
| 3.3.1 | NPT with backbone restraints | `gmx grompp -f npt.mdp -c nvt.gro -p topol.top -r nvt.gro -o npt1.tpr` | — | Backbone: 1000 kJ/mol/nm² | `npt1.tpr` |
| 3.3.2 | Execute NPT (restrained) | `gmx mdrun -deffnm npt1 -nb gpu` | 100 ps | Backbone | `npt1.gro` |
| 3.3.3 | NPT without restraints | `gmx grompp -f npt_free.mdp -c npt1.gro -p topol.top -o npt2.tpr` | — | None (define = "") | `npt2.tpr` |
| 3.3.4 | Execute NPT (unrestrained) | `gmx mdrun -deffnm npt2 -nb gpu` | 500 ps | None | `npt2.gro` |
| 3.3.5 | Check density | `gmx energy -f npt2.edr -o density.xvg` | — | Select "Density" | ρ ≈ 1000 ± 50 kg/m³ |

**NPT Parameters (npt.mdp):**
```ini
; Run control
integrator  = md
nsteps      = 50000          ; 100 ps
dt          = 0.002

; Temperature coupling
tcoupl      = nose-hoover
tc-grps     = System
tau-t       = 1.0
ref-t       = 310.15

; Pressure coupling
pcoupl      = parrinello-rahman
pcoupltype  = isotropic
tau-p       = 5.0
ref-p       = 1.0
compressibility = 4.5e-5

; Position restraints (backbone only)
define      = -DPOSRES_BB

; Bond constraints
continuation    = yes
constraint_algorithm = lincs
constraints     = h-bonds
lincs_iter      = 1
lincs_order     = 4

; Electrostatics
coulombtype     = PME
rcoulomb        = 1.0
rvdw            = 1.0
pme_order       = 4
fourierspacing  = 0.12

; Neighbor searching
cutoff-scheme   = Verlet
ns_type         = grid
nstlist         = 10

; PBC
pbc             = xyz

; VDW modification
DispCorr        = EnerPres

; Output
nstxout-compressed = 1000
nstenergy        = 1000
nstlog           = 1000

; No velocity generation (continuation from NVT)
gen_vel         = no
```

#### 3.4 Equilibration Validation Checklist

| Check | Target | Command | Pass/Fail |
|-------|--------|---------|-----------|
| EM converged | Fmax < 1000 kJ/mol/nm | `gmx energy -f em.edr` | □ |
| NVT temperature stable | 310 ± 2 K | `gmx energy -f nvt.edr -o temp.xvg` | □ |
| NPT density stable | 1000 ± 50 kg/m³ | `gmx energy -f npt2.edr -o dens.xvg` | □ |
| No energy drift | Conserved E drift < 0.1% | `gmx energy -f npt2.edr -o conserved.xvg` | □ |
| Temperature drift | < 1 K over last 50 ps | Plot temperature.xvg | □ |
| Pressure stable | 1.0 ± 1.0 bar | `gmx energy -f npt2.edr -o press.xvg` | □ |

---

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### WP4: PRODUCTION MD
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Objective:** Unrestrained MD sampling for structural characterization
**Duration:** Hours to days (100–500 ns)
**Dependencies:** WP3 complete (npt2.gro, equilibration validated)
**Scripts:** `03_production.sh`

#### 4.1 Production Run

| Task ID | Task | GROMACS Command | Parameters | Output |
|---------|------|-----------------|------------|--------|
| 4.1.1 | Generate production TPR | `gmx grompp -f prod.mdp -c npt2.gro -p topol.top -o prod.tpr` | No restraints, NPT | `prod.tpr` |
| 4.1.2 | Execute production | `gmx mdrun -deffnm prod -nb gpu` | 100–500 ns | `prod.xtc`, `prod.gro`, `prod.edr`, `prod.log` |
| 4.1.3 | Monitor in real-time | `gmx energy -f prod.edr -o realtime.xvg` | Temperature, energy | Real-time check |
| 4.1.4 | Checkpoint restart (if needed) | `gmx mdrun -cpi prod.cpt -deffnm prod -nb gpu` | Continue from checkpoint | Resume |

**Production Parameters (prod.mdp):**
```ini
; Run control
integrator  = md
nsteps      = 250000000      ; 500 ns (adjust as needed)
dt          = 0.002

; Temperature coupling
tcoupl      = nose-hoover
tc-grps     = System
tau-t       = 1.0
ref-t       = 310.15

; Pressure coupling
pcoupl      = parrinello-rahman
pcoupltype  = isotropic
tau-p       = 5.0
ref-p       = 1.0
compressibility = 4.5e-5

; NO position restraints (define = )

; Bond constraints
continuation    = yes
constraint_algorithm = lincs
constraints     = h-bonds
lincs_iter      = 1
lincs_order     = 4

; Electrostatics
coulombtype     = PME
rcoulomb        = 1.0
rvdw            = 1.0
pme_order       = 4
fourierspacing  = 0.12

; Neighbor searching
cutoff-scheme   = Verlet
ns_type         = grid
nstlist         = 10

; PBC
pbc             = xyz

; VDW modification
DispCorr        = EnerPres

; Output (compressed trajectory for analysis)
nstxout-compressed = 5000     ; Write XTC every 10 ps
nstxout            = 0        ; No full-precision trajectory (save space!)
nstvout            = 0        ; No velocities
nstfout            = 0        ; No forces
nstenergy          = 5000     ; Energy terms every 10 ps
nstlog             = 5000     ; Log every 10 ps
nstcalcenergy      = 5000

; No velocity generation
gen_vel         = no

; Save checkpoint every 15 minutes
nstxout-compressed = 5000
```

#### 4.2 Production Monitoring

| Monitor | Frequency | Threshold | Action if breached |
|---------|-----------|-----------|-------------------|
| Temperature | Every 10 ps | 310 ± 10 K | Check thermostat settings |
| Pressure | Every 10 ps | 1.0 ± 10 bar | Check barostat settings |
| Conserved energy | Every 10 ps | Drift < 0.1% | Check timestep, constraints |
| Box volume | Every 100 ps | Stable ± 5% | Check pressure coupling |
| RMSD | Every 1 ns | < 0.5 nm from start | May indicate unfolding |

---

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### WP5: ANALYSIS & BIOSENSING CHARACTERIZATION
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Objective:** Extract biosensor-relevant metrics from production trajectory
**Duration:** ~1 hour
**Dependencies:** WP4 complete (production trajectory)
**Scripts:** `04_analysis.sh`, `05_visualization.py`

#### 5.1 Structural Stability Analysis

| Task ID | Task | Tool | Command | Output | Biosensing Relevance |
|---------|------|------|---------|--------|---------------------|
| 5.1.1 | RMSD from initial structure | `gmx rms` | `-s prod.tpr -f prod.xtc -o rmsd.xvg -tu ns` | `rmsd.xvg` | Convergence = stable fold |
| 5.1.2 | RMSF per residue | `gmx rmsf` | `-s prod.tpr -f prod.xtc -o rmsf.xvg -res` | `rmsf.xvg` | Flexible binding loops identified |
| 5.1.3 | Radius of gyration | `gmx gyrate` | `-s prod.tpr -f prod.xtc -o gyrate.xvg` | `gyrate.xvg` | Compactness indicator |

#### 5.2 Interaction Analysis

| Task ID | Task | Tool | Command | Output | Biosensing Relevance |
|---------|------|------|---------|--------|---------------------|
| 5.2.1 | Hydrogen bonds | `gmx hbond` | `-s prod.tpr -f prod.xtc -num hbnum.xvg` | `hbnum.xvg` | Base-pairing stability |
| 5.2.2 | Base stacking | MDAnalysis (Python) | `analyze_stacking.py` | Stacking occupancy | Core structural motif |
| 5.2.3 | Base pairing | `gmx hbond` or custom | `-sel "resname DA DT DG DC"` | Pairing patterns | Aptamer fold integrity |

#### 5.3 Solvent Analysis

| Task ID | Task | Tool | Command | Output | Biosensing Relevance |
|---------|------|------|---------|--------|---------------------|
| 5.3.1 | SASA (Solvent Accessible Surface Area) | `gmx sasa` | `-s prod.tpr -f prod.xtc -o sasa.xvg` | `sasa.xvg` | Exposed binding pocket area |
| 5.3.2 | Water density around aptamer | `gmx density` | `-d Z -o density.xvg` | `density.xvg` | Solvation shell structure |

#### 5.4 Biosensing-Specific Analysis

| Task ID | Task | Tool | Command | Output | Biosensing Relevance |
|---------|------|------|---------|--------|---------------------|
| 5.4.1 | Principal component analysis | `gmx covar` / `gmx anaeig` | `-s prod.tpr -f prod.xtc` | Eigenvalues, eigenvectors | Dominant conformational modes |
| 5.4.2 | Free energy landscape | Custom (Python) | `free_energy_landscape.py` | 2D FEL (PC1 vs PC2) | Folding funnel topology |
| 5.4.3 | MM-PBSA binding energy (if ligand) | gmx_MMPBSA | `-s prod.xtc -n index.ndx` | Binding ΔG | Aptamer–analyte affinity |
| 5.4.4 | Conformational clustering | `gmx cluster` | `-s prod.tpr -f prod.xtc -method gromos -cutoff 0.2` | Cluster structures | Dominant binding-competent conformations |
| 5.4.5 | Aptamer–ligand contacts (if ligand) | `gmx distance` / MDAnalysis | Custom | Contact maps | Binding site identification |

#### 5.5 Visualization & Reporting

| Task ID | Task | Tool | Command | Output |
|---------|------|------|---------|--------|
| 5.5.1 | Trajectory visualization | VMD / PyMOL / ChimeraX | Load `.xtc` + `.tpr` | Rendered images |
| 5.5.2 | RMSD/RMSF/Rg plots | Python (matplotlib) | `plot_analysis.py` | Publication figures |
| 5.5.3 | H-bond heatmap | MDAnalysis + seaborn | `hbond_heatmap.py` | Base-pairing patterns |
| 5.5.4 | Free energy landscape contour | matplotlib | `plot_FEL.py` | PC1 vs PC2 landscape |
| 5.5.5 | Compile results report | LaTeX/Markdown | `generate_report.py` | Final report (PDF/MD) |

---

## GANTT CHART (Estimated Timeline)

```
Day 1:  ████████████ WP1 (Structure Prep) ──────────
Day 1:  ██ WP2 (System Setup) ─────────────────────
Day 1:  ████████ WP3 (Equilibration) ──────────────
Day 1-5: ████████████████████████████████████ WP4 (Production)
Day 5:  ████████████ WP5 (Analysis) ──────────────
```

---

## CRITICAL PATH

```
FASTA input → NUPACK → 3D fold → pdb2gmx → editconf → solvate → genion → EM → NVT → NPT → Production → Analysis
```

---

## DELIVERABLES

| WP | Deliverable | Format | Location |
|----|-------------|--------|----------|
| WP1 | Predicted 3D structure | .pdb | `structures/` |
| WP2 | System topology + ionized structure | .top, .gro | `system/` |
| WP3 | Equilibrated structure | .gro, .edr, .log | `equilibration/` |
| WP4 | Production trajectory | .xtc, .tpr, .edr | `production/` |
| WP5 | Analysis results + figures | .xvg, .png, .pdf | `analysis/` |

---

*Generated: 2026-09-02 | Project: GROMACS_NA53*
