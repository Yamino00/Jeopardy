import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tabellone.dart';
import 'providers.dart';

/// A che punto è la creazione di un tabellone.
sealed class StatoGenerazione {
  const StatoGenerazione();
}

class GenerazioneFerma extends StatoGenerazione {
  const GenerazioneFerma();
}

class GenerazioneInCorso extends StatoGenerazione {
  const GenerazioneInCorso({required this.argomenti, required this.iniziataIl});

  final List<String> argomenti;
  final DateTime iniziataIl;

  /// Stima grossolana, presentata **come stima** e non come barra che avanza.
  ///
  /// D10: il commento del codice precedente diceva "una chiamata al modello per
  /// fascia di difficoltà per categoria" e stimava 9 secondi a categoria, ma il
  /// backend è stato unificato a **una sola chiamata per categoria**
  /// (`TabelloneService.fillCategoria`). La finta barra di avanzamento era
  /// tarata su un backend che non esiste più.
  Duration get stima => Duration(seconds: 8 * argomenti.length + 5);
}

class GenerazioneRiuscita extends StatoGenerazione {
  const GenerazioneRiuscita(this.tabellone);
  final Tabellone tabellone;
}

class GenerazioneFallita extends StatoGenerazione {
  const GenerazioneFallita(this.errore);
  final Object errore;
}

/// Lo stato della creazione di un tabellone.
///
/// S2: prima viveva in tre campi di uno `StatefulWidget` più un
/// `Timer.periodic` dentro `setState`. Un'operazione asincrona da decine di
/// secondi in un widget significa che uscendo dalla schermata diventa
/// inosservabile, non è testabile e non si può riprendere. Qui vive in un
/// provider, quindi sopravvive alla schermata.
final generazioneProvider =
    NotifierProvider<GenerazioneNotifier, StatoGenerazione>(
  GenerazioneNotifier.new,
);

class GenerazioneNotifier extends Notifier<StatoGenerazione> {
  @override
  StatoGenerazione build() => const GenerazioneFerma();

  bool get inCorso => state is GenerazioneInCorso;

  /// Quante generazioni consuma creare un tabellone con questi argomenti.
  ///
  /// D11: la creazione è **transazionale**. Se la quarta categoria di sei
  /// esaurisce la quota, l'intera transazione fa rollback e l'utente perde un
  /// minuto senza ottenere niente. Il numero si può stimare in anticipo — una
  /// generazione per categoria — e dirlo prima è l'unico modo di prevenirlo.
  static int costoStimato(int quanteCategorie) => quanteCategorie;

  Future<void> crea({
    required String titolo,
    required List<String> argomenti,
    required int righe,
    required int puntiBase,
  }) async {
    // E7: due tocchi ravvicinati mandavano due POST, cioè due tabelloni e due
    // timer. Qui la seconda chiamata non parte.
    if (inCorso) return;

    state = GenerazioneInCorso(
      argomenti: List.unmodifiable(argomenti),
      iniziataIl: DateTime.now(),
    );

    try {
      final tabellone = await ref.read(tabelloneRepositoryProvider).crea(
            titolo: titolo,
            argomenti: argomenti,
            righe: righe,
            puntiBase: puntiBase,
          );
      // Il codice di modifica arriva **solo** in questa risposta: se non lo si
      // ricorda adesso, non lo si ricorda mai.
      await ref
          .read(codiciModificaStorageProvider)
          .ricorda(tabellone.codicePubblico, tabellone.codiceModifica);
      ref.invalidate(mieiTabelloniProvider);
      state = GenerazioneRiuscita(tabellone);
    } catch (e) {
      state = GenerazioneFallita(e);
    }
  }

  /// Torna al modulo, per esempio dopo un errore o dopo essere entrati nel
  /// tabellone appena creato.
  void reimposta() => state = const GenerazioneFerma();
}
