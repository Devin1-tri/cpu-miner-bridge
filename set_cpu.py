#!/usr/bin/env python3
"""Set xmrig's CPU allocation as a percentage of logical CPUs.

MINING.bat asks the operator how much CPU to give the miner and calls this
script with the chosen percentage. We edit only `cpu.max-threads-hint` in
config.json so everything else (pool, randomx mode, donate level) is untouched.

Usage: python set_cpu.py 50
"""
import json
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parent / "config.json"

# sensible defaults, one RandomX thread per physical core where possible
PRESETS = {
    25: "1 thread  - ringan, PC tetap enak dipakai",
    50: "2 thread  - seimbang",
    75: "3 thread  - agak berat",
    100: "4 thread  - maksimal untuk 4 core (sweet spot RandomX)",
}


def main():
    if len(sys.argv) < 2:
        print("pakai: set_cpu.py <persen>")
        return 1
    try:
        pct = int(sys.argv[1])
    except ValueError:
        print(f"[!] '{sys.argv[1]}' bukan angka")
        return 1
    if pct < 1 or pct > 100:
        print("[!] persen harus 1-100")
        return 1

    if not CONFIG.exists():
        print(f"[!] {CONFIG} tidak ada")
        return 1

    cfg = json.loads(CONFIG.read_text())
    cfg.setdefault("cpu", {})["max-threads-hint"] = pct
    # keep xmrig from rewriting our setting back on autosave
    cfg["autosave"] = False
    CONFIG.write_text(json.dumps(cfg, ensure_ascii=False, indent=2))

    threads_hint = PRESETS.get(pct, "")
    print(f"[+] CPU diatur ke {pct}% ({threads_hint})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
