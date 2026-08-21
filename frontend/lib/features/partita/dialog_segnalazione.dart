import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../data/segnalazione_repository.dart';

/// Cosa scegliere quando una domanda è sbagliata.
///
/// Restituisce `(motivo, nota)` oppure `null` se annullato.
///
/// Il motivo **si sceglie**, non si scrive: a metà partita, con il gruppo che
/// aspetta, nessuno compila un campo libero. La nota resta, ma è facoltativa e
/// non blocca l'invio — è per chi vuole spiegare, non un pedaggio per chi vuole
/// solo andare avanti.
class DialogSegnalazione extends StatefulWidget {
  const DialogSegnalazione({
    super.key,
    required this.nomeCategoria,
    required this.valore,
  });

  final String nomeCategoria;
  final int valore;

  @override
  State<DialogSegnalazione> createState() => _DialogSegnalazioneState();
}

class _DialogSegnalazioneState extends State<DialogSegnalazione> {
  MotivoSegnalazione? _motivo;
  late final TextEditingController _nota;

  @override
  void initState() {
    super.initState();
    _nota = TextEditingController();
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colori.quadro,
      shape: const RoundedRectangleBorder(borderRadius: Misure.bordoCartellino),
      title: const Text('Segnala la domanda'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Misure.larghezzaLettura),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.nomeCategoria.toUpperCase()} · ${widget.valore}',
                style: Tipografia.ferramenta,
              ),
              const SizedBox(height: Misure.s4),
              const Text('Che cosa non va?', style: Tipografia.corpo),
              const SizedBox(height: Misure.s2),
              for (final motivo in MotivoSegnalazione.values)
                _RigaMotivo(
                  motivo: motivo,
                  scelto: _motivo == motivo,
                  onScelta: () => setState(() => _motivo = motivo),
                ),
              const SizedBox(height: Misure.s4),
              TextField(
                key: const Key('nota-segnalazione'),
                controller: _nota,
                maxLines: 3,
                minLines: 1,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Nota (facoltativa)',
                  hintText: 'La risposta giusta sarebbe…',
                ),
              ),
              // Quante ne servano lo dice il server, e lo dice **dopo**: la
              // soglia è un valore di configurazione, e tenerne qui una copia
              // significherebbe mentire il giorno in cui cambia.
              const Text(
                'La segnalazione vale sulla domanda condivisa: raccolte '
                'abbastanza segnalazioni da dispositivi diversi, non comparirà '
                'più nei tabelloni nuovi. Questa partita non cambia — la cella '
                'resta dov\'è.',
                style: Tipografia.ferramenta,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('invia-segnalazione'),
          // Senza motivo non si invia: è l'unico dato che il backend usa, e
          // spedire un motivo di default falserebbe la statistica di tutti.
          onPressed: _motivo == null
              ? null
              : () => Navigator.of(context).pop(
                    (motivo: _motivo!, nota: _nota.text),
                  ),
          child: const Text('Segnala'),
        ),
      ],
    );
  }
}

/// Un motivo, come riga tappabile alta quanto un pollice.
///
/// Non è un `RadioListTile`: la selezione non si affida al solo colore del
/// pallino, ma porta anche un contorno e un'icona piena — così resta leggibile
/// in bianco e nero e a un metro e mezzo.
class _RigaMotivo extends StatelessWidget {
  const _RigaMotivo({
    required this.motivo,
    required this.scelto,
    required this.onScelta,
  });

  final MotivoSegnalazione motivo;
  final bool scelto;
  final VoidCallback onScelta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: scelto,
      button: true,
      label: motivo.etichetta,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Misure.s2),
        child: InkWell(
          key: Key('motivo-${motivo.valore}'),
          onTap: onScelta,
          borderRadius: Misure.bordoCartellino,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: Misure.areaTattileMinima,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Misure.s3,
              vertical: Misure.s2,
            ),
            decoration: BoxDecoration(
              borderRadius: Misure.bordoCartellino,
              border: Border.all(
                color: scelto ? Colori.ottone : Colori.acciaio,
                width: scelto ? Misure.bordoLuce : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  scelto
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: scelto ? Colori.ottone : Colori.acciaio,
                ),
                const SizedBox(width: Misure.s3),
                Expanded(
                  child: Text(motivo.etichetta, style: Tipografia.corpo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
