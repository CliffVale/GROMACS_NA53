# Mid-run partial download — what to grab while the simulation is still running

## Context

Job 2036720 (na53_prod) is RUNNING on cpn3133. ~10150 ps elapsed. xtc is 1.0 GB and growing. We want to download something NOW so we can analyze and improve things mid-run, in case there's something to fix before the chain ends.

## What's safe and useful to download NOW

### 1. `scripts/prod.log` — the GOLDMINE (download this)

This is the live mdrun output file. It contains:
- Every energy/step/time table (printed every 10 ps = every 5000 steps)
- Instantaneous T, P, Pressure, Density, Potential, Kinetic En, Total Energy, Conserved En
- The step N, will finish ETA line (when/if mdrun prints it)
- The final "N steps, X ps." completion line (at chain end)
- The final Performance line (at chain end)

**Why it's useful mid-run:**
- We can verify the dashboard parser against REAL data from THIS run
- We can see early physics behavior (T/P fluctuations, energy drift trends)
- We can check if the log format matches what the parser expects
- We can spot anomalies early (e.g. pressure spikes, temperature instability)

**Size:** Currently small (~5-10 KB per 1000 ps of data), grows over time but very manageable.

**Download command (run on YOUR laptop, not T3):**
```bash
scp u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.log ./na53_prod.log.current
```

Or as a gzip snapshot (cleaner, smaller):
```bash
ssh u5662994@twnia3.nchc.org.tw 'cd ~/GROMACS_NA53 && gzip -c scripts/prod.log' > na53_prod.log.current.gz
```

**Note:** This is a LIVE file. scp gives you a point-in-time snapshot. If you want to track evolution, repeat the download every few hours.

### 2. `scripts/prod.cpt` — checkpoint insurance (optional)

This is the binary checkpoint file (15-min old). It's used to RESUME the simulation if the job dies. Downloading it now:
- Doesn't help with analysis (it's binary, not human-readable)
- IS useful as insurance: if the job dies and you need to restart, you have the checkpoint locally

**Download command:**
```bash
scp u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.cpt ./prod.cpt.snapshot
```

### 3. `logs/na53_prod_2036720.out` — SLURM capture (low value mid-run)

This is what SLURM captures from the job's stdout/stderr. Mid-run it only has:
- Job startup info (Job ID, node, start time, gmx version)
- The grompp output (TPR generation)
- The beginning of mdrun output

The useful stuff (Performance line, completion summary) only appears at the END. Don't bother downloading mid-run.

## What NOT to download now

### ❌ `prod.xtc` (1.0 GB, growing)

