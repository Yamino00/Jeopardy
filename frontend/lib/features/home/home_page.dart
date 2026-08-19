import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animazioni.dart';
import '../../data/providers.dart';

/// Entry point: create a board, join with a code, or reopen your boards.
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
    if (codice.isNotEmpty) {
      context.go('/tabellone/$codice');
    }
  }

  @override
  Widget build(BuildContext context) {
    final miei = ref.watch(mieiTabelloniProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: sfondoApp,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                children: [
                  const ComparsaAnimata(indice: 0, child: _Intestazione()),
                  const SizedBox(height: 36),
                  ComparsaAnimata(
                    indice: 1,
                    child: _BottoneCrea(onTap: () => context.go('/crea')),
                  ),
                  const SizedBox(height: 14),
                  ComparsaAnimata(
                    indice: 2,
                    child: _RigaCodice(
                      controller: _codiceController,
                      onEntra: _entraConCodice,
                    ),
                  ),
                  const SizedBox(height: 36),
                  ComparsaAnimata(
                    indice: 3,
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view_rounded,
                            size: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        Text('I miei tabelloni',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  miei.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => _Avviso(
                      testo: 'Impossibile caricare i tabelloni.\n$e',
                    ),
                    data: (tabelloni) => tabelloni.isEmpty
                        ? const _Avviso(
                            testo: 'Nessun tabellone ancora: creane uno!',
                            neutro: true,
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < tabelloni.length; i++)
                                ComparsaAnimata(
                                  indice: 4 + i,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _SchedaTabellone(
                                      titolo: tabelloni[i].titolo,
                                      codice: tabelloni[i].codicePubblico,
                                      righe: tabelloni[i].righe,
                                      onTap: () => context.go(
                                          '/tabellone/${tabelloni[i].codicePubblico}'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Intestazione extends StatelessWidget {
  const _Intestazione();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: gradienteCategoria,
            borderRadius: BorderRadius.circular(22),
            boxShadow: bagliore(jeopardyBlueLight),
          ),
          child: const Icon(Icons.bolt_rounded, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [jeopardyGold, accentoMagenta],
          ).createShader(bounds),
          child: const Text(
            'QUIZ GRID',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              color: Colors.white,
              height: 1.05,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Quiz a griglia stile Jeopardy',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.white70, letterSpacing: 0.4),
        ),
      ],
    );
  }
}

class _BottoneCrea extends StatelessWidget {
  const _BottoneCrea({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremibileAnimato(
      onTap: onTap,
      child: Container(
        key: const Key('crea-tabellone'),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [jeopardyGold, Color(0xFFFF9F1C)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: bagliore(jeopardyGold, intensita: 0.35),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Colors.black87),
            SizedBox(width: 10),
            Text(
              'Crea nuovo tabellone',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RigaCodice extends StatelessWidget {
  const _RigaCodice({required this.controller, required this.onEntra});

  final TextEditingController controller;
  final VoidCallback onEntra;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('campo-codice'),
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Codice tabellone',
              hintText: 'ES. KDSYMS',
              prefixIcon: Icon(Icons.vpn_key_rounded, size: 20),
            ),
            onSubmitted: (_) => onEntra(),
          ),
        ),
        const SizedBox(width: 10),
        PremibileAnimato(
          onTap: onEntra,
          child: Container(
            key: const Key('entra-codice'),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: jeopardyBlueLight,
              borderRadius: BorderRadius.circular(14),
              boxShadow: bagliore(jeopardyBlueLight, intensita: 0.3),
            ),
            child: const Center(
              child: Text('Entra',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SchedaTabellone extends StatelessWidget {
  const _SchedaTabellone({
    required this.titolo,
    required this.codice,
    required this.righe,
    required this.onTap,
  });

  final String titolo;
  final String codice;
  final int righe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremibileAnimato(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: gradienteCella,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.grid_on_rounded,
                  size: 20, color: jeopardyGold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titolo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text('$codice · $righe righe',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          letterSpacing: 1)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _Avviso extends StatelessWidget {
  const _Avviso({required this.testo, this.neutro = false});

  final String testo;
  final bool neutro;

  @override
  Widget build(BuildContext context) {
    final colore =
        neutro ? Colors.white54 : Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colore.withValues(alpha: 0.25)),
      ),
      child: Text(testo, style: TextStyle(color: colore)),
    );
  }
}
