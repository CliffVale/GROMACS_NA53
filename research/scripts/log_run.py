#!/usr/bin/env python3
"""Append one line per deep search run to logs/deepsearch.log.

Usage:
  python3 research/scripts/log_run.py --query "..." --report "research/reports/file.md" \
      --sources 12 --tools "web_search,read_url" [--note "..."]

The log is append-only and machine-readable (JSONL). It feeds pipeline
validation: weak runs should be traceable to tools used, source counts, etc.
"""
import argparse
import json
import os
from datetime import datetime, timezone

# research/scripts/log_run.py → research/deepsearch.log
LOG_PATH = os.path.join(os.path.dirname(__file__), "..", "deepsearch.log")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--query", required=True)
    ap.add_argument("--report", required=True)
    ap.add_argument("--sources", type=int, required=True)
    ap.add_argument("--tools", required=True)
    ap.add_argument("--note", default="")
    args = ap.parse_args()

    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "query": args.query,
        "report": args.report,
        "sources_used": args.sources,
        "tools": [t.strip() for t in args.tools.split(",") if t.strip()],
        "note": args.note,
    }

    log_dir = os.path.dirname(LOG_PATH)
    os.makedirs(log_dir, exist_ok=True)
    with open(LOG_PATH, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry) + "\n")
    print(f"logged → {os.path.relpath(LOG_PATH)}")


if __name__ == "__main__":
    main()