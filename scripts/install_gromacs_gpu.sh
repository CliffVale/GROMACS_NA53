#!/bin/bash
# ============================================================
# install_gromacs_gpu.sh — Compile GROMACS from source (GPU or CPU)
# GROMACS_NA53
# ============================================================
# ⚠️ NOT NEEDED ON TAIWANIA 3 (verified 2026-09-03): that cluster has no
#    cuda/cmake/openmpi modules and its GPU partitions are restricted (ngs*)
#    or down (gpu-amd). Use the conda-forge CPU gromacs from environment.yml.
#
# Keep this script for GPU-equipped clusters (or your local GTX 1650 Ti):
#   bash install_gromacs_gpu.sh                # GPU build (CUDA toolkit required)
#   bash install_gromacs_gpu.sh --cpu          # CPU-only source build
#   bash install_gromacs_gpu.sh --build-jobs 16
# ============================================================

set -euo pipefail

BUILD_JOBS=16          # modest default — login node is shared (do NOT use -j56 there)
MODE="gpu"             # gpu | cpu

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu) MODE="cpu"; shift ;;
        --build-jobs) BUILD_JOBS="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

INSTALL_DIR="${HOME}/NA53_tools"
GROMACS_VERSION="2024.4"
BUILD_DIR="$INSTALL_DIR/gromacs_build"
INSTALL_PREFIX="$INSTALL_DIR/gromacs"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  GROMACS BUILD — v$GROMACS_VERSION  [mode: $MODE]        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ─── Load modules (VERIFIED names; never guess CUDA paths) ──
if command -v module &> /dev/null; then
    module purge 2>/dev/null || true
    module load gcc/13.2.0 2>/dev/null || module load gcc 2>/dev/null || true
    module load cmake/3.26.4 2>/dev/null || module load cmake 2>/dev/null || true
    if [ "$MODE" = "gpu" ]; then
        module load cuda/12.0.0 2>/dev/null || module load cuda 2>/dev/null || true
    fi
fi

# ─── Real CUDA root from the module (never hardcode a path) ──
CUDA_ROOT=""
if [ "$MODE" = "gpu" ]; then
    if command -v nvcc &> /dev/null; then
        CUDA_ROOT="$(dirname "$(dirname "$(which nvcc)")")"
        echo "✓ CUDA: $(nvcc --version | tail -1)"
        echo "  CUDA root: $CUDA_ROOT"
    else
        echo "⚠️  nvcc not found — falling back to CPU-only build."
        MODE="cpu"
    fi
fi

# ─── Download GROMACS ─────────────────────────────────────
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ ! -f "gromacs-${GROMACS_VERSION}.tar.gz" ]; then
    echo "Downloading GROMACS ${GROMACS_VERSION}..."
    wget -q "https://ftp.gromacs.org/gromacs/gromacs-${GROMACS_VERSION}.tar.gz" || {
        echo "❌ Download failed — check network or pick a version available on the cluster."
        echo "   Try: wget https://ftp.gromacs.org/gromacs/gromacs-2024.4.tar.gz  (manual)"
        exit 1
    }
fi

echo "Extracting..."
rm -rf "gromacs-${GROMACS_VERSION}" 2>/dev/null || true
tar -xzf "gromacs-${GROMACS_VERSION}.tar.gz"
cd "gromacs-${GROMACS_VERSION}"

# ─── Configure ────────────────────────────────────────────
mkdir -p build
cd build

CMAKE_ARGS=(
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
    -DGMX_BUILD_OWN_FFTW=ON
    -DGMX_MPI=ON
    -DGMX_BUILD_MMPBSA=ON
    -DCMAKE_BUILD_TYPE=Release
    -DGMX_SIMD=AVX_512
)

if [ "$MODE" = "gpu" ]; then
    CMAKE_ARGS+=(-DGMX_GPU=CUDA)
    if [ -n "$CUDA_ROOT" ]; then
        CMAKE_ARGS+=(-DCUDA_TOOLKIT_ROOT_DIR="$CUDA_ROOT")
    fi
    echo "▶ Configuring GROMACS with GPU (CUDA) support..."
else
    CMAKE_ARGS+=(-DGMX_GPU=OFF)
    echo "▶ Configuring GROMACS CPU-only build..."
fi

cmake .. "${CMAKE_ARGS[@]}" 2>&1 | tee ../cmake_log.txt

echo ""
echo "▶ Compiling with $BUILD_JOBS jobs (may take 20–60 min)..."
make -j"$BUILD_JOBS" 2>&1 | tee ../make_log.txt

echo ""
echo "▶ Installing..."
make install 2>&1 | tee ../install_log.txt

# ─── Environment ──────────────────────────────────────────
echo ""
echo "▶ Setting up environment..."

cat > "$HOME/.gromacsrc" << EOF
# GROMACS environment — GROMACS_NA53
export PATH="${INSTALL_PREFIX}/bin:\$PATH"
export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib64:\$LD_LIBRARY_PATH"
export GMXLIB="${INSTALL_PREFIX}/share/gromacs/top"
EOF

echo "  ✓ Environment written to ~/.gromacsrc"
echo "  ℹ  Add to your .bashrc: source ~/.gromacsrc"

# ─── Verify ───────────────────────────────────────────────
source "$HOME/.gromacsrc"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GROMACS BUILD COMPLETE — mode: $MODE"
gmx --version 2>&1 | head -6
echo ""
echo "  MPI:       $([ -f "${INSTALL_PREFIX}/bin/gmx_mpi" ] && echo YES || echo NO)"
echo "  Install:   $INSTALL_PREFIX"
echo ""
echo "  NEXT: source ~/.gromacsrc (or add to .bashrc), then:"
echo "    sinfo -s   # find real partition; fill --partition/--gres/--account in slurm/*.sbatch"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"