import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sarge_depo_app/core/providers/auth_providers.dart';
import 'package:sarge_depo_app/core/routing/app_router.dart';

/// Regression test for the "bottom navigation bar disappears" bug.
///
/// ROOT CAUSE: `AsyncValue.value` RETHROWS when a provider is in an *error*
/// state (riverpod's `AsyncError.value` -> `throwErrorWithCombinedStackTrace`).
/// The router's `redirect` callback and the profile provider both read the auth
/// provider, so an auth error (token refresh / offline / permission-denied)
/// used to throw while the shell was being built — which removed the ENTIRE
/// shell, including the bottom navigation bar.
///
/// These tests fail loudly if anyone reintroduces `.value` on an AsyncValue.
void main() {
  /// Waits until [provider] has settled into an AsyncError.
  Future<void> waitForError<T>(
    ProviderContainer container,
    ProviderListenable<AsyncValue<T>> provider,
  ) async {
    for (var i = 0; i < 50; i++) {
      if (container.read(provider).hasError) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('provider never reached an error state');
  }

  group('AsyncValue error-state safety (bottom nav regression)', () {
    test('approval providers survive an errored authStateProvider', () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<Never>.error(Exception('auth boom')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await waitForError(container, authStateProvider);

      // Must not throw: the providers degrade to "not approved".
      // (v4.4.0 replaced the old guest-session providers with the registration
      // approval providers; the same `.valueOrNull` rule still applies.)
      expect(() => container.read(isApprovedProvider), returnsNormally);
      expect(container.read(isApprovedProvider), isFalse);
      expect(() => container.read(isPendingApprovalProvider), returnsNormally);
      expect(container.read(isPendingApprovalProvider), isFalse);
    });

    test('currentAppUserProvider / isAdminProvider survive auth errors',
        () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<Never>.error(Exception('auth boom')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await waitForError(container, authStateProvider);

      // `.value` here would rethrow and take the shell down with it.
      expect(() => container.read(currentAppUserProvider), returnsNormally);
      expect(container.read(currentAppUserProvider).valueOrNull, isNull);
      expect(container.read(isAdminProvider), isFalse);
    });

    test('AsyncValue.value rethrows but valueOrNull does not (documented trap)',
        () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<Never>.error(Exception('auth boom')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await waitForError(container, authStateProvider);

      final async = container.read(authStateProvider);
      expect(async.hasError, isTrue);
      expect(async.isLoading, isFalse);
      // Documents WHY we must never use `.value` on a provider that the shell
      // watches: this is the exact throw that killed the bottom navigation bar.
      expect(() => async.value, throwsA(isA<Exception>()));
      expect(async.valueOrNull, isNull);
    });

    test('AppRouter builds and stays error-free while auth is in error state',
        () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<Never>.error(Exception('auth boom')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await waitForError(container, authStateProvider);

      // Building the router must not throw. The redirect closure runs on every
      // navigation; a `.value` read there throws inside go_router, which then
      // renders its error page INSTEAD of the ShellRoute -> the bottom
      // navigation bar disappears. `.valueOrNull` keeps the shell alive.
      final router = container.read(appRouterProvider);
      expect(router.configuration.redirect, isNotNull);

      // The ShellRoute (which owns the bottom nav bar) must still be declared.
      final hasShell = router.configuration.routes.any(
        (r) => r is ShellRoute,
      );
      expect(hasShell, isTrue,
          reason: 'ShellRoute (bottom nav bar owner) must exist');
    });
  });
}
