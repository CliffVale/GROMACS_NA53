#!/bin/bash
# ============================================================
# live_dashboard.sh — NA53 real-time simulation dashboard
# GROMACS_NA53
# ============================================================
# Polls every N seconds and re-renders one professional, boxed screen:
#
#   ┌─ NA53 · GROMACS LIVE DASHBOARD ───────────── <time> ─┐
#   │ header: profile · host · refresh cadence              │
#   ├──────────────────────────────────────────────────────┤
#   │ JOBS      every na53_* SLURM job: id, state,         │
#   │           elapsed/limit, node or dependency reason    │
#   ├──────────────────────────────────────────────────────┤
#   │ STAGE     active MD stage (EM/NVT/NPT1/NPT2/prod),    │
#   │           progress bar, step, sim time                │
#   ├──────────────────────────────────────────────────────┤
#   │ PHYSICS   live Temp / Pres from the gmx energy table  │
#   ├──────────────────────────────────────────────────────┤
#   │ SPEED     ns/day, steps/s, stage ETA, mdrun-estimated │
#   │           finish time, prod-target ETA                │
#   ├──────────────────────────────────────────────────────┤
#   │ PIPELINE  01 prep / 02 equil / 03 prod / 04 analysis  │
#   │           state + key artifacts + system size         │
#   ├──────────────────────────────────────────────────────┤
#   │ TRAIL     last launcher events (logs/run_status.txt)  │
#   ├──────────────────────────────────────────────────────┤
#   │ HEALTH    ✅ / ⏳ / ⚠️ / ❌ verdict + log freshness    │
#   └──────────────────────────────────────────────────────┘
#
# Data is read live from squeue, the gmx .log sidecars
# (scripts/{em,nvt,npt1,npt2,prod}.log) and pipeline artifacts —
# no gmx spawning, so polls are cheap even on a login node.
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
    C_M=$'\033[35m'; C_B=$'\033[1m'; C_D=$'\033[2m'; C_0=$'\033[0m'
else
    C_G=""; C_Y=""; C_R=""; C_C=""; C_M=""; C_B=""; C_D=""; C_0=""
fi

W=76                                   # box width (borders included)
STAGES="em nvt npt1 npt2 prod"
declare -A STAGE_LABEL=( [em]="EM · energy minimization (no T/P)"
                          [nvt]="NVT · 100 ps, V-rescale"
                          [npt1]="NPT1 · 100 ps, restrained (POSRES)"
                          [npt2]="NPT2 · 500 ps, free"
                          [prod]="PRODUCTION · unrestrained NPT" )

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

