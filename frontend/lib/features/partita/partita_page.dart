import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/widgets/animazioni.dart';
import '../../core/widgets/raccolta_tessere.dart';
import '../../core/widgets/schermo_sveglio.dart';
import '../../core/widgets/punteggio_palette.dart';
import '../../core/widgets/tessera.dart';
import 'azioni_in_attesa.dart';
import 'cella_senza_domanda.dart';
import 'placca_domanda.dart';
import '../../data/providers.dart';
import '../../data/tabellone_repository.dart';
import '../../models/partita.dart';
import '../../models/tabellone.dart';
import '../../core/widgets/stato_errore.dart';

/// The live game: board grid, fullscreen cell with two-step reveal,
/// and the always-visible team bar with undo.
class PartitaPage extends ConsumerWidget {
  const PartitaPage({super.key, required this.partitaId});

  final int partitaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partitaAsync = ref.watch(partitaVisualizzataProvider(partitaId));

    return partitaAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.go('/'))),
        body: StatoErrore(
          errore: e,
          onRiprova: () => ref.invalidate(partitaProvider(partitaId)),
          onIndietro: () => context.go('/'),
        ),
      ),
      data: (partita) {
        final tabelloneAsync =
            ref.watch(tabelloneProvider(partita.codiceTabellone));
        return tabelloneAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar:
                AppBar(leading: BackButton(onPressed: () => context.go('/'))),
            body: StatoErrore(
              errore: e,
              onRiprova: () =>
                  ref.invalidate(tabelloneProvider(partita.codiceTabellone)),
              onIndietro: () => context.go('/'),
            ),
          ),
          data: (tabellone) => _PartitaBody(
            partita: partita,
            tabellone: tabellone,
          ),
        );
      },
    );
  }
}

/// La griglia, che guarda **solo** quali celle sono state giocate.
///
/// S1: prima l'intera pagina osservava la `Partita` e ogni azione ricostruiva
/// tutto — fino a trenta celle piu' la barra squadre — anche per un semplice
/// cambio di punteggio, che alla griglia non interessa. Qui il `select` su una
/// chiave confrontabile per valore fa si' che la griglia si ricostruisca
/// soltanto quando una cella cambia stato.
class _GrigliaPartita extends ConsumerWidget {
  const _GrigliaPartita({
    required this.partitaId,
    required this.tabellone,
    required this.onApri,
  });

  final int partitaId;
  final Tabellone tabellone;
  final void Function(int cellaId) onApri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fetta = ref.watch(
      partitaVisualizzataProvider(partitaId).select(
        (async) => async.whenData(
          (p) => (giocate: p.chiaveCelleGiocate, inCorso: p.inCorso),
        ),
      ),
    );
    final dati = fetta.valueOrNull;
    if (dati == null) return const SizedBox.shrink();

    final giocate = dati.giocate.isEmpty
        ? const <String>{}
        : dati.giocate.split(',').toSet();

    return RaccoltaTessere(
      categorie: [
        for (final categoria in tabellone.categorie)
          CategoriaTessere(
            nome: categoria.nomeDisplay,
            tessere: [
              for (final cella in categoria.celle)
                DatiTessera(
                  id: cella.id,
                  valore: cella.valore,
                  stato: giocate.contains('${cella.id}')
                      ? StatoTessera.dorso
                      : StatoTessera.faccia,
                ),
            ],
          ),
      ],
      onTocco: dati.inCorso ? onApri : null,
    );
  }
}

class _PartitaBody extends ConsumerWidget {
  const _PartitaBody({required this.partita, required this.tabellone});

