import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class WalletSecurityService {
  static const _storage = FlutterSecureStorage();
  static const String _pinKey = 'wallet_pin_v1';

  final LocalAuthentication _localAuth = LocalAuthentication();

  static bool biometricPromptInProgress = false;

  Future<void> ensureDemoPinExists() async {
    final existingPin = await _storage.read(key: _pinKey);
    if (existingPin == null) {
      await _storage.write(key: _pinKey, value: '1234');
    }
  }

  Future<bool> verifyPin(String pin) async {
    await ensureDemoPinExists();
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == pin;
  }

  Future<bool> canUseBiometrics() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      return isSupported && canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics({required String reason}) async {
    try {
      if (!await canUseBiometrics()) return false;

      biometricPromptInProgress = true;
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
      );
      return authenticated;
    } finally {
      biometricPromptInProgress = false;
    }
  }
}