- Wastes bandwidth on a file that's instantly stale
- Can't analyze a partial trajectory usefully (no meaningful stats from 10% of the run)
- Will be available at chain end (when it's complete and final)

### ❌ `prod.edr` (growing, binary)

- Same issue as xtc — partial edr can't give meaningful energy stats
- The energy TABLES are already in prod.log (text, much smaller)
- Full edr is only needed for the final gmx energy extraction at chain end

### ❌ `analysis/` directory (stale)

- Currently contains the 1ns smoke's analysis (wrong energy IDs, stale figures)
- Will be COMPLETELY REGENERATED at chain end by the auto-analysis
- Don't waste bandwidth on stale data

### ❌ `results/figures/` (stale)

- Same as analysis/ — the 8 PNGs are from the 1ns smoke
- Will be regenerated at chain end with correct data
- Don't download stale figures

## Mid-run analysis plan (what we can do with prod.log now)

Once you've downloaded `prod.log.current`:

1. **Verify the dashboard parser** — run the same awk logic the dashboard uses against the real log and confirm it extracts T/P correctly
2. **Check early physics** — look at T/P evolution over the first 10 ns, see if pressure is stabilizing
3. **Check for anomalies** — any spikes, drifts, or unexpected behavior in the energy tables
4. **Parser improvements** — if we find the log format differs from what we expect, fix the parser BEFORE the run ends so the final analysis is correct

## Transfer methods (small files vs large files)

### Small files (logs, text, configs — < 100 MB)

**scp** is fine for one-off small transfers (HPC best-practice consensus: Stony Brook RCI, Sheffield, Sigma2 HPC intros all say this):
```bash
scp u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.log ./na53_prod.log.current
```

### Single large file (xtc, edr — up to a few GB)

**rsync -azP** (archive + compress + partial+progress) is the community-recommended upgrade over scp for large or unstable-link transfers. Multiple HPC docs (Stony Brook, Sheffield, EPCC/Sigma2) and the HPC-101 guide (theloginnode.com, 2026) all converge on the same rule of thumb:

> Small file or simple transfer → **scp**
> Big file or unstable network → **rsync -azP**

```bash
rsync -azP --bwlimit=10000 \
  u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.xtc .
```
- `-a` archive mode (preserves permissions/timestamps/symlinks)
- `-z` compresses during transfer (helps text-ish files; xtc is already compressed so `-z` is mostly harmless overhead)
- `-P` = `--partial --progress`: keeps partial files so a dropped connection resumes instead of restarting from 0%
- `--bwlimit=10000` throttles to ~10 MB/s so you don't saturate your link; raise/lower to taste
- If the transfer drops, rerun the **same** command — rsync diffs source vs dest and continues

### Multiple files (analysis + figures + logs — the final download)

**Pack before you move** is the golden rule from HPC-101: transferring thousands of small files individually kills network performance due to per-file overhead. Bundle into one archive first:

```bash
# One transfer for the whole tree, compression on the fly (xvg/PNG compress well)
ssh u5662994@twnia3.nchc.org.tw \
  'cd ~/GROMACS_NA53 && tar czf - analysis results/figures logs' \
  > na53_results.tar.gz
tar xzf na53_results.tar.gz
```

If that archive is large enough to risk a drop, make it resumable by putting rsync on the tarball:

```bash
# On T3: build the tarball once
ssh u5662994@twnia3.nchc.org.tw \
  'cd ~/GROMACS_NA53 && tar czf na53_results.tar.gz analysis results/figures logs'
# Then rsync the single tarball resumably
rsync -azP --bwlimit=10000 \
  u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/na53_results.tar.gz .
```

### Very large xtc (multi-GB, e.g. 100 ns trajectory = ~10 GB)

**Split → rsync chunks → reassemble.** This is what the Unix StackExchange HPC community recommends for multi-GB dataset moves (parallel rsync on 30-100 big files). It's overkill for a 1 GB file but scales to 10+ GB:

```bash
# On T3: split xtc into 500 MB chunks
ssh u5662994@twnia3.nchc.org.tw \
  'cd ~/GROMACS_NA53/scripts && split -b 500M prod.xtc prod.xtc.part.'

# Download chunks resumably (can run several in parallel from different terminals)
rsync -azP --bwlimit=10000 \
  u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.xtc.part.aa .
rsync -azP --bwlimit=10000 \
  u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.xtc.part.ab .
# ... etc

# Reassemble on your laptop
cat prod.xtc.part.* > prod.xtc
rm prod.xtc.part.*
```

### GUI alternatives (if you prefer not to use the terminal for transfers)

- **FileZilla** (cross-platform): SFTP, drag-and-drop. Set simultaneous connections to 1 in Transfer Settings, use Interactive logon type for the 2FA prompt. (Sheffield HPC docs)
- **WinSCP** (Windows): SFTP, very popular. Same settings.
- **MobaXTerm** (Windows): built-in SFTP sidebar; use a dedicated SFTP session to avoid repeated 2FA prompts.

These are fine for browsing and one-off small transfers, but rsync is still the right tool for large/resumable.

### When direct transfer ISN'T the bottleneck

Sheffield HPC notes that downloading **directly to the cluster** can be 10-100x faster than going through your local device's internet — relevant if the data is hosted on a web server and you're on a slow link. For T3 downloads that doesn't apply (the data is already on T3), but it's worth knowing for future web-hosted inputs.

### For truly massive data (TB scale, multi-institution)

**Globus** is the heavyweight option — high-performance, auth-managed, resumable transfers between research centers. Not worth the setup for this project, but the HPC community points to it when SCP/rsync stop being practical.

## Summary table

| What | Size (typical) | When to download | Method (community-recommended) |
|---|---|---|---|
| `scripts/prod.log` | ~1 MB, grows | **NOW** (mid-run, for analysis) | scp (small enough) |
| `scripts/prod.cpt` | ~10-100 MB | Optional — insurance only, not for analysis | scp or rsync |
| `logs/na53_prod_*.out` | ~1-10 MB | At chain end (has the Performance line then) | scp |
| `analysis/` (xvg + logs) | ~1-10 MB | At chain end (regenerated by auto-analysis) | tar+ssh, or rsync the tarball |
| `results/figures/` (PNGs) | ~10-50 MB | At chain end (regenerated) | tar+ssh, or rsync the tarball |
| `prod.tpr` | ~10-100 MB | At chain end (needed for reanalysis) | scp or rsync |
| `prod.edr` | ~100 MB - 1 GB | At chain end (for `gmx energy` extraction) | rsync -azP --partial |
| `prod.xtc` | ~1-10+ GB | At chain end (the trajectory) | rsync -azP --partial; split+reassemble if multi-GB |

### Rule of thumb (from the HPC community consensus above)

| Situation | Tool |
|---|---|
| Small file, one-off | **scp** |
| Big file, or link might drop | **rsync -azP** |
| Many small files | **tar.gz first, then move the archive** |
| Web-hosted data → cluster | **wget/curl directly on the cluster** (avoid laptop double-hop) |
| Code/scripts | **git** (push/pull) — not rsync |
| TB-scale, multi-institution | **Globus** |

## The one command to run now

```bash
scp u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.log ./na53_prod.log.current
```

That's it. Then we can analyze it and improve the parser/approach before the run ends.

## Provenance note

The mid-run prod.log snapshot and any analysis we do from it should be recorded in `research/reports/` alongside the final results, so the repo has a complete record of what was checked mid-run and what decisions were made based on it.

## References (HPC transfer best-practice consensus)

- Stony Brook Research Computing (SeaWulf): "File Transfer with rsync, scp, sftp" — rsync for large files, interrupted transfers that need resuming, syncing directories. (rci.stonybrook.edu)
- Sheffield HPC: "Transferring files" — rsync is typically faster than scp and sftp; can resume with --append-verify; download directly to the cluster can be 10-100x faster than via your local device. (docs.hpc.shef.ac.uk)
- EPCC/Sigma2 HPC-intro tutorial 15: "Transferring files" — recommends rsync for best practices. (training.pages.sigma2.no)
- theloginnode.com "HPC 101: File Transfer on HPC" (2026): golden rule = pack before you move; scp for quick small transfers, rsync -azP for big/unstable, git for code, Globus for TB-scale. (theloginnode.com)
- GROMACS Best Practice Guide (BioExcel): workflow = prepare → run → post-analysis; doesn't prescribe a transfer tool but treats the trajectory as the final output of the run phase. (docs.bioexcel.eu)
