# 📐 PROJECT SCOPE STATEMENT
## MD Translation: The System Boundary & Force Field Matrix

---

**Project ID:** GROMACS_NA53
**Version:** 1.0
**Date:** 2026-09-02

---

## 1. Scope Overview

This document defines the explicit boundaries of the aptamer 3D folding simulation pipeline — what is included, what is excluded, and the precise parameter matrix governing every simulation stage.

---

## 2. IN-SCOPE Items

### 2.1 Simulation Stages

| Stage | Scope | Status |
|-------|-------|--------|
| **Structure Preparation** | Sequence → secondary structure (NUPACK/seqfold) → 3D fold (MMB/AlphaFold2-RNA) | ✅ IN-SCOPE |
| **System Setup** | pdb2gmx → editconf → solvate → genion | ✅ IN-SCOPE |
| **Energy Minimization** | Steepest descent → conjugate gradient | ✅ IN-SCOPE |
| **NVT Equilibration** | 100 ps, positional restraints (heavy atoms → backbone → none) | ✅ IN-SCOPE |
| **NPT Equilibration** | 100–500 ps, density equilibration, pressure coupling | ✅ IN-SCOPE |
| **Production MD** | Unrestrained NPT, 100–500 ns | ✅ IN-SCOPE |
| **Structural Analysis** | RMSD, RMSF, Rg, H-bonds, SASA, base stacking | ✅ IN-SCOPE |
| **Biosensing Analysis** | Binding free energy (MM-PBSA/GBSA), conformational switching | ✅ IN-SCOPE |

### 2.2 Aptamer Types

