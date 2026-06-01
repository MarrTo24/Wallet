import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum PinStatus { success, wrongPin, locked }

class PinVerificationResult {
  final PinStatus status;
  final int? lockSeconds;
  final int? attemptsLeft;

  const PinVerificationResult({
    required this.status,
    this.lockSeconds,
    this.attemptsLeft,
  });
}

class WalletSecurityService {
  static const _storage = FlutterSecureStorage();
  static const String _pinKey = 'wallet_pin_v2';
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockUntilKey = 'pin_lock_until_ms';

  // After N wrong attempts, lock for the corresponding number of seconds.
  static const List<int> _lockThresholds = [3, 5, 7, 10];
  static const List<int> _lockDurations = [30, 120, 600, 3600];

  final LocalAuthentication _localAuth = LocalAuthentication();
  static bool biometricPromptInProgress = false;

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockUntilKey);
  }

  Future<PinVerificationResult> verifyPin(String pin) async {
    final lockResult = await _getLockResult();
    if (lockResult != null) return lockResult;

    final storedPin = await _storage.read(key: _pinKey);
    if (storedPin == pin) {
      await _resetAttempts();
      return const PinVerificationResult(status: PinStatus.success);
    }

    return _recordFailedAttempt();
  }

  Future<PinVerificationResult?> _getLockResult() async {
    final lockUntilStr = await _storage.read(key: _lockUntilKey);
    if (lockUntilStr == null) return null;
    final lockUntil = int.tryParse(lockUntilStr) ?? 0;
    final remaining = lockUntil - DateTime.now().millisecondsSinceEpoch;
    if (remaining > 0) {
      return PinVerificationResult(
        status: PinStatus.locked,
        lockSeconds: (remaining / 1000).ceil(),
      );
    }
    return null;
  }

  Future<PinVerificationResult> _recordFailedAttempt() async {
    final attemptsStr = await _storage.read(key: _failedAttemptsKey);
    final attempts = (int.tryParse(attemptsStr ?? '0') ?? 0) + 1;
    await _storage.write(key: _failedAttemptsKey, value: attempts.toString());

    int lockDuration = 0;
    for (int i = _lockThresholds.length - 1; i >= 0; i--) {
      if (attempts >= _lockThresholds[i]) {
        lockDuration = _lockDurations[i];
        break;
      }
    }

    if (lockDuration > 0) {
      final lockUntil =
          DateTime.now().millisecondsSinceEpoch + lockDuration * 1000;
      await _storage.write(key: _lockUntilKey, value: lockUntil.toString());
      return PinVerificationResult(
        status: PinStatus.locked,
        lockSeconds: lockDuration,
      );
    }

    int? attemptsLeft;
    for (final threshold in _lockThresholds) {
      if (attempts < threshold) {
        attemptsLeft = threshold - attempts;
        break;
      }
    }

    return PinVerificationResult(
      status: PinStatus.wrongPin,
      attemptsLeft: attemptsLeft,
    );
  }

  Future<void> _resetAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockUntilKey);
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
      return await _localAuth.authenticate(localizedReason: reason);
    } finally {
      biometricPromptInProgress = false;
    }
  }
}
