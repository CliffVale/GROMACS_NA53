#!/bin/bash
# ============================================================
# dssr_inf.sh — OPTIONAL nucleic-acid structural analysis (DSSR/INF)
# GROMACS_NA53
# ============================================================
# APTAMD-style analysis adopted from the APTAMD suite (see
# docs/APTAMD_DEEP_ANALYSIS.md). DSSR annotates base pairs/stacking in a
# 3D nucleic-acid model; INF (Interaction Network Fidelity) then scores how
# much of the seqfold-predicted 2D pairing network survives in 3D.
#
# IMPORTANT — OPTIONAL, NEVER BLOCKING:
#   * x3dna-dssr is NOT in environment.yml: DSSR 2.0 is licensed by Columbia
#     University (free for academic/non-commercial use after registration at
#     https://x3dna.org — NOT a frictionless conda install). Adding it to the
#     env would break the error-free `conda env create`, so it stays optional.
#   * This script exits 0 when DSSR is absent (prints how to enable it) and is
#     NOT part of the 01-04 sbatch chain.
#
# Usage: bash scripts/dssr_inf.sh [model.pdb]
#   default model: structures/NA53_initial.pdb
#   optional pairs: structures/NA53_pairs.txt (1-based "i j" per line, written
#                   by 00_predict_structure.sh from seqfold)
#
# Output: analysis/dssr_inf.txt (+ analysis/dssr_raw.json when DSSR runs)
# ============================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PDB="${1:-../structures/NA53_initial.pdb}"
PAIRS="../structures/NA53_pairs.txt"
OUT_DIR="../analysis"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/dssr_inf.txt"

if [ ! -f "$PDB" ]; then
    echo "❌ model not found: $PDB (stage the real AF3 structure first)"
    exit 1
fi

# ─── Gate: is DSSR installed? Optional — never an error ───
if ! command -v x3dna-dssr > /dev/null 2>&1; then
    echo "ℹ  x3dna-dssr not found — DSSR/INF analysis SKIPPED (optional)."
    echo "   Why optional: DSSR 2.0 is licensed by Columbia University (free for"
    echo "   academics after registration). It is deliberately NOT in environment.yml"
    echo "   so the conda env stays error-free."
    echo "   To enable later: register at https://x3dna.org, install the binary,"
    echo "   then re-run: bash scripts/dssr_inf.sh $PDB"
    exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DSSR / INF ANALYSIS — $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Model: $PDB"

# ─── Run DSSR (JSON) ───
x3dna-dssr -i="$PDB" --json > "$OUT_DIR/dssr_raw.json" 2> "$OUT_DIR/dssr_raw.err" \
    || { echo "❌ DSSR failed on $PDB — see $OUT_DIR/dssr_raw.err"; exit 2; }
echo "  ✓ DSSR annotation complete (pairs, stacking, helical params)"

# ─── INF vs seqfold 2D prediction (stdlib python only) ───
python3 - "$PDB" "$PAIRS" "$OUT" <<'PYEOF'
import json, os, re, sys

pdb, pairs_file, out = sys.argv[1:4]
try:
    data = json.load(open(os.path.join(os.path.dirname(out), "dssr_raw.json")))
except Exception as e:
    print(f"⚠️  could not parse DSSR JSON: {e}")
    sys.exit(0)

def resnum(label):
    m = re.search(r"(\d+)\s*$", str(label))
    return int(m.group(1)) if m else None

# DSSR-reported base pairs (label format "A.DA5" = chain.resname+num)
dssr_pairs = set()
for p in data.get("pairs", []):
    n1, n2 = resnum(p.get("nt1", "")), resnum(p.get("nt2", ""))
    name = str(p.get("name", ""))
    if n1 and n2:
        dssr_pairs.add((min(n1, n2), max(n1, n2)))

# seqfold-predicted pairs (1-based "i j" per line)
pred = set()
if os.path.exists(pairs_file):
    for ln in open(pairs_file):
        ln = ln.split("#")[0].strip()
        if not ln: continue
        try:
            a, b = map(int, ln.split()[:2])
            pred.add((min(a, b), max(a, b)))
        except ValueError:
            continue

lines = [f"DSSR pairs found in model : {len(dssr_pairs)}"]
if pred:
    tp = len(pred & dssr_pairs)
    fp = len(dssr_pairs - pred)
    fn = len(pred - dssr_pairs)
    inf = tp / (tp + fp + fn) if (tp + fp + fn) else 0.0
    lines += [
        f"seqfold 2D pairs predicted: {len(pred)}",
        f"true positives (in both)   : {tp}",
        f"model-only (false pos.)    : {fp}",
        f"predicted-missing (false -): {fn}",
        f"INF (TP/(TP+FP+FN))        : {inf:.3f}",
        "",
        "INF = 1.0 means the 3D model realises every predicted 2D base pair.",
        "Low INF on the STARTING model is normal for flexible ssDNA aptamers —",
        "report it alongside RMSD/Rg as the folding sanity baseline.",
    ]
else:
    lines += ["(no structures/NA53_pairs.txt yet — run 00_predict_structure.sh to compare against seqfold 2D)"]
open(out, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
PYEOF

echo ""
echo "  ✓ Report: $OUT"
