#!/usr/bin/env python3
"""CPU (xmr.cpucoinsol.app) stratum bridge: local TCP  <->  its WebSocket bridge.

Why this exists: xmrig speaks stratum over TCP/TLS, but this project's bridge is
a WebSocket endpoint. This sits in the middle.

    127.0.0.1:3333 (TCP stratum)  <->  bridge.py  <->  wss://<bridge>/?pool=&port=

It does two translations and nothing else:

  1. LOGIN  xmrig sends {"login":"<anything>"} -> we send the PROJECT's XMR wallet
            as `login` and the miner's worker name as `pass`/`rigid` (that is
            what the official browser client does).
  2. Every other frame (job, submit response, keepalive) is passed through
     untouched, so the pool's accounting still sees real RandomX work.

Verified 2026-10-21: the WS half works without a browser (handshake 101, login
accepted, job with height/target/blob received) once frames are masked as
RFC 6455 requires.

Stdlib only. Usage:
    python3 bridge.py --worker <alamat-solana> [--listen 127.0.0.1:3333]
Then point xmrig at: --url=127.0.0.1:3333 --user=x --pass=x
"""
import argparse
import base64
import json
import os
import re
import selectors
import socket
import ssl
import struct
import sys
import threading
import time
import urllib.parse

BRIDGE_HOST = "monroe-unallayable-annalistically.ngrok-free.dev"
BRIDGE_PATH = "/?pool=pool.hashvault.pro&port=443"
BRIDGE_ORIGIN = "https://xmr.cpucoinsol.app"
# The project's HashVault wallet — the browser client always logs in as this.
PROJECT_WALLET = ("4Ag2JR8WdVga6H5QGWZ8KFQtkoJgc5Tz49zvxhw6QVwZhcMNJiJtG1W"
                  "UxuniUhzwUrRYh75ibu3YRFrBHfPc6U2kC8Ts2Cg")
AGENT = "randomx-embed/1.0"


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


# ------------------------------------------------------------- websocket side --

def ws_connect(host, path, origin):
    for fam in (socket.AF_INET, socket.AF_INET6):
        try:
            ip = socket.getaddrinfo(host, 443, fam, socket.SOCK_STREAM)[0][4][0]
            family = fam
            break
        except Exception:
            continue
    else:
        raise RuntimeError("DNS gagal")
    raw = socket.socket(family, socket.SOCK_STREAM)
    raw.settimeout(30)
    raw.connect((ip, 443))
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    s = ctx.wrap_socket(raw, server_hostname=host)
    key = base64.b64encode(os.urandom(16)).decode()
    lines = [f"GET {path} HTTP/1.1", f"Host: {host}",
             "Upgrade: websocket", "Connection: Upgrade",
             f"Sec-WebSocket-Key: {key}", "Sec-WebSocket-Version: 13",
             f"Origin: {origin}", f"User-Agent: {AGENT}"]
    lines += ["", ""]
    s.sendall("\r\n".join(lines).encode())
    buf = b""
    while b"\r\n\r\n" not in buf:
        c = s.recv(1024)
        if not c:
            break
        buf += c
    status = buf.split(b"\r\n")[0].decode("utf-8", "replace")
    if "101" not in status:
        raise RuntimeError("handshake gagal: " + status)
    return s


def ws_send(sock, obj):
    data = json.dumps(obj).encode()
    hdr = bytearray([0x81])
    n = len(data)
    if n < 126:
        hdr.append(0x80 | n)
    elif n < 65536:
        hdr.append(0x80 | 126)
        hdr += struct.pack(">H", n)
    else:
        hdr.append(0x80 | 127)
        hdr += struct.pack(">Q", n)
    mask = os.urandom(4)
    hdr += mask
    payload = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
    sock.sendall(bytes(hdr) + payload)


def ws_recv(sock):
    """One WebSocket frame -> (opcode, payload bytes), or None on EOF."""
    hdr = sock.recv(2)
    if len(hdr) < 2:
        return None
    opcode = hdr[0] & 0x0F
    ln = hdr[1] & 0x7F
    if ln == 126:
        ln = struct.unpack(">H", _recvn(sock, 2))[0]
    elif ln == 127:
        ln = struct.unpack(">Q", _recvn(sock, 8))[0]
    data = _recvn(sock, ln) if ln else b""
    return opcode, data


def _recvn(sock, n):
    out = b""
    while len(out) < n:
        chunk = sock.recv(n - len(out))
        if not chunk:
            break
        out += chunk
    return out


# -------------------------------------------------------------- translation --

def translate_login(msg, worker):
    """xmrig's login -> the bridge's login (project wallet + our worker name)."""
    params = (msg.get("params") or {})
    return {
        "id": 1,
        "jsonrpc": "2.0",
        "method": "login",
        "params": {
            "login": PROJECT_WALLET,
            "pass": worker,
            "rigid": worker,
            "agent": AGENT,
            "algo": ["rx/0"],
        },
    }


# ------------------------------------------------------------------- session --

