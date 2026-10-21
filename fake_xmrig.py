#!/usr/bin/env python3
"""Pretend to be xmrig: connect to bridge.py's TCP port and speak stratum.

This is the end-to-end proof that a native miner needs no browser: we send the
exact login packet xmrig sends, then read whatever the bridge relays back.
"""
import json
import socket
import sys
import time

HOST, PORT = "127.0.0.1", 33333


def recv_lines(sock, timeout=30):
    sock.settimeout(timeout)
    buf = b""
    out = []
    try:
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                if line.strip():
                    out.append(line.strip().decode())
    except socket.timeout:
        pass
    return out


def main():
    s = socket.socket()
    s.connect((HOST, PORT))
    print("connected to", f"{HOST}:{PORT}")

    # exactly the shape xmrig's first packet has
    login = {
        "id": 1,
        "jsonrpc": "2.0",
        "method": "login",
        "params": {
            "login": "AAAA",
            "pass": "x",
            "agent": "xmrig/6.21.0",
            "algo": ["rx/0"],
        },
    }
    print("sending login:", json.dumps(login))
    s.sendall((json.dumps(login) + "\n").encode())

    lines = recv_lines(s, timeout=35)
    if not lines:
        print("TIDAK ADA RESPON")
        return 1
    for line in lines[:6]:
        try:
            d = json.loads(line)
        except Exception:
            print("raw:", line[:160])
            continue
        if "result" in d:
            r = d["result"]
            print("LOGIN RESPONSE diterima")
            job = r.get("job")
            if job:
                print("  job_id  :", job.get("job_id"))
                print("  height  :", job.get("height"))
                print("  target  :", job.get("target"))
                print("  seed    :", (job.get("seed_hash") or "")[:24], "...")
                print("  blob    :", len(job.get("blob", "")), "hex chars")
                print("\nSUKSES: miner native bisa dapat work tanpa browser.")
                return 0
            print("  result  :", json.dumps(r)[:200])
        elif "error" in d:
            print("ERROR:", json.dumps(d["error"])[:200])
            return 2
        elif d.get("method") == "job":
            p = d["params"]
            print("JOB (notif):", p.get("job_id"), "height", p.get("height"))
            return 0
        else:
            print("msg:", json.dumps(d)[:160])
    return 0


if __name__ == "__main__":
    sys.exit(main())
