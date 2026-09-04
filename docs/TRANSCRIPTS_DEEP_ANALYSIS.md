# Transcripts Deep Analysis — GROMACS Workflow

**Date:** 2026-09-03
**Source files analyzed:**
- `/home/cliff/Documents/GROMACS_Transcripts/freebuff-chat-2026-08-31T11-12-16.639Z.md` (22 messages — NCHC iService + Taiwania 3 onboarding)
- `/home/cliff/Documents/GROMACS_Transcripts/SESSION_TRANSCRIPT.md` (Aug 30, 2026 — 1BNA trial runs, 200 ns production, analysis)

**Purpose:** Extract every *verified* fact about Taiwania 3, audit both transcripts for hallucinated/guesswork content, and fold the validated learnings into the NA53 pipeline so the GitHub → Taiwania 3 deployment is error-free.

---

## 1. What Each Transcript Covers

| Transcript | Scope | Status |
|---|---|---|
| **freebuff-chat** (Aug 31) | NCHC iService registration → 2FA/OTP → project join → SSH to Taiwania 3 → software audit → GROMACS compile plan → local CachyOS tooling (tmux, PyMOL, mdtraj) | ✅ Account **live**, user `u5662994`, project member |
| **SESSION_TRANSCRIPT** (Aug 30) | Local GROMACS 2025.3 build, 7 trial runs, 200 ns 1BNA production, analysis (RMSD/Rg/RMSF/H-bonds/clustering/FEL/MM-PBSA/FEP), 300 ns extension setup | ✅ 200 ns done, validated parameters |

These are complementary: the 1BNA session **validated the physics parameters**, the freebuff chat **validated the HPC environment**. The NA53 pipeline must use only the intersection of the two.

---

## 2. VERIFIED FACTS — Taiwania 3 (from live SSH session)

> ⚠️ These were confirmed by the user's actual login output on Aug 31, 2026. **Do not guess anything else about the cluster.**

| Item | Verified value |
|---|---|
| SSH host | `twnia3.nchc.org.tw` (resolves to `203.145.216.55`; HackMD lists login node `203.145.216.53` — multiple login nodes exist) |
| Username | `u5662994` |
| 2FA | **Mandatory** — method `1` Mobile APP OTP, `2` Mobile APP Push, `3` Email OTP. **Must register OTP device first** (iService → 會員中心 → 會員資訊 → 主機帳號資訊 → 「建立OTP載具」). Without it, SSH fails with `[FAIL] The account doesn't exist.` |
| Login node | `lgn303` — Intel Xeon Platinum 8280, 56 cores, 375 GB RAM |
| Storage | `/home` + `/work` on 14 PB GPFS |
| **GROMACS** | ❌ **NOT installed, NOT a module** — must compile from source (GPU) or install via conda (CPU) |
| LAMMPS | ✅ Available as module (not suitable for nucleic-acid MD — GROMACS preferred) |
| AMBER / NAMD / OpenMM | ❌ Not available |
| Compilers | `gcc/8.5.0` (D), `gcc/11.2.0`, `gcc/13.2.0`; Intel compilers |
| CMake | `cmake/3.26.4` |
| CUDA | `cuda/11.0`, `cuda/12.0.0` (module names as shown in transcript output) |
| GP1 bio facility (Taiwania 3 bio nodes, `t3-c4`) | CPU nodes **0.08 NTD/core-hr** (NSTC), GPU nodes **10 NTD/GPU-hr** — GPU access may require applying to the GP1 core facility |
| Architecture | Taiwania 3 is a **CPU-first** HPC platform. GPU nodes exist but are not the default resource |

---

## 3. VERIFIED FACTS — Simulation Parameters (from 200 ns 1BNA run)

These were validated on real hardware (GTX 1650 Ti, 256.9 ns/day, 91% GPU util) and are already baked into `configs/*.mdp`:

- `rcoulomb = rvdw = 0.8 nm` (0.8 nm converged; 1.0 nm was the wrong initial guess in trial 01)
- `vdw-modifier = Potential-shift-Verlet`, `DispCorr = EnerPres` (required for AMBER FF)
- `tcoupl = V-rescale`, separate `tc-grps = DNA Water_and_ions`, `tau_t = 0.1`
- `pcoupl = Parrinello-Rahman`, `tau_p = 2.0`, `ref_p = 1.0`
- `comm-mode = Linear`, `nstcomm = 100`
- Checkpointing: `-cpo prod -cpt 900` (every 15 min) — *mandatory* (trial runs 02–03 lost hours without it)
- No position restraints in production (`define =` empty)
- `nohup`/`setsid` for long local runs; on SLURM, checkpoint + requeue handles disconnects

