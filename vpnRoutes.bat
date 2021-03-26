@echo off
SETLOCAL EnableDelayedExpansion
echo.
REM put your VPN connection name here
set myvpn="AHIMA RRAS"
REM List of networks
set netList=192.168.10.0 192.168.11.0 192.168.12.0 192.168.20.0 192.168.65.0 192.168.75.0 10.1.1.0 10.1.2.0 10.1.3.0 10.1.4.0 10.1.5.0 10.1.6.0 10.1.50.0 10.10.5.0 10.200.5.0 172.15.15.0
set netList16=10.8.0.0

goto check_Permissions

:check_Permissions
    echo Administrative permissions required. Detecting permissions...

    net session >nul 2>&1
    if %errorLevel% == 0 (
        echo Success: Administrative permissions confirmed.
    ) else (
        echo Failure: Current permissions inadequate.
		goto end
    )


ipconfig | find /i %myvpn% > nul 2>&1

if %ERRORLEVEL% == 0 (
    
	echo "VPN connected. Adding routes..."
    
	FOR /F "TOKENS=2 DELIMS=:" %%A IN ('IPCONFIG ^| FIND "IPv4 Address" ^| FIND "192.168.13."') DO (
		SET IP=%%A
		set GW=!IP:~1!
		)
	echo Gateway: !GW!
	
	FOR /F %%i in ('netsh interface ipv4 show interface ^| find /i %myvpn%') do set ifnum=%%i
	echo If Num: !ifnum!
	
	for %%b in (%netList%) do (
		route add %%b mask 255.255.255.0 !GW! if !ifnum! > nul 2>&1
	)
	for %%c in (%netList16%) do (
		route add %%c mask 255.255.0.0 !GW! if !ifnum! > nul 2>&1
	)
) else if %ERRORLEVEL% == 1 (

    echo "VPN not connected."
    echo.
	rem exit
    rem rasdial %myvpn% %myuser% %mypass%
    rem runas.exe /user:%winadmin% /savedcred "route add %network% mask %mask% %gateway%"
)

:end
echo.
echo Done. 
pause
rem exit