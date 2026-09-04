# Profiles — one repo, any machine

`./run_simulation.sh` and the SLURM job generator read a **profile** that describes one
compute target (cluster, engine, GPU flags, queue values). Pick a profile with
`--profile <name>` or let the launcher auto-detect by hostname. **Clone once, run
anywhere.**

## The profile files

| Profile | Machine | Status | Notes |
|---|---|---|---|
| `taiwania3_cpu.env` | Taiwania 3, CPU `ct56` | ✅ **VERIFIED live 2026-09-03** (conda GROMACS 2024.4, account `mst115368`) | production default until GPU access lands |
| `taiwania3_gpu.env` | Taiwania 3, GPU partition | ⚠️ template | fill from `docs/HPC_GPU_OPTIONS.md` §5 checklist; engine must be CUDA-enabled |
| `taiwania2_twai_gpu.env` | TWAI (台智雲) Taiwania-2 GPU | ⚠️ template | commercial V100; engine module/container per NCHC guide |
| `local_gpu.env` | your workstation GPU (GTX 1650 Ti / CachyOS) | ✅ ready | dev + trial runs |

## Variable contract (every profile sets these)

```bash
PROFILE_NAME="Human-readable name"
ENV_SETUP='...multi-line bash, run before every gmx call (module/conda/container)...'
MDRUN_GPU_FLAG=""            # "" = CPU/auto  |  "-nb gpu -pme gpu -bonded gpu -update gpu" = full offload
PROD_NS=100                  # default production length (ns)

# ── SLURM (only used by: ./run_simulation.sh submit) ──
PARTITION="ct56"             # real partition name
ACCOUNT="mst115368"          # Slurm account
GRES=""                      # e.g. gpu:ampere:1 — leave "" for CPU
# per-stage: walltime / cores / memory
TIME_01="01:00:00"  CPUS_01=4  MEM_01=8G
TIME_02="04:00:00"  CPUS_02=28 MEM_02=32G
TIME_03="95:00:00"  CPUS_03=56 MEM_03=32G
TIME_04="02:00:00"  CPUS_04=8  MEM_04=16G

# ── Remote monitoring (only used by: ./run_simulation.sh monitor/status) ──
SSH_HOST="" SSH_USER="" REMOTE_DIR=""   # empty = running on this machine
```

Rules:
- `ENV_SETUP` must be **idempotent** and tolerate re-runs (`module purge || true`,
  `conda activate ... || true`-style guards), because it runs at every stage.
- Templates marked ⚠️ contain `CHANGE_ME` values **on purpose** — they are filled from
  the live checklist in `docs/HPC_GPU_OPTIONS.md` §5, never guessed.
- Never commit real credentials; `ACCOUNT`/`PARTITION` are not secrets.

## Auto-detection table (hostname → profile)

| Hostname pattern | Profile |
|---|---|
| `lgn*` (Taiwania 3 login) | `taiwania3_cpu` |
| anything else | error → pass `--profile` explicitly |

Override anytime: `--profile <name>` or env `NA53_PROFILE=<name>`.
Persist a choice on a machine: `./run_simulation.sh profile --set <name>` (writes
`~/.gromacs_na53_profile`).
