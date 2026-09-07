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
#   ./run_simulation.sh archive [--run-id ID] [--yes]  # preserve finished run BEFORE the next one
#   ./run_simulation.sh runs                             # run registry (RUN_ID, requested vs VERIFIED ns)
#   ./run_simulation.sh extend [--profile NAME] [--to N] [--submit]  # continue finished run from checkpoint
#   ./run_simulation.sh status [--profile NAME] [--local]   # snapshot incl. health report (H1-H4)
#   ./run_simulation.sh monitor [--profile NAME] [--once]    # LIVE dashboard (job/stage/T-P/ns-day/ETA, polls every 30 s; --once = snapshot)
#   (status & monitor run scripts/health_report.sh — doctor-style ✅/⚠️/❌ —
#    locally AND over SSH, so cluster jobs report health the same way)
#
# RUN IDENTITY (post-15ns-pilot): every chain registers a RUN_ID in
# logs/run_registry.tsv (scripts/run_state.sh). Requested ns is recorded
# at submit; the VERIFIED ns is parsed from prod.log once production ends.
# A new chain is REFUSED while un-archived run data sits in scripts/ — run
# `./run_simulation.sh archive` to preserve it. This kills the flat-workspace
# overwrite bug and the "100 ns report on a 15 ns run" naming bug.
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

# shellcheck source=scripts/run_state.sh
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/run_state.sh"   # registry + verified-ns helpers
STAGES_SBATCH=(01_prep 02_equil 03_prod 04_analysis)

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

# ─── Run-registry plumbing (post-15ns-pilot) ───────────────
# Active run id, set by cmd_start/cmd_submit. Persisted to a side file so
# status/monitor/archive can find it without re-parsing.
ACTIVE_RUN_FILE="$REPO_ROOT/logs/.active_run_id"
active_run() { [ -f "$ACTIVE_RUN_FILE" ] && cat "$ACTIVE_RUN_FILE" || echo ""; }
set_active_run() { mkdir -p "$REPO_ROOT/logs"; echo "$1" > "$ACTIVE_RUN_FILE"; }

# unarchived run data present in the flat stage workspace? (exit 0 = yes)
unarchived_prod_data() {
    ls scripts/prod.xtc scripts/prod.edr scripts/prod.cpt 2>/dev/null | grep -q .
}

# registry has a row for RUN_ID already archived?
row_archived() { run_state_is_archived "${1:-}" 2>/dev/null; }

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

    # Fresh full runs must not clobber a preserved-but-unarchived previous run
    # (INCIDENT 2026-09-06: the 15 ns run was almost lost to the flat workspace).
    # Partial stage runs (prep/equil/prod/analysis alone) are RESUMES of the
    # current run and are allowed — only a full fresh chain needs the guard.
    if [ "$stage" = "all" ] && unarchived_prod_data; then
        local cur; cur=$(active_run)
        if [ -z "$cur" ] || ! row_archived "$cur"; then
            echo "❌ scripts/ still holds un-archived run data (prod.*)."
            echo "   A fresh run would silently overwrite it. Preserve it first:"
            echo "     ./run_simulation.sh archive   # move prod.* + analysis into archive/<RUN_ID>"
            echo "   or extend it instead of re-running:"
            echo "     ./run_simulation.sh extend --profile $PROFILE_NAME_CUR --to N"
            exit 1
        fi
    fi

    # register this chain in the run registry (RUN_ID = YYYYMMDD-rN). Partial
    # stage resumes (--stage prod etc.) REUSE the active run if one exists — a
    # resume is not a new run and must not spawn registry rows.
    local RUN_ID cur
    RUN_ID=""
    if [ "$stage" != "all" ]; then
        cur=$(active_run)
        [ -n "$cur" ] && ! row_archived "$cur" && RUN_ID="$cur"
    fi
    if [ -z "$RUN_ID" ]; then
        RUN_ID=$(run_state_new "$PROFILE_NAME_CUR" "$([ "$stage" = all ] && echo fresh || echo partial)" "${ns:-$PROD_NS}")
    fi
    set_active_run "$RUN_ID"
    echo "== run $RUN_ID | profile=$PROFILE_NAME_CUR stage=$stage ns=${ns:-$PROD_NS} pdb=$(basename "$PDB") =="
    log_status "run=$RUN_ID start profile=$PROFILE_NAME_CUR stage=$stage ns=${ns:-$PROD_NS} pdb=$(basename "$PDB")"

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

    # Full interactive chain finished → mark verified ns + finished in the registry
    # (parsed from the real prod.log — never trust the requested value).
    if [ "$stage" = "all" ] && [ -f scripts/prod.log ]; then
        local vns rns; read -r vns rns <<< "$(ns_from_log "$REPO_ROOT/scripts/prod.log")"
        run_state_update "$RUN_ID" STATE=finished NS_VER="$vns" NS_REACH="$rns" FINISHED="$(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "== run $RUN_ID finished — VERIFIED ${vns} ns reached ${rns} ns (prod.log) =="
        echo "   Preserve it before the next run:  ./run_simulation.sh archive"
    fi
    echo "== start finished — status: tail logs/run_status.txt =="
}

