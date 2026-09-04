#!/bin/bash
# ============================================================
# live_dashboard.sh — real-time NA53 simulation dashboard
# GROMACS_NA53
# ============================================================
# Polls every N seconds and re-renders one compact screen:
#   · SLURM job state  (na53_prep/equ/prod/ana — state, elapsed, limit)
#   · current MD stage (EM / NVT / NPT1 / NPT2 / prod) + progress bar
#   · live physics     (Temp, Pres from the gmx .log energy table)
#   · throughput       (measured ns/day + steps/s, rolling)
#   · ETAs             (current stage done · prod target done)
#   · status verdict   (✅ healthy / ⏳ queued / ⚠️ stale / ❌ failed)
#
# The gmx .log sidecars (scripts/{em,nvt,npt1,npt2,prod}.log) are the live
# source: mdrun writes a Step/Time/Temp/Pres table every nstlog steps plus
# "step N, will finish <date>" lines carrying mdrun's own ETA.
#
# Usage:
#   bash scripts/live_dashboard.sh [--every SEC] [--target-ns N] [--once]
#                                   [--profile NAME] [--no-color] [--no-clear]
#   --every SEC     poll interval (default 30, min 5)
#   --target-ns N   production target for the long ETA (default 100)
#   --once          single render, no loop (script-friendly)
#   --profile NAME  just cosmetic (shown in the header)
# ============================================================

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

EVERY=30 TARGET_NS=100 ONCE=0 PROFILE="" 
NO_COLOR=0 NO_CLEAR=0
while [ $# -gt 0 ]; do
    case "$1" in
        --every)     EVERY="${2:-30}"; shift 2 ;;
        --target-ns) TARGET_NS="${2:-100}"; shift 2 ;;
        --once)      ONCE=1; shift ;;
        --profile)   PROFILE="$2"; shift 2 ;;
        --no-color)  NO_COLOR=1; shift ;;
        --no-clear)  NO_CLEAR=1; shift ;;
        *) shift ;;
    esac
done
[ "$EVERY" -lt 5 ] && EVERY=5

# colors only on a real terminal (never in pipes/logs)
TTY=0; [ -t 1 ] && TTY=1
if [ "$TTY" = "1" ] && [ "$NO_COLOR" = "0" ]; then
    C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_C=$'\033[36m'
    C_B=$'\033[1m';  C_0=$'\033[0m'
else
    C_G=""; C_Y=""; C_R=""; C_C=""; C_B=""; C_0=""
fi

STAGES="em nvt npt1 npt2 prod"
declare -A STAGE_LABEL=( [em]="EM (energy minimization)" [nvt]="NVT (100 ps, V-rescale)"
                          [npt1]="NPT1 (100 ps, restrained)" [npt2]="NPT2 (500 ps, free)"
                          [prod]="PRODUCTION (NPT)" )

fmt_dur() { # seconds -> "3d 4h 12m" | "12m 34s" | "34s"
    local s=$1 d h m
    if [ "$s" -lt 60 ]; then echo "${s}s"; return; fi
    d=$(( s / 86400 )); s=$(( s % 86400 ))
    h=$(( s / 3600 ));  s=$(( s % 3600 ))
    m=$(( s / 60 ));    s=$(( s % 60 ))
    if [ "$d" -gt 0 ]; then echo "${d}d ${h}h ${m}m"; 
    elif [ "$h" -gt 0 ]; then echo "${h}h ${m}m";
    else echo "${m}m ${s}s"; fi
}

# ─── data gatherers ─────────────────────────────────────────

squeue_rows() { # our job rows: "JOBID PARTITION NAME STATE ELAPSED LIMIT NODELIST"
    command -v squeue >/dev/null 2>&1 || return 0
    squeue -h -u "$USER" -o "%i %P %j %T %M %L %R" 2>/dev/null \
        | awk '$3 ~ /^na53_/ { print }'
}

active_log() { # newest scripts/<stage>.log NOT finished; prints stage + path
    local best="" best_t=0 s f t
    for s in $STAGES; do
        f="scripts/$s.log"
        [ -f "$f" ] || continue
        grep -q "Finished mdrun" "$f" && continue
        t=$(stat -c %Y "$f" 2>/dev/null || echo 0)
        if [ "$t" -gt "$best_t" ]; then best="$s"; best_t="$t"; fi
    done
    [ -n "$best" ] && echo "$best scripts/$best.log"
}

