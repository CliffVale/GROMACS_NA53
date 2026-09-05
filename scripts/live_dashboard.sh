#!/bin/bash
# ============================================================
# live_dashboard.sh — NA53 real-time simulation dashboard (THE monitor)
# GROMACS_NA53
# ============================================================
# Polls every N seconds and re-renders a simple, line-based screen.
# Zero dependencies: pure bash + squeue + log reads — nothing to pip
# install, safe on a login node. `./run_simulation.sh monitor` runs
# this and only this (no TUI layer).
#
#   JOBS        every na53_* SLURM job (state, elapsed/limit, node/reason)
#   STAGE       active MD stage + progress bar + step/sim time
#   PHYSICS     live Temp / Pres from the gmx .log energy table
#   SPEED+ETA   measured ns/day, stage ETA, prod-target ETA
#   PIPELINE    01 prep / 02 equil / 03 prod / 04 analysis checklist
#   LOG         tail of the newest logs/mdrun_*.log (raw mdrun output)
#   TRAIL       last launcher events (logs/run_status.txt)
#   STATUS      ✅ / ⏳ / ⚠️ / ❌ verdict — incl. a STALE-STAGE check that
#               flags an unfinished stage log with no job running (a
#               job that died/killed mid-stage shows up here, not as
#               "idle")
#
# Data is read live from squeue, the gmx .log sidecars
# (scripts/{em,nvt,npt1,npt2,prod}.log) and pipeline artifacts — no gmx
# spawning, so polls are cheap even on a login node.
#
# Usage:
#   bash scripts/live_dashboard.sh [--every SEC] [--target-ns N] [--once]
#                                   [--profile NAME] [--no-color] [--no-clear]
# ============================================================

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

EVERY=30 TARGET_NS=100 ONCE=0 PROFILE=""
NO_COLOR=0 NO_CLEAR=0
# poll-to-poll rate state (live ns/day needs two renders ≥15 s apart)
POLL_TS=0 POLL_PS="" POLL_STAGE=""
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

TTY=0; [ -t 1 ] && TTY=1
if [ "$TTY" = "1" ] && [ "$NO_COLOR" = "0" ]; then
    C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_C=$'\033[36m'
    C_B=$'\033[1m'; C_D=$'\033[2m'; C_0=$'\033[0m'
else
    C_G=""; C_Y=""; C_R=""; C_C=""; C_B=""; C_D=""; C_0=""
fi

STAGES="em nvt npt1 npt2 prod"
declare -A STAGE_LABEL=( [em]="EM · energy minimization (no T/P)"
                          [nvt]="NVT · 100 ps, V-rescale"
                          [npt1]="NPT1 · 100 ps, restrained (POSRES)"
                          [npt2]="NPT2 · 500 ps, free"
                          [prod]="PRODUCTION · unrestrained NPT" )
RULE="────────────────────────────────────────────────────────"

fmt_dur() { # seconds -> "3d 4h 12m" | "12m 04s" | "34s"
    local s=$1 d h m
    if [ "$s" -lt 60 ]; then echo "${s}s"; return; fi
    d=$(( s / 86400 )); s=$(( s % 86400 ))
    h=$(( s / 3600 ));  s=$(( s % 3600 ))
    m=$(( s / 60 ));    s=$(( s % 60 ))
    if   [ "$d" -gt 0 ]; then printf '%dd %dh %dm' "$d" "$h" "$m"
    elif [ "$h" -gt 0 ]; then printf '%dh %02dm' "$h" "$m"
    else printf '%dm %02ds' "$m" "$s"; fi
}
fmt_bytes() { # bytes -> human
    local b=$1
    awk -v b="$b" 'BEGIN{ if (b >= 1073741824) printf "%.1f GB", b/1073741824;
                     else if (b >= 1048576) printf "%.1f MB", b/1048576;
                     else if (b >= 1024) printf "%.1f KB", b/1024;
                     else printf "%d B", b }'
}

# ─── data gatherers ─────────────────────────────────────────

