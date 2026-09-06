# Downloading the 100 ns raw results from Taiwania-3 (Windows tablet)

This is the laptop-side companion to `research/reports/2026-09-06-na53-100ns-results.md`.
The raw results live on T3 at:

    ~/GROMACS_NA53/archive/2026-09-06_100ns_prod/

and you want a local copy on the Windows tablet.

---

## What you're downloading

| Item | Size | Notes |
|---|---|---|
| `prod.xtc` | ~1.6 GB | trajectory — the big one, fetch separately with rsync |
| `prod.edr` | ~415 KB | energy database |
| `prod.cpt` | ~7 MB | checkpoint (resumable if you ever extend the run) |
| `scripts/prod.log` | ~98 KB | raw mdrun output (has the Performance line + energy blocks) |
| `logs/na53_prod_2036720.out` + `.err` | ~2–3 KB each | SLURM capture for the prod job |
| `analysis/*.xvg` | ~20+ files, ~1–2 MB total | RMSD, RMSF, Rg, SASA, H-bonds, PCA, energy terms, etc. |
| `results/figures/*.png` | 8 figures, ~5 MB total | plots |
| (also present, but not from this run) `logs/na53_prod_2033888.*` | tiny | the 1 ns smoke job's logs — kept for history, not the latest |

Total if you grab everything in one tarball: about **1.7 GB compressed**.

---

## Option A — PowerShell + rsync (best for the big xtc, resumable)

This is the recommended path if you want the trajectory reliably. rsync can resume
if the Wi-Fi drops.

### 0. Get rsync on Windows

Pick one:

- **WSL** (Ubuntu from the Microsoft Store) — then use the bash commands below
  inside WSL. This is the cleanest if you already have it.
- **Git for Windows** — ships `rsync` and `ssh` under `Git\usr\bin`. If you have
  Git installed, that `bin` folder may already be on your PATH.
- **cwRsync / rsync.net standalone** — older option, only if the above aren't available.

If `rsync` isn't on your PATH, open a terminal and run:

```powershell
where.exe rsync
```

If that returns nothing, use the GUI option below instead.

### 1. Make a folder for the download

Run this in PowerShell (or WSL bash) from wherever you keep projects:

```powershell
mkdir na53_100ns
cd na53_100ns
```

If you're in WSL bash, use the bash form:

```bash
mkdir -p na53_100ns && cd na53_100ns
```

### 2. Fetch everything EXCEPT the trajectory in one tarball

This is one SSH session, compression on the fly, and it produces a single
`na53_100ns_run.tar.gz` on your tablet.

**WSL bash:**

```bash
ssh u5662994@twnia3.nchc.org.tw \
  'cd ~/GROMACS_NA53 && tar czf - archive/2026-09-06_100ns_prod' \
  > na53_100ns_run.tar.gz
tar xzf na53_100ns_run.tar.gz
```

**PowerShell (if ssh is on PATH, e.g. from Git for Windows or OpenSSH):**

```powershell
ssh u5662994@twnia3.nchc.org.tw `
  'cd ~/GROMACS_NA53 && tar czf - archive/2026-09-06_100ns_prod' `
  > na53_100ns_run.tar.gz
tar xzf na53_100ns_run.tar.gz
```

You'll see the 2FA prompt. Pick your OTP method when asked.

> **2FA prompt example (first login of the session):**
>
> ```
> (u5662994@twnia3.nchc.org.tw) Please select the 2FA login method.
> 1. Mobile APP OTP
> 2. Mobile APP PUSH
> 3. Email OTP
> Login method:
> ```
>
> Type the number for the method you registered (usually `1` for app OTP), then
> enter the code. You only do this once per SSH connection.

### 3. Fetch the trajectory with rsync (resumable)

From inside the same `na53_100ns/` folder:

**WSL bash:**

```bash
rsync -avzP u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/archive/2026-09-06_100ns_prod/prod.xtc \
  ./archive/2026-09-06_100ns_prod/
```

**PowerShell:**

```powershell
rsync -avzP u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/archive/2026-09-06_100ns_prod/prod.xtc `
  .\archive\2026-09-06_100ns_prod\
