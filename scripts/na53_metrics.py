#!/usr/bin/env python3
"""
na53_metrics.py — live cluster/run metrics for the NA53 pipeline (stdlib only)
=============================================================================
Shared data layer for the Textual dashboard (dashboard_textual.py) and for
`--selftest`. Reads live state from squeue, the gmx .log sidecars and
pipeline artifacts — no gmx spawning, cheap to poll.

Usage:
  python3 scripts/na53_metrics.py --selftest     # JSON snapshot, no textual needed
"""
import collections
import datetime as dt
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGES = ("em", "nvt", "npt1", "npt2", "prod")
STAGE_LABEL = {
    "em": "EM · energy minimization",
    "nvt": "NVT · 100 ps, V-rescale",
    "npt1": "NPT1 · 100 ps, restrained",
    "npt2": "NPT2 · 500 ps, free",
    "prod": "PRODUCTION · unrestrained NPT",
}
STEP_RE = re.compile(r"^(\d+) steps,\s+([\d.]+) ps\.$", re.M)
FIN_RE = re.compile(r"^step (\d+), will finish (.*)$", re.M)
STATE_STYLE = {"RUNNING": "bold green", "COMPLETING": "green",
               "PENDING": "yellow", "COMPLETED": "green",
               "FAILED": "bold red", "CANCELLED": "red"}


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True,
                              timeout=10).stdout
    except Exception:
        return ""


def our_jobs():
    """list of dicts: id, name, state, elapsed, limit, node/reason"""
    out = run(["squeue", "-h", "-u", os.environ.get("USER", ""),
               "-o", "%i %j %T %M %L %R"])
    rows = []
    for ln in out.splitlines():
        f = ln.split()
        if len(f) >= 6 and f[1].startswith("na53_"):
            rows.append(dict(jid=f[0], name=f[1], state=f[2], elapsed=f[3],
                             limit=f[4], node=f[5]))
    return rows


def active_log():
    """newest scripts/<stage>.log not containing 'Finished mdrun' → (stage, path)"""
    best, best_t = None, -1
    for s in STAGES:
        p = os.path.join(REPO, "scripts", s + ".log")
        if not os.path.isfile(p):
            continue
        with open(p, errors="replace") as fh:
            if "Finished mdrun" in fh.read():
                continue
        t = os.path.getmtime(p)
        if t > best_t:
            best, best_t = (s, p), t
    return best


def parse_log(path):
    """dict with totals/step/time/temp/pres/mdrun-eta from a gmx .log"""
    d = dict(total_steps=None, total_ps=None, cur_step=None, cur_ps=None,
             temp=None, pres=None, fin_step=None, fin_eta=None, age=0)
    try:
        txt = open(path, errors="replace").read()
        d["age"] = int(dt.datetime.now().timestamp() - os.path.getmtime(path))
    except OSError:
        return d
    m = list(STEP_RE.finditer(txt))
    if m:
        d["total_steps"] = int(m[-1].group(1))
        d["total_ps"] = float(m[-1].group(2))
    m = list(FIN_RE.finditer(txt))
    if m:
        d["fin_step"] = int(m[-1].group(1))
        d["fin_eta"] = m[-1].group(2)
    # last Step/Time table row (tolerant: any "Step Time" header)
    want, st, t, tp, pr = False, None, None, None, None
    for ln in txt.splitlines():
        if re.match(r"^\s*Step\s+Time", ln):
            want = True
            continue
        if not want:
            continue
        f = ln.split()
        if len(f) >= 2 and f[0].isdigit() and re.fullmatch(r"[\d.]+", f[1]):
            st, t = int(f[0]), float(f[1])
            if len(f) >= 5 and re.fullmatch(r"-?[\d.]+", f[3]) \
               and re.fullmatch(r"-?[\d.]+", f[4]):
                tp, pr = float(f[3]), float(f[4])
    d["cur_step"], d["cur_ps"] = st, t
    d["temp"], d["pres"] = tp, pr
    return d


def artifact_snapshot():
    """pipeline + artifact facts"""
    def size(p):
        try:
            return os.path.getsize(p)
        except OSError:
            return 0
    atoms = ""
    try:
        lines = open(os.path.join(REPO, "scripts", "NA53_initial_ionized.gro"),
                     errors="replace").read().splitlines()
        atoms = lines[1].strip() if len(lines) > 1 else ""
    except OSError:
        pass
    figdir = os.path.join(REPO, "results", "figures")
    figs = len([f for f in os.listdir(figdir) if f.endswith(".png")]) \
        if os.path.isdir(figdir) else 0
    return dict(topol=size(os.path.join(REPO, "scripts", "topol.top")),
                npt2=size(os.path.join(REPO, "scripts", "npt2.gro")),
                xtc=size(os.path.join(REPO, "scripts", "prod.xtc")),
                atoms=atoms, figs=figs)


def run_status_tail(n=4):
    try:
        lines = open(os.path.join(REPO, "logs", "run_status.txt"),
                     errors="replace").read().splitlines()
        return lines[-n:]
    except OSError:
        return []


def md_tail(n=8):
    try:
        logs = os.path.join(REPO, "logs")
        cands = [os.path.join(logs, f) for f in os.listdir(logs)
                 if f.startswith("mdrun_") and f.endswith(".log")]
        if not cands:
            return []
        latest = max(cands, key=os.path.getmtime)
        return open(latest, errors="replace").read().splitlines()[-n:]
    except OSError:
        return []


def snapshot():
    """everything the UI needs, as plain data"""
    stage, path = active_log()
    d = parse_log(path) if path else {}
    return dict(stage=stage, log=path, jobs=our_jobs(),
                art=artifact_snapshot(), trail=run_status_tail(),
                md=md_tail(), **d)


def fmt_dur(sec):
    sec = int(sec)
    if sec < 60:
        return f"{sec}s"
    d, sec = divmod(sec, 86400)
    h, sec = divmod(sec, 3600)
    m, s = divmod(sec, 60)
    if d:
        return f"{d}d {h}h {m}m"
    if h:
        return f"{h}h {m:02d}m"
    return f"{m}m {s:02d}s"


def fmt_bytes(b):
    for unit, div in (("GB", 1 << 30), ("MB", 1 << 20), ("KB", 1 << 10)):
        if b >= div:
            return f"{b / div:.1f} {unit}"
    return f"{b} B"


def state_style(st):
    return STATE_STYLE.get(st, "yellow")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        print(json.dumps(snapshot(), indent=2, default=str))
    else:
        print(__doc__)