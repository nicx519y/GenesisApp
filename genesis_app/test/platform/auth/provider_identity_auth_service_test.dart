import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/apple_sign_in_service.dart';
import 'package:genesis_flutter_android/platform/auth/auth_cancelled_exception.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/auth/provider_identity_auth_service.dart';
import 'package:genesis_flutter_android/platform/google_sign_in_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  test('Google sign-in maps the provider token and profile directly', () async {
    final service = ProviderIdentityAuthService(
      sessionStore: MemoryUserSessionStore(),
      googleSignIn: () async => const GoogleIdentitySession(
        googleIdToken: 'google-token',
        displayName: 'Google User',
        photoUrl: 'https://example.com/google.png',
      ),
    );

    final session = await service.signIn(IdentityProvider.google);

    expect(session.provider, IdentityProvider.google);
    expect(session.providerIdToken, 'google-token');
    expect(session.displayName, 'Google User');
    expect(session.photoUrl, 'https://example.com/google.png');
  });

  test('Apple sign-in uses cached Genesis name when Apple omits it', () async {
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUserInfo({
      'uid': 'u_apple',
      'login_provider': 'apple',
      'name': 'Cached Apple User',
    });
    final service = ProviderIdentityAuthService(
      sessionStore: sessionStore,
      appleSignIn: () async => const AppleIdentitySession(
        appleIdentityToken: 'apple-token',
        displayName: '',
        photoUrl: '',
      ),
    );

    final session = await service.signIn(IdentityProvider.apple);

    expect(session.provider, IdentityProvider.apple);
    expect(session.providerIdToken, 'apple-token');
    expect(session.displayName, 'Cached Apple User');
    expect(session.photoUrl, isEmpty);
  });

  test(
    'silent refresh only attempts Google for a cached Google login',
    () async {
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUserInfo({
        'uid': 'u_google',
        'login_provider': 'google',
      });
      var refreshCount = 0;
      final service = ProviderIdentityAuthService(
        sessionStore: sessionStore,
        googleRefresh: () async {
          refreshCount += 1;
          return const GoogleIdentitySession(
            googleIdToken: 'refreshed-google-token',
            displayName: 'Google User',
            photoUrl: '',
          );
        },
      );

      final session = await service.refreshSilently();

      expect(refreshCount, 1);
      expect(session?.provider, IdentityProvider.google);
      expect(session?.providerIdToken, 'refreshed-google-token');
    },
  );

  for (final provider in ['apple', '']) {
    test(
      'silent refresh skips provider ${provider.isEmpty ? 'unknown' : provider}',
      () async {
        final sessionStore = MemoryUserSessionStore();
        await sessionStore.saveUserInfo({
          'uid': 'u_1',
          if (provider.isNotEmpty) 'login_provider': provider,
        });
        var refreshCount = 0;
        final service = ProviderIdentityAuthService(
          sessionStore: sessionStore,
          googleRefresh: () async {
            refreshCount += 1;
            return null;
          },
        );

        expect(await service.refreshSilently(), isNull);
        expect(refreshCount, 0);
      },
    );
  }

  test('provider cancellation remains an AuthCancelledException', () async {
    final googleService = ProviderIdentityAuthService(
      sessionStore: MemoryUserSessionStore(),
      googleSignIn: () async => throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'cancelled',
      ),
    );
    final appleService = ProviderIdentityAuthService(
      sessionStore: MemoryUserSessionStore(),
      appleSignIn: () async =>
          throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'cancelled',
          ),
    );

    await expectLater(
      googleService.signIn(IdentityProvider.google),
      throwsA(isA<AuthCancelledException>()),
    );
    await expectLater(
      appleService.signIn(IdentityProvider.apple),
      throwsA(isA<AuthCancelledException>()),
    );
  });

  test('identity sign-out only invokes the Google provider sign-out', () async {
    var signOutCount = 0;
    final service = ProviderIdentityAuthService(
      sessionStore: MemoryUserSessionStore(),
      googleSignOut: () async {
        signOutCount += 1;
      },
    );

    await service.signOutIdentity();

    expect(signOutCount, 1);
  });
}
