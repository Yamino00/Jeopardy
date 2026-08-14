import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/generazione/generazione_placeholder_page.dart';
import '../../features/partita/partita_placeholder_page.dart';
import '../../features/tabellone/tabellone_placeholder_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/tabellone',
    routes: [
      GoRoute(
        path: '/tabellone',
        builder: (context, state) => const TabellonePlaceholderPage(),
      ),
      GoRoute(
        path: '/partita',
        builder: (context, state) => const PartitaPlaceholderPage(),
      ),
      GoRoute(
        path: '/generazione',
        builder: (context, state) => const GenerazionePlaceholderPage(),
      ),
    ],
  );
});
