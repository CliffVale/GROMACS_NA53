#!/usr/bin/env python3
"""
dashboard_textual.py — NA53 live simulation dashboard (Textual TUI)
====================================================================
A real-time, keyboard-driven dashboard inspired by squid-tui (Textual
Slurm dashboard) and slurm-tui (Ratatui). Renders live cluster state —
no gmx spawning, cheap polls:

    • JOBS        every na53_* SLURM job (state, elapsed/limit, node/reason)
    • STAGE       active MD stage + animated progress bar + step/sim time
    • PHYSICS     live T / P with session history sparklines
    • PERFORMANCE measured ns/day + steps/s, stage ETA, prod-target ETA
    • PIPELINE    01 prep → 02 equil → 03 prod → 04 analysis checklist
    • LOG         launcher trail + md log tail (ANSI-safe)

Requires textual >= 0.50 (`pip install textual`). `run_simulation.sh
monitor` auto-falls back to the bash dashboard when textual is missing;
`python3 scripts/na53_metrics.py --selftest` runs the parsers standalone.

Usage:
  python3 scripts/dashboard_textual.py [--every 15] [--target-ns 100]
                                       [--profile NAME]
Keys: q quit · r refresh now · d toggle dark/light
"""
import argparse
import collections
import datetime as dt
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from na53_metrics import (STAGE_LABEL, fmt_bytes, fmt_dur, snapshot,
                              state_style)
    from textual.app import App, ComposeResult
    from textual.binding import Binding
    from textual.containers import Grid, Vertical
    from textual.widgets import (Footer, Header, ProgressBar,
                                 RichLog, Sparkline, Static)
except ImportError as e:
    print(f"❌ dashboard_textual.py needs textual + na53_metrics: {e}\n"
          "   Run: pip install textual   (monitor will fall back to bash meanwhile)",
          file=sys.stderr)
    sys.exit(3)


