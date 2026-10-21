@echo off
chcp 65001 >nul
REM ============================================================
REM  CPU Web Miner - jalankan Chrome miner tanpa ikon di taskbar
REM
REM  Tiga mode tersembunyi. Pilih lewat angka di bawah.
REM  Semua mode memakai flag anti-throttle, karena tanpa itu
REM  Chrome memperlambat tab yang tidak kelihatan.
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
echo    CPU WEB MINER - mode jalan tersembunyi
echo  ============================================================
echo.
echo   [1] OFF-SCREEN  ^(paling aman buat hashrate^)
echo       Window Chrome dipindah jauh ke luar layar. Chrome
echo       mengira dirinya TAMPIL, jadi tidak diperlambat.
echo       Ikon taskbar masih ada.
echo.
echo   [2] TRAY ^(ikon taskbar hilang total^)
echo       Chrome diminimalkan ke system tray pakai RBTray.
echo       Perlu RBTray terinstall - lihat catatan di bawah.
echo.
echo   [3] VIRTUAL DESKTOP ^(asli Windows, tanpa aplikasi lain^)
echo       Chrome dipindah ke desktop virtual Windows. Gabung
echo       dengan setelan taskbar, ikon tidak muncul di desktop lo.
echo.
echo   [0] NORMAL ^(tidak disembunyikan^)
echo.
choice /c 1230 /n /m "  Pilih mode: "
if errorlevel 1 goto OFFSCREEN
if errorlevel 2 goto TRAY
if errorlevel 3 goto VDESKTOP
if errorlevel 4 goto NORMAL
goto MENU

:OFFSCREEN
REM  Window diposisikan di luar area semua monitor, tapi TIDAK minimized.
REM  Ini kunci: Chrome lihat dirinya visible -> tidak ada throttling.
start "" "%CHROME%" %FLAGS% --user-data-dir="%PROFILE%" --window-position=30000,30000 --window-size=700,500 "https://xmr.cpucoinsol.app/#webminer"
echo.
echo   Chrome jalan di posisi off-screen.
echo   Laju hash: cek di halaman site ^(harus tetap mendekati 58-60 H/s^).
echo   Kalau turun banyak, berarti Chrome tetap mendeteksi dirinya tersembunyi.
echo.
pause
exit /b 0

:TRAY
set "RBTRAY=%ProgramFiles%\RBTray\RBTray.exe"
if not exist "%RBTRAY%" set "RBTRAY=%LocalAppData%\RBTray\RBTray.exe"
if not exist "%RBTRAY%" (
  echo.
  echo   ------------------------------------------------------------
  echo   RBTray belum terinstall.
  echo   ------------------------------------------------------------
  echo.
  echo   1. Download dari github.com/benbuck/rbtray
  echo      ^(file: RBTray.zip^)
  echo   2. Extract ke C:\Program Files\RBTray\
  echo   3. Klik-kanan RBTray.exe -^> Run as administrator
  echo   4. Jalankan file ini lagi, pilih [1]
  echo.
  echo   Setelah RBTray aktif: klik TOMBOL MINIMIZE Chrome dengan
  echo   KANAN mouse ^(bukan kiri^), Chrome akan masuk ke tray.
  echo.
  pause
  exit /b 1
)
start "" "%CHROME%" %FLAGS% --user-data-dir="%PROFILE%" --start-minimized "https://xmr.cpucoinsol.app/#webminer"
echo.
echo   Chrome jalan minimized. Klik-kanan tombol minimize Chrome
echo   untuk mengirimnya ke tray ^(ikon dekat jam^).
echo.
pause
exit /b 0

:VDESKTOP
start "" "%CHROME%" %FLAGS% --user-data-dir="%PROFILE%" "https://xmr.cpucoinsol.app/#webminer"
echo.
echo   Windows 10/11: pindahkan Chrome ke desktop virtual:
echo.
echo     Win + Ctrl + D        = buat desktop baru
echo     Win + Tab             = Task View, drag Chrome ke desktop baru
echo     Win + Ctrl + Kiri/Kanan = pindah desktop
echo.
echo   Supaya ikon taskbar tidak muncul:
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
