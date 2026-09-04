#!/bin/bash
# ============================================================
# 02_equil.sbatch — Equilibration Job (CPU)
# GROMACS_NA53 — Taiwania 3
# ============================================================
# VERIFIED (2026-09-03): account mst115368, partition ct56,
# GROMACS via conda env na53_aptamer (conda-forge gromacs 2024.4, CPU).
#
# Submit from inside slurm/:
#   cd slurm && sbatch 02_equil.sbatch
# ============================================================

#SBATCH --job-name=na53_equil
#SBATCH --output=../logs/na53_equil_%j.out
#SBATCH --error=../logs/na53_equil_%j.err
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=28
#SBATCH --mem=32G
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

# Find ionized gro file (stage scripts colocate artifacts in scripts/)
IONIZED_GRO=$(ls *_ionized.gro ../system/*_ionized.gro 2>/dev/null | head -1)
if [ -z "$IONIZED_GRO" ]; then
    echo "❌ ERROR: No _ionized.gro found. Run 01_prep.sbatch first."
    exit 1
fi

# CPU-only run: mdrun detects cores from SLURM (28 threads)
bash 02_equilibration.sh "$IONIZED_GRO" ""

echo ""
echo "End: $(date)"
echo "Equilibration complete — submit 03_prod.sbatch next"
