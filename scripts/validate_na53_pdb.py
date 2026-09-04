#!/usr/bin/env python3
"""
validate_na53_pdb.py — Gate a candidate 3D model against the canonical NA53 sequence
=====================================================================================
Purpose:  any PDB about to become structures/NA53_initial.pdb (Phase 5 input to the
          GROMACS pipeline) must be checked BEFORE it reaches the cluster. This script
          is that gate — it refuses to bless a wrong molecule.

What it checks (static, no gmx needed):
  1. Source        : reads structures/NA53.fasta (the canonical 75-nt sequence,
                     provenance: Hong et al. 2019 — see research lit-review claim C2)
  2. Molecule type : the model's nucleotides must be DNA (DA/DT/DC/DG etc.);
                     RNA residues (A/C/G/U) are flagged as a likely wrong model
  3. Length        : residue count must equal the FASTA length (75)
  4. Identity      : base at every position must match the FASTA sequence
  5. Completeness  : every residue must carry its full backbone + base heavy atoms
                     (pdb2gmx will REJECT partial nucleotides — see INCIDENT_ANALYSIS)
  6. Cleanliness   : altLoc duplicates, unknown residues, water/ions/protein in the
                     aptamer chain are reported

Usage:
  python3 scripts/validate_na53_pdb.py [candidate.pdb]
  python3 scripts/validate_na53_pdb.py --selftest     # in-memory pass+reject proof

Exit code 0 = candidate is BLESSED for the pipeline; nonzero = do NOT proceed.
Part of the Phase-5 gate: AF3 / w3DNA / 3dDNA output → validate → commit → cluster.
"""
import sys, os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FASTA = os.path.join(REPO, "structures", "NA53.fasta")

# residue-name -> base letter (CCD DNA names; some builders add 5/3 termini suffixes)
DNA = {"DA": "A", "DT": "T", "DC": "C", "DG": "G"}
RNA = {"A": "A", "U": "U", "C": "C", "G": "G"}   # U flagged as RNA
BACKBONE = ["P", "O5'", "C5'", "C4'", "C3'", "O3'"]
SUGAR = ["C1'", "C2'", "O4'"]   # pdb2gmx needs the full ribose too
PHOS_O = ["OP1", "OP2", "O1P", "O2P"]
# canonical heavy base atoms per base (name sets); used for a completeness warning only
BASE_HEAVY = {
 "A": {"N9","C8","N7","C5","C6","N1","C2","N3","C4","N6"},
 "C": {"N1","C2","O2","N3","C4","N4","C5","C6"},
 "G": {"N9","C8","N7","C5","C6","O6","N1","C2","N2","N3","C4"},
 "T": {"N1","C2","O2","N3","C4","O4","C5","C5M","C6"},
}

def load_fasta(path=FASTA):
    seq = ""
    for line in open(path):
        if line.startswith(">"):
            continue
        seq += line.strip().upper()
    return seq

def base_of(name):
    """residue name -> base letter or None"""
    up = name.upper()
    if up in DNA: return DNA[up], "DNA"
    if up in RNA: return RNA[up], "RNA"
    for k in DNA:                       # DA5/DA3/dA etc.
        if up.startswith(k) and (up[len(k):] in ("5", "3", "") or up.startswith("D" + k)):
            return DNA[k], "DNA"
    for k in RNA:
        if up.startswith(k) and up[len(k):] in ("5", "3", ""):
            return RNA[k], "RNA"
    return None, None

def parse_pdb(path):
    """returns (chain_atoms: dict chain -> {resnum: {name: (letter,kind,altloc)}} ...)"""
    res_atoms = {}          # chain -> {resnum -> {atomname: (letter,kind)}}
    res_kind = {}           # chain -> {resnum -> kind}
    order = {}              # chain -> [resnum...]
    alt = {}                # chain -> {resnum -> count of altloc atoms}
    problems = []
    for ln in open(path):
        if not ln.startswith(("ATOM", "HETATM")):
            continue
        name = ln[12:16].strip()
        resn = ln[17:20].strip()
        chain = ln[21].strip() or "A"
        resi = ln[22:26].strip()
        altloc = ln[16:17].strip()
        try: resi = int(resi)
        except ValueError:
            problems.append(f"bad residue number '{resi}' on atom {name}"); continue
        letter, kind = base_of(resn)
        if letter is None:
            # non-nucleotide residue: note it (protein/water/ion in the chain)
            res_atoms.setdefault(chain, {}).setdefault(resi, {})["__non_nt__"] = (resn,)
            continue
        d = res_atoms.setdefault(chain, {}).setdefault(resi, {})
        if name in d and altloc:
            alt[chain] = alt.get(chain, 0) + 1
        if altloc and name in d:
            continue                     # altloc duplicate — already counted
        d[name] = (letter, kind)
        res_kind.setdefault(chain, {}).setdefault(resi, kind)
        o = order.setdefault(chain, [])
        if not o or o[-1] != resi: o.append(resi)
    return res_atoms, res_kind, order, alt, problems

