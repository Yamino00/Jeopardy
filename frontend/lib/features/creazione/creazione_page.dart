import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// Board creation: title, topic chips, rows. During generation the wait is
/// long (one LLM call per difficulty band per category on a cold bank), so
/// the UI walks through the categories instead of showing a single spinner.
class CreazionePage extends ConsumerStatefulWidget {
  const CreazionePage({super.key});

  @override
  ConsumerState<CreazionePage> createState() => _CreazionePageState();
}

class _CreazionePageState extends ConsumerState<CreazionePage> {
  final _titoloController = TextEditingController();
  final _argomentoController = TextEditingController();
  final List<String> _argomenti = [];
  int _righe = 5;
  int _puntiBase = 100;

  bool _generating = false;
  int _categoriaInCorso = 0;
  Timer? _progressTimer;
  String? _errore;

  static const int _maxArgomenti = 6;

  /// Rough per-category estimate used only to advance the progress list;
  /// the real completion arrives with the API response.
  static const Duration _stimaPerCategoria = Duration(seconds: 9);

  @override
  void dispose() {
    _titoloController.dispose();
    _argomentoController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _aggiungiArgomento() {
    final value = _argomentoController.text.trim();
    if (value.isEmpty || _argomenti.length >= _maxArgomenti) return;
    if (_argomenti.any((a) => a.toLowerCase() == value.toLowerCase())) return;
    setState(() {
      _argomenti.add(value);
      _argomentoController.clear();
    });
  }

  Future<void> _crea() async {
    final titolo = _titoloController.text.trim();
    if (titolo.isEmpty || _argomenti.isEmpty) {
      setState(() =>
          _errore = 'Servono un titolo e almeno un argomento per iniziare');
      return;
    }
    setState(() {
      _errore = null;
      _generating = true;
      _categoriaInCorso = 0;
    });
    _progressTimer = Timer.periodic(_stimaPerCategoria, (_) {
      if (_categoriaInCorso < _argomenti.length - 1) {
        setState(() => _categoriaInCorso++);
      }
    });

    try {
      final tabellone = await ref.read(tabelloneRepositoryProvider).crea(
            titolo: titolo,
            argomenti: _argomenti,
            righe: _righe,
            puntiBase: _puntiBase,
          );
      if (!mounted) return;
      ref.invalidate(mieiTabelloniProvider);
      context.go('/tabellone/${tabellone.codicePubblico}'
          '?modifica=${tabellone.codiceModifica}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _errore = e.toString();
      });
    } finally {
      _progressTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo tabellone'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _generating ? _buildProgress() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          key: const Key('campo-titolo'),
          controller: _titoloController,
          decoration: const InputDecoration(
            labelText: 'Titolo del quiz',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('campo-argomento'),
                controller: _argomentoController,
                decoration: InputDecoration(
                  labelText: 'Aggiungi argomento',
                  hintText: 'es. Storia romana',
                  border: const OutlineInputBorder(),
                  helperText:
                      '${_argomenti.length}/$_maxArgomenti categorie',
                ),
                onSubmitted: (_) => _aggiungiArgomento(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const Key('aggiungi-argomento'),
              onPressed: _argomenti.length >= _maxArgomenti
                  ? null
                  : _aggiungiArgomento,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final argomento in _argomenti)
              Chip(
                label: Text(argomento),
                onDeleted: () =>
                    setState(() => _argomenti.remove(argomento)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Righe per categoria',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 5, label: Text('5')),
          ],
          selected: {_righe},
          onSelectionChanged: (s) => setState(() => _righe = s.first),
        ),
        const SizedBox(height: 20),
        Text('Punti base (valore della prima riga)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 100, label: Text('100')),
            ButtonSegment(value: 200, label: Text('200')),
            ButtonSegment(value: 500, label: Text('500')),
          ],
          selected: {_puntiBase},
          onSelectionChanged: (s) => setState(() => _puntiBase = s.first),
        ),
        const SizedBox(height: 28),
        if (_errore != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errore!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton.icon(
          key: const Key('genera-tabellone'),
          onPressed: _crea,
          icon: const Icon(Icons.auto_awesome),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          label: const Text('Genera il tabellone'),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sto preparando il tabellone...',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Le domande nuove vengono generate dall\'IA: '
            'puo volerci qualche istante per categoria.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _argomenti.length; i++)
            ListTile(
              leading: i < _categoriaInCorso
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : i == _categoriaInCorso
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Icon(Icons.hourglass_empty),
              title: Text(_argomenti[i]),
              subtitle: Text(i < _categoriaInCorso
                  ? 'Pronta'
                  : i == _categoriaInCorso
                      ? 'Cerco in banca e genero le domande mancanti...'
                      : 'In attesa'),
            ),
        ],
      ),
    );
  }
}