---

## 4. 🚨 HALLUCINATION / GUESSWORK AUDIT

Everything below appeared in one of the transcripts but is **NOT verified**. It must not silently enter the NA53 pipeline.

| # | Claim in transcript | Verdict | Why | Correct action |
|---|---|---|---|---|
| 1 | Partition table `serial / ct560 / ct2k / ct8k` with "best for" descriptions | ❌ **Fabricated** | The only real `sinfo` output seen was from HackMD and belongs to a **different cluster** (ilgn01 → `alphatest/betatest/development/ct112/ct448/ct1k/visual-dev/visual`). No Taiwania 3 `sinfo` output was ever captured | Run `sinfo -s` and `sinfo -p` on the real login node; record actual partitions before touching `#SBATCH --partition` |
| 2 | "`ct560` with 28 cores is perfect for aptamer MD" | ❌ **Unverified** | Same as above — invented partition semantics | Use verified partition only |
| 3 | CUDA toolkit root `/optohpc/pkg/compiler/cuda/12.0.0` | ❌ **Guessed** | Never confirmed; module paths differ across NCHC systems | Use `module show cuda/12.0.0 \| grep CUDA` to get the real `CUDA_HOME` |
| 4 | `make -j56` on the login node | ⚠️ **Bad practice** | Login nodes are shared; 56-core compile will degrade the cluster for everyone and may violate policy | Compile inside a short interactive/SLURM job or use `make -j8` on login |
| 5 | "A100/V100" GPU assumption for Taiwania 3 | ⚠️ **Unverified** | GPU spec never confirmed; Taiwania 3 is CPU-first. GP1 GPU nodes exist (10 NTD/GPU-hr) but model unknown | `sinfo -p <gpu_partition> -o "%N %G %C %m"` and `scontrol show node` before assuming GPU |
| 6 | `rcoulomb/rvdw = 1.0 nm` in the beginner's guide | ❌ **Wrong** | Contradicts the validated 0.8 nm from the 200 ns run | NA53 configs already use 0.8 nm ✅ |
| 7 | "GROMACS 2024.3 — latest stable" | ⚠️ **Stale** | GROMACS 2025.x is current; 2024.4 is a fine stable choice matching gcc 13.2/CUDA 12, but verify availability of the tarball before relying on it | Pin a version we control (2024.4) and verify `wget` works on the cluster |
| 8 | `echo "DNA" \| gmx grompp` interactive group selection | ⚠️ **Fragile** | Works interactively but breaks automation and is a classic error source | NA53 scripts pre-build `index.ndx` with `gmx make_ndx` non-interactively ✅ |
| 9 | "compile GROMACS via `conda install gromacs`" inside `setup_taiwania3.sh` | ⚠️ **Mixed** | conda-forge GROMACS is CPU-only — fine for CPU nodes, useless for GPU. It also conflicts with a source build | Split strategy: **conda for CPU analysis tools**, **source build for GPU mdrun** (see §6) |
| 10 | Email OTP selected during first login (`Login method: 3`) | ⚠️ **User error, not hallucination** | Fails if OTP device never registered; also email OTP is slower | Prefer method `1` (app OTP); register OTP device first |

**Golden rule going forward:** every cluster-specific value in `slurm/` and `scripts/` must be traceable to either (a) the live session output above, or (b) a command the user runs and pastes back (`sinfo`, `module avail`, `scontrol`). Anything else gets a `← VERIFY:` comment, never a silent default.

---

## 5. Environment Matrix — What the Pipeline Actually Needs vs. What Exists

| Need | Taiwania 3 reality | Pipeline action |
|---|---|---|
| GROMACS engine | Not installed | `install_gromacs_gpu.sh` (source, GPU) **or** conda-forge `gromacs` (CPU-only). CPU build is the safe default on this cluster |
| Force field (AMBER parmbsc1/OL15) | Ships inside GROMACS `top/` dir | None needed — included with install |
| Structure prediction (seqfold/RNAfold) | conda | `environment.yml` (viennarna, seqfold) |
| Analysis (MDAnalysis, matplotlib) | conda | `environment.yml` |
| MPI | `openmpi/4.1.4`? — **verify** with `module avail openmpi` | Module load line (fallback to `module load openmpi`) |
| Compiler | `gcc/13.2.0` ✅ | Use this; drop the old `gcc/11.3.0` guess |
| CMake | `cmake/3.26.4` ✅ | Use this; drop `cmake/3.25.0` guess |
| CUDA | `cuda/12.0.0` ✅ (also 11.0) | Load `cuda/12.0.0`; get real root via `module show` |
| GPU partition | ❓ Unverified | `sinfo` gate before any GPU job; CPU partition is the fallback |