  final Partita partita;
  final Tabellone tabellone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lo schermo resta acceso **solo** mentre la partita e' in corso: su una
    // partita conclusa il telefono torna a comportarsi come sempre.
    return SchermoSveglio(
      attivo: partita.inCorso,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(color: Colori.notte),
          child: Column(
            children: [
              AppBar(
                title: Text(tabellone.titolo),
                leading: BackButton(onPressed: () => context.go('/')),
                actions: [
                  TextButton.icon(
                    key: const Key('concludi-partita'),
                    onPressed:
                        partita.inCorso ? () => _concludi(context, ref) : null,
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: const Text('Concludi'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Misure.s3),
                  child: _GrigliaPartita(
                    partitaId: partita.id,
                    tabellone: tabellone,
                    onApri: (id) => _apriCella(context, ref, id),
                  ),
                ),
              ),
              StrisciaAzioniInAttesa(partitaId: partita.id),
            BarraSquadre(partitaId: partita.id),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _apriCella(
      BuildContext context, WidgetRef ref, int cellaId) async {
    for (final categoria in tabellone.categorie) {
      for (final cella in categoria.celle) {
        if (cella.id != cellaId) continue;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => CellaDialog(
            partitaId: partita.id,
            codiceTabellone: tabellone.codicePubblico,
            cella: cella,
            nomeCategoria: categoria.nomeDisplay,
            squadre: partita.squadreAttive,
          ),
        );
        return;
      }
    }
    // Nessuna categoria contiene la cella: prima era uno `StateError` non
    // gestito (E5). Non c'e' niente da mostrare, quindi non si mostra niente.
  }

  Future<void> _concludi(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colori.quadro,
        shape:
            const RoundedRectangleBorder(borderRadius: Misure.bordoCartellino),
        title: const Text('Concludere la partita?'),
        content: const Text('I punteggi diventeranno definitivi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No')),
          FilledButton(
              key: const Key('conferma-concludi'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Concludi')),
        ],
      ),
    );
    if (conferma != true || !context.mounted) return;
    await ref.read(partitaProvider(partita.id).notifier).concludi();
    if (context.mounted) {
      context.go('/partita/${partita.id}/riepilogo');
    }
  }
}

/// La cella aperta: la placca a tutto schermo.
///
/// Il dialog non disegna niente da sé — sceglie **quale** superficie mostrare
/// (la placca, oppure lo stato "questa cella non ha una domanda") e possiede lo
/// stato asincrono. Il disegno sta in `placca_domanda.dart` e
/// `cella_senza_domanda.dart`, che si montano in un test senza Riverpod.
class CellaDialog extends ConsumerStatefulWidget {
  const CellaDialog({
    super.key,
    required this.partitaId,
    required this.codiceTabellone,
    required this.cella,
    required this.nomeCategoria,
    required this.squadre,
  });

  final int partitaId;
  final String codiceTabellone;
  final Cella cella;
  final String nomeCategoria;
  final List<Squadra> squadre;

  @override
  ConsumerState<CellaDialog> createState() => _CellaDialogState();
}

class _CellaDialogState extends ConsumerState<CellaDialog> {
  bool _rispostaVisibile = false;
  bool _inviando = false;

  /// La cella corrente: cambia sotto i piedi quando viene rigenerata o
  /// corretta a mano, e da quel momento la placca la usa come qualunque altra.
  late Cella _cella;

  EsitoTentativo _esito = EsitoTentativo.nessuno;
  String? _messaggioErrore;

  @override
  void initState() {
    super.initState();
    _cella = widget.cella;
  }

  Future<void> _gioca(String esito, int delta, int? squadraId) async {
    if (_inviando) return;
    setState(() => _inviando = true);
    try {
      await ref.read(partitaProvider(widget.partitaId).notifier).giocaCella(
            cellaId: _cella.id,
            esito: esito,
            deltaPunti: delta,
            squadraId: squadraId,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _inviando = false);
        ScaffoldMessenger.of(context).showSnackBar(barraErrore(e));
      }
    }
  }

