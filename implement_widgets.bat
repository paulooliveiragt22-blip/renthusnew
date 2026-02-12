@echo off
:: ========================================
:: SCRIPT DE IMPLEMENTAÇÃO AUTOMÁTICA
:: Widgets de Estado - TOP 5 Arquivos
:: Versão Batch (não precisa de assinatura)
:: ========================================

setlocal enabledelayedexpansion

echo ========================================
echo 🚀 IMPLEMENTAÇÃO AUTOMÁTICA DE WIDGETS
echo    Versão Batch
echo ========================================
echo.

:: Configuração
set "PROJECT_ROOT=D:\renthus_new\renthus_new"
set "WIDGETS_PATH=%PROJECT_ROOT%\lib\widgets\states"

:: Verificar projeto
if not exist "%PROJECT_ROOT%\pubspec.yaml" (
    echo ❌ ERRO: Projeto não encontrado em %PROJECT_ROOT%
    echo    Edite a variável PROJECT_ROOT no início do script
    pause
    exit /b 1
)

echo ✅ Projeto encontrado
echo.

:: Verificar widgets
if not exist "%WIDGETS_PATH%\state_builder.dart" (
    echo ❌ ERRO: Widgets não encontrados em lib\widgets\states\
    pause
    exit /b 1
)

echo ✅ Widgets encontrados
echo.

:: Criar backup
set "TIMESTAMP=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"
set "BACKUP_DIR=%PROJECT_ROOT%\backup_widgets_%TIMESTAMP%"

mkdir "%BACKUP_DIR%" 2>nul

echo 💾 Criando backup em: %BACKUP_DIR%
echo.

:: Arquivos a processar
set FILES[0]=lib\screens\client_chats_page.dart
set FILES[1]=lib\screens\chat_page.dart
set FILES[2]=lib\screens\provider_home_page.dart
set FILES[3]=lib\screens\provider_my_jobs_page.dart
set FILES[4]=lib\screens\notifications_page.dart

set COUNT=1

:: Processar cada arquivo
for /L %%i in (0,1,4) do (
    set "FILE=!FILES[%%i]!"
    
    echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    echo !COUNT!️⃣  !FILE!
    echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    if exist "%PROJECT_ROOT%\!FILE!" (
        :: Fazer backup
        for %%f in ("!FILE!") do set "FILENAME=%%~nxf"
        copy "%PROJECT_ROOT%\!FILE!" "%BACKUP_DIR%\!FILENAME!" >nul
        echo    💾 Backup criado
        
        :: Usar PowerShell para processar (inline)
        powershell -ExecutionPolicy Bypass -Command "$file='%PROJECT_ROOT%\!FILE!'; $content=Get-Content $file -Raw -Encoding UTF8; if($content -notmatch 'widgets/states/state_builder'){$content=$content -replace '(import [^;]+;)(\s*\n\s*(?!import))', \"`$1`n`nimport 'package:renthus/widgets/states/state_builder.dart';`nimport 'package:renthus/widgets/states/loading_widget.dart';`nimport 'package:renthus/widgets/states/error_widget.dart';`nimport 'package:renthus/widgets/states/empty_widget.dart';`n`$2\"; Set-Content $file -Value $content -Encoding UTF8 -NoNewline; Write-Host '   ✅ Imports adicionados'}else{Write-Host '   ⏭️  Imports já existem'}; if($content -match 'StreamBuilder' -and $content -notmatch 'StreamStateBuilder'){$content=Get-Content $file -Raw -Encoding UTF8; $content=$content -replace 'StreamBuilder<','StreamStateBuilder<'; Set-Content $file -Value $content -Encoding UTF8 -NoNewline; Write-Host '   ✅ StreamBuilder convertido'}; if($content -match 'FutureBuilder' -and $content -notmatch 'StateBuilder'){$content=Get-Content $file -Raw -Encoding UTF8; $content=$content -replace 'FutureBuilder<','StateBuilder<'; Set-Content $file -Value $content -Encoding UTF8 -NoNewline; Write-Host '   ✅ FutureBuilder convertido'}"
        
        echo.
    ) else (
        echo    ⚠️  Arquivo não encontrado
        echo.
    )
    
    set /a COUNT+=1
)

:: Resumo
echo ========================================
echo ⚠️  AJUSTES MANUAIS NECESSÁRIOS
echo ========================================
echo.
echo Os builders foram convertidos, mas você precisa ADICIONAR:
echo.
echo Para cada StateBuilder/StreamStateBuilder, adicione:
echo   loadingWidget: LoadingShimmerList(itemCount: 5, itemHeight: 80),
echo   errorWidget: ErrorStateWidget.network(onRetry: () =^> setState(() {})),
echo   emptyWidget: EmptyWidget.TIPO(),
echo   isEmpty: (data) =^> data.isEmpty,
echo.
echo Tipos de EmptyWidget:
echo   - client_chats_page → EmptyWidget.conversations()
echo   - chat_page → EmptyWidget.messages()
echo   - provider_home_page → EmptyWidget.jobs()
echo   - provider_my_jobs_page → EmptyWidget.history()
echo   - notifications_page → EmptyWidget.notifications()
echo.

:: Perguntar se quer executar flutter
echo ========================================
echo.
set /p FLUTTER="Deseja executar 'flutter pub get' agora? (S/N): "

if /i "%FLUTTER%"=="S" (
    echo.
    echo 📦 Executando flutter pub get...
    cd /d "%PROJECT_ROOT%"
    call flutter pub get
    
    echo.
    echo 🔍 Executando flutter analyze...
    call flutter analyze
)

echo.
echo ========================================
echo ✅ SCRIPT CONCLUÍDO!
echo ========================================
echo.
echo 💾 Backup salvo em: %BACKUP_DIR%
echo.
echo ❌ PARA REVERTER:
echo    xcopy "%BACKUP_DIR%\*" "%PROJECT_ROOT%\lib\screens\" /Y
echo.

pause
