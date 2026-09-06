#!/bin/bash
# ============================================================
# gmx_energy_lib.sh — Runtime energy-term lookup for `gmx energy`
# GROMACS_NA53
# ============================================================
# WHY THIS EXISTS
#   gmx energy term IDs are NOT stable across .edr files. The
#   numbered list printed by `gmx energy` depends on which terms
#   that particular run wrote to its .edr (e.g. NVT runs with
#   position restraints insert an extra `Position-Rest.` entry,
#   shifting every later term by one). Hardcoding IDs (23/24/36
#   etc.) caused the Density/Pressure/Potential mis-extraction
#   bug class THREE times in this project (V-class incidents).
#
#   Correct approach: ask each .edr for its own numbered term
#   list, then look the desired term up BY NAME.
#
# Usage (source this file, then):
#   gmx_energy_id      <file.edr> <Term-Name>   # prints numeric id
#   gmx_energy_extract <file.edr> <out.xvg> <Term-Name>
# ============================================================

# gmx_energy_id <edr> <Term-Name>
# Prints the numeric term id for <Term-Name> in <edr>, or nothing
# (exit 1) if not found / file missing.
gmx_energy_id() {
    local edr="$1" want="$2" id
    [ -f "$edr" ] || { echo "gmx_energy_id: no such file: $edr" >&2; return 1; }
    # Feeding "0" makes `gmx energy` print its numbered term list (to
    # STDERR) and exit — merge 2>&1 so the list reaches the parser.
    id=$(printf "0\n" | gmx energy -f "$edr" -o /dev/null 2>&1 | \
        awk -v want="$want" '
            /^ *[0-9]+/ {
                n = split($0, tok, / +/)
                for (i = 1; i <= n; ) {
                    if (tok[i] ~ /^[0-9]+$/ && i + 1 <= n) {
                        num = tok[i]
                        nm  = tok[i + 1]
                        sub(/\.$/, "", nm)        # "Conserved-En." -> "Conserved-En"
                        if (nm == want) { print num; exit }
                        i += 2
                    } else {
                        i++
                    }
                }
            }')
    [ -n "$id" ] || { echo "gmx_energy_id: term '$want' not found in $edr" >&2; return 1; }
    echo "$id"
}

# gmx_energy_extract <edr> <out.xvg> <Term-Name>
# Extracts one named energy term from <edr> into <out.xvg>.
gmx_energy_extract() {
    local edr="$1" out="$2" name="$3" id
    id=$(gmx_energy_id "$edr" "$name") || return 1
    printf "%s\n0\n" "$id" | gmx energy -f "$edr" -o "$out" >/dev/null 2>&1 \
        || { echo "gmx_energy_extract: gmx energy failed for '$name' ($edr)" >&2; return 1; }
    echo "  ✓ $out  (term $id = $name from $(basename "$edr"))"
}
