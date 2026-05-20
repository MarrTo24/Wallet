import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoIdentity {
  final String did;
  final String publicKey;
  final bool createdNow;

  const CryptoIdentity({
    required this.did,
    required this.publicKey,
    required this.createdNow,
  });
}

class CryptoIdentityService {
  static const _storage = FlutterSecureStorage();
  static const _privateKeyKey = 'wallet_ed25519_private_key_v1';
  static const _publicKeyKey = 'wallet_ed25519_public_key_v1';

  final Ed25519 _algorithm = Ed25519();

  Future<CryptoIdentity> getOrCreateIdentity() async {
    final storedPrivateKey = await _storage.read(key: _privateKeyKey);
    final storedPublicKey = await _storage.read(key: _publicKeyKey);

    if (storedPrivateKey != null && storedPublicKey != null) {
      return CryptoIdentity(
        did: didKeyFromPublicKey(_decodeBase64Url(storedPublicKey)),
        publicKey: storedPublicKey,
        createdNow: false,
      );
    }

    final keyPair = await _algorithm.newKeyPair();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    final privateKeyEncoded = _encodeBase64Url(privateKeyBytes);
    final publicKeyEncoded = _encodeBase64Url(publicKey.bytes);

    await _storage.write(key: _privateKeyKey, value: privateKeyEncoded);
    await _storage.write(key: _publicKeyKey, value: publicKeyEncoded);

    return CryptoIdentity(
      did: didKeyFromPublicKey(publicKey.bytes),
      publicKey: publicKeyEncoded,
      createdNow: true,
    );
  }

  Future<String> signPayload(Map<String, dynamic> payload) async {
    final identity = await getOrCreateIdentity();
    final privateKeyEncoded = await _storage.read(key: _privateKeyKey);

    if (privateKeyEncoded == null) {
      throw StateError('No existe una llave privada para firmar.');
    }

    final keyPair = await _algorithm.newKeyPairFromSeed(
      _decodeBase64Url(privateKeyEncoded),
    );
    final canonicalPayload = canonicalJson(payload);
    final signature = await _algorithm.sign(
      utf8.encode(canonicalPayload),
      keyPair: keyPair,
    );

    final signingPublicKey = await keyPair.extractPublicKey();
    if (_encodeBase64Url(signingPublicKey.bytes) != identity.publicKey) {
      throw StateError('La llave publica no coincide con la llave privada.');
    }

    return _encodeBase64Url(signature.bytes);
  }

  Future<bool> verifyPayload({
    required Map<String, dynamic> payload,
    required String signature,
    required String publicKey,
  }) async {
    final signatureBytes = _decodeBase64Url(signature);
    final publicKeyBytes = _decodeBase64Url(publicKey);
    final canonicalPayload = canonicalJson(payload);

    return _algorithm.verify(
      utf8.encode(canonicalPayload),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(
          publicKeyBytes,
          type: KeyPairType.ed25519,
        ),
      ),
    );
  }

  static String canonicalJson(Object? value) {
    return jsonEncode(_canonicalize(value));
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sortedKeys = value.keys.map((key) => key.toString()).toList()..sort();
      return {
        for (final key in sortedKeys) key: _canonicalize(value[key]),
      };
    }

    if (value is List) {
      return value.map(_canonicalize).toList();
    }

    return value;
  }

  static String didKeyFromPublicKey(List<int> publicKeyBytes) {
    // did:key para Ed25519: multicodec varint 0xed01 + llave publica, codificado base58btc con prefijo z.
    final multicodecBytes = <int>[0xed, 0x01, ...publicKeyBytes];
    return 'did:key:z${_base58Encode(multicodecBytes)}';
  }

  static String _encodeBase64Url(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static List<int> _decodeBase64Url(String value) {
    final normalized = value.padRight(value.length + ((4 - value.length % 4) % 4), '=');
    return base64Url.decode(normalized);
  }

  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String _base58Encode(List<int> bytes) {
    if (bytes.isEmpty) return '';

    var digits = <int>[0];
    for (final byte in bytes) {
      var carry = byte;
      for (var i = 0; i < digits.length; i++) {
        carry += digits[i] << 8;
        digits[i] = carry % 58;
        carry ~/= 58;
      }
      while (carry > 0) {
        digits.add(carry % 58);
        carry ~/= 58;
      }
    }

    var leadingZeros = 0;
    for (final byte in bytes) {
      if (byte == 0) {
        leadingZeros++;
      } else {
        break;
      }
    }

    final buffer = StringBuffer();
    for (var i = 0; i < leadingZeros; i++) {
      buffer.write(_base58Alphabet[0]);
    }
    for (final digit in digits.reversed) {
      buffer.write(_base58Alphabet[digit]);
    }
    return buffer.toString();
  }
}
