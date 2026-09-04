#!/bin/bash
# ============================================================
# health_report.sh — Unified MD-run health report
# GROMACS_NA53
# ============================================================
# One compact report in one vocabulary (✅ PASS / ⚠️ WARN / ❌ FAIL) covering:
#   H1  engine        — profile, host, gmx build (same probe as doctor)
#   H2  repo health   — static integrity result (check_repo_integrity.sh)
#   H3  gmx compat    — live flag probes (probe_gmx_compat.sh)
#   H4  run KPIs      — stage, sim time, throughput (ns/day), log freshness
#                       (parses mdrun .log — see docs/06_KPI_DASHBOARD.md §5)
#
# Used by ./run_simulation.sh status|monitor — locally AND over SSH on the
# cluster, so jobs report health the same way on every machine.
#
# Usage:
#   bash scripts/health_report.sh [--profile NAME] [--quiet-integrity]
#   --profile NAME      profile whose ENV_SETUP puts the right gmx on PATH
#   --quiet-integrity   integrity result as one summary line (status/monitor)
# Exit 0 = healthy; 1 = any FAIL (integrity or probes).
# ============================================================

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

profile="" quiet=0
while [ $# -gt 0 ]; do
    case "$1" in
        --profile)  profile="$2"; shift 2 ;;
        --quiet-integrity) quiet=1; shift ;;
        *) shift ;;
    esac
done

# ── H1: engine ─────────────────────────────────────────────
echo "── health | $(date '+%F %T %Z') | host: $(hostname) ──"
if [ -n "$profile" ] && [ -f "profiles/$profile.env" ]; then
    # shellcheck disable=SC1090
    source "profiles/$profile.env"
    echo "  profile:  $profile ($PROFILE_NAME)"
    ENV_SETUP="${ENV_SETUP:-}" && [ -n "$ENV_SETUP" ] && eval "$ENV_SETUP"
    hash -r 2>/dev/null || true
else
    echo "  profile:  ${profile:-<none — using current PATH>}"
fi
if command -v gmx >/dev/null 2>&1; then
    gmx --version 2>/dev/null | head -1 | sed 's/^/  gmx:      /'
else
    echo "  gmx:      ❌ not found (run with --profile so ENV_SETUP loads it)"
fi

# ── H2: repo integrity ─────────────────────────────────────
echo ""
echo "── H2  repo integrity (static) ──"
if [ "$quiet" = "1" ]; then
    out=$(bash scripts/check_repo_integrity.sh 2>&1)
    rc=$?
    res=$(printf '%s\n' "$out" | tail -1)
    fails=$(printf '%s\n' "$out" | grep -cE '^  ❌' || true)
    if [ "$rc" -eq 0 ]; then echo "  ✅ $res"; else echo "  ❌ $res — $fails failure(s), run the checker for detail"; fi
    integrity_rc=$rc
else
    bash scripts/check_repo_integrity.sh 2>&1
    integrity_rc=$?
fi

# ── H3: live gmx probes ────────────────────────────────────
echo ""
echo "── H3  gmx compat (live probes) ──"
if command -v gmx >/dev/null 2>&1; then
    bash scripts/probe_gmx_compat.sh
    probes_rc=$?
else
    echo "  ⚠️  gmx not on PATH — probes skipped"
    probes_rc=0
fi

# ── H4: run KPIs ───────────────────────────────────────────
echo ""
echo "── H4  run KPIs ──"

# last stage from the launcher status file
if [ -f logs/run_status.txt ]; then
    last=$(tail -n 1 logs/run_status.txt)
    echo "  stage:    ${last}"
else
    echo "  stage:    (no logs/run_status.txt — launcher not run yet)"
fi

# newest mdrun log (stdout capture) + the gmx .log sidecar (deffnm *.log).
# dlog is restricted to the MD-stage names on purpose: "Finished mdrun" and the
# Step/Time + Performance tables live in the deffnm log, and stray .log files
# (e.g. an analysis-era covar.log) must not shadow prod.log.
mlog=$(ls -t logs/mdrun_*.log 2>/dev/null | head -1 || true)
dlog=$(ls -t scripts/em.log scripts/nvt.log scripts/npt1.log scripts/npt2.log scripts/prod.log 2>/dev/null | head -1 || true)

finished=""
if [ -n "$mlog" ] && grep -q "Finished mdrun" "$mlog" 2>/dev/null; then finished=1; fi
if [ -n "$dlog" ] && grep -q "Finished mdrun" "$dlog" 2>/dev/null; then finished=1; fi

# 1) sim time reached — last "Step Time" data row in the gmx .log
sim_ps=""
if [ -n "$dlog" ]; then
    sim_ps=$(awk '
        /^ *Step +Time *$/ { want=1; next }
        want && NF >= 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ { last=$2 }
        END { if (last != "") print last }
    ' "$dlog")
fi

# 2) throughput — measured ns/day if finished, else estimate from run wall age
ns_day=""
if [ -n "$dlog" ]; then
    ns_day=$(awk '/^Performance:/ { print $2; exit }' "$dlog")
fi
if [ -z "$ns_day" ] && [ -n "$dlog" ]; then
    start_epoch=$(stat -c %Y "$dlog" 2>/dev/null || echo "")
    if [ -n "$start_epoch" ] && [ -n "$sim_ps" ] && [ "${sim_ps%.*}" -gt 0 ] 2>/dev/null; then
        wall_days=$(awk -v s="$start_epoch" 'BEGIN { print (systime() - s) / 86400.0 }')
        ns_day=$(awk -v ps="$sim_ps" -v d="$wall_days" 'BEGIN { if (d > 0) printf "%.1f (est.)", ps / 1000.0 / d }')
    fi
fi

# 3) log freshness (stale log on a live run = possible hang)
stale=""
if [ -n "$mlog" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$mlog") ))
    if [ -z "$finished" ] && [ "$age" -gt 600 ]; then
        stale="⚠️  log untouched for ${age}s while run not finished — possible hang"
    fi
fi

echo "  mdrun log: ${mlog:-none}${finished:+  ✅ finished}"
[ -n "$sim_ps" ] && echo "  sim time:  ${sim_ps} ps"
[ -n "$ns_day" ] && echo "  ns/day:    ${ns_day}"
[ -n "$stale" ] && echo "  ${stale}"
[ -z "$mlog" ] && [ -z "$dlog" ] && echo "  (no md logs yet — nothing running)"

echo ""
if [ "${integrity_rc:-0}" -ne 0 ] || [ "${probes_rc:-0}" -ne 0 ]; then
    echo "HEALTH RESULT: FAIL — fix the ❌ above before starting stages (docs/INCIDENT_ANALYSIS.md)"
    exit 1
fi
echo "HEALTH RESULT: ✅ healthy"
exit 0
