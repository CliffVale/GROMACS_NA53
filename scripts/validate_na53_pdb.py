#!/usr/bin/env python3
"""
validate_na53_pdb.py — Gate + STAGE a candidate 3D model against canonical NA53
=====================================================================================
Purpose:  any PDB about to become structures/NA53_initial.pdb (Phase 5 input to the
          GROMACS pipeline) must be checked BEFORE it reaches the cluster.

Two modes (APTAMD-style automated "edition", adapted from do_aptamer_edition's
clean-and-verify philosophy — see docs/APTAMD_DEEP_ANALYSIS.md addendum 2026-09-04):

  1. VALIDATE (default): static checks only, never writes:
       python3 scripts/validate_na53_pdb.py candidate.pdb
     Checks molecule type (DNA), length (75), per-position identity vs the
     canonical FASTA, residue completeness (pdb2gmx rejects partial
     nucleotides), and cleanliness (altLoc/water/protein/extra chains).

  2. STAGE (--stage): raw-modeler-output -> clean -> bless -> write in place:
       python3 scripts/validate_na53_pdb.py --stage /path/raw_af3.pdb
     This is the one command that turns ANY raw output (AlphaFold 3 / w3DNA /
     3dDNA) into the blessed structures/NA53_initial.pdb the sbatch chain needs:
       * keeps only the first MODEL (AF3 emits one by default)
       * keeps nucleotide ATOM/HETATM records only (drops water/ions/protein/
         ligands), normalises DA/DT/DC/DG and single-letter A/T/C/G to DNA names
       * resolves alternate-location duplicates (keeps highest occupancy),
         drops hydrogens (pdb2gmx -ignh rebuilds them)
       * renumbers residues contiguously 1..N and merges stray chains
         (NA53 is ONE ssDNA strand — multi-chain AF3 artifacts are merged)
       * writes to a temp file, re-validates the CLEANED result, and only then
         atomically replaces structures/NA53_initial.pdb — a failed stage never
         leaves a bad file behind

Exit code 0 = candidate is BLESSED for the pipeline; nonzero = do NOT proceed.
Part of the Phase-5 gate: AF3 output -> --stage -> commit -> cluster run.
"""
import sys, os, re, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FASTA = os.path.join(REPO, "structures", "NA53.fasta")
DEFAULT_OUT = os.path.join(REPO, "structures", "NA53_initial.pdb")

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
CANON = {"A": "DA", "T": "DT", "C": "DC", "G": "DG"}


def load_fasta(path=FASTA):
    seq = ""
    for line in open(path):
        if line.startswith(">"):
            continue
        seq += line.strip().upper()
    return seq


def base_of(name):
    """residue name -> (base letter, kind) or (None, None)"""
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


def nt_canonical(resn):
    """For STAGING: map any nucleotide residue name -> canonical DNA 3-letter or None.
    Single letters A/T/C/G are treated as DNA (NA53 is a DNA aptamer; AF3 and the
    w3DNA/3dDNA builders emit DA/DT/DC/DG, but a stray single-letter tool must not
    hard-fail the edition step). Uridine -> None (RNA = wrong molecule)."""
    up = resn.upper()
    if up in DNA: return up
    if up in ("A", "T", "C", "G"): return CANON[up]
    for k in DNA:
        if up.startswith(k) and up[len(k):] in ("5", "3", ""):
            return k
    if up in RNA or (len(up) == 1 and up == "U"):
        return None          # RNA residue in a DNA model -> reject at stage
    return None              # not a nucleotide at all


def parse_pdb(path):
    """returns (chain_atoms, res_kind, order, alt, problems) — see assess()"""
    res_atoms = {}
    res_kind = {}
    order = {}
    alt = {}
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
            res_atoms.setdefault(chain, {}).setdefault(resi, {})["__non_nt__"] = (resn,)
            continue
        d = res_atoms.setdefault(chain, {}).setdefault(resi, {})
        if name in d and altloc:
            alt[chain] = alt.get(chain, 0) + 1
        if altloc and name in d:
            continue
        d[name] = (letter, kind)
        res_kind.setdefault(chain, {}).setdefault(resi, kind)
        o = order.setdefault(chain, [])
        if not o or o[-1] != resi: o.append(resi)
    return res_atoms, res_kind, order, alt, problems



