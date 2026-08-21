import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/design/design.dart';
import 'data/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: QuizApp()));
}

class QuizApp extends ConsumerStatefulWidget {
  const QuizApp({super.key});

  @override
  ConsumerState<QuizApp> createState() => _QuizAppState();
}

class _QuizAppState extends ConsumerState<QuizApp> {
  @override
  void initState() {
    super.initState();
    // Il backend dorme quando nessuno gioca e ci mette una ventina di secondi
    // a rialzarsi. Bussare adesso, senza aspettare risposta, gli dà il tempo
    // di svegliarsi mentre l'host sceglie gli argomenti.
    ref.read(apiClientProvider).risveglia();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Quiz Grid',
      theme: Tema.scuro,
      routerConfig: router,
    );
  }
}
