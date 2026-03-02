import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tickets_owner_app/features/auth/presentation/profile_page.dart';
import 'package:tickets_owner_app/features/auth/presentation/verify_code_page.dart';
import 'package:tickets_owner_app/features/events/presentation/event_edit_page.dart';

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

    GoRoute(
      path: '/auth/verify',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return VerifyCodePage(email: data['email'], password: data['password']);
      },
    ),

    /// 🎟 Events
    GoRoute(path: '/events', builder: (_, __) => const EventsListPage()),
    GoRoute(path: '/events/new', builder: (_, __) => const EventCreatePage()),
    GoRoute(
      path: '/events/:eventId',
      builder: (_, state) =>
          EventDetailPage(eventId: state.pathParameters['eventId']!),
    ),
    GoRoute(
      path: '/events/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EventEditPage(eventId: id);
      },
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
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(
      path: '/events/:eventId/sellers/:sellerId',
      builder: (_, state) {
        final eventId = state.pathParameters['eventId']!;
        final sellerId = state.pathParameters['sellerId']!;

        return FutureBuilder(
          future: Supabase.instance.client
              .from('events')
              .select('status')
              .eq('id', eventId)
              .single(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final status = snapshot.data!['status'] ?? 'draft';

            return SellerDetailPage(
              eventId: eventId,
              sellerId: sellerId,
              eventStatus: status,
            );
          },
        );
      },
    ),
  ],
);
