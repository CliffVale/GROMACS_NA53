# 📋 PROJECT CHARTER
## MD Translation: The Simulation Mission Directive & System Definition

---

**Project ID:** GROMACS_NA53
**Project Name:** In Silico Aptamer 3D Folding for Biosensing Applications
**Version:** 1.0
**Date:** 2026-09-02
**Author:** Auto-generated via literature-informed protocol

---

---
> ⚠️ **VALIDATION BANNER (2026-09-04):** this charter records the *original plan*
> (2026-09-02). Where its numbers differ from what actually runs, the ✅-annotated
> `configs/*.mdp` files are the **running truth** — notably: cutoffs are **0.8 nm**
> (not 1.0 nm), the thermostat is **V-rescale** (not Nosé–Hoover), and the
> implemented force field is `amber99sb-ildn` (the `bsc1`/`parmbsc1` upgrade is a
> tracked decision, see `memory.md` Q7). Root cause & prevention of this drift:
> `docs/INCIDENT_ANALYSIS.md` class P.

## 1. Executive Summary## 1. Executive Summary

This project establishes a reproducible, literature-validated GROMACS molecular dynamics simulation pipeline for predicting the 3D folded structure of nucleic acid aptamers intended for biosensing applications. The pipeline spans from sequence input through production MD and thermodynamic/biosensing-relevant analysis, following established protocols (E2EDNA2, literature SOPs).

## 2. Biological Problem Statement

DNA/RNA aptamers are short single-stranded oligonucleotides (~10–100 nt) that fold into defined 3D structures enabling selective binding to target analytes — the foundation of aptamer-based biosensors. The causal relationship between sequence and sensing performance depends primarily on the **3D folded structure** of the aptamer and **structural rearrangements upon ligand binding**. Experimental determination of aptamer 3D structure (X-ray crystallography, cryo-EM, NMR) is costly and time-consuming. In silico approaches can:

- Predict aptamer 3D structure from sequence
- Validate thermodynamic stability under physiological conditions
- Screen binding affinity against target analytes
- Guide rational aptamer truncation and optimization

**Reference:** Kilgour et al., *J. Chem. Inf. Model.* 2021, 61(9), 4139–4144 (E2EDNA protocol)

## 3. Project Objectives

| # | Objective | Success Criteria |
|---|-----------|-----------------|
| O1 | Predict stable 3D fold of target aptamer sequence | RMSD converges < 0.3 nm over last 50 ns of production |
| O2 | Validate structural compactness and flexibility | Rg within 1.5–3.0 nm; RMSF peaks at loop regions only |
| O3 | Assess biosensing-relevant interactions | H-bond occupancy, base stacking persistence > 80% |
| O4 | Produce publication-quality analysis pipeline | Automated RMSD, RMSF, Rg, H-bond, SASA, 2D-P FS analysis |
| O5 | Benchmark computational resource usage | Track core-hours, storage per nanosecond |

## 4. System Definition

### 4.1 Biological Source
| Parameter | Value |
|-----------|-------|
| **Aptamer type** | Single-stranded DNA (ssDNA) aptamer |
| **Target length** | 20–80 nucleotides (typical biosensor aptamer) |
| **Input format** | FASTA sequence + optional 2D structure (dot-bracket notation) |
| **Structure prediction tool** | NUPACK (secondary) → MMB/AlphaFold2-RNA (tertiary) |
| **PDB source** | User-provided or E2EDNA2-predicted starting structure |

### 4.2 Target Ensemble
| Parameter | Value |
|-----------|-------|
| **Production ensemble** | NPT (Nosé-Hoover + Parrinello-Rahman) |
| **Equilibration sequence** | Energy Min → NVT → NPT |
| **Temperature** | 310.15 K (physiological, biosensor operating temp) |
| **Pressure** | 1.0 bar (ambient, Parrinello-Rahman barostat) |
| **pH** | ~7.4 (implicit in force field protonation) |

### 4.3 Force Field & Solvation
| Parameter | Value |
|-----------|-------|
| **Force field (DNA)** | AMBER99bsc1 (bsc1 corrections for α/γ, χOL3 for RNA) |
| **Water model** | TIP3P (standard) or SPC/E |
| **Solvation** | Explicit water, dodecahedral box |
| **Ion concentration** | 0.15 M NaCl (physiological) |
| **Counterions** | Na⁺/Cl⁻ to neutralize + 0.15 M |

### 4.4 Boundary Conditions
| Parameter | Value |
|-----------|-------|
| **Box type** | Dodecahedral (minimal image convention) |
| **Box padding** | 1.2 nm minimum from solute to box edge |
| **PME** | Particle Mesh Ewald for long-range electrostatics |
| **Cutoff** | 1.0 nm for VDW and Coulomb real-space |
| **Constraints** | LINCS (hydrogen bonds) |

## 5. Key References

| # | Reference | Relevance |
|---|-----------|-----------|
| R1 | Kilgour et al. (2021) *JCIM* — E2EDNA | End-to-end aptamer simulation protocol |
| R2 | Rodríguez Serrano et al. (2022) *JCISD* | Aptamer–small molecule interaction MD |
| R3 | Díaz-Fernández et al. (2025) *ChemRxiv* | Aptamer truncation & MD refinement |
| R4 | Autiero et al. (2023) *Mol. Biophys.* | Enhanced MD for RNA aptamer long-range effects |
| R5 | Yekeen et al. (2023) *GigaScience* — CHAPERONg | Automated GROMACS analysis pipeline |
| R6 | Zgarbová et al. (2011) *JCTC* | AMBER99bsc1 force field |
| R7 | Banáš et al. (2022) *JCTC* | OL15 force field for DNA |
| R8 | iGEM Aptamers Hub | Computational tools for aptamer design |

## 6. Assumptions

1. The aptamer sequence is available in FASTA format
2. The target analyte structure (if applicable) is available in PDB/SDF format
3. GROMACS 2023+ is installed with GPU acceleration
4. AmberTools (ante chamber, pdb4amber) is available for parameterization
5. The simulation aims for nanosecond-scale production runs (100–500 ns typical)

## 7. Constraints

- **Computational:** Single GPU (RTX 3080/4090) or small cluster allocation
- **Storage:** ~50–200 GB per 500 ns run (uncompressed .trr); compressed .xtc preferred
- **Time:** Production runs at 20–100 ns/day depending on system size

## 8. Approvals

| Role | Name | Signature | Date |
|------|------|-----------|------|
| PI / Sponsor | _____________ | _____________ | ___/___/2026 |
| Computational Lead | _____________ | _____________ | ___/___/2026 |
| MD Specialist | _____________ | _____________ | ___/___/2026 |

---
*Generated: 2026-09-02 | Project: GROMACS_NA53*
