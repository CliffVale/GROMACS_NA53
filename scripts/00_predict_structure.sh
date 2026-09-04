#!/bin/bash
# ============================================================
# 00_predict_structure.sh — 3D Structure Prediction Pipeline
# GROMACS_NA53
# ============================================================
# Predicts 3D structure of NA53 DNA aptamer from sequence:
#   1. Secondary structure prediction (seqfold / RNAfold)
#   3. Build 3D coordinates from sequence + secondary structure
#   4. Minimize initial structure
#
# Usage: bash 00_predict_structure.sh [sequence] [temperature]
# Example: bash 00_predict_structure.sh AGCAGCACAGAGGTCAGATGGCGCTGGATAGCAAGATCACGTTATCATCGTAAACCCTATGCGTGCTACCGTGAA 310.15
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Configuration ────────────────────────────────────────
SEQUENCE="${1:-AGCAGCACAGAGGTCAGATGGCGCTGGATAGCAAGATCACGTTATCATCGTAAACCCTATGCGTGCTACCGTGAA}"
TEMPERATURE="${2:-310.15}"
SALT=0.15  # NaCl concentration (M)
STRUCTURES_DIR="../structures"
LOG_DIR="../logs"
mkdir -p "$STRUCTURES_DIR" "$LOG_DIR"

