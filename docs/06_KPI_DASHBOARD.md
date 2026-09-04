# 📈 KPI DASHBOARD
## MD Translation: The Real-Time MD Performance & Thermodynamic Monitor

---

**Project ID:** GROMACS_NA53
**Version:** 1.0
**Date:** 2026-09-02

---

## 1. Purpose

This dashboard tracks vital simulation health indicators in real-time during production MD. It provides pass/fail criteria for thermodynamic stability, structural convergence, and computational performance — enabling immediate detection of simulation anomalies.

---

## 2. Performance KPIs

### 2.1 Simulation Speed

| KPI | Target | Warning | Critical | How to Measure |
|-----|--------|---------|----------|----------------|
| **ns/day** | > 100 (small sys) | < 50 | < 10 | `tail -5 prod.log \| grep "Performance"` |
| **ns/day (stable)** | ±10% over 10 hr | ±20% drift | ±50% drift | Rolling average from log |
| **ms/day** | > 1.0 | < 0.5 | < 0.1 | Calculated from ns/day |
| **Wall-clock per step** | < 10 ms | > 20 ms | > 100 ms | `grep "Step" prod.log` |
| **GPU utilization** | > 90% | 70–90% | < 70% | `nvidia-smi` |

### 2.2 Performance Monitoring Commands

```bash
# Real-time performance (watch every 30s):
watch -n 30 'tail -20 prod.log | grep -A 5 "Performance"'

# GPU utilization:
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,temperature.gpu,power.draw --format=csv -l 10

# GROMACS performance from log:
grep "Performance" prod.log | tail -1

# Estimated completion time:
grep "Time remaining" prod.log
```

---

## 3. Thermodynamic KPIs

### 3.1 Temperature Stability

| KPI | Target | Warning | Critical | How to Measure |
|-----|--------|---------|----------|----------------|
| **Mean temperature** | 310.15 ± 2 K | 310.15 ± 5 K | 310.15 ± 10 K | `gmx energy -f prod.edr -o temp.xvg` |
| **Temperature drift** | < 0.1 K/ns | > 0.5 K/ns | > 1.0 K/ns | Linear fit to temperature.xvg |
| **Temperature fluctuation (σ)** | < 3 K | > 5 K | > 10 K | Std. dev. of temperature.xvg |
| **Temperature autocorrelation** | τ < 1 ps | τ > 5 ps | τ > 20 ps | Autocorrelation analysis |

### 3.2 Pressure Stability

| KPI | Target | Warning | Critical | How to Measure |
|-----|--------|---------|----------|----------------|
| **Mean pressure** | 1.0 ± 1.0 bar | 1.0 ± 5.0 bar | 1.0 ± 10.0 bar | `gmx energy -f prod.edr -o press.xvg` |
| **Pressure drift** | < 0.1 bar/ns | > 0.5 bar/ns | > 1.0 bar/ns | Linear fit to pressure.xvg |
| **Box volume stability** | ±2% | ±5% | ±10% | `gmx energy -f prod.edr -o box.xvg` |

### 3.3 Energy Conservation

| KPI | Target | Warning | Critical | How to Measure |
|-----|--------|---------|----------|----------------|
| **Conserved energy drift** | < 0.01% over 1 ns | > 0.05% | > 0.1% | `gmx energy -f prod.edr -o conserved.xvg` |
| **Total energy drift** | < 0.05% over 1 ns | > 0.1% | > 0.5% | `gmx energy -f prod.edr -o total.xvg` |
| **Potential energy range** | Stable (no drift) | Slight trend | Significant trend | Plot potential.xvg |
| **Kinetic energy** | Stable (T-dependent) | Oscillating wildly | Diverging | Plot kinetic.xvg |

### 3.4 Thermodynamic Monitoring Commands

```bash
# Extract temperature:
gmx energy -f prod.edr -o analysis/temperature.xvg << EOF
15
EOF

# Extract pressure:
gmx energy -f prod.edr -o analysis/pressure.xvg << EOF
23
EOF

# Extract density:
gmx energy -f prod.edr -o analysis/density.xvg << EOF
24
EOF

# Extract potential energy:
gmx energy -f prod.edr -o analysis/potential.xvg << EOF
10
EOF

# Extract conserved energy:
gmx energy -f prod.edr -o analysis/conserved.xvg << EOF
21
EOF

# Extract box volume:
gmx energy -f prod.edr -o analysis/box_volume.xvg << EOF
34
EOF
```

