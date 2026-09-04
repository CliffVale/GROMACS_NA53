# CLUSTER_RUNBOOK — Running NA53 on Taiwania 3 (ct56 CPU)

**Applies to:** the real NA53 science run. **Date:** 2026-09-04 ·
**Compute:** verified `taiwania3_cpu` profile — partition `ct56`, account `mst115368`,
conda env `na53_aptamer` (GROMACS 2024.4, CPU/AVX2). See `memory.md §4.1` for the
verified-facts source and `profiles/taiwania3_cpu.env` for the values.

> ⚠️ **Sequence correction (2026-09-04):** NA53 is **75 nt**, not 55 nt — the
> "55-nt" figure that propagated through early docs was a miscount. The canonical
> sequence lives in `structures/NA53.fasta` and is enforced by
> `scripts/validate_na53_pdb.py`. Every AF3/model input must be the 75-nt molecule.

---

## 0. Pre-flight (your workstation — one command)

Every candidate 3D model must pass the gate **before** it is committed. One
command does the whole job (APTAMD-style automated edition, 2026-09-04):
**clean → bless → stage** — it keeps model 1, drops water/protein/ions/ligands
and hydrogens, resolves altLoc duplicates, merges stray chains, renumbers
residues 1..75, re-validates the CLEANED result, and only then writes
`structures/NA53_initial.pdb`. A rejected model leaves **no file behind**.
AlphaFold 3 emits **mmCIF (.cif)** — `--stage` reads .cif and .pdb natively
and normalizes AF3's nonstandard 5'-triphosphate to the amber `DA5`
monophosphate terminus (drops the gamma OP3 atom, reported in the output).

```bash
cd GROMACS_NA53
python3 scripts/validate_na53_pdb.py --stage /path/to/your/AF3_model.pdb   # expect ✅ BLESSED + STAGED
git add structures/NA53_initial.pdb structures/NA53.fasta
git commit -m "Phase 5: real NA53 75-nt structure (AF3) — validated" && git push
```

Rejections tell you exactly what is wrong (length, position mismatch, missing
atoms). Fix in the modeling tool and re-stage; **never commit an unvalidated PDB**.

## 1. First time on Taiwania 3 — environment (once)

```bash
ssh u5662994@twnia3.nchc.org.tw          # 2FA: method 1 (app OTP) + password
cd ~
bash slurm/setup_taiwania3.sh https://github.com/CliffVale/GROMACS_NA53.git
# (setup now auto-accepts the conda 25.x Anaconda-ToS gate — see slurm/setup_taiwania3.sh)
# (after it finishes, verify the engine once:)
conda activate na53_aptamer
gmx --version 2>&1 | head -1             # expect: GROMACS 2024.4 ...
```

Later sessions (repo already cloned): `cd ~/GROMACS_NA53 && git pull`.

## 2. Health check before every run (on the login node)

```bash
cd ~/GROMACS_NA53
./run_simulation.sh doctor --profile taiwania3_cpu     # expect ✅ all checks passed
```

`doctor` runs the static repo-integrity checks **plus live probes of the gmx that
the profile loads** (version, flags, group layout). If it fails, stop and paste the
output — do not submit.

## 3. Smoke run — validate the cluster toolchain + real structure (1 ns)

Purpose: prove prep → EM → NVT → NPT → production → analysis works on the real
75-nt system through the actual SLURM chain, and get the **measured ns/day** that
plans the full run. Do not skip this.

```bash
cd ~/GROMACS_NA53
./run_simulation.sh submit --profile taiwania3_cpu --ns 1 --dry-run   # inspect first
./run_simulation.sh submit --profile taiwania3_cpu --ns 1             # submit chain 01→02→03→04
squeue -u $USER                                                       # watch jobs
```

Four jobs run in sequence (afterok dependency). Typical CPU times: prep ~10–30 min,
equil (EM→NVT→NPT₁→NPT₂) ~1–3 h, 1 ns prod ~30–90 min, analysis ~15 min.

**Monitoring while it runs:**

```bash
# ON the login node (no SSH loop — status would try to ssh back to itself):
./run_simulation.sh status --profile taiwania3_cpu --local
tail -n 15 logs/mdrun_prod.log        # ns/day appears in the Performance line
tail -n 8  logs/run_status.txt        # stage=… start/ok markers

# FROM your workstation (each call prompts for an OTP — that is expected):
./run_simulation.sh status  --profile taiwania3_cpu     # remote snapshot
./run_simulation.sh monitor --profile taiwania3_cpu     # live tail (Ctrl-C stops)
```

