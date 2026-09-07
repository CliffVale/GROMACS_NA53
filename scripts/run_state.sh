#!/bin/bash
# ============================================================
# run_state.sh — Run registry + verified-length + archive state
# GROMACS_NA53
# ============================================================
# THE lesson of the 15 ns pilot: a run must never be identified by
# what was REQUESTED (--ns 100 → actually 15 ns). Every run gets a
# RUN_ID row in a registry; the row records requested ns at submit
# time and VERIFIED ns (parsed from prod.log) once production ends.
# Artifacts are archived into archive/<RUN_ID>__<verified>ns/ and a
# new run is refused while un-archived data still sits in scripts/
# (the flat-workspace overwrite bug that forced the manual
# Raw_Result_15ns rescue).
#
# Registry:  $REPO_ROOT/logs/run_registry.tsv   (TSV, one row per run)
# Columns:
#   RUN_ID  PROFILE  MODE  NS_REQ  NS_VER  NS_REACH  JOBS  STATE
#   CREATED  FINISHED  ARCHIVE_DIR
# STATE ∈ submitted | running | finished | archived | died
#
# Usage (source this file, or run directly):
#   bash scripts/run_state.sh new   <profile> <mode: fresh|extend|replica> <ns_requested>
#   bash scripts/run_state.sh update <run_id> STATE=finished [NS_VER=15] [NS_REACH=15.0] [JOBS=...]
#   bash scripts/run_state.sh ns_from_log <prod.log>   → prints "verified_ns reached_ns"
#   bash scripts/run_state.sh current                  → prints last RUN_ID (or nothing)
#   bash scripts/run_state.sh is_archived <run_id>     → exit 0 if archived
#   bash scripts/run_state.sh show                     → pretty print registry
# ============================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$REPO_ROOT/logs/run_registry.tsv"
ARCHIVE_ROOT="$REPO_ROOT/archive"
TS=$(date '+%Y-%m-%d %H:%M:%S %Z')
STEPS_PER_NS=500000            # 2 fs timestep

_reg_dir() { mkdir -p "$REPO_ROOT/logs"; }

# ── ns_from_log <prod.log> — authoritative length from the run itself ──
# Prints "verified_ns reached_ns":
#   verified_ns = nsteps echoed in the mdrun log header ÷ steps/ns
#                (what the .tpr was actually built for — ground truth)
#   reached_ns  = last Step/Time row ÷ 1000 (how far mdrun actually got)
# Empty output (or "0 0") if the log is missing/unfinished.
ns_from_log() {
    local log="$1"
    [ -f "$log" ] || { echo "0 0"; return 1; }
    local nsteps step last
    nsteps=$(awk '/^ *nsteps +?= +[0-9]+/{print $3; exit}' "$log")
    [ -z "$nsteps" ] && nsteps=$(awk '/^ *nsteps/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/){print $i; exit}}' "$log")
    step=$(awk '
        /^ *Step +Time *$/ { want=1; next }
        want && NF >= 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ { last=$2 }
        END { if (last != "") print last }
    ' "$log")
    local vns=0 rns=0
    [ -n "$nsteps" ] && vns=$(awk -v n="$nsteps" 'BEGIN{printf "%.3f", n/500000}')
    [ -n "$step" ]   && rns=$(awk -v s="$step"    'BEGIN{printf "%.3f", s/1000}')
    echo "$vns $rns"
}

# ── new <profile> <mode> <ns_req> — create a run row, print RUN_ID ──
run_state_new() {
    local profile="$1" mode="$2" ns_req="$3"
    _reg_dir
    local day seq=1 rid
    day=$(date +%Y%m%d)
    while :; do
        rid="${day}-r${seq}"
        if ! awk -F'\t' -v id="$rid" '$1 == id {found=1} END{exit !found}' "$REGISTRY" 2>/dev/null; then
            break
        fi
        seq=$((seq + 1))
    done
    printf '%s\t%s\t%s\t%s\t\t\t\t submitted\t%s\t\t\n' \
        "$rid" "$profile" "$mode" "$ns_req" "$TS" >> "$REGISTRY"
    echo "$rid"
}

# ── update <run_id> FIELD=value [FIELD=value ...] ──
# Rewrites the matching row (registry is tiny; append-only is overkill).
run_state_update() {
    local rid="$1"; shift
    [ -f "$REGISTRY" ] || { echo "run_state: no registry yet" >&2; return 1; }
    local f v
    for kv in "$@"; do
        f="${kv%%=*}"; v="${kv#*=}"
        awk -F'\t' -v OFS='\t' -v id="$rid" -v f="$f" -v v="$v" '
            $1 == id {
                if (f == "STATE")   $8  = v
                if (f == "NS_VER")  $5  = v
                if (f == "NS_REACH")$6  = v
                if (f == "JOBS")    $7  = v
                if (f == "FINISHED")$10 = v
                if (f == "ARCHIVE") $11 = v
                found = 1
            }
            { print }
            END { if (!found) exit 1 }
        ' "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
    done
}

# ── current — print the most recent RUN_ID (nothing if empty) ──
run_state_current() {
    [ -f "$REGISTRY" ] || return 0
    tail -n 1 "$REGISTRY" | cut -f1
}

# ── is_archived <run_id> ──
run_state_is_archived() {
    [ -f "$REGISTRY" ] || return 1
    awk -F'\t' -v id="$1" '$1 == id && $8 == "archived" {found=1} END{exit !found}' "$REGISTRY"
}

# ── archive-dir for a run id (even before it exists — pure naming) ──
run_state_archive_dir() { echo "$ARCHIVE_ROOT/$1"; }

# ── show ──
run_state_show() {
    [ -f "$REGISTRY" ] || { echo "(no runs registered yet)"; return 0; }
    printf '%-14s %-12s %-8s %5s %6s %7s %-16s %-10s %s\n' \
        RUN_ID PROFILE MODE NS_REQ NS_VER NS_REACH JOBS STATE CREATED
    awk -F'\t' '{ printf "%-14s %-12s %-8s %5s %6s %7s %-16s %-10s %s\n", $1,$2,$3,$4,$5,$6,$7,$8,$9 }' "$REGISTRY"
}

# ── CLI dispatch ──
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cmd="${1:-show}"
    case "$cmd" in
        new)     run_state_new "${2:?profile}" "${3:?mode}" "${4:?ns}" ;;
        update)  rid="${2:?run_id}"; shift 2; run_state_update "$rid" "$@" ;;
        ns_from_log) ns_from_log "${2:?prod.log}" ;;
        current) run_state_current ;;
        is_archived) run_state_is_archived "${2:?run_id}" ;;
        show)    run_state_show ;;
        *) echo "usage: run_state.sh new|update|ns_from_log|current|is_archived|show" >&2; exit 2 ;;
    esac
fi