  Future<void> _rigenera(String codiceModifica) async {
    setState(() {
      _esito = EsitoTentativo.inCorso;
      _messaggioErrore = null;
    });
    try {
      final risultato =
          await ref.read(tabelloneRepositoryProvider).rigeneraCella(
                codicePubblico: widget.codiceTabellone,
                codiceModifica: codiceModifica,
                cellaId: _cella.id,
              );
      if (!mounted) return;
      switch (risultato) {
        case RigenerazioneRiuscita(cella: final nuova):
          // Il tabellone in cache non sa della nuova domanda: va invalidato,
          // altrimenti la griglia resta con la cella vecchia.
          ref.invalidate(tabelloneProvider(widget.codiceTabellone));
          setState(() {
            _cella = nuova;
            _esito = EsitoTentativo.nessuno;
          });
        case NessunaAlternativa():
          // Esito atteso, non errore: nessuno snackbar rosso.
          setState(() => _esito = EsitoTentativo.esaurita);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _esito = EsitoTentativo.errore;
          _messaggioErrore = '$e';
        });
      }
    }
  }

  Future<void> _correggi(String codiceModifica) async {
    final correzione = await showDialog<({String testo, String risposta})>(
      context: context,
      builder: (_) => DialogCorrezioneCella(
        nomeCategoria: widget.nomeCategoria,
        valore: _cella.valore,
        testoIniziale: _cella.senzaDomanda ? '' : (_cella.testo ?? ''),
        rispostaIniziale: _cella.risposta ?? '',
      ),
    );
    if (correzione == null || !mounted) return;

    setState(() {
      _esito = EsitoTentativo.inCorso;
      _messaggioErrore = null;
    });
    try {
      final tabellone =
          await ref.read(tabelloneRepositoryProvider).correggiCella(
                codicePubblico: widget.codiceTabellone,
                codiceModifica: codiceModifica,
                cellaId: _cella.id,
                testo: correzione.testo,
                risposta: correzione.risposta,
              );
      if (!mounted) return;
      ref.invalidate(tabelloneProvider(widget.codiceTabellone));
      // La risposta del PUT è il tabellone intero: la cella corretta si
      // ripesca da lì invece di fidarsi di quello che abbiamo inviato.
      Cella? aggiornata;
      for (final categoria in tabellone.categorie) {
        for (final c in categoria.celle) {
          if (c.id == _cella.id) aggiornata = c;
        }
      }
      setState(() {
        _cella = aggiornata ?? _cella;
        _esito = EsitoTentativo.nessuno;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _esito = EsitoTentativo.errore;
          _messaggioErrore = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nullo quando questo dispositivo non ha creato il tabellone: allora le
    // azioni di riparazione non esistono, perché il backend le rifiuterebbe.
    final codiceModifica =
        ref.watch(codiceModificaProvider(widget.codiceTabellone)).valueOrNull;

    return Dialog.fullscreen(
      backgroundColor: Colori.notte,
      child: _cella.senzaDomanda
          ? CellaSenzaDomanda(
              nomeCategoria: widget.nomeCategoria,
              valore: _cella.valore,
              puoRiparare: codiceModifica != null,
              esito: _esito,
              messaggioErrore: _messaggioErrore,
              onChiudi: () => Navigator.of(context).pop(),
              onRigenera: () => _rigenera(codiceModifica!),
              onCorreggi: () => _correggi(codiceModifica!),
              onPassa: () => _gioca('passata', 0, null),
            )
          : PlaccaDomanda(
              nomeCategoria: widget.nomeCategoria,
              valore: _cella.valore,
              domanda: _cella.testo ?? '',
              risposta: _cella.risposta ?? '',
              rispostaVisibile: _rispostaVisibile,
              inviando: _inviando,
              squadre: [
                for (final squadra in widget.squadre)
                  (
                    id: squadra.id,
                    nome: squadra.nome,
                    colore: coloreDaHex(squadra.colore),
                  ),
              ],
              onChiudi: () => Navigator.of(context).pop(),
              onMostraRisposta: () => setState(() => _rispostaVisibile = true),
              onAssegna: (squadraId, positivo) => _gioca(
                positivo ? 'corretta' : 'errata',
                positivo ? _cella.valore : -_cella.valore,
                squadraId,
              ),
              onPassa: () => _gioca('passata', 0, null),
            ),
    );
  }
}

/// Always-visible team bar: scores (long-press to edit), add team,
/// and the ever-reachable undo button.
/// Il podio, sempre visibile, con l'annulla sempre raggiungibile.
///
/// S3: prima riceveva la `Partita` dal costruttore, quindi si ricostruiva per
/// intero insieme al padre invece di isolarsi sul solo dato che le serve.
class BarraSquadre extends ConsumerWidget {
  const BarraSquadre({super.key, required this.partitaId});

  final int partitaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      partitaVisualizzataProvider(partitaId).select(
        (a) => a.whenData((p) => p.chiaveSquadre),
      ),
    );
    if (async.valueOrNull == null) return const SizedBox.shrink();
    // La chiave serve solo a decidere *quando* ricostruire; i dati veri si
    // leggono una volta sola, qui.
    // La proiezione, non lo stato grezzo: altrimenti offline i punteggi
    // restano fermi a quello che il server sapeva prima della disconnessione,
    // mentre la griglia si aggiorna — e il podio contraddice il tabellone.
    final partita =
        ref.read(partitaVisualizzataProvider(partitaId)).requireValue;
    final notifier = ref.read(partitaProvider(partitaId).notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Colori.notte,
        border: Border(
          top: BorderSide(color: Colori.quadro),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 92,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  children: [
                    for (final squadra in partita.squadreAttive)
                      _SquadraCard(
                        squadra: squadra,
                        inTurno: squadra.id == partita.turnoSquadraId,
                        onLongPress: () =>
                            _modificaSquadra(context, notifier, squadra),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('aggiungi-squadra-partita'),
                tooltip: 'Aggiungi squadra',
                onPressed: partita.inCorso
                    ? () => _aggiungiSquadra(
                        context, notifier, partita.squadre.length)
                    : null,
                icon: const Icon(Icons.group_add_rounded),
              ),
              PremibileAnimato(
                onTap: partita.inCorso
                    ? () async {
                        try {
                          final evento = await notifier.annulla();
                          if (!context.mounted) return;
                          // Il backend restituisce l'evento annullato: si dice
                          // cosa e' tornato indietro invece di farlo in
                          // silenzio. Con un host che sbaglia ad assegnare i
                          // punti, e' l'informazione piu' utile dell'app.
                          // Nullo significa che e' stata tolta un'azione
                          // dalla coda: il server non l'aveva mai vista,
                          // quindi non c'e' nessun evento da raccontare.
                          final String messaggio;
                          if (evento == null) {
                            messaggio = 'Annullata: era in attesa, '
                                'non era ancora arrivata al server';
                          } else {
                            final nome = partita.squadre
                                .where((s) => s.id == evento.squadraId)
                                .map((s) => s.nome)
                                .firstOrNull;
                            messaggio =
                                'Annullato: ${evento.descrizione(nome)}';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(messaggio),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(barraErrore(e));
                          }
                        }
                      }
                    : null,
                child: Semantics(
                  button: true,
                  enabled: partita.inCorso,
                  label: "Annulla l'ultima azione",
                  excludeSemantics: true,
                  child: Container(
                    key: const Key('annulla-evento'),
                    margin: const EdgeInsets.symmetric(horizontal: Misure.s1),
                    // CLAUDE.md: "L'annulla deve essere sempre raggiungibile
                    // con un pollice, mai sepolto in un menu". Area piu' grande
                    // del minimo, perche' l'host la cerca col pollice mentre
                    // guarda il tavolo invece dello schermo.
                    width: Misure.areaAnnulla,
                    height: Misure.areaAnnulla,
                    decoration: BoxDecoration(
                      color: Colori.quadro,
                      borderRadius: Misure.bordoCartellino,
                      border: Border.all(
                        color:
                            partita.inCorso ? Colori.ottone : Colori.acciaio,
                      ),
                    ),
                    child: Icon(
                      Icons.undo_rounded,
                      // C3: l'annulla disabilitato era Colors.white24, cioe'
                      // 2,1:1. Acciaio sta a 5,14:1 sul Quadro.
                      color: partita.inCorso ? Colori.ottone : Colori.acciaio,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _aggiungiSquadra(
    BuildContext context,
    PartitaNotifier notifier,
    int quanteSquadre,
  ) async {
    // E6: i controller creati per un dialog vanno smaltiti alla chiusura.
    // Prima ne restava uno appeso per ogni apertura.
    final controller = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colori.quadro,
        shape:
            const RoundedRectangleBorder(borderRadius: Misure.bordoCartellino),
        title: const Text('Nuova squadra'),
        content: TextField(
          key: const Key('campo-nuova-squadra'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla')),
          FilledButton(
            key: const Key('conferma-nuova-squadra'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nome == null || nome.isEmpty) return;
    final colore =
        SmaltiSquadra.tutti[quanteSquadre % SmaltiSquadra.tutti.length];
    await notifier.aggiungiSquadra(nome, colore: hexDaColore(colore));
  }

  Future<void> _modificaSquadra(
      BuildContext context, PartitaNotifier notifier, Squadra squadra) async {
    final nomeController = TextEditingController(text: squadra.nome);
    final punteggioController =
        TextEditingController(text: '${squadra.punteggio}');
    final azione = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colori.quadro,
        shape:
            const RoundedRectangleBorder(borderRadius: Misure.bordoCartellino),
        title: Text('Modifica ${squadra.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('campo-punteggio'),
              controller: punteggioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Punteggio',
                helperText: 'La correzione finisce nel log eventi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('rimuovi'),
            child:
                const Text('Rimuovi', style: TextStyle(color: Colori.segnale)),
          ),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla')),
          FilledButton(
            key: const Key('salva-squadra'),
            onPressed: () => Navigator.of(context).pop('salva'),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    // I valori si leggono prima di smaltire i controller.
    final nuovoNome = nomeController.text.trim();
    final punteggio = int.tryParse(punteggioController.text.trim());
    nomeController.dispose();
    punteggioController.dispose();

    if (azione == null) return;
    if (azione == 'rimuovi') {
      await notifier.rimuoviSquadra(squadra.id);
      return;
    }
    await notifier.aggiornaSquadra(
      squadra.id,
      nome: nuovoNome.isEmpty ? null : nuovoNome,
      punteggio: punteggio,
    );
  }
}

class _SquadraCard extends StatelessWidget {
  const _SquadraCard({
    required this.squadra,
    required this.inTurno,
    required this.onLongPress,
  });

  final Squadra squadra;
  final bool inTurno;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colore = coloreDaHex(squadra.colore);
    return PremibileAnimato(
      onLongPress: onLongPress,
      etichetta: '${squadra.nome}, ${squadra.punteggio} punti'
          '${inTurno ? ", di turno" : ""}',
      suggerimento: 'tieni premuto per correggere il punteggio o rimuovere',
      child: AnimatedContainer(
        key: Key('squadra-${squadra.id}'),
        duration: context.durata(Movimento.normale),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // Il colore squadra non sta dietro del testo: e' l'intarsio nella
          // riga sotto. Qui il fondo e' la superficie di sistema, e il bordo
          // di luce dice soltanto di chi e' il turno.
          color: Colori.quadro,
          borderRadius: Misure.bordoCartellino,
          border: Border.all(
            color: inTurno ? Colori.ottone : Colori.acciaio,
            width: inTurno ? Misure.bordoLuce : 1,
          ),
          boxShadow: inTurno ? Luce.alone() : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: colore, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    squadra.nome,
                    style: Tipografia.nomeSquadra,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            PunteggioPalette(
              key: Key('punteggio-${squadra.id}'),
              valore: squadra.punteggio,
              dimensione: 22,
            ),
          ],
        ),
      ),
    );
  }
}
