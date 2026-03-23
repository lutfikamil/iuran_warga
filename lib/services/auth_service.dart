import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole {
  admin,
  ketua,
  bendahara,
  sekretaris,
  petugas,
  pengurusMusolah,
  warga,
  unauthenticated,
}

class LoginResult {
  final String role;
  final String identifier;
  final bool isAdmin;
  final String? userDocId;

  const LoginResult({
    required this.role,
    required this.identifier,
    required this.isAdmin,
    this.userDocId,
  });
}

class PasswordResetResult {
  final bool sentToWhatsapp;
  final String maskedPhone;
  final String temporaryPassword;

  const PasswordResetResult({
    required this.sentToWhatsapp,
    required this.maskedPhone,
    required this.temporaryPassword,
  });
}

class AdminResidentPasswordResetResult {
  final String wargaId;
  final String authUid;
  final String authEmail;
  final String password;
  final bool generated;

  const AdminResidentPasswordResetResult({
    required this.wargaId,
    required this.authUid,
    required this.authEmail,
    required this.password,
    required this.generated,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final AuthService _instance = AuthService._internal();
  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  UserRole _currentUserRole = UserRole.unauthenticated;
  UserRole get currentUserRole => _currentUserRole;

  void setCurrentUserRole(UserRole role) {
    _currentUserRole = role;
  }

  static String normalizeRole(String? role) {
    final normalizedRole = (role ?? '').trim().toLowerCase();
    if (normalizedRole.isEmpty) {
      return '';
    }

    final compactRole = normalizedRole
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .replaceAll('_', '');

    switch (compactRole) {
      case 'admin':
        return 'admin';
      case 'ketua':
        return 'ketua';
      case 'bendahara':
        return 'bendahara';
      case 'sekretaris':
        return 'sekretaris';
      case 'petugas':
        return 'petugas';
      case 'pengurusmusolah':
        return 'pengurus_musolah';
      case 'warga':
        return 'warga';
      default:
        return normalizedRole.replaceAll('-', '_').replaceAll(' ', '_');
    }
  }

  UserRole roleFromString(String? role) {
    switch (normalizeRole(role)) {
      case 'admin':
        return UserRole.admin;
      case 'ketua':
        return UserRole.ketua;
      case 'bendahara':
        return UserRole.bendahara;
      case 'sekretaris':
        return UserRole.sekretaris;
      case 'petugas':
        return UserRole.petugas;
      case 'pengurus_musolah':
        return UserRole.pengurusMusolah;
      case 'warga':
        return UserRole.warga;
      default:
        return UserRole.unauthenticated;
    }
  }

  void restoreRoleFromSession(String? role) {
    setCurrentUserRole(roleFromString(role));
  }

  Future<LoginResult> loginFlexible(String identifier, String password) async {
    final normalizedIdentifier = identifier.trim();

    if (normalizedIdentifier.contains('@')) {
      try {
        await _auth.signInWithEmailAndPassword(
          email: normalizedIdentifier,
          password: password,
        );
        setCurrentUserRole(UserRole.admin);

        return LoginResult(
          role: 'admin',
          identifier: normalizedIdentifier,
          isAdmin: true,
        );
      } on FirebaseAuthException catch (_) {
        // Lanjutkan pencarian akun warga/pengurus non-admin.
      }
    }

    final residentAccount = await _findResidentAccount(normalizedIdentifier);
    if (residentAccount == null) {
      throw Exception('User tidak ditemukan');
    }

    if (residentAccount.isActive == false) {
      throw Exception('Akun sudah tidak aktif');
    }

    await _signInResident(email: residentAccount.authEmail, password: password);

    final roleString = normalizeRole(residentAccount.role);
    final role = roleFromString(roleString);
    setCurrentUserRole(role);

    return LoginResult(
      role: roleString,
      identifier: residentAccount.wargaId,
      isAdmin: false,
      userDocId: residentAccount.userDocId,
    );
  }

  Future<void> _signInResident({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'invalid-login-credentials':
          throw Exception('Password salah');
        case 'user-not-found':
          throw Exception('Akun Firebase Auth tidak ditemukan');
        case 'too-many-requests':
          throw Exception('Terlalu banyak percobaan login. Coba lagi nanti.');
        default:
          throw Exception(e.message ?? 'Gagal login ke Firebase Auth');
      }
    }
  }

  Future<_ResidentAccountLookup?> _findResidentAccount(
    String identifier,
  ) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) return null;

