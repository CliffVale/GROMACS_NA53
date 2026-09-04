#!/bin/bash
# ============================================================
# run_simulation.sh — GROMACS_NA53 clone-and-run launcher
# ============================================================
# One repo, any machine. Drives the stage pipeline (00 predict → 01 prep →
# 02 equil → 03 prod → 04 analysis) either interactively (workstation) or as a
# chained SLURM submission (HPC), parameterized by a machine profile.
#
# Usage:
#   ./run_simulation.sh profile [--profile NAME] [--set NAME]
#   ./run_simulation.sh env  [--profile NAME]          # print engine-setup snippet
#   ./run_simulation.sh doctor [--profile NAME]        # pre-run health check (static + live gmx probes)
#   ./run_simulation.sh start  [--profile NAME] [--ns N] [--stage all|prep|equil|prod|analysis] [--pdb FILE]
#   ./run_simulation.sh submit [--profile NAME] [--ns N] [--dry-run]
#   ./run_simulation.sh status [--profile NAME] [--local]   # snapshot incl. health report (H1-H4)
#   ./run_simulation.sh monitor [--profile NAME] [--once]    # health report + live md log tail
#   (status & monitor run scripts/health_report.sh — doctor-style ✅/⚠️/❌ —
#    locally AND over SSH, so cluster jobs report health the same way)
#
# Profiles live in profiles/*.env — see profiles/README.md.
# Postmortem + prevention map: docs/INCIDENT_ANALYSIS.md.
# ============================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# Anchored to repo root: cmd_start cd's into scripts/, so a relative path
# would split the log across logs/ and scripts/logs/.
STATUS_FILE="$REPO_ROOT/logs/run_status.txt"
JOBS_DIR="$REPO_ROOT/slurm/jobs"
PROFILE_NAMES=(taiwania3_cpu taiwania3_gpu taiwania2_twai_gpu local_gpu)

# ─── Help ──────────────────────────────────────────────────
usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    echo ""
    echo "Available profiles:"
    for p in "${PROFILE_NAMES[@]}"; do
        printf '  %-22s %s\n' "$p" "$(prof_meta "$p" 2>/dev/null || echo '?')"
    done
}

# ─── Profile plumbing ──────────────────────────────────────
prof_file() { echo "profiles/$1.env"; }
prof_meta() { # PROFILE_NAME of a file without sourcing into this shell
    local v
    v=$(grep -m1 '^PROFILE_NAME=' "profiles/$1.env" | sed 's/^PROFILE_NAME="\?//; s/"\?$//')
    echo "${v:-<template — set values>}"
}
prof_exists() { [ -f "$(prof_file "$1")" ]; }

# resolve profile NAME: flag > env NA53_PROFILE > ~/.gromacs_na53_profile > hostname
resolve_profile() {
    local name="${1:-}"
    if [ -z "$name" ]; then name="${NA53_PROFILE:-}"; fi
    if [ -z "$name" ] && [ -f "$HOME/.gromacs_na53_profile" ]; then
        name="$(cat "$HOME/.gromacs_na53_profile")"
    fi
    if [ -z "$name" ]; then
        case "$(hostname)" in
            lgn*) name="taiwania3_cpu" ;;   # Taiwania 3 login nodes (verified CPU path)
            *)    name="" ;;
        esac
    fi
    if [ -z "$name" ] || ! prof_exists "$name"; then
        echo "❌ Cannot determine a profile for host '$(hostname)'. Use --profile:" >&2
        for p in "${PROFILE_NAMES[@]}"; do echo "  $p" >&2; done
        exit 2
    fi
    echo "$name"
}

# load a profile into the current shell as variables
load_profile() {
    local prof
    prof="$(resolve_profile "${1:-}")"
    # shellcheck disable=SC1090
    source "$(prof_file "$prof")"
    PROFILE_NAME_CUR="$prof"
    export PROFILE_NAME_CUR
}

