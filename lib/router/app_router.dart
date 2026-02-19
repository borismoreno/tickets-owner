import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/splash/presentation/splash_page.dart';
import '../features/auth/presentation/session_gate.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';

import '../features/events/presentation/events_list_page.dart';
import '../features/events/presentation/event_create_page.dart';
import '../features/events/presentation/event_detail_page.dart';

import '../features/sellers/presentation/sellers_list_page.dart';
import '../features/sellers/presentation/seller_create_page.dart';
import '../features/sellers/presentation/seller_detail_page.dart';

final appRouter = GoRouter(
  initialLocation: '/', // 👈 ahora la app inicia en Splash

  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    final goingToAuth = state.matchedLocation.startsWith('/auth');
    final goingToSplash = state.matchedLocation == '/';
    final goingToSessionGate = state.matchedLocation == '/session-gate';

    // Permitir splash y session gate siempre
    if (goingToSplash || goingToSessionGate) return null;

    // Si NO está logueado y quiere ir a events → login
    if (!isLoggedIn && !goingToAuth) {
      return '/auth/login';
    }

    // Si está logueado y quiere ir a login/register → events
    if (isLoggedIn && goingToAuth) {
      return '/events';
    }

    return null;
  },

  routes: [
    /// 🔵 Splash
    GoRoute(path: '/', builder: (_, __) => const SplashPage()),

    /// 🧠 Session Gate (decide ruta)
    GoRoute(path: '/session-gate', builder: (_, __) => const SessionGate()),

    /// 🔐 Auth
    GoRoute(path: '/auth/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/auth/register', builder: (_, __) => const RegisterPage()),

    /// 🎟 Events
    GoRoute(path: '/events', builder: (_, __) => const EventsListPage()),
    GoRoute(path: '/events/new', builder: (_, __) => const EventCreatePage()),
    GoRoute(
      path: '/events/:eventId',
      builder: (_, state) =>
          EventDetailPage(eventId: state.pathParameters['eventId']!),
    ),

    /// 👥 Sellers
    GoRoute(
      path: '/events/:eventId/sellers',
      builder: (_, state) =>
          SellersListPage(eventId: state.pathParameters['eventId']!),
    ),
    GoRoute(
      path: '/events/:eventId/sellers/new',
      builder: (_, state) =>
          SellerCreatePage(eventId: state.pathParameters['eventId']!),
    ),
    GoRoute(
      path: '/events/:eventId/sellers/:sellerId',
      builder: (_, state) => SellerDetailPage(
        eventId: state.pathParameters['eventId']!,
        sellerId: state.pathParameters['sellerId']!,
      ),
    ),
  ],
);
