@echo off
title AGB Sunucu
cd /d "%~dp0server"

rem --- sunucu zaten ayakta mi? oyleyse ikinci kopya acma ---
curl.exe -s -o nul --max-time 2 http://127.0.0.1:8000/api/health && goto zaten

echo.
echo   AGB sunucusu baslatiliyor...
echo   ComfyUI ve LAN sitesi de otomatik acilacak (yan_servisler).
echo   Durdurmak icin Ctrl+C.
echo.

python main.py

echo.
echo   Sunucu durdu. Pencereyi kapatabilirsin.
pause
exit /b 0

:zaten
echo.
echo   AGB zaten calisiyor  ^(http://127.0.0.1:8000^)
echo.
echo   [1] LAN sitesini ac      http://127.0.0.1:8080
echo   [2] ComfyUI'yi ac        http://127.0.0.1:8188
echo   [3] Yan servis durumu
echo   [Enter] cik
echo.
set /p secim=Secim:
if "%secim%"=="1" start "" "http://127.0.0.1:8080"
if "%secim%"=="2" start "" "http://127.0.0.1:8188"
rem API anahtari batch degiskenine alinmaz - PowerShell okur ve ayni adimda
rem kullanir, boylece anahtar hicbir yerde ekrana ya da loga dusmez.
if "%secim%"=="3" (
  powershell -NoProfile -Command ^
    "$s = Get-Content -Raw '%~dp0server\config\settings.json' | ConvertFrom-Json;" ^
    "try { Invoke-RestMethod -Uri 'http://127.0.0.1:8000/api/services/side' -Headers @{'X-API-Key'=$s.security.api_key} | ConvertTo-Json -Depth 5 }" ^
    "catch { 'Durum alinamadi: ' + $_.Exception.Message }"
  echo.
  pause
)
exit /b 0
