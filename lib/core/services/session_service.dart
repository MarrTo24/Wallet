import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();

  static const String _sessionKey = 'is_logged_in';
  static const String _nameKey = 'user_name';
  static const String _emailKey = 'user_email';

  Future<void> saveSession({String name = 'Usuario', String email = ''}) async {
    await _storage.write(key: _sessionKey, value: 'true');
    await _storage.write(key: _nameKey, value: name);
    await _storage.write(key: _emailKey, value: email);
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

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _emailKey);
  }
}