# Ripristina un ambiente di build Flutter sano quando il progetto vive dentro
# OneDrive. Fa due cose:
#
#   1. Sposta frontend\build fuori dalla cartella sincronizzata (junction).
#      Con Files On-Demand attivo OneDrive marca gli artefatti appena scritti
#      come segnaposto cloud e ReadOnly: quando Flutter prova a cancellare
#      build\flutter_assets per ricrearla l'operazione fallisce con
#        Flutter failed to delete a directory at "...\build\flutter_assets".
#      Gli artefatti non vanno comunque mai sincronizzati: cambiano a ogni
#      compilazione e pesano centinaia di MB.
#
#   2. Rigenera .dart_tool (la mappa package: -> cartella nella pub cache).
#      Se quel file si corrompe o resta a mezzo, il compilatore fallisce su
#      OGNI import con centinaia di righe
#        Error when reading '.../AppData/Local/Pub/Cache/...':
#        Impossibile trovare il percorso specificato
#      anche se i pacchetti sono presenti sul disco.
#
# Da rilanciare dopo un `flutter clean`, che rimuove la junction.
#
# Uso, dalla root del progetto:
#   .\scripts\fix-build-onedrive.ps1

$ErrorActionPreference = 'Stop'

$progetto = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $progetto 'frontend'
$build = Join-Path $frontend 'build'
$dartTool = Join-Path $frontend '.dart_tool'
$target = 'C:\Apps\jeopardy-build\frontend'

# --- 1. build fuori da OneDrive -------------------------------------------
if ((Get-Item $build -Force -ErrorAction SilentlyContinue).LinkType -eq 'Junction') {
    Write-Host "Junction gia presente, svuoto la cache di compilazione..."
    Get-ChildItem $target -Force -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
} else {
    if (Test-Path $build) {
        Write-Host "Rimuovo la cartella build sincronizzata..."
        # -R: senza togliere ReadOnly la cancellazione dei segnaposto fallisce
        & attrib -R "$build\*" /S /D 2>&1 | Out-Null
        Remove-Item -Recurse -Force $build
    }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    New-Item -ItemType Junction -Path $build -Target $target | Out-Null
    Write-Host "Build spostata: $build -> $target"
}

# --- 2. risoluzione dei package ------------------------------------------
Write-Host "Rigenero .dart_tool..."
Get-ChildItem $dartTool -Force -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }

Push-Location $frontend
try {
    # flutter deve essere raggiungibile: se non e' nel PATH lo aggiungiamo
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        $env:PATH = "C:\Apps\flutter\bin;$env:PATH"
    }
    & flutter pub get
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Ambiente ripristinato: ora 'flutter run' riparte da zero." -ForegroundColor Green
