import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animazioni.dart';
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
      body: DecoratedBox(
        decoration: sfondoApp,
        child: Column(
          children: [
            AppBar(
              title: const Text('Nuovo tabellone'),
              leading: BackButton(onPressed: () => context.go('/')),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _generating ? _buildProgress() : _buildForm(),
                ),
              ),
            ),
          ],
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
        PremibileAnimato(
          onTap: _crea,
          child: Container(
            key: const Key('genera-tabellone'),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [jeopardyGold, Color(0xFFFF9F1C)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: bagliore(jeopardyGold, intensita: 0.32),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.black87),
                SizedBox(width: 10),
                Text('Genera il tabellone',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
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
            _RigaAvanzamento(
              nome: _argomenti[i],
              fatta: i < _categoriaInCorso,
              inCorso: i == _categoriaInCorso,
            ),
        ],
      ),
    );
  }
}

/// Una categoria nella schermata di attesa. Lo stato è leggibile a colpo
/// d'occhio dal colore del bordo, non solo dall'icona.
class _RigaAvanzamento extends StatelessWidget {
  const _RigaAvanzamento({
    required this.nome,
    required this.fatta,
    required this.inCorso,
  });

  final String nome;
  final bool fatta;
  final bool inCorso;

  @override
  Widget build(BuildContext context) {
    final colore = fatta
        ? const Color(0xFF4ADE80)
        : inCorso
            ? jeopardyGold
            : Colors.white24;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: inCorso ? 0.07 : 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colore.withValues(alpha: inCorso ? 0.6 : 0.25)),
        boxShadow: inCorso ? bagliore(jeopardyGold, intensita: 0.18) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: fatta
                ? const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF4ADE80), size: 22)
                : inCorso
                    ? const CircularProgressIndicator(
                        strokeWidth: 2.5, color: jeopardyGold)
                    : const Icon(Icons.hourglass_empty_rounded,
                        color: Colors.white24, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  fatta
                      ? 'Pronta'
                      : inCorso
                          ? 'Cerco in banca e genero le mancanti...'
                          : 'In attesa',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