# execute the engine setup snippet (module/conda/container) before gmx calls
setup_env() {
    if [ -n "${ENV_SETUP:-}" ]; then
        eval "$ENV_SETUP"
    fi
}

# ─── Shared helpers ────────────────────────────────────────
log_status() { mkdir -p "$REPO_ROOT/logs"; echo "$(date -Is) | $*" >> "$STATUS_FILE"; }

need_gmx() {
    setup_env
    if ! command -v gmx >/dev/null 2>&1; then
        echo "❌ gmx not found after profile environment setup."
        echo "   Run './run_simulation.sh env' to see what the profile tried to load." >&2
        exit 1
    fi
    echo "   gmx: $(gmx --version 2>&1 | head -1)"
}

STAGES_SBATCH=(01_prep 02_equil 03_prod 04_analysis)

# ─── Subcommand: profile ───────────────────────────────────
cmd_profile() {
    local set_name="" flag_name=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --profile) flag_name="$2"; shift 2 ;;
            --set)     set_name="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    if [ -n "$set_name" ]; then
        prof_exists "$set_name" || { echo "❌ no such profile: $set_name" >&2; exit 2; }
        echo "$set_name" > "$HOME/.gromacs_na53_profile"
        echo "✅ default profile on this machine → $set_name ($HOME/.gromacs_na53_profile)"
        return
    fi
    local p; p="$(resolve_profile "$flag_name")"
    echo "Profile: $p  →  $(prof_meta "$p")"
    echo "Set as default here:  ./run_simulation.sh profile --set $p"
    echo "Overrides:            --profile NAME | env NA53_PROFILE=NAME"
}

