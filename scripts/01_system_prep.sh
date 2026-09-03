#!/bin/bash
# ============================================================
# 01_system_prep.sh — System Preparation for Aptamer MD
# GROMACS_NA53
# ============================================================
# This script performs:
#   1. Force field topology generation (pdb2gmx)
#   2. Box definition (editconf)
#   3. Solvation (solvate)
#   4. Ionization & neutralization (genion)
#
# Usage: bash 01_system_prep.sh <input.pdb> <force_field> <water_model>
# Example: bash 01_system_prep.sh structures/clean.pdb amber99sb-ildn tip3p
# ============================================================

set -euo pipefail

# ─── Configuration ────────────────────────────────────────
INPUT_PDB="${1:?Usage: $0 <input.pdb> <force_field> <water_model>}"
FF="${2:-amber99sb-ildn}"
WATER="${3:-tip3p}"
BOX_PADDING=1.2          # nm, minimum distance from solute to box edge
BOX_TYPE="dodecahedron"  # Most efficient for solvation
ION_CONC=0.15            # M, NaCl concentration
CONFIG_DIR="../configs"
LOG_DIR="../logs"
mkdir -p "$LOG_DIR"

# ─── Derived names ────────────────────────────────────────
BASENAME=$(basename "$INPUT_PDB" .pdb)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NA53 SYSTEM PREP — $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Input:    $INPUT_PDB"
echo "  Force Field: $FF"
echo "  Water:    $WATER"
echo "  Box:      $BOX_TYPE ($BOX_PADDING nm padding)"
echo "  [NaCl]:   $ION_CONC M"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Step 1: Topology Generation ─────────────────────────
echo ""
echo "▶ Step 1/4: Generating topology with pdb2gmx..."
gmx pdb2gmx -f "$INPUT_PDB" -o "${BASENAME}_processed.gro" \
    -p topol.top -ff "$FF" -water "$WATER" -ignh \
    > "$LOG_DIR/pdb2gmx.log" 2>&1

# Check for successful topology
if [ ! -f "topol.top" ]; then
    echo "❌ ERROR: topol.top not generated. Check PDB naming and force field."
    echo "  DNA residues: DA, DT, DG, DC"
    echo "  RNA residues: A, U, G, C"
    exit 1
fi
echo "  ✓ Topology generated: topol.top"
echo "  ✓ Processed structure: ${BASENAME}_processed.gro"

# Verify charge
CHARGE=$(grep -c "^   residues_ions" topol.top || echo "0")
echo "  ℹ  Check topol.top for charge information"

# ─── Step 2: Box Definition ──────────────────────────────
echo ""
echo "▶ Step 2/4: Defining simulation box..."
gmx editconf -f "${BASENAME}_processed.gro" -o "${BASENAME}_boxed.gro" \
    -c -d "$BOX_PADDING" -bt "$BOX_TYPE" \
    > "$LOG_DIR/editconf.log" 2>&1

echo "  ✓ Box defined: $BOX_TYPE (${BOX_PADDING} nm padding)"

# Show box dimensions
echo "  Box vectors:"
tail -3 "${BASENAME}_boxed.gro"

# ─── Step 3: Solvation ───────────────────────────────────
echo ""
echo "▶ Step 3/4: Solvating system with $WATER water..."
gmx solvate -cp "${BASENAME}_boxed.gro" -cs spc216.gro \
    -o "${BASENAME}_solvated.gro" -p topol.top \
    > "$LOG_DIR/solvate.log" 2>&1

# Count water molecules
NWAT=$(grep -c "SOL" "${BASENAME}_solvated.gro" || echo "?")
echo "  ✓ Solvation complete"
echo "  ℹ  Water molecules added: ~$NWAT"

# ─── Step 4: Ionization ──────────────────────────────────
echo ""
echo "▶ Step 4/4: Adding ions ($ION_CONC M NaCl)..."

# Add ions.itp include to topol.top if not present
if ! grep -q "ions.itp" topol.top; then
    # Insert ions.itp include before the system non-bonded params
    sed -i '/#include.*forcefield\.itp/a #include "ions.itp"' topol.top
    echo "  ✓ Added #include \"ions.itp\" to topol.top"
fi

# Generate .tpr for genion
gmx grompp -f "$CONFIG_DIR/ions.mdp" \
    -c "${BASENAME}_solvated.gro" -p topol.top \
    -o "${BASENAME}_ions.tpr" \
    > "$LOG_DIR/grompp_ions.log" 2>&1

# Replace water with ions (neutral + 0.15 M)
echo "SOL" | gmx genion -s "${BASENAME}_ions.tpr" \
    -o "${BASENAME}_ionized.gro" -p topol.top \
    -pname NA -nname CL -neutral -conc "$ION_CONC" \
    > "$LOG_DIR/genion.log" 2>&1

echo "  ✓ Ions added: Na⁺/Cl⁻ (neutral, $ION_CONC M)"

# ─── Verification ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SYSTEM PREP COMPLETE — Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# File check
for f in "${BASENAME}_ionized.gro" topol.top; do
    if [ -f "$f" ]; then
        echo "  ✓ $f"
    else
        echo "  ❌ $f MISSING"
    fi
done

# Atom count
NATOMS=$(head -1 "${BASENAME}_ionized.gro")
echo "  ℹ  Total atoms: $NATOMS"

echo ""
echo "  Output files:"
echo "    ${BASENAME}_ionized.gro  (solvated + ionized structure)"
echo "    topol.top                (molecular topology)"
echo ""
echo "  Next step: Run 02_equilibration.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
