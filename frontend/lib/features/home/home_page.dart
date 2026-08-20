import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../data/providers.dart';
import '../../models/tabellone.dart';

/// La schermata iniziale: **lo scaffale dei tabelloni**.
///
/// Il concetto è lo stesso della griglia di gioco, e non per coerenza formale:
/// ciò che si tocca in questa app sono tessere, quindi anche un tabellone da
/// riaprire è una tessera. Stesso fondo, stessa faccia, stessa fuga a separarle.
///
/// L'ordine delle cose segue l'uso reale, non l'ordine in cui si scoprono: chi
/// torna sull'app quasi sempre vuole **riaprire un tabellone che ha già**, non
/// crearne uno. Quindi lo scaffale prende lo spazio, la creazione è un'azione
/// dichiarata in testa, e il codice altrui è l'utilità in fondo.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _codiceController = TextEditingController();

  @override
  void dispose() {
    _codiceController.dispose();
    super.dispose();
  }

  void _entraConCodice() {
    final codice = _codiceController.text.trim().toUpperCase();
    if (codice.isEmpty) return;
    context.go('/tabellone/$codice');
  }

  @override
  Widget build(BuildContext context) {
    final miei = ref.watch(mieiTabelloniProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, vincoli) {
            final largo = vincoli.maxWidth >= Misure.sogliaColonnaEtichetta;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Misure.s5,
                    Misure.s6,
                    Misure.s5,
                    Misure.s4,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _Testata(
                      largo: largo,
                      onCrea: () => context.go('/crea'),
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: Misure.s5),
                  sliver: SliverToBoxAdapter(
                    child: Text('I MIEI TABELLONI',
                        style: Tipografia.ferramenta),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: Misure.s3),
                ),
                ..._scaffale(context, miei, largo),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Misure.s5,
                    Misure.s7,
                    Misure.s5,
                    Misure.s6,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _CodiceAltrui(
                      controller: _codiceController,
                      onEntra: _entraConCodice,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _scaffale(
    BuildContext context,
    AsyncValue<List<TabelloneSintesi>> miei,
    bool largo,
  ) {
    Widget dentro(Widget figlio) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Misure.s5),
          sliver: SliverToBoxAdapter(child: figlio),
        );

    return switch (miei) {
      AsyncLoading() => [
          dentro(const _ScaffaleInAttesa()),
        ],
      AsyncError(:final error) => [
          dentro(
            _Avviso(
              testo: 'Non riesco a leggere i tuoi tabelloni. $error',
              onRiprova: () => ref.invalidate(mieiTabelloniProvider),
            ),
          ),
        ],
      AsyncValue(:final value) when value == null || value.isEmpty => [
          dentro(const _ScaffaleVuoto()),
        ],
      AsyncValue(:final value) => [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Misure.s5),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                // Su tablet lo scaffale usa tutta la larghezza invece di
                // restare una striscia al centro dello schermo.
                maxCrossAxisExtent: largo ? 340 : double.infinity,
                mainAxisSpacing: Misure.fuga,
                crossAxisSpacing: Misure.fuga,
                mainAxisExtent: _altezzaTessera(context),
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: value!.length,
                (context, i) => _TesseraTabellone(
                  key: Key('tabellone-${value[i].codicePubblico}'),
                  tabellone: value[i],
                  onTocco: () =>
                      context.go('/tabellone/${value[i].codicePubblico}'),
                ),
              ),
            ),
          ),
        ],
    };
  }

  /// L'altezza di una tessera-tabellone alla scala corrente.
  ///
  /// Calcolata e non fissa: a textScaler 2.0 un'altezza fissa taglierebbe il
  /// titolo, e qui il titolo è l'unica cosa che serve leggere.
  static double _altezzaTessera(BuildContext context) {
    final scala = MediaQuery.textScalerOf(context);
    final titolo = scala.scale(Tipografia.corpoRilievo.fontSize!) * 1.35 * 2;
    final meta = scala.scale(Tipografia.ferramenta.fontSize!) * 1.2;
    return math.max(
      Misure.areaTattileMinima,
      titolo + meta + Misure.s2 + Misure.s4 * 2,
    );
  }
}

/// Il nome dell'app, la riga che dice cos'è, e l'azione principale.
///
/// Niente icona dentro un riquadro arrotondato: era decorazione, e per di più
/// un fulmine non ha niente a che vedere con il soggetto. Al suo posto una
/// piccola rastrelliera di tessere, che è **letteralmente** l'app.
class _Testata extends StatelessWidget {
  const _Testata({required this.largo, required this.onCrea});

  final bool largo;
  final VoidCallback onCrea;

  @override
  Widget build(BuildContext context) {
    const nome = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Rastrelliera(),
        SizedBox(height: Misure.s4),
        Text('QUIZ GRID', style: Tipografia.marchio),
        SizedBox(height: Misure.s2),
        Text(
          'Un tabellone, delle squadre, e domande nuove ogni volta.',
          style: Tipografia.corpoMinore,
        ),
      ],
    );

    final crea = FilledButton.icon(
      key: const Key('crea-tabellone'),
      onPressed: onCrea,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Crea nuovo tabellone'),
    );

    if (!largo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          nome,
          const SizedBox(height: Misure.s5),
          crea,
        ],
      );
    }
    // Su schermo largo il nome e l'azione stanno sulla stessa riga: lo
    // scaffale sotto guadagna l'altezza che il titolo non si prende.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(child: nome),
        const SizedBox(width: Misure.s6),
        crea,
      ],
    );
  }
}