# ─── Subcommand: env ───────────────────────────────────────
cmd_env() {
    local flag_name=""
    while [ $# -gt 0 ]; do case "$1" in --profile) flag_name="$2"; shift 2;; *) shift;; esac; done
    load_profile "$flag_name"
    echo "# Engine setup for profile '$PROFILE_NAME_CUR' (eval in a shell before manual gmx use):"
    printf '%s\n' "$ENV_SETUP"
}

# ─── Subcommand: start (interactive/foreground on THIS machine) ──
# Runs stages in scripts/ (the stage workspace). Every stage script — including
# 03_production.sh — runs mdrun in the FOREGROUND, so each gate passes only on
# real completion.
cmd_start() {
    local flag_name="" ns="" stage="all" pdb_val=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --profile) flag_name="$2"; shift 2 ;;
            --ns) ns="$2"; shift 2 ;;
            --stage) stage="$2"; shift 2 ;;
            --pdb) pdb_val="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    load_profile "$flag_name"
    local PDB="${pdb_val:-$REPO_ROOT/structures/NA53_initial.pdb}"
    PDB="$(readlink -f "$PDB" 2>/dev/null || echo "$PDB")"
    # The input PDB is only needed by predict/prep stages — later-stage resumes don't touch it
    case "$stage" in
        all|predict|prep)
            [ -f "$PDB" ] || { echo "❌ input PDB not found: $PDB (use --pdb FILE or place NA53_initial.pdb)"; exit 1; } ;;
    esac
    echo "== start | profile=$PROFILE_NAME_CUR stage=$stage ns=${ns:-$PROD_NS} pdb=$(basename "$PDB") =="
    log_status "start profile=$PROFILE_NAME_CUR stage=$stage ns=${ns:-$PROD_NS} pdb=$(basename "$PDB")"

    need_gmx
    mkdir -p structures system equilibration production analysis results/figures logs

    cd scripts

    run_stage_predict() {
        if [ "$PDB" != "$REPO_ROOT/structures/NA53_initial.pdb" ]; then
            echo "✔ custom --pdb provided — skipping 00 predict"
            return
        fi
        if [ ! -f "$PDB" ]; then
            echo "── stage: predict (00) ──"
            log_status "stage=predict start"
            bash 00_predict_structure.sh || { echo "❌ 00 exited — place a real PDB at structures/NA53_initial.pdb first"; exit 1; }
            log_status "stage=predict ok"
        else
            echo "✔ structures/NA53_initial.pdb present — skipping 00 predict"
        fi
    }
    run_stage_prep() {
        echo "── stage: prep (01) ──"
        log_status "stage=prep start"
        bash 01_system_prep.sh "$PDB" amber99sb-ildn tip3p
        log_status "stage=prep ok"
    }
    run_stage_equil() {
        local ion
        ion=$(ls *_ionized.gro 2>/dev/null | head -1)
        [ -n "$ion" ] || { echo "❌ no *_ionized.gro — run prep first"; exit 1; }
        echo "── stage: equil (02) ──"
        log_status "stage=equil start"
        bash 02_equilibration.sh "$ion" "$MDRUN_GPU_FLAG"
        log_status "stage=equil ok"
    }
    run_stage_prod() {
        [ -f npt2.gro ] || { echo "❌ npt2.gro missing — run equil first"; exit 1; }
        echo "── stage: prod (03, ${ns:-$PROD_NS} ns) ──"
        log_status "stage=prod start ns=${ns:-$PROD_NS}"
        # 03_production.sh runs mdrun in the foreground — returns only on completion
        bash 03_production.sh "$MDRUN_GPU_FLAG" "${ns:-$PROD_NS}"
        log_status "stage=prod ok"
    }
    run_stage_analysis() {
        [ -f prod.xtc ] || { echo "❌ prod.xtc missing — run prod first"; exit 1; }
        echo "── stage: analysis (04 + viz) ──"
        log_status "stage=analysis start"
        bash 04_analysis.sh prod 0
        python3 05_visualization.py ../analysis
        log_status "stage=analysis ok"
    }

    case "$stage" in
        all)      run_stage_predict; run_stage_prep; run_stage_equil; run_stage_prod; run_stage_analysis ;;
        predict)  run_stage_predict ;;
        prep)     run_stage_prep ;;
        equil)    run_stage_equil ;;
        prod)     run_stage_prod ;;
        analysis) run_stage_analysis ;;
        *) echo "❌ unknown stage: $stage"; exit 2 ;;
    esac
    echo "== start finished — status: tail logs/run_status.txt =="
}

# ─── Subcommand: submit (SLURM chain on HPC) ───────────────
# Generates slurm/jobs/*_<profile>.sbatch from the verified templates, patching
# partition/account/time/cpus/mem (+ optional gres) and swapping the environment
# block for the profile's ENV_SETUP, then submits 01→02→03→04 with afterok deps.
generate_jobs() { # $1 = profile name, $2 = production length in ns (default for the 03 job)
    local prof="$1" ns_def="${2:-100}"
    local jobs=()
    rm -rf "$JOBS_DIR"; mkdir -p "$JOBS_DIR"
    for base in "${STAGES_SBATCH[@]}"; do
        local src="slurm/${base}.sbatch" out="$JOBS_DIR/${base}_${prof}.sbatch"
        local T="${TIME_01}" C="${CPUS_01}" M="${MEM_01}"
        case "$base" in
            01_prep) T="$TIME_01"; C="$CPUS_01"; M="$MEM_01" ;;
            02_equil) T="$TIME_02"; C="$CPUS_02"; M="$MEM_02" ;;
            03_prod) T="$TIME_03"; C="$CPUS_03"; M="$MEM_03" ;;
            04_analysis) T="$TIME_04"; C="$CPUS_04"; M="$MEM_04" ;;
        esac
        awk -v env="$ENV_SETUP" '
            /^# >>> NA53_ENV_SETUP >>>/ { print; printf "%s\n", env; inblock=1; next }
            /^# <<< NA53_ENV_SETUP <<</ { inblock=0; print; next }
            !inblock { print }
        ' "$src" \
        | sed -E \
            -e "s|^#SBATCH --partition=.*|#SBATCH --partition=${PARTITION}|" \
            -e "s|^#SBATCH --account=.*|#SBATCH --account=${ACCOUNT}|" \
            -e "s|^#SBATCH --time=.*|#SBATCH --time=${T}|" \
            -e "s|^#SBATCH --cpus-per-task=.*|#SBATCH --cpus-per-task=${C}|" \
            -e "s|^#SBATCH --mem=.*|#SBATCH --mem=${M}|" \
        > "$out"
        if [ "$base" = "03_prod" ] && [ "$ns_def" != "100" ]; then
            # honor --ns: template's NS_LENGTH default is 100 — override in the generated job
            sed -i "s|NS_LENGTH=\"\${1:-100}\"|NS_LENGTH=\"\${1:-$ns_def}\"|" "$out"
        fi
        if [ -n "${GRES:-}" ]; then
            # one --account= line exists in every template header — append gres after it
            grep -q -- "--gres=" "$out" || sed -i "/^#SBATCH --account=/a #SBATCH --gres=${GRES}" "$out"
        else
            sed -i "/^#SBATCH --gres=/d" "$out"
        fi
        jobs+=("$base:$out")
    done
    for j in "${jobs[@]}"; do echo "${j%%:*} → ${j#*:}"; done
}

