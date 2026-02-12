# ========================================
# SCRIPT DE IMPLEMENTAÇÃO AUTOMÁTICA V2
# Widgets de Estado - TOP 5 Arquivos
# VERSÃO MANUAL COM REGEXES PRECISOS
# ========================================

param(
    [string]$ProjectPath = "D:\renthus_new\renthus_new"
)

$ErrorActionPreference = "Stop"

Write-Host @"
========================================
🚀 IMPLEMENTAÇÃO AUTOMÁTICA DE WIDGETS
   Versão 2.0 - Robusto
========================================

"@ -ForegroundColor Cyan

# Verificar se está na pasta correta
if (-not (Test-Path "$ProjectPath\pubspec.yaml")) {
    Write-Host "❌ ERRO: Projeto Flutter não encontrado em: $ProjectPath" -ForegroundColor Red
    Write-Host "   Use: .\implement_widgets.ps1 -ProjectPath 'C:\caminho\do\projeto'" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Projeto encontrado" -ForegroundColor Green
Set-Location $ProjectPath

# Verificar widgets
$widgetsPath = "$ProjectPath\lib\widgets\states"
if (-not (Test-Path "$widgetsPath\state_builder.dart")) {
    Write-Host "❌ ERRO: Widgets não encontrados em lib\widgets\states\" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Widgets encontrados" -ForegroundColor Green
Write-Host ""

# ========================================
# CRIAR BACKUP
# ========================================
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "$ProjectPath\backup_widgets_$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "💾 Criando backup em: $backupDir" -ForegroundColor Cyan
Write-Host ""

# ========================================
# ARQUIVOS A MODIFICAR
# ========================================
$files = @{
    "client_chats_page" = @{
        Path = "lib\screens\client_chats_page.dart"
        Type = "Stream"
        EmptyWidget = "conversations"
    }
    "chat_page" = @{
        Path = "lib\screens\chat_page.dart"
        Type = "Stream"
        EmptyWidget = "messages"
    }
    "provider_home_page" = @{
        Path = "lib\screens\provider_home_page.dart"
        Type = "Future"
        EmptyWidget = "jobs"
    }
    "provider_my_jobs_page" = @{
        Path = "lib\screens\provider_my_jobs_page.dart"
        Type = "Future"
        EmptyWidget = "history"
    }
    "notifications_page" = @{
        Path = "lib\screens\notifications_page.dart"
        Type = "Future"
        EmptyWidget = "notifications"
    }
}

# ========================================
# FUNÇÃO: Processar Arquivo
# ========================================
function Process-File {
    param(
        [string]$FilePath,
        [string]$BuilderType,
        [string]$EmptyWidget
    )
    
    $fullPath = Join-Path $ProjectPath $FilePath
    
    if (-not (Test-Path $fullPath)) {
        Write-Host "   ⚠️  Arquivo não encontrado" -ForegroundColor Yellow
        return $false
    }
    
    # Backup
    $fileName = Split-Path $fullPath -Leaf
    Copy-Item $fullPath "$backupDir\$fileName" -Force
    
    # Ler conteúdo
    $content = Get-Content $fullPath -Raw -Encoding UTF8
    $modified = $false
    
    # 1. ADICIONAR IMPORTS
    if ($content -notmatch "widgets/states/state_builder\.dart") {
        Write-Host "   📝 Adicionando imports..." -ForegroundColor Gray
        
        # Encontrar último import
        if ($content -match "(?s)(.*?import [^;]+;)([^i]*)") {
            $imports = @"

// Widgets de estado
import 'package:renthus/widgets/states/state_builder.dart';
import 'package:renthus/widgets/states/loading_widget.dart';
import 'package:renthus/widgets/states/error_widget.dart';
import 'package:renthus/widgets/states/empty_widget.dart';
"@
            $content = $content -replace "(import [^;]+;)(\s*\n\s*(?!import))", "`$1$imports`$2"
            $modified = $true
            Write-Host "   ✅ Imports adicionados" -ForegroundColor Green
        }
    } else {
        Write-Host "   ⏭️  Imports já existem" -ForegroundColor Gray
    }
    
    # 2. SUBSTITUIR BUILDERS
    if ($BuilderType -eq "Stream") {
        if ($content -match "StreamBuilder" -and $content -notmatch "StreamStateBuilder") {
            Write-Host "   📝 Convertendo StreamBuilder..." -ForegroundColor Gray
            $content = $content -replace "StreamBuilder<", "StreamStateBuilder<"
            $modified = $true
            Write-Host "   ✅ StreamBuilder → StreamStateBuilder" -ForegroundColor Green
        } else {
            Write-Host "   ⏭️  Já usa StreamStateBuilder" -ForegroundColor Gray
        }
    }
    
    if ($BuilderType -eq "Future") {
        if ($content -match "FutureBuilder" -and $content -notmatch "StateBuilder") {
            Write-Host "   📝 Convertendo FutureBuilder..." -ForegroundColor Gray
            $content = $content -replace "FutureBuilder<", "StateBuilder<"
            $modified = $true
            Write-Host "   ✅ FutureBuilder → StateBuilder" -ForegroundColor Green
        } else {
            Write-Host "   ⏭️  Já usa StateBuilder" -ForegroundColor Gray
        }
    }
    
    # Salvar se modificado
    if ($modified) {
        Set-Content $fullPath -Value $content -Encoding UTF8 -NoNewline
        Write-Host "   💾 Arquivo salvo" -ForegroundColor Green
        return $true
    }
    
    return $false
}

# ========================================
# PROCESSAR TODOS OS ARQUIVOS
# ========================================
$count = 1
$totalModified = 0

foreach ($key in $files.Keys) {
    $file = $files[$key]
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "${count}️⃣  $key.dart" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    
    $result = Process-File -FilePath $file.Path -BuilderType $file.Type -EmptyWidget $file.EmptyWidget
    
    if ($result) {
        $totalModified++
    }
    
    Write-Host ""
    $count++
}

# ========================================
# AJUSTES MANUAIS NECESSÁRIOS
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "⚠️  AJUSTES MANUAIS NECESSÁRIOS" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Os builders foram convertidos, mas você precisa ADICIONAR MANUALMENTE:" -ForegroundColor White
Write-Host ""
Write-Host "Para cada StateBuilder/StreamStateBuilder, adicione:" -ForegroundColor Yellow
Write-Host @"
  loadingWidget: LoadingShimmerList(itemCount: 5, itemHeight: 80),
  errorWidget: ErrorStateWidget.network(onRetry: () => setState(() {})),
  emptyWidget: EmptyWidget.TIPO_CORRETO(),
  isEmpty: (data) => data.isEmpty,
"@ -ForegroundColor Gray
Write-Host ""
Write-Host "Tipos de EmptyWidget:" -ForegroundColor Yellow
Write-Host "  - client_chats_page → EmptyWidget.conversations()" -ForegroundColor Gray
Write-Host "  - chat_page → EmptyWidget.messages()" -ForegroundColor Gray
Write-Host "  - provider_home_page → EmptyWidget.jobs()" -ForegroundColor Gray
Write-Host "  - provider_my_jobs_page → EmptyWidget.history()" -ForegroundColor Gray
Write-Host "  - notifications_page → EmptyWidget.notifications()" -ForegroundColor Gray
Write-Host ""

# ========================================
# RESUMO
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📊 RESUMO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Arquivos processados: $($files.Count)" -ForegroundColor White
Write-Host "Arquivos modificados: $totalModified" -ForegroundColor White
Write-Host "Backup salvo em: $backupDir" -ForegroundColor White
Write-Host ""

# ========================================
# PRÓXIMOS PASSOS
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📋 PRÓXIMOS PASSOS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Abra cada arquivo no VS Code" -ForegroundColor Yellow
Write-Host "2. Procure por 'StateBuilder' ou 'StreamStateBuilder'" -ForegroundColor Yellow
Write-Host "3. Adicione os widgets (loading, error, empty)" -ForegroundColor Yellow
Write-Host "4. Execute: flutter pub get" -ForegroundColor Yellow
Write-Host "5. Execute: flutter analyze" -ForegroundColor Yellow
Write-Host "6. Teste o app!" -ForegroundColor Yellow
Write-Host ""

# ========================================
# EXECUTAR FLUTTER?
# ========================================
Write-Host "Deseja executar 'flutter pub get' agora? (S/N): " -ForegroundColor Cyan -NoNewline
$response = Read-Host

if ($response -eq 'S' -or $response -eq 's') {
    Write-Host ""
    Write-Host "📦 Executando flutter pub get..." -ForegroundColor Cyan
    flutter pub get
    
    Write-Host ""
    Write-Host "🔍 Executando flutter analyze..." -ForegroundColor Cyan
    flutter analyze | Select-String "error|warning" -Context 0,2
}

Write-Host ""
Write-Host "✅ SCRIPT CONCLUÍDO!" -ForegroundColor Green
Write-Host ""
Write-Host "❌ PARA REVERTER:" -ForegroundColor Red
Write-Host "   Copy-Item '$backupDir\*' 'lib\screens\' -Force" -ForegroundColor Gray
Write-Host ""