# ─── box helpers ────────────────────────────────────────────
HORIZ() { printf '%.0s─' $(seq 1 $((W - 2))); }
top() { # $1 = right-side text
    local left="NA53 · GROMACS LIVE DASHBOARD" right="$1"
    local fill=$(( W - 4 - ${#left} - ${#right} - 3 ))
    [ "$fill" -lt 1 ] && fill=1
    printf '┌─ %s%s %s ─┐\n' "$left" "$(printf '%.0s─' $(seq 1 "$fill"))" "$right"
}
sep()  { printf '├%s┤\n' "$(HORIZ)"; }
bot()  { printf '└%s┘\n' "$(HORIZ)"; }
pad() { # ANSI-aware right-pad: $1 text, $2 width
    local s="$1" w="${2:-$((W - 4))}" plain l
    plain=$(printf '%s' "$s" | sed -E 's/\x1B\[[0-9;]*m//g')
    l=${#plain}
    if [ "$l" -lt "$w" ]; then printf '%s%*s' "$s" "$((w - l))" "";
    else printf '%s' "$s"; fi
}
line() { printf '│ %s│\n' "$(pad "$1")"; }
sec()  { line "${C_B}${C_C}$1${C_0}"; }

# ─── data gatherers ─────────────────────────────────────────

our_jobs() { # all na53_* jobs: "JOBID NAME STATE ELAPSED LIMIT REASON/NODE"
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

parse_log() { # $1=stage $2=log → sets total_steps total_ps cur_step cur_ps
              #                    temp pres fin_eta fin_step log_age
    local s="$1" log="$2" line
    total_steps=""; total_ps=""; cur_step=""; cur_ps=""; temp=""; pres=""
    fin_eta=""; fin_step=""; log_age=""
    log_age=$(( $(date +%s) - $(stat -c %Y "$log" 2>/dev/null || echo "$(date +%s)") ))
    # total: last "N steps, X ps." (prod RESTART appends further starts)
    line=$(grep -E "^[0-9]+ steps, +[0-9.]+ ps\.$" "$log" | tail -1)
    if [ -n "$line" ]; then
        total_steps=$(echo "$line" | awk '{print $1}')
        total_ps=$(echo "$line" | awk '{print $3}')
    fi
    # mdrun's own ETA: "step N, will finish <date>" (strip the comma)
    line=$(grep -E "^step [0-9]+, will finish" "$log" | tail -1)
    if [ -n "$line" ]; then
        fin_step=$(echo "$line" | awk '{print $2}' | tr -d ',')
        fin_eta=$(echo "$line" | sed -E 's/^step [0-9]+, will finish //')
    fi
    # step/time — tolerant, same as health_report H4 (proven on T3 2024.4)
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

# ─── render ─────────────────────────────────────────────────
render() {
    local epoch_now rows running="" pending="" failed="" jid job st el lim node reason
    local stage="" log="" total_steps="" total_ps="" cur_step="" cur_ps="" temp="" pres=""
    local fin_eta="" fin_step="" log_age=""
    local rate="" nsday="" eta_s="" eta_s2="" pct="" bar=""
    local prep_done=0 equil_done=0 prod_done=0 ana_done=0 atoms="" n_figs=0
    epoch_now=$(date +%s)

    # ── SLURM ──
    rows=$(our_jobs)
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
    if [ -n "$stage" ]; then parse_log "$stage" "$log"; fi

    # ── pipeline / artifacts ──
    [ -s scripts/topol.top ] && prep_done=1
    atoms=$(sed -n '2p' scripts/NA53_initial_ionized.gro 2>/dev/null)
    [ -f scripts/npt2.gro ] && equil_done=1
    [ -f scripts/prod.xtc ] && prod_done=1
    n_figs=$(ls results/figures/*.png 2>/dev/null | wc -l)
    [ "$n_figs" -gt 0 ] && ana_done=1

    # ── progress bar ──
    if [ -n "$total_ps" ] && [ -n "$cur_ps" ] && awk -v a="$total_ps" 'BEGIN{exit !(a>0)}'; then
        pct=$(awk -v c="$cur_ps" -v t="$total_ps" 'BEGIN{printf "%d", c/t*100}')
        bar=$(awk -v p="$pct" 'BEGIN{ w=22; n=int(p/100*w); s="";
            for(i=0;i<w;i++) s=s (i<n?"█":"░"); print s }')
    fi

    # ── throughput / ETAs ──
    if [ -n "$stage" ] && [ -n "$cur_ps" ] && [ -n "$total_ps" ]; then
        if [ -n "$fin_eta" ]; then
            local fe
            fe=$(date -d "$fin_eta" +%s 2>/dev/null || echo "")
            if [ -n "$fe" ] && [ "$fe" -gt "$epoch_now" ]; then
                eta_s=$(( fe - epoch_now ))
                if [ -n "$fin_step" ] && [ -n "$total_steps" ] \
                   && [ "$total_steps" -gt "$fin_step" ] 2>/dev/null; then
                    rate=$(awk -v r="$(( total_steps - fin_step ))" -v e="$eta_s" \
                           'BEGIN{ if (e > 0) printf "%.2f", r/e }')
                fi
            fi
        fi
        if [ -z "$rate" ] && [ "$log_age" -gt 5 ]; then   # log-age fallback
            nsday=$(awk -v p="$cur_ps" -v a="$log_age" 'BEGIN{ printf "%.1f (est.)", p/a*86400/1000 }')
        fi
        if [ -n "$rate" ]; then
            nsday=$(awk -v r="$rate" 'BEGIN{ printf "%.1f", r*2e-3*86400/1000 }')   # 2 fs/step
        fi
        if [ -n "$rate" ] && [ -n "$total_steps" ] && [ -n "$cur_step" ] \
           && [ "$total_steps" -gt "$cur_step" ] 2>/dev/null; then
            eta_s2=$(awk -v rem="$(( total_steps - cur_step ))" -v r="$rate" \
                     'BEGIN{ if (r > 0) printf "%d", rem / r }')
        fi
    fi

    # ── assemble ──
    top "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    line "${C_D}profile ${C_B}${PROFILE:-?}${C_D} · host $(hostname)${C_D} · refresh every ${EVERY}s · target ${TARGET_NS} ns${C_0}"
    sep
    sec "JOBS"
    if [ -n "$rows" ]; then
        while read -r jid job st el lim reason; do
            [ -z "$jid" ] && continue
            local stc="$C_Y" sttxt="$st"
            case "$st" in
                RUNNING)   stc="$C_G"; sttxt="RUNNING" ;;
                PENDING)   stc="$C_Y"; sttxt="queued" ;;
                FAILED)    stc="$C_R"; sttxt="FAILED" ;;
                COMPLETED) stc="$C_G"; sttxt="done" ;;
                *)         stc="$C_Y" ;;
            esac
            if [ "$st" = "RUNNING" ]; then
                line "  ${C_D}$jid${C_0}  ${C_B}$job${C_0}  ${stc}$sttxt${C_0}  ${C_D}${el} / ${lim}${C_0}  ${C_D}$reason${C_0}"
            else
                line "  ${C_D}$jid${C_0}  ${C_B}$job${C_0}  ${stc}$sttxt${C_0}  ${C_D}—${C_0}  ${C_D}$reason${C_0}"
            fi
        done <<< "$rows"
    else
        line "  ${C_Y}(no na53_* jobs in queue)${C_0}"
    fi
    sep
    sec "STAGE"
    if [ -n "$stage" ]; then
        line "  ${C_B}${C_C}${STAGE_LABEL[$stage]}${C_0}"
        if [ -n "$bar" ]; then
            line "  ${bar} ${C_B}$pct%${C_0}"
        else
            line "  ${C_D}(progress — waiting for the first energy block)${C_0}"
        fi
        if [ -n "$cur_step" ] && [ -n "$total_steps" ]; then
            line "  step  ${C_B}$(printf "%'d" "$cur_step")${C_0} / $(printf "%'d" "$total_steps")"
        fi
        if [ -n "$cur_ps" ] && [ -n "$total_ps" ]; then
            line "  sim   ${C_B}${cur_ps}${C_0} ps / ${total_ps} ps"
        elif [ -n "$total_ps" ]; then
            line "  sim   0.0 ps / ${total_ps} ps  ${C_D}(log age ${log_age}s)${C_0}"
        fi
    else
        line "  ${C_Y}(between MD stages — prep/analysis, or idle)${C_0}"
    fi
    sep
    sec "PHYSICS"
    if [ -n "$stage" ] && [ "$stage" != "em" ] && [ -n "$temp" ] && [ -n "$pres" ]; then
        line "  T = ${C_B}${temp}${C_0} K      P = ${C_B}${pres}${C_0} bar    ${C_D}(V-rescale · Parrinello-Rahman)${C_0}"
    elif [ -n "$stage" ] && [ "$stage" = "em" ]; then
        line "  ${C_D}EM — energy minimization, no temperature (emtol in configs/em.mdp)${C_0}"
    else
        line "  ${C_D}(no energy table yet — see STAGE)${C_0}"
    fi
    sep
    sec "SPEED + ETA"
    if [ -n "$nsday" ]; then
        line "  ns/day  ${C_B}${nsday}${C_0}${rate:+  ·  ${rate} steps/s @ 2 fs}${C_D}${rate:+ (mdrun implied)}${C_0}"
    else
        line "  ns/day  ${C_D}— (need the first energy block)${C_0}"
    fi
    if [ -n "$eta_s2" ] && [ "$eta_s2" -gt 0 ] 2>/dev/null; then
        line "  ETA     ${C_B}$(fmt_dur "$eta_s2")${C_0} to finish this stage"
    elif [ -n "$eta_s" ]; then
        line "  ETA     ${C_B}$(fmt_dur "$eta_s")${C_0} (mdrun estimate · finish ~${C_D}${fin_eta}${C_0})"
    fi
    if [ "$stage" = "prod" ] && [ -n "$nsday" ]; then
        local target_ps=$(( TARGET_NS * 1000 ))
        if [ "$target_ps" -gt "${cur_ps%.*}" ] 2>/dev/null; then
            local d
            d=$(awk -v t="$target_ps" -v c="${cur_ps%.*}" -v n="${nsday%% *}" \
                'BEGIN{ if (n+0 > 0) printf "%.2f", (t-c)/1000/n; else print 0 }')
            line "  target  ${TARGET_NS} ns at this rate ≈ ${C_B}${d}d${C_0}"
        fi
    elif [ -n "$stage" ] && [ -n "$total_ps" ]; then
        line "  next    ${C_D}$(next_stage "$stage")${C_0}"
    fi
    sep
    sec "PIPELINE"
    line "  ${C_B}01 prep${C_0}      $(icon $prep_done $stage prep) ${C_D}topol.top ${C_B}${fmt_bytes $(stat -c %s scripts/topol.top 2>/dev/null || echo 0)}${C_0}${atoms:+ · ${C_B}${atoms}${C_0} atoms}"
    line "  ${C_B}02 equil${C_0}     $(icon $equil_done $stage equil) ${C_D}npt2.gro ${C_B}${fmt_bytes $(stat -c %s scripts/npt2.gro 2>/dev/null || echo 0)}${C_0}"
    line "  ${C_B}03 prod${C_0}      $(icon $prod_done $stage prod) ${C_D}target ${TARGET_NS} ns · xtc ${C_B}${fmt_bytes $(stat -c %s scripts/prod.xtc 2>/dev/null || echo 0)}${C_0}"
    line "  ${C_B}04 analysis${C_0}  $(icon $ana_done $stage ana) ${C_D}${n_figs} figure(s)${C_0}"
    sep
    if [ -s logs/run_status.txt ]; then
        sec "TRAIL"
        local tline
        while IFS= read -r tline; do
            line "  ${C_D}${tline}${C_0}"
        done < <(tail -n 3 logs/run_status.txt)
        sep
    fi
    # ── health verdict ──
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
    else
        st="⏳ idle — chain finished or not submitted"; stc="$C_Y"
    fi
    line "  ${stc}${st}${C_0}"
    bot
}

icon() { # $1 done(0/1)  $2 stage  $3 stage-family
    local done=$1 stg=$2 fam=$3
    if [ "$done" = "1" ]; then
        printf '%s✅ done%s' "$C_G" "$C_0"
    elif [ "$fam" = "$stg" ]; then
        printf '%s▶ active%s' "$C_Y" "$C_0"
    elif [ "$fam" = "equil" ] && { [ "$stg" = "em" ] || [ "$stg" = "nvt" ] \
           || [ "$stg" = "npt1" ] || [ "$stg" = "npt2" ]; }; then
        printf '%s▶ active%s' "$C_Y" "$C_0"
    else
        printf '%s○ pending%s' "$C_D" "$C_0"
    fi
}

next_stage() { # $1 current stage -> human label of what follows
    case "$1" in
        em) echo "NVT — 100 ps, V-rescale" ;;
        nvt) echo "NPT1 — 100 ps, restrained" ;;
        npt1) echo "NPT2 — 500 ps, free" ;;
        npt2) echo "PRODUCTION — 1 ns unrestrained NPT" ;;
        prod) echo "ANALYSIS — 7-metric suite + figures" ;;
        *) echo "—" ;;
    esac
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
        echo ""
        sleep "$EVERY"
    done
fi