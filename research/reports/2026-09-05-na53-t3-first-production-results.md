# NA53 (NGAL aptamer) — First Production Results & Throughput Calibration (Taiwania-3 ct56)

**Run date:** 2026-09-05 · **Cluster:** Taiwania-3, CPU `ct56` partition (account `mst115368`), conda-forge GROMACS 2024.4 single precision, 56 cores/node, 95 h walltime
**System:** NA53 75-nt ssDNA aptamer (`structures/NA53.fasta`) + Na⁺/Cl⁻ + water — **290,578 atoms**, 2 fs timestep, 310 K, 1 bar, PME, `rcoulomb`/`rvdw` 0.8 nm (`configs/*.mdp`)
**Scripts:** `run_simulation.sh submit --profile taiwania3_cpu --ns N` → chain 01 prep → 02 equil → 03 prod → 04 analysis (sbatch, afterok)

---

## 1. Runs completed (timeline)

| Chain | Jobs | Outcome |
|---|---|---|
| Smoke (1 ns prod) | 2033887 (equil), 2033888 (prod), 2033889 (analysis) | ✅ completed end-to-end; analysis produced **8 figures** (`results/figures/`) |
| Duplicate chain (1 ns) | 2034005–2034008 | ❌ submitted by mistake alongside the first chain, **cancelled** (workspace collision on `topol.top`/`prod.*` avoided) |
| 4 ns run | — | ⚠️ **never actually submitted** (an earlier "queued/running/finished" reading was a stale-suggestion artifact; no 4 ns job ever ran) |
| **15 ns run** | submitted 2026-09-05 `--ns 15` | ▶ expected ~25.5 h total wall; analysis auto-runs at chain end |

## 2. Measured throughput — the calibration number

| Stage | Cores | ns/day | h/ns |
|---|---|---|---|
| NPT2 (equilibration) | 28 MPI threads | **15.885** | 1.511 |
| Production (smoke sample) | 56 | **~15.1** (490 ps in ~47 min) | ~1.6 |

- The 290k-atom system does **not** scale from 28 → 56 cores (no meaningful gain); **~15 ns/day is the practical production rate** → 1 ns ≈ 1.6 h of compute.
- The definitive production number comes from the 15 ns run's `logs/na53_prod_*.out` `Performance:` line (SLURM capture — sbatch runs mdrun with no internal redirect).

## 3. First production analysis (1 ns smoke) — structural metrics (valid)

All 101 frames (1 ns @ 2 fs). mean / min / max / stdev / final:

| Metric | mean | min | max | stdev | final | Read |
|---|---|---|---|---|---|---|
| RMSD (nm) | 0.6519 | 0.0000 | 0.9288 | 0.2036 | 0.6727 | still relaxing — drift up to ~1 nm from start structure; 1 ns is **not converged** |
| Rg (nm) | 2.8091 | 2.5449 | 3.1343 | 0.1268 | 2.5787 | **compact folded domain** (fully extended 75-nt chain would be ~14 nm) |
| SASA (nm²) | 149.38 | 146.49 | 152.00 | 1.09 | 150.01 | very stable — no unfolding events |
| Intra-DNA H-bonds | 70.78 | 63 | 81 | 3.32 | 68 | extensive secondary structure (base pairing/stacking) |
| Temp (K) | 310.14 | 308.71 | 311.54 | 0.54 | 310.37 | thermostat healthy ✓ |
| RMSF (nm) | mean 0.3553 overall | — | — | — | — | **top-3 flexible: residues 75 (1.120), 74 (0.856), 73 (0.741)** → floppy 3′ tail; rest of chain ordered |

**Interpretation:** NA53 folds into a stable, compact globule (~2.8 nm Rg) with extensive internal base-pairing (~71 H-bonds), a very stable solvent-accessible surface, and a flexible 3′ terminal tail — typical aptamer architecture (binding pocket internal, terminus free). The RMSD was still drifting at 1 ns, which is the core argument for the 100 ns target.

## 4. Energy-term extraction bug — found and fixed

**Symptom (smoke analysis):** Pressure ≈ **988 bar**, Density ≈ **179 kg/m³**, "Potential" ≈ **+68,312 kJ/mol**.