```

What the flags do:

- `-a` archive mode (keeps file metadata)
- `-v` verbose
- `-z` compress during transfer
- `-P` shows progress AND keeps partial files so a dropped link resumes

If it interrupts, just run the same command again. rsync picks up where it left off.

---

## Option B — GUI (if you'd rather not use the terminal)

If rsync/ssh from PowerShell is annoying on the tablet, use an SFTP GUI.

### MobaXTerm (good on Windows)

1. New session → SSH → `twnia3.nchc.org.tw`, username `u5662994`.
2. Use **Interactive** authentication so the OTP prompt appears.
3. After login, open the built-in SFTP sidebar.
4. Navigate on the remote side to:
   ```
   /home/u5662994/GROMACS_NA53/archive/2026-09-06_100ns_prod/
   ```
5. Drag the whole `2026-09-06_100ns_prod` folder to your local side.

MobaXTerm can download by SFTP drag-and-drop. For the 1.6 GB xtc, a single GUI
transfer is fine if your connection is stable, but it won't resume as cleanly as
rsync.

### WinSCP (Windows)

Same idea: SFTP to `twnia3.nchc.org.tw`, user `u5662994`, then drag the folder.
Set transfer mode to **binary** for the trajectory.

### FileZilla (cross-platform)

Host `twnia3.nchc.org.tw`, protocol SFTP, user `u5662994`, logon type **Interactive**
so the OTP prompt works. Drag the folder across. Set simultaneous transfers to 1
in the transfer settings.

---

## What 2FA will look like

Each new SSH/rsync connection will ask once:

```
(u5662994@twnia3.nchc.org.tw) Please select the 2FA login method.
1. Mobile APP OTP
2. Mobile APP PUSH
3. Email OTP
Login method:
```

Then either:

- if you chose app OTP: it prompts for the code
- if you chose push: it waits for the app approval
- if you chose email: it waits for the email code

After that one prompt per connection, the transfer starts.

> If you get `Permission denied (publickey,password,keyboard-interactive)` or
> `account doesn't exist` style failures, stop and check:
> - your username is `u5662994`
> - the OTP device is registered in iService (會員資訊 → 主機帳號資訊 → 建立OTP載具)
> - you're not behind a network that blocks the SSH port

---

## After the fetch — quick verification

You should now have:

```
na53_100ns/
  archive/
    2026-09-06_100ns_prod/
      prod.xtc        (~1.6 GB)
      prod.edr
      prod.cpt
      scripts/
        prod.log
      logs/
        na53_prod_2036720.out
        na53_prod_2036720.err
      analysis/
        *.xvg
      results/
        figures/
          *.png
```

### Run the repo's verification script (WSL / Git bash)

There's a dependency-free check in the repo:

```bash
bash research/scripts/verify_100ns_fetch.sh
```

It will:

- confirm the archive tree is there
- check that `prod.xtc` is roughly the right size for 100 ns
- print the `Performance:` line from `scripts/prod.log`
- print the `Performance:` line from `logs/na53_prod_2036720.out`
- count the analysis xvg files and figures
- warn if the old smoke logs (`na53_prod_2033888.*`) are sitting in the archive

### Or just eyeball it with a few shell commands

```bash
cd na53_100ns
ls -la archive/2026-09-06_100ns_prod/prod.xtc
ls -la archive/2026-09-06_100ns_prod/scripts/prod.log
grep -a "Performance:" archive/2026-09-06_100ns_prod/scripts/prod.log | tail -1
grep -a "Finished mdrun" archive/2026-09-06_100ns_prod/scripts/prod.log | tail -1
ls archive/2026-09-06_100ns_prod/analysis/*.xvg | wc -l
ls archive/2026-09-06_100ns_prod/results/figures/*.png | wc -l
```

Expected outcomes:

- `prod.xtc` should be around **1.6 GB**
- the `Performance:` line should say about **18.3 ns/day**
- the `Finished mdrun` line should mention **2026-09-06 08:45:37**
- `analysis/*.xvg` count should be around **22**
- `results/figures/*.png` count should be **8**

---

## If the transfer drops

- **For the tarball:** re-run the same `ssh ... tar czf ... > ...` command.
  It starts over from scratch (it's one stream, not resumable by itself).
- **For the trajectory:** re-run the same `rsync -avzP ...` command.
  It resumes from the partial file.
- **If the link is really flaky:** fetch the tarball with rsync as a single file
  instead of a streaming ssh pipe:
  1. On T3 (one ssh command):
     ```bash
     ssh u5662994@twnia3.nchc.org.tw \
       'cd ~/GROMACS_NA53 && tar czf na53_100ns_run.tar.gz archive/2026-09-06_100ns_prod'
     ```
  2. Then on the tablet:
     ```bash
     rsync -avzP u5662994@twnia3.nchc.org.tw:~/GROMACS_NA53/na53_100ns_run.tar.gz .
     ```
  3. Then:
     ```bash
     tar xzf na53_100ns_run.tar.gz
     ```

---

## Where to put the download

Any folder you control on the tablet is fine. A common choice:

```
Documents/GROMACS_NA53/na53_100ns/
```

or next to a local clone of the repo:

```
c:\users\<you>\projects\GROMACS_NA53\na53_100ns\
```

The only requirement is that you can write there and that you remember where it
is for the next analysis step.

---

## What to do next

Once the fetch is verified:

1. If you have GROMACS + a viewer on the tablet, you can re-render figures from
   `archive/2026-09-06_100ns_prod/analysis/*.xvg` — but first fix the density/pressure
   term ID issue on T3 and re-extract, otherwise the energy panels will be wrong.
2. Otherwise, just keep the archive as your local raw-data copy. The next step is
   the density/pressure ID verification on T3, then re-rendering figures there and
   either re-fetching the corrected figures or copying the corrected `analysis/*.xvg`
   back down.
