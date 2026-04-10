import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccessToken  = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId       = 'user_id';
  static const _keyTenantId     = 'tenant_id';
  static const _keyUserName     = 'user_name';
  static const _keyUserRole     = 'user_role';
  static const _keyUserEmail    = 'user_email';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken,  value: accessToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
    ]);
  }

  Future<void> saveUser({
    required String userId,
    required String tenantId,
    required String name,
    required String role,
    required String email,
  }) async {
    await Future.wait([
      _storage.write(key: _keyUserId,    value: userId),
      _storage.write(key: _keyTenantId,  value: tenantId),
      _storage.write(key: _keyUserName,  value: name),
      _storage.write(key: _keyUserRole,  value: role),
      _storage.write(key: _keyUserEmail, value: email),
    ]);
  }

  Future<String?> getAccessToken()  => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  Future<String?> getUserId()       => _storage.read(key: _keyUserId);
  Future<String?> getTenantId()     => _storage.read(key: _keyTenantId);
  Future<String?> getUserName()     => _storage.read(key: _keyUserName);
  Future<String?> getUserRole()     => _storage.read(key: _keyUserRole);
  Future<String?> getUserEmail()    => _storage.read(key: _keyUserEmail);

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() => _storage.deleteAll();
}
