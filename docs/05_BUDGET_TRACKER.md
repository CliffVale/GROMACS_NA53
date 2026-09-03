# 💰 BUDGET TRACKER
## MD Translation: The Storage Allocation & GPU Core-Hour Ledger

---

**Project ID:** GROMACS_NA53
**Version:** 1.0
**Date:** 2026-09-02

---

## 1. Purpose

This tracker monitors computational resource consumption — **core-hours**, **GPU-hours**, and **storage footprint** — to prevent allocation exhaustion and cluster scratch directory overflow. Unlike financial budgets, the currency here is:

- **Time:** GPU-hours / CPU-hours consumed vs. allocation cap
- **Space:** Gigabytes consumed per nanosecond of simulation

---

## 2. Allocation Summary

### 2.1 Cluster / GPU Allocation

| Resource | Total Allocation | Used | Remaining | % Consumed |
|----------|-----------------|------|-----------|------------|
| **GPU-hours** | ___ hrs | 0 | ___ hrs | 0% |
| **CPU-hours** | ___ hrs | 0 | ___ hrs | 0% |
| **Storage (scratch)** | ___ GB | 0 | ___ GB | 0% |
| **Storage (project)** | ___ GB | 0 | ___ GB | 0% |

### 2.2 Per-Run Allocation Budget

| Run | Stage | Est. Duration | Est. Storage | Est. GPU-hours |
|-----|-------|---------------|-------------|----------------|
| System Prep | WP2 | ~5 min | ~0.1 GB | 0 |
| EM | WP3.1 | ~5 min | ~0.5 GB | 0.1 |
| NVT | WP3.2 | ~15 min | ~1 GB | 0.25 |
| NPT | WP3.3 | ~30 min | ~2 GB | 0.5 |
| Production (100 ns) | WP4 | ~12 hr (RTX 4090) | ~15 GB | 12 |
| Production (500 ns) | WP4 | ~60 hr | ~75 GB | 60 |
| Analysis | WP5 | ~30 min | ~1 GB | 0.1 |
| **TOTAL (500 ns)** | — | **~73 hr** | **~95 GB** | **~73 GPU-hr** |

---

## 3. Storage Budget

### 3.1 Estimated File Sizes (Per 500 ns Production)

| File | Format | Est. Size | Compression | Compressed Size |
|------|--------|-----------|-------------|-----------------|
| `prod.xtc` (trajectory) | XTC | 15–50 GB | — | 15–50 GB |
| `prod.tpr` (run input) | TPR | 50–200 MB | gzip | 20–80 MB |
| `prod.edr` (energy) | EDR | 50–100 MB | — | 50–100 MB |
| `prod.log` | LOG | 10–50 MB | — | 10–50 MB |
| `prod.cpt` (checkpoint) | CPT | 50–200 MB | — | 50–200 MB |
| `topol.top` + .itp | TOP | 1–5 MB | — | 1–5 MB |
| **TOTAL per run** | — | **15–50 GB** | — | **15–50 GB** |

### 3.2 Storage per Nanosecond

| Metric | Uncompressed (.trr) | Compressed (.xtc) | Savings |
|--------|---------------------|-------------------|---------|
| **GB per ns** (small aptamer, 10k atoms) | 2–5 GB/ns | 0.03–0.1 GB/ns | ~97% |
| **GB per ns** (medium aptamer, 30k atoms) | 5–15 GB/ns | 0.1–0.3 GB/ns | ~97% |
| **GB per ns** (large aptamer, 100k atoms) | 15–50 GB/ns | 0.3–1.0 GB/ns | ~97% |

**⚠️ CRITICAL:** Always use `.xtc` (compressed) for production trajectories. Disable `.trr` output:
```ini
nstxout = 0        ; No .trr (full precision)
nstxout-compressed = 5000  ; XTC every 10 ps
```

### 3.3 Storage Tracking Log