## 4. Verify the smoke result before spending production hours

On the login node, after the chain finishes:

```bash
cd ~/GROMACS_NA53
tail -n 8 logs/run_status.txt                    # all four stages end with “ok”
ls scripts/prod.xtc analysis/*.xvg results/figures/   # artifacts present
```

Sanity (values will differ from the 12-bp duplex — this is a 75-nt ssDNA with
stem-loops, not a duplex): RMSD plateaus (no steady drift), Rg in the ~1.5–3.5 nm
band, energy/temperature stable in the equil logs, **no** `⚠️` in doctor/health.
H-bond counts are *intramolecular* here (a handful from the stems), not 30–40.

Record the measured ns/day from `scripts/prod.log` (Performance line). That number
decides the production length and restart plan:

| measured ns/day (56 cores) | 100 ns wall time | action |
|---|---|---|
| ≥ 40 | ~2.5 days | fits one ct56 job (95 h cap) |
| 20–40 | ~3–5 days | fits with the RESTART path below |
| < 20 | > 5 days | reconsider length / GPU profile |

## 5. Full production run (100 ns default)

The smoke left 1 ns of trajectory in `scripts/`. Archive it so the production
starts clean (prep/equil rerun cost ~1–3 h — negligible next to production):

```bash
cd ~/GROMACS_NA53
mkdir -p runs/smoke_1ns
mv scripts/prod.tpr scripts/prod.xtc scripts/prod.cpt scripts/prod.log scripts/prod.edr runs/smoke_1ns/ 2>/dev/null || true
./run_simulation.sh submit --profile taiwania3_cpu           # default PROD_NS=100
# or, to choose a length explicitly:
./run_simulation.sh submit --profile taiwania3_cpu --ns 200
```

**Checkpoint-restart** (if a job hits the 95 h wall or is cancelled — the chain's
own restart is seamless, this covers an interrupted 03):

```bash
cd ~/GROMACS_NA53/scripts
RESTART=1 sbatch ../slurm/jobs/03_prod_taiwania3_cpu.sbatch   # continues from prod.cpt
```

## 6. When production finishes

```bash
./run_simulation.sh status --profile taiwania3_cpu --local    # expect stage=prod ok, analysis ok
```

Analysis (04) and figures already ran in the chain. Fetch them to the workstation
(trajectory is large — fetch results only, or tar the trajectory separately):

```bash
# from your workstation:
mkdir -p results/na53_run1 && cd results/na53_run1
rsync -av --progress "u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/analysis/" ./analysis/
rsync -av --progress "u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/results/figures/" ./figures/
```

Then bring the workspace back to the repo for the write-up (figures + xvg are
gitignored by design; add a run manifest instead).

---

## Troubleshooting quick table

| Symptom | Cause / fix |
|---|---|
| `gmx: command not found` in a job | conda env not active — the profile's ENV_SETUP block activates it; check `conda env list` → `na53_aptamer` exists |
| `status` hangs asking for OTP on the login node | you are ON the cluster — add `--local` (it would otherwise ssh to itself) |
| Job stays `PD` (pending) | normal queue wait on ct56; `squeue -u $USER` shows why (Resources/Priority) |
| `❌ npt2.gro not found` in 03 | chain order broke — 02 must finish ok first; never submit 03 alone before 02 ran |
| Equil/prod log shows unexpected thread count | mdrun thread detection vs `--cpus-per-task` — first sign is slow ns/day, not an error; paste the log if it looks wrong |
| Structure rejected by validator | read the verdict line; most likely wrong length (55-nt impostor) or a partial nucleotide |
| Anything else | paste the log + `./run_simulation.sh doctor --profile taiwania3_cpu` output |

---

## Decisions still open before/at production time

- **Force field (Q7 in memory.md):** pipeline default `amber99sb-ildn` is ✅-validated
  end-to-end. Research (bibliography analysis R2 — Dans 2017) recommends switching
  the DNA block to **parmbsc1** for multi-µs ssDNA fidelity. The smoke run is valid
  under either; decide **before** the full production and I will wire the bsc1 port
  install + switch.
- **Production length:** 100 ns (default) is the first milestone; extend via
  checkpointed restart if KPIs look healthy.
