# 🔬 DEEP ANALYSIS: APTAMD & APTAMD_TUTORIALS
## Relevance to NA53 DNA Aptamer Simulation Pipeline

---

**Analysis Date:** 2026-09-02
**Analyst:** Buffy (Codebuff AI)
**Repositories Analyzed:**
- https://github.com/dimassuarez/APTAMD (main suite)
- https://github.com/dimassuarez/APTAMD_TUTORIALS (6-session course)

---

## 1. REPOSITORY OVERVIEW

### 1.1 APTAMD — The Main Suite

| Aspect | Detail |
|--------|--------|
| **Authors** | Natalia Díaz-Fernández & Dimas Suárez (University of Oviedo) |
| **Language** | BASH backbone + Octave/Python for numerics + Fortran for auxiliaries |
| **MD Engine** | AMBER (PMEMD.cuda) — **NOT GROMACS** |
| **Force Field** | parmbsc1 (default), OL15/OL21/OL25 (alternatives) |
| **Water Model** | TIP3P (default), OPC (alternative) |
| **License** | Open-source (academic use) |
| **Last Updated** | 2025–2026 (active development) |
| **Citations** | Díaz-Fernández et al. *Chem. Sci.* 2020, 11, 9402; *JCIM* 2025, 65, 4128 |

### 1.2 APTAMD_TUTORIALS — The Course

| Aspect | Detail |
|--------|--------|
| **Format** | 6 Jupyter notebooks (3–4 hr each) |
| **Audience** | Analytical chemists / graduate students |
| **Tools** | AMBER, x3dna-dssr, Autodock4, APTAMD scripts |
| **Focus** | Hands-on MD simulation + analysis + docking |

---

## 2. THE APTAMD PROTOCOL (5-Stage Pipeline)

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  STAGE 1    │→│  STAGE 2    │→│  STAGE 3    │→│  STAGE 4    │→│  STAGE 5    │
│  Edition    │  │  GaMD       │  │  Analysis   │  │  cMD        │  │  Clustering │
│  (do_       │  │  (do_runmd) │  │  (do_struct │  │  (do_runmd) │  │  (do_cluster│
│  aptamer_   │  │             │  │  + do_rwgamd)│ │             │  │  + do_mmpbsa)│
│  edition)   │  │             │  │             │  │             │  │             │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
  2D→3D+FF        Enhanced MD      FEL + INF        Equilibrium MD   Representative
  +solvation      (exploration)    (conformational   (sampling)       structures +
                                   landscape)                        MM-PBSA scoring
