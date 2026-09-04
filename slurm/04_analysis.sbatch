#!/bin/bash
# ============================================================
# 04_analysis.sbatch — Analysis Job (CPU)
# GROMACS_NA53 — Taiwania 3
# ============================================================
# VERIFIED (2026-09-03): account mst115368, partition ct56.
# Analysis is light — 8 cores is plenty (do NOT waste a full node).
#
# Submit from inside slurm/:
#   cd slurm && sbatch 04_analysis.sbatch
# ============================================================

#SBATCH --job-name=na53_analysis
#SBATCH --output=../logs/na53_analysis_%j.out
#SBATCH --error=../logs/na53_analysis_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=ct56
#SBATCH --account=mst115368

# >>> NA53_ENV_SETUP >>>
# Environment Setup — replaced by ./run_simulation.sh submit (profile ENV_SETUP)
module purge
module load gcc/13.2.0 2>/dev/null || module load gcc 2>/dev/null || true

source "${HOME}/miniconda3/etc/profile.d/conda.sh" 2>/dev/null || \
source "${HOME}/anaconda3/etc/profile.d/conda.sh" 2>/dev/null || true
conda activate na53_aptamer 2>/dev/null || true
# <<< NA53_ENV_SETUP <<<

cd "${SLURM_SUBMIT_DIR}/../scripts" || cd scripts

echo "Job ID: $SLURM_JOB_ID"
echo "Node:   $SLURM_NODELIST"
echo "Start:  $(date)"
gmx --version 2>&1 | head -1

# Check trajectory exists (03_prod.sbatch colocates prod.* in scripts/)
if [ ! -f "prod.xtc" ]; then
    echo "❌ ERROR: prod.xtc not found. Run 03_prod.sbatch first."
    exit 1
fi

# Run analysis
bash 04_analysis.sh prod 0

# Generate plots
python3 05_visualization.py ../analysis

echo ""
echo "End: $(date)"
echo "Analysis complete — check ../results/figures/ and ../analysis/"