def cif_atom_lines(path):
    """Convert an mmCIF atom_site loop into standard PDB-format ATOM lines.
    Handles AF3 output specifically (DNA chains, CIF-quoted atom names like
    "O5'", label/auth ids, single model). Stdlib only — no biopython needed.
    Returns (lines, notes) where notes collects sanitisation reports."""
    lines = open(path).read().splitlines()
    start, cols = None, []
    for i, l in enumerate(lines):
        if l.strip() == "loop_":
            j, cc = i + 1, []
            while j < len(lines) and lines[j].strip().startswith("_"):
                cc.append(lines[j].strip()); j += 1
            if any("_atom_site." in c for c in cc):
                start, cols = j, cc
                break
    if start is None:
        raise ValueError("no _atom_site loop found — not an mmCIF file?")
    ci = {}
    for c in cols:
        key = c.split(".")[-1]
        ci[key] = len(ci)
    need = ["group_PDB", "label_atom_id", "label_comp_id", "label_asym_id",
            "Cartn_x", "Cartn_y", "Cartn_z", "auth_seq_id"]
    for k in need:
        if k not in ci:
            raise ValueError(f"mmCIF missing _atom_site.{k}")
    def unquote(v):
        v = v.strip()
        if len(v) >= 2 and v[0] in ("'", '"') and v[-1] == v[0]:
            return v[1:-1]
        return v
    out, notes = [], []
    # keep only the first MODEL block if the file has multiple
    model_seen = False
    rows = 0
    for l in lines[start:]:
        t = l.strip()
        if not t or t.startswith("#"):
            continue
        if t.startswith("loop_") or t.startswith("_"):
            break
        f = l.split()
        if len(f) < len(need):
            continue
        if "pdbx_PDB_model_num" in ci and f[ci["pdbx_PDB_model_num"]].strip() not in (".", "1"):
            continue
        model_seen = True
        g = f[ci["group_PDB"]]
        if g != "ATOM" and g != "HETATM":
            continue
        name = unquote(f[ci["label_atom_id"]])
        resn = unquote(f[ci["label_comp_id"]])
        chain = unquote(f[ci["label_asym_id"]]) or "A"
        seqid = f[ci["auth_seq_id"]]
        try:
            resi = int(seqid)
        except ValueError:
            notes.append(f"skipped atom {name} with non-integer seq id {seqid}")
            continue
        x, y, z = f[ci["Cartn_x"]], f[ci["Cartn_y"]], f[ci["Cartn_z"]]
        occ = f[ci["occupancy"]] if "occupancy" in ci else "1.00"
        b = f[ci["B_iso_or_equiv"]] if "B_iso_or_equiv" in ci else "0.00"
        el = f[ci["type_symbol"]] if "type_symbol" in ci else name[:1]
        # AF3 puts a 5'-triphosphate (OP3 P OP1 OP2) on residue 1 — amber DNA
        # force fields (DA5) only support a monophosphate. Drop the single gamma
        # oxygen OP3 and report it; OP1/OP2/P stay as the standard DA5 phosphate.
        if name == "OP3":
            notes.append("dropped OP3 (AF3 5'-triphosphate -> amber 5'-monophosphate, DA5 terminus)")
            continue
        # PDB columns: name left-just 4 in 13-16; resn right-just 3 in 18-20;
        # chain col 22; resSeq right-just 4 in 23-26; x/y/z 8.3 in 31-54;
        # occ/B 6.2 in 55-66; element right-just 2 in 77-78.
        try:
            out.append(f"ATOM  {rows + 1:5d} {name:<4s} {resn:>3s} {chain:1s}{resi:4d}    "
                       f"{float(x):8.3f}{float(y):8.3f}{float(z):8.3f}"
                       f"{float(occ):6.2f}{float(b):6.2f}          {el:>2s}")
        except ValueError:
            notes.append(f"skipped atom {name}: non-numeric coordinate/occupancy")
            continue
        rows += 1
    if not out:
        raise ValueError("no ATOM rows converted from mmCIF")
    return out, notes


