@echo off
cd /d "C:\Users\mnavarro\Documents\flutterprojects\identity_wallet_Rama_final\Portal\backend"

:: Verificar si ya está corriendo en el puerto 8010
netstat -ano | find ":8010 " | find "LISTENING" >NUL 2>&1
if not errorlevel 1 (
    echo Backend ya en ejecucion en puerto 8010.
    exit /b 0
)

:: Arrancar uvicorn en background
start "" /B python -m uvicorn app.main:app --host 0.0.0.0 --port 8010 >> portal_out.log 2>> portal_err.log
echo Backend iniciado.
