import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();

  static const String _sessionKey = 'is_logged_in';
  static const String _nameKey = 'user_name';
  static const String _emailKey = 'user_email';
  static const String _aliasKey = 'wallet_alias';
  static const String _passwordKey = 'user_password';

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
    await _storage.write(key: _passwordKey, value: password);
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

  Future<String> getUserPassword() async {
    return await _storage.read(key: _passwordKey) ?? '';
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
    await _storage.write(key: 'key_file_name', value: keyFileName);

    await _storage.write(key: 'key_content_base64', value: keyContentBase64);
  }

  Future<void> saveCerDocumentFromQr({
    required String cerFileName,
    required String cerContentBase64,
  }) async {
    await _storage.write(key: 'cer_file_name', value: cerFileName);

    await _storage.write(key: 'cer_content_base64', value: cerContentBase64);
  }
}