```

### Stage 1: `do_aptamer_edition` — Model Building
**What it does:**
1. Takes initial 3D PDB (from RNAComposer/mfold)
2. Converts RNA residue/atom names → DNA names
3. Removes 2'-OH groups from ribose
4. Adds missing methylene in thymines
5. Adds all hydrogen atoms
6. Assigns parmbsc1 (or OL15/OL21/OL25) force field parameters
7. Relaxes internal geometry of nucleobases (sander minimization)
8. Adds octahedral TIP3P water box
9. Adds Na⁺/Cl⁻ counterions
10. Outputs: `.top` (topology) + `.crd` (coordinates) — ready for MD

**Key insight for NA53:** This is equivalent to our `01_system_prep.sh` but uses AMBER's tLEaP instead of GROMACS's pdb2gmx. The RNA→DNA conversion step is specific to APTAMD's workflow of predicting structure with RNAComposer then converting to DNA.

### Stage 2: `do_runmd` — Gaussian Accelerated MD (GaMD)
**What it does:**
1. **Solvent relaxation** (energy minimization + restrained MD)
2. **Thermalization** (NVT, 300 K, Langevin thermostat)
3. **Pressurization** (NPT, 1 atm, Berendsen barostat)
4. **GaMD equilibration** (boost potential calibration)
5. **GaMD production** (enhanced sampling with harmonic boost potentials)

**Key insight for NA53:** GaMD is a major advantage over our standard MD approach. It accelerates conformational transitions by smoothing the potential energy surface, allowing the aptamer to explore its conformational landscape much faster than conventional MD. This is critical for 3D folding where the energy landscape is rugged.

### Stage 3: `do_struct` + `do_reweight_gamd` — GaMD Analysis
**What it does:**
1. **RMSD** — heavy atom deviation from initial structure
2. **INF** (Interaction Network Fidelity) — base-pairing/stacking persistence using DSSR
3. **Rg** — radius of gyration
4. **Free energy reweighting** — 2D FEL (RMSD vs INF)
5. **Representative structure extraction** — lowest-energy conformations

**Key insight for NA53:** The INF metric is unique to APTAMD and directly relevant for biosensing — it quantifies how well the aptamer maintains its characteristic base-pairing/stacking network, which is essential for target recognition.

### Stage 4: `do_runmd` (cMD) — Conventional MD
**What it does:**
- Takes the best GaMD structure
- Re-edits with `do_aptamer_edition`
- Runs conventional MD (µs timescale) for equilibrium sampling

**Key insight for NA53:** The GaMD→cMD two-stage approach is more robust than our single-stage production. GaMD explores the landscape, then cMD refines the equilibrium properties.

### Stage 5: `do_cluster` + `do_mmpbsa` — Clustering & Scoring
**What it does:**
1. **Clustering** — average-linkage on heavy-atom RMSD (cpptraj)
2. **MM-PBSA** — solvation energy scoring with Poisson-Boltzmann
3. **Conformational entropy** — via CENCALC (dihedral angle discretization)
4. **Ensemble docking** — AutoDock4 against multiple conformations

**Key insight for NA53:** MM-PBSA scoring of aptamer models is directly relevant for predicting binding affinity to NGAL. The ensemble docking capability is exactly what we need for the aptamer-target complex.

---

## 3. CRITICAL COMPARISON: APTAMD vs. Our GROMACS Pipeline

| Feature | APTAMD (AMBER) | Our Pipeline (GROMACS) | Impact on NA53 |
|---------|---------------|----------------------|----------------|
| **MD Engine** | PMEMD.cuda (AMBER) | GROMACS mdrun | Both valid; AMBER slightly faster for nucleic acids |
| **Force Field** | parmbsc1 (default) | AMBER99bsc1 | Equivalent — same corrections |
| **Enhanced Sampling** | GaMD (built-in) | Standard MD only | ⚠️ APTAMD explores landscape faster |
| **Initial Model** | RNAComposer → DNA conversion | seqfold → B-form helix | ⚠️ RNAComposer gives better 3D starting structures |
| **Structural Analysis** | RMSD + INF + Rg (DSSR) | RMSD + RMSF + Rg + H-bonds | APTAMD's INF is more nucleic-acid-specific |
| **Free Energy** | GaMD reweighting (2D FEL) | PCA + clustering | APTAMD's reweighting is more rigorous |
| **MM-PBSA** | Built-in (sander/PBSA) | gmx_MMPBSA (external) | Both available |
| **Docking** | AutoDock4 ensemble docking | Not implemented | ⚠️ Needed for NA53-NGAL complex |
| **Conformational Entropy** | CENCALC (unique) | Not implemented | Useful for biosensing mechanism |
| **Automation** | High (do_* scripts) | High (bash scripts) | Comparable |
| **Installation** | Complex (AMBER license + DSSR + Octave + Fortran) | Simpler (conda + GROMACS) | GROMACS easier to install |
| **Cost** | AMBER license required | Free (open-source) | GROMACS advantage |

---

## 4. WHAT WE SHOULD ADOPT FROM APTAMD

### 4.1 HIGH PRIORITY — Adopt Immediately

#### ① RNAComposer for Initial 3D Structure
**Why:** APTAMD uses RNAComposer to generate initial 3D coordinates from secondary structure, which is far superior to our B-form helix approximation.

**Action for NA53:**
```
1. Get NA53 secondary structure from mfold/seqfold
2. Submit to RNAComposer: https://rnacomposer.cs.put.poznan.pl/
3. Download PDB → use as input for 01_system_prep.sh
```

#### ② GaMD for Enhanced Sampling
**Why:** Standard MD may take microseconds to fold a 55-nt aptamer. GaMD can explore the landscape in 1–2 days of GPU time.

**Action for NA53:**
- If AMBER is available on Taiwania 3: Use APTAMD directly for the GaMD stage
- If GROMACS only: Implement加速 MD (accelMD) or use GROMACS's integrated adaptively tempered MD

#### ③ INF (Interaction Network Fidelity) Analysis
**Why:** INF directly measures whether the aptamer maintains its characteristic base-pairing/stacking network — the structural signature required for biosensing.

**Action for NA53:**
- Install x3dna-dssr on Taiwania 3
- Add INF calculation to our analysis pipeline
- Compare INF between folded and unfolded states

#### ④ Two-Stage Protocol (GaMD → cMD)
**Why:** APTAMD's approach of first exploring with GaMD, then refining with cMD, is more robust than our single-stage production.

**Action for NA53:**
```
Stage 1: 100 ns GaMD (exploration) → select best structure
Stage 2: 500 ns cMD (equilibrium) → production analysis
```

### 4.2 MEDIUM PRIORITY — Consider Adopting

#### ⑤ MM-PBSA with Multiple Dielectric Constants
**Why:** APTAMD tests PDIE=1, 4, etc. to assess sensitivity of scoring to the inner dielectric constant.

#### ⑥ Conformational Entropy (CENCALC)
**Why:** S_conform as a function of time is a powerful convergence diagnostic. Also complements MM-PBSA scoring via the -TS term.

#### ⑦ Ensemble Docking for NA53-NGAL
**Why:** APTAMD's AutoDock4 ensemble docking is exactly what we need for the aptamer-protein complex.

### 4.3 LOW PRIORITY — Nice to Have

#### ⑧ DSSR-based Structural Analysis
**Why:** DSSR provides nucleic-acid-specific structural parameters (helical rise, twist, groove widths) that GROMACS tools don't compute.

---

## 5. APTAMD TUTORIALS — KEY TAKEAWAYS FOR NA53

### Session 2: Initial Models
- **mfold** for secondary structure (T=25°C, 0.15 M NaCl)
- **RNAComposer** for 3D coordinates from dot-bracket notation
- **G-quadruplex check** — if NA53 has G-rich regions, may form G4 structures

### Session 3: Molecular Mechanics
- **Energy minimization** is critical before MD
- **Solvation** — octahedral box with TIP3P + Na⁺/Cl⁻
- **Parmbsc1** force field validated for DNA aptamers

### Session 4: MD Fundamentals
- **GaMD** settings: dual-boost (potential + dihedral), cuff=0.2, nstboost=1
- **Equilibration stages**: minimization → solvent relaxation → thermalization → pressurization → GaMD equilibration
- **Production**: 100–500 ns GaMD, then µs cMD

### Session 5: Analysis
- **RMSD + INF** as dual descriptors for conformational landscape
- **Clustering** — test multiple RMSD thresholds (1–5 Å)
- **Convergence** — S_conform vs time plot

### Session 6: Docking
- **Ensemble docking** — use cluster representatives from cMD
- **AutoDock4** — prepare PDBQT files from APTAMD snapshots
- **Relaxation** — sander minimization of docking poses

---

## 6. INTEGRATION PLAN: APTAMD + Our GROMACS Pipeline

### Option A: Hybrid Approach (RECOMMENDED)
```
1. Use APTAMD for structure prediction (RNAComposer + do_aptamer_edition)
2. Use GROMACS for production MD (free, fast on Taiwania 3)
3. Use APTAMD analysis tools (DSSR, INF, CENCALC) on GROMACS trajectories
4. Use APTAMD docking for NA53-NGAL complex
```

### Option B: Full APTAMD Pipeline
```
1. Install AMBER on Taiwania 3 (requires license)
2. Use APTAMD for entire pipeline (Edition → GaMD → cMD → Clustering → Docking)
3. More automated but requires AMBER license
```

### Option C: GROMACS-Only with APTAMD Insights
```
1. Adopt RNAComposer for initial structure
2. Implement GaMD-like enhanced sampling in GROMACS (accelMD)
3. Add INF analysis using DSSR
4. Keep everything else in GROMACS
```

---

## 7. SPECIFIC RECOMMENDATIONS FOR NA53

### 7.1 Structure Prediction
```
Current: seqfold → B-form helix (poor quality)
Better:  mfold → RNAComposer → DNA conversion (APTAMD method)
Best:    AlphaFold3 server (if available) → GROMACS refinement
```

### 7.2 Enhanced Sampling
```
Current: Standard MD (100 ns) — may not fold completely
Better:  GaMD (100 ns) → cMD (500 ns) — APTAMD approach
Best:    Replica exchange MD (REMD) — most thorough but expensive
```

### 7.3 Analysis Metrics
```
Current: RMSD, RMSF, Rg, H-bonds
Add:     INF (base-pairing/stacking persistence from DSSR)
Add:     S_conform (conformational entropy convergence)
Add:     Groove widths (from DSSR — relevant for protein binding)
```

### 7.4 NGAL Complex
```
Current: Not implemented
Plan:    Use APTAMD's AutoDock4 ensemble docking
         Use cluster representatives from NA53 cMD
         Dock NGAL protein against aptamer conformations