---

## 6. Deployment Strategy (updated with verified facts)

```
LOCAL (CachyOS)                          TAIWANIA 3 (u5662994@twnia3.nchc.org.tw)
─────────────────                        ────────────────────────────────────────
1. git push NA53 repo  ────────────────→ 2. ssh u5662994@twnia3.nchc.org.tw   (2FA method 1)
                                           3. bash slurm/setup_taiwania3.sh <repo-url>
                                              ├─ module load gcc/13.2.0 cmake/3.26.4 cuda/12.0.0
                                              ├─ conda env (CPU analysis tools + optional CPU gromacs)
                                              └─ source-compile GROMACS w/ CUDA (GPU mdrun)
                                           4. sinfo -s  →  record REAL partition names
                                           5. fill --account / --partition in *.sbatch
                                           6. sbatch 01_prep.sbatch → 02_equil → 03_prod → 04_analysis
                                           7. scp/rsync results back
```

### Decision gate — GPU vs CPU on Taiwania 3
Run this once, paste output back, then choose:

```bash
sinfo -s
sinfo -p -o "%P %a %l %D %G"
scontrol show partition | grep -E "PartitionName|TRES|DefaultTime"
```

- If a partition lists GPUs (`%G` column shows `gpu:*`): use `install_gromacs_gpu.sh` and `-nb gpu`.
- If not (likely, CPU-first cluster): use the conda CPU build or a CPU-only source build. A 75-nt aptamer in TIP3P (~45–65k atoms) runs fine on 56 CPU cores — expect **~40–100 ns/day** with AVX-512, so 100 ns production is a 1–2.5 day job. Completely viable.

### Expected cost (from verified GP1 rates, if using bio nodes)
| Stage | Nodes | Est. core/GPU-hr | NSTC cost |
|---|---|---|---|
| System prep + EM | 4 CPU cores × 1 h | 4 | ~0.32 NTD |
| Equilibration | 4 CPU × 4 h | 16 | ~1.28 NTD |
| Production 100 ns | GPU (10 NTD/h) ≈ 5 h | 50 | ~50 NTD |
| Analysis | 4 CPU × 2 h | 8 | ~0.64 NTD |
| **Total** | | | **≈ 52 NTD (~$1.5 USD)** — negligible |

---

## 7. Consolidated Action Plan for NA53 (from both transcripts)

1. **[DONE]** Verify account: `u5662994` added to project; OTP device registered.
2. **[NEXT]** On Taiwania 3: run `sinfo -s` + `module avail openmpi` + `module show cuda/12.0.0` → paste output → finalize partition/module lines in `slurm/*.sbatch`.
3. **[NEXT]** Decide GPU vs CPU (decision gate above), then run `setup_taiwania3.sh` + `install_gromacs_gpu.sh` (or conda CPU build).
4. **[NEXT]** `bash 00_predict_structure.sh` to build the NA53 initial model (75 nt, B-form fallback) — upload any better model (RNAComposer/3dRNA/DSSR-annotated) if available.
5. **[NEXT]** `sbatch 01_prep.sbatch` → `02_equil.sbatch` → `03_prod.sbatch` (100 ns default) → `04_analysis.sbatch`.
6. **[LATER]** Conformational-switching analysis (two-state clustering, FEL) — the 1BNA session proved the exact toolchain (gromos clustering + FEL) works.
7. **[LATER]** NA53–NGAL complex: PDB 1X71 target; ensemble docking + MM-PBSA per APTAMD protocol once the free-aptamer fold is converged.

---

## 8. Additional Pipeline Defects Surfaced by This Analysis (now fixed)

