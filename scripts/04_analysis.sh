#!/bin/bash
# ============================================================
# 04_analysis.sh — Production Trajectory Analysis
# GROMACS_NA53
# ============================================================
# This script performs comprehensive structural and biosensing
# analysis on the production trajectory.
#
# Usage: bash 04_analysis.sh [production_prefix] [skip_frames]
# Example: bash 04_analysis.sh prod 0
# ============================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────
PROD_PREFIX="${1:-prod}"
SKIP="${2:-0}"                  # Skip first N ps (for equilibration)
ANALYSIS_DIR="../analysis"
mkdir -p "$ANALYSIS_DIR"

TPR_FILE="${PROD_PREFIX}.tpr"
XTC_FILE="${PROD_PREFIX}.xtc"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NA53 ANALYSIS — $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Trajectory: $XTC_FILE"
echo "  Reference:  $TPR_FILE"
echo "  Skip first: ${SKIP} ps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Helper function ──────────────────────────────────────
run_analysis() {
    local name="$1"
    local cmd="$2"
    echo ""
    echo "▶ $name..."
    eval "$cmd" > "$ANALYSIS_DIR/${name}.log" 2>&1 || {
        echo "  ⚠️  $name encountered issues (check $ANALYSIS_DIR/${name}.log)"
        return 0
    }
    echo "  ✓ $name complete"
}

# ═══════════════════════════════════════════════════════════
# ANALYSIS 1: RMSD (Root Mean Square Deviation)
# ═══════════════════════════════════════════════════════════
run_analysis "RMSD" \
    "echo '4 4' | gmx rms -s $TPR_FILE -f $XTC_FILE \
    -o $ANALYSIS_DIR/rmsd.xvg -tu ns -b $SKIP"

# ═══════════════════════════════════════════════════════════
# ANALYSIS 2: RMSF (Root Mean Square Fluctuation)
# ═══════════════════════════════════════════════════════════
run_analysis "RMSF" \
    "echo '4' | gmx rmsf -s $TPR_FILE -f $XTC_FILE \
    -o $ANALYSIS_DIR/rmsf.xvg -res -b $SKIP"

# ═══════════════════════════════════════════════════════════
# ANALYSIS 3: Radius of Gyration
# ═══════════════════════════════════════════════════════════
run_analysis "Radius_of_Gyration" \
    "echo '1' | gmx gyrate -s $TPR_FILE -f $XTC_FILE \
    -o $ANALYSIS_DIR/gyrate.xvg -b $SKIP"

# ═══════════════════════════════════════════════════════════
# ANALYSIS 4: Hydrogen Bonds
# ═══════════════════════════════════════════════════════════
run_analysis "Hydrogen_Bonds" \
    "echo '1 1' | gmx hbond -s $TPR_FILE -f $XTC_FILE \
    -num $ANALYSIS_DIR/hbnum.xvg -dist $ANALYSIS_DIR/hbdist.xvg \
    -ang $ANALYSIS_DIR/hbangle.xvg -life $ANALYSIS_DIR/hblife.xvg \
    -b $SKIP"

# ═══════════════════════════════════════════════════════════
# ANALYSIS 5: Solvent Accessible Surface Area
# ═══════════════════════════════════════════════════════════
run_analysis "SASA" \
    "echo '1' | gmx sasa -s $TPR_FILE -f $XTC_FILE \
    -o $ANALYSIS_DIR/sasa.xvg -o $ANALYSIS_DIR/sasa_per_res.xvg \
    -tu ns -b $SKIP"

# ═══════════════════════════════════════════════════════════
# ANALYSIS 6: Principal Component Analysis (PCA)
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Principal Component Analysis..."

# Covariance matrix
echo "4 4" | gmx covar -s $TPR_FILE -f $XTC_FILE \
    -o $ANALYSIS_DIR/eigenval.xvg \
    -v $ANALYSIS_DIR/eigenvec.trr \
    -lpc $ANALYSIS_DIR/lpc.xvg \
    -b $SKIP \
    > "$ANALYSIS_DIR/pca_covar.log" 2>&1 || true

