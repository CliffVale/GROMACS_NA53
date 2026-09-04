#!/bin/bash
# ============================================================
# 01_prep.sbatch — System Preparation Job (CPU)
# GROMACS_NA53 — Taiwania 3
# ============================================================
# VERIFIED (2026-09-03, live session): account mst115368,
# partition ct56 (56 cores, 754 GB/node), GROMACS via conda env na53_aptamer.
#
# Submit from inside slurm/:
#   cd slurm && sbatch 01_prep.sbatch
# ============================================================

#SBATCH --job-name=na53_prep
#SBATCH --output=../logs/na53_prep_%j.out
#SBATCH --error=../logs/na53_prep_%j.err
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --partition=ct56
#SBATCH --account=mst115368
# (No GPU: ngs* GPU partitions are restricted, gpu-amd is down — CPU path)

# >>> NA53_ENV_SETUP >>>
# Environment Setup — this block is REPLACED by ./run_simulation.sh submit with
# the active profile's ENV_SETUP. Direct sbatch runs use the defaults below.
module purge
module load gcc/13.2.0 2>/dev/null || module load gcc 2>/dev/null || true

# Conda env provides gmx (conda-forge gromacs 2024.4)
source "${HOME}/miniconda3/etc/profile.d/conda.sh" 2>/dev/null || \
source "${HOME}/anaconda3/etc/profile.d/conda.sh" 2>/dev/null || true
conda activate na53_aptamer 2>/dev/null || true
# <<< NA53_ENV_SETUP <<<

cd "${SLURM_SUBMIT_DIR}/../scripts" || cd scripts

echo "Job ID: $SLURM_JOB_ID"
echo "Node:   $SLURM_NODELIST"
echo "Start:  $(date)"
gmx --version 2>&1 | head -1

# Step 0: Predict structure (if PDB doesn't exist)
if [ ! -f "../structures/NA53_initial.pdb" ]; then
    echo "▶ Predicting 3D structure..."
    bash 00_predict_structure.sh || {
        echo "❌ No valid 3D model. Get one from AptaFold/w3DNA (see script output),"
        echo "   place at structures/NA53_initial.pdb, then re-submit."
        exit 1
    }
fi

# Step 1: System preparation
echo "▶ Running system preparation..."
bash 01_system_prep.sh ../structures/NA53_initial.pdb amber99sb-ildn tip3p

echo ""
echo "End: $(date)"
echo "System preparation complete — submit 02_equil.sbatch next"