SEQ_LENGTH=${#SEQUENCE}

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  NA53 STRUCTURE PREDICTION — $(date)        ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Sequence: ${SEQUENCE:0:30}...                          "
echo "║  Length:   $SEQ_LENGTH nt (DNA)                         "
echo "║  Temp:    $TEMPERATURE K                                "
echo "║  [NaCl]:  $SALT M                                      "
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ─── Validate sequence ────────────────────────────────────
echo "▶ Validating sequence..."
if [[ ! "$SEQUENCE" =~ ^[ATCGatcg]+$ ]]; then
    echo "❌ ERROR: Invalid DNA sequence. Only A, T, C, G allowed."
    echo "  Got: $SEQUENCE"
    exit 1
fi
SEQUENCE=$(echo "$SEQUENCE" | tr 'atcg' 'ATCG')
echo "  ✓ Sequence validated: $SEQ_LENGTH nt"
echo "  ✓ Sequence: $SEQUENCE"

# Save FASTA
cat > "$STRUCTURES_DIR/NA53.fasta" << EOF
>NA53 DNA aptamer for NGAL biosensing
$SEQUENCE
EOF
echo "  ✓ FASTA saved: $STRUCTURES_DIR/NA53.fasta"

# ═══════════════════════════════════════════════════════════
# STEP 1: SECONDARY STRUCTURE PREDICTION
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Step 1/3: Secondary structure prediction..."

# Method 1: seqfold (free, Python)
PREDICTED_SS=""
python3 << PYEOF
import sys
try:
    from seqfold import fold
    print("  Using seqfold for secondary structure prediction...")

    # Predict secondary structure
    dot_bracket, pairs = fold("$SEQUENCE", temp=$TEMPERATURE)

    print(f"  Predicted structure: {dot_bracket}")
    print(f"  Base pairs: {len(pairs)}")

    # Save dot-bracket notation
    with open("$STRUCTURES_DIR/NA53_secondary.dbn", "w") as f:
        f.write(">NA53 secondary structure (seqfold)\n")
        f.write(f"$SEQUENCE\n")
        f.write(f"{dot_bracket}\n")

    # Save base pairs
    with open("$STRUCTURES_DIR/NA53_pairs.txt", "w") as f:
        for i, j in sorted(pairs):
            f.write(f"{i+1} {j+1}\n")

    # Convert to CT format
    with open("$STRUCTURES_DIR/NA53.ct", "w") as f:
        f.write(f"{len('$SEQUENCE')}  NA53 aptamer\n")
        for idx, nt in enumerate('$SEQUENCE'):
            pair = pairs.get(idx, -1) if isinstance(pairs, dict) else (idx if idx in [p[0] for p in pairs] else -1)
            # Find pairing partner
            partner = -1
            for i, j in pairs:
                if i == idx:
                    partner = j + 1
                    break
                elif j == idx:
                    partner = i + 1
                    break
            f.write(f"{idx+1} {nt} {idx} {idx+2 if idx < len('$SEQUENCE')-1 else 0} {partner} {idx+1}\n")

    print(f"  ✓ Secondary structure saved")
    sys.exit(0)

except ImportError:
    print("  ⚠️  seqfold not available, trying RNAfold...")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then
    # Method 2: RNAfold (ViennaRNA)
    if command -v RNAfold &> /dev/null; then
        echo "  Using RNAfold (ViennaRNA)..."
        echo "$SEQUENCE" | RNAfold --temperature=$TEMPERATURE --salt=$SALT \
            > "$STRUCTURES_DIR/NA53_rnafold.out" 2>&1
        DOT_BRACKET=$(grep -v "^>" "$STRUCTURES_DIR/NA53_rnafold.out" | tail -1 | awk '{print $2}')
        echo "$DOT_BRACKET" > "$STRUCTURES_DIR/NA53_secondary.dbn"
        echo "  ✓ Secondary structure (RNAfold): $DOT_BRACKET"
    else
        # Method 3: Simple hairpin prediction (fallback)
        echo "  ⚠️  No prediction tool available — using simple hairpin model"
        echo "  ℹ  Install seqfold: pip install seqfold"
        echo "  ℹ  Or install ViennaRNA: conda install -c conda-forge viennarna"

        # Generate a simple hairpin-like structure as placeholder
        python3 << PYEOF2
seq = "$SEQUENCE"
n = len(seq)
# Simple all-extended (no pairs) — user must provide real structure
dot = "." * n
with open("$STRUCTURES_DIR/NA53_secondary.dbn", "w") as f:
    f.write(f">NA53 secondary structure (placeholder — no prediction tool)\n")
    f.write(f"{seq}\n")
    f.write(f"{dot}\n")
print(f"  ⚠️  Placeholder: all-unpaired ({dot[:30]}...)")
print(f"  ℹ  Replace with real secondary structure before 3D folding")
PYEOF2
    fi
fi

# ═══════════════════════════════════════════════════════════
# STEP 2: 3D STRUCTURE BUILDING
# ═══════════════════════════════════════════════════════════
# IMPORTANT (verified from real GROMACS behavior):
#   gmx pdb2gmx CANNOT build DNA topology from partial residues. The old
#   fallback here wrote 2 atoms/nt (P + C4') which FAILS pdb2gmx with
#   "Atom X not found in residue" — a guaranteed pipeline error.
#   pdb2gmx needs COMPLETE nucleotides. Therefore NA53_initial.pdb MUST be
#   a real all-atom model. Sources that work for ssDNA:
#     1. AptaFold   (github.com/virtualscreenlab/AptaFold) — DNA+RNA aptamers, free
#     2. w3DNA web  (https://w3dna.rutgers.edu, Build B-form ssDNA) — manual, free
#     3. 3dDNA      (https://zhanggroup.org/3dDNA) — DNA from sequence, free
#   NOTE: RNAComposer is RNA-only — NOT valid for DNA NA53.
#   If you already placed a PDB at structures/NA53_initial.pdb, we use it.
echo ""
echo "▶ Step 2/3: Building 3D coordinates..."

if [ -f "$STRUCTURES_DIR/NA53_initial.pdb" ]; then
    echo "  ✓ Found existing PDB: $STRUCTURES_DIR/NA53_initial.pdb"
    echo "  ℹ  Skipping 3D build (already provided)."
else
    # Try AptaFold (free, aptamer-specific, DNA+RNA) if present
    if [ -d "${HOME}/NA53_tools/AptaFold" ]; then
        echo "  Using AptaFold for 3D structure prediction..."
        APTAFOLD_PDB=$(find "${HOME}/NA53_tools/AptaFold" -name "*.pdb" -newer "$STRUCTURES_DIR/NA53.fasta" 2>/dev/null | head -1)
        if [ -n "$APTAFOLD_PDB" ]; then
            cp "$APTAFOLD_PDB" "$STRUCTURES_DIR/NA53_initial.pdb"
            echo "  ✓ Copied AptaFold model: $STRUCTURES_DIR/NA53_initial.pdb"
        else
            echo "  ⚠️  AptaFold source present but no runnable model found."
        fi
    fi

    if [ ! -f "$STRUCTURES_DIR/NA53_initial.pdb" ]; then
        echo ""
        echo "  ❌ NO VALID STARTING STRUCTURE."
        echo ""
        echo "  gmx pdb2gmx requires a COMPLETE all-atom DNA model — it cannot"
        echo "  build one from sequence, and this script will NOT write a fake"
        echo "  partial PDB (that would fail pdb2gmx later)."
        echo ""
        echo "  Get a real ssDNA model for NA53 (75 nt, DNA — NOT RNA):"
        echo ""
        echo "    Option A (CLI, free):  AptaFold"
        echo "      git clone https://github.com/virtualscreenlab/AptaFold \$HOME/NA53_tools/AptaFold"
        echo "      # then rerun this script — it will pick up the model"
        echo ""
        echo "    Option B (web, free):  w3DNA → Build → B-form single strand"
        echo "      https://w3dna.rutgers.edu"
        echo "      paste: $SEQUENCE"
        echo "      save result as structures/NA53_initial.pdb"
        echo ""
        echo "    Option C (web, free):  3dDNA"
        echo "      https://zhanggroup.org/3dDNA"
        echo ""
        echo "  Then re-run: bash 00_predict_structure.sh"
        exit 1
    fi
fi

# Quick sanity check: a usable DNA PDB must have full nucleotides
python3 - << 'PYEOF_CHECK'
import sys
pdb = "../structures/NA53_initial.pdb"
residues = {}
try:
    with open(pdb) as f:
        for line in f:
            if line.startswith("ATOM"):
                resname = line[17:20].strip()
                resnum = int(line[22:26])
                residues.setdefault(resnum, set()).add(line[12:16].strip())
    bad = [r for r, atoms in residues.items() if len(atoms) < 10]  # full nt has 30+ atoms
    if bad:
        print(f"  ⚠️  Residues with suspiciously few atoms (need full nucleotides): {bad[:5]}...")
        print("  ℹ  pdb2gmx will still fail — verify the PDB is a COMPLETE all-atom model.")
        sys.exit(1)
    total = sum(len(a) for a in residues.values())
    print(f"  ✓ PDB sanity check passed: {len(residues)} residues, {total} atoms")
except FileNotFoundError:
    print("  ❌ NA53_initial.pdb missing")
    sys.exit(1)
PYEOF_CHECK

if [ $? -ne 0 ]; then
    exit 1
fi

# ═══════════════════════════════════════════════════════════
# STEP 3: SUMMARY
# ═══════════════════════════════════════════════════════════
echo ""
echo "▶ Step 3/3: Structure ready"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OUTPUT FILES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  $STRUCTURES_DIR/NA53.fasta"
echo "  $STRUCTURES_DIR/NA53_secondary.dbn"
echo "  $STRUCTURES_DIR/NA53_pairs.txt"
echo "  $STRUCTURES_DIR/NA53_initial.pdb   (COMPLETE all-atom model — required)"
echo ""
echo "  NEXT STEPS:"
echo "  1. Verify secondary structure in VARNA or Nview (optional)"
echo "  2. Run: bash 01_system_prep.sh ../structures/NA53_initial.pdb"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
