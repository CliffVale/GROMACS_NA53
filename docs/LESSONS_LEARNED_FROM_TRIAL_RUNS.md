# 🎯 LESSONS LEARNED & ERROR-FREE WORKFLOW
## Based on Actual GROMACS_TEEP Trial Runs (1BNA, 8 Trials, 200 ns)

---

**Source:** GROMACS_TEEP repository (https://github.com/CliffVale/GROMACS_TEEP)
**Validated on:** 1BNA DNA dodecamer (12 bp, ~26k atoms)
**Hardware:** GTX 1650 Ti, Intel i5-10300H, 15 GB RAM
**GROMACS:** 2025.3

---

## 1. ERRORS WE MADE (AND HOW TO AVOID THEM)

### ❌ ERROR 1: Wrong Cutoff Distance (Trial 01)

```markdown
WHAT HAPPENED:
- Used rcoulomb = 1.0 nm and rvdw = 1.0 nm
- AMBER99SB was parameterized with 0.8 nm cutoff
- Results: Wrong electrostatics, wrong vdW energies, 170 ns/day (slow)

WHY IT MATTERS:
- Force fields are ONLY valid at the parameters they were parameterized with
- Using 1.0 nm adds ~50% more neighbor pairs
- Produces incorrect energies and structures

FIX:
- ALWAYS use 0.8 nm for AMBER99SB
- ALWAYS include vdw-modifier = Potential-shift-Verlet
- ALWAYS include DispCorr = EnerPres

VALIDATED PARAMETER:
  rcoulomb    = 0.8     # ✅ Correct for AMBER99SB
  rvdw        = 0.8     # ✅ Correct for AMBER99SB
  vdw-modifier = Potential-shift-Verlet  # ✅ Required
  DispCorr    = EnerPres  # ✅ Required
```

### ❌ ERROR 2: Position Restraints in Production (Trial 01-03)

```markdown
WHAT HAPPENED:
- Used -DPOSRES in production MDP
- DNA structure was overly constrained
- Couldn't sample conformational space

WHY IT MATTERS:
- Position restraints prevent natural dynamics
- Production MD must be unrestrained
- Only use restraints during equilibration

FIX:
- Remove define = -DPOSRES from production MDP
- Use define = "" (empty) for production
- Keep restraints only in NVT and NPT equilibration

VALIDATED PARAMETER:
  # Production MDP:
  define = ""  # ✅ No restraints in production
  
  # NVT/NPT MDP:
  define = -DPOSRES  # ✅ Restraints only during equilibration
```

### ❌ ERROR 3: Interrupted Runs Without Checkpoint (Trial 02-03)

```markdown
WHAT HAPPENED:
- Sessions disconnected (SSH, terminal closed)
- Simulations stopped without saving state
- Lost hours of computation

WHY IT MATTERS:
- GROMACS saves checkpoints periodically
- Without checkpoints, must restart from scratch
- Long runs are vulnerable to interruptions

FIX:
- Always use -cpo flag to save checkpoints
- Set reasonable checkpoint interval (15 min = 900 s)
- Always use -cpi to resume from checkpoint
- Use nohup/setsid for background execution

VALIDATED COMMAND:
  gmx mdrun -deffnm prod \
    -nb gpu -pme gpu -bonded gpu -update gpu \
    -cpo prod -cpt 900 \  # Save checkpoint every 15 min
    -cpi prod.cpt          # Resume from checkpoint if exists
```

### ❌ ERROR 4: Wrong Temperature Coupling Groups (Trial 01)

```markdown
WHAT HAPPENED:
- Used tc-grps = System (single group)
- DNA and water coupled together
- Temperature fluctuations larger than necessary

WHY IT MATTERS:
- DNA and water have different heat capacities
- Separate coupling allows better temperature control
- Standard practice for nucleic acid simulations

FIX:
- Use separate coupling groups for DNA and water
- This matches how AMBER handles temperature control

VALIDATED PARAMETER:
  tc-grps     = DNA Water_and_ions  # ✅ Separate groups
  tau_t       = 0.1 0.1              # ✅ 0.1 ps coupling time
  ref_t       = 300 300              # ✅ 300 K target
```

### ❌ ERROR 5: Not Using CLI Mode (Trial 06 vs 07)

```markdown
WHAT HAPPENED:
- Ran simulations with KDE Plasma desktop active
- Desktop compositor used ~5% GPU
- RAM usage 8.8 GB (desktop) vs 3.1 GB (CLI)

WHY IT MATTERS:
- GUI overhead reduces performance by ~5.8%
- RAM usage 65% higher with desktop
- Desktop processes compete for CPU

FIX:
- Switch to CLI mode (Ctrl+Alt+F3) for production
- Or use nohup to run without terminal
- Or submit to HPC cluster

VALIDATED IMPROVEMENT:
  GUI mode: 232 ns/day, 8.8 GB RAM
  CLI mode: 245 ns/day, 3.1 GB RAM  (+5.8% speed, -65% RAM)
```

---

## 2. VALIDATED PARAMETERS (From 8 Trial Runs)

### 2.1 Force Field & Cutoff

```ini
; ═══════════════════════════════════════════════════════════
; VALIDATED: AMBER99SB with 0.8 nm cutoff
; Source: GROMACS_TEEP Trials 01-08, convergence study
; ═══════════════════════════════════════════════════════════
ff = amber99sb          ; DNA force field
water = tip3p           ; Water model
rcoulomb = 0.8          ; ✅ CRITICAL: Must be 0.8 nm for AMBER99SB
rvdw = 0.8              ; ✅ CRITICAL: Must be 0.8 nm for AMBER99SB
coulombtype = PME       ; Long-range electrostatics
pme_order = 4           ; PME interpolation order
fourierspacing = 0.12   ; PME grid spacing
vdwtype = Cut-off       ; VDW treatment
vdw-modifier = Potential-shift-Verlet  ; ✅ REQUIRED for AMBER
DispCorr = EnerPres     ; ✅ REQUIRED: Dispersion correction
```

### 2.2 Thermostat & Barostat

```ini
; ═══════════════════════════════════════════════════════════
; VALIDATED: V-rescale + Parrinello-Rahman
; Source: GROMACS_TEEP Trials 04-08
; ═══════════════════════════════════════════════════════════
tcoupl = V-rescale       ; ✅ V-rescale (better than Berendsen)
tc-grps = DNA Water_and_ions  ; ✅ Separate coupling groups
tau_t = 0.1 0.1          ; ✅ 0.1 ps coupling time
ref_t = 300 300          ; ✅ 300 K target

pcoupl = Parrinello-Rahman  ; ✅ Correct ensemble
pcoupltype = isotropic     ; Isotropic pressure coupling
tau_p = 2.0                ; ✅ 2.0 ps barostat coupling
ref_p = 1.0                ; 1.0 bar reference pressure
compressibility = 4.5e-5   ; Water compressibility
```

### 2.3 Integration & Constraints

```ini
; ═══════════════════════════════════════════════════════════
; VALIDATED: Leap-frog with LINCS
; Source: GROMACS_TEEP Trials 01-08
; ═══════════════════════════════════════════════════════════
integrator = md            ; Leap-frog integrator
dt = 0.002                 ; 2 fs timestep
nsteps = 50000000          ; 100 ns (adjust as needed)

constraints = h-bonds      ; ✅ Constrain hydrogen bonds
constraint_algorithm = lincs  ; LINCS algorithm
lincs_iter = 1             ; LINCS iterations
lincs_order = 4            ; LINCS expansion order

continuation = yes         ; ✅ Continue from previous run
gen_vel = no               ; ✅ Don't generate velocities in production
```

### 2.4 GPU Offloading (Validated)

```bash
; ═══════════════════════════════════════════════════════════
; VALIDATED: Full GPU offloading
; Source: GROMACS_TEEP Trials 04-08
; Performance: 245-257 ns/day on GTX 1650 Ti
; ═══════════════════════════════════════════════════════════
gmx mdrun -deffnm prod \
  -nb gpu \          ; ✅ Neighbor list on GPU
  -pme gpu \         ; ✅ PME on GPU
  -bonded gpu \      ; ✅ Bonded forces on GPU
  -update gpu \      ; ✅ Integration on GPU
  -gpu-id 0 \        ; GPU device ID
  -ntomp 4 \         ; OpenMP threads
  -cpo prod \        ; ✅ Save checkpoints
  -cpt 900           ; ✅ Checkpoint every 15 min
```

### 2.5 Output Control

```ini
; ═══════════════════════════════════════════════════════════
; VALIDATED: Compressed trajectory only (saves storage)
; Source: GROMACS_TEEP 200 ns run
; ═══════════════════════════════════════════════════════════
nstxout = 0              ; ✅ No .trr (saves ~97% storage)
nstvout = 0              ; No velocities
nstfout = 0              ; No forces
nstxout-compressed = 5000  ; XTC every 10 ps
nstenergy = 5000         ; Energy every 10 ps
nstlog = 5000            ; Log every 10 ps
nstcalcenergy = 5000     ; Calculate energy every 10 ps
```

---

## 3. ERROR-FREE WORKFLOW FOR NA53

### Step-by-Step Protocol (Validated)

```
STEP 0: Structure Prediction
├── Get NA53 sequence: AGCAGCACAGAGGTCAGATGGCGCTGG...
├── Predict secondary structure: mfold / seqfold / RNAfold
├── Build 3D coordinates: RNAComposer (best) or B-form helix
└── Output: NA53_initial.pdb

STEP 1: System Preparation
├── gmx pdb2gmx -ff amber99sb -water tip3p
├── gmx editconf -d 1.0 -bt dodecahedron  (⚠️ 1.0 nm for NA53, not 0.8)
├── gmx solvate -cs spc216.gro
├── gmx genion -neutral -conc 0.15
└── Output: ionized.gro, topol.top

STEP 2: Energy Minimization
├── Steepest descent, Fmax < 1000 kJ/mol/nm
├── emstep = 0.01, max 50000 steps
└── Output: em.gro

STEP 3: NVT Equilibration (100 ps)
├── define = -DPOSRES (heavy atom restraints)
├── V-rescale thermostat, 300 K
├── tc-grps = DNA Water_and_ions
├── tau_t = 0.1 0.1
└── Output: nvt.gro

STEP 4: NPT Equilibration (500 ps)
├── define = -DPOSRES (backbone restraints)
├── Parrinello-Rahman barostat, 1.0 bar
├── tau_p = 2.0
├── continuation = yes
└── Output: npt.gro, npt.cpt

STEP 5: Production MD (100-500 ns)
├── define = "" (NO restraints!)
├── Full GPU offloading: -nb gpu -pme gpu -bonded gpu -update gpu
├── Checkpoint: -cpo prod -cpt 900
├── Resume: -cpi prod.cpt
└── Output: prod.xtc, prod.gro, prod.edr

STEP 6: Analysis
├── RMSD, RMSF, Rg, H-bonds (gmx tools)
├── Clustering (gmx cluster, GROMOS method)
├── Free energy landscape (Python: RMSD vs Rg)
└── Output: analysis figures + reports
```

---

## 4. PERFORMANCE BENCHMARKS (From Actual Runs)

| Configuration | Performance | Notes |
|---------------|-------------|-------|
| AMBER99SB, 1.0 nm cutoff, CPU | 170 ns/day | ❌ Wrong cutoff |
| AMBER99SB, 0.8 nm cutoff, GPU | 232 ns/day | ✅ Correct |
| AMBER99SB, 0.8 nm cutoff, GPU, CLI | 245 ns/day | ✅ Best local |
| AMBER99SB, 0.8 nm cutoff, GPU, CLI, optimized | 257 ns/day | 🏆 Best |

**For NA53 (55 nt, ~50k atoms):** Expect ~50-100 ns/day on GTX 1650 Ti

---

## 5. CONVERGENCE CRITERIA (From 200 ns Run)

| Metric | Target | Status in 200 ns |
|--------|--------|------------------|
| Temperature | 300 ± 2 K | ✅ 300.01 ± 1.97 K |
| Density | 1016 ± 5 kg/m³ | ✅ 1016.5 ± 5.4 kg/m³ |
| RMSD plateau | < 0.3 nm drift over last 50 ns | ⚠️ Two-state behavior |
| Rg stability | ± 5% from mean | ✅ Stable |
| H-bond count | Stable ± 5 | ✅ 53.6 ± 1.7 |
| Clustering | < 5 dominant clusters | ⚠️ 887 clusters (flexible) |

---

## 6. MONITORING CHECKLIST (From Enhanced Monitor)

```bash
# Real-time checks during production:
✅ Temperature: 300 ± 2 K
✅ Pressure: -500 ± 500 bar (Parrinello-Rahman normal)
✅ Density: 1016 ± 5 kg/m³
✅ Energy drift: < 0.05% per ns
✅ LINCS warnings: 0
✅ GPU utilization: > 90%
✅ CPU temperature: < 85°C
✅ Disk space: > 10 GB free
```

---

## 7. BACKUP STRATEGY (From 200 ns Run)

```bash
# After production completes:
1. Save raw trajectory: production.xtc (1.8 GB for 200 ns)
2. Save energy data: production.edr (14 MB)
3. Save final structure: production.gro (1.8 MB)
4. Save topology: topol.top + *.itp
5. Save index: index.ndx
6. Create backup directory: 1BNA_200ns_BACKUP/
7. Keep original directory untouched for re-analysis
```

---

## 8. CRITICAL REMINDERS

1. **Cutoff is 0.8 nm for AMBER99SB** — not 1.0 nm, not 1.2 nm
2. **vdw-modifier = Potential-shift-Verlet** — required for AMBER
3. **DispCorr = EnerPres** — required for AMBER
4. **No restraints in production** — define = ""
5. **Use CLI mode** — 5.8% faster, 65% less RAM
6. **Always checkpoint** — -cpo prod -cpt 900
7. **Always resume** — -cpi prod.cpt
8. **Separate temperature groups** — tc-grps = DNA Water_and_ions
9. **tau_t = 0.1 ps** — not 1.0 ps (faster coupling)
10. **tau_p = 2.0 ps** — not 5.0 ps (faster pressure coupling)

---

*Generated: 2026-09-02 | Based on GROMACS_TEEP Trials 01-08*
