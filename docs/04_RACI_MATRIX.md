# 📊 RACI MATRIX
## MD Translation: The Pipeline Automation Script Dependencies Architecture

---

**Project ID:** GROMACS_NA53
**Version:** 1.0
**Date:** 2026-09-02

---

## 1. RACI Legend

| Code | Role | MD Translation |
|------|------|---------------|
| **R** | **Responsible** | Automation bash/python scripts generating coordinates and driving execution |
| **A** | **Accountable** | The master run-input configuration binary (.tpr), the ultimate ground truth for parameters during execution |
| **C** | **Consulted** | Topology headers (.top, .itp), providing foundational force field parameter definitions |
| **I** | **Informed** | Final parsed plot outputs (.xvg) and structural visualization trackers |

---

## 2. RACI Responsibility Assignment Matrix

### 2.1 WP1: Structure Preparation

| Task | Responsible (R) | Accountable (A) | Consulted (C) | Informed (I) |
|------|-----------------|-----------------|---------------|--------------|
| Parse FASTA input | `parse_fasta.py` | `input_sequence.fasta` | — | `logs/fasta_check.log` |
| Secondary structure prediction | `nupack` / `seqfold` | `secondary_structure.ct` | `aptamer_sequence.fasta` | `structures/prediction_2d.png` |
| 3D structure generation | `MMB` / `AlphaFold2-RNA` | `initial_3d.pdb` | `secondary_structure.ct` | `structures/3d_check.log` |
| Structure validation | `pdb4amber` | `clean.pdb` | `force_field.ff` | `structures/validation_report.txt` |
| Visual inspection | VMD/PyMOL (manual) | User | `clean.pdb` | Screenshot files |

### 2.2 WP2: System Preparation

| Task | Responsible (R) | Accountable (A) | Consulted (C) | Informed (I) |
|------|-----------------|-----------------|---------------|--------------|
| Topology generation | `01_system_prep.sh` → `gmx pdb2gmx` | `topol.top` | `force_field.ff`, `water_model.itp` | `logs/pdb2gmx.log` |
| Box definition | `01_system_prep.sh` → `gmx editconf` | `boxed.gro` | `topol.top` | `logs/box_check.log` |
| Solvation | `01_system_prep.sh` → `gmx solvate` | `solvated.gro` | `topol.top` | `logs/solvation.log` |
| Ions topology | `01_system_prep.sh` (manual edit) | `topol.top` (+ `ions.itp`) | — | `logs/topology_check.log` |
| Ion generation | `01_system_prep.sh` → `gmx genion` | `ionized.gro` | `topol.top`, `ions.tpr` | `logs/genion.log` |

### 2.3 WP3: Equilibration

| Task | Responsible (R) | Accountable (A) | Consulted (C) | Informed (I) |
|------|-----------------|-----------------|---------------|--------------|
| EM preparation | `02_equilibration.sh` → `gmx grompp` | `em.tpr` | `em.mdp`, `topol.top`, `ionized.gro` | `logs/grompp_em.log` |
| EM execution | `02_equilibration.sh` → `gmx mdrun` | `em.gro` | `em.tpr` | `logs/em.log`, `em.edr` |
| EM validation | `plot_em.py` | `potential.xvg` | `em.edr` | `analysis/em_potential.png` |
| NVT preparation | `02_equilibration.sh` → `gmx grompp` | `nvt.tpr` | `nvt.mdp`, `topol.top`, `em.gro` | `logs/grompp_nvt.log` |
| NVT execution | `02_equilibration.sh` → `gmx mdrun` | `nvt.gro` | `nvt.tpr` | `logs/nvt.log`, `nvt.edr` |
| NVT validation | `plot_nvt.py` | `temperature.xvg` | `nvt.edr` | `analysis/nvt_temp.png` |
| NPT preparation | `02_equilibration.sh` → `gmx grompp` | `npt1.tpr`, `npt2.tpr` | `npt.mdp`, `topol.top`, `nvt.gro` | `logs/grompp_npt.log` |
| NPT execution | `02_equilibration.sh` → `gmx mdrun` | `npt2.gro` | `npt2.tpr` | `logs/npt.log`, `npt2.edr` |
| NPT validation | `plot_npt.py` | `density.xvg` | `npt2.edr` | `analysis/npt_density.png` |

### 2.4 WP4: Production MD

| Task | Responsible (R) | Accountable (A) | Consulted (C) | Informed (I) |
|------|-----------------|-----------------|---------------|--------------|
| Production preparation | `03_production.sh` → `gmx grompp` | `prod.tpr` | `prod.mdp`, `topol.top`, `npt2.gro` | `logs/grompp_prod.log` |
| Production execution | `03_production.sh` → `gmx mdrun` | `prod.xtc` | `prod.tpr` | `logs/prod.log`, `prod.edr` |
| Real-time monitoring | `monitor.sh` (watch) | `monitor.xvg` | `prod.edr` | Terminal output |
| Checkpoint management | `03_production.sh` | `prod.cpt` | `prod.tpr` | `logs/checkpoint.log` |
| Trajectory stripping | `gmx trjconv` (manual) | `prod_strip.xtc` | `prod.tpr` | `logs/trjconv.log` |

### 2.5 WP5: Analysis