    final usersRef = _db.collection('users');

    Future<_ResidentAccountLookup?> lookupByField(String field) async {
      final result = await usersRef
          .where(field, isEqualTo: normalized)
          .limit(1)
          .get();
      if (result.docs.isEmpty) return null;
      final doc = result.docs.first;
      return _ResidentAccountLookup.fromFirestore(doc.id, doc.data());
    }

    final userLookups = <Future<_ResidentAccountLookup?> Function()>[
      () => lookupByField('authEmail'),
      () => lookupByField('noHpPenghuni'),
      () => lookupByField('rumah'),
      () => lookupByField('wargaId'),
    ];

    for (final lookup in userLookups) {
      final result = await lookup();
      if (result != null) return result;
    }

    final wargaFields = normalized.contains('@')
        ? ['email']
        : ['noHpPenghuni', 'rumah'];

    for (final field in wargaFields) {
      final result = await _db
          .collection('warga')
          .where(field, isEqualTo: normalized)
          .limit(1)
          .get();
      if (result.docs.isEmpty) continue;

      final wargaDoc = result.docs.first;
      final userDoc = await usersRef
          .where('wargaId', isEqualTo: wargaDoc.id)
          .limit(1)
          .get();
      if (userDoc.docs.isEmpty) continue;

      return _ResidentAccountLookup.fromFirestore(
        userDoc.docs.first.id,
        userDoc.docs.first.data(),
      );
    }

    return null;
  }

  String maskPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return phone;

    final visibleEnd = digits.substring(digits.length - 4);
    return '••••$visibleEnd';
  }

  Future<PasswordResetResult> resetPasswordForResident(
    String identifier,
  ) async {
    final residentAccount = await _findResidentAccount(identifier.trim());
    if (residentAccount == null) {
      throw Exception('Akun tidak ditemukan.');
    }

    throw Exception(
      'Reset password otomatis via WhatsApp sudah dinonaktifkan karena akun warga sekarang memakai Firebase Auth penuh. Silakan hubungi pengurus untuk set ulang password dari panel/admin service.',
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required bool isAdmin,
    required String identifier,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      throw Exception('Sesi tidak valid. Silakan login ulang.');
    }

    final credential = EmailAuthProvider.credential(
      email: currentUser.email!,
      password: currentPassword,
    );

    await currentUser.reauthenticateWithCredential(credential);
    await currentUser.updatePassword(newPassword);

    if (!isAdmin) {
      await _db.collection('users').doc(currentUser.uid).set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<AdminResidentPasswordResetResult> adminResetResidentPassword({
    required String wargaId,
    String? newPassword,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminResetResidentPassword',
    );

    try {
      final response = await callable.call(<String, dynamic>{
        'wargaId': wargaId,
        if (newPassword != null && newPassword.trim().isNotEmpty)
          'newPassword': newPassword.trim(),
      });

      final data = Map<String, dynamic>.from(
        (response.data as Map<dynamic, dynamic>?) ?? const {},
      );

      return AdminResidentPasswordResetResult(
        wargaId: (data['wargaId'] ?? '').toString(),
        authUid: (data['authUid'] ?? '').toString(),
        authEmail: (data['authEmail'] ?? '').toString(),
        password: (data['password'] ?? '').toString(),
        generated: data['generated'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Reset password warga gagal.');
    }
  }

  bool hasAnyRole(List<UserRole> allowedRoles) {
    if (allowedRoles.isEmpty) return true;
    return allowedRoles.contains(_currentUserRole);
  }
}

class _ResidentAccountLookup {
  final String userDocId;
  final String wargaId;
  final String authEmail;
  final String role;
  final bool isActive;

  const _ResidentAccountLookup({
    required this.userDocId,
    required this.wargaId,
    required this.authEmail,
    required this.role,
    required this.isActive,
  });

  factory _ResidentAccountLookup.fromFirestore(
    String userDocId,
    Map<String, dynamic> data,
  ) {
    final authEmail = (data['authEmail'] ?? '').toString().trim();
    final wargaId = (data['wargaId'] ?? '').toString().trim();
    if (authEmail.isEmpty || wargaId.isEmpty) {
      throw Exception('Akun warga belum termigrasi penuh ke Firebase Auth.');
    }

    return _ResidentAccountLookup(
      userDocId: userDocId,
      wargaId: wargaId,
      authEmail: authEmail,
      role: (data['role'] ?? 'warga').toString(),
      isActive: data['isActive'] != false,
    );
  }
}