def _emit_staged(raw_path, out_path):
    """Stage raw_path -> out_path (atomic). Returns (report_lines, exit_code)."""
    report = [f"── STAGING {os.path.basename(raw_path)} ──"]
    if raw_path.lower().endswith(".cif"):
        try:
            cif_lines, cif_notes = cif_atom_lines(raw_path)
        except Exception as e:
            return report + [f"❌ mmCIF conversion failed: {e}"], 1
        report += [f"ℹ  converted mmCIF -> PDB records ({len(cif_lines)} atoms)"] + \
                   ["ℹ  " + n for n in cif_notes]
        lines = cif_lines
    else:
        lines = open(raw_path).read().splitlines()
    keep = []
    in_model = None
    dropped = {"water": 0, "non-nt": 0, "hydrogen": 0, "altloc": 0, "rna": 0}
    # MODEL handling: AF3/ensembles emit MODEL/ENDMDL blocks. We want ONLY the
    # first model, so: records before any MODEL are ignored once a MODEL appears;
    # parsing stops at the first ENDMDL. Plain single-structure PDBs (no MODEL
    # records) pass through untouched. NOTE: never compare atom serials to the
    # model number — the serial field overlaps the model column (bug fixed
    # 2026-09-04 after the stage selftest dropped all atoms past serial 9).
    for ln in lines:
        if ln.startswith("MODEL"):
            if in_model is None:
                in_model = True
            continue
        if ln.startswith("ENDMDL") and in_model:
            break
        if not ln.startswith(("ATOM", "HETATM")):
            continue
        name = ln[12:16].strip(); resn = ln[17:20].strip()
        chain = ln[21].strip() or "A"
        try: resi = int(ln[22:26].strip())
        except ValueError: continue
        altloc = ln[16:17].strip()
        try: occ = float(ln[54:60].strip() or "1.0")
        except ValueError: occ = 1.0
        canon = nt_canonical(resn)
        if canon is None:
            if resn.upper() in ("HOH", "WAT", "SOL"): dropped["water"] += 1
            elif base_of(resn)[1] == "RNA": dropped["rna"] += 1
            else: dropped["non-nt"] += 1
            continue
        if name.upper().startswith("H"):
            dropped["hydrogen"] += 1; continue
        keep.append([canon, name, chain, resi, altloc, occ, ln])
    if not keep:
        return report + ["❌ FAIL — no nucleotide atoms in file (empty, non-PDB, or RNA-only?)"], 1

    # altLoc: highest occupancy per (chain, resi, atomname)
    best = {}
    for r in keep:
        key = (r[2], r[3], r[1])
        if key not in best or (r[4] and r[5] > best[key][5]):
            best[key] = r
    dropped["altloc"] = len(keep) - len(best)
    keep = sorted(best.values(), key=lambda r: (r[2], r[3], r[1]))
    n_alt = dropped["altloc"]

    # emit cleaned PDB with contiguous 1..N numbering, single chain A.
    # (residue counter advances ONLY when the source residue changes — a
    # per-atom counter here was a real bug: every atom became its own residue)
    out, seq_chars = [], []
    chains_seen = []
    serial = 1
    res_count, prev_resi = 0, None
    for r in keep:
        canon, name, chain, resi, altloc, occ, raw = r
        if chain not in chains_seen:
            chains_seen.append(chain)
        if resi != prev_resi:
            res_count += 1
            prev_resi = resi
            seq_chars.append(DNA[canon])
        x, y, z = raw[30:38], raw[38:46], raw[46:54]
        el = raw[76:78].strip() or name[:1]
        out.append(f"ATOM  {serial:5d} {name:<4s} {canon:>3s} A{res_count:4d}    {x:>8s}{y:>8s}{z:>8s}  1.00  0.00          {el:>2s}")
        serial += 1
    if len(chains_seen) > 1:
        report.append(f"ℹ  merged {len(chains_seen)} chains ({','.join(chains_seen)}) into one strand")
    if n_alt:
        report.append(f"ℹ  resolved {n_alt} altLoc duplicate atom(s) — kept highest occupancy")
    for what, n in (("water", dropped["water"]), ("non-nucleotide", dropped["non-nt"]),
                    ("hydrogen", dropped["hydrogen"]), ("RNA", dropped["rna"])):
        if n:
            report.append(f"ℹ  dropped {n} {what} record(s)")

    # atomic write to temp, validate CLEANED file, then replace target only if blessed
    d = os.path.dirname(os.path.abspath(out_path)) or "."
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".na53_stage_", suffix=".pdb", dir=d)
    try:
        with os.fdopen(fd, "w") as f:
            f.write("REMARK  NA53 staged from " + os.path.basename(raw_path) + "\n")
            f.write("\n".join(out) + "\nEND\n")
        msg, code = assess(tmp, load_fasta())
        if code == 0:
            os.replace(tmp, out_path)
            report.append(f"✅ BLESSED + STAGED -> {os.path.relpath(out_path, REPO)} ({len(seq_chars)} nt)")
        else:
            os.unlink(tmp)
            report.append("❌ CLEANED MODEL FAILED VALIDATION — target file NOT written (nothing staged).")
            report.append("   Verdict on the cleaned model:")
            report += ["   " + l for l in msg.splitlines()]
    except Exception as e:
        report.append(f"❌ staging error: {e}")
        return report, 1
    return report, code


