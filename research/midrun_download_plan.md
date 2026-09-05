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

## What to do at chain end (when the job finishes)

At that point, download EVERYTHING:
```bash
# On your laptop:
mkdir -p na53_final && cd na53_final

# All the small stuff (analysis, figures, logs) — one OTP, fast:
ssh u5662994@twnia3.nchc.org.tw 'cd ~/GROMACS_NA53 && tar czf - analysis results/figures logs' > na53_results.tar.gz
tar xzf na53_results.tar.gz

# The trajectory (resumable, large):
rsync -avP u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.xtc .
rsync -avP u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.edr .
rsync -avP u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.cpt .
rsync -avP u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.tpr .
rsync -avP u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.log .
```

## Mid-run analysis plan (what we can do with prod.log now)

Once you've downloaded `prod.log.current`:

1. **Verify the dashboard parser** — run the same awk logic the dashboard uses against the real log and confirm it extracts T/P correctly
2. **Check early physics** — look at T/P evolution over the first 10 ns, see if pressure is stabilizing
3. **Check for anomalies** — any spikes, drifts, or unexpected behavior in the energy tables
4. **Parser improvements** — if we find the log format differs from what we expect, fix the parser BEFORE the run ends so the final analysis is correct

## Summary

| File | Download now? | Why |
|---|---|---|
| `scripts/prod.log` | ✅ YES | Live, text, has all mid-run data we can analyze |
| `scripts/prod.cpt` | ⚠️ OPTIONAL | Insurance only, not for analysis |
| `logs/na53_prod_2036720.out` | ❌ No | Only has startup info mid-run |
| `prod.xtc` | ❌ No | 1 GB, growing, can't analyze partial |
| `prod.edr` | ❌ No | Binary, partial is useless, tables already in prod.log |
| `analysis/` | ❌ No | Stale from 1ns smoke, will be regenerated |
| `results/figures/` | ❌ No | Stale, will be regenerated |

## The one command to run now

```bash
scp u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/scripts/prod.log ./na53_prod.log.current
```

That's it. Then we can analyze it and improve the parser/approach before the run ends.
