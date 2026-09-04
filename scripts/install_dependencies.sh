#!/bin/bash
# ============================================================
# install_dependencies.sh — Install All Dependencies
# GROMACS_NA53
# ============================================================
# Run this once on Taiwania 3 to set up the environment.
#
# Usage: bash install_dependencies.sh
# ============================================================

set -euo pipefail

INSTALL_DIR="${HOME}/NA53_tools"
CONDA_ENV="na53_aptamer"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  NA53 DEPENDENCY INSTALLER — $(date)        ║"
echo "║  Installing to: $INSTALL_DIR                           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ─── Step 1: Check system environment ─────────────────────
echo "▶ Step 1: Checking system environment..."

# Check for module system
if command -v module &> /dev/null; then
    echo "  ✓ Module system available"
    echo "  ℹ  Loading GCC module..."

    # VERIFIED Taiwania 3 (2026-09-03): ONLY gcc modules exist (no cuda/cmake/openmpi)
    module purge 2>/dev/null || true
    module load gcc/13.2.0 2>/dev/null || module load gcc 2>/dev/null || true

    echo "  ✓ Modules loaded"
else
    echo "  ⚠️  No module system found — assuming dependencies are in PATH"
fi

# Check compilers
if command -v gcc &> /dev/null; then
    echo "  ✓ GCC: $(gcc --version | head -1)"
else
    echo "  ❌ GCC not found — install with: sudo apt install build-essential"
    exit 1
fi

# Check CUDA
if command -v nvcc &> /dev/null; then
    echo "  ✓ CUDA: $(nvcc --version | tail -1)"
    HAS_CUDA=1
else
    echo "  ⚠️  CUDA not found — GROMACS will be built without GPU support"
    HAS_CUDA=0
fi

# ─── Step 2: Install Miniconda (if not present) ──────────
echo ""
echo "▶ Step 2: Setting up Miniconda..."

if [ -d "$HOME/miniconda3" ] || [ -d "$HOME/anaconda3" ]; then
    echo "  ✓ Conda already installed"
    eval "$($HOME/miniconda3/bin/conda shell.bash hook 2>/dev/null || $HOME/anaconda3/bin/conda shell.bash hook 2>/dev/null)"
else
    echo "  Installing Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$HOME/miniconda3"
    eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
    echo "  ✓ Miniconda installed"
fi

# ─── Step 3: Create conda environment ─────────────────────
echo ""
echo "▶ Step 3: Creating conda environment ($CONDA_ENV)..."

if conda env list | grep -q "^${CONDA_ENV} "; then
    echo "  ✓ Environment '$CONDA_ENV' already exists"
    set +u
    conda activate "$CONDA_ENV"
    set -u
else
    conda create -n "$CONDA_ENV" python=3.10 -y
    set +u
    conda activate "$CONDA_ENV"
    set -u
    echo "  ✓ Environment created"
fi

# ─── Step 4: GROMACS engine (conda CPU build) ────────────
# VERIFIED on Taiwania 3: no cuda/cmake/openmpi/fftw modules, GPU partitions
# restricted (ngs*) or down (gpu-amd) → conda-forge gromacs 2024.4 (prebuilt
# CPU, AVX2 + thread-MPI) is the engine. No source compile on this cluster.
echo ""
echo "▶ Step 4: Installing GROMACS engine (conda-forge, CPU)..."

if command -v gmx &> /dev/null; then
    echo "  ✓ GROMACS already present: $(gmx --version 2>&1 | head -1)"
else
    conda install -c conda-forge gromacs=2024.4 -y 2>&1 | tail -3
    echo "  ✓ GROMACS installed from conda-forge"
fi
# (install_gromacs_gpu.sh exists for GPU-equipped clusters — NOT needed here.)

# ─── Step 5: Install AmberTools ───────────────────────────
echo ""
echo "▶ Step 5: Installing AmberTools..."

if command -v ante &> /dev/null || command -v pdb4amber &> /dev/null; then
    echo "  ✓ AmberTools already installed"
else
    conda install -c conda-forge ambertools=23 -y
    echo "  ✓ AmberTools installed"
fi

# ─── Step 6: Install Python dependencies ──────────────────
echo ""
echo "▶ Step 6: Installing Python dependencies..."

pip install --upgrade pip
pip install \
    numpy \
    scipy \
    matplotlib \
    seaborn \
    pandas \
    biopython \
    mdanalysis \
    natsort \
    tqdm

# Aptamer-specific tools
pip install \
    seqfold \
    nupack 2>/dev/null || echo "  ⚠️  NUPACK requires license — using seqfold as alternative"

echo "  ✓ Python dependencies installed"

# ─── Step 7: Install structure prediction tools ───────────
echo ""
echo "▶ Step 7: Installing aptamer structure prediction tools..."

# AptaFold (free, from GitHub)
if [ ! -d "$INSTALL_DIR/AptaFold" ]; then
    echo "  Cloning AptaFold..."
    git clone https://github.com/virtualscreenlab/AptaFold.git "$INSTALL_DIR/AptaFold" 2>/dev/null || \
        echo "  ⚠️  Could not clone AptaFold — manual install required"
fi

# ViennaRNA (for RNAfold — free secondary structure prediction)
if ! command -v RNAfold &> /dev/null; then
    conda install -c conda-forge viennarna -y 2>/dev/null || \
        echo "  ⚠️  ViennaRNA not available via conda — install manually"
fi

echo "  ✓ Structure prediction tools installed"

# ─── Step 8: Verify installation ─────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  INSTALLATION VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "  Checking GROMACS..."
gmx --version 2>&1 | head -3 || echo "  ❌ GROMACS not found"

echo ""
echo "  Checking AmberTools..."
pdb4amber --version 2>&1 | head -1 || echo "  ⚠️  pdb4amber not found (amber14sb may be needed)"

echo ""
echo "  Checking Python packages..."
python3 -c "
import numpy; print(f'  ✓ numpy {numpy.__version__}')
import matplotlib; print(f'  ✓ matplotlib {matplotlib.__version__}')
import MDAnalysis; print(f'  ✓ MDAnalysis {MDAnalysis.__version__}')
import Bio; print(f'  ✓ BioPython {Bio.__version__}')
" 2>/dev/null || echo "  ⚠️  Some Python packages missing"

echo ""
echo "  Checking seqfold..."
python3 -c "import seqfold; print('  ✓ seqfold available')" 2>/dev/null || echo "  ⚠️  seqfold not installed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  INSTALLATION COMPLETE"
echo ""
echo "  To activate the environment:"
echo "    conda activate $CONDA_ENV"
echo ""
echo "  Next step: Run the pipeline"
echo "    cd scripts/"
echo "    bash run_pipeline.sh ../structures/NA53_input.pdb"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
