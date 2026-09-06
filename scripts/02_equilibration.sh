#!/bin/bash
# ============================================================
# 02_equilibration.sh — Equilibration Pipeline
# GROMACS_NA53
# ============================================================
# This script performs:
#   1. Energy Minimization (Steepest Descent)
#   2. NVT Equilibration (100 ps, positional restraints)
#   3. NPT Equilibration (100 ps restrained + 500 ps unrestrained)
#
# Usage: bash 02_equilibration.sh <ionized.gro> [gpu_flag]
# Example: bash 02_equilibration.sh system/NA53_ionized.gro -nb auto
# ============================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────
INPUT_GRO="${1:?Usage: $0 <ionized.gro> [gpu_flag]}"
GPU_FLAG="${2:--nb auto}"   # auto = GPU if available, else CPU (safe everywhere)
CONFIG_DIR="../configs"
LOG_DIR="../logs"
ANALYSIS_DIR="../analysis"
mkdir -p "$LOG_DIR" "$ANALYSIS_DIR"

BASENAME=$(basename "$INPUT_GRO" .gro)

# Runtime energy-term lookup (gmx energy IDs are per-.edr, NOT stable —
# hardcoded IDs caused the Density/Pressure/Potential mis-extraction bug
# class three times; see docs/INCIDENT_ANALYSIS.md V-class and
# gmx_energy_lib.sh header).
# shellcheck source=scripts/gmx_energy_lib.sh
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gmx_energy_lib.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NA53 EQUILIBRATION — $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Input: $INPUT_GRO"
echo "  GPU:   $GPU_FLAG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ═══════════════════════════════════════════════════════════
# STEP 1: ENERGY MINIMIZATION
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Step 1/6: Energy Minimization (Steepest Descent)..."

gmx grompp -f "$CONFIG_DIR/em.mdp" -c "$INPUT_GRO" \
    -p topol.top -o em.tpr \
    > "$LOG_DIR/grompp_em.log" 2>&1

gmx mdrun -v -deffnm em $GPU_FLAG \
    > "$LOG_DIR/mdrun_em.log" 2>&1

# Validate EM convergence (term looked up by name: NVT-style runs with
# position restraints shift the numbering, and EM writes no Pressure term,
# so IDs must never be assumed)
gmx_energy_extract em.edr "$ANALYSIS_DIR/em_potential.xvg" Potential >/dev/null || true
EM_POTENTIAL=$(awk '!/^[#@&]/{v=$2} END{printf "%.0f", v}' "$ANALYSIS_DIR/em_potential.xvg" 2>/dev/null || echo "?")
echo "  ✓ Energy minimization complete (final potential ≈ ${EM_POTENTIAL} kJ/mol)"
echo "  ℹ  Output: em.gro, em.edr"
# SANITY GATE — a positive or near-zero "potential" means the wrong term
# was extracted (bug-era em_potential.xvg held Coul. recip., +8.4e4 kJ/mol)
gmx_energy_check "$ANALYSIS_DIR/em_potential.xvg" "EM potential" -1000000000000 -1000 "kJ/mol"

# ═══════════════════════════════════════════════════════════
# STEP 2: NVT EQUILIBRATION (100 ps)
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Step 2/6: NVT Equilibration (100 ps, T=310.15 K)..."

gmx grompp -f "$CONFIG_DIR/nvt.mdp" -c em.gro -r em.gro \
    -p topol.top -o nvt.tpr \
    > "$LOG_DIR/grompp_nvt.log" 2>&1

gmx mdrun -deffnm nvt $GPU_FLAG \
    > "$LOG_DIR/mdrun_nvt.log" 2>&1

# Validate temperature (term looked up by name — nvt.edr contains a
# Position-Rest. entry that shifts Temperature to a different ID)
echo "  ℹ  Checking temperature..."
gmx_energy_extract nvt.edr "$ANALYSIS_DIR/nvt_temperature.xvg" Temperature || true
# SANITY GATE — bug-era nvt_temperature.xvg held Conserved-En (-4.09e6)
gmx_energy_check "$ANALYSIS_DIR/nvt_temperature.xvg" "NVT temperature" 300 320 "K"
echo "  ✓ NVT equilibration complete"
echo "  ℹ  Output: nvt.gro, nvt.edr"