class NA53Dashboard(App):
    TITLE = "NA53 · GROMACS LIVE"
    CSS = """
    #grid { grid-size: 2 3; grid-gutter: 1 1; padding: 0 1; }
    .panel { height: 100%; }
    #stage_box, #physics_box { height: 100%; }
    #stage_bar { width: 100%; }
    #temp_spark, #pres_spark { height: 3; }
    #logbox { height: 100%; }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("r", "refresh", "Refresh"),
        Binding("d", "toggle_theme", "Dark/Light"),
    ]

    def __init__(self, every=15, target_ns=100, profile=""):
        super().__init__()
        self.every = max(3, every)
        self.target_ns = target_ns
        self.profile = profile
        self.hist_temp = collections.deque(maxlen=240)
        self.hist_pres = collections.deque(maxlen=240)
        self.last_stage = None

    def compose(self) -> ComposeResult:
        yield Header()
        with Grid(id="grid"):
            yield Static(id="jobs", classes="panel")
            with Vertical(id="stage_box", classes="panel"):
                yield Static(id="stage")
                yield ProgressBar(id="stage_bar", show_percentage=False,
                                  show_eta=False)
            with Vertical(id="physics_box", classes="panel"):
                yield Static(id="physics")
                yield Sparkline(id="temp_spark", data=None)
                yield Sparkline(id="pres_spark", data=None)
            yield Static(id="perf", classes="panel")
            yield Static(id="pipeline", classes="panel")
            yield RichLog(id="logbox", classes="panel", markup=False)
        yield Footer()

    def on_mount(self) -> None:
        self.refresh_data()
        self.set_interval(self.every, self.refresh_data)

    def action_toggle_theme(self) -> None:
        self.theme = "textual-light" if self.theme == "textual-dark" \
            else "textual-dark"

    def action_refresh(self) -> None:
        self.refresh_data()

    def refresh_data(self) -> None:
        try:
            self._refresh()
        except Exception:
            # keep the traceback reachable: also write it to a log so a
            # fullscreen error can be read without fighting terminal capture
            import traceback
            try:
                with open(os.path.join(
                        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "logs", "dashboard_error.log"), "a") as fh:
                    fh.write(f"[{dt.datetime.now():%Y-%m-%d %H:%M:%S}] "
                             + traceback.format_exc() + "\n")
            except OSError:
                pass
            self.notify("refresh error — see logs/dashboard_error.log",
                        severity="error", timeout=8)

    def _refresh(self) -> None:
        snap = snapshot()
        if snap["stage"] and snap["stage"] != self.last_stage and self.last_stage:
            self.query_one("#logbox", RichLog).write(
                f"[{dt.datetime.now():%H:%M:%S}] stage → "
                f"{STAGE_LABEL[snap['stage']]}")
        if snap["stage"]:
            self.last_stage = snap["stage"]
        self.update_jobs(snap["jobs"])
        self.update_stage(snap)
        self.update_physics(snap)
        self.update_perf(snap)
        self.update_pipeline(snap)
        self.update_log(snap)

    # ── JOBS ──
    def update_jobs(self, jobs):
        w = self.query_one("#jobs", Static)
        if not jobs:
            w.update("JOBS\n  (no na53_* jobs in queue)")
            return
        lines = ["JOBS"]
        for j in jobs:
            tail = (f"  {j['elapsed']} / {j['limit']}   {j['node']}"
                    if j["state"] == "RUNNING" else f"  —   {j['node']}")
            st = state_style(j["state"])
            lines.append(f"  [{st}]{j['name']}[/] [{st}]{j['state']}[/]  "
                         f"#{j['jid']}{tail}")
        w.update("\n".join(lines))

    # ── STAGE ──
    def update_stage(self, snap):
        w = self.query_one("#stage", Static)
        stage, d = snap["stage"], snap
        if not stage:
            w.update("STAGE\n  (between MD stages — prep/analysis or idle)")
            return
        bar = self.query_one("#stage_bar", ProgressBar)
        lines = [f"STAGE   {STAGE_LABEL[stage]}"]
        total_ps, cur_ps = d.get("total_ps"), d.get("cur_ps")
        if cur_ps is not None and total_ps:
            pct = min(100, int(cur_ps / total_ps * 100))
            bar.update(progress=min(cur_ps, total_ps), total=total_ps)
            lines.append(f"        {pct}%   sim {cur_ps:.1f} / "
                         f"{total_ps:.0f} ps")
        elif cur_ps is not None:
            # a Step table but no fixed total (EM converges on Fmax, not steps)
            lines.append(f"        sim {cur_ps:.1f} ps so far "
                         f"(EM/restart — no fixed length)")
        else:
            bar.update(progress=0, total=100)
            lines.append(f"        (waiting for first energy block — log age "
                         f"{d.get('age', 0)}s)")
        if d.get("cur_step") is not None:
            ts = d.get("total_steps")
            if ts:
                lines.append(f"        step {d['cur_step']:,} / {ts:,}")
            else:
                lines.append(f"        step {d['cur_step']:,} (no fixed total)")
        w.update("\n".join(lines))

    # ── PHYSICS ──
    def update_physics(self, snap):
        w = self.query_one("#physics", Static)
        temp, pres = snap.get("temp"), snap.get("pres")
        if temp is not None:
            self.hist_temp.append(temp)
            self.hist_pres.append(pres)
        ts, ps = list(self.hist_temp), list(self.hist_pres)
        try:
            self.query_one("#temp_spark", Sparkline).data = ts or None
            self.query_one("#pres_spark", Sparkline).data = ps or None
        except Exception:
            pass
        lines = ["PHYSICS"]
        if temp is not None:
            lines.append(f"  T = {temp:.2f} K    P = {pres:.2f} bar")
        else:
            lines.append("  (no energy table yet)")
        if len(ts) > 1:
            lines.append(f"  T trend {min(ts):.1f}–{max(ts):.1f} K  "
                         f"({len(ts)} samples)")
        w.update("\n".join(lines))

    # ── PERFORMANCE ──
    def update_perf(self, snap):
        w = self.query_one("#perf", Static)
        stage, d = snap["stage"], snap
        lines = ["PERFORMANCE"]
        if not stage or d.get("cur_ps") is None:
            lines.append("  ns/day  — (need the first energy block)")
            w.update("\n".join(lines))
            return
        rate = nsday = None
        eta_s = eta_s2 = None
        if d.get("fin_eta") and d.get("fin_step") is not None \
           and d.get("total_steps"):
            try:
                fe = dt.datetime.strptime(d["fin_eta"], "%a %b %d %H:%M:%S %Y")
                eta_s = int((fe - dt.datetime.now()).total_seconds())
                if eta_s > 0:
                    rate = (d["total_steps"] - d["fin_step"]) / eta_s
            except ValueError:
                pass
        if rate:
            nsday = rate * 2e-3 * 86400 / 1000
        elif d.get("age", 0) > 5:
            nsday = d["cur_ps"] / d["age"] * 86400 / 1000
        if rate and d.get("total_steps") and d.get("cur_step") is not None:
            rem = d["total_steps"] - d["cur_step"]
            if rem > 0 and rate > 0:
                eta_s2 = int(rem / rate)
        if nsday:
            lines.append(f"  ns/day  {nsday:.1f}"
                         + (f"   ({rate:.0f} steps/s @ 2 fs)" if rate else " (est.)"))
        else:
            lines.append("  ns/day  —")
        if eta_s2:
            lines.append(f"  ETA     {fmt_dur(eta_s2)} to finish this stage")
        elif eta_s:
            lines.append(f"  ETA     {fmt_dur(eta_s)} (mdrun estimate, "
                         f"finish ~{d['fin_eta']})")
        if stage == "prod" and nsday and d.get("cur_ps"):
            need = (self.target_ns * 1000 - d["cur_ps"]) / 1000
            if need > 0:
                lines.append(f"  TARGET  {self.target_ns} ns at this rate ≈ "
                             f"{need / nsday:.2f} d")
        w.update("\n".join(lines))

    # ── PIPELINE ──
    def update_pipeline(self, snap):
        w = self.query_one("#pipeline", Static)
        art, stage = snap["art"], snap["stage"]

        def icon(done, fam):
            if done:
                return "✅ done"
            if fam == "equil":
                return "▶ active" if stage in ("em", "nvt", "npt1", "npt2") \
                    else "○ pending"
            return "▶ active" if stage == fam else "○ pending"

        lines = ["PIPELINE"]
        lines.append(f"  01 prep     {icon(bool(art['topol']), 'prep')}"
                     + (f"   topol.top {fmt_bytes(art['topol'])}"
                        + (f" · {art['atoms']} atoms" if art["atoms"] else "")))
        lines.append(f"  02 equil    {icon(bool(art['npt2']), 'equil')}"
                     + (f"   npt2.gro {fmt_bytes(art['npt2'])}" if art["npt2"] else ""))
        lines.append(f"  03 prod     {icon(bool(art['xtc']), 'prod')}"
                     + f"   target {self.target_ns} ns"
                     + (f" · xtc {fmt_bytes(art['xtc'])}" if art["xtc"] else ""))
        lines.append(f"  04 analysis {icon(bool(art['figs']), 'ana')}"
                     + (f"   {art['figs']} figure(s)" if art["figs"] else ""))
        w.update("\n".join(lines))

    # ── LOG ──
    def update_log(self, snap):
        box = self.query_one("#logbox", RichLog)
        if not hasattr(self, "_log_primed"):
            for ln in snap["trail"]:
                box.write(ln)
            box.write("── md log tail ──")
            for ln in snap["md"]:
                box.write(ln)
            self._log_primed = True


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--every", type=int, default=15)
    ap.add_argument("--target-ns", type=int, default=100)
    ap.add_argument("--profile", default="")
    args = ap.parse_args(argv)
    app = NA53Dashboard(every=args.every, target_ns=args.target_ns,
                        profile=args.profile)
    app.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())