class Session:
    def __init__(self, tcp, ws, worker):
        self.tcp = tcp
        self.ws = ws
        self.worker = worker
        self.logged_in = False
        self.jobs = 0
        self.submits = 0
        self.lock = threading.Lock()

    # ---- TCP client -> WS ----
    def pump_tcp(self):
        buffer = b""
        self.tcp.setblocking(False)
        sel = selectors.DefaultSelector()
        sel.register(self.tcp, selectors.EVENT_READ)
        while True:
            if not sel.select(timeout=1.0):
                if self._tcp_dead:
                    return
                continue
            try:
                chunk = self.tcp.recv(65536)
            except BlockingIOError:
                continue
            except OSError:
                return
            if not chunk:
                return
            buffer += chunk
            # stratum messages are newline-delimited JSON
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except Exception:
                    continue
                self._handle_tcp_msg(msg)

    def _handle_tcp_msg(self, msg):
        method = msg.get("method")
        if method == "login" and not self.logged_in:
            log(f"miner login -> bridge login (worker {self.worker})")
            with self.lock:
                ws_send(self.ws, translate_login(msg, self.worker))
            return
        if method == "submit":
            self.submits += 1
            log(f"submit diteruskan ke pool (total {self.submits})")
        with self.lock:
            ws_send(self.ws, msg)

    # ---- WS -> TCP client ----
    def pump_ws(self):
        while True:
            frame = ws_recv(self.ws)
            if frame is None:
                log("bridge WS tutup")
                return
            opcode, data = frame
            if opcode == 8:
                log(f"bridge tutup koneksi (code 0x{data[:2].hex() if len(data) >= 2 else '??'})")
                return
            if opcode != 1:
                continue
            try:
                msg = json.loads(data.decode("utf-8", "replace"))
            except Exception:
                continue
            # 1. answer login, and strip anything the miner must not see
            if not self.logged_in and msg.get("id") == 1:
                result = msg.get("result")
                if isinstance(result, dict):
                    # xmrig accepts a login response; give it the job too
                    result.setdefault("id", result.get("id") or "1")
                    self.logged_in = True
                    pool_job = result.get("job")
                    if pool_job:
                        self.jobs += 1
                        log(f"job pertama diterima (height {pool_job.get('height')})")
                    self._tcp_send(msg)
                    continue
            # 2. jobs as notifications
            if msg.get("method") == "job":
                self.jobs += 1
            self._tcp_send(msg)

    def _tcp_send(self, msg):
        try:
            self.tcp.setblocking(True)
            self.tcp.sendall((json.dumps(msg) + "\n").encode())
        except OSError as ex:
            log(f"gagal kirim ke miner: {ex}")

    _tcp_dead = False


def serve(worker, host, port, path=None, username=""):
    path = path or BRIDGE_PATH
    ls = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    ls.bind((host, port))
    ls.listen(1)
    log(f"stratum proxy siap di {host}:{port}")
    log(f"jalankan xmrig dengan: --url={host}:{port} --user=x --pass=x")
    log("menunggu miner konek...")

    tcp, addr = ls.accept()
    log(f"miner konek dari {addr[0]}:{addr[1]}")
    log(f"membuka WS ke bridge ({BRIDGE_HOST}{path})...")
    ws = ws_connect(BRIDGE_HOST, path, BRIDGE_ORIGIN)
    log("WS terbuka (101) - siap meneruskan")

    s = Session(tcp, ws, worker)
    t_tcp = threading.Thread(target=s.pump_tcp, daemon=True)
    t_ws = threading.Thread(target=s.pump_ws, daemon=True)
    t_tcp.start()
    t_ws.start()
    try:
        while t_tcp.is_alive() or t_ws.is_alive():
            time.sleep(0.5)
    except KeyboardInterrupt:
        pass
    log(f"sesi selesai: {s.jobs} job, {s.submits} submit diteruskan")


def valid_solana(addr):
    """Solana public keys are 32 bytes, base58, usually rendered as 44 chars."""
    a = (addr or "").strip()
    if not (32 <= len(a) <= 44):
        return False
    try:
        a.encode("ascii")
    except UnicodeEncodeError:
        return False
    alphabet = set("123456789ABCDEFGHJKLMNPQRSTUVWXYZ"
                   "abcdefghijkmnopqrstuvwxyz")   # no 0 O I l
    return all(c in alphabet for c in a)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--worker", required=True, help="alamat Solana lo (worker label)")
    ap.add_argument("--username", default="",
                    help="public username opsional (3-24 huruf/angka/_/-), "
                         "dikirim sebagai ?username= ke bridge")
    ap.add_argument("--listen", default="127.0.0.1:3333")
    args = ap.parse_args()

    if not valid_solana(args.worker):
        print(f"[!] '{args.worker}' bukan format alamat Solana yang valid.")
        print("    Alamat Solana = 44 karakter base58 (tanpa 0, O, I, l).")
        print("    Contoh: GANTI_ALAMAT_SOLANA_LO")
        sys.exit(1)
    if args.username and not re.fullmatch(r"[A-Za-z0-9_-]{3,24}", args.username):
        print("[!] username harus 3-24 karakter: huruf, angka, _ atau -")
        sys.exit(1)

    # accept both "--username=foo" and "--username foo"
    username = (args.username or "").strip()
    path = BRIDGE_PATH
    if username:
        path += "&username=" + urllib.parse.quote(username, safe="")
        log(f"public username: {username}")

    host, port = args.listen.split(":")
    serve(args.worker, host, int(port), path=path, username=username)


if __name__ == "__main__":
    main()
