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
  echo.
  echo  ============================================================
  echo   PYTHON TIDAK DITEMUKAN.
  echo  ============================================================
  echo.
  echo   Install dari https://www.python.org/downloads/
  echo   PENTING: centang "Add python.exe to PATH" di installer.
  echo.
  pause
  exit /b 1
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

echo.
echo  ============================================================
echo   Ringkasan
echo  ============================================================
echo   Alamat Solana : %SOL%
if not "%NAME%"=="" (echo   Username      : %NAME%) else (echo   Username      : ^(dilewati^))
echo   CPU           : 75%% ^(3 thread, aman untuk RAM 8GB^)
echo.
choice /c YN /m "  Mulai mining sekarang"
if errorlevel 2 exit /b 0

REM ------------------------------------------------------------
REM  Susun argumen bridge (username opsional)
REM  CATATAN BATCH: set "VAR=--username "%NAME%"" membuat tanda kutip
REM  ikut masuk ke value. Pakai pemisah '=' supaya tidak ada nested quote.
REM ------------------------------------------------------------
set "NAME_ARG="
if not "%NAME%"=="" set "NAME_ARG=--username=%NAME%"

REM  pilih interpreter python: 'python' atau 'py -3'
set "PY=python"
where python >nul 2>&1 || set "PY=py -3"

REM ------------------------------------------------------------
REM  Simpan pilihan biar gak usah tiap kali
REM ------------------------------------------------------------
> "%TEMP%\cpu_miner_args.txt" echo --worker "%SOL%"
if not "%NAME%"=="" >> "%TEMP%\cpu_miner_args.txt" echo --username "%NAME%"

echo.
echo  Menjalankan bridge + xmrig... ^(Ctrl+C untuk stop^)
echo.

REM bridge jalan di terminal sendiri supaya log kelihatan
start "CPU-Bridge" /min cmd /c %PY% bridge.py --worker "%SOL%" %NAME_ARG% > "%TEMP%\cpu_bridge.log" 2>&1
timeout /t 2 /nobreak >nul

xmrig.exe --config=config.json

echo.
echo  Menghentikan bridge...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3333 ^| findstr LISTENING') do taskkill /PID %%a /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq CPU-Bridge*" /T /F >nul 2>&1

echo.
echo  Selesai. Cek reward di https://xmr.cpucoinsol.app/rewards.html
echo.
pause
