# Taiwania 3 — Usage-Policy Violations to Avoid

**Why this exists:** NCHC enforces its usage policy with account **suspension** (1 week
per repeat violation) — see the login banner (updated 2025-08-14) and the sources below.
This is the consolidated checklist of what gets people in trouble, mapped to our project's
actual commands. Sources are listed at the bottom with verification tags (see
`docs/REFERENCES.md` legend); the login-banner rules are `[P]` primary (printed by the
system at every login).

---

## 1. Login-node abuse (the #1 cause of enforcement) — `[P]` login banner

**The rule (system text):** the login node is reserved for *editing files, compiling
code, submitting jobs, installing software, and short tests* (a few CPU cores, a few
minutes). **Any intensive work — including pre-processing and post-processing — MUST run
as a batch or interactive (srun) job.** Sessions auto-logout after 15 min of inactivity.

| ❌ Violation | ✅ Our practice |
|---|---|
| Running gmx/mdrun or heavy analysis directly on `lgn*` | All MD stages run inside sbatch jobs (`./run_simulation.sh submit`); analysis runs as its own job (04) |
| Heavy python/pandas loops on the login node | Anything heavy goes in a job script; login node is for editing + `squeue` + small checks only |
| Interactive long sessions | 15-min auto-logout is system-enforced — use sbatch + `squeue`/logs; don't fight it |

## 2. Slurm query hammering (treated as an attack) — `[P]` login banner

**The rule (system text):** query intervals < 30 s sustained for > 5 min, or continuous
queries > 10 min, are treated as a system attack. First violation → stopped + email.
**Repeat violations → account suspended 1 week per occurrence.**

| ❌ Violation | ✅ Our practice |
|---|---|
| `while true; do squeue; sleep 10; done` or a monitor script polling fast | `squeue -u $USER` **manually**, or `watch -n 60` (≥ 60 s interval, only while actively watching) |
| Scripted `scontrol show job` loops | One-off checks only; never in a loop |
| Leaving a `tail -f` monitor on the login node unattended | Fine briefly, but it counts as activity — log out when done |

## 3. Prohibited / non-research use — `[P]` official manual (S1)

**The rule:** no crypto-currency mining, weapons R&D, cyber-attacks, or any use
unrelated to research computation — violation → access **suspended or cancelled**.
Also: do **not** attempt to bypass the mandatory 2FA (Taiwan's Cyber Security
Management Act requires it) — bypass methods carry security risk and are penalized (S3).

Our project (academic MD simulation) is squarely inside policy; the risk here is
only from account-sharing or borrowed credentials — don't.

## 4. Storage hygiene — `[P]` manual + `[W]` system FAQ (S2/S4)

| ❌ Violation | ✅ Our practice |
|---|---|
| Storing important files in `/tmp` on login/transfer nodes — **cleaned periodically without notice** (S4) | Never; everything lives in `$HOME/GROMACS_NA53` (quota 100 GB) or `/work` (1.5 TB) |
| Filling the 100 GB `/home` quota (writes start failing mid-run) | `hfs-quota` before big runs; trajectories are small (~GBs); archive finished runs to `/work` |
| `chmod 777` file sharing | Avoid — use `setfacl`/`setgid` per the FAQ if sharing is ever needed (S2) |

## 5. Allocation etiquette — `[W]` official FAQ (S2) — waste, not suspension

These don't get you suspended but burn your project's allocation and can get jobs
rejected or scattered:

| Trap | Consequence | Our setting (already correct in `profiles/taiwania3_cpu.env`) |
|---|---|---|
| No `--mem` in a job script | SLURM reserves the **entire node memory** for your job (FAQ: ~162 GB usable/node) → blocks co-scheduling, other users queue behind you | `--mem=8G/32G` per stage |
| Asking for cores without `--ntasks-per-node`/`--nodes` | Job scattered across nodes on leftover cores → terrible MD performance | `--nodes=1 --ntasks=1 --cpus-per-task=N` |
| `--time` above the partition limit | Job never runs: reason `PartitionTimeLimit` | ct56 cap is 4 days; our 03 job asks 95:00:00 |
| Not reading pending-reason codes | Confusion + resubmit storms | `squeue` shows e.g. `Dependency`/`Resources`/`QOSMaxJobsPerUserLimit` — check the reason before resubmitting (S2 has the full legend) |
| Jobs killed by walltime without checkpoints | Whole trajectory lost | mdrun checkpoints every 15 min (`prod.cpt`); `RESTART=1` continues |

**One more from the FAQ worth knowing (S2):** if your job is interrupted by the system
(hardware/filesystem) it is *auto-requeued* (default). Our mdrun checkpointing makes
requeue safe — nothing to do. If a job is ever preempted by a higher-priority reserved
queue, `sacct -o JobID,State` shows `PREEMPTED` — with checkpoints, that costs nothing.

---

## Sources (verified 2026-09-04)

| Tag | Source | What it gave us |
|---|---|---|
| `[P]` | Login banner text, Taiwania 3 (printed 2025-08-14; captured in SESSION transcripts 2026-08-31) | §1 login-node rule, §2 query limits, enforcement ladder |
| `[W]` S1 | Taiwan 杉三號 official manual — https://man.twcc.ai/@twnia3/rJM5qk3Aw | §3 prohibited uses; filesystem layout; hardware facts |
| `[W]` S2 | Taiwania 3 official FAQ — https://iservice.nchc.org.tw/nchc_service/nchc_service_qa.php?target=118 | §5 memory/co-scheduling, job reason codes, requeue/preemption, sharing |
| `[W]` S3 | "如何連線到國網中心使用計算資源" — https://hackmd.io/@acyang/rJTFDZpB0 | 2FA-bypass warning (snippet-level: seen in search, headline rule quoted) |
| `[W]` S4 | NCHC system/general FAQ — https://iservice.nchc.org.tw/nchc_service/nchc_service_qa.php?target=129 | `/tmp` periodic cleanup (snippet-level) |
