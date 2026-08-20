# Frontend Flutter — regole di progetto

## Cosa stiamo costruendo
Client Android per un'app di quiz a griglia stile game show, dove le
domande sono generate da un LLM e le partite si giocano di persona:
un host tiene il dispositivo, i giocatori rispondono a voce.
Il backend Java Spring Boot esiste già e non va toccato.

## Piattaforma
- **Android nativo, esclusivamente.** Niente web, niente iOS, niente
  desktop. Se una scelta va bene sul web ma è mediocre su Android,
  vince Android.
- Telefono in verticale è il caso principale, tablet in orizzontale è
  il caso importante: è un gioco di gruppo, spesso finisce su un tablet
  appoggiato al tavolo.
- minSdk 24, target e compile SDK all'ultima versione stabile.

## Contesto d'uso che deve guidare ogni scelta
- Si gioca in gruppo, con lo schermo visibile a più persone da lontano.
  I testi delle domande devono essere leggibili a un metro e mezzo.
- Le sessioni durano 20-40 minuti con lunghe pause di riflessione:
  lo schermo non deve mai spegnersi durante una partita.
- L'host sbaglia ad assegnare i punti. L'annulla deve essere sempre
  raggiungibile con un pollice, mai sepolto in un menu.
- La generazione IA richiede decine di secondi. L'attesa va progettata,
  non nascosta dietro uno spinner.

## Stack
- Riverpod per lo stato, go_router per la navigazione
- dio + retrofit per le API, freezed + json_serializable per i modelli
- flutter_animate per la coreografia, CustomPainter e shader per il resto
- Drift per la persistenza locale
- Prima di aggiungere un package non elencato qui, chiedi.

## Cosa NON fare
- NON usare i colori di default di Material 3 (il viola-lilla di
  `ColorScheme.fromSeed` senza seed personalizzato è un tell immediato).
- NON introdurre login, account, registrazione. L'identità è solo un
  UUID anonimo in shared_preferences.
- NON usare `Lottie` con file scaricati a caso: licenza non verificabile.
- NON lasciare `TODO` o widget segnaposto nel codice consegnato.

## Verifica
Dopo ogni modifica:
    cd app && flutter analyze && flutter test
Prima di dichiarare conclusa una fase:
    flutter build apk --debug
Se hai accesso a un emulatore, avvialo e cattura screenshot delle
schermate toccate dalla fase.

## Qualità minima non negoziabile
- 60fps stabili sulla griglia e nelle transizioni, verificati in profile
  mode, non a occhio.
- `MediaQuery.disableAnimationsOf(context)` rispettato ovunque: se
  l'utente ha ridotto le animazioni, le durate vanno a zero e nulla
  si rompe.
- `textScaler` fino a 2.0 senza overflow.
- Contrasto AA su ogni testo.
- Ogni elemento interattivo ha una `Semantics` label sensata.

## NOTE IMPORTANTI

- Tieni conto che il backend dovra alla fine girare su Azure