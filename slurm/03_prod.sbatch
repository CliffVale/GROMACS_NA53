#!/bin/bash
# ============================================================
# 03_prod.sbatch — Production MD Job (CPU, 56 cores)
# GROMACS_NA53 — Taiwania 3
# ============================================================
# VERIFIED (2026-09-03): account mst115368, partition ct56
# (56 cores, 754 GB RAM, 4-day max). GROMACS = conda env na53_aptamer.
#
# Expected throughput (conda CPU gromacs 2024.4, ~35-45k atoms):
#   ~40-70 ns/day → 100 ns fits comfortably in the 4-day limit.
#
# Restart from checkpoint after a walltime stop:
#   cd slurm && RESTART=1 sbatch 03_prod.sbatch
#
# Submit from inside slurm/:
#   cd slurm && sbatch 03_prod.sbatch [ns]
# ============================================================

#SBATCH --job-name=na53_prod
#SBATCH --output=../logs/na53_prod_%j.out
#SBATCH --error=../logs/na53_prod_%j.err
#SBATCH --time=95:00:00          # ~4 days (ct56 limit) — adjust for 100 ns run
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=56       # full node
#SBATCH --mem=32G                # node has 754 GB — this is plenty
#SBATCH --partition=ct56
#SBATCH --account=mst115368

# ─── Environment Setup ────────────────────────────────────
module purge
module load gcc/13.2.0 2>/dev/null || module load gcc 2>/dev/null || true

source "${HOME}/miniconda3/etc/profile.d/conda.sh" 2>/dev/null || \
source "${HOME}/anaconda3/etc/profile.d/conda.sh" 2>/dev/null || true
conda activate na53_aptamer 2>/dev/null || true

cd "${SLURM_SUBMIT_DIR}/../scripts" || cd scripts

echo "Job ID: $SLURM_JOB_ID"
echo "Node:   $SLURM_NODELIST"
echo "Start:  $(date)"
gmx --version 2>&1 | head -1

# Restart path (RESTART=1): continue from saved checkpoint
if [ -f "../production/prod.cpt" ] && [ "${RESTART:-0}" = "1" ]; then
    echo "▶ Restarting from checkpoint..."
    cd ../production
    gmx mdrun -deffnm prod -cpi prod.cpt -ntomp 56
    echo "Production restarted from checkpoint"
    exit 0
fi

# Fresh run: require equilibration output
if [ ! -f "npt2.gro" ]; then
    echo "❌ ERROR: npt2.gro not found. Run 02_equil.sbatch first."
    exit 1
fi

# Length requested (ns), default 100
NS_LENGTH="${1:-100}"
NSTEPS=$((NS_LENGTH * 500000))   # 2 fs timestep

echo "▶ Starting production MD ($NS_LENGTH ns = $NSTEPS steps, CPU 56 threads)..."

# Prepare MDP with the requested length
cp ../configs/prod.mdp prod_mdp_temp.mdp
sed -i "s/nsteps.*/nsteps          = $NSTEPS/" prod_mdp_temp.mdp

# Generate TPR
gmx grompp -f prod_mdp_temp.mdp -c npt2.gro \
    -p topol.top -o ../production/prod.tpr
rm -f prod_mdp_temp.mdp

# Run — checkpoint every 15 min so a walltime kill costs nothing
cd ../production
gmx mdrun -deffnm prod -ntomp 56 -cpo prod -cpt 900

echo ""
echo "End: $(date)"
echo "Production complete — submit 04_analysis.sbatch next"
