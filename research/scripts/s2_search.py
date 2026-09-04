#!/usr/bin/env python3
"""Keyless Semantic Scholar search + citation-graph tool for the deep search pipeline.

Pure Python stdlib — runs anywhere python3 exists (no uv / npx / API key).
Use it whenever the semantic-scholar MCP server is not available, and inside
the scholarly-literature stage of research/WORKFLOW.md (the Research SOP).

Modes (use exactly one):
  # 1. relevance search (may be rate-limited when the keyless pool is busy)
  python3 research/scripts/s2_search.py "aptamer docking molecular dynamics" --limit 8
  python3 research/scripts/s2_search.py "SELEX high-throughput sequencing" --year 2020-2026 --min-citations 20

  # 2. DOI metadata lookup — separate, more reliable keyless route; verify
  #    a paper's metadata (title/venue/year/citations/open access) before citing
  python3 research/scripts/s2_search.py --dois 10.3390/ijms21228420,10.1101/2024.05.23.594910

  # 3. author search (profiles: h-index, paper count) — keyless-friendly route
  python3 research/scripts/s2_search.py --author "Andrey Buglak"

  # 4. papers by an author (accepts an S2 authorId or a name — resolves the top hit)
  python3 research/scripts/s2_search.py --author-papers 5948648 --limit 15
  python3 research/scripts/s2_search.py --author-papers "Andrey Buglak" --limit 15

  # 5./6. citation graph — walk a paper's references (foundations) or the papers
  #    that cite it (who extended it). Accepts S2 paperId, DOI, arXiv:ID, ...
  python3 research/scripts/s2_search.py --refs 10.3390/ijms21228420 --limit 20
  python3 research/scripts/s2_search.py --cites 10.3390/ijms21228420 --limit 20

  # any mode can dump raw JSON
  python3 research/scripts/s2_search.py "aptamer biosensor" --sort citationCount --save hits.json

Optional: export SEMANTIC_SCHOLAR_API_KEY=<free key> for higher rate limits
(https://www.semanticscholar.org/product/api). Keyless shared pool ~100 req/5 min.

Output is metadata from the API only — verify a paper exists / read its full
text before adding it to research/REFERENCES.md.
"""
import argparse
import json
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://api.semanticscholar.org/graph/v1"
FIELDS = (
    "title,abstract,year,venue,publicationDate,citationCount,externalIds,"
    "url,openAccessPdf,fieldsOfStudy,authors.name"
)
AUTHOR_FIELDS = "name,authorId,affiliations,paperCount,citationCount,hIndex"
# Graph-list endpoints (references/citations, author papers) reject nested
# specs like authors.name — request the whole author objects instead.
GRAPH_FIELDS = (
    "title,abstract,year,venue,publicationDate,citationCount,externalIds,"
    "url,openAccessPdf,authors"
)