squeue_rows() { # our job rows: "JOBID NAME STATE ELAPSED LIMIT NODE/REASON"
    command -v squeue >/dev/null 2>&1 || return 0
    squeue -h -u "$USER" -o "%i %j %T %M %L %R" 2>/dev/null \
        | awk '$2 ~ /^na53_/ { print }'
}

active_log() { # newest scripts/<stage>.log NOT finished; echoes "stage path"
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

parse_log() { # $1=stage → sets total_steps total_ps cur_step cur_ps temp
              # pres fin_eta fin_step log_age. Merges BOTH the gmx sidecar
              # scripts/<stage>.log and the redirected mdrun stdout
              # logs/mdrun_<stage>.log — mdrun prints its "step N, will
              # finish" ETA + progress tables to stdout; the sidecar carries
              # the same tables. Newer file is primary so restarts win.
    local s="$1" log out sout src
    log="scripts/$s.log"; out="logs/mdrun_${s}.log"
    # SLURM capture: sbatch runs mdrun with no internal redirect, so the
    # "step N, will finish" + totals lines land in logs/na53_<stage>_*.out
    sout=$(ls -t logs/na53_${s}_*.out 2>/dev/null | head -1)
    total_steps=""; total_ps=""; cur_step=""; cur_ps=""; temp=""; pres=""
    fin_eta=""; fin_step=""; log_age=""
    # candidates: gmx sidecar, redirected stdout, SLURM capture.
    # Newest mtime first (a live stream wins); each field takes the first hit.
    local cand=""
    for src in "$out" "$sout" "$log"; do
        [ -f "$src" ] && cand="$cand $src"
    done
    [ -n "$cand" ] && cand=$(ls -t $cand 2>/dev/null)
    for src in $cand; do
        [ -f "$src" ] || continue
        if [ -z "$log_age" ]; then
            log_age=$(( $(date +%s) - $(stat -c %Y "$src" 2>/dev/null || echo "$(date +%s)") ))
        fi
        # total: last "N steps, X ps." (prod RESTART appends further starts);
        # allow leading space — gmx may indent it in the .log sidecar
        if [ -z "$total_steps" ]; then
            line=$(grep -E "^ *[0-9]+ steps, +[0-9.]+ ps\.$" "$src" | tail -1)
            if [ -n "$line" ]; then
                total_steps=$(echo "$line" | awk '{print $1}')
                total_ps=$(echo "$line" | awk '{print $3}')
            fi
        fi
        # mdrun's own ETA: "step N, will finish <date>" (strip the comma)
        if [ -z "$fin_step" ]; then
            line=$(grep -E "^step [0-9]+, will finish" "$src" | tail -1)
            if [ -n "$line" ]; then
                fin_step=$(echo "$line" | awk '{print $2}' | tr -d ',')
                fin_eta=$(echo "$line" | sed -E 's/^step [0-9]+, will finish //')
            fi
        fi
        # step/time — tolerant, same as health_report H4 (proven on T3 2024.4)
        if [ -z "$cur_step" ]; then
            read -r cur_step cur_ps <<< "$(awk '
                /^ *Step +Time/ { want=1; next }
                want && NF >= 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ { st=$1; t=$2 }
                END { if (st != "") print st, t }
            ' "$src")"
        fi
        # temp/pres — gmx 2024 .log reports these as LABELED scalars inside
        # the energy block (scientific notation), not Step/Time columns:
        #   … Conserved En.    Temperature      ← label row, T is LAST label
        #   -3.33e+06          3.09567e+02      ← value row, T is LAST value
        #   Pres. DC (bar) Pressure (bar) …     ← P is the 2nd label/value
        # Order-anchored on the raw row text (robust to spacing), with a
        # cols-4/5 fallback for other gmx versions.
        if [ -z "$temp" ]; then
            read -r temp pres <<< "$(awk '
                /^ *Step +Time/ { want=1; lbl=""; next }
                want && /Energies \(kJ\/mol\)/ { next }
                want && $1 ~ /[A-Za-z]/ && $1 !~ /^[-+0-9]/ {
                    lbl=$0; last=$NF; next
                }
                want && $1 ~ /^[-+0-9]/ {
                    if (last=="Temperature") tp=$NF
                    if (lbl ~ /Pressure \(bar\)/) pr=$2
                    last=""
                }
                END { if (tp != "") printf "%.2f %.4f", tp+0, pr+0 }
            ' "$src")"
        fi
        # fallback: tabular layout (older gmx) — Temp/Pres as cols 4/5
        if [ -z "$temp" ]; then
            read -r temp pres <<< "$(awk '
                /^ *Step +Time/ { want=1; next }
                want && NF >= 5 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ \
                     && $4 ~ /^-?[0-9.]+$/ && $5 ~ /^-?[0-9.]+$/ { tp=$4; pr=$5 }
                END { if (tp != "") print tp, pr }
            ' "$src")"
        fi
    done
}

stage_icon() { # $1 done(0/1)  $2 active-stage  $3 stage-family
    local done=$1 stg=${2:-} fam=${3:-}
    if [ "$done" = "1" ]; then printf '%s✅ done%s' "$C_G" "$C_0"
    elif [ "$fam" = "$stg" ]; then printf '%s▶ active%s' "$C_Y" "$C_0"
    elif [ "$fam" = "equil" ] && { [ "$stg" = "em" ] || [ "$stg" = "nvt" ] \
           || [ "$stg" = "npt1" ] || [ "$stg" = "npt2" ]; }; then
        printf '%s▶ active%s' "$C_Y" "$C_0"
    else
        printf '%s○ pending%s' "$C_D" "$C_0"
    fi
}

next_label() { # $1 stage key -> human label of what follows
    case "$1" in
        em) echo "NVT · 100 ps" ;;
        nvt) echo "NPT1 · 100 ps, restrained" ;;
        npt1) echo "NPT2 · 500 ps, free" ;;
        npt2) echo "PRODUCTION · unrestrained NPT" ;;
        prod) echo "ANALYSIS · 7 metrics + figures" ;;
        *) echo "—" ;;
    esac
}

