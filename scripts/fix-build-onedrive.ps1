# Sposta la cartella di build di Flutter fuori da OneDrive.
#
# Perche' serve: il progetto vive dentro una cartella sincronizzata da
# OneDrive. Con Files On-Demand attivo, OneDrive trasforma i file appena
# scritti in segnaposto cloud (attributi ReparsePoint + RecallOnDataAccess) e
# li marca ReadOnly. Quando Flutter prova a cancellare build\flutter_assets
# per ricrearla, Windows tenta di riscaricare quei segnaposto e l'operazione
# fallisce con:
#
#   Flutter failed to delete a directory at "...\build\flutter_assets".
#   The flutter tool cannot access the file or directory.
#
# Gli artefatti di build non vanno comunque mai sincronizzati: cambiano a ogni
# compilazione e pesano centinaia di MB. Questo script sostituisce
# frontend\build con una junction verso una cartella locale fuori da OneDrive.
#
# Da rilanciare dopo un `flutter clean`, che rimuove la junction.
#
# Uso, dalla root del progetto:
#   .\scripts\fix-build-onedrive.ps1

$ErrorActionPreference = 'Stop'

$progetto = Split-Path -Parent $PSScriptRoot
$build = Join-Path $progetto 'frontend\build'
$target = 'C:\Apps\jeopardy-build\frontend'

if ((Get-Item $build -Force -ErrorAction SilentlyContinue).LinkType -eq 'Junction') {
    # Junction gia' a posto: resta da svuotare la cache di compilazione, che
    # dopo uno spostamento della build resta con riferimenti non piu' validi e
    # fa fallire il compilatore con
    #   Error when reading '.../AppData/Local/Pub/Cache/...': percorso non trovato
    Write-Host "Junction gia presente, svuoto la cache di compilazione..."
    Get-ChildItem $target -Force -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "Fatto: la prossima compilazione riparte da zero." -ForegroundColor Green
    exit 0
}

if (Test-Path $build) {
    Write-Host "Rimuovo la cartella build sincronizzata..."
    # -R: senza togliere ReadOnly la cancellazione dei segnaposto fallisce
    & attrib -R "$build\*" /S /D 2>&1 | Out-Null
    Remove-Item -Recurse -Force $build
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
New-Item -ItemType Junction -Path $build -Target $target | Out-Null

Write-Host "Fatto: $build -> $target" -ForegroundColor Green
Write-Host "Gli artefatti di build non vengono piu sincronizzati da OneDrive."
