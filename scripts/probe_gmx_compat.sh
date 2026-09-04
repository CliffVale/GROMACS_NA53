#!/bin/bash
# ============================================================
# probe_gmx_compat.sh — LIVE gmx build probes (shared)
# GROMACS_NA53
# ============================================================
# Probes the gmx on PATH for every CLI flag the pipeline uses, plus the
# analysis group-layout sanity check. Guards bug class V (version drift) and
# G (group-index) from docs/INCIDENT_ANALYSIS.md.
#
# Called by: ./run_simulation.sh doctor and scripts/health_report.sh
# (both run it AFTER the profile's ENV_SETUP put the right gmx on PATH).
#
# Usage: bash scripts/probe_gmx_compat.sh [--gro PATH]
#   --gro PATH  structure to check group layout on (default: newest
#               scripts/*_ionized.gro). Omit to skip group check with a warning.
# Exit 0 = all probes PASS; 1 = any FAIL.
# ============================================================

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1   # repo root

FAILED=0
probe_flag() { # label, gmx -h command, expected token
    # grep -c reads the full stream (no early-exit SIGPIPE under pipefail);
    # gmx prints -h help to STDERR, so 2>&1 is required (see INCIDENT_ANALYSIS.md S2)
    local hits
    hits=$(eval "$2" 2>&1 | grep -cE -- "$3" || true)
    if [ "${hits:-0}" -gt 0 ]; then
        echo "  ✅ $1"
    else
        echo "  ❌ $1 — missing on this build; see docs/INCIDENT_ANALYSIS.md class V"
        FAILED=$((FAILED + 1))
    fi
}

if ! command -v gmx >/dev/null 2>&1; then
    echo "  ❌ gmx not on PATH — source the profile ENV_SETUP first (run_simulation.sh does this)"
    exit 1
fi
gmx --version 2>/dev/null | head -1 | sed 's/^/  ✅ /'

probe_flag "mdrun   -gpu_id (V1)"        "gmx mdrun -h"            "-gpu_id"
probe_flag "hbond   -r selection (V5)"   "gmx hbond -h"            "-r <selection>"
probe_flag "hbond   -t selection (V5)"   "gmx hbond -h"            "-t <selection>"
probe_flag "sasa    -or per-residue (V4)" "gmx sasa -h"            "-or "
probe_flag "cluster -o accepts .xpm (V6)" "gmx cluster -h"         "<.xpm>"

# ── Group-layout sanity (G1) ───────────────────────────────
gro=""
while [ $# -gt 0 ]; do case "$1" in --gro) gro="$2"; shift 2;; *) shift;; esac; done
[ -n "$gro" ] || gro=$(ls -t scripts/*_ionized.gro 2>/dev/null | head -1)
if [ -n "$gro" ] && [ -f "$gro" ]; then
    local_hits=$(printf 'q\n' | gmx make_ndx -f "$gro" -o /dev/null 2>&1 | grep -cE "^ *1 DNA " || true)
    if [ "${local_hits:-0}" -gt 0 ]; then
        echo "  ✅ index group 1 = DNA on $gro (04_analysis.sh targets this)"
    else
        echo "  ❌ index group 1 is NOT 'DNA' on $gro — analysis targets the wrong molecule; fix 04_analysis.sh"
        FAILED=$((FAILED + 1))
    fi
else
    echo "  ⚠️  no *_ionized.gro yet — group-layout check runs after prep (G1)"
fi

echo ""
if [ "$FAILED" -gt 0 ]; then
    echo "PROBE RESULT: $FAILED FAILED"
    exit 1
fi
echo "PROBE RESULT: all PASS"
exit 0