**Cause:** `04_analysis.sh` used `gmx energy` term IDs `23:Pressure`, `24:Density`, `10:Potential`, `21:Conserved-En` — which in gmx 2024.x map to **virial tensor components and Coul. recip.**, not the named terms. Smoking gun: the extracted "Potential" (68,312) matched the production log's Coul. recip. value (6.79e4) exactly.

**Fix (`f217451`):** correct gmx 2024.x IDs — `15:Temperature` (was already right), `17:Pressure`, `36:Density`, `11:Potential`, `14:Conserved-En`.

**Fallout:** the smoke's `energy_terms.png` / `summary_dashboard.png` carry the wrong pressure/density/potential; re-extraction was impossible because `prod.edr` was deleted during the fresh-run cleanup → **correct energy figures come only from the 15 ns chain's auto-analysis**. A fail-fast guard was added (`f6a52e0`): `04_analysis.sh` exits with a message if `gmx` is missing from PATH (the `(base)` conda-env footgun that caused silent per-tool failures).

## 5. Throughput / ETA comparison (at measured ~15 ns/day; prep+equil ≈ 1.5 h fixed)

| Run | Prod compute | 95 h segments | **Total wall (ETA)** | Steps (2 fs) | xtc size | Verdict |
|---|---|---|---|---|---|---|
| **1 ns** | 1.6 h | 1 | **~3 h** | 0.5 M | 0.10 GB | ✅ smoke — done; validates the chain |
| **4 ns** | 6.4 h | 1 | **~8 h** | 2 M | 0.42 GB | methods + preliminary stats (never run) |
| **15 ns** | 24 h | 1 | **~25.5 h** | 7.5 M | 1.6 GB | ▶ production pilot — running; fits one job, no RESTART |
| **100 ns** | 6.7 d | 2 (59 + 41 ns) | **~6 d 18 h** | 50 M | 10.4 GB | 🎯 target dataset — RESTART chaining |
| **500 ns** | 33.3 d | 9 | **~35 d** | 250 M | 52 GB | feasible but needs a RESTART-loop script + storage |
| **1000 ns** | 66.7 d | 17 | **~67 d** | 500 M | 104 GB | impractical on CPU ct56 — GPU or replica strategy |

**Scaling rule:** ETA = `15/R × 24 h + 1.5 h` where `R` = measured ns/day (at 12 ns/day → ~31.5 h for 15 ns; at 18 → ~21.5 h).

## 6. Data provenance

- **Durable record:** this report + `memory.md`. Raw artifacts are gitignored by design (`/analysis/`, `/results/`, `logs/*.out`).
- **Raw artifacts live on T3:** `analysis/*.xvg` + `*.log`, `results/figures/*.png` (8: rmsd, rmsf, gyrate, sasa, hbonds, pca, energy_terms, summary_dashboard), `logs/na53_prod_2033888.out` (Performance line), `scripts/prod.tpr`.
- **Not recoverable:** smoke `prod.xtc` / `prod.edr` / `prod.cpt` — deleted during the fresh-run cleanup (intended; only the raw trajectory/checkpoint were lost, figures + xvg data survive).
- **Stale:** the figures regenerated from old `.xvg` between runs (energy panels wrong, see §4). Final figures come from the 15 ns chain.

## 7. Next steps

1. **15 ns run** → at chain end: analysis auto-runs (corrected IDs) → `bash scripts/summarize_analysis.sh` + the `Performance:` line → scientific read + lock 100 ns sizing to the measured rate.
2. **100 ns:** `submit --ns 100` (one tpr, 50 M steps) → prod wall-killed at ~95 h (~59–60 ns, checkpoint ≤15 min old) → `cd slurm/jobs && RESTART=1 sbatch 03_prod_taiwania3_cpu.sbatch` (run from `slurm/jobs/` so its `../` paths resolve to the repo) → completes remaining ~41 ns (~65 h) → analysis.
3. **500/1000 ns:** not practical on CPU ct56 (9/17 sequential 4-day jobs, ~5 weeks / ~2 months) — recommend a GPU allocation or a replica/sub-sampling strategy instead.