# ─── render ─────────────────────────────────────────────────
render() {
    local rows running="" pending="" failed="" jid job st el lim reason
    local stage="" log="" total_steps="" total_ps="" cur_step="" cur_ps="" temp="" pres=""
    local fin_eta="" fin_step="" log_age=""
    local rate="" r_ps="" nsday="" eta_s="" eta_s2="" pct="" bar=""
    local prep_done=0 equil_done=0 prod_done=0 ana_done=0 atoms="" n_figs=0
    local epoch_now; epoch_now=$(date +%s)

    # ── SLURM ──
    rows=$(squeue_rows)
    if [ -n "$rows" ]; then
        while read -r jid job st el lim reason; do
            [ -z "$jid" ] && continue
            case "$st" in
                RUNNING|COMPLETING) running="$job" ;;
                PENDING)  pending="${pending:+$pending, }$job" ;;
                FAILED)   failed="${failed:+$failed, }$job" ;;
            esac
        done <<< "$rows"
    fi

    # ── active MD stage ──
    read -r stage log <<< "$(active_log)"
    if [ -n "$stage" ]; then parse_log "$stage"; fi

    # ── pipeline / artifacts ──
    [ -s scripts/topol.top ] && prep_done=1
    atoms=$(sed -n '2p' scripts/NA53_initial_ionized.gro 2>/dev/null)
    # done means mdrun actually FINISHED the stage ("Finished mdrun" in the
    # gmx log) — a partial prod.xtc/npt2.gro is NOT done
    grep -q "Finished mdrun" scripts/npt2.log 2>/dev/null && equil_done=1
    grep -q "Finished mdrun" scripts/prod.log 2>/dev/null && prod_done=1
    n_figs=$(ls results/figures/*.png 2>/dev/null | wc -l)
    [ "$n_figs" -gt 0 ] && ana_done=1

    # ── progress bar ──
    if [ -n "$total_ps" ] && [ -n "$cur_ps" ] && awk -v a="$total_ps" 'BEGIN{exit !(a>0)}'; then
        pct=$(awk -v c="$cur_ps" -v t="$total_ps" 'BEGIN{printf "%d", c/t*100}')
        bar=$(awk -v p="$pct" 'BEGIN{ w=20; n=int(p/100*w); s="";
            for(i=0;i<w;i++) s=s (i<n?"█":"░"); print s }')
    fi

    # ── live rate + ETAs (fresh-log gate only; a stale log is a dead stage) ──
    if [ -n "$stage" ] && [ -n "$cur_ps" ] && [ "$log_age" -le 600 ]; then
        # 1) mdrun's own ETA line (stdout capture), when present
        if [ -n "$fin_eta" ] && [ -n "$total_steps" ]; then
            local fe
            fe=$(date -d "$fin_eta" +%s 2>/dev/null || echo "")
            if [ -n "$fe" ] && [ "$fe" -gt "$epoch_now" ] \
               && [ -n "$fin_step" ] && [ "$total_steps" -gt "$fin_step" ] 2>/dev/null; then
                eta_s=$(( fe - epoch_now ))
                rate=$(awk -v r="$(( total_steps - fin_step ))" -v e="$eta_s" \
                       'BEGIN{ if (e > 0) printf "%.2f", r/e }')
                if [ -n "$rate" ]; then
                    nsday=$(awk -v r="$rate" 'BEGIN{ printf "%.1f", r*2e-3*86400/1000 }')   # 2 fs/step
                    if [ -n "$cur_step" ] && [ "$total_steps" -gt "$cur_step" ] 2>/dev/null; then
                        eta_s2=$(awk -v rem="$(( total_steps - cur_step ))" -v r="$rate" \
                                 'BEGIN{ if (r > 0) printf "%d", rem / r }')
                    fi
                fi
            fi
        fi
        # 2) poll-to-poll Δps/Δt — works with NO totals and NO ETA line
        if [ -z "$rate" ]; then
            local now2 dt dps
            now2=$(date +%s)
            if [ "$POLL_STAGE" = "$stage" ] && [ -n "$POLL_PS" ] \
               && [ "$now2" -gt "$POLL_TS" ] && [ "$(( now2 - POLL_TS ))" -ge 15 ] \
               && awk -v a="$cur_ps" -v b="$POLL_PS" 'BEGIN{exit !(a>b)}'; then
                dt=$(( now2 - POLL_TS ))
                dps=$(awk -v a="$cur_ps" -v b="$POLL_PS" 'BEGIN{printf "%.3f", a-b}')
                r_ps=$(awk -v d="$dps" -v t="$dt" 'BEGIN{ if (t>0) printf "%.2f", d/t }')
                if [ -n "$r_ps" ]; then
                    nsday=$(awk -v r="$r_ps" 'BEGIN{ printf "%.1f", r*86.4 }')   # ps/s → ns/day
                    if [ -n "$total_ps" ] \
                       && awk -v t="$total_ps" -v c="$cur_ps" 'BEGIN{exit !(t>c)}'; then
                        eta_s2=$(awk -v rem="$(( ${total_ps%.*} - ${cur_ps%.*} ))" -v r="$r_ps" \
                                 'BEGIN{ if (r > 0) printf "%d", rem / r }')
                    fi
                fi
            fi
            POLL_STAGE="$stage"; POLL_PS="$cur_ps"; POLL_TS="$now2"
        fi
    else
        POLL_STAGE=""; POLL_PS=""; POLL_TS=0
    fi

    # ── output ──
    echo ""
    echo "${C_C}${RULE}${C_0}"
    echo "  ${C_B}NA53 · GROMACS LIVE${C_0}          $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "  profile ${C_B}${PROFILE:-?}${C_0} · host $(hostname) · refresh ${EVERY}s · target ${TARGET_NS} ns"
    echo "${C_C}${RULE}${C_0}"

    echo "  ${C_B}JOBS${C_0}"
    if [ -n "$rows" ]; then
        while read -r jid job st el lim reason; do
            [ -z "$jid" ] && continue
            case "$st" in
                RUNNING|COMPLETING) stc="$C_G"; sttxt="$st" ;;
                PENDING)            stc="$C_Y"; sttxt="queued" ;;
                FAILED)             stc="$C_R"; sttxt="FAILED" ;;
                COMPLETED)          stc="$C_G"; sttxt="done" ;;
                *)                  stc="$C_Y"; sttxt="$st" ;;
            esac
            echo "    ${C_D}#${jid}${C_0}  ${C_B}${job}${C_0}  ${stc}${sttxt}${C_0}"
            if [ "$st" = "RUNNING" ] || [ "$st" = "COMPLETING" ]; then
                echo "      ${C_D}${el} elapsed / ${lim} limit · ${reason}${C_0}"
            else
                echo "      ${C_D}waiting: ${reason}${C_0}"
            fi
        done <<< "$rows"
    else
        echo "    ${C_Y}(no na53_* jobs in queue)${C_0}"
    fi

    echo "  ${C_B}STAGE${C_0}"
    if [ -n "$stage" ]; then
        echo "    ${C_B}${STAGE_LABEL[$stage]}${C_0}"
        if [ -n "$bar" ]; then
            echo "    ${bar} ${C_B}${pct}%${C_0}"
        elif [ -n "$cur_ps" ] && [ -z "$total_ps" ]; then
            # mdrun start line (the totals) lives in the stdout capture, which
            # this run doesn't write — show elapsed progress without a bar
            echo "    ${C_Y}sim ${cur_ps} ps elapsed — total not in log (bar unavailable)${C_0}"
        else
            echo "    ${C_D}(waiting for the first energy block — log age ${log_age}s)${C_0}"
        fi
        [ -n "$cur_step" ] && \
            echo "    step ${cur_step}${total_steps:+ / ${total_steps}}"
        if [ -n "$cur_ps" ] && [ -n "$total_ps" ]; then
            echo "    sim  ${C_B}${cur_ps}${C_0} ps / ${total_ps} ps"
        fi
    else
        echo "    ${C_Y}(between MD stages — prep/analysis running, or idle)${C_0}"
    fi

    echo "  ${C_B}PHYSICS${C_0}"
    if [ -n "$stage" ] && [ "$stage" != "em" ] && [ -n "$temp" ] && [ -n "$pres" ]; then
        echo "    T = ${C_B}${temp}${C_0} K      P = ${C_B}${pres}${C_0} bar"
    elif [ -n "$stage" ] && [ "$stage" = "em" ]; then
        echo "    ${C_D}EM — minimizing, no T/P yet${C_0}"
    elif [ -z "$stage" ]; then
        echo "    ${C_D}(no active MD stage — T/P appear once mdrun prints its energy table)${C_0}"
    else
        echo "    ${C_D}(no T/P in the log table yet)${C_0}"
    fi

    echo "  ${C_B}SPEED + ETA${C_0}"
    if [ -n "$nsday" ]; then
        echo "    ns/day ${C_B}${nsday}${C_0}${rate:+  (${rate} steps/s @ 2 fs)}${r_ps:+  (${r_ps} ps/s)}"
    elif [ -n "$log_age" ] && [ "$log_age" -gt 600 ]; then
        echo "    ns/day ${C_D}— log stale (${log_age}s old) — no live speed${C_0}"
    elif [ -n "$cur_ps" ]; then
        echo "    ns/day ${C_D}— measuring (needs two polls ≥15 s apart)${C_0}"
    else
        echo "    ns/day ${C_D}— need the first energy block${C_0}"
    fi
    if [ -n "$eta_s2" ] && [ "$eta_s2" -gt 0 ] 2>/dev/null; then
        echo "    ETA ${C_B}$(fmt_dur "$eta_s2")${C_0} to finish this stage"
    elif [ -n "$eta_s" ]; then
        echo "    ETA ${C_B}$(fmt_dur "$eta_s")${C_0} (mdrun estimate · ~${fin_eta})"
    fi
    if [ "$stage" = "prod" ] && [ -n "$nsday" ]; then
        local target_ps=$(( TARGET_NS * 1000 ))
        if [ "$target_ps" -gt "${cur_ps%.*}" ] 2>/dev/null; then
            local d
            d=$(awk -v t="$target_ps" -v c="${cur_ps%.*}" -v n="${nsday%% *}" \
                'BEGIN{ if (n+0 > 0) printf "%.2f", (t-c)/1000/n; else print 0 }')
            echo "    target ${TARGET_NS} ns at this rate ≈ ${C_B}${d} d${C_0}"
        fi
    elif [ -n "$stage" ] && [ "$stage" != "prod" ] && [ -n "$total_ps" ]; then
        echo "    next  ${C_D}$(next_label "$stage")${C_0}"
    fi

    echo "  ${C_B}PIPELINE${C_0}"
    local prep_suffix=""
    [ -n "$atoms" ] && prep_suffix=" · ${atoms} atoms"
    echo "    01 prep      $(stage_icon "$prep_done" "$stage" prep)" \
         "${C_D}topol.top $(fmt_bytes "$(stat -c %s scripts/topol.top 2>/dev/null || echo 0)")${C_0}${prep_suffix}"
    echo "    02 equil     $(stage_icon "$equil_done" "$stage" equil)" \
         "${C_D}npt2.gro $(fmt_bytes "$(stat -c %s scripts/npt2.gro 2>/dev/null || echo 0)")${C_0}"
    echo "    03 prod      $(stage_icon "$prod_done" "$stage" prod)" \
         "${C_D}target ${TARGET_NS} ns · xtc $(fmt_bytes "$(stat -c %s scripts/prod.xtc 2>/dev/null || echo 0)")${C_0}"
    echo "    04 analysis  $(stage_icon "$ana_done" "$stage" ana)" \
         "${C_D}${n_figs} figure(s)${C_0}"

    # ── raw mdrun output: the active stage's stdout capture, or its .log
    # sidecar when the capture is missing (as in the current T3 prod run) ──
    local mlog
    if [ -n "$stage" ]; then
        mlog="logs/mdrun_${stage}.log"
        [ -f "$mlog" ] || mlog="scripts/${stage}.log"
    else
        mlog=$(ls -t logs/mdrun_*.log 2>/dev/null | head -1)
    fi
    if [ -n "$mlog" ] && [ -f "$mlog" ]; then
        echo "  ${C_B}LOG${C_0}    ${C_D}tail of ${mlog}${C_0}"
        tail -n 4 "$mlog" 2>/dev/null | sed "s/^/    ${C_D}/; s/$/${C_0}/"
    fi

    if [ -s logs/run_status.txt ]; then
        echo "  ${C_B}TRAIL${C_0}"
        local tline
        while IFS= read -r tline; do
            echo "    ${C_D}${tline}${C_0}"
        done < <(tail -n 3 logs/run_status.txt)
    fi

    # ── verdict ──
    local st="" stc="$C_Y"
    if [ -n "$failed" ]; then
        st="❌ FAILED: ${failed} — inspect logs/na53_*_*.err"; stc="$C_R"
    elif [ -n "$running" ]; then
        if [ -n "$stage" ] && [ "$log_age" -gt 600 ]; then
            st="⚠️  stale — log untouched ${log_age}s while running (possible hang)"; stc="$C_Y"
        else
            st="✅ healthy${stage:+ · ${STAGE_LABEL[$stage]}}${nsday:+ · ${nsday} ns/day}"; stc="$C_G"
        fi
    elif [ -n "$pending" ]; then
        st="⏳ queued — ${pending} waiting (afterok chain)"; stc="$C_Y"
    elif [ -n "$stage" ]; then
        # stage log open but no job running: died mid-stage or a manual run
        if [ "$log_age" -gt 900 ]; then
            st="⚠️  ${stage} log stopped ${log_age}s ago with no job in queue — job likely died/killed; check sacct + logs/na53_*_*.err"
            stc="$C_Y"
        else
            st="▶ ${stage} log active (${log_age}s old) but no SLURM job — manual/local run?"
            stc="$C_Y"
        fi
    else
        st="⏳ idle — chain finished or not submitted"; stc="$C_Y"
    fi
    echo ""
    echo "  ${stc}${st}${C_0}"
    echo "${C_C}${RULE}${C_0}"
}

# ─── loop ───────────────────────────────────────────────────
if [ "$ONCE" = "1" ]; then
    render
    exit 0
fi
if [ "$TTY" = "1" ] && [ "$NO_CLEAR" = "0" ]; then
    while true; do
        printf '\033[2J\033[H'
        render
        sleep "$EVERY"
    done
else
    while true; do
        render
        sleep "$EVERY"
    done
fi