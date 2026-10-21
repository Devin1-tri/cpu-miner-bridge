@echo off
chcp 65001 >nul
REM ============================================================
REM  CPU Miner - xmr.cpucoinsol.app ($CPU)
REM  Sekali klik: tanya alamat Solana + username, lalu mining.
REM
REM  Butuh: xmrig.exe + Python 3 di folder ini (atau di PATH).
REM  Download xmrig: github.com/xmrig/xmrig/releases
REM  Download Python: python.org (centang "Add python.exe to PATH")
REM ============================================================

title CPU Miner - $CPU
cd /d "%~dp0"

:CHECK_XMRIG
if not exist "xmrig.exe" (
  echo.
  echo  ============================================================
  echo   xmrig.exe TIDAK DITEMUKAN di folder ini.
  echo  ============================================================
  echo.
  echo   1. Buka https://github.com/xmrig/xmrig/releases/latest
  echo   2. Download file "xmrig-x.x.x-msvc-win64.zip"
  echo   3. Extract, taruh xmrig.exe di folder ini:
  echo      %CD%
  echo   4. Jalankan file ini lagi.
  echo.
  pause
  exit /b 1
)

where python >nul 2>&1
if errorlevel 1 (
  where py >nul 2>&1
  if errorlevel 1 (
    echo.
    echo  ============================================================
    echo   PYTHON TIDAK DITEMUKAN.
    echo  ============================================================
    echo.
    echo   Install dari https://www.python.org/downloads/
    echo   PENTING: centang "Add python.exe to PATH" di installer,
    echo   lalu tutup dan buka lagi CMD ini.
    echo.
    pause
    exit /b 1
  )
  set "PY=py -3"
) else (
  set "PY=python"
)

:ASK_SOL
echo.
echo  ============================================================
echo    CPU MINER - $CPU
echo  ============================================================
echo.
echo   Masukkan ALAMAT SOLANA lo ^(44 karakter^).
echo   Alamat ini yang dipakai menghitung reward $CPU lo.
echo   Contoh: GANTI_ALAMAT_SOLANA_LO
echo.
set /p SOL="  Alamat Solana: "
if "%SOL%"=="" (
  echo   ^^! Alamat Solana wajib diisi.
  goto ASK_SOL
)

:ASK_NAME
echo.
echo   Public username ^(opsional, Enter = lewati^)
echo   Tampil di leaderboard. 3-24 huruf, angka, _, atau -
echo.
set /p NAME="  Username: "
if not "%NAME%"=="" (
  echo %NAME%| findstr /r "^[A-Za-z0-9_-][A-Za-z0-9_-]*$" >nul || (
    echo   ^^! Username hanya boleh huruf/angka/_/- ^(3-24 karakter^).
    set NAME=
    goto ASK_NAME
  )
)

:ASK_CPU
echo.
echo  ============================================================
echo   Berapa CPU yang mau dialokasikan?
echo  ============================================================
echo.
echo   [1] 25%%  - 1 thread   ringan, PC tetap enak dipakai
echo   [2] 50%%  - 2 thread   seimbang  ^(rekomendasi kalau masih pakai PC^)
echo   [3] 75%%  - 3 thread   agak berat
echo   [4] 100%% - 4 thread   maksimal untuk 4 core  ^(sweet spot RandomX^)
echo.
echo   RandomX paling optimal 1 thread per CORE fisik, jadi 100%% di
echo   prosesor 4-core biasanya sudah ambang terbaik ditambah thread.
echo.
choice /c 1234 /m "  Pilih alokasi CPU"
if errorlevel 1 set "CPUPCT=25"
if errorlevel 2 set "CPUPCT=50"
if errorlevel 3 set "CPUPCT=75"
if errorlevel 4 set "CPUPCT=100"

echo.
echo  ============================================================
echo   Ringkasan
echo  ============================================================
echo   Alamat Solana : %SOL%
if not "%NAME%"=="" (echo   Username      : %NAME%) else (echo   Username      : ^(dilewati^))
echo   CPU           : %CPUPCT%%
echo.
choice /c YN /m "  Mulai mining sekarang"
if errorlevel 2 exit /b 0