cmd_submit() {
    local flag_name="" ns="" dry=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --profile) flag_name="$2"; shift 2 ;;
            --ns) ns="$2"; shift 2 ;;
            --dry-run) dry=1; shift ;;
            *) shift ;;
        esac
    done
    load_profile "$flag_name"
    if [ -z "${PARTITION:-}" ] || [ "$PARTITION" = "CHANGE_ME" ]; then
        echo "❌ Profile '$PROFILE_NAME_CUR' has no verified SLURM values yet."
        echo "   Fill PARTITION/ACCOUNT/GRES from docs/HPC_GPU_OPTIONS.md §5, or use:"
        echo "     ./run_simulation.sh start --profile $PROFILE_NAME_CUR   # interactive instead"
        exit 2
    fi

    local prof="$PROFILE_NAME_CUR"
    echo "== submit | profile=$prof partition=$PARTITION gres='${GRES:-none}' ns=${ns:-$PROD_NS} =="
    echo "Generating jobs from verified templates → $JOBS_DIR/"
    generate_jobs "$prof" "${ns:-$PROD_NS}"

    if [ "$dry" = "1" ]; then
        echo ""
        echo "── dry-run: would submit (with afterok dependencies) ──"
        local prev=""
        for base in "${STAGES_SBATCH[@]}"; do
            echo "  sbatch --parsable${prev:+ --dependency=afterok:$prev} $JOBS_DIR/${base}_${prof}.sbatch"
            prev="<jobid>"
        done
        echo "✅ dry-run done — nothing submitted."
        return
    fi

    log_status "submit profile=$prof partition=$PARTITION gres='${GRES:-none}' ns=${ns:-$PROD_NS}"
    local prev="" jid
    for base in "${STAGES_SBATCH[@]}"; do
        local job="$JOBS_DIR/${base}_${prof}.sbatch"
        if [ -n "$prev" ]; then
            jid=$(sbatch --parsable --dependency=afterok:"$prev" "$job")
        else
            jid=$(sbatch --parsable "$job")
        fi
        echo "✔ ${base}: job $jid"
        log_status "job ${base} id=$jid"
        prev="$jid"
    done
    echo ""
    echo "Chain submitted. Watch:  ./run_simulation.sh monitor --profile $prof"
}

