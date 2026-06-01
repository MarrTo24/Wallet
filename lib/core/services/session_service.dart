import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();

  static const String _sessionKey = 'is_logged_in';
  static const String _nameKey = 'user_name';
  static const String _emailKey = 'user_email';
  static const String _aliasKey = 'wallet_alias';
  static const String _passwordHashKey = 'user_password_hash';

  static const String _cerFileNameKey = 'cer_file_name';
  static const String _keyFileNameKey = 'key_file_name';
  static const String _cerContentKey = 'cer_content_base64';
  static const String _keyContentKey = 'key_content_base64';
  static const String _identityVerifiedKey = 'identity_verified';

  Future<void> saveSession({
    String name = 'Usuario',
    String email = '',
    String alias = '',
    String password = '',
  }) async {
    await _storage.write(key: _sessionKey, value: 'true');
    await _storage.write(key: _nameKey, value: name);
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _aliasKey, value: alias);
    if (password.isNotEmpty) {
      final hash = await _hashPassword(password);
      await _storage.write(key: _passwordHashKey, value: hash);
    }
    // Remove any legacy plaintext password key left from previous versions
    await _storage.delete(key: 'user_password');
  }

  Future<bool> verifyPassword(String password) async {
    final stored = await _storage.read(key: _passwordHashKey);
    if (stored == null || stored.isEmpty) return false;
    return _checkPassword(password, stored);
  }

  static Future<String> _hashPassword(String password) async {
    final salt = _generateSalt();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final keyBytes = await secretKey.extractBytes();
    return '${base64Encode(salt)}:${base64Encode(keyBytes)}';
  }

  static Future<bool> _checkPassword(String password, String stored) async {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final salt = base64Decode(parts[0]);
    final expectedHash = parts[1];
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final keyBytes = await secretKey.extractBytes();
    return base64Encode(keyBytes) == expectedHash;
  }

  static List<int> _generateSalt([int length = 16]) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(256));
  }

  Future<bool> hasSession() async {
    final value = await _storage.read(key: _sessionKey);
    return value == 'true';
  }

  Future<String> getUserName() async {
    return await _storage.read(key: _nameKey) ?? 'Usuario';
  }

  Future<String> getUserEmail() async {
    return await _storage.read(key: _emailKey) ?? '';
  }

  Future<String> getWalletAlias() async {
    return await _storage.read(key: _aliasKey) ?? '';
  }

  Future<void> saveDocumentsFromQr({
    required String cerFileName,
    required String keyFileName,
    required String cerContentBase64,
    required String keyContentBase64,
  }) async {
    await _storage.write(key: _cerFileNameKey, value: cerFileName);
    await _storage.write(key: _keyFileNameKey, value: keyFileName);
    await _storage.write(key: _cerContentKey, value: cerContentBase64);
    await _storage.write(key: _keyContentKey, value: keyContentBase64);
    await _storage.write(key: _identityVerifiedKey, value: 'true');
  }

  Future<bool> isIdentityVerified() async {
    final value = await _storage.read(key: _identityVerifiedKey);
    return value == 'true';
  }

  Future<String> getCerFileName() async {
    return await _storage.read(key: _cerFileNameKey) ?? '';
  }

  Future<String> getKeyFileName() async {
    return await _storage.read(key: _keyFileNameKey) ?? '';
  }

  Future<String> getCerContentBase64() async {
    return await _storage.read(key: _cerContentKey) ?? '';
  }

  Future<String> getKeyContentBase64() async {
    return await _storage.read(key: _keyContentKey) ?? '';
  }

  Future<void> clearSession() async {
    await _storage.deleteAll();
  }

  Future<void> saveKeyDocumentFromQr({
    required String keyFileName,
    required String keyContentBase64,
  }) async {
    await _storage.write(key: _keyFileNameKey, value: keyFileName);
    await _storage.write(key: _keyContentKey, value: keyContentBase64);
  }

  Future<void> saveCerDocumentFromQr({
    required String cerFileName,
    required String cerContentBase64,
  }) async {
    await _storage.write(key: _cerFileNameKey, value: cerFileName);
    await _storage.write(key: _cerContentKey, value: cerContentBase64);
  }
}