```

---

## 8. FILES TO UPDATE IN OUR PIPELINE

Based on APTAMD analysis, these files need updates:

| File | Update | Priority |
|------|--------|----------|
| `00_predict_structure.sh` | Add RNAComposer option, G4 check | HIGH |
| `02_equilibration.sh` | Add GaMD stage if AMBER available | HIGH |
| `04_analysis.sh` | Add DSSR/INF calculation, S_conform | HIGH |
| `05_visualization.py` | Add INF plots, 2D FEL from GaMD reweighting | MEDIUM |
| `configs/prod.mdp` | Document GaMD alternative settings | MEDIUM |
| `docs/03_WORK_BREAKDOWN_STRUCTURE.md` | Add GaMD stage to WBS | HIGH |
| `docs/02_PROJECT_SCOPE_STATEMENT.md` | Add GaMD, DSSR, ensemble docking | MEDIUM |

---

## 9. DEPENDENCIES TO INSTALL ON TAIWANIA 3

From APTAMD requirements:

| Tool | Purpose | Install Method |
|------|---------|---------------|
| AMBER (pmemd.cuda) | GaMD + MM-PBSA | License required — `module load amber` |
| x3dna-dssr | Structural analysis (INF, helical params) | `conda install -c conda-forge x3dna-dssr` |
| AutoDock4 | Ensemble docking | `conda install -c conda-forge autodock` |
| Octave | APTAMD numerics | `conda install -c conda-forge octave` |
| GNU Parallel | Distributed processing | `conda install -c conda-forge parallel` |

---

## 10. SUMMARY

**APTAMD is the gold-standard protocol for DNA aptamer MD simulation.** It provides:

1. ✅ **Proven pipeline** — validated on multiple aptamers (anti-MUC1, anti-NGAL, etc.)
2. ✅ **GaMD enhanced sampling** — faster conformational exploration than standard MD
3. ✅ **INF metric** — nucleic-acid-specific structural descriptor
4. ✅ **Ensemble docking** — for aptamer-target complex prediction
5. ✅ **Conformational entropy** — convergence diagnostic
6. ✅ **Active maintenance** — updated 2025, good documentation

**For NA53, we should:**
1. Use RNAComposer for initial 3D structure (instead of B-form helix)
2. Consider AMBER+APTAMD for GaMD exploration stage
3. Add DSSR/INF analysis to our GROMACS pipeline
4. Use APTAMD's docking protocol for NA53-NGAL complex

**The main limitation of APTAMD:** It requires an AMBER license and is BASH-heavy (harder to port to GROMACS). Our GROMACS pipeline is free and more portable, but lacks enhanced sampling and nucleic-acid-specific analysis tools.

---

*Analysis complete. APTAMD_DEEP_ANALYSIS.md — GROMACS_NA53 Project*
