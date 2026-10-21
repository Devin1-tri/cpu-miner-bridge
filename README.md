# CPU Miner Bridge — `xmr.cpucoinsol.app` tanpa browser

Menjalankan mining `$CPU` langsung dari **xmrig native** di Windows, tanpa
membuka browser. `bridge.py` jadi jembatan di tengah karena xmrig ngomong
stratum **TCP**, sedangkan project ini cuma menyediakan **WebSocket**.

```
xmrig (TCP)  ──►  bridge.py  ──►  wss://…ngrok-free.dev/?pool=pool.hashvault.pro&port=443
 127.0.0.1:3333      (WS client)          (RandomX pool)
```

## Isi folder

| File | Guna |
|---|---|
| `bridge.py` | jembatan WS ↔ TCP. Terjemahkan login xmrig jadi login bridge |
| `config.json` | konfigurasi xmrig, sudah diarahkan ke `127.0.0.1:3333` |
| `start-mining.bat` | menjalankan bridge + xmrig sekaligus |
| `fake_xmrig.py` | tes: pura-pura jadi miner, buktikan bridge meneruskan paket |

## Cara pakai di Windows

1. **Download xmrig** dari github.com/xmrig/xmrig/releases (versi Windows).
   Taruh `xmrig.exe` di folder yang sama dengan `bridge.py`
2. Pastikan **Python** terpasang (python.org, centang "Add to PATH")
3. Edit `start-mining.bat` → ganti `WORKER` dengan **alamat Solana lo**
4. Dobel-klik `start-mining.bat`

xmrig akan nyambung ke `127.0.0.1:3333` → bridge → bridge → pool. Nggak ada
browser sama sekali.

## Kalau mau jalankan manual (dua terminal)

```bash
python bridge.py --worker <ALAMAT_SOLANA_LO>
```
```bash
xmrig.exe --config=config.json
```

## Yang sudah diverifikasi

- WS bridge hidup: handshake `101`, login diterima, job diterima
- **Masking frame wajib** (RFC 6455) — tanpa itu server menutup koneksi
  dengan close code `1002`. Ini bedanya koneksi berhasil vs gagal
- `bridge.py` menerima koneksi xmrig, menerjemahkan login, dan meneruskan
  paket job utuh ke miner (diuji dengan `fake_xmrig.py`: job_id, height,
  target, seed_hash, blob 152 hex chars diterima)
- Alamat Solana 44 karakter base58 = format yang benar untuk worker name
  (Monero itu 95 karakter — jangan ketuker)

## Yang perlu lo tahu sebelum menjalankan

**XMR masuk ke wallet project, bukan ke lo.** Login selalu memakai wallet XMR
project (`4Ag2JR8W…Ts2Cg`), itu memang desain mereka:

> "The project receives the XMR pool proceeds; miners receive no XMR."
> — xmr.cpucoinsol.app

Yang lo dapat adalah token **`$CPU` di Solana**, dihitung dari *pool-accepted
work*. Worker name lo (alamat Solana) adalah yang menentukan work itu tercatat
atas nama siapa.

**Sesuaikan CPU, jangan langsung full.** PC lo Xeon E-2224G (4C/4T) dengan
8GB RAM. Di `config.json` sudah disetel `max-threads-hint: 75` (~3 thread).
Pantau RAM — kalau lewat 6GB, turunkan ke 50.

**Nilai reward bisa di bawah biaya listrik.** Itu peringatan resmi dari situs
mereka sendiri, bukan opini. Cek dulu 1-2 jam di
`xmr.cpucoinsol.app/rewards.html` (masukin alamat Solana lo) sebelum
dinyalakan 24/7.

## Kalau share nggak muncul di rewards

1. Worker name harus **alamat Solana** — cek `pass` di login bridge
2. Bridge harus jalan bersama xmrig; kalau bridge mati, xmrig putus
3. Tutup Chrome dulu kalau hasilnya 0 — berarti browser lagi pakai pool yang sama
