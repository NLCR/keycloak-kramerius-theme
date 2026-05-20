#!/usr/bin/env python3
"""
Porovná dva idps.json soubory a uloží do diff_idps.json záznamy,
které jsou v ./idps.json ale chybí v ./src/main/resources/idps.json

Porovnává podle alias (SHA256) i kc22alias (base64).

Použití:
    python3 diff-idps.py
    python3 diff-idps.py --source ./src/main/resources/idps.json --new ./idps.json --output ./diff_idps.json
"""

import json
import argparse
import sys

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def main():
    parser = argparse.ArgumentParser(description="Porovná dva idps.json a vypíše chybějící záznamy")
    parser.add_argument("--source", default="./src/main/resources/idps.json",
                        help="Zdrojový soubor (referenční)")
    parser.add_argument("--new",    default="./idps.json",
                        help="Nový soubor (ze kterého hledáme chybějící)")
    parser.add_argument("--output", default="./diff_idps.json",
                        help="Výstupní soubor s chybějícími záznamy")
    args = parser.parse_args()

    print(f"Načítám zdrojový:  {args.source}", file=sys.stderr)
    source = load(args.source)
    print(f"Načítám nový:      {args.new}", file=sys.stderr)
    new = load(args.new)

    # Sestav sadu všech známých aliasů ze zdrojového souboru
    known = set()
    for entry in source:
        if entry.get("alias"):     known.add(entry["alias"])
        if entry.get("kc22alias"): known.add(entry["kc22alias"])

    print(f"Zdrojový má {len(source)} záznamů ({len(known)} unikátních aliasů)", file=sys.stderr)
    print(f"Nový má     {len(new)} záznamů", file=sys.stderr)

    # Najdi záznamy z nového souboru které nejsou ve zdrojovém
    missing = []
    for entry in new:
        alias     = entry.get("alias", "")
        kc22alias = entry.get("kc22alias", "")
        if alias not in known and kc22alias not in known:
            missing.append(entry)

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(missing, f, ensure_ascii=False, indent=2)

    print(f"\nChybějící záznamy: {len(missing)}", file=sys.stderr)
    print(f"Uloženo do:        {args.output}", file=sys.stderr)

    if missing:
        print("\nChybějící instituce:", file=sys.stderr)
        for e in missing:
            print(f"  - {e.get('en-name', '?')}  [{e.get('alias','')[:16]}...]", file=sys.stderr)

if __name__ == "__main__":
    main()
