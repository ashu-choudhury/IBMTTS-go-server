@echo off
echo Building IBMTTS Bridge Server for 32-bit Windows...
set GOARCH=386
set GOOS=windows
go build -ldflags="-s -w" -o ibmtts_server_32bit.exe main.go
if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] Binary created: ibmtts_server_32bit.exe
) else (
    echo.
    echo [ERROR] Build failed!
)
pause
