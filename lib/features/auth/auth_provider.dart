import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_classification/data/local/auth_preferences.dart';
import 'package:waste_classification/data/local/user_repository.dart';
import 'package:waste_classification/data/models/user_model.dart';

// ─────────────────────────────────────────────
// Auth State
// ─────────────────────────────────────────────

enum AuthStatus { loading, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.unauthenticated([String? error])
      : this(status: AuthStatus.unauthenticated, error: error);
  const AuthState.authenticated(UserModel user)
      : this(status: AuthStatus.authenticated, user: user);

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// ─────────────────────────────────────────────
// Auth Notifier
// ─────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthState.loading();
  }

  Future<void> _init() async {
    try {
      final session = await authPreferences.getSession();
      if (session.userId != null) {
        final user = await userRepository.getUserById(session.userId!);
        if (user != null) {
          state = AuthState.authenticated(user);
          return;
        }
      }
    } catch (_) {}
    state = const AuthState.unauthenticated();
  }

  /// Register a new account.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final user = await userRepository.register(
        name: name,
        email: email,
        password: password,
      );
      await authPreferences.saveSession(
        userId: user.id!,
        name: user.name,
        email: user.email,
        initials: user.initials,
      );
      state = AuthState.authenticated(user);
    } on Exception catch (e) {
      state = AuthState.unauthenticated(_mapError(e));
    }
  }

  /// Login with email & password.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final user = await userRepository.login(email: email, password: password);
      await authPreferences.saveSession(
        userId: user.id!,
        name: user.name,
        email: user.email,
        initials: user.initials,
      );
      state = AuthState.authenticated(user);
    } on Exception catch (e) {
      state = AuthState.unauthenticated(_mapError(e));
    }
  }

  /// Update profile (name, optional new password).
  Future<String?> updateProfile({
    required String name,
    String? currentPassword,
    String? newPassword,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return 'not_logged_in';
    try {
      final updated = await userRepository.updateProfile(
        userId: currentUser.id!,
        name: name,
        currentPassword: currentPassword,
        newPassword: newPassword?.isEmpty == true ? null : newPassword,
        avatarInitials: UserModel.computeInitials(name),
      );
      await authPreferences.updateSession(
        name: updated.name,
        email: updated.email,
        initials: updated.initials,
      );
      state = AuthState.authenticated(updated);
      return null; // success
    } on Exception catch (e) {
      return _mapError(e);
    }
  }

  /// Change password specifically.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return 'not_logged_in';
    try {
      final updated = await userRepository.updateProfile(
        userId: currentUser.id!,
        name: currentUser.name,
        currentPassword: currentPassword,
        newPassword: newPassword,
        avatarInitials: currentUser.avatarInitials,
      );
      state = AuthState.authenticated(updated);
      return null; // success
    } on Exception catch (e) {
      return _mapError(e);
    }
  }

  /// Sign out.
  Future<void> logout() async {
    await authPreferences.clearSession();
    state = const AuthState.unauthenticated();
  }

  String _mapError(Exception e) {
    final msg = e.toString();
    if (msg.contains('email_already_exists')) return 'This email is already registered.';
    if (msg.contains('user_not_found')) return 'No account found with this email.';
    if (msg.contains('invalid_current_password')) return 'Current password is incorrect.';
    if (msg.contains('invalid_password')) return 'Incorrect password.';
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
