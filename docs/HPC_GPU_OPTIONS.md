# HPC GPU Options for GROMACS_NA53 — Platform Analysis & Recommendation

**Date:** 2026-09-04 · **Status:** decision support (verify live before committing hours)
**Question:** which GPU compute resource should the NA53 100–500 ns production run use,
given the project has funding?

---

## 1. TL;DR recommendation

1. **Primary — Taiwania 3 GPU quota/rental via NCHC iService.** You already have a live
   T3 account and project (`u5662994` / `mst115368`, Slurm). The GPU partitions on your
   cluster (`ngs1gpu*` Tesla, `gpu-amd` A100) exist but are not granted to generic
   projects — get NCHC to add GPU access/rental to your project. Same login, same Slurm,
   same repo profile — **shortest path to production.**
2. **Fallback — 台智雲 TWAI Taiwania-2 (commercial).** V100 32 GB GPU nodes under Slurm,
   pay-per-use. Proven GROMACS GPU module/container path documented by NCHC. Good when
   T3 GPU allocation is slow or quota is insufficient.
3. **Avoid — TWCC (Taiwan AI Cloud).** Official NCHC announcement: service **shut down
   2026-08-31**. Already offline.
4. **Local GTX 1650 Ti (CachyOS)** stays useful for development, 1–20 ns trial runs, and
   benchmarking new .mdp changes while cluster access settles.

> ⚠️ GPU *models, counts, and fee schedules* change; the decision above is from public
> evidence gathered 2026-09-04. Before spending allocation/core-hours, run the on-node
> checklist in §5 and paste results back to lock the final `profiles/*.env`.

---

## 2. Evidence (public sources, opened 2026-09-04)

| # | Claim | Source | Confidence |
|---|-------|--------|------------|
| E1 | **TWCC (Taiwan AI Cloud) officially offline 2026-08-31** — "TWCC 台灣AI雲服務即將在2026年8月31日正式熄燈下線"; NCHC directs users to newer AI/HPC/cloud services | NCHC official Facebook post (posted ~Aug 2026) | High (official NCHC announcement) |
| E2 | Taiwania-2 hardware: 2,016× NVIDIA Tesla V100 32 GB, ~9 PFLOPS; commercial operation transferred to 台智雲 (TWAI) after the NCHC program budget ended | NCHC supercomputer page; 知勢 2022 report | High |
| E3 | TWAI (台智雲) still offers Taiwania-2 **Slurm GPU HPC tasks** (interactive/queue, GPU allocation via Slurm) as a commercial service | docs.twcloud.ai TWAI HPC job guide | High (vendor docs) |
| E4 | NCHC iService sells/allocates **GPU rental packages** (e.g. "租用8顆GPU; 或以200天為期, 租用160顆GPU") spanning T3-generation resources | iservice.nchc.org.tw service Q&A | Medium (Q&A text; exact terms need current quote) |
| E5 | Taiwania-3 has dedicated GPU-capable partitions on your cluster: `ngs1gpu/ngs*gput` (Tesla 8/node) and `gpu-amd` (A100 4/node); both were **not usable for your project** on 2026-08-31 (`ngs*` = genomics service; `gpu-amd` nodes all in non-idle state) | your live `sinfo` output 2026-08-31 | High (verified live) |
| E6 | NCHC published a GROMACS quick-usage guide for the Taiwania-2 GPU path: Slurm `--partition=gp1d --gres=gpu:N`, GROMACS 2023.4 native module `/opt/ohpc/pkg/gromacs/2023.4`, NGC Singularity containers 2022.1/2023.2 | hackmd @nchc-software (read in full; recorded in `research/reports/2026-09-03-ngal-na53-gromacs-litreview.md` §5, S5) | High that the doc exists; **verify on the live TWAI/T2 system** because operators changed |

---

## 3. Comparison for THIS workload (75-nt ssDNA, ~45–65k atoms, 100–500 ns, parmbsc1+TIP3P)

| Criterion | T3 GPU (iService) | TWAI T2 (commercial) | Local GTX 1650 Ti |
|---|---|---|---|
| Access now | Pending (request/rental) | Immediate (pay) | Immediate |
| GPU class | A100 (gpu-amd) / Tesla (ngs) | V100 32 GB | GTX 1650 Ti 4 GB |
| Expected MD rate (est.) | ~150–400 ns/day | ~100–250 ns/day | ~257 ns/day (1BNA, 12-bp; smaller NA53 ≈ faster) |
| Cost model | allocation or NCHC rental | pay-per-hour GPU | electricity |
| Same repo profile | `taiwania3_gpu.env` | `taiwania2_twai_gpu.env` | `local_gpu.env` |
| Main risk | grant/rental delay | per-hour cost; operator differences | 4 GB VRAM caps system size; you're away from it |
| Queue | Slurm (ct56-like waits) | Slurm | none |

**Estimate basis:** 1BNA (26k atoms) ran 257 ns/day on a GTX 1650 Ti. NA53 (75-nt) at ~45–65k
atoms is ~1.5× the work → ~170 ns/day on the same GPU; modern data-center GPUs add
another 1–3× with full offload (`-nb gpu -pme gpu -bonded gpu -update gpu`). ⚠️
Estimates — always run the 5,000-step benchmark (`bash scripts/benchmark.sh`) on the
actual node before committing walltime.

---

## 4. What to do next (by you, on the NCHC portal)

1. iService → your project `mst115368` → request **GPU compute (T3, A100/`gpu-amd`)**
   — either free allocation review or the paid rental package in E4. State the use:
   "GROMACS molecular dynamics, aptamer folding, ~45k atoms, ≤4 GPUs/node."
2. If granted: `ssh u5662994@twnia3.nchc.org.tw`, then run the §5 checklist and paste
   results here → I lock `profiles/taiwania3_gpu.env`.
3. If T3 GPU is slow: sign up at TWAI (台智雲) for Taiwania-2 Slurm HPC, request a GPU
   test, run the same §5 checklist → I lock `profiles/taiwania2_twai_gpu.env`.

---

## 5. On-node verification checklist (run on the GPU machine, paste outputs back)

```bash
sinfo -s                                  # partition names + GPU-bearing partitions
sinfo -p <gpu-partition> -o "%P %a %G %C %m"   # real GRES line (GPU model/count)
module avail 2>&1 | grep -iE "gromacs|cuda|openmpi|singularity" || echo "no modules"
which gmx_mpi gmx || true                 # engine location
# GROMACS version + CUDA acceleration check:
gmx --version | grep -iE "GROMACS version|acceleration|CUDA" || true
sacctmgr show assoc user=$USER format=Account,Partition%40   # your partitions
```

Fill in `profiles/<target>.env` with the results (partition/account/engine) — then:

```bash
./run_simulation.sh submit --profile <target>    # clone-and-run GPU chain
./run_simulation.sh monitor                      # watch from your machine
```

---

*Sources opened 2026-09-04; recorded in the spirit of `research/REFERENCES.md` — add the
ones you want to keep citing there.*
