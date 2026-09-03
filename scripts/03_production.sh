#!/bin/bash
# ============================================================
# 03_production.sh — Production MD Run
# GROMACS_NA53
# ============================================================
# This script runs unrestrained NPT production MD.
# Duration: 500 ns (adjustable via NSteps)
#
# Usage: bash 03_production.sh [gpu_flag] [ns_length]
# Example: bash 03_production.sh -nb auto 100     (auto-detect; CPU-safe)
# Example: bash 03_production.sh -nb gpu 500       (explicit GPU, local machine)
# ============================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────
GPU_FLAG="${1:--nb auto}"
NS_LENGTH="${2:-500}"            # Production length in nanoseconds
CONFIG_DIR="../configs"
LOG_DIR="../logs"
ANALYSIS_DIR="../analysis"
mkdir -p "$LOG_DIR" "$ANALYSIS_DIR"

NSTEPS=$((NS_LENGTH * 500000))  # ns × 500,000 steps/ns (2 fs timestep)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NA53 PRODUCTION MD — $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Duration: $NS_LENGTH ns ($NSTEPS steps)"
echo "  GPU:      $GPU_FLAG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Check equilibrated structure exists ──────────────────
if [ ! -f "npt2.gro" ]; then
    echo "❌ ERROR: npt2.gro not found. Run 02_equilibration.sh first."
    exit 1
fi

# ─── Prepare production MDP ──────────────────────────────
# Copy production MDP and adjust nsteps
cp "$CONFIG_DIR/prod.mdp" prod_mdp_temp.mdp
sed -i "s/nsteps.*/nsteps          = $NSTEPS/" prod_mdp_temp.mdp
echo "  ℹ  Production MDP prepared ($NS_LENGTH ns)"

# ─── Generate TPR ────────────────────────────────────────
echo ""
echo "▶ Generating production TPR..."
gmx grompp -f prod_mdp_temp.mdp -c npt2.gro \
    -p topol.top -o prod.tpr \
    > "$LOG_DIR/grompp_prod.log" 2>&1

echo "  ✓ prod.tpr generated"
rm -f prod_mdp_temp.mdp

# ─── Run production MD ───────────────────────────────────
echo ""
echo "▶ Starting production MD ($NS_LENGTH ns)..."
echo "  ℹ  Checkpoint saved every 15 minutes (prod.cpt)"
echo "  ℹ  Monitor: tail -f $LOG_DIR/mdrun_prod.log"
echo ""

# Full explicit offload only when GPU requested; otherwise let mdrun decide
MD_ARGS="$GPU_FLAG"
if [ "$GPU_FLAG" = "-nb gpu" ]; then
    MD_ARGS="-nb gpu -pme gpu -bonded gpu -update gpu -gpu-id 0"
fi

gmx mdrun -deffnm prod $MD_ARGS -ntomp 4 \
    -cpo prod -cpt 900 \
    > "$LOG_DIR/mdrun_prod.log" 2>&1 &

PROD_PID=$!
echo "  ℹ  Production MD started (PID: $PROD_PID)"
echo "  ℹ  To resume after interruption:"
echo "      gmx mdrun -deffnm prod $GPU_FLAG -cpi prod.cpt"
echo ""
echo "  To monitor progress:"
echo "      tail -f $LOG_DIR/mdrun_prod.log"
echo "      watch -n 30 'grep Performance prod.log | tail -1'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Production MD running in background (PID: $PROD_PID)"
echo "  When complete, run: 04_analysis.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for completion (optional — remove & from mdrun above for foreground)
# wait $PROD_PID
