import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_client.dart';

/// Authentication state
enum AuthStatus { unknown, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api = ApiClient();

  AuthNotifier() : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final hasToken = await _api.hasToken();
    if (hasToken) {
      try {
        final response = await _api.dio.get('/users/me');
        if (response.statusCode == 200) {
          final user = User.fromJson(response.data['data']);
          state = AuthState(status: AuthStatus.authenticated, user: user);
          return;
        }
      } catch (_) {
        await _api.clearTokens();
      }
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> sendOtp({String? phone, String? email, required String type}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _api.dio.post('/auth/send-otp', data: {
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        'type': type,
      });
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Failed to send OTP. Please try again.',
      );
    }
  }

  Future<bool> verifyOtp({
    String? phone,
    String? email,
    required String otp,
    required String deviceName,
    required String deviceType,
    required String deviceId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.dio.post('/auth/verify-otp', data: {
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        'otp': otp,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'deviceId': deviceId,
      });

      if (response.statusCode == 200) {
        final data = response.data['data'];
        await _api.setTokens(
          data['tokens']['accessToken'],
          data['tokens']['refreshToken'],
        );
        final user = User.fromJson(data['user']);
        state = AuthState(status: AuthStatus.authenticated, user: user);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Invalid OTP. Please try again.',
      );
      return false;
    }
  }

  Future<bool> googleAuth(String idToken, {
    required String deviceName,
    required String deviceType,
    required String deviceId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.dio.post('/auth/google', data: {
        'idToken': idToken,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'deviceId': deviceId,
      });

      if (response.statusCode == 200) {
        final data = response.data['data'];
        await _api.setTokens(
          data['tokens']['accessToken'],
          data['tokens']['refreshToken'],
        );
        final user = User.fromJson(data['user']);
        state = AuthState(status: AuthStatus.authenticated, user: user);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Google sign-in failed.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/auth/logout');
    } catch (_) {}
    await _api.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// For demo mode: skip auth
  void setDemoUser() {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: User(
        id: 'demo-user',
        name: 'Demo User',
        email: 'demo@vanix.com',
        isVerified: true,
        profiles: const [
          Profile(id: 'p1', name: 'Demo User'),
          Profile(id: 'p2', name: 'Kids', isKids: true),
        ],
      ),
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
