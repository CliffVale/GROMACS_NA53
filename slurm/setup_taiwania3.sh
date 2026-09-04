#!/bin/bash
# ============================================================
# setup_taiwania3.sh — Setup NA53 Pipeline on Taiwania 3
# ============================================================
# Run this once after cloning the repo on Taiwania 3.
#
# VERIFIED ENVIRONMENT (live sessions 2026-08-31 & 2026-09-03):
#   SSH:      ssh u5662994@twnia3.nchc.org.tw  (2FA required, method 1 = app OTP)
#   Account:  mst115368
#   Partitions: ct56 (56 cores/754 GB/4 days) ← MD jobs; ct224/ct560/ct2k/ct8k larger
#   Modules:  gcc/13.2.0 only — NO cuda/cmake/openmpi/fftw modules
#   GPUs:     ngs* (Tesla) restricted to genomics service; gpu-amd (A100) DOWN
#   Engine:   conda-forge gromacs 2024.4 (CPU, AVX2, thread-MPI) — NO compile needed
#
# Usage: bash setup_taiwania3.sh [github_repo_url]
# Example: bash setup_taiwania3.sh https://github.com/CliffVale/GROMACS_NA53.git
# ============================================================

set -euo pipefail

REPO_URL="${1:-https://github.com/YOUR_USERNAME/GROMACS_NA53.git}"
CONDA_ENV="na53_aptamer"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  NA53 TAIWANIA 3 SETUP — $(date)              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ─── Step 1: Locate/clone repository ─────────────────────
# INCIDENT 2026-09-04: this script used to clone unconditionally when a
# GROMACS_NA53/ subdir was absent — running it FROM INSIDE a clone nested a
# second repo (GROMACS_NA53/GROMACS_NA53). Guard: if we are already inside
# the repo (environment.yml + .git), never clone.
echo "▶ Step 1/4: Locating repository..."
if [ -f environment.yml ] && [ -d .git ]; then
    echo "  ✓ Already inside the repo: $(pwd)"
elif [ -d GROMACS_NA53 ] && [ -f GROMACS_NA53/environment.yml ]; then
    echo "  ✓ Repository already cloned"
    cd GROMACS_NA53
else
    git clone "$REPO_URL" GROMACS_NA53
    cd GROMACS_NA53
fi
echo "  ✓ Working directory: $(pwd)"

# ─── Step 2: Load modules (only gcc exists here) ──────────
echo ""
echo "▶ Step 2/4: Loading modules..."
if command -v module &> /dev/null; then
    module purge 2>/dev/null || true
    module load gcc/13.2.0 2>/dev/null || module load gcc 2>/dev/null || true
    echo "  ✓ Loaded: $(module list 2>&1 | tail -1)"
fi

# ─── Step 3: Conda environment (contains the GROMACS engine) ──
echo ""
echo "▶ Step 3/4: Setting up conda environment '$CONDA_ENV'..."
echo "  ℹ  environment.yml ships conda-forge gromacs 2024.4 (CPU) — no source compile."

if command -v conda &> /dev/null; then
    eval "$(conda shell.bash hook)"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
else
    echo "  Installing Miniconda (user-space)..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3"
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi

# Refresh env from environment.yml (adds gromacs if missing)
if conda env list | grep -q "^${CONDA_ENV} "; then
    echo "  ✓ Environment exists — updating with environment.yml..."
    conda env update -f environment.yml 2>&1 | tail -3 || true
else
    echo "  Creating environment from environment.yml (may take 5-15 min)..."
    conda env create -f environment.yml 2>&1 | tail -5
fi
conda activate "$CONDA_ENV"

# ─── Step 4: Validate + prepare directories ───────────────
echo ""
echo "▶ Step 4/4: Validating + creating directories..."
mkdir -p structures system equilibration production analysis results/figures logs
chmod +x scripts/*.sh slurm/*.sbatch 2>/dev/null || true

echo "  ✓ GROMACS: $(gmx --version 2>&1 | head -1)"
echo "  ✓ Directories created"

# ─── Done ─────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SETUP COMPLETE — VERIFIED CLUSTER VALUES"
echo ""
echo "  Environment: conda activate $CONDA_ENV"
echo "  Account:     mst115368   (already filled in slurm/*.sbatch)"
echo "  Partition:   ct56        (already filled — MD jobs, 4-day limit)"
echo ""
echo "  Smoke test (validates SLURM access, ~2 min):"
echo "    cd slurm"
echo "    sbatch --test-only 01_prep.sbatch          # dry run, no execution"
echo ""
echo "  Run the pipeline:"
echo "    cd slurm"
echo "    sbatch 01_prep.sbatch   # → 02_equil.sbatch → 03_prod.sbatch [ns] → 04_analysis.sbatch"
echo ""
echo "  Watch jobs:  squeue -u u5662994     Cancel: scancel <jobid>"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
