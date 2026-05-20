import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/wallet/wallet_home_screen.dart';
import '../features/wallet/qr_screen.dart';
import '../features/wallet/scan_qr_screen.dart';
import '../features/wallet/credential_detail_screen.dart';
import '../features/wallet/verification_result_screen.dart';
import '../features/auth/pin_screen.dart';
import '../features/wallet/issue_credential_screen.dart';
import '../models/credential.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/wallet',
      builder: (context, state) => const WalletHomeScreen(),
    ),
    GoRoute(
      path: '/qr',
      builder: (context, state) => QrScreen(
        initialCredential: state.extra is Credential
            ? state.extra as Credential
            : null,
      ),
    ),
    GoRoute(path: '/scan', builder: (context, state) => const ScanQrScreen()),
    GoRoute(
      path: '/credential',
      builder: (context, state) {
        final credential = state.extra as Credential;

        return CredentialDetailScreen(credential: credential);
      },
    ),
    GoRoute(
      path: '/verification-result',
      builder: (context, state) {
        final qrValue = state.extra as String;

        return VerificationResultScreen(qrValue: qrValue);
      },
    ),
    GoRoute(
      path: '/pin',
      builder: (context, state) => PinScreen(
        redirectTo: state.extra is String ? state.extra as String : '/wallet',
      ),
    ),
    GoRoute(
      path: '/issue-credential',
      builder: (context, state) => const IssueCredentialScreen(),
    ),
  ],
);
