import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../models/credential.dart';

class CredentialNotifier extends StateNotifier<List<Credential>> {
  CredentialNotifier() : super(_initialCredentials) {
    _loadCredentials();
  }

  static const _storage = FlutterSecureStorage();
  static const _credentialsKey = 'saved_credentials';

  static final List<Credential> _initialCredentials = [];

  Future<void> _loadCredentials() async {
    try {
      final String? data = await _storage.read(key: _credentialsKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        final List<Credential> savedCredentials = decoded
            .map((item) => Credential.fromJson(item as Map<String, dynamic>))
            .toList();

        if (savedCredentials.isNotEmpty) {
          state = savedCredentials;
        }
      }
    } catch (e) {
      debugPrint('Error loading credentials: $e');
    }
  }

  Future<void> _saveCredentials(List<Credential> credentials) async {
    try {
      final String encoded = jsonEncode(
        credentials.map((c) => c.toJson()).toList(),
      );
      await _storage.write(key: _credentialsKey, value: encoded);
    } catch (e) {
      debugPrint('Error saving credentials: $e');
    }
  }

  void addCredential(Credential credential) {
    state = [...state, credential];
    _saveCredentials(state);
  }

  Future<void> replaceCredentials(List<Credential> credentials) async {
    state = credentials;
    await _saveCredentials(state);
  }
}

final credentialsProvider =
    StateNotifierProvider<CredentialNotifier, List<Credential>>((ref) {
      return CredentialNotifier();
    });
