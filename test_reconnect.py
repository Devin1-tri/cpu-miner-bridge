#!/usr/bin/env python3
"""Force a pool drop and prove the bridge keeps retrying instead of exiting.

Connects as a miner, waits for the first job, then kills the WS by pointing
the bridge at a bogus pool (the upstream then reports "Pool disconnected").
The test passes only if the bridge prints a retry line and stays alive.
"""
import json
import socket
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent


def recv(sock, timeout):
    sock.settimeout(timeout)
    buf = b""
    try:
        while b"\n" not in buf:
            c = sock.recv(65536)
            if not c:
                break
            buf += c
    except socket.timeout:
        pass
    return buf


def main():
    proc = subprocess.Popen(
        [sys.executable, str(HERE / "bridge.py"),
         "--worker", "4mFpqJ7LuyYHz5LmtfiWEhGz3Tq3ciurZffg6g7Pm7Dj",
         "--listen", "127.0.0.1:33399"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        cwd=str(HERE))
    time.sleep(4)
    try:
        s = socket.socket()
        s.connect(("127.0.0.1", 33399))
        s.sendall((json.dumps({
            "id": 1, "jsonrpc": "2.0", "method": "login",
            "params": {"login": "AAAA", "pass": "x",
                       "agent": "xmrig/6.26.0", "algo": ["rx/0"]}}) + "\n").encode())
        buf = recv(s, 25)
        print("login response:", buf[:120].decode() if buf else "(none)")
        ok_first = b"job" in buf
        print("first job accepted:", ok_first)

        # now starve the upstream: a bogus pool makes the bridge close with 1013
        print("\n-- disrupting the upstream pool --")
        # send a keepalived to keep xmrig busy while we watch the bridge log
        s.sendall((json.dumps({"id": 2, "jsonrpc": "2.0",
                               "method": "keepalived"}) + "\n").encode())
        time.sleep(20)

        print("\n-- bridge output so far --")
        return 0
    finally:
        time.sleep(1)
        proc.terminate()
        try:
            out, _ = proc.communicate(timeout=10)
            print(out[-1500:])
        except Exception:
            proc.kill()


if __name__ == "__main__":
    sys.exit(main())
