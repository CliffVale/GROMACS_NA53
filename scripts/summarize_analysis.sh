#!/usr/bin/env bash
# ============================================================
# summarize_analysis.sh — Compact summary of a GROMACS_NA53
# analysis/ directory (from 04_analysis.sh) for quick review.
#
# Usage:
#   bash summarize_analysis.sh [analysis_dir] [logs_dir]
#   (defaults: analysis/ and logs/, i.e. run from the repo root)
#
# Output: performance (ns/day), per-metric xvg stats
# (mean/min/max/stdev/final), gmx summary tails, PCA + clusters.
# Plain ASCII, no dependencies — runs anywhere bash + awk exist.
# ============================================================
set -uo pipefail

A="${1:-analysis}"
L="${2:-logs}"

echo "── NA53 ANALYSIS SUMMARY ──────────────────────────────────"

# ── 1. Production throughput (definitive, from SLURM capture) ──
perf=$(ls -t "$L"/na53_prod_*.out 2>/dev/null | head -1)
echo ""
echo "── PERFORMANCE (from ${perf:-no na53_prod_*.out found}) ──"
if [ -n "${perf:-}" ]; then
    awk '/^Performance:/ { print "  ns/day " $2 "   (hour/ns " $3 ")"; exit }' "$perf"
    awk '/^Time:/ { print "  core " $2 " s / wall " $3 " s (" $4 "%)"; exit }' "$perf"
    grep -m1 "GROMACS reminds you" "$perf" >/dev/null 2>&1 && echo "  (mdrun completed normally)"
else
    echo "  (not found)"
fi

# ── 2. xvg stats: mean / min / max / stdev / final of last col ──
echo ""
echo "── XVG STATS (mean / min / max / stdev / final) ──"
xvg_stats() { # $1 = file, $2 = label, $3 = unit
    local f="$A/$1"
    [ -f "$f" ] || { echo "  $2      (missing $1)"; return; }
    awk -v label="$2" -v unit="$3" '
        /^[#@]/ { next }
        NF >= 2 {
            v = $NF
            if (v !~ /^[-+0-9.eE]+$/) next
            n++; s += v; s2 += v*v
            if (n == 1 || v < mn) mn = v
            if (n == 1 || v > mx) mx = v
            last = v
        }
        END {
            if (n == 0) { printf "  %-16s  (no data)\n", label; exit }
            m = s / n
            sd = (n > 1) ? sqrt((s2 - s*s/n) / (n - 1)) : 0
            printf "  %-16s  %.4f / %.4f / %.4f / %.4f / %.4f   (%d pts) %s\n",
                   label, m, mn, mx, sd, last, n, unit
        }' "$f"
}
xvg_stats rmsd.xvg        "RMSD"            "nm"
xvg_stats gyrate.xvg      "Rg"              "nm"
xvg_stats sasa.xvg        "SASA"            "nm^2"
xvg_stats hbnum.xvg       "H-bonds (intra)" "#"
xvg_stats base_pairs.xvg  "Base pairs"      "#"
xvg_stats energy_Temperature.xvg "Temp"     "K"
xvg_stats energy_Pressure.xvg     "Press"   "bar"
xvg_stats energy_Density.xvg      "Density" "kg/m^3"
xvg_stats energy_Potential.xvg    "Potential" "kJ/mol"

# RMSF: per-residue — report top-3 most flexible residues
f="$A/rmsf.xvg"
if [ -f "$f" ]; then
    echo ""
    echo "── RMSF (top-3 most flexible residues) ──"
    awk '/^[#@]/ { next }
         NF >= 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ {
             print $2, $1
         }' "$f" | sort -rn | head -3 | \
        awk '{ printf "  residue %5s   RMSF %.4f nm\n", $2, $1 }'
    awk 'BEGIN{printf "  (overall "} /^[#@]/{next}
         NF>=2 && $1~/^[0-9]+$/ && $2~/^[0-9.]+$/{s+=$2;n++}
         END{ if(n>0) printf "mean %.4f nm over %d residues)\n", s/n, n }' "$f"
fi

# ── 3. PCA eigenvalue capture ──
f="$A/eigenval.xvg"
if [ -f "$f" ]; then
    echo ""
    echo "── PCA (top-5 modes, % of total variance) ──"
    awk '/^[#@]/ { next }
         NF >= 2 && $2 ~ /^[0-9.]+$/ { ev[++n] = $2; sum += $2 }
         END {
             for (i = 1; i <= n && i <= 5; i++)
                 printf "  mode %2d  %.3e  (%.1f%%)\n", i, ev[i], 100*ev[i]/sum
             if (n > 0) printf "  total %d modes\n", n
         }' "$f"
fi

# ── 4. gmx tool summary tails (raw) ──
echo ""
echo "── GMX SUMMARY TAILS ──"
for lf in RMSD RMSF Radius_of_Gyration Hydrogen_Bonds SASA Clustering; do
    f="$A/${lf}.log"
    [ -f "$f" ] || continue
    echo "  [$lf.log]"
    tail -4 "$f" | sed 's/^/    /'
done

# ── 5. Cluster occupancy ──
f="$A/cluster.log"
if [ -f "$f" ]; then
    echo ""
    echo "── CLUSTERS (occupancy) ──"
    grep -E "Cluster [0-9]+" "$f" | head -6 | sed 's/^/  /'
fi

echo ""
echo "── END ───────────────────────────────────────────────────"