| Date | Stage | Files Added | Size (GB) | Cumulative (GB) | % of Budget |
|------|-------|-------------|-----------|-----------------|-------------|
| ___  | WP2   | topology    | ___       | ___             | ___%        |
| ___  | WP3.1 | EM output   | ___       | ___             | ___%        |
| ___  | WP3.2 | NVT output  | ___       | ___             | ___%        |
| ___  | WP3.3 | NPT output  | ___       | ___             | ___%        |
| ___  | WP4   | Production  | ___       | ___             | ___%        |
| ___  | WP5   | Analysis    | ___       | ___             | ___%        |

### 3.4 Storage Cleanup Protocol

| Action | When | Command |
|--------|------|---------|
| Remove `.trr` files | After production completes | `rm *.trr` |
| Compress trajectory | After analysis | `gmx trjconv -f prod.xtc -o prod_compressed.xtc -dt 100` |
| Remove intermediate equilibration files | After production starts | `rm em.* nvt.* npt*.*` |
| Archive completed runs | After analysis | `tar -czf run_YYYYMMDD.tar.gz *.xtc *.tpr *.edr *.gro *.xvg` |
| Clear scratch | After archiving | `rm -rf /scratch/$USER/NA53/` |

---

## 4. GPU/CPU Time Budget

### 4.1 Performance Estimates

| System Size | GPU | ns/day (estimated) | CPU-only ns/day |
|-------------|-----|---------------------|-----------------|
| Small aptamer (10k atoms) | RTX 4090 | 200–400 | 5–10 |
| Medium aptamer (30k atoms) | RTX 4090 | 50–150 | 1–3 |
| Large aptamer (100k atoms) | RTX 4090 | 10–30 | 0.2–0.5 |
| Small aptamer (10k atoms) | A100 80GB | 500–1000 | — |

### 4.2 Core-Hour Consumption Log

| Date | Run Name | Stage | GPU Type | Duration (hr) | GPU-hr | ns Completed | ns/day |
|------|----------|-------|----------|---------------|--------|--------------|--------|
| ___  | _______  | EM    | _______  | ___           | ___    | —            | —      |
| ___  | _______  | NVT   | _______  | ___           | ___    | —            | —      |
| ___  | _______  | NPT   | _______  | ___           | ___    | —            | —      |
| ___  | _______  | PROD  | _______  | ___           | ___    | ___          | ___    |
| ___  | _______  | ANA   | CPU      | ___           | ___    | —            | —      |
| **TOTAL** | —    | —     | —        | **___**       | **___** | **___**     | —      |

### 4.3 Allocation Burn Rate

```
Allocation:     ████████████████████████████████████████████ 100%
Used:           ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  20%
Remaining:      ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  80%

Burn rate:      ___ GPU-hr/day
Days remaining: ___ days at current rate
ETA:            ___/___/2026
```

---

## 5. Cost Optimization Strategies

| Strategy | Impact | Implementation |
|----------|--------|---------------|
| **Use .xtc instead of .trr** | ~97% storage savings | Set `nstxout = 0`, `nstxout-compressed = 5000` |
| **Reduce analysis trajectory frequency** | ~50% analysis I/O | `gmx trjconv -dt 100` before analysis |
| **Use GPU acceleration** | ~50x speedup | `gmx mdrun -nb gpu` |
| **Checkpoint restart** | Prevents wasted GPU-hr | Always use `-cpi` for long runs |
| **Batch analysis** | Reduces overhead | Run all analysis in single script |
| **Delete intermediate files** | ~30% storage savings | After successful production start |

---

## 6. Budget Alerts

| Alert Level | Condition | Action |
|-------------|-----------|--------|
| 🟢 **Green** | < 50% consumed | Continue normally |
| 🟡 **Yellow** | 50–75% consumed | Review remaining tasks, prioritize |
| 🟠 **Orange** | 75–90% consumed | Reduce production length, clean storage |
| 🔴 **Red** | > 90% consumed | Pause, request extension, archive results |

---

*Generated: 2026-09-02 | Project: GROMACS_NA53*
