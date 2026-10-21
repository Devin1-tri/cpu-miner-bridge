@echo off
chcp 65001 >nul
REM ============================================================
REM  CPU Web Miner - jalankan Chrome miner tanpa ganggu taskbar
REM
REM  Semua mode memakai flag anti-throttle, karena tanpa itu Chrome
REM  memperlambat tab yang tidak kelihatan.
REM ============================================================

setlocal EnableDelayedExpansion

REM ---- cari Chrome ----
set "CHROME="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if "%CHROME%"=="" (
  echo.
  echo   Chrome tidak ditemukan. Install Chrome dulu.
  pause
  exit /b 1
)

REM ---- flag anti-throttle: WAJIB, jangan dihapus ----
REM  disable-background-timer-throttling    : timer JS jalan normal saat tab tidur
REM  disable-renderer-backgrounding         : renderer tidak diberi prioritas rendah
REM  disable-backgrounding-occluded-windows : window ketutup window lain != background
REM  CalculateNativeWinOcclusion off        : Chrome tidak mendeteksi dirinya ketutup
set "FLAGS=--disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-features=CalculateNativeWinOcclusion"

REM ---- folder profil khusus miner (biar sesi Chrome biasa nggak kecampur) ----
set "PROFILE=%LocalAppData%\ChromeMinerProfile"
if not exist "%PROFILE%" mkdir "%PROFILE%"

:MENU
cls
echo.
echo  ============================================================
echo    CPU WEB MINER
echo  ============================================================
echo.
echo   [1] OFF-SCREEN  ^(rekomendasi^)
echo       Chrome dipindah jauh ke luar layar, TIDAK diminimized.
echo       Chrome mengira dirinya tampil, jadi tidak diperlambat.
echo       ^(ikon taskbar masih ada, window-nya nggak ganggu^)
echo.
echo   [2] VIRTUAL DESKTOP
echo       Chrome di desktop virtual Windows terpisah.
echo.
echo   [3] NORMAL
echo       Chrome biasa, langsung kelihatan.
echo.
echo   [0] KELUAR
echo.
choice /c 1230 /n /m "  Pilih mode: "
if errorlevel 1 goto OFFSCREEN
if errorlevel 2 goto VDESKTOP
if errorlevel 3 goto NORMAL
exit /b 0

:OFFSCREEN
REM  Window diposisikan di luar area semua monitor, tapi TIDAK minimized.
REM  Ini kunci: Chrome lihat dirinya visible -> tidak ada throttling.
start "" "%CHROME%" %FLAGS% --user-data-dir="%PROFILE%" --window-position=30000,30000 --window-size=700,500 "https://xmr.cpucoinsol.app/#webminer"
echo.
echo   Chrome jalan di posisi off-screen ^(luar layar, tidak diminimized^).
echo.
echo   Cek hashrate di halaman site - harus tetap mendekati
echo   58-60 H/s. Kalau turun banyak, berarti Chrome tetap
echo   mendeteksi dirinya tersembunyi.
echo.
pause
exit /b 0

:VDESKTOP
start "" "%CHROME%" %FLAGS% --user-data-dir="%PROFILE%" "https://xmr.cpucoinsol.app/#webminer"
echo.
echo   Windows 10/11: pindahkan Chrome ke desktop virtual:
echo.
echo     Win + Ctrl + D          = buat desktop baru
echo     Win + Tab               = Task View, drag Chrome ke desktop baru
echo     Win + Ctrl + Kiri/Kanan = pindah desktop
echo.
echo   Supaya ikon taskbar tidak muncul dari desktop lain:
echo     Settings -^> System -^> Multitasking -^> Desktops
echo     -^> "On the taskbar, show all open windows"
echo        pilih: "Only on the desktop I'm using"
echo.
pause
exit /b 0

:NORMAL
start "" "%CHROME%" %FLAGS% --user-data-dir="%PROFILE%" "https://xmr.cpucoinsol.app/#webminer"
echo.
echo   Chrome jalan normal dengan flag anti-throttle.
pause
exit /b 0
