#!/bin/bash
# ============================================================
# check_repo_integrity.sh — Static repo-integrity checks
# GROMACS_NA53
# ============================================================
# Single source of truth for the STATIC checks that guard against the
# bug classes found in the 2026-09-04 postmortem (see docs/INCIDENT_ANALYSIS.md):
#   C1  referenced runtime files missing from the repo (gitignore swallowed
#       configs/em,nvt,npt,npt_free.mdp on the original commit)
#   C2  entry-point scripts committed non-executable (./run_simulation.sh
#       → Permission denied on a fresh clone)
#   C3  MDP configs drifted from the validated physics standard
#       (cutoff 1.0 vs 0.8 nm, missing shift-Verlet, PME on the charged
#       pre-genion grompp, POSRES_BB macro never defined, missing
#       refcoord_scaling=com, restraints left in production)
#   C4  unresolved CHANGE_ME placeholders in executable pipeline files
#   C5  shell/python syntax breakage
#
# No gmx required — runs on CI and on any host.
# Usage:  bash scripts/check_repo_integrity.sh
# Exit 0 = all PASS; 1 = any FAIL.
# ============================================================

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1   # repo root

FAILED=0
WARNED=0
note()  { printf '  %s %s\n' "$1" "$2"; }
pass()  { note "✅" "$*"; }
warn()  { note "⚠️ " "$*"; WARNED=$((WARNED + 1)); }
fail()  { note "❌" "$*"; FAILED=$((FAILED + 1)); }

section() { echo ""; echo "── $* ──"; }

# ── C5: syntax ─────────────────────────────────────────────
section "Syntax"
for f in run_simulation.sh scripts/*.sh slurm/*.sbatch slurm/*.sh; do
    [ -f "$f" ] || continue
    if bash -n "$f" 2>/dev/null; then pass "bash -n  $f"; else fail "bash -n  $f"; fi
done
if command -v python3 >/dev/null 2>&1; then
    for f in scripts/*.py research/scripts/*.py; do
        [ -f "$f" ] || continue
        if python3 -m py_compile "$f" 2>/dev/null; then pass "py     $f"; else fail "py     $f"; fi
    done
else
    warn "python3 not found — skipping python compile checks"
fi

# ── C1: every runtime-referenced file must exist + not be gitignored ──
section "Runtime file inventory (C1)"
REQUIRED_FILES=(
    configs/em.mdp configs/nvt.mdp configs/npt.mdp configs/npt_free.mdp
    configs/ions.mdp configs/prod.mdp
    scripts/00_predict_structure.sh scripts/01_system_prep.sh
    scripts/02_equilibration.sh scripts/03_production.sh scripts/04_analysis.sh
    scripts/05_visualization.py scripts/run_pipeline.sh
    slurm/01_prep.sbatch slurm/02_equil.sbatch slurm/03_prod.sbatch
    slurm/04_analysis.sbatch slurm/setup_taiwania3.sh
    profiles/README.md profiles/taiwania3_cpu.env profiles/taiwania3_gpu.env
    profiles/taiwania2_twai_gpu.env profiles/local_gpu.env
)
for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        fail "missing: $f"
        continue
    fi
    # The gitignore-swallow bug: a file can exist locally yet never reach a
    # fresh clone. If we're in a git work tree, assert it is NOT ignored.
    if git rev-parse --git-dir >/dev/null 2>&1; then
        if git check-ignore -q "$f"; then
            fail "gitignored (never ships in a clone!): $f"
            continue
        fi
    fi
    pass "present + tracked: $f"
done

# ── C2: entry points must be executable in the git index ──
section "Executable bits in git index (C2)"
if git rev-parse --git-dir >/dev/null 2>&1; then
    for f in run_simulation.sh scripts/*.sh slurm/*.sbatch slurm/setup_taiwania3.sh; do
        [ -f "$f" ] || continue
        mode=$(git ls-files -s "$f" | awk '{print $1}')
        if [ "$mode" = "100755" ]; then
            pass "100755  $f"
        else
            fail "not executable in index ($mode): $f — run: git update-index --chmod=+x $f"
        fi
    done
else
    warn "not a git work tree — exec-bit check skipped (CI runs it)"
fi

# ── C3: MDP consistency with the validated physics standard ──
section "MDP consistency (C3)"
mdp_has() { # mdp_has <file> <grep-pattern> <label>
    if grep -qE "$2" "$1"; then pass "$1: $3"; else fail "$1: $3 MISSING"; fi
}
mdp_lacks() { # mdp_lacks <file> <grep-pattern> <label>
    if grep -qE "$2" "$1"; then fail "$1: $3 present (should NOT be)"; else pass "$1: no $3"; fi
}
# Non-ions stage configs: 0.8 nm + shift-Verlet (validated standard)
for mdp in em nvt npt npt_free prod; do
    mdp_has "configs/$mdp.mdp" '^rcoulomb\s*=\s*0\.8'      "rcoulomb 0.8"
    mdp_has "configs/$mdp.mdp" '^rvdw\s*=\s*0\.8'          "rvdw 0.8"
    mdp_has "configs/$mdp.mdp" 'vdw-modifier\s*=\s*Potential-shift-Verlet' "Potential-shift-Verlet"
done
# ions.mdp: NO PME — genion pre-step runs on the un-neutralized (charged) DNA
mdp_lacks "configs/ions.mdp" 'coulombtype\s*=\s*PME' "PME (ions.mdp must be Cut-off)"
mdp_has  "configs/ions.mdp" 'coulombtype\s*=\s*Cut-off' "Cut-off electrostatics"
# prod.mdp: PME on, restraints OFF
mdp_has  "configs/prod.mdp" 'coulombtype\s*=\s*PME' "PME electrostatics"
mdp_lacks "configs/prod.mdp" '^\s*define\s*=\s*-D?POSRES' "position restraints in production"
# Equilibration restraints: use the POSRES macro pdb2gmx actually provides,
# with refcoord_scaling=com (required for posres + Parrinello-Rahman)
mdp_has "configs/nvt.mdp" 'define\s*=\s*-DPOSRES' "-DPOSRES"
mdp_has "configs/npt.mdp" 'define\s*=\s*-DPOSRES' "-DPOSRES"
mdp_has "configs/npt.mdp" 'refcoord_scaling\s*=\s*com' "refcoord_scaling=com"

# ── C4: placeholders in executable pipeline files ──
section "Placeholders (C4)"
# Exclude this checker itself (its header documents the C4 pattern).
if grep -rn "CHANGE_ME" slurm/ scripts/ \
    --exclude=check_repo_integrity.sh 2>/dev/null; then
    fail "unresolved CHANGE_ME in slurm/ or scripts/"
else
    pass "no CHANGE_ME in slurm/ or scripts/"
fi

# ── Phase-5 gate: input PDB (informational — ships empty by design) ──
section "Input structure (Phase 5)"
if [ -f structures/NA53_initial.pdb ]; then
    pass "structures/NA53_initial.pdb present"
else
    warn "structures/NA53_initial.pdb absent — expected until Phase 5 (real NA53 model)"
fi

echo ""
if [ "$FAILED" -gt 0 ]; then
    echo "RESULT: $FAILED FAILED, $WARNED warnings"
    exit 1
fi
echo "RESULT: all PASS ($WARNED warnings)"
exit 0