---

## 4. Structural KPIs

### 4.1 Convergence Metrics

| KPI | Target | Warning | Critical | How to Measure |
|-----|--------|---------|----------|----------------|
| **RMSD (final 50 ns)** | < 0.3 nm | 0.3–0.5 nm | > 0.5 nm | `gmx rms -f prod.xtc -s prod.tpr` |
| **RMSD drift rate** | < 0.001 nm/ns | > 0.005 nm/ns | > 0.01 nm/ns | Slope of RMSD vs. time |
| **RMSD plateau** | Yes (last 100 ns) | Partial | No | Visual inspection of RMSD plot |
| **RMSF convergence** | σ < 0.1 nm between halves | 0.1–0.2 nm | > 0.2 nm | Compare RMSF first/second half |

### 4.2 Compactness Metrics

| KPI | Target | Warning | Critical | How to Measure |
|-----|--------|---------|----------|----------------|
| **Radius of gyration (Rg)** | 1.5–3.0 nm (aptamer) | ±20% from mean | ±50% from mean | `gmx gyrate -f prod.xtc -s prod.tpr` |
| **Rg fluctuation (σ)** | < 0.1 nm | 0.1–0.2 nm | > 0.2 nm | Std. dev. of gyrate.xvg |
| **Rg drift** | < 0.001 nm/ns | > 0.005 nm/ns | > 0.01 nm/ns | Linear fit |

### 4.3 Interaction Metrics

| KPI | Target | Warning | Critical | How to Measure |
|-----|--------|---------|----------|----------------|
| **H-bond occupancy (canonical)** | > 80% | 60–80% | < 60% | `gmx hbond -num hbnum.xvg` |
| **H-bond count (total)** | Stable ± 2 | ± 5 | > ± 10 | hbnum.xvg statistics |
| **Base stacking persistence** | > 70% | 50–70% | < 50% | Custom MDAnalysis script |
| **SASA (buried core)** | Stable ± 5% | ± 10% | > ± 20% | `gmx sasa -o sasa.xvg` |

### 4.4 Structural Monitoring Commands

```bash
# RMSD:
gmx rms -s prod.tpr -f prod.xtc -o analysis/rmsd.xvg -tu ns << EOF
4
4
EOF

# RMSF:
gmx rmsf -s prod.tpr -f prod.xtc -o analysis/rmsf.xvg -res << EOF
4
EOF

# Radius of gyration:
gmx gyrate -s prod.tpr -f prod.xtc -o analysis/gyrate.xvg << EOF
1
EOF

# Hydrogen bonds:
gmx hbond -s prod.tpr -f prod.xtc -num analysis/hbnum.xvg << EOF
1
1
EOF

# SASA:
gmx sasa -s prod.tpr -f prod.xtc -o analysis/sasa.xvg -tu ns << EOF
1
EOF
```

---

## 5. Dashboard Status Summary

### 5.1 Real-Time Status (Update During Production)