| Task | Responsible (R) | Accountable (A) | Consulted (C) | Informed (I) |
|------|-----------------|-----------------|---------------|--------------|
| RMSD calculation | `gmx rms` (via `04_analysis.sh`) | `rmsd.xvg` | `prod.tpr`, `prod.xtc` | `analysis/rmsd.png` |
| RMSF calculation | `gmx rmsf` (via `04_analysis.sh`) | `rmsf.xvg` | `prod.tpr`, `prod.xtc` | `analysis/rmsf.png` |
| Rg calculation | `gmx gyrate` (via `04_analysis.sh`) | `gyrate.xvg` | `prod.tpr`, `prod.xtc` | `analysis/gyrate.png` |
| H-bond analysis | `gmx hbond` (via `04_analysis.sh`) | `hbnum.xvg` | `prod.tpr`, `prod.xtc` | `analysis/hbond.png` |
| SASA calculation | `gmx sasa` (via `04_analysis.sh`) | `sasa.xvg` | `prod.tpr`, `prod.xtc` | `analysis/sasa.png` |
| PCA analysis | `gmx covar` + `gmx anaeig` | `eigenval.xvg`, `proj.xvg` | `prod.tpr`, `prod.xtc` | `analysis/pca.png` |
| FEL calculation | `free_energy_landscape.py` | `fel_2d.dat` | `proj.xvg` | `analysis/FEL.png` |
| MM-PBSA (if ligand) | `gmx_MMPBSA` | `binding_energy.dat` | `prod.xtc`, `prod.tpr` | `analysis/mmpbsa.png` |
| Clustering | `gmx cluster` | `cluster.xvg`, representative `.gro` | `prod.tpr`, `prod.xtc` | `analysis/clusters.png` |
| Visualization | `05_visualization.py` | Rendered images | `prod.xtc`, `prod.tpr` | `results/figures/` |
| Report generation | `generate_report.py` | `final_report.pdf` | All analysis files | `results/report/` |

---

## 3. Script Dependency Map

```
INPUT FILES                    SCRIPTS                          OUTPUT FILES
───────────                    ───────                          ────────────

input_sequence.fasta    ──→    parse_fasta.py            ──→    clean.fasta
                                    │
secondary_structure     ──→    fold_aptamer.py           ──→    initial_3d.pdb
                                    │
clean.pdb               ──→    01_system_prep.sh         ──→    ionized.gro, topol.top
                                    │
ionized.gro + topol.top ──→    02_equilibration.sh       ──→    npt2.gro, prod.tpr
                                    │
npt2.gro + prod.mdp     ──→    03_production.sh          ──→    prod.xtc, prod.edr
                                    │
prod.xtc + prod.tpr     ──→    04_analysis.sh            ──→    *.xvg
                                    │
*.xvg + prod.xtc        ──→    05_visualization.py       ──→    *.png, *.pdf
                                    │
All results             ──→    generate_report.py        ──→    final_report.pdf
```

---

## 4. File Ownership & Integrity Map

### 4.1 Critical Files (Do NOT Edit After Execution)

| File | Created By | Read By | Purpose |
|------|------------|---------|---------|
| `prod.tpr` | `gmx grompp` | `gmx mdrun`, `gmx rms`, all analysis | **Ground truth** — all parameters frozen here |
| `topol.top` | `gmx pdb2gmx` | `gmx grompp`, `gmx solvate`, `gmx genion` | Topology definition |
| `em.gro` | `gmx mdrun` | `gmx grompp` (NVT) | Energy-minimized coordinates |
| `npt2.gro` | `gmx mdrun` | `gmx grompp` (production) | Equilibrated coordinates |

### 4.2 Read-Only After Production

| File | Created By | Read By | Purpose |
|------|------------|---------|---------|
| `prod.xtc` | `gmx mdrun` | All analysis tools | Compressed trajectory |
| `prod.edr` | `gmx mdrun` | `gmx energy`, monitoring | Energy terms |
| `prod.log` | `gmx mdrun` | Debugging | Execution log |

### 4.3 Regeneratable Files

| File | Regeneration Command | When to Regenerate |
|------|---------------------|-------------------|
| `solvated.gro` | `gmx solvate` | If box size changes |
| `ionized.gro` | `gmx genion` | If ion concentration changes |
| `*.tpr` files | `gmx grompp` | If .mdp parameters change |
| `*.xvg` analysis | Re-run analysis commands | If analysis parameters change |

---

## 5. Error Propagation Matrix

| If This Fails... | This Also Fails... | Recovery Action |
|-------------------|--------------------|-----------------|
| `pdb2gmx` | All downstream | Fix PDB naming, check FF selection |
| `solvate` | Ionization, equilibration | Check box definition, PDB completeness |
| `genion` | Equilibration, production | Check ions.mdp, topology completeness |
| EM (not converged) | NVT, NPT, production | Reduce emstep, increase maxsteps |
| NVT (temp drift) | NPT, production | Check thermostat, reduce dt |
| NPT (density unstable) | Production | Check barostat, extend NPT |
| Production (crash) | Analysis | Restart from checkpoint (.cpt) |

---

## 6. Conflict Avoidance Rules

1. **Never edit .tpr files** — regenerate with `gmx grompp` if changes needed
2. **Never modify topol.top during simulation** — topology must be frozen before `gmx mdrun`
3. **Never run two `gmx mdrun` on the same output prefix** — use different `-deffnm`
4. **Always use `-deffnm`** — prevents accidental overwrite of input files
5. **Always checkpoint** — `gmx mdrun` saves .cpt every 15 min by default
6. **Never delete .cpt files** — they are restart insurance
7. **Backup before re-running** — `mv output output_backup_$(date +%Y%m%d)`

---

*Generated: 2026-09-02 | Project: GROMACS_NA53*