| Type | Status |
|------|--------|
| ssDNA aptamers (10–80 nt) | ✅ IN-SCOPE |
| ssRNA aptamers (10–80 nt) | ✅ IN-SCOPE (with RNA force field) |
| DNA/RNA aptamer–ligand complexes | ✅ IN-SCOPE |
| Modified aptamers (2'-OMe, LNA) | ⚠️ PARTIAL (requires custom parameters) |
| Aptamer–protein complexes | ❌ OUT-SCOPE (too large for standard workflow) |

---

## 3. OUT-SCOPE Items

| Item | Justification |
|------|---------------|
| SELEX experimental design | Computational only |
| Protein–aptamer complexes (except small peptides <20 aa) | System size prohibitive for standard GPU workflow |
| Coarse-grained simulations | Resolution insufficient for atomic-level biosensing analysis |
| Free energy perturbation (FEP) | Requires specialized setup beyond standard pipeline |
| Reactive MD (ReaxFF) | Not applicable for biosensor conformational study |
| Multi-scale (QM/MM) | Too expensive for routine aptamer screening |

---

## 4. Force Field Matrix

### 4.1 DNA Force Fields

| Force Field | Version | Use Case | Water Model | Citation |
|-------------|---------|----------|-------------|----------|
| **AMBER99bsc1** | BSC1 (2011) | **DEFAULT for DNA aptamers** | TIP3P | Zgarbová et al. *JCTC* 7:2886 |
| OL15 | OL15 (2017) | Alternative DNA with improved α/γ/ε/ζ | TIP3P/SPC/E | Banáš et al. *JCTC* 8:3016 |
| CHARMM36 | C36 (2014) | Protein–DNA complexes | TIP3P | Hart et al. *JCTC* 8:3484 |
| AMBEROL3 | OL3 (2010) | RNA aptamers (χ torsion) | TIP3P | Zgarbová et al. *JCTC* 7:2886 |

### 4.2 RNA Force Fields

| Force Field | Version | Use Case | Citation |
|-------------|---------|----------|----------|
| **AMBER99bsc1 + χOL3** | bsC1+OL3 | **DEFAULT for RNA aptamers** | Zgarbová et al. *JCTC* 7:2886 |
| CHARMM36 | C36 | RNA–protein complexes | Hart et al. *JCTC* 8:3484 |
| MAYPOINT | v5 | RNA with improved backbone sampling | However et al. *JCTC* 11:3547 |

### 4.3 Water Models

| Model | Atoms/Mol | ε_O (kJ/mol) | σ_O (nm) | Use Case |
|-------|-----------|---------------|----------|----------|
| **TIP3P** | 3 | 0.6364 | 0.3150 | **DEFAULT** (AMBER/CHARMM standard) |
| SPC/E | 3 | 0.7112 | 0.3166 | Alternative for diffusion studies |
| TIP4P-Ew | 4 | 0.6809 | 0.3154 | More accurate, ~20% slower |
| OPC | 4 | 0.8945 | 0.3174 | Best for nucleic acids (newer) |

---

## 5. System Parameter Matrix

### 5.1 Box & Boundary Conditions

| Parameter | Value | Justification |
|-----------|-------|---------------|
| Box shape | Dodecahedral | Smallest volume for PBC, saves ~30% water vs. cubic |
| Box padding | 1.2 nm | Prevents solute self-interaction via image |
| PBC | Full 3D periodic | Standard for aqueous biomolecular simulation |
| Neighbor list | Verlet (updated every 10 steps) | Default in GROMACS 2016+ |
| PME order | 4th order | Standard accuracy |
| PME grid spacing | 0.12 nm | Matches real-space cutoff |

### 5.2 Electrostatics & VDW

| Parameter | Value | Justification |
|-----------|-------|---------------|
| Electrostatics | PME | Long-range electrostatics (essential for charged aptamers) |
| VDW treatment | Cut-off (1.0 nm) + dispersion correction | Standard for AMBER force fields |
| Dispersion correction | yes | Compensates truncation of long-range VDW |
| Twin-range cutoff | No | Verlet scheme handles VDW in single range |

### 5.3 Integration & Constraints

| Parameter | Value | Justification |
|-----------|-------|---------------|
| Integrator | md (leap-frog) | Standard, stable for biomolecular MD |
| Timestep | 2 fs | With LINCS H-bond constraints |
| LINCS order | 4 | Sufficient for non-flexible water |
| LINCS iterations | 1 | Standard |
| Constraints | h-bonds | Allows 2 fs timestep |

### 5.4 Temperature Coupling

| Parameter | Value | Justification |
|-----------|-------|---------------|
| Thermostat | Nosé-Hoover | Produces correct NVT/NPT ensemble |
| Coupling time (τ_T) | 1.0 ps | Standard for biomolecular systems |
| Target temperature | 310.15 K | Physiological / biosensor operating conditions |
| T-coupling groups | 1 (DNA + solvent) | Or separate groups for large systems |

### 5.5 Pressure Coupling

| Parameter | Value | Justification |
|-----------|-------|---------------|
| Barostat | Parrinello-Rahman | Better than Berendsen for production runs |
| Coupling time (τ_P) | 5.0 ps | Standard for nucleic acid simulations |
| Reference pressure | 1.0 bar | Ambient conditions |
| Compressibility | 4.5 × 10⁻⁵ bar⁻¹ | Water compressibility at 300 K |
| Pressure coupling type | isotropic | Unless membrane present (semi-isotropic) |

### 5.6 Output Control

| Parameter | Production | Equilibration |
|-----------|------------|---------------|
| nstxout-compressed (.xtc) | 5000 (10 ps) | 1000 (2 ps) |
| nstxout (.trr) | 0 (disabled for storage) | 0 |
| nstenergy (.edr) | 5000 | 1000 |
| nstlog | 5000 | 1000 |
| nstcalcenergy | 5000 | 1000 |

---

## 6. Analysis Parameter Matrix

| Metric | Tool | GROMACS Command | Relevance to Biosensing |
|--------|------|-----------------|------------------------|
| RMSD | Structural stability | `gmx rms` | Confirms convergence of fold |
| RMSF | Residue flexibility | `gmx rmsf` | Identifies flexible binding loops |
| Radius of gyration | Compactness | `gmx gyrate` | Folded vs. unfolded state |
| H-bond count | Structural integrity | `gmx hbond` | Base-pairing & aptamer stability |
| SASA | Solvent accessibility | `gmx sasa` | Buried vs. exposed residues |
| Base stacking | Stacking persistence | Custom analysis (MDAnalysis) | Core structural motif stability |
| 2D-P FS | Pseudorotation phase | Custom or 3DNA/CanDo | Sugar pucker sampling |
| Free energy (MM-PBSA) | Binding affinity | gmx_MMPBSA | Aptamer–analyte interaction |
| Principal components | Conformational landscape | `gmx covar` / `gmx anaeig` | Dominant motion modes |

---

## 7. Delimitation Matrix

| Category | Included | Excluded |
|----------|----------|----------|
| System size | ≤ 100,000 atoms | > 100,000 atoms |
| Simulation length | ≤ 1 µs per run | > 1 µs (unless clustering) |
| Force field | AMBER/CHARMM families | OPLS-AA, GROMOS (not validated for nucleic acids) |
| Analysis | Structural + thermodynamic | Transport properties (viscosity, diffusion) |
| Output format | .xtc + .tpr + .gro | .trr (disabled to save storage) |

---

*Generated: 2026-09-02 | Project: GROMACS_NA53*