# ═══════════════════════════════════════════════════════════
# STEP 3: NPT EQUILIBRATION — RESTRAINED (100 ps)
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Step 3/6: NPT Equilibration — Restrained (100 ps, backbone restraints)..."

gmx grompp -f "$CONFIG_DIR/npt.mdp" -c nvt.gro -r nvt.gro \
    -p topol.top -o npt1.tpr \
    > "$LOG_DIR/grompp_npt1.log" 2>&1

gmx mdrun -deffnm npt1 $GPU_FLAG \
    > "$LOG_DIR/mdrun_npt1.log" 2>&1

echo "  ✓ Restrained NPT complete"

# ═══════════════════════════════════════════════════════════
# STEP 4: NPT EQUILIBRATION — UNRESTRAINED (500 ps)
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Step 4/6: NPT Equilibration — Unrestrained (500 ps)..."

gmx grompp -f "$CONFIG_DIR/npt_free.mdp" -c npt1.gro \
    -p topol.top -o npt2.tpr \
    > "$LOG_DIR/grompp_npt2.log" 2>&1

gmx mdrun -deffnm npt2 $GPU_FLAG \
    > "$LOG_DIR/mdrun_npt2.log" 2>&1

echo "  ✓ Unrestrained NPT complete"

# ═══════════════════════════════════════════════════════════
# STEP 5: EQUILIBRATION VALIDATION
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Step 5/6: Equilibration Validation..."

# Extract density / temperature / pressure (names, not hardcoded IDs)
gmx_energy_extract npt2.edr "$ANALYSIS_DIR/npt2_density.xvg" Density || true
gmx_energy_extract npt2.edr "$ANALYSIS_DIR/npt2_temperature.xvg" Temperature || true
gmx_energy_extract npt2.edr "$ANALYSIS_DIR/npt2_pressure.xvg" Pressure || true

# SANITY GATES — steady-state mean must sit at physical values
# (T ref 310.15 K, P ref 1.0 bar, ρ ≈ water ~997 kg/m³). Bug-era files
# carried pV / Density in the wrong slots (178.8 kg/m³ "density",
# 988.7 kg/m³ "pressure") — both windows below catch those swaps.
gmx_energy_check "$ANALYSIS_DIR/npt2_density.xvg" "NPT2 density" 950 1050 "kg/m^3"
gmx_energy_check "$ANALYSIS_DIR/npt2_temperature.xvg" "NPT2 temperature" 300 320 "K"
gmx_energy_check "$ANALYSIS_DIR/npt2_pressure.xvg" "NPT2 pressure" -100 100 "bar"

echo "  ✓ Validation plots generated in $ANALYSIS_DIR/"

# ═══════════════════════════════════════════════════════════
# STEP 6: SUMMARY
# ═══════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  EQUILIBRATION COMPLETE — Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Stages completed:"
echo "    ✓ EM:    em.gro    (energy minimized)"
echo "    ✓ NVT:   nvt.gro   (temperature equilibrated)"
echo "    ✓ NPT1:  npt1.gro  (pressure equilibrated, restrained)"
echo "    ✓ NPT2:  npt2.gro  (density equilibrated, free)"
echo ""
echo "  Validation files:"
echo "    $ANALYSIS_DIR/em_potential.xvg"
echo "    $ANALYSIS_DIR/nvt_temperature.xvg"
echo "    $ANALYSIS_DIR/npt2_density.xvg"
echo "    $ANALYSIS_DIR/npt2_temperature.xvg"
echo "    $ANALYSIS_DIR/npt2_pressure.xvg"
echo ""
echo "  CHECK BEFORE PRODUCTION:"
echo "    □ EM converged (Fmax < 1000 kJ/mol/nm)"
echo "    □ NVT temperature stable at 310.15 K ± 2 K"
echo "    □ NPT density stable at ~1000 kg/m³"
echo "    □ NPT pressure stable at ~1.0 bar"
echo ""
echo "  Next step: Run 03_production.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
