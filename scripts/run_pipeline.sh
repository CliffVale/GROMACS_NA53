#!/bin/bash
# ============================================================
# run_pipeline.sh — MASTER PIPELINE RUNNER
# GROMACS_NA53
# ============================================================
# Executes the complete aptamer 3D folding pipeline.
#
# Usage: bash run_pipeline.sh <input.pdb> [force_field] [water_model] [gpu_flag] [ns_length]
# Example: bash run_pipeline.sh structures/clean.pdb amber99sb-ildn tip3p -nb auto 100
#
# Or run individual stages:
#   bash run_pipeline.sh <input.pdb> --stage prep
#   bash run_pipeline.sh <input.pdb> --stage equil
#   bash run_pipeline.sh <input.pdb> --stage prod
#   bash run_pipeline.sh <input.pdb> --stage analysis
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Parse Arguments ──────────────────────────────────────
INPUT_PDB="${1:?Usage: $0 <input.pdb> [force_field] [water_model] [gpu_flag] [ns_length]}"
FF="${2:-amber99sb-ildn}"
WATER="${3:-tip3p}"
GPU_FLAG="${4:--nb auto}"
NS_LENGTH="${5:-500}"
STAGE="${6:-all}"  # all, prep, equil, prod, analysis

# ─── Banner ───────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  GROMACS_NA53: MASTER PIPELINE                      ║"
echo "║  Aptamer 3D Folding for Biosensing Applications             ║"
echo "║  $(date)                                         ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Input:    $INPUT_PDB"
echo "║  FF:       $FF"
echo "║  Water:    $WATER"
echo "║  GPU:      $GPU_FLAG"
echo "║  Length:   $NS_LENGTH ns"
echo "║  Stage:    $STAGE"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ─── Validate Input ───────────────────────────────────────
if [ ! -f "$INPUT_PDB" ]; then
    echo "❌ ERROR: Input file not found: $INPUT_PDB"
    exit 1
fi

# Check GROMACS is available
if ! command -v gmx &> /dev/null; then
    echo "❌ ERROR: GROMACS (gmx) not found in PATH"
    exit 1
fi

echo "✓ GROMACS version: $(gmx --version 2>&1 | head -2)"
echo "✓ Input file: $INPUT_PDB ($(wc -l < "$INPUT_PDB") lines)"
echo ""

# ─── Create directory structure ───────────────────────────
mkdir -p ../{structures,system,equilibration,production,analysis,results/figures,logs}

# Copy input PDB to structures directory
BASENAME=$(basename "$INPUT_PDB" .pdb)
cp "$INPUT_PDB" "../structures/${BASENAME}_input.pdb"

# ─── Execute Pipeline ─────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Starting pipeline..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# WP2: System Preparation
if [ "$STAGE" = "all" ] || [ "$STAGE" = "prep" ]; then
    echo "▶═══════════════════════════════════════════════════◀"
    echo "  WORK PACKAGE 2: SYSTEM PREPARATION"
    echo "◀═══════════════════════════════════════════════════▶"
    bash 01_system_prep.sh "../structures/${BASENAME}_input.pdb" "$FF" "$WATER"
    echo ""
fi

# WP3: Equilibration
if [ "$STAGE" = "all" ] || [ "$STAGE" = "equil" ]; then
    echo "▶═══════════════════════════════════════════════════◀"
    echo "  WORK PACKAGE 3: EQUILIBRATION"
    echo "◀═══════════════════════════════════════════════════▶"
    IONIZED_GRO=$(ls ../*_ionized.gro 2>/dev/null | head -1)
    if [ -z "$IONIZED_GRO" ]; then
        echo "❌ ERROR: No _ionized.gro found. Run 'prep' stage first."
        exit 1
    fi
    bash 02_equilibration.sh "$IONIZED_GRO" "$GPU_FLAG"
    echo ""
fi

# WP4: Production
if [ "$STAGE" = "all" ] || [ "$STAGE" = "prod" ]; then
    echo "▶═══════════════════════════════════════════════════◀"
    echo "  WORK PACKAGE 4: PRODUCTION MD"
    echo "◀═══════════════════════════════════════════════════▶"
    if [ ! -f "npt2.gro" ]; then
        echo "❌ ERROR: npt2.gro not found. Run 'equil' stage first."
        exit 1
    fi
    bash 03_production.sh "$GPU_FLAG" "$NS_LENGTH"
    echo ""
fi

# WP5: Analysis
if [ "$STAGE" = "all" ] || [ "$STAGE" = "analysis" ]; then
    echo "▶═══════════════════════════════════════════════════◀"
    echo "  WORK PACKAGE 5: ANALYSIS & VISUALIZATION"
    echo "◀═══════════════════════════════════════════════════▶"
    if [ ! -f "prod.xtc" ]; then
        echo "❌ ERROR: prod.xtc not found. Run 'prod' stage first."
        exit 1
    fi
    bash 04_analysis.sh prod 0
    python3 05_visualization.py ../analysis
    echo ""
fi

# ─── Completion ───────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PIPELINE COMPLETE — $(date)              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Output structure:    $BASENAME_ionized.gro → prod.gro       ║"
echo "║  Trajectory:          prod.xtc ($NS_LENGTH ns)               ║"
echo "║  Analysis:            ../analysis/*.xvg                      ║"
echo "║  Figures:             ../results/figures/*.png                ║"
echo "║                                                              ║"
echo "║  Review validation:                                        ║"
echo "║    □ RMSD converged (< 0.3 nm last 50 ns)                  ║"
echo "║    □ Rg stable (1.5–3.0 nm)                                ║"
echo "║    □ H-bonds > 80% occupancy                               ║"
echo "║    □ Temperature stable (310.15 ± 2 K)                     ║"
echo "║    □ Pressure stable (1.0 ± 1 bar)                         ║"
echo "║    □ Density stable (~1000 kg/m³)                           ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
