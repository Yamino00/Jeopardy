<#
.SYNOPSIS
    Dice se il backend su Azure funziona davvero, e quanto ci mette.

.DESCRIPTION
    Non si limita a chiedere se e' vivo. Controlla, in ordine:

      1. che risponda (e misura l'avvio a freddo, che e' la cosa che l'host
         nota per prima aprendo l'app);
      2. che raggiunga il database in TLS;
      3. che le rotte protette continuino a chiedere l'identita' del client;
      4. che creare un tabellone vero funzioni, e quanto tempo resta prima
         del tetto interno di 150 secondi.

    Il punto 4 e' quello che conta: gli altri tre passerebbero anche con un
    servizio che non riesce a generare niente.

    Scritto per Windows PowerShell 5.1, che e' quello installato di serie su
    Windows: niente -SkipHttpErrorCheck, niente operatore ternario, niente
    che richieda PowerShell 7.

.PARAMETER BaseUrl
    Indirizzo del backend. **Omettilo** e lo script se lo fa dire da Azure:
    l'indirizzo di una Container App non e' componibile a mente, perche'
    contiene un sottodominio casuale assegnato all'ambiente
    (ca-jeopardy.<qualcosa-a-caso>.<regione>.azurecontainerapps.io). Va
    passato solo per provare un backend locale.

.PARAMETER NomeApp
    Nome della Container App, quando l'indirizzo va ricavato da Azure.

.PARAMETER GruppoRisorse
    Gruppo di risorse, quando l'indirizzo va ricavato da Azure.

.PARAMETER SaltaCreazione
    Salta il punto 4. Utile per un controllo veloce: creare un tabellone
    consuma una delle generazioni giornaliere e chiama davvero l'IA.

.PARAMETER Argomento
    Argomento del tabellone di prova. Se si passa un argomento che la banca
    ha gia' in casa, il punto 4 gira senza chiamare l'IA e senza consumare
    quota: verifica tutto tranne il tempo di generazione. Lasciandolo vuoto
    ne viene usato uno nuovo ogni volta, che e' la prova piu' severa.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1 -BaseUrl http://localhost:8080 -Argomento "Storia romana"
#>
[CmdletBinding()]
param(
    [string] $BaseUrl,

    [string] $NomeApp = 'ca-jeopardy',

    [string] $GruppoRisorse = 'rg-jeopardy',

    [switch] $SaltaCreazione,

    [string] $Argomento
)

$ErrorActionPreference = 'Stop'
$clientId = [guid]::NewGuid().ToString()
$problemi = @()

# Senza -BaseUrl, l'indirizzo se lo fa dire ad Azure. Comporlo a mano e' la
# trappola: il FQDN di una Container App include un sottodominio casuale
# dell'ambiente, e "ca-nome.regione.azurecontainerapps.io" non esiste.
if (-not $BaseUrl) {
    $az = Get-Command az -ErrorAction SilentlyContinue
    if (-not $az) {
        # winget installa `az` fuori dal PATH di sessioni gia' aperte
        $probabile = "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
        if (Test-Path $probabile) { $az = $probabile } else {
            Write-Host "Serve la CLI di Azure per ricavare l'indirizzo, oppure passa -BaseUrl." -ForegroundColor Red
            exit 1
        }
    } else { $az = $az.Source }

    Write-Host "Chiedo a Azure l'indirizzo di $NomeApp..." -ForegroundColor DarkGray
    $fqdn = & $az containerapp show --name $NomeApp --resource-group $GruppoRisorse `
        --query properties.configuration.ingress.fqdn -o tsv 2>$null
    if (-not $fqdn) {
        Write-Host "Non trovata la Container App '$NomeApp' nel gruppo '$GruppoRisorse'." -ForegroundColor Red
        Write-Host "Controlla i nomi, oppure passa -BaseUrl a mano." -ForegroundColor Yellow
        exit 1
    }
    $BaseUrl = "https://$($fqdn.Trim())"
}

$BaseUrl = $BaseUrl.TrimEnd('/')

# Windows PowerShell 5.1 negozia ancora TLS 1.0 di default su alcune
# installazioni, e Azure lo rifiuta: senza questa riga le chiamate HTTPS
# falliscono con un errore di connessione che sembra un servizio spento.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

<#
    Invoke-WebRequest solleva su 4xx e 5xx, e in 5.1 non esiste
    -SkipHttpErrorCheck per impedirglielo. Qui l'eccezione viene riportata a
    un oggetto uniforme, cosi' il resto dello script ragiona sempre su
    .Stato e .Corpo e mai su try/catch sparsi.
#>
function Invoke-Chiamata {
    param(
        [string] $Uri,
        [string] $Metodo = 'GET',
        [hashtable] $Intestazioni = @{},
        [string] $Corpo,
        [int] $TimeoutSec = 60
    )

    $argomenti = @{
        Uri              = $Uri
        Method           = $Metodo
        Headers          = $Intestazioni
        TimeoutSec       = $TimeoutSec
        UseBasicParsing  = $true
    }
    if ($Corpo) {
        $argomenti.Body = $Corpo
        $argomenti.ContentType = 'application/json'
    }

    try {
        $r = Invoke-WebRequest @argomenti
        return [pscustomobject]@{
            Stato    = [int] $r.StatusCode
            Corpo    = $r.Content
            Raggiunto = $true
            Errore   = $null
        }
    }
    catch [System.Net.WebException] {
        $risposta = $_.Exception.Response
        if ($null -eq $risposta) {
            # Nessuna risposta HTTP: DNS, TLS, connessione rifiutata, timeout.
            return [pscustomobject]@{
                Stato = 0; Corpo = ''; Raggiunto = $false; Errore = $_.Exception.Message
            }
        }
        $testo = ''
        try {
            $lettore = New-Object IO.StreamReader($risposta.GetResponseStream())
            $testo = $lettore.ReadToEnd()
            $lettore.Close()
        } catch { }
        return [pscustomobject]@{
            Stato    = [int] $risposta.StatusCode
            Corpo    = $testo
            Raggiunto = $true
            Errore   = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Stato = 0; Corpo = ''; Raggiunto = $false; Errore = $_.Exception.Message
        }
    }
}

function Scrivi-Esito {
    param([bool] $Ok, [string] $Testo)
    if ($Ok) { Write-Host "  OK      $Testo" -ForegroundColor Green }
    else     { Write-Host "  FALLITO $Testo" -ForegroundColor Red }
}

Write-Host ""
Write-Host "Verifica di $BaseUrl" -ForegroundColor Cyan
Write-Host ""

# --- 1. Risveglio -----------------------------------------------------
# La prima richiesta dopo una pausa paga l'avvio della JVM. Il timeout e'
# largo di proposito: qui si sta misurando, non si sta pretendendo.
Write-Host "1. Risveglio e liveness"
$orologio = [Diagnostics.Stopwatch]::StartNew()
$r = Invoke-Chiamata -Uri "$BaseUrl/api/salute/vivo" -TimeoutSec 180
$orologio.Stop()
$secondi = [math]::Round($orologio.Elapsed.TotalSeconds, 1)

if (-not $r.Raggiunto) {
    Scrivi-Esito $false "irraggiungibile dopo $secondi s: $($r.Errore)"
    Write-Host ""
    Write-Host "Il servizio non risponde. Guarda i log in diretta con:" -ForegroundColor Yellow
    Write-Host "  az containerapp logs show --name ca-jeopardy --resource-group rg-jeopardy --follow"
    exit 1
}
if ($r.Stato -eq 200) {
    Scrivi-Esito $true "risponde in $secondi s"
    if ($secondi -gt 60) {
        Write-Host "          Avvio a freddo lungo: l'host lo notera'." -ForegroundColor Yellow
    }
} else {
    Scrivi-Esito $false "HTTP $($r.Stato) dopo $secondi s"
    $problemi += "liveness: HTTP $($r.Stato)"
}

# --- 2. Database ------------------------------------------------------
Write-Host "2. Database"
$r = Invoke-Chiamata -Uri "$BaseUrl/api/salute/pronto" -TimeoutSec 60
if ($r.Raggiunto -and $r.Stato -eq 200) {
    Scrivi-Esito $true 'raggiungibile in TLS, migrazioni applicate'
} else {
    Scrivi-Esito $false "HTTP $($r.Stato) $($r.Errore) $($r.Corpo)"
    $problemi += 'database non raggiungibile'
    Write-Host "          Causa piu' probabile: DB_URL senza ?sslmode=require." -ForegroundColor Yellow
}

# --- 3. Identita' del client -----------------------------------------
# Le rotte protette devono continuare a chiedere X-Client-Id: se smettessero,
# le quote per dispositivo non varrebbero piu' niente.
Write-Host "3. Rotte protette"
$r = Invoke-Chiamata -Uri "$BaseUrl/api/tabelloni" -TimeoutSec 30
if ($r.Raggiunto -and $r.Stato -eq 400) {
    Scrivi-Esito $true 'senza X-Client-Id rispondono 400, come devono'
} else {
    Scrivi-Esito $false "atteso 400, ricevuto $($r.Stato) $($r.Errore)"
    $problemi += "rotte protette: HTTP $($r.Stato) invece di 400"
}

# --- 4. Creazione di un tabellone vero --------------------------------
if ($SaltaCreazione) {
    Write-Host "4. Creazione tabellone  (saltata)"
} else {
    Write-Host "4. Creazione di un tabellone vero"
    if ($Argomento) {
        $tema = $Argomento
        Write-Host "          Argomento '$tema': se la banca lo copre, l'IA non viene chiamata."
    } else {
        # Argomento sempre nuovo: la banca non puo' averlo, quindi la
        # generazione parte per forza. E' la prova che misura il tempo vero.
        $tema = 'Verifica deploy ' + (Get-Date -Format 'yyyyMMddHHmmss')
        Write-Host "          Chiama l'IA e consuma una generazione. Puo' durare oltre un minuto."
    }
    $corpo = @{
        titolo     = 'Verifica deploy'
        argomenti  = @($tema)
        righe      = 3
        punti_base = 100
    } | ConvertTo-Json -Compress

    $orologio = [Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-Chiamata -Uri "$BaseUrl/api/tabelloni" -Metodo 'POST' `
        -Intestazioni @{ 'X-Client-Id' = $clientId } -Corpo $corpo -TimeoutSec 240
    $orologio.Stop()
    $secondi = [math]::Round($orologio.Elapsed.TotalSeconds, 1)

    if (-not $r.Raggiunto) {
        Scrivi-Esito $false "fallita dopo $secondi s: $($r.Errore)"
        $problemi += 'creazione tabellone fallita'
    }
    elseif ($r.Stato -eq 201) {
        $board = $r.Corpo | ConvertFrom-Json
        $celle = @($board.categorie | ForEach-Object { $_.celle })
        $vuote = @($celle | Where-Object { -not $_.risposta })
        $dd    = @($celle | Where-Object { $_.daily_double })

        Scrivi-Esito $true "creato $($board.codice_pubblico) in $secondi s"
        Scrivi-Esito ($vuote.Count -eq 0) "$($celle.Count) celle, $($vuote.Count) senza risposta"
        Scrivi-Esito ($dd.Count -eq 1) "Daily Double: $($dd.Count) cella"

        if ($vuote.Count -gt 0) { $problemi += 'celle senza domanda' }
        if ($dd.Count -ne 1)    { $problemi += "Daily Double: $($dd.Count) invece di 1" }

        $margine = [math]::Round(150 - $secondi, 1)
        if ($margine -lt 40) {
            Write-Host "          Margine sul tetto di 150 s: $margine s. Stretto." -ForegroundColor Yellow
            Write-Host "          Un tabellone con piu' categorie potrebbe non farcela." -ForegroundColor Yellow
        } else {
            Write-Host "          Margine sul tetto di 150 s: $margine s."
        }
    }
    elseif ($r.Stato -eq 504) {
        Scrivi-Esito $false "tempo esaurito dopo $secondi s (il server si e' fermato da solo)"
        $problemi += 'generazione oltre il budget di tempo'
    }
    elseif ($r.Stato -eq 429) {
        Scrivi-Esito $false 'quota giornaliera di generazioni esaurita'
        Write-Host "          Non e' un guasto del deploy: riprovare domani." -ForegroundColor Yellow
    }
    elseif ($r.Stato -eq 503) {
        Scrivi-Esito $false 'IA non configurata, o nessuna domanda disponibile'
        Write-Host "          Controlla GEMINI_API_KEY e GROQ_API_KEY nelle" -ForegroundColor Yellow
        Write-Host "          impostazioni applicative del servizio." -ForegroundColor Yellow
        $problemi += 'IA non configurata'
    }
    else {
        Scrivi-Esito $false "HTTP $($r.Stato) dopo $secondi s - $($r.Corpo)"
        $problemi += "creazione tabellone: HTTP $($r.Stato)"
    }
}

# --- Esito ------------------------------------------------------------
Write-Host ""
if ($problemi.Count -eq 0) {
    Write-Host "Tutto a posto. Per costruire l'APK che punta qui:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  cd frontend"
    Write-Host "  flutter build apk --release --dart-define=API_BASE_URL=$BaseUrl"
    Write-Host ""
    exit 0
}

Write-Host "Problemi trovati:" -ForegroundColor Red
foreach ($p in $problemi) { Write-Host "  - $p" -ForegroundColor Red }
Write-Host ""
Write-Host "Vedi 'Cosa fare quando qualcosa non va' in docs/DEPLOY_AZURE.md." -ForegroundColor Yellow
exit 1
