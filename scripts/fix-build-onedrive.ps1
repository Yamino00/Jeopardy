# Ripristina un ambiente di build Flutter sano quando il progetto vive dentro
# OneDrive.
#
# Il sintomo piu' frequente e' un build che fallisce cosi':
#
#   Execution failed for task ':app:cleanMergeDebugAssets'.
#   > java.io.IOException: Unable to delete directory '...\build\app\...'
#       Failed to delete some children.
#
# oppure, da Flutter:
#
#   Flutter failed to delete a directory at "...\build\flutter_assets".
#
# La causa e' la stessa in entrambi i casi: dentro l'albero di build ci sono
# cartelle e file marcati **ReadOnly**, e sia Java sia Flutter falliscono nel
# cancellarli. Non serve capire chi abbia messo quel bit (un filtro di sistema
# lo rimette su artefatti appena scritti): serve toglierlo prima di cancellare.
#
# Uso, dalla root del progetto:
#   .\scripts\fix-build-onedrive.ps1            # sblocca e basta: veloce
#   .\scripts\fix-build-onedrive.ps1 -Completo  # anche .dart_tool e pub get
#
# La modalita' veloce e' quella che serve nel 90% dei casi. Quella completa
# tocca la risoluzione dei pacchetti, che e' delicata: usala solo se il
# compilatore fallisce su OGNI import con
#   Error when reading '.../AppData/Local/Pub/Cache/...'

param(
    [switch]$Completo
)

$ErrorActionPreference = 'Stop'

$progetto = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $progetto 'frontend'
$build = Join-Path $frontend 'build'
$dartTool = Join-Path $frontend '.dart_tool'
$target = 'C:\Apps\jeopardy-build\frontend'

function Remove-SolaLettura {
    param([string]$Cartella)
    if (-not (Test-Path $Cartella)) { return 0 }
    $prima = @(Get-ChildItem $Cartella -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -band [IO.FileAttributes]::ReadOnly }).Count
    # /S ricorsivo, /D anche sulle directory: senza /D il bit resta sulle
    # cartelle, ed e' esattamente quello che fa fallire cleanMergeDebugAssets.
    & attrib -R "$Cartella\*" /S /D 2>&1 | Out-Null
    return $prima
}

# --- 1. la build vive fuori dalla cartella sincronizzata ------------------
$item = Get-Item $build -Force -ErrorAction SilentlyContinue
if ($item -and $item.LinkType -eq 'Junction') {
    Write-Host "Junction gia' presente."
} else {
    if (Test-Path $build) {
        Write-Host "Sposto la build fuori da OneDrive..."
        [void](Remove-SolaLettura $build)
        Remove-Item -Recurse -Force $build
    }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    New-Item -ItemType Junction -Path $build -Target $target | Out-Null
    Write-Host "Build spostata: $build -> $target"
}

# --- 2. il bit ReadOnly, che e' la causa vera -----------------------------
# Va tolto **anche quando la junction c'e' gia'**: era la lacuna della versione
# precedente di questo script, che in quel ramo cancellava senza sbloccare e
# quindi falliva in silenzio lasciando gli artefatti a meta'.
$quanti = Remove-SolaLettura $target
if ($quanti -gt 0) {
    Write-Host "Sbloccate $quanti voci in sola lettura."
} else {
    Write-Host "Nessuna voce in sola lettura."
}

# --- 3. gli intermedi che Gradle non riesce a ripulire da solo ------------
# Una volta tolto il ReadOnly si cancellano senza storie, e Gradle li rifa'.
foreach ($sotto in @('app\intermediates', 'app\generated')) {
    $percorso = Join-Path $target $sotto
    if (Test-Path $percorso) {
        Remove-Item -Recurse -Force $percorso -ErrorAction SilentlyContinue
        Write-Host "Ripulito $sotto"
    }
}

# --- 4. solo se richiesto: la risoluzione dei pacchetti -------------------
if ($Completo) {
    Write-Host "Rigenero .dart_tool..."
    Get-ChildItem $dartTool -Force -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }

    Push-Location $frontend
    try {
        if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
            $env:PATH = "C:\Apps\flutter\bin;$env:PATH"
        }
        & flutter pub get
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Fatto: ora 'flutter build apk --debug' riparte." -ForegroundColor Green