# ─── Subcommand: status / monitor ──────────────────────────
remote_dest() { # prints ssh destination if profile points to a remote machine
    if [ -n "${SSH_HOST:-}" ]; then echo "${SSH_USER:+$SSH_USER@}$SSH_HOST"; fi
}
remote_cd() { # remote working directory (expand $HOME on the REMOTE side)
    if [[ "${REMOTE_DIR:-}" == /* ]]; then echo "cd ${REMOTE_DIR}";
    else echo "cd \${HOME}/${REMOTE_DIR:-GROMACS_NA53}"; fi
}

# remote_snapshot PROFILE — same report shape as the local status path, so the
# cluster reports health with the same vocabulary (scripts/health_report.sh).
remote_snapshot() {
    local dest rcd rprof
    dest=$(remote_dest) || true
    [ -n "$dest" ] || return 1
    rcd=$(remote_cd)
    rprof="${1:-}"
    # shellcheck disable=SC2029
    ssh -o ConnectTimeout=15 "$dest" "
        set -e
        ${rcd}
        echo '── SLURM (me) ──'
        squeue -u \$(whoami) 2>/dev/null || true
        echo '── run status ──'
        tail -n 8 logs/run_status.txt 2>/dev/null || echo '(no run_status.txt yet)'
        echo '── health report (same as local status) ──'
        bash scripts/health_report.sh ${rprof:+--profile $rprof} --quiet-integrity 2>&1 || true
        echo '── latest md log tail ──'
        f=\$(ls -t logs/mdrun_*.log 2>/dev/null | head -1); [ -n \"\$f\" ] && tail -n 12 \"\$f\" || echo '(no md log yet)'
    "
}

cmd_status() {
    local flag_name="" force_local=0
    while [ $# -gt 0 ]; do
        case "$1" in --profile) flag_name="$2"; shift 2;; --local) force_local=1; shift;; *) shift;; esac
    done
    load_profile "$flag_name"
    echo "Profile: $PROFILE_NAME_CUR"
    if [ "$force_local" = "0" ] && remote_dest >/dev/null 2>&1 \
       && [ "$(hostname)" != "${SSH_HOST}" ] && [ "${SSH_HOST}" != "localhost" ]; then
        echo "Machine: remote (${SSH_HOST}) — fetching snapshot (2FA OTP may prompt)…"
        remote_snapshot "$PROFILE_NAME_CUR"
    else
        echo "Machine: local"
        echo "── run status ──"
        [ -f "$STATUS_FILE" ] && tail -n 10 "$STATUS_FILE" || echo "(no run_status.txt yet)"
        echo "── SLURM (me) ──"
        command -v squeue >/dev/null 2>&1 && squeue -u "$USER" 2>/dev/null || echo "(no squeue here)"
        echo "── health report (doctor vocabulary: ✅/⚠️/❌) ──"
        bash scripts/health_report.sh --profile "$PROFILE_NAME_CUR" --quiet-integrity || true
        echo "── latest md log tail ──"
        local f; f=$(ls -t logs/mdrun_*.log 2>/dev/null | head -1 || true)
        [ -n "$f" ] && tail -n 12 "$f" || echo "(no md log yet)"
    fi
}

cmd_monitor() {
    local flag_name="" once=0
    while [ $# -gt 0 ]; do
        case "$1" in --profile) flag_name="$2"; shift 2;; --once) once=1; shift;; *) shift;; esac
    done
    load_profile "$flag_name"
    if [ "${SSH_HOST:-}" != "" ] && [ "$(hostname)" != "$SSH_HOST" ]; then
        echo "Monitoring remote $SSH_HOST — Ctrl-C to stop."
        echo "NOTE: Taiwania 3 requires 2FA — you will be asked for an OTP."
        local dest; dest=$(remote_dest); local rcd; rcd=$(remote_cd)
        local hr="bash scripts/health_report.sh --profile $PROFILE_NAME_CUR --quiet-integrity 2>&1 || true"
        if [ "$once" = "1" ]; then
            # shellcheck disable=SC2029
            ssh -t "$dest" "${rcd}; echo '── health report ──'; ${hr}; echo '── SLURM ──'; squeue -u \$(whoami); f=\$(ls -t logs/mdrun_*.log 2>/dev/null | head -1); echo '── \$f ──'; tail -n 25 \"\$f\" 2>/dev/null || true"
        else
            # shellcheck disable=SC2029
            ssh -t "$dest" "${rcd}; echo '── health report ──'; ${hr}; echo '── SLURM ──'; squeue -u \$(whoami); f=\$(ls -t logs/mdrun_*.log 2>/dev/null | head -1); echo \"── tail -f \\\$f ──\"; tail -f \"\$f\" 2>/dev/null || tail -f logs/*.out"
        fi
    else
        echo "Monitoring local run — Ctrl-C to stop."
        echo "── health report ──"
        bash scripts/health_report.sh --profile "$PROFILE_NAME_CUR" --quiet-integrity || true
        echo "── live md log tail (Ctrl-C to stop) ──"
        local f; f=$(ls -t logs/mdrun_*.log 2>/dev/null | head -1 || true)
        [ -n "$f" ] && tail -n 20 "$f" || echo "(no md log yet — run ./run_simulation.sh start)"
        [ "$once" = "1" ] && return
        [ -n "$f" ] && tail -f "$f"
    fi
}

# ─── Subcommand: doctor (pre-run health check) ─────────────
# Guards the bug classes from docs/INCIDENT_ANALYSIS.md:
#  - static repo integrity (C1..C5) via scripts/check_repo_integrity.sh
#  - LIVE probes of the gmx build the profile selects (V1/V4/V5 flag drift)
#  - group-layout sanity vs a real prepared structure (G1)
cmd_doctor() {
    local flag_name=""
    while [ $# -gt 0 ]; do case "$1" in --profile) flag_name="$2"; shift 2;; *) shift;; esac; done
    load_profile "$flag_name"
    echo "── doctor | profile: $PROFILE_NAME_CUR ──"
    local failed=0

    echo ""
    echo "▶ 1/3  Static repo integrity (scripts/check_repo_integrity.sh)"
    if bash scripts/check_repo_integrity.sh; then
        echo "  ✅ static checks passed"
    else
        echo "  ❌ static checks FAILED — fix before running any stage"
        failed=1
    fi

    echo ""
    echo "▶ 2/3  Live gmx probes on $(command -v gmx >/dev/null 2>&1 && echo 'current PATH' || echo 'PATH after profile ENV_SETUP')"
    setup_env
    hash -r 2>/dev/null || true
    if ! command -v gmx >/dev/null 2>&1; then
        echo "  ❌ gmx not found after profile ENV_SETUP — run './run_simulation.sh env'"
        return 1
    fi
    # Live probes live in the shared script so status/monitor health reporting
    # checks the exact same flags (docs/INCIDENT_ANALYSIS.md class V/G).
    bash scripts/probe_gmx_compat.sh || failed=1

    echo ""
    if [ "$failed" -gt 0 ]; then
        echo "❌ doctor: check(s) FAILED — do not start stages yet"
        echo "   See docs/INCIDENT_ANALYSIS.md (bug classes V/P/S/G/K + fixes)."
        return 1
    fi
    echo "✅ doctor: all checks passed — safe to start/submit."
}

# ─── Dispatch ──────────────────────────────────────────────
cmd="${1:-usage}"
case "$cmd" in
    profile)  shift; cmd_profile "$@" ;;
    env)      shift; cmd_env "$@" ;;
    doctor)   shift; cmd_doctor "$@" ;;
    start)    shift; cmd_start "$@" ;;
    submit)   shift; cmd_submit "$@" ;;
    status)   shift; cmd_status "$@" ;;
    monitor)  shift; cmd_monitor "$@" ;;
    -h|--help|help|usage) usage ;;
    *) usage; exit 2 ;;
esac
