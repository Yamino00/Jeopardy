import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/creazione/creazione_page.dart';
import '../../features/home/home_page.dart';
import '../../features/partita/partita_page.dart';
import '../../features/partita/riepilogo_page.dart';
import '../../features/tabellone/tabellone_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/crea',
        builder: (context, state) => const CreazionePage(),
      ),
      GoRoute(
        path: '/tabellone/:codice',
        builder: (context, state) => TabellonePage(
          codice: state.pathParameters['codice']!,
          // Passato solo subito dopo la creazione, per mostrarlo una volta
          codiceModifica: state.uri.queryParameters['modifica'],
        ),
      ),
      GoRoute(
        path: '/partita/:id',
        builder: (context, state) => PartitaPage(
          partitaId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/partita/:id/riepilogo',
        builder: (context, state) => RiepilogoPage(
          partitaId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
});