/// Quattro tessere, una in gioco: la stessa figura dell'icona del launcher.
class _Rastrelliera extends StatelessWidget {
  const _Rastrelliera();

  @override
  Widget build(BuildContext context) {
    Widget tessera(Color colore) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: colore,
            borderRadius: Misure.bordoTessera,
          ),
        );

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tessera(Colori.quadro),
          const SizedBox(width: Misure.fuga),
          tessera(Colori.ottone),
          const SizedBox(width: Misure.fuga),
          tessera(Colori.quadro),
          const SizedBox(width: Misure.fuga),
          tessera(Colori.quadro),
        ],
      ),
    );
  }
}

/// Un tabellone sullo scaffale.
class _TesseraTabellone extends StatelessWidget {
  const _TesseraTabellone({
    super.key,
    required this.tabellone,
    required this.onTocco,
  });

  final TabelloneSintesi tabellone;
  final VoidCallback onTocco;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tabellone.titolo}, '
          '${tabellone.righe} righe, codice ${tabellone.codicePubblico}',
      hint: 'apri il tabellone',
      excludeSemantics: true,
      child: Material(
        color: Colori.quadro,
        borderRadius: Misure.bordoCartellino,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTocco,
          child: Padding(
            padding: const EdgeInsets.all(Misure.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tabellone.titolo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Tipografia.corpoRilievo,
                ),
                Text(
                  '${tabellone.codicePubblico} · ${tabellone.righe} righe',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tipografia.ferramenta,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lo scaffale mentre carica: tessere vuote al posto di uno spinner al centro.
///
/// Non è un vezzo: una rotellina non dice quanto manca né cosa sta arrivando,
/// mentre delle tessere spente dicono già che arriveranno dei tabelloni.
class _ScaffaleInAttesa extends StatelessWidget {
  const _ScaffaleInAttesa();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sto caricando i tuoi tabelloni',
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Misure.fuga),
              child: Container(
                height: Misure.areaTattileMinima + Misure.s5,
                decoration: BoxDecoration(
                  border: Border.all(color: Colori.acciaio),
                  borderRadius: Misure.bordoCartellino,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScaffaleVuoto extends StatelessWidget {
  const _ScaffaleVuoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Misure.s5),
      decoration: BoxDecoration(
        border: Border.all(color: Colori.acciaio),
        borderRadius: Misure.bordoCartellino,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lo scaffale è vuoto', style: Tipografia.corpoRilievo),
          SizedBox(height: Misure.s2),
          Text(
            'Crea il tuo primo tabellone: scegli gli argomenti e le domande '
            'le scrive l\'IA. Ci vuole un minuto.',
            style: Tipografia.corpoMinore,
          ),
        ],
      ),
    );
  }
}

/// L'errore: bordo pieno, nessun riempimento traslucido, e un modo per riprovare.
class _Avviso extends StatelessWidget {
  const _Avviso({required this.testo, this.onRiprova});

  final String testo;
  final VoidCallback? onRiprova;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Misure.s4),
      decoration: BoxDecoration(
        border: Border.all(color: Colori.segnale),
        borderRadius: Misure.bordoCartellino,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colori.segnale),
              const SizedBox(width: Misure.s3),
              Expanded(
                child: Text(
                  testo,
                  style: Tipografia.corpo.copyWith(color: Colori.segnale),
                ),
              ),
            ],
          ),
          if (onRiprova != null) ...[
            const SizedBox(height: Misure.s3),
            OutlinedButton(
              key: const Key('riprova-tabelloni'),
              onPressed: onRiprova,
              child: const Text('Riprova'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Entrare nel tabellone di qualcun altro. È l'utilità, non l'azione
/// principale: sta in fondo, e lo dice anche il corpo del testo.
class _CodiceAltrui extends StatelessWidget {
  const _CodiceAltrui({required this.controller, required this.onEntra});

  final TextEditingController controller;
  final VoidCallback onEntra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('HAI IL CODICE DI QUALCUN ALTRO?', style: Tipografia.ferramenta),
        const SizedBox(height: Misure.s3),
        // IntrinsicHeight: il pulsante si allinea al campo anche quando il
        // campo cresce con il textScaler, invece di restare a un'altezza fissa.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('campo-codice'),
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.go,
                  inputFormatters: [
                    UpperCaseFormatter(),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  style: Tipografia.corpoRilievo.copyWith(letterSpacing: 3),
                  decoration: const InputDecoration(
                    hintText: 'KDSYMS',
                    labelText: 'Codice tabellone',
                  ),
                  onSubmitted: (_) => onEntra(),
                ),
              ),
              const SizedBox(width: Misure.s3),
              OutlinedButton(
                key: const Key('entra-codice'),
                onPressed: onEntra,
                child: const Text('Entra'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// I codici del backend sono maiuscoli: convertirli mentre si scrive evita che
/// l'utente veda una cosa e ne invii un'altra.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue vecchio,
    TextEditingValue nuovo,
  ) =>
      TextEditingValue(
        text: nuovo.text.toUpperCase(),
        selection: nuovo.selection,
      );
}