```
╔══════════════════════════════════════════════════════════════╗
║  GROMACS_NA53 PRODUCTION DASHBOARD                  ║
║  Date: ___/___/2026    Time: __:__                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  PERFORMANCE                                                 ║
║  ├── ns/day:      ___        [🟢 >100 | 🟡 50-100 | 🔴 <50] ║
║  ├── GPU util:    ___%       [🟢 >90% | 🟡 70-90% | 🔴 <70%]║
║  ├── Wall/step:   ___ ms     [🟢 <10  | 🟡 10-20  | 🔴 >20] ║
║  └── Time left:   ___ hrs                                  ║
║                                                              ║
║  THERMODYNAMICS                                              ║
║  ├── Temperature: ___ K      [🟢 310±2 | 🟡 ±5    | 🔴 ±10] ║
║  ├── Pressure:    ___ bar    [🟢 1±1   | 🟡 ±5    | 🔴 ±10] ║
║  ├── Density:     ___ kg/m³  [🟢 1000±20| 🟡 ±50  | 🔴 ±100]║
║  └── E_cons drift: ___ %/ns  [🟢 <0.01| 🟡 <0.05 | 🔴 >0.1]║
║                                                              ║
║  STRUCTURE                                                   ║
║  ├── RMSD:       ___ nm     [🟢 <0.3  | 🟡 <0.5  | 🔴 >0.5]║
║  ├── Rg:         ___ nm     [🟢 stable| 🟡 drift  | 🔴 erratic]║
║  ├── H-bonds:    ___ (avg)  [🟢 >80%  | 🟡 60-80%| 🔴 <60%]║
║  └── SASA:       ___ nm²    [🟢 stable| 🟡 drift  | 🔴 erratic]║
║                                                              ║
║  STORAGE                                                     ║
║  ├── XTC size:   ___ GB                                   ║
║  ├── EDR size:   ___ MB                                   ║
║  └── Total:      ___ GB / ___ GB (___%)                   ║
║                                                              ║
║  OVERALL STATUS:  [🟢 HEALTHY | 🟡 WARNING | 🔴 CRITICAL]   ║
╚══════════════════════════════════════════════════════════════╝
```

### 5.2 Automated Health Check Script

```bash
#!/bin/bash
# health_check.sh — Run during production to verify simulation health

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  NA53 SIMULATION HEALTH CHECK — $(date)           ║"
echo "╚══════════════════════════════════════════════════════════╝"

# 1. Performance
echo ""
echo "=== PERFORMANCE ==="
tail -20 prod.log | grep -A 5 "Performance" || echo "⚠️  Cannot read performance"

# 2. Temperature (last 100 frames)
echo ""
echo "=== TEMPERATURE ==="
gmx energy -f prod.edr -o /tmp/temp_check.xvg -b $(tail -1 prod.log | awk '{print $1-100}') <<EOF 2>/dev/null
15
EOF
if [ -f /tmp/temp_check.xvg ]; then
    awk 'NR>20{sum+=$2; sumsq+=$2*$2; n++} END{mean=sum/n; sd=sqrt(sumsq/n-mean*mean); printf "Mean: %.1f K | StdDev: %.1f K\n", mean, sd}' /tmp/temp_check.xvg
fi

# 3. Pressure (last 100 frames)
echo ""
echo "=== PRESSURE ==="
gmx energy -f prod.edr -o /tmp/press_check.xvg -b $(tail -1 prod.log | awk '{print $1-100}') <<EOF 2>/dev/null
23
EOF
if [ -f /tmp/press_check.xvg ]; then
    awk 'NR>20{sum+=$2; n++} END{mean=sum/n; printf "Mean: %.1f bar\n", mean}' /tmp/press_check.xvg
fi

# 4. Energy drift
echo ""
echo "=== CONSERVED ENERGY DRIFT ==="
gmx energy -f prod.edr -o /tmp/econs_check.xvg <<EOF 2>/dev/null
21
EOF
if [ -f /tmp/econs_check.xvg ]; then
    awk 'NR>20{if(NR==21){first=$2} last=$2; n++} END{drift=(last-first)/first*100; printf "Drift: %.4f%%\n", drift}' /tmp/econs_check.xvg
fi

# 5. Storage
echo ""
echo "=== STORAGE ==="
ls -lh prod.xtc prod.edr 2>/dev/null | awk '{print $5, $9}'

# 6. GPU
echo ""
echo "=== GPU STATUS ==="
nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw --format=csv,noheader 2>/dev/null || echo "nvidia-smi not available"

echo ""
echo "Health check complete."
```

---

## 6. Alert Thresholds Summary

| KPI | 🟢 GREEN | 🟡 YELLOW | 🔴 RED | Action on RED |
|-----|----------|-----------|--------|---------------|
| ns/day | > 100 | 50–100 | < 50 | Check GPU, reduce system size |
| Temperature | 310 ± 2 K | ± 5 K | ± 10 K | Check thermostat, restart |
| Pressure | 1.0 ± 1 bar | ± 5 bar | ± 10 bar | Check barostat, extend NPT |
| E_cons drift | < 0.01%/ns | < 0.05%/ns | > 0.1%/ns | Reduce timestep, check constraints |
| RMSD | < 0.3 nm | 0.3–0.5 nm | > 0.5 nm | Check if unfolding, review fold |
| H-bonds | > 80% | 60–80% | < 60% | Check base-pairing stability |
| Rg drift | < 0.001 nm/ns | < 0.005 nm/ns | > 0.01 nm/ns | May indicate unfolding |
| GPU util | > 90% | 70–90% | < 70% | Check background processes |
| Storage | < 50% | 50–75% | > 75% | Clean, compress, archive |

