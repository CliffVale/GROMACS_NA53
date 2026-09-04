# GROMACS_NA53 — Product Requirements Document (PRD)

| Field | Value |
|---|---|
| **Project name** | GROMACS_NA53 |
| **Status** | Active — Phase 3 (Scaffolding) complete, ready for execution |
| **Owner** | Cliff (IITD Masters student) |
| **AI assistant** | Buffy (Codebuff/Freebuff) |
| **Last updated** | 2026-09-03 |

---

## 1. Executive Summary

**GROMACS_NA53** is an in-silico pipeline that predicts the 3D folded structure of the **NA53 DNA aptamer** (75 nucleotides, targeting NGAL/Lipocalin-2 for biosensing) via **Molecular Dynamics (MD) simulation** with GROMACS, executed on the **Taiwania 3 HPC cluster** (CPU partitions). The pipeline covers: secondary-structure prediction → all-atom 3D model → system solvation/ionization → energy minimization → NVT/NPT equilibration → production MD → conformational analysis (RMSD, RMSF, Rg, H-bonds, PCA, clustering, free-energy landscape) → publication-grade figures.

The purpose is twofold:
1. **Scientific**: obtain the 3D fold and conformational ensemble of NA53, identify binding-competent conformations, and provide a structural basis for NGAL biosensor design.
2. **Engineering**: a fully reproducible, scripted, checkpointed pipeline whose every parameter is **verified** (from real trial runs and real cluster sessions) — a zero-hallucination reference for AI-assisted execution.

---

## 2. Problem Statement & Background

### 2.1 Scientific problem
NA53 is a 75-nt single-stranded DNA aptamer with reported nanomolar affinity (Kd ≈ 32.52 nM) for NGAL (Neutrophil Gelatinase-Associated Lipocalin), a biomarker for acute kidney injury. Biosensing applications require knowing its **3D structure and conformational behavior**, but ssDNA aptamers are flexible and their binding-competent conformation is unknown a priori.

