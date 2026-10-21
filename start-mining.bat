@echo off
REM ============================================================
REM  CPU ($CPU / xmr.cpucoinsol.app) — Windows starter
REM  PowerEdge T40 / Xeon E-2224G / 8GB RAM
REM
REM  bridge.py menerjemahkan stratum TCP xmrig -> WebSocket bridge.
REM  xmrig sendiri tidak bisa langsung ke WS, makadari skrip ini ada.
REM ============================================================
setlocal

set WORKER=4mFpqJ7LuyYHz5LmtfiWEhGz3Tq3ciurZffg6g7Pm7Dj

echo.
echo  [1/3] bridge...
start "bridge" /min cmd /c python bridge.py --worker %WORKER%.*
timeout /t 3 /nobreak >nul

echo.
echo  [2/3] xmrig...
echo  Tekan Ctrl+C untuk berhenti xmrig, lalu tutup jendela bridge juga.
echo.
xmrig.exe --config=config.json

REM jendela bridge tertinggal (start /min) - hentikan setelah xmrig keluar
echo.
echo  [3/3] menghentikan bridge...
taskkill /FI "WINDOWTITLE eq bridge*" /T /F >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3333 ^| findstr LISTENING') do taskkill /PID %%a /F >nul 2>&1

echo.
echo  Selesai.
pause

REM Ganti baris di atas sesuai lokasi file di PC lo:
REM   WORKER = alamat Solana lo (worker name yang dihitung reward)
REM
REM CATATAN PENTING soal RAM (8GB di T40):
REM   config.json memakai max-threads-hint 75 (~3 thread) dan randomx mode auto.
REM   Kalau Task Manager menunjukkan RAM di atas ~6GB, turunkan ke 50.