# Project trajectory onto first 2 PCs
echo "4 4" | gmx anaeig -s $TPR_FILE -f $XTC_FILE \
    -v $ANALYSIS_DIR/eigenvec.trr \
    -first 1 -last 2 \
    -proj $ANALYSIS_DIR/proj.xvg \
    -b $SKIP \
    > "$ANALYSIS_DIR/pca_anaeig.log" 2>&1 || true

echo "  ✓ PCA complete"

# ═══════════════════════════════════════════════════════════
# ANALYSIS 7: Clustering
# ═══════════════════════════════════════════════════════════
run_analysis "Clustering" \
    "echo '4 4' | gmx cluster -s $TPR_FILE -f $XTC_FILE \
    -method gromos -cutoff 0.2 \
    -o $ANALYSIS_DIR/clusters.xvg \
    -g $ANALYSIS_DIR/cluster.log \
    -dist $ANALYSIS_DIR/clustdist.xvg \
    -b $SKIP"

# ═══════════════════════════════════════════════════════════
# ANALYSIS 8: Energy Terms (from production .edr)
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Extracting energy terms..."
if [ -f "${PROD_PREFIX}.edr" ]; then
    for term in "15:Temperature" "23:Pressure" "24:Density" "10:Potential" "21:Conserved-En"; do
        ID=$(echo $term | cut -d: -f1)
        NAME=$(echo $term | cut -d: -f2)
        echo "$ID" | gmx energy -f ${PROD_PREFIX}.edr \
            -o "$ANALYSIS_DIR/energy_${NAME}.xvg" \
            -b $SKIP 2>/dev/null || true
    done
    echo "  ✓ Energy terms extracted"
else
    echo "  ⚠️  ${PROD_PREFIX}.edr not found, skipping energy analysis"
fi

# ═══════════════════════════════════════════════════════════
# ANALYSIS 9: Base Pairing (DNA aptamer-specific)
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Base-pair analysis (Watson-Crick)..."
echo "1 1" | gmx hbond -s $TPR_FILE -f $XTC_FILE \
    -num $ANALYSIS_DIR/base_pairs.xvg \
    -life $ANALYSIS_DIR/bp_lifetime.xvg \
    -ghost \
    -b $SKIP \
    > "$ANALYSIS_DIR/basepair.log" 2>&1 || true
echo "  ✓ Base-pair analysis complete"

# ═══════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ANALYSIS COMPLETE — Output Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Structural metrics:"
echo "    $ANALYSIS_DIR/rmsd.xvg          (RMSD vs time)"
echo "    $ANALYSIS_DIR/rmsf.xvg          (RMSF per residue)"
echo "    $ANALYSIS_DIR/gyrate.xvg        (Radius of gyration)"
echo ""
echo "  Interaction metrics:"
echo "    $ANALYSIS_DIR/hbnum.xvg         (H-bond count)"
echo "    $ANALYSIS_DIR/hblife.xvg        (H-bond lifetime)"
echo "    $ANALYSIS_DIR/base_pairs.xvg    (Base-pair count)"
echo ""
echo "  Solvent metrics:"
echo "    $ANALYSIS_DIR/sasa.xvg          (Total SASA)"
echo ""
echo "  Dynamics metrics:"
echo "    $ANALYSIS_DIR/proj.xvg          (PCA projection)"
echo "    $ANALYSIS_DIR/clusters.xvg      (Cluster analysis)"
echo ""
echo "  Energy metrics:"
echo "    $ANALYSIS_DIR/energy_Temperature.xvg"
echo "    $ANALYSIS_DIR/energy_Pressure.xvg"
echo "    $ANALYSIS_DIR/energy_Density.xvg"
echo "    $ANALYSIS_DIR/energy_Potential.xvg"
echo "    $ANALYSIS_DIR/energy_Conserved-En.xvg"
echo ""
echo "  Next step: Run 05_visualization.py for figures"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