def get_json(url: str, args, headers: dict | None = None) -> dict:
    """GET a URL with rate-limit retry/backoff. Raises RuntimeError on failure."""
    hdrs = {"User-Agent": "deepsearch-pipeline/1.0"}
    key = os.environ.get("SEMANTIC_SCHOLAR_API_KEY", "").strip()
    if key:
        hdrs["x-api-key"] = key
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, headers=hdrs)
    delay = 2.0
    for attempt in range(args.max_retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=args.timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < args.max_retries:
                jitter = random.uniform(0, 1.0)
                wait = min(delay * (2 ** attempt) + jitter, 45.0)
                print(f"  ⏳ HTTP {e.code} — retrying in {wait:.0f}s "
                      f"(attempt {attempt + 1}/{args.max_retries})", file=sys.stderr)
                time.sleep(wait)
                continue
            if e.code == 429:
                raise RuntimeError(
                    "Rate limited by Semantic Scholar (HTTP 429). Wait a few minutes, "
                    "retry, or set a free SEMANTIC_SCHOLAR_API_KEY for higher limits."
                ) from e
            raise RuntimeError(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}") from e
        except urllib.error.URLError as e:
            if attempt < args.max_retries:
                time.sleep(min(delay * (2 ** attempt), 30.0))
                continue
            raise RuntimeError(f"Network error: {e.reason}") from e
    return {}  # unreachable


def paper_ref(identifier: str) -> str:
    """Normalize a paper identifier for /paper/<id> routes.
    Accepts S2 ids, DOI:…, arXiv:…, CorpusId:…, ACL:…, PMID:…, MAG:…, or a bare DOI."""
    ident = identifier.strip()
    scheme = ident.split(":", 1)[0].lower()
    if ":" in ident and scheme in {"doi", "arxiv", "corpus", "corpusid",
                                   "acl", "pmid", "mag", "s2", "paper"}:
        return ident
    if "/" in ident or ident.lower().startswith("10."):
        return "DOI:" + urllib.parse.quote(ident, safe="/.-()")
    return ident  # assume raw S2 paperId


def search(query: str, args) -> dict:
    params = {"query": query, "limit": str(args.limit), "fields": FIELDS}
    if args.year:
        params["year"] = args.year
    if args.min_citations:
        params["minCitationCount"] = str(args.min_citations)
    if args.fields_of_study:
        params["fieldsOfStudy"] = ",".join(args.fields_of_study)
    if args.sort:
        params["sort"] = args.sort
    url = f"{BASE}/paper/search?" + urllib.parse.urlencode(params)
    return get_json(url, args)


def lookup_dois(dois: list[str], args) -> list[dict]:
    """Papers by DOI (GET /paper/DOI:... — a reliable keyless route)."""
    hits: list[dict] = []
    for doi in dois:
        doi = doi.strip()
        if not doi:
            continue
        url = f"{BASE}/paper/{paper_ref(doi)}?fields={urllib.parse.quote(FIELDS, safe=',')}"
        try:
            paper = get_json(url, args)
        except RuntimeError as e:
            print(f"  ⚠️ {doi}: {e}", file=sys.stderr)
            continue
        if paper and "title" in paper:
            hits.append(paper)
        time.sleep(0.5)
    return hits


def author_search(name: str, args) -> dict:
    params = {"query": name, "limit": str(args.limit), "fields": AUTHOR_FIELDS}
    url = f"{BASE}/author/search?" + urllib.parse.urlencode(params)
    return get_json(url, args)


def resolve_author_name(name: str, args) -> tuple[str, str] | None:
    """Resolve a human name to the top (most-cited) S2 author profile."""
    data = author_search(name, args)
    rows = data.get("data", [])
    if not rows:
        return None
    rows.sort(key=lambda a: a.get("citationCount") or 0, reverse=True)
    top = rows[0]
    return top["authorId"], top.get("name") or name


def author_papers(author_id: str, args) -> dict:
    url = (f"{BASE}/author/{author_id}/papers"
           f"?fields={urllib.parse.quote(GRAPH_FIELDS, safe=',')}&limit={args.limit}")
    resp = get_json(url, args)
    papers = resp.get("data", [])
    return {"data": papers, "total": resp.get("total", len(papers))}


def graph(identifier: str, direction: str, args) -> dict:
    """references (foundations) or citations (extensions) of a paper.
    Returns dict with an unwrapped 'data' list of paper objects."""
    verb = "references" if direction == "refs" else "citations"
    url = (f"{BASE}/paper/{paper_ref(identifier)}/{verb}"
           f"?fields={urllib.parse.quote(GRAPH_FIELDS, safe=',')}&limit={args.limit}")
    resp = get_json(url, args)
    key = "citedPaper" if direction == "refs" else "citingPaper"
    papers = [item[key] for item in resp.get("data", []) if item.get(key)]
    return {"data": papers, "total": resp.get("total", len(papers))}


def show_papers(hits: list, source: str, total: int) -> None:
    print(f"Semantic Scholar — {len(hits)} of {total} shown (source: {source})")
    for i, p in enumerate(hits, 1):
        year = p.get("year") or p.get("publicationDate", "?")[:4] or "?"
        title = (p.get("title") or "").strip() or "<no title>"
        print(f"\n{i}. {title} ({year})")
        meta = []
        if p.get("venue"):
            meta.append(str(p["venue"]))
        if p.get("citationCount") is not None:
            meta.append(f"{p['citationCount']} citations")
        if meta:
            print("   " + " · ".join(meta))
        authors = [a.get("name") for a in p.get("authors", []) if a.get("name")]
        if authors:
            shown = ", ".join(authors[:6]) + (" …" if len(authors) > 6 else "")
            print(f"   Authors: {shown}")
        ext = p.get("externalIds") or {}
        if ext.get("DOI"):
            print(f"   DOI: {ext['DOI']}")
        oa = p.get("openAccessPdf") or {}
        if oa.get("url"):
            print(f"   Open access: {oa['url']}")
        elif p.get("url"):
            print(f"   S2 page: {p['url']}")

    if total == 0:
        print("\nNo matches. Broaden the query or drop --year/--min-citations filters.")
    else:
        print("\nHint: full text may be paywalled — check the DOI/Open-access URL. "
              "Only cite papers you actually read (research/REFERENCES.md).")


def show_authors(rows: list, source: str, total: int) -> None:
    print(f"Semantic Scholar — {len(rows)} of {total} authors shown (source: {source})")
    for i, a in enumerate(rows, 1):
        name = a.get("name") or "<no name>"
        affil = "; ".join(a.get("affiliations") or []) or "affiliation n/a"
        print(f"\n{i}. {name}  [authorId {a.get('authorId')}]")
        print(f"   {affil}")
        print(f"   papers: {a.get('paperCount')} · citations: {a.get('citationCount')}"
              f" · h-index: {a.get('hIndex')}")
    if total == 0:
        print("\nNo authors matched. Try a fuller name (e.g. 'Andrey Buglak').")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("query", nargs="?", help="relevance-search query (mode 1)")
    ap.add_argument("--dois", help="comma-separated DOI list to look up (mode 2)")
    ap.add_argument("--author", help="search author profiles by name (mode 3)")
    ap.add_argument("--author-papers", metavar="AUTHOR_ID_OR_NAME",
                    help="list papers of an author (mode 4); name auto-resolves to top hit")
    ap.add_argument("--refs", metavar="PAPER_ID_OR_DOI",
                    help="list papers a paper cites (mode 5)")
    ap.add_argument("--cites", metavar="PAPER_ID_OR_DOI",
                    help="list papers that cite a paper (mode 6)")
    ap.add_argument("--limit", type=int, default=10, help="max results (≤100, default 10)")
    ap.add_argument("--year", help="year filter, e.g. '2020-2026' or '2023-'")
    ap.add_argument("--min-citations", type=int, help="only papers cited ≥ N times")
    ap.add_argument("--fields-of-study", nargs="*",
                    help="e.g. Chemistry Biology Medicine Computer Science")
    ap.add_argument("--sort", choices=["relevance", "citationCount", "publicationDate"],
                    default="relevance", help="result ordering (default relevance)")
    ap.add_argument("--save", help="also write raw JSON results to this file")
    ap.add_argument("--timeout", type=int, default=30)
    ap.add_argument("--max-retries", type=int, default=5)
    args = ap.parse_args()

    modes = [bool(args.query), bool(args.dois), bool(args.author),
             bool(args.author_papers), bool(args.refs), bool(args.cites)]
    if sum(modes) != 1:
        ap.error("use exactly one of: QUERY, --dois, --author, --author-papers, --refs, --cites")

    if args.limit > 100:
        args.limit = 100

    try:
        source: str
        if args.query:
            data = search(args.query, args)
            hits, total, source = data.get("data", []), data.get("total", 0), f"query {args.query!r}"
            show_papers(hits, source, total)
        elif args.dois:
            hits = lookup_dois([d for d in args.dois.split(",") if d.strip()], args)
            source = "DOI lookup: " + args.dois
            show_papers(hits, source, len(hits))
        elif args.author:
            data = author_search(args.author, args)
            rows, total, source = (data.get("data", []), data.get("total", 0),
                                   f"author search {args.author!r}")
            show_authors(rows, source, total)
            hits = rows  # for --save
        elif args.author_papers:
            ref = args.author_papers.strip()
            # bare integer / 40-hex id → use as authorId; otherwise resolve by name
            if ref.isdigit() or (len(ref) == 40 and all(c in "0123456789abcdef" for c in ref)):
                aid, label = ref, f"authorId {ref}"
            else:
                resolved = resolve_author_name(ref, args)
                if not resolved:
                    raise RuntimeError(f"No Semantic Scholar author found for {ref!r}")
                aid, label = resolved
                print(f"→ resolved {ref!r} to {label} [authorId {aid}]")
            data = author_papers(aid, args)
            hits, total, source = data["data"], data["total"], f"papers by {label}"
            show_papers(hits, source, total)
        else:  # --refs or --cites
            target = args.refs or args.cites
            direction = "refs" if args.refs else "cites"
            kind = "references (foundations)" if direction == "refs" else "citations (extensions)"
            data = graph(target, direction, args)
            hits, total, source = data["data"], data["total"], f"{kind} of {target}"
            show_papers(hits, source, total)
    except RuntimeError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(2)

    if args.save:
        with open(args.save, "w", encoding="utf-8") as fh:
            json.dump({"mode": source, "total": total, "data": hits}, fh, indent=2)
        print(f"\nraw results saved → {args.save}")


if __name__ == "__main__":
    main()