### 2.2 Engineering problem
MD pipelines fail silently for three reasons, all encountered in our trial runs (GROMACS_TEEP):
1. **Wrong physics parameters** (e.g., 1.0 nm cutoff instead of 0.8 nm with AMBER force fields).
2. **Fabricated inputs** (e.g., partial PDB with 2 atoms/nucleotide that `pdb2gmx` cannot build topology from).
3. **Unverified cluster facts** (e.g., invented partition names, GPU modules that don't exist).

This project exists to eliminate those failure classes by recording **only what has been measured**, and by failing loudly when something is unverified.

---

## 3. Goals & Non-Goals

### 3.1 Goals (Must have)
| # | Goal | Priority |
|---|---|---|
| G1 | Predict NA53 3D fold from sequence (all-atom, pdb2gmx-compatible) | P0 |
| G2 | Run 100 ns production MD (minimum) on Taiwania 3 CPU, expandable to 300–500 ns | P0 |
| G3 | Equilibrate correctly: EM → NVT → NPT with verified MDP parameters | P0 |
| G4 | Conformational analysis: RMSD, RMSF, Rg, H-bonds, PCA, clustering, FEL | P1 |
| G5 | Full reproducibility: conda env, pinned versions, seed, scripts, SLURM jobs | P1 |
| G6 | Zero-hallucination AI workflow: every number traceable to a source or live command | P0 |

### 3.2 Non-goals (explicitly out of scope)
| # | Non-goal | Reason |
|---|---|---|
| N1 | GPU-accelerated MD on Taiwania 3 | GPU partitions restricted (`ngs*`) or down (`gpu-amd`); no CUDA module |
| N2 | AMBER engine (APTAMD/GaMD) | Requires commercial license; GROMACS is free |
| N3 | Full GaMD enhanced sampling (Phase 8+ possible) | Scope creep; revisit after cMD converges |
| N4 | Wet-lab validation | Out of computational scope (separate experimental plan exists) |
| N5 | Quantum mechanics / QM-MM | Unnecessary for folding study |
| N6 | RNA aptamer handling | NA53 is DNA; RNAComposer is explicitly rejected |

---

## 4. Target Users

| User | Role | Needs |
|---|---|---|
| **Cliff** (primary) | Researcher running the pipeline | Working scripts, verified parameters, honest estimates, clear next steps |
| **Buffy / AI agents** | Automation assistant | Ground truth files (this repo's docs) so it never guesses; explicit rules.md boundaries |
| **Future collaborators** | Lab mates / advisors | Reproducible protocol, clean docs, publication-ready figures |
| **Reviewers / graders** | MSc thesis committee | Methodology traceability (force field, water model, convergence checks) |
| **HPC admins (implicit)** | Taiwania 3 operations | Jobs that respect partitions, walltime, and login-node policy |

---

## 5. Features

| ID | Feature | Description | Priority |
|---|---|---|---|
| F-01 | Sequence validation & FASTA export | Validate A/T/C/G only; write `NA53.fasta` | P0 |
| F-02 | Secondary structure prediction | seqfold (primary) / RNAfold (fallback) → dot-bracket `.dbn` | P0 |
| F-03 | 3D structure intake | Accepts real all-atom PDB (AptaFold / w3DNA / 3dDNA); **refuses to fabricate** | P0 |
| F-04 | PDB sanity check | ≥10 atoms/residue validation before pdb2gmx | P0 |
| F-05 | Topology generation | `gmx pdb2gmx` with amber99sb-ildn + TIP3P | P0 |
| F-06 | Box + solvation + ions | dodecahedron 1.2 nm, SPC water, Na⁺/Cl⁻ 0.15 M neutralized | P0 |
| F-07 | Energy minimization | Steepest descent, Fmax < 1000 kJ/mol/nm | P0 |
| F-08 | NVT equilibration | 100 ps, 310.15 K, restraints | P0 |
| F-09 | NPT equilibration | 100 ps restrained + 500 ps free, 1.0 bar | P0 |
| F-10 | Production MD | Unrestrained NPT, ns-configurable, checkpoint every 15 min | P0 |
| F-11 | Analysis suite | RMSD, RMSF, Rg, H-bonds, SASA, PCA, clustering, FEL | P1 |
| F-12 | Visualization | matplotlib/seaborn publication figures | P1 |
| F-13 | SLURM deployment | 4 sbatch jobs + setup script for Taiwania 3 | P0 |
| F-14 | Restart/resume | `-cpo`/`-cpt` checkpoints; `RESTART=1` path | P0 |
| F-15 | CI validation | `bash -n` + Python syntax checks on every push | P2 |
| F-16 | AI-reference records | PRD/architecture/rules/phases/design/memory (this layer) | P0 |

---

## 6. Non-Functional Requirements

| Category | Requirement |
|---|---|
| **Performance** | ≥40 ns/day on Taiwania 3 `ct56` (56 cores) for ~45–65k-atom system; 100 ns ≤ 4-day walltime |
| **Portability** | Runs on CPU-only clusters; `-nb auto` default; local GTX 1650 Ti optional GPU path |
| **Reproducibility** | conda env pinned (`gromacs=2024.4`, python 3.10); deterministic seeds in MDPs; versions logged |
| **Storage** | Trajectories `.xtc` only (compressed); `.trr` never written; ≤50 GB working set; backup policy in docs/05 |
| **Fail-fast** | `set -euo pipefail` everywhere; explicit file-existence checks between stages |
| **Traceability** | Every MDP parameter cross-referenced to `docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md` or a citation |
| **Usability** | One command per stage; ~5 min from clone to first job on Taiwania 3 |

---

## 7. Success Metrics (KPIs)

| Metric | Target | Measurement |
|---|---|---|
| EM converges | Fmax < 1000 kJ/mol/nm | `gmx energy` from em.edr |
| NVT temperature | 310.15 K ± 2 K | nvt.edr |
| NPT density | ~1000 kg/m³ stable | npt2.edr |
| NPT pressure | ~1.0 bar | npt2.edr |
| Production throughput | ≥40 ns/day (CPU) | mdrun log `Performance` line |
| RMSD convergence | Plateau in last 50% of run | rmsd.xvg |
| Job success rate | 100% of submitted jobs complete or cleanly restart | slurm job logs |
| Rg stability | 1.5–3.5 nm plateau (75-nt ssDNA) | gyrate.xvg |

---

## 8. Constraints & Assumptions

### 8.1 Verified cluster facts (Taiwania 3, live session 2026-09-03)
| Fact | Value | Status |
|---|---|---|
| SSH | `u5662994@twnia3.nchc.org.tw`, 2FA (app OTP) | ✅ verified |
| Account | `mst115368` | ✅ verified via sacctmgr |
| MD partition | `ct56` — 56 cores, 754 GB RAM, 4-day max | ✅ verified via sinfo/scontrol |
| Modules | `gcc/13.2.0`; **no** cuda/cmake/openmpi/fftw modules | ✅ verified via module avail |
| GPU | Not viable: `ngs*` restricted, `gpu-amd` A100 down | ✅ verified via sinfo |
| GROMACS | conda-forge 2024.4 CPU (thread-MPI), no compile | ✅ verified via gmx --version |
| Policy | 15-min login timeout; intensive work must be scheduled | ✅ verified (motd) |

### 8.2 Assumptions
- NA53_initial.pdb will be generated with an external all-atom tool (AptaFold/w3DNA/3dDNA) — the pipeline validates but does not fabricate.
- 100 ns is the minimum scientifically defensible production length for this study; 300–500 ns preferred if walltime/queue permits.
- pH implicitly ~7; protonation states from AMBER defaults (no explicit pH handling).

---

## 9. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| pdb2gmx fails on input PDB | Medium | High | PDB sanity check (F-04); requires DA/DT/DG/DC naming; docs troubleshooting |
| Job killed at 4-day walltime | Certain (long runs) | Medium | Checkpoints every 15 min; RESTART=1 resume path |
| Wrong FF/water combo silently wrong physics | Low | High | MDPs locked & verified; params traceable to trial runs |
| conda env breaks on Taiwania 3 | Low | Medium | `setup_taiwania3.sh` re-creatable; environment.yml pinned |
| Login-node misuse (compile on login) | Medium | Policy violation | setup script runs compile-free (conda install); docs warn |
| Storage quota exceeded | Medium | Medium | .xtc only, cleanup protocol in docs/05 |

---

## 10. Release Plan (Milestones)

| Milestone | Deliverable | Phase | Status |
|---|---|---|---|
| M0 | AI-reference records + repo scaffold | 3 | ✅ done (this PRD included) |
| M1 | Real all-atom NA53_initial.pdb | 5 | ⬜ next |
| M2 | Prepared solvated system (ionized.gro + topol.top) | 6 | ⬜ |
| M3 | Equilibrated system (npt2.gro) passing KPIs | 7 | ⬜ |
| M4 | 100 ns production trajectory + checkpoint | 8 | ⬜ |
| M5 | Analysis pack: 7 metrics + figures | 9 | ⬜ |
| M6 | (Optional) 300–500 ns extension + publication pack | 10–11 | ⬜ |

---

*Traceability: all cluster facts verified in live SSH session; all MDP params from docs/LESSONS_LEARNED_FROM_TRIAL_RUNS.md. Nothing in this document is guessed.*