parse_log() { # $1=stage $2=log → sets: total_steps total_ps cur_step cur_ps temp pres fin_eta fin_step
    local s="$1" log="$2" line
    total_steps=""; total_ps=""; cur_step=""; cur_ps=""; temp=""; pres=""; fin_eta=""; fin_step=""
    # total: last "N steps, X ps." after a starting mdrun (prod RESTART appends)
    line=$(grep -E "^[0-9]+ steps, +[0-9.]+ ps\.$" "$log" | tail -1)
    if [ -n "$line" ]; then
        total_steps=$(echo "$line" | awk '{print $1}')
        total_ps=$(echo "$line" | awk '{print $3}')
    fi
    # mdrun's own ETA: "step N, will finish <date>" (strip the comma in $2)
    line=$(grep -E "^step [0-9]+, will finish" "$log" | tail -1)
    if [ -n "$line" ]; then
        fin_step=$(echo "$line" | awk '{print $2}' | tr -d ',')
        fin_eta=$(echo "$line" | sed -E 's/^step [0-9]+, will finish //')
    fi
    # step/time — same tolerant extraction health_report.sh H4 uses (proven on
    # T3 2024.4): any "Step Time" header, last numeric row wins. Split from the
    # Temp/Pres pass so a row layout quirk in one column never hides progress.
    read -r cur_step cur_ps <<< "$(awk '
        /^ *Step +Time/ { want=1; next }
        want && NF >= 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ { st=$1; t=$2 }
        END { if (st != "") print st, t }
    ' "$log")"
    # temp/pres — best-effort, cols 4/5 of the same table when present
    read -r temp pres <<< "$(awk '
        /^ *Step +Time/ { want=1; next }
        want && NF >= 5 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ \
             && $4 ~ /^[-0-9.]+$/ && $5 ~ /^[-0-9.]+$/ { tp=$4; pr=$5 }
        END { if (tp != "") print tp, pr }
    ' "$log")"
}