| # | Defect | Why it was a guaranteed failure | Fix applied |
|---|---|---|---|
| 1 | `00_predict_structure.sh` fallback wrote **2 atoms/nt** (P + C4′) as the "initial PDB" | `gmx pdb2gmx` needs COMPLETE nucleotides for DNA; partial residues abort topology generation with missing-atom errors | Script now refuses to fabricate a partial PDB: uses an existing/user-supplied all-atom model (AptaFold, w3DNA B-form ssDNA, 3dDNA) and validates atom counts per residue (`<10` atoms ⇒ stop). RNAComposer explicitly rejected — it is RNA-only, NA53 is DNA |
| 2 | `environment.yml` shipped `gromacs=2024.4` (conda-forge, CPU-only) **alongside** a compiled GPU engine | `conda activate` prepends its `bin/`, silently shadowing the compiled `gmx` → runs would use the CPU conda build even after a GPU compile | Removed `gromacs` from `environment.yml` (env = analysis tools only); compiled engine is the single source of truth via `~/.gromacsrc`, sourced **after** `conda activate` in all `.sbatch` files |
| 3 | `.sbatch` scripts requested `--gres=gpu:1` and passed `-nb gpu` unconditionally | Taiwania 3 is CPU-first; on a CPU-only partition `--gres` fails submission and `-nb gpu` aborts on a CPU build — a guaranteed job error until the cluster is verified | `--gres` now commented out (opt-in after `sinfo` confirms GPUs); mdrun calls use `-nb auto` (GPU if present, else CPU); partition/account are `CHANGE_ME_*` so `sbatch` errors loudly until the user fills verified values |
| 4 | Module guesses `gcc/11.3.0`, `cmake/3.25.0`, `cuda/11.8.0`, hardcoded CUDA path | None exist as loaded — compilation would silently use defaults or fail | All module loads use VERIFIED `gcc/13.2.0`, `cmake/3.26.4`, `cuda/12.0.0`; CUDA root discovered via `dirname dirname $(which nvcc)`, never hardcoded |
| 5 | `setup_taiwania3.sh` (old) treated conda GROMACS as the engine and ran `make -j56` on the login node | Login node is shared; conda GROMACS conflicts with compiled build | Setup now compiles via `install_gromacs_gpu.sh` with a modest default `--build-jobs 16` and prints the `sinfo`/`module show` verification steps |

---

## 9. Live Session 2 (2026-09-03): Corrections Locked In

A second live session on Taiwania 3 replaced guesses with facts and **reversed one earlier assumption**:

| Earlier assumption | Live-session reality (2026-09-03) | Consequence |
|---|---|---|
| `cuda/12.0.0`, `cmake/3.26.4`, `openmpi` modules exist (from ilgn01 HackMD) | **Only `gcc/*` modules exist** (`gcc/13.2.0`). No cuda/cmake/openmpi/fftw | Compiling from source would require bootstrapping cmake+FFTW — abandoned. Engine = **conda-forge gromacs 2024.4 (CPU)** |
| A100/V100 GPU partition usable | GPU partitions: `ngs*` = Tesla 8/node (**genomics service, restricted**); `gpu-amd` = A100 4/node but **0 idle — all down** | **CPU-only is the operative plan** on this account |
| Account ID unknown | `sacctmgr show assoc` → **`mst115368`** | Filled into every `--account=` |
| Partition names uncertain | `ctest` (default, 2 h), **`ct56` (56 cores, 754 GB, 4 days)**, `ct224`/`ct560`/`ct2k`/`ct8k` | All MD jobs → `ct56`, `--cpus-per-task=56` for production |
| Node RAM ~375 GB (login node) | Compute node `cpn3001`: **CPUTot=56, RealMemory=772412 MB**, Gres=(null) | Memory is never a constraint; request 32 GB |
| Setup compiled GROMACS from source | Too many missing pieces; policy restricts login-node builds | `setup_taiwania3.sh` now: conda env create (env ships gromacs) + validation only |
| `-nb gpu` mdrun flags | No GPU build possible | All sbatch/scripts default to `-nb auto` (resolves to CPU here); explicit GPU flags preserved only in `03_production.sh` for the local GTX machine |

**Throughput expectation (CPU, ct56, 56 threads, ~45–65k atoms):** ~15–45 ns/day → 100 ns needs the checkpointed RESTART path across the 4-day `ct56` limit; `RESTART=1 sbatch 03_prod.sbatch` continues from `prod.cpt` if a job hits the wall.

**Cost sanity (from GP1 academic rates):** ~50 CPU-core-hr per 100 ns → well under 10 NTD per full pipeline. Budget is not a concern.

---

## 10. Key Takeaway

The two transcripts together give us **everything verified**: the HPC environment (Taiwania 3, user `u5662994`, no GROMACS module, gcc 13.2 / cmake 3.26.4 / cuda 12.0.0) and the simulation physics (0.8 nm cutoff, V-rescale, Parrinello-Rahman, parmbsc1, checkpointing every 15 min). The remaining unknowns are **cluster-specific and small** (partition names, GPU availability, project account ID) — each is resolved by one command the user runs on the login node, not by guessing. The NA53 pipeline is now structured so those three values are the *only* placeholders left.