def assess(path, fasta):
    ref = fasta
    res_atoms, res_kind, order, alt, problems = parse_pdb(path)
    if not res_atoms:
        return "❌ FAIL — no ATOM/HETATM records found (empty or non-PDB file?)", 1
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


def fake_pdb(n, seq, name, messy=False):
    """synthetic PDB for self-test only (toy geometry, never for science).
    messy=True adds MODEL/ENDMDL, a water, an altLoc duplicate, and a protein atom."""
    lines = []
    if messy:
        lines += ["HEADER    SYNTHETIC", "MODEL        1"]
    a = 1
    for i, b in enumerate(seq, start=1):
        resn = {"A": "DA", "C": "DC", "G": "DG", "T": "DT"}[b]
        atoms = BACKBONE + SUGAR + PHOS_O + sorted(BASE_HEAVY[b])
        for k, an in enumerate(atoms):
            x = i * 3.4
            lines.append(f"ATOM  {a:5d} {an:<4s} {resn:>3s} A{i:4d}    {x + a * 0.001:8.3f}{a * 0.001:8.3f}{a * 0.002:8.3f}  1.00  0.00           ")
            if messy and an == "P":       # altLoc duplicate of the P atom (B conformer)
                lines.append(f"ATOM  {a + 500:5d} {an:<4s} {resn:>3s} A{i:4d}B   {x + a * 0.002:8.3f}{a * 0.001:8.3f}{a * 0.002:8.3f}  0.60  0.00           ")
            a += 1
    if messy:
        lines += ["ATOM    999  CA  GLY A  99       1.000   1.000   1.000  1.00  0.00           C",
                  "HETATM 1000  O   HOH A 200       2.000   2.000   2.000  1.00  0.00           O",
                  "ENDMDL"]
    else:
        lines.append("END")
    return "\n".join(lines) + "\n"