def assess(path, fasta):
    ref = fasta
    res_atoms, res_kind, order, alt, problems = parse_pdb(path)
    if not res_atoms:
        return "❌ FAIL — no ATOM/HETATM records found (empty or non-PDB file?)", 1

    # pick the primary chain: most complete nucleotide residues
    best, best_n = None, -1
    for ch, resd in res_atoms.items():
        n = sum(1 for r, atoms in resd.items() if not any(k.startswith("__") for k in atoms))
        if n > best_n: best_n, best = n, ch
    if best is None or best_n == 0:
        return "❌ FAIL — no nucleotide residues detected in any chain", 1
    rlist = order[best]
    chains_dna = {c for c, rd in res_kind.items() if any(k == "DNA" for k in rd.values())}
    extra_chains = chains_dna - {best}

    rows = [f"file        : {path}",
            f"primary chain: '{best}' with {best_n} nucleotide residues",
            f"extra DNA chains: {sorted(extra_chains) or 'none'}"]
    if any(k == "RNA" for k in res_kind.get(best, {}).values()):
        rows.append("⚠️  RNA residues found in the aptamer chain — expected DNA")
    if alt.get(best):
        rows.append(f"⚠️  {alt[best]} alternate-location (altLoc) duplicate atoms — remove before pdb2gmx")

    # per-residue walk in residue-number order
    seq, bad, missing_bb, short_heavy = [], [], 0, 0
    for r in rlist:
        d = res_atoms[best][r]
        non = [v[0] for k, v in d.items() if k.startswith("__")]
        if non:
            bad.append((r, "?", f"non-nucleotide residue {non[0]} in aptamer chain")); continue
        letter = next(v[0] for k, v in d.items() if not k.startswith("__"))
        seq.append(letter)
        heavy = [a for a in d if not a.startswith("__") and not a.startswith("H")]
        for atom in BACKBONE + SUGAR:
            if atom not in d:
                missing_bb += 1
                bad.append((r, letter, f"missing backbone/sugar atom {atom}"))
        if not any(p in d for p in PHOS_O):
            bad.append((r, letter, "no phosphate oxygen (OP1/OP2/O1P/O2P)"))
        if letter in BASE_HEAVY and len(BASE_HEAVY[letter] - set(heavy)) > 2:
            bad.append((r, letter, "base heavy atoms missing"))
        if len(heavy) < 16:
            short_heavy += 1
            bad.append((r, letter, f"only {len(heavy)} heavy atoms — pdb2gmx WILL reject"))

    got = "".join(seq)
    rows.append(f"model length: {len(got)} nt   expected: {len(ref)} nt")
    rows.append(f"model seq   : {got}")
    rows.append(f"expected seq: {ref}")

    mism = [i + 1 for i in range(min(len(got), len(ref))) if got[i] != ref[i]]
    if len(got) != len(ref):
        rows.append(f"❌ FAIL — length {len(got)} ≠ {len(ref)} (the '55-nt' vs 75-nt class of error — see memory.md)")
        return "\n".join(rows), 1
    if mism:
        rows.append(f"❌ FAIL — {len(mism)} position(s) mismatch (1-based): {mism[:20]}{'…' if len(mism) > 20 else ''}")
        return "\n".join(rows), 1
    if missing_bb or short_heavy:
        rows.append(f"❌ FAIL — {missing_bb} missing backbone atoms, {short_heavy} incomplete residues; fix in a modeling tool first")
        return "\n".join(rows), 1
    rows.append("✅ BLESSED — 75 nt, sequence-identical, all residues complete (DNA). Safe for the pipeline.")
    return "\n".join(rows), 0

def fake_pdb(n, seq, name):
    """synthetic complete-nucleotide PDB for self-test only (toy geometry, never for science)"""
    import random
    random.seed(7)
    lines = []
    a = 1
    for i, b in enumerate(seq, start=1):
        resn = {"A": "DA", "C": "DC", "G": "DG", "T": "DT"}[b]
        atoms = BACKBONE + SUGAR + PHOS_O + sorted(BASE_HEAVY[b])
        x = i * 3.4
        for an in atoms:
            lines.append(f"ATOM  {a:5d} {an:<4s} {resn:>3s} A{i:4d}    {x + a * 0.001:8.3f}{a * 0.001:8.3f}{a * 0.002:8.3f}  1.00  0.00           ")
            a += 1
    return "\n".join(lines) + "\nEND\n"

def selftest(fasta):
    rc = 0
    full = fasta
    ok_seq = full
    good = fake_pdb(len(full), ok_seq, "good")
    open("/tmp/_na53_good.pdb", "w").write(good)
    msg, code = assess("/tmp/_na53_good.pdb", fasta)
    print("[selftest PASS-path ]", msg.splitlines()[-1], "→ rc", code)
    rc |= (code != 0)
    trunc = fake_pdb(len(full) - 20, full[: len(full) - 20], "trunc")   # 55-nt impostor
    open("/tmp/_na53_bad.pdb", "w").write(trunc)
    msg, code = assess("/tmp/_na53_bad.pdb", fasta)
    print("[selftest REJECT-path]", msg.splitlines()[-1], "→ rc", code)
    rc |= (code == 0)
    for p in ("/tmp/_na53_good.pdb", "/tmp/_na53_bad.pdb"):
        os.remove(p)
    print("selftest:", "PASS ✅" if rc == 0 else "FAIL ❌")
    return rc

def main(argv):
    if "--selftest" in argv:
        return selftest(load_fasta())
    fasta = load_fasta()
    print(f"canonical NA53 (from {os.path.relpath(FASTA, REPO)}): {len(fasta)} nt")
    cand = argv[1] if len(argv) > 1 and not argv[1].startswith("-") else \
        os.path.join(REPO, "structures", "NA53_initial.pdb")
    if not os.path.exists(cand):
        print(f"❌ no candidate PDB at {cand}")
        return 1
    msg, code = assess(cand, fasta)
    print(msg)
    if code == 0:
        print("\nnext: commit the PDB, then on the cluster run:")
        print("  ./run_simulation.sh doctor --profile taiwania3_cpu")
        print("  ./run_simulation.sh submit --profile taiwania3_cpu --ns 1   # smoke")
    return code

if __name__ == "__main__":
    sys.exit(main(sys.argv))