---

## 7. Automated Monitoring Script

```bash
#!/bin/bash
# monitor_production.sh — Continuous monitoring during production run

PROD_RUN="prod"
LOG_FILE="logs/health_monitor.log"

while true; do
    echo "=== $(date) ===" >> $LOG_FILE
    
    # Performance
    perf=$(grep "Performance" ${PROD_RUN}.log 2>/dev/null | tail -1 | awk '{print $2}')
    echo "ns/day: $perf" >> $LOG_FILE
    
    # Temperature (from last energy frame)
    gmx energy -f ${PROD_RUN}.edr -o /tmp/temp_mon.xvg -dt 1000 <<EOF 2>/dev/null
15
EOF
    temp=$(awk 'NR>10{sum+=$2; n++} END{printf "%.1f", sum/n}' /tmp/temp_mon.xvg 2>/dev/null)
    echo "Temperature: $temp K" >> $LOG_FILE
    
    # Disk usage
    disk=$(du -sh ${PROD_RUN}.xtc 2>/dev/null | awk '{print $1}')
    echo "XTC size: $disk" >> $LOG_FILE
    
    # GPU
    gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader 2>/dev/null)
    echo "GPU util: $gpu" >> $LOG_FILE
    
    sleep 600  # Check every 10 minutes
done
```

---

## 8. Implemented: Unified Health Reporting (2026-09-04)

§5.2 and §7 sketch manual scripts; the **implemented** flow replaces them:

| Piece | What it does | Where
|---|---|---|
| `scripts/health_report.sh` | One compact report, one vocabulary (✅ PASS / ⚠️ WARN / ❌ FAIL) across **H1 engine · H2 repo integrity · H3 gmx compat · H4 run KPIs** | `status`/`monitor`, local + remote |
| `scripts/check_repo_integrity.sh` | H2 — static repo health (files shipped, exec bits, MDP standard, placeholders) | CI on every push + H2 |
| `scripts/probe_gmx_compat.sh` | H3 — live probes of the gmx build (same flags `doctor` checks) | H3 |
| `./run_simulation.sh doctor` | Pre-run gate: H2 + H3 (+ group-layout G1) | before first start/submit |

### 8.1 KPI table → implementation map

| KPI table (above) | Implemented by | When |
|---|---|---|
| §2 Performance (ns/day) | H4 `ns/day` — measured from the `Performance:` line (finished) or estimated from log age (running) | every status/monitor |
| §2 Wall-clock/GPU | H4 sim-time + log-freshness; GPU via `nvidia-smi` on the node (manual) | during prod |
| §3 Thermodynamic | `gmx energy` in `04_analysis.sh` (energy_*.xvg → figures) | post-run |
| §4 Structural (RMSD/Rg/H-bonds/SASA) | `04_analysis.sh` → `05_visualization.py` (`summary_dashboard.png`) | post-run |
| Storage / budget | `docs/05_BUDGET_TRACKER.md` ledger | per run |

### 8.2 Calling the health report

```bash
# one-shot snapshot (what ./run_simulation.sh status now prints):
bash scripts/health_report.sh --profile taiwania3_cpu --quiet-integrity

# live monitoring (health block, then md log follow) — same on the cluster via SSH:
./run_simulation.sh status --profile taiwania3_cpu
./run_simulation.sh monitor --once --profile taiwania3_cpu
```

**Exit code:** 0 = healthy; 1 = a ❌ in H2/H3 — do not start/continue stages until fixed.
The stale-log rule: a live (not finished) mdrun whose log is untouched for > 600 s is
flagged ⚠️ as a possible hang. `doctor` stays the pre-flight gate; `status`/`monitor`
report the same signals *during* the run, on any machine.

---

*Generated: 2026-09-02 (rev. 2026-09-04: §8 unified health reporting) | Project: GROMACS_NA53*