REM ------------------------------------------------------------
REM  Terapkan pilihan CPU ke config.json xmrig
REM ------------------------------------------------------------
%PY% set_cpu.py %CPUPCT%
if errorlevel 1 (
  echo   ^^! Gagal mengatur CPU - cek set_cpu.py
  pause
  exit /b 1
)

REM ------------------------------------------------------------
REM  Susun argumen bridge (username opsional)
REM  CATATAN BATCH: set "VAR=--username "%NAME%"" membuat tanda kutip
REM  ikut masuk ke value. Pakai pemisah '=' supaya tidak ada nested quote.
REM ------------------------------------------------------------
set "NAME_ARG="
if not "%NAME%"=="" set "NAME_ARG=--username=%NAME%"

REM ------------------------------------------------------------
REM  Simpan pilihan biar gak usah tiap kali
REM ------------------------------------------------------------
> "%TEMP%\cpu_miner_args.txt" echo --worker "%SOL%"
if not "%NAME%"=="" >> "%TEMP%\cpu_miner_args.txt" echo --username "%NAME%"

echo.
echo  Menjalankan bridge + xmrig... ^(Ctrl+C untuk stop^)
echo.

REM  Bridge dibuat sebagai file log, bukan window /min, supaya kalau ada
REM  masalah bisa langsung dibaca tanpa buka window terpisah.
start "CPU-Bridge" /b cmd /c %PY% bridge.py --worker "%SOL%" %NAME_ARG% > "%TEMP%\cpu_bridge.log" 2>&1
timeout /t 3 /nobreak >nul

echo  ---- cek bridge ----
if not exist "%TEMP%\cpu_bridge.log" (
  echo   ^^! bridge tidak jalan. Pastikan Python terinstall.
  pause
  exit /b 1
)
findstr /c:"stratum proxy siap" "%TEMP%\cpu_bridge.log" >nul && (
  echo   bridge OK - mendengarkan di 127.0.0.1:3333
) || (
  echo   ^^! bridge belum siap. Isi log ^(5 baris terakhir^):
  echo.
  powershell -NoProfile -Command "Get-Content '%TEMP%\cpu_bridge.log' -Tail 5"
  pause
  exit /b 1
)
echo  -------------------
echo.

REM  ============================================================
REM  Catatan penting soal cara xmrig dijalankan:
REM
REM  xmrig.exe dijalankan langsung di console ini (foreground), BUKAN lewat
REM  'start', supaya output-nya kelihatan dan Ctrl+C berhenti di xmrig.
REM
REM  JANGAN jalankan xmrig dengan 'start /b' atau bungkus dengan 'timeout':
REM  xmrig akan langsung exit setelah mencetak "READY threads", karena proses
REM  induk (cmd.exe) sudah tidak menunggu anaknya. Gejalanya: log berhenti di
REM  READY threads, lalu "Menghentikan bridge", padahal mining belum dapat
REM  satu pun share.
REM  ============================================================
xmrig.exe --config=config.json
set XMRIG_EXIT=%errorlevel%

echo.
echo  Menghentikan bridge...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3333 ^| findstr LISTENING') do taskkill /PID %%a /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq CPU-Bridge*" /T /F >nul 2>&1

if not "%XMRIG_EXIT%"=="0" (
  echo.
  echo  ============================================================
  echo   xmrig berhenti dengan kode %XMRIG_EXIT%
  echo  ============================================================
  echo.
  echo   Kemungkinan penyebab dan solusi:
  echo.
  echo    ^(1^) TIDAK ADA BARIS "accepted" dan RAM di atas 85%%
  echo        -^^> seda terlalu banyak program. Tutup Chrome/browser,
  echo           lalu jalankan MINING.bat lagi.
  echo        -^^> Sudah disetel mode light ^(~256MB/thread^), tapi kalau
  echo           masih gagal, edit config.json:
  echo           "max-threads-hint": 25
  echo.
  echo    ^(2^) Log xmrig bilang "pool disconnected" / "1013"
  echo        -^^> pool mereka yang lagi down, bukan setup lo.
  echo           Coba lagi nanti.
  echo.
  echo   Log lengkap xmrig ada di: %CD%\xmrig.log
  echo.
  pause
  exit /b 1
)

echo.
echo  Selesai. Cek reward di https://xmr.cpucoinsol.app/rewards.html
echo.
pause
