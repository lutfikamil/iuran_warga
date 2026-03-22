import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'users_service.dart';
import 'whatsapp_service.dart';

enum UserRole {
  admin,
  ketua,
  bendahara,
  sekertaris,
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
      case 'sekertaris':
        return 'sekertaris';
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
      case 'sekertaris':
        return UserRole.sekertaris;
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

  String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
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
        // Lanjutkan fallback ke users collection jika bukan akun admin Firebase
        // atau jika terjadi error autentikasi email/password.
      }
    }

    final userDoc = await _findUserByIdentifier(normalizedIdentifier);

    if (userDoc == null || userDoc.data() == null) {
      throw Exception('User tidak ditemukan');
    }

    final data = userDoc.data()!;

    if (data['password'] != hashPassword(password)) {
      throw Exception('Password salah');
    }

    if (data['isActive'] == false) {
      throw Exception('Akun sudah tidak aktif');
    }

    final roleString = normalizeRole((data['role'] ?? 'warga').toString());
    final role = roleFromString(roleString);

    setCurrentUserRole(role);
    return LoginResult(
      role: roleString,
      identifier: normalizedIdentifier,
      isAdmin: false,
      userDocId: userDoc.id,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByIdentifier(
    String identifier,
  ) async {
    final fields = ['identifier', 'noHpPenghuni', 'rumah', 'email'];

    for (final field in fields) {
      final result = await _db
          .collection('users')
          .where(field, isEqualTo: identifier)
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        return result.docs.first;
      }
    }

    return null;
  }

  String maskPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return phone;

    final visibleEnd = digits.substring(digits.length - 4);
    return '••••$visibleEnd';
  }

  Future<PasswordResetResult> resetPasswordForResident(String identifier) async {
    final normalizedIdentifier = identifier.trim();
    if (normalizedIdentifier.isEmpty) {
      throw Exception('Identifier wajib diisi.');
    }

    final userDoc = await _findUserByIdentifier(normalizedIdentifier);
    if (userDoc == null || userDoc.data() == null) {
      throw Exception('Akun tidak ditemukan.');
    }

    final userData = userDoc.data()!;
    if (userData['isActive'] == false) {
      throw Exception('Akun sudah tidak aktif.');
    }

    final phone = (userData['noHpPenghuni'] ?? '').toString().trim();
    if (phone.isEmpty) {
      throw Exception(
        'Nomor WhatsApp belum terdaftar. Silakan hubungi pengurus untuk reset manual.',
      );
    }

    final temporaryPassword = generateRandomPassword(length: 10);
    await _db.collection('users').doc(userDoc.id).update({
      'password': hashPassword(temporaryPassword),
      'forceChangePassword': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final nama = (userData['nama'] ?? 'Warga').toString();
    final rumah = (userData['rumah'] ?? '-').toString();

    try {
      await WhatsappService.sendMessage(
        phone: phone,
        message: '''Halo Bapak/Ibu $nama

Kami menerima permintaan reset password untuk akun rumah $rumah.

Password sementara Anda:
$temporaryPassword

Silakan login menggunakan password sementara ini lalu segera ganti password di menu profil.
Jika Anda tidak merasa meminta reset password, segera hubungi pengurus.

Terima kasih.
Pengurus Perumahan Mulia Land Patria.''',
      );
      return PasswordResetResult(
        sentToWhatsapp: true,
        maskedPhone: maskPhoneNumber(phone),
        temporaryPassword: temporaryPassword,
      );
    } catch (_) {
      return PasswordResetResult(
        sentToWhatsapp: false,
        maskedPhone: maskPhoneNumber(phone),
        temporaryPassword: temporaryPassword,
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required bool isAdmin,
    required String identifier,
  }) async {
    if (isAdmin) {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('Sesi admin tidak valid. Silakan login ulang.');
      }

      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.updatePassword(newPassword);
      return;
    }

    final userDoc = await _findUserByIdentifier(identifier);

    if (userDoc == null || userDoc.data() == null) {
      throw Exception('Akun user tidak ditemukan');
    }

    final userData = userDoc.data()!;
    if (userData['password'] != hashPassword(currentPassword)) {
      throw Exception('Password saat ini salah');
    }

    await _db.collection('users').doc(userDoc.id).update({
      'password': hashPassword(newPassword),
      'forceChangePassword': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  bool hasAnyRole(List<UserRole> allowedRoles) {
    if (allowedRoles.isEmpty) return true;
    return allowedRoles.contains(_currentUserRole);
  }
}
