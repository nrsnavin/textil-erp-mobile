import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthState {
  final bool   isLoggedIn;
  final String userId;
  final String tenantId;
  final String name;
  final String role;
  final String email;

  const AuthState({
    required this.isLoggedIn,
    this.userId   = '',
    this.tenantId = '',
    this.name     = '',
    this.role     = '',
    this.email    = '',
  });

  static const guest = AuthState(isLoggedIn: false);
}

// ── Auth provider ─────────────────────────────────────────────────────────────

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final storage = ref.read(secureStorageProvider);
    final loggedIn = await storage.isLoggedIn();
    if (!loggedIn) return AuthState.guest;

    return AuthState(
      isLoggedIn: true,
      userId:     await storage.getUserId()    ?? '',
      tenantId:   await storage.getTenantId()  ?? '',
      name:       await storage.getUserName()  ?? '',
      role:       await storage.getUserRole()  ?? '',
      email:      await storage.getUserEmail() ?? '',
    );
  }

  Future<LoginResult> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/v1/auth/login', data: {
        'email':    email,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;

      if (data['mfaRequired'] == true) {
        state = AsyncData(AuthState.guest);
        return LoginResult.mfaRequired(mfaToken: data['mfaToken'] ?? '');
      }

      await _persistSession(data);
      return LoginResult.success();
    } catch (e, s) {
      state = AsyncError(e, s);
      return LoginResult.error(apiError(e));
    }
  }

  Future<LoginResult> verifyMfa(String mfaToken, String otp) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/api/v1/auth/mfa/verify', data: {
        'mfaToken': mfaToken,
        'otp':      otp,
      });
      await _persistSession(res.data as Map<String, dynamic>);
      return LoginResult.success();
    } catch (e, s) {
      state = AsyncError(e, s);
      return LoginResult.error(apiError(e));
    }
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.clearAll();
    state = const AsyncData(AuthState.guest);
  }

  Future<void> _persistSession(Map<String, dynamic> data) async {
    final storage = ref.read(secureStorageProvider);
    await storage.saveTokens(
      accessToken:  data['accessToken']  ?? '',
      refreshToken: data['refreshToken'] ?? '',
    );
    final user = data['user'] as Map<String, dynamic>? ?? {};
    await storage.saveUser(
      userId:   user['id']       ?? '',
      tenantId: user['tenantId'] ?? '',
      name:     user['name']     ?? '',
      role:     user['role']     ?? '',
      email:    user['email']    ?? '',
    );
    state = AsyncData(AuthState(
      isLoggedIn: true,
      userId:     user['id']       ?? '',
      tenantId:   user['tenantId'] ?? '',
      name:       user['name']     ?? '',
      role:       user['role']     ?? '',
      email:      user['email']    ?? '',
    ));
  }
}

class LoginResult {
  final bool    success;
  final bool    mfaRequired;
  final String? mfaToken;
  final String? error;

  LoginResult._({required this.success, this.mfaRequired = false, this.mfaToken, this.error});
  factory LoginResult.success()  => LoginResult._(success: true);
  factory LoginResult.mfaRequired({required String mfaToken}) =>
      LoginResult._(success: false, mfaRequired: true, mfaToken: mfaToken);
  factory LoginResult.error(String msg) => LoginResult._(success: false, error: msg);
}