# ─── Subcommand: submit (SLURM chain on HPC) ───────────────
# Generates slurm/jobs/*_<profile>.sbatch from the verified templates, patching
# partition/account/time/cpus/mem (+ optional gres) and swapping the environment
# block for the profile's ENV_SETUP, then submits 01→02→03→04 with afterok deps.
generate_jobs() { # $1 = profile, $2 = ns, $3 = RUN_ID (optional; embedded as env for stage hooks)
    local prof="$1" ns_def="${2:-100}" run_id="${3:-}"
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
        awk -v env="$ENV_SETUP" -v rid="$run_id" '
            /^# >>> NA53_ENV_SETUP >>>/ { print; if (rid != "") printf "export NA53_RUN_ID=%s\n", rid; printf "%s\n", env; inblock=1; next }
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
        if [ "$base" = "03_prod" ]; then
            # ALWAYS pin the requested ns into the generated 03 job, whatever the
            # template default says. INCIDENT 2026-09-06: the override was guarded
            # by `[ "$ns_def" != "100" ]`, so when a drifted template default (15)
            # was present, requesting 100 skipped the sed and the run silently
            # produced 15 ns while every report said 100 ns.
            _pin_ns_length "$out" "$ns_def"
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

# _pin_ns_length <sbatch-file> <ns_value> — rewrite NS_LENGTH=${1:-$ns} to use
# the requested ns, verified twice (sed + grep). INCIDENT 2026-09-06 fix:
# the old sed failed when called deep inside generate_jobs because the shell
# positional escapes interact badly with "${1:-...}" inside double-quoted sed.
_pin_ns_length() {
    local out="$1" ns_def="$2"
    # Rewrite the template's NS_LENGTH default to the requested ns, whatever
    # number the template currently carries (INCIDENT 2026-09-06: drift from
    # 100 to 15 sailed through when the pin was skipped).
    #
    # Template line:  NS_LENGTH="${1:-15}"
    # Match the whole line and rewrite. Use awk with comma as FS (never in
    # this line) to avoid all double-quote escaping: split on ",", reassemble.
    awk -F'"' -v ns="$ns_def" '
        /^NS_LENGTH=/ {
            # $1 = NS_LENGTH=   $2 = ${1:-15}   $3 = (empty, trailing ")
            # Rebuild with new default inside the quotes
            print $1 "\"" "${1:-" ns "}" "\""
            next
        }
        { print }
    ' "$out" > "$out.tmp" && mv "$out.tmp" "$out"

    # Verify the pin is present.
    if ! grep -qF "NS_LENGTH=\"\${1:-${ns_def}}\"" "$out"; then
        echo "❌ generate_jobs: NS_LENGTH pin failed in $out" >&2
        echo "   wanted: NS_LENGTH=\"\${1:-${ns_def}}\"" >&2
        echo "   current line:" >&2
        grep -n 'NS_LENGTH' "$out" >&2 || true
        return 1
    fi
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

    # Guard: never let a fresh chain overwrite an un-archived finished run.
    if unarchived_prod_data; then
        local cur; cur=$(active_run)
        if [ -z "$cur" ] || ! row_archived "$cur"; then
            echo "❌ scripts/ still holds un-archived run data (prod.*)."
            echo "   A fresh chain would silently overwrite the previous run."
            echo "   Preserve it first:"
            echo "     ./run_simulation.sh archive   # → archive/<RUN_ID>__<verified>ns/"
            echo "   Or continue it instead:"
            echo "     ./run_simulation.sh extend --profile $prof --to N [--submit]"
            exit 1
        fi
    fi

    echo "== submit | profile=$prof partition=$PARTITION gres='${GRES:-none}' ns=${ns:-$PROD_NS} =="

    # register this chain (fresh always gets a new RUN_ID) — BEFORE generating so
    # the RUN_ID is embedded into the jobs for the end-of-chain registry hook
    local RUN_ID=""
    if [ "$dry" != "1" ]; then
        RUN_ID=$(run_state_new "$prof" fresh "${ns:-$PROD_NS}")
        set_active_run "$RUN_ID"
        echo "✔ run $RUN_ID registered"
    fi
    echo "Generating jobs from verified templates → $JOBS_DIR/"
    generate_jobs "$prof" "${ns:-$PROD_NS}" "$RUN_ID"

    if [ "$dry" = "1" ]; then
        echo ""
        echo "── dry-run: would submit (with afterok dependencies, from slurm/) ──"
        local prev=""
        for base in "${STAGES_SBATCH[@]}"; do
            echo "  sbatch --parsable${prev:+ --dependency=afterok:$prev} jobs/${base}_${prof}.sbatch"
            prev="<jobid>"
        done
        echo "✅ dry-run done — nothing submitted."
        return
    fi

    log_status "submit run=$RUN_ID profile=$prof partition=$PARTITION gres='${GRES:-none}' ns=${ns:-$PROD_NS}"
    # Submit FROM slurm/ (so SLURM_SUBMIT_DIR=slurm): the sbatch templates resolve
    # `--output=../logs/` and `cd ${SLURM_SUBMIT_DIR}/../scripts` against the
    # submission cwd. INCIDENT 2026-09-04: submitting from the repo root sent job
    # logs to ~/logs/ (the repo's parent) and could cd jobs into ~/scripts.
    local prev="" jid jobids=""
    (
        cd slurm
        for base in "${STAGES_SBATCH[@]}"; do
            local job="jobs/${base}_${prof}.sbatch"
            if [ -n "$prev" ]; then
                jid=$(sbatch --parsable --dependency=afterok:"$prev" "$job")
            else
                jid=$(sbatch --parsable "$job")
            fi
            echo "✔ ${base}: job $jid"
            log_status "job ${base} id=$jid run=$RUN_ID"
            jobids="${jobids:+$jobids,}${base}=$jid"
            prev="$jid"
        done
        # registry write must happen INSIDE this subshell: jobids accumulated here
        run_state_update "$RUN_ID" STATE=submitted JOBS="$jobids"
    )
    echo ""
    echo "Chain submitted (run $RUN_ID). Watch:  ./run_simulation.sh monitor --profile $prof"
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
    # Remote only from a NON-cluster machine: when squeue exists we ARE on the
    # cluster (e.g. T3 login node lgn301), and SSH-ing back to twnia3 from
    # itself would prompt for a second OTP and hang. Run local instead.
    if [ "$force_local" = "0" ] && remote_dest >/dev/null 2>&1 \
       && [ "$(hostname)" != "${SSH_HOST}" ] && [ "${SSH_HOST}" != "localhost" ] \
       && ! command -v squeue >/dev/null 2>&1; then
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
    # Same guard as cmd_status: on the cluster itself (squeue present) run
    # locally — SSH-ing back to $SSH_HOST from a login node would 2FA-hang.
    if [ "${SSH_HOST:-}" != "" ] && [ "$(hostname)" != "$SSH_HOST" ] \
       && ! command -v squeue >/dev/null 2>&1; then
        echo "Monitoring remote $SSH_HOST — Ctrl-C to stop."
        echo "NOTE: Taiwania 3 requires 2FA — you will be asked for an OTP."
        local dest; dest=$(remote_dest); local rcd; rcd=$(remote_cd)
        if [ "$once" = "1" ]; then
            # snapshot: health report + md log tail, then exit
            # shellcheck disable=SC2029
            ssh -t "$dest" "${rcd}; bash scripts/health_report.sh --profile $PROFILE_NAME_CUR --quiet-integrity 2>&1 || true; f=\$(ls -t logs/mdrun_*.log 2>/dev/null | head -1); [ -n \"\$f\" ] && tail -n 25 \"\$f\" || true"
        else
            # one SSH session runs the polling dashboard ON the cluster —
            # pure bash, zero deps: the loop re-reads files + squeue locally,
            # no per-poll 2FA prompts.
            # shellcheck disable=SC2029
            ssh -t "$dest" "${rcd}; bash scripts/live_dashboard.sh --profile $PROFILE_NAME_CUR --target-ns ${PROD_NS:-100} --every ${MONITOR_EVERY:-30}"
        fi
    else
        echo "Monitoring local run — Ctrl-C to stop."
        bash scripts/health_report.sh --profile "$PROFILE_NAME_CUR" --quiet-integrity || true
        echo ""
        if [ "$once" = "1" ]; then
            local f; f=$(ls -t logs/mdrun_*.log 2>/dev/null | head -1 || true)
            [ -n "$f" ] && tail -n 20 "$f" || echo "(no md log yet — run ./run_simulation.sh start)"
            return
        fi
        # live dashboard: one lightweight pure-bash viewer (no python deps —
        # runs anywhere, cheap polls: squeue + log sidecar reads).
        bash scripts/live_dashboard.sh --profile "$PROFILE_NAME_CUR" \
            --target-ns "${PROD_NS:-100}" --every "${MONITOR_EVERY:-30}"
    fi
}

# ─── Subcommand: runs (registry view) ─────────────────────
cmd_runs() {
    load_profile "${1:-}"
    echo "── Run registry ($REPO_ROOT/logs/run_registry.tsv) ──"
    run_state_show
    echo ""
    echo "Active run: $(active_run || echo '<none>')"
    if unarchived_prod_data; then
        echo "⚠️  Un-archived run data still in scripts/ — run:  ./run_simulation.sh archive"
    fi
}

# ─── Subcommand: archive (preserve a finished run) ─────────
# Moves run artifacts out of the flat scripts/ workspace into
# archive/<RUN_ID>__<verified>ns/ so the NEXT run cannot overwrite them
# (INCIDENT 2026-09-06: the 15 ns pilot was nearly lost this way).
# Archive dir is named from the VERIFIED ns, never the requested one.
cmd_archive() {
    local run_id="" yes=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --run-id) run_id="$2"; shift 2 ;;
            --yes|-y) yes=1; shift ;;
            *) shift ;;
        esac
    done
    [ -z "$run_id" ] && run_id=$(active_run)
    if [ -z "$run_id" ]; then
        echo "❌ no RUN_ID known. Use --run-id, or register one via start/submit first."
        echo "   (registry: ./run_simulation.sh runs)"
        exit 1
    fi

    # Only archive what actually exists — nothing to do is not an error, but
    # an un-finished run (no Finished mdrun) is worth a loud warning.
    if ! unarchived_prod_data; then
        echo "⚠️  No un-archived prod.* artifacts in scripts/ — nothing to archive."
        echo "   (run $run_id registry state: $(awk -F'\t' -v id="$run_id" '$1==id{print $8}' logs/run_registry.tsv 2>/dev/null || echo '?'))"
        run_state_update "$run_id" STATE=archived 2>/dev/null || true
        exit 0
    fi

    # verified length from the REAL prod.log (fall back to the requested ns
    # only if no log exists yet, and say so)
    local vns rns vtag
    read -r vns rns <<< "$(ns_from_log "$REPO_ROOT/scripts/prod.log" 2>/dev/null || echo "0 0")"
    if awk -v v="$vns" 'BEGIN{exit !(v>0)}'; then
        vtag="${vns}ns"
    else
        vns=$(awk -F'\t' -v id="$run_id" '$1==id{print $4}' logs/run_registry.tsv 2>/dev/null || echo "?")
        vtag="${vns}ns_UNVERIFIED"
        echo "⚠️  No finished prod.log — archiving with REQUESTED length tag ${vtag}. Verify later!"
    fi

    local dest="$REPO_ROOT/archive/${run_id}__${vtag}"
    if [ -d "$dest" ]; then
        echo "❌ archive dir already exists: $dest"
        echo "   Refusing to overwrite. Move/rename it first."
        exit 1
    fi
    mkdir -p "$dest"

    echo "── Archiving run $run_id (VERIFIED ${vns} ns, reached ${rns} ns) ──"
    echo "  → $dest"

    # move the stage workspace artifacts (mv = frees scratch for the next run)
    # NB layout: stage scripts run from scripts/ but write their analysis xvg
    # to the REPO-ROOT analysis/ (04 uses ANALYSIS_DIR="../analysis") and the
    # figures to root results/ — both are gitignored, regeneratable outputs
    # that must travel with the run into the archive.
    local moved=0
    for pat in 'em.*' 'nvt.*' 'npt1.*' 'npt2.*' 'prod.*' 'system_*.gro' '*_processed.gro' \
               '*_boxed.gro' '*_solvated.gro' '*_ionized.gro' 'topol.top' 'posre_*.itp' \
               'index.ndx' 'average.pdb' 'mdout.mdp' 'prod_mdp_temp.mdp'; do
        for f in scripts/$pat; do
            [ -f "$f" ] || continue
            mv "$f" "$dest/" && moved=$((moved + 1))
        done
    done

    # analysis/ + results/ (repo root — where 04/05 actually write)
    for d in analysis results; do
        if [ -d "$REPO_ROOT/$d" ] && [ -n "$(ls -A "$REPO_ROOT/$d" 2>/dev/null)" ]; then
            mv "$REPO_ROOT/$d" "$dest/$d" 2>/dev/null || { cp -r "$REPO_ROOT/$d" "$dest/$d"; rm -rf "$REPO_ROOT/$d"; }
        fi
    done

    # provenance manifest
    local manifest="$dest/ARCHIVE_MANIFEST.txt"
    {
        echo "NA53 RUN ARCHIVE"
        echo "==============="
        echo "RUN_ID:        $run_id"
        echo "ARCHIVED:      $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "VERIFIED ns:   $vns   (from prod.log nsteps ÷ steps/ns)"
        echo "REACHED ns:    $rns   (last Step/Time row in prod.log)"
        echo "REQUESTED ns:  $(awk -F'\t' -v id="$run_id" '$1==id{print $4}' logs/run_registry.tsv 2>/dev/null || echo '?')   (registry NS_REQ — may differ from VERIFIED!)"
        echo "PROFILE:       $(awk -F'\t' -v id="$run_id" '$1==id{print $2}' logs/run_registry.tsv 2>/dev/null || echo '?') "
        echo "JOBS:          $(awk -F'\t' -v id="$run_id" '$1==id{print $7}' logs/run_registry.tsv 2>/dev/null || echo '?') "
        echo "FILES:         $moved moved from scripts/ + analysis/ + results/ trees"
        echo ""
        echo "RECIPE: rename this dir to anything readable; the __<verified>ns suffix"
        echo "        is the ACTUAL length, which is what every report must cite."
    } > "$manifest"

    run_state_update "$run_id" STATE=archived ARCHIVE="${dest#$REPO_ROOT/}" FINISHED="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    log_status "archive run=$run_id → ${dest#$REPO_ROOT/} verified=${vns}ns"
    echo "✅ Archived. Registry updated. Next run can start safely."
    echo "   Tip: figures/large analysis may also be committed to docs/figures/ per-report."
}