# ─── one render ─────────────────────────────────────────────
render() {
    local now epoch_now rows running="" pending="" failed="" jid job elapsed lim node
    local stage="" log="" total_steps="" total_ps="" cur_step="" cur_ps="" temp="" pres="" fin_eta="" fin_step=""
    local out="" status="⏳ idle" status_color="$C_Y"
    epoch_now=$(date +%s)

    # --- SLURM ---
    rows=$(squeue_rows)
    if [ -n "$rows" ]; then
        while read -r jid part job st el lim node; do
            [ -z "$jid" ] && continue
            case "$st" in
                RUNNING|COMPLETING) running="$job"; jid_running="$jid"; elapsed_running="$el"; limit_running="$lim"; node_running="$node" ;;
                PENDING) pending="$pending${pending:+, }$job" ;;
                FAILED)  failed="$failed${failed:+, }$job" ;;
            esac
        done <<< "$rows"
    fi

    # --- active MD stage ---
    read -r stage log <<< "$(active_log)"
    if [ -n "$stage" ]; then
        parse_log "$stage" "$log"
    fi

    # --- header ---
    out+="${C_C}── NA53 DASHBOARD ──────────────────────────────── $(date '+%F %T %Z')${C_0}\n"
    [ -n "$PROFILE" ] && out+="  profile: $PROFILE\n"

    # --- job line ---
    if [ -n "$running" ]; then
        out+="  job:      ${C_B}${running}${C_0} RUNNING  ${elapsed_running} / ${limit_running}  (${node_running})\n"
    elif [ -n "$pending" ]; then
        out+="  job:      ${C_Y}${pending} queued — waiting for dependencies${C_0}\n"
    elif [ -n "$failed" ]; then
        out+="  job:      ${C_R}${failed} FAILED — inspect logs/na53_*_*.err${C_0}\n"
    else
        out+="  job:      none in queue (chain finished or not submitted)\n"
    fi

    # --- stage + progress ---
    if [ -n "$stage" ]; then
        local pct="" bar=""
        if [ -n "$total_ps" ] && [ -n "$cur_ps" ] && awk -v a="$total_ps" 'BEGIN{exit !(a>0)}'; then
            pct=$(awk -v c="$cur_ps" -v t="$total_ps" 'BEGIN{printf "%d", c/t*100}')
            bar=$(awk -v p="$pct" 'BEGIN{
                w=20; n=int(p/100*w); s="";
                for(i=0;i<w;i++) s=s (i<n?"█":"░");
                print s }')
        fi
        out+="  stage:    ${C_B}${STAGE_LABEL[$stage]}${C_0}  ${bar:+$bar $pct%}\n"
        [ -n "$cur_step" ] && [ -n "$total_steps" ] && \
            out+="  step:     $cur_step / $total_steps"
        [ -n "$cur_ps" ] && [ -n "$total_ps" ] && out+="   ·  sim $cur_ps / $total_ps ps"
        [ -n "$cur_step$cur_ps" ] && out+="\n"
        # physics (EM has no Temp/Pres columns)
        if [ "$stage" != "em" ] && [ -n "$temp" ] && [ -n "$pres" ]; then
            out+="  phys:     T = ${temp} K   P = ${pres} bar\n"
        elif [ "$stage" = "em" ] && [ -n "$cur_ps" ]; then
            out+="  phys:     EM — converging (no T/P; emtol in configs/em.mdp)\n"
        fi
    else
        out+="  stage:    (between MD stages — prep/analysis or idle)\n"
    fi

    # --- throughput + ETAs ---
    if [ -n "$stage" ] && [ -n "$cur_ps" ] && [ -n "$total_ps" ]; then
        local rate="" nsday="" eta_s="" eta_s2=""
        # 1) mdrun's own ETA + implied rate ("step N, will finish <date>")
        if [ -n "$fin_eta" ]; then
            local fe
            fe=$(date -d "$fin_eta" +%s 2>/dev/null || echo "")
            if [ -n "$fe" ] && [ "$fe" -gt "$epoch_now" ]; then
                eta_s=$(( fe - epoch_now ))
                if [ -n "$fin_step" ] && [ -n "$total_steps" ] && [ "$total_steps" -gt "$fin_step" ] 2>/dev/null; then
                    rate=$(awk -v r="$(( total_steps - fin_step ))" -v e="$eta_s" 'BEGIN{ if (e > 0) printf "%.2f", r/e }')
                fi
            fi
        fi
        # 2) fallback rate: sim ps over log age (rough, first minutes)
        if [ -z "$rate" ]; then
            local age
            age=$(( epoch_now - $(stat -c %Y "$log" 2>/dev/null || echo "$epoch_now") ))
            if [ "$age" -gt 5 ]; then
                nsday=$(awk -v p="$cur_ps" -v a="$age" 'BEGIN{ printf "%.1f (est.)", p/a*86400/1000 }')
            fi
        fi
        if [ -n "$rate" ]; then
            nsday=$(awk -v r="$rate" 'BEGIN{ printf "%.1f", r*2e-3*86400/1000 }')   # 2 fs/step
        fi
        [ -n "$nsday" ] && out+="  speed:    ${nsday} ns/day${rate:+ · ${rate} steps/s}\n"
        # 3) ETA for this stage: measured first, mdrun estimate as fallback
        if [ -n "$rate" ] && [ -n "$total_steps" ] && [ -n "$cur_step" ] \
           && [ "$total_steps" -gt "$cur_step" ] 2>/dev/null; then
            eta_s2=$(awk -v rem="$(( total_steps - cur_step ))" -v r="$rate" \
                     'BEGIN{ if (r > 0) printf "%d", rem / r }')
            [ -n "$eta_s2" ] && [ "$eta_s2" -gt 0 ] 2>/dev/null && \
                out+="  eta:      ${C_B}$(fmt_dur "$eta_s2")${C_0} to finish this stage\n"
        elif [ -n "$eta_s" ]; then
            out+="  eta:      ${C_B}$(fmt_dur "$eta_s")${C_0} to finish this stage (mdrun estimate)\n"
        fi
        # 4) prod: ETA to the full target (e.g. 100 ns)
        if [ "$stage" = "prod" ] && [ -n "$nsday" ]; then
            local target_ps=$(( TARGET_NS * 1000 ))
            if [ "$target_ps" -gt "${cur_ps%.*}" ] 2>/dev/null; then
                local d
                d=$(awk -v t="$target_ps" -v c="${cur_ps%.*}" -v n="${nsday%% *}" \
                    'BEGIN{ if (n+0 > 0) printf "%.2f", (t-c)/1000/n; else print 0 }')
                out+="  target:   ${TARGET_NS} ns at this rate ≈ ${C_B}${d}d${C_0}\n"
            fi
        fi
    fi

    # --- status verdict ---
    if [ -n "$failed" ]; then
        status="❌ failed"; status_color="$C_R"
    elif [ -n "$running" ]; then
        local age2=0
        if [ -n "$log" ]; then age2=$(( epoch_now - $(stat -c %Y "$log" 2>/dev/null || echo 0) )); fi
        if [ -n "$stage" ] && [ "$age2" -gt 600 ]; then
            status="⚠️  stale — ${age2}s without log writes (possible hang)"; status_color="$C_Y"
        else
            status="✅ healthy"; status_color="$C_G"
        fi
    elif [ -n "$pending" ]; then
        status="⏳ queued"; status_color="$C_Y"
    else
        status="⏳ idle — nothing running"; status_color="$C_Y"
    fi
    out+="  status:   ${status_color}${status}${C_0}\n"
    out+="${C_C}──────────────────────────────────────────────────────────────${C_0}\n"
    printf '%b' "$out"
}

# ─── loop ───────────────────────────────────────────────────
if [ "$ONCE" = "1" ]; then
    render
    exit 0
fi
if [ "$TTY" = "1" ] && [ "$NO_CLEAR" = "0" ]; then
    while true; do
        printf '\033[2J\033[H'      # clear + home
        render
        sleep "$EVERY"
    done
else
    while true; do
        render
        echo ""
        sleep "$EVERY"
    done
fi