def selftest(fasta):
    rc = 0
    full = fasta
    # --- validate pass/reject paths (unchanged behavior) ---
    good = fake_pdb(len(full), full, "good")
    open("/tmp/_na53_good.pdb", "w").write(good)
    msg, code = assess("/tmp/_na53_good.pdb", fasta)
    print("[validate PASS-path ]", msg.splitlines()[-1], "→ rc", code)
    rc |= (code != 0)
    trunc = fake_pdb(len(full) - 20, full[: len(full) - 20], "trunc")   # 55-nt impostor
    open("/tmp/_na53_bad.pdb", "w").write(trunc)
    msg, code = assess("/tmp/_na53_bad.pdb", fasta)
    print("[validate REJECT-path]", msg.splitlines()[-1], "→ rc", code)
    rc |= (code == 0)
    # --- staging pass path: messy raw input must clean+reorder to 75 nt ---
    raw = fake_pdb(len(full), full, "raw", messy=True)
    open("/tmp/_na53_raw_messy.pdb", "w").write(raw)
    rep, code = _emit_staged("/tmp/_na53_raw_messy.pdb", "/tmp/_na53_staged.pdb")
    ok_stage = code == 0 and os.path.exists("/tmp/_na53_staged.pdb")
    print("[stage   PASS-path ] cleaned → rc", code, "| staged file exists:", os.path.exists("/tmp/_na53_staged.pdb"))
    rc |= (not ok_stage)
    if ok_stage:
        msg, code2 = assess("/tmp/_na53_staged.pdb", fasta)
        print("[stage re-validate ]", msg.splitlines()[-1], "→ rc", code2)
        rc |= (code2 != 0)
        bad_atoms = [l for l in open("/tmp/_na53_staged.pdb")
                     if l.startswith("ATOM") and ("GLY" in l or "HOH" in l or l[16:17].strip())]
        if bad_atoms:
            print("❌ staged file still contains water/protein/altLoc — sanitize failed")
            rc |= 1
        n = sum(1 for l in open("/tmp/_na53_staged.pdb") if l.startswith("ATOM"))
        resnums = sorted({int(l[22:26]) for l in open("/tmp/_na53_staged.pdb") if l.startswith("ATOM")})
        if resnums != list(range(1, 76)):
            print(f"❌ staged residue numbering not contiguous 1..75: first={resnums[:3]} last={resnums[-3:]}")
            rc |= 1
        print(f"[stage   file check ] {n} atoms, {len(resnums)} residues numbered 1..75 ✅")
    # --- staging reject path: staged output must NOT remain on failure ---
    rep, code = _emit_staged("/tmp/_na53_bad.pdb", "/tmp/_na53_must_not_exist.pdb")
    if code == 0 or os.path.exists("/tmp/_na53_must_not_exist.pdb"):
        print("[stage   REJECT-path] FAIL — bad molecule got staged")
        rc |= 1
    else:
        print("[stage   REJECT-path] 24-nt impostor correctly rejected, no file left behind → rc", code)
    for p in ("/tmp/_na53_good.pdb", "/tmp/_na53_bad.pdb", "/tmp/_na53_raw_messy.pdb",
              "/tmp/_na53_staged.pdb", "/tmp/_na53_must_not_exist.pdb"):
        if os.path.exists(p): os.remove(p)
    print("selftest:", "PASS ✅" if rc == 0 else "FAIL ❌")
    return rc


def main(argv):
    if "--selftest" in argv:
        return selftest(load_fasta())
    if "--stage" in argv:
        i = argv.index("--stage")
        if i + 1 >= len(argv):
            print("usage: validate_na53_pdb.py --stage RAW_MODEL.pdb [--out structures/NA53_initial.pdb]")
            return 2
        raw = argv[i + 1]
        out = DEFAULT_OUT
        if "--out" in argv:
            out = argv[argv.index("--out") + 1]
        if not os.path.exists(raw):
            print(f"❌ raw model not found: {raw}")
            return 1
        report, code = _emit_staged(raw, out)
        print("\n".join(report))
        return code
    fasta = load_fasta()
    print(f"canonical NA53 (from {os.path.relpath(FASTA, REPO)}): {len(fasta)} nt")
    cand = argv[1] if len(argv) > 1 and not argv[1].startswith("-") else DEFAULT_OUT
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