# ─── Subcommand: extend (continue a finished run from checkpoint) ──
# Extends the CURRENT run's trajectory (e.g. 15 ns → 30 ns) by converting
# the existing .tpr to a longer end-time and continuing mdrun from prod.cpt
# (gmx convert-tpr -until N + mdrun -cpi). No re-equilibration — the new
# segment appends to the same prod.xtc/.edr, so nothing from the previous
# run is touched or lost.
#   ./run_simulation.sh extend --profile P --to 30            # local foreground
#   ./run_simulation.sh extend --profile P --to 30 --submit   # SLURM job
cmd_extend() {
    local flag_name="" to="" submit=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --profile) flag_name="$2"; shift 2 ;;
            --to) to="$2"; shift 2 ;;
            --submit) submit=1; shift ;;
            *) shift ;;
        esac
    done
    load_profile "$flag_name"
    local run_id; run_id=$(active_run)
    if [ -z "$run_id" ]; then
        echo "❌ no active run. Register one first:"
        echo "     ./run_simulation.sh start --profile $PROFILE_NAME_CUR --ns 15 --stage prod"
        exit 1
    fi
    [ -f scripts/prod.tpr ] || { echo "❌ scripts/prod.tpr missing — nothing to extend"; exit 1; }
    [ -f scripts/prod.cpt ] || { echo "❌ scripts/prod.cpt missing — need a checkpoint to continue from"; exit 1; }

    # current VERIFIED length
    local vns rns
    read -r vns rns <<< "$(ns_from_log "$REPO_ROOT/scripts/prod.log" 2>/dev/null || echo "0 0")"
    local target="${to:-0}"
    if ! awk -v t="$target" -v v="$vns" 'BEGIN{exit !(t>v && t<=10000)}'; then
        echo "❌ --to must exceed the current VERIFIED length ($vns ns) and be sane (≤10000 ns)."
        exit 1
    fi
    local target_steps; target_steps=$((target * 500000))
    local target_ps;  target_ps=$((target * 1000))

    echo "== extend | run=$run_id profile=$PROFILE_NAME_CUR ${vns}ns → ${target}ns (checkpoint continuation) =="
    echo "  current verified: ${vns} ns (prod.log) · reached ${rns} ns"
    echo "  new end:         ${target_ps} ps = ${target_steps} steps"
    echo "  mechanism: gmx convert-tpr -until $target_ps → mdrun -cpi prod.cpt (appends; no re-equilibration)"

    if [ "$submit" = "1" ]; then
        # No SLURM submit path for extend yet — 03 template runs prod fresh.
        echo "❌ --submit not implemented for extend in this version."
        echo "   Run it as an interactive foreground job instead (remove --submit)."
        echo "   Alternatively, on the cluster: sbatch a short interactive node:"
        echo "     srun -p ${PARTITION:-ct56} -A ${ACCOUNT:-<acct>} --cpus-per-task=${CPUS_03:-56} --time=95:00:00 --pty bash"
        echo "     ./run_simulation.sh extend --profile $PROFILE_NAME_CUR --to $target"
        exit 2
    fi

    need_gmx
    mkdir -p "$REPO_ROOT/logs"
    ( cd scripts && \
        gmx convert-tpr -s prod.tpr -until "$target_ps" -o prod.tpr.new \
            > "$REPO_ROOT/logs/convert_tpr_extend.log" 2>&1 ) \
        || { echo "❌ convert-tpr failed — see $REPO_ROOT/logs/convert_tpr_extend.log"; exit 1; }
    ( cd scripts && mv prod.tpr prod.tpr.pre_extend && mv prod.tpr.new prod.tpr )

    log_status "extend run=$run_id ${vns}ns→${target}ns target_steps=$target_steps"
    echo "  ✓ prod.tpr extended to ${target} ns (original saved as prod.tpr.pre_extend)"
    echo "  ▶ Continuing mdrun from prod.cpt in the FOREGROUND — do not interrupt."

    # Continue: -cpi reads prod.cpt, -s prod.tpr (now longer); mdrun appends.
    # ntomp from the profile's CPU count, or leave auto if unset.
    local ntomp="${CPUS_03:-4}"
    ( cd scripts && gmx mdrun -s prod.tpr -deffnm prod -cpi prod.cpt \
            -cpo prod -cpt 900 -ntomp "$ntomp" \
            > "$REPO_ROOT/logs/mdrun_prod_extend.log" 2>&1 ) \
        || { echo "❌ mdrun (extend) failed — see $REPO_ROOT/logs/mdrun_prod_extend.log"; echo "   Restore: mv scripts/prod.tpr.pre_extend scripts/prod.tpr"; exit 1; }

    # re-run analysis so xvg figures cover the FULL extended trajectory
    echo "  ✓ Production extended to ${target} ns. Re-running analysis on the full trajectory..."
    ( cd scripts && bash 04_analysis.sh prod 0 && python3 05_visualization.py ../analysis ) \
        || echo "  ⚠️  re-analysis had issues — check scripts/analysis logs"

    read -r vns rns <<< "$(ns_from_log "$REPO_ROOT/scripts/prod.log" 2>/dev/null || echo "0 0")"
    run_state_update "$run_id" NS_VER="$vns" NS_REACH="$rns" STATE=finished
    echo "── extend done — run $run_id now VERIFIED ${vns} ns ──"
    echo "   Preserve: ./run_simulation.sh archive"
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
    archive)  shift; cmd_archive "$@" ;;
    runs)     shift; cmd_runs "$@" ;;
    extend)   shift; cmd_extend "$@" ;;
    status)   shift; cmd_status "$@" ;;
    monitor)  shift; cmd_monitor "$@" ;;
    -h|--help|help|usage) usage ;;
    *) usage; exit 2 ;;
esac
