#!/usr/bin/env python3
"""Compare the hand-transcribed inventory with executed pinned Rust descriptors."""
import argparse
import json
import math
from pathlib import Path


def flatten(rows):
    for row in rows:
        yield row
        yield from flatten(row.get("children", []))


def equal(a, b):
    if isinstance(a, (float, int)) and isinstance(b, (float, int)):
        return math.isclose(a, b, rel_tol=1e-6, abs_tol=1e-8)
    return a == b


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-dir", type=Path, default=Path("build/ntscrt-reference"))
    parser.add_argument("--schema", type=Path, default=Path("tools/ntscrt/ntsc_schema.json"))
    args = parser.parse_args()
    inventory = {d["id"]: d for d in flatten(json.loads(args.schema.read_text())["settings"])}
    descriptors = list(flatten(json.loads((args.reference_dir / "descriptors.json").read_text())))
    authoritative = {d["id"]: d for d in descriptors}
    defaults = json.loads((args.reference_dir / "defaults.json").read_text())
    errors = []
    if len(descriptors) != 62 or set(authoritative) != set(range(62)):
        errors.append("Reference does not contain exactly 62 unique IDs 0..61")
    if set(inventory) != set(authoritative):
        errors.append("Inventory/reference ID sets differ")
    for id_, ref in authoritative.items():
        item = inventory.get(id_, {})
        for key in ("name", "label", "type", "min", "max", "logarithmic", "options"):
            if key in ("min", "max") and ref["type"] == "percentage" and key not in item:
                continue  # Inventory typeNotes defines the implicit [0, 1] range.
            if key in ref and not equal(item.get(key), ref[key]):
                errors.append({"id": id_, "name": ref["name"], "field": key,
                               "inventory": item.get(key), "reference": ref[key]})
        if not equal(item.get("default"), defaults[ref["name"]]):
            errors.append({"id": id_, "name": ref["name"], "field": "default",
                           "inventory": item.get("default"), "reference": defaults[ref["name"]]})
    report = {"referenceCount": len(descriptors), "discrepancies": errors}
    (args.reference_dir / "schema-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
