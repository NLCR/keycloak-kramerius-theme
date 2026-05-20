#!/usr/bin/env python3
"""
Stáhne idp.xml z CDK a vygeneruje idps.json ve formátu pro Keycloak kramerius téma.

alias = SHA256(entityID)  ... pro zpětnou kompatibilitu s KC18
kc22alias = base64(entityID) ... pro KC22

Použití:
    python3 generate-idps.py
    python3 generate-idps.py --url https://jina-url/idp.xml --output muj-idps.json
"""

import urllib.request
import xml.etree.ElementTree as ET
import hashlib
import base64
import json
import argparse
import sys

NS = {
    "md":    "urn:oasis:names:tc:SAML:2.0:metadata",
    "mdui":  "urn:oasis:names:tc:SAML:metadata:ui",
}

def sha256hex(s):
    return hashlib.sha256(s.encode()).hexdigest()

def to_base64(s):
    return base64.b64encode(s.encode()).decode().rstrip("=")

def parse_idp_xml(url):
    print(f"Stahuji {url} ...", file=sys.stderr)
    with urllib.request.urlopen(url, timeout=30) as r:
        data = r.read()
    print(f"Staženo {len(data)} bytů", file=sys.stderr)

    root = ET.fromstring(data)

    # Projdi všechny EntityDescriptor (přímo nebo vnořené)
    entities = root.findall(".//md:EntityDescriptor", NS)
    if not entities:
        entities = root.findall("md:EntityDescriptor", NS)

    print(f"Nalezeno {len(entities)} entit", file=sys.stderr)

    results = []
    skipped = 0

    for entity in entities:
        entity_id = entity.get("entityID", "")
        if not entity_id:
            continue

        # Hledej DisplayName[lang=en]
        en_name = None
        for dn in entity.findall(".//mdui:DisplayName", NS):
            lang = dn.get("{http://www.w3.org/XML/1998/namespace}lang", "")
            if lang == "en":
                en_name = (dn.text or "").strip()
                break
        # Fallback na cs
        if not en_name:
            for dn in entity.findall(".//mdui:DisplayName", NS):
                en_name = (dn.text or "").strip()
                break

        # Hledej Logo (preferuj height=40, jinak první)
        logo_url = None
        logos = entity.findall(".//mdui:Logo", NS)
        for logo in logos:
            h = logo.get("height", "0")
            if h == "40" and logo.text:
                logo_url = logo.text.strip()
                break
        if not logo_url and logos:
            logo_url = (logos[0].text or "").strip() or None

        if not en_name:
            skipped += 1
            continue

        entry = {
            "alias":     sha256hex(entity_id),
            "kc22alias": to_base64(entity_id),
            "en-name":   en_name,
        }
        if logo_url:
            entry["logo"] = logo_url

        results.append(entry)

    print(f"Zpracováno: {len(results)}, přeskočeno (bez jména): {skipped}", file=sys.stderr)
    return results

def main():
    parser = argparse.ArgumentParser(description="Generuje idps.json z SAML metadata XML")
    parser.add_argument("--url", default="https://raw.githubusercontent.com/moravianlibrary/cdk-idp-list/main/idp.xml",
                        help="URL nebo cesta k idp.xml")
    parser.add_argument("--output", default="idps.json",
                        help="Výstupní soubor (default: idps.json)")
    args = parser.parse_args()

    # Podpora lokálního souboru
    if args.url.startswith("http"):
        results = parse_idp_xml(args.url)
    else:
        print(f"Čtu lokální soubor {args.url} ...", file=sys.stderr)
        with open(args.url, "rb") as f:
            data = f.read()
        root = ET.fromstring(data)
        args_url_backup = args.url
        args.url = args_url_backup
        # Reuse parse logic
        import io
        # Quick hack - just parse directly
        entities = root.findall(".//md:EntityDescriptor", NS)
        results = []
        for entity in entities:
            entity_id = entity.get("entityID", "")
            if not entity_id:
                continue
            en_name = None
            for dn in entity.findall(".//mdui:DisplayName", NS):
                if dn.get("{http://www.w3.org/XML/1998/namespace}lang", "") == "en":
                    en_name = (dn.text or "").strip()
                    break
            if not en_name:
                for dn in entity.findall(".//mdui:DisplayName", NS):
                    en_name = (dn.text or "").strip()
                    break
            if not en_name:
                continue
            logos = entity.findall(".//mdui:Logo", NS)
            logo_url = None
            for logo in logos:
                if logo.get("height", "0") == "40" and logo.text:
                    logo_url = logo.text.strip()
                    break
            if not logo_url and logos:
                logo_url = (logos[0].text or "").strip() or None
            entry = {"alias": sha256hex(entity_id), "kc22alias": to_base64(entity_id), "en-name": en_name}
            if logo_url:
                entry["logo"] = logo_url
            results.append(entry)

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"Uloženo {len(results)} záznamů do {args.output}", file=sys.stderr)

if __name__ == "__main__":
    main()
