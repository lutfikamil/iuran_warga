import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    // Pastikan userDoc dan datanya tidak null sebelum diakses
    if (userDoc == null || userDoc.data() == null) {
      throw Exception('User tidak ditemukan');
    }

    final data = userDoc.data()!; // Gunakan ! karena sudah dipastikan tidak null

    if (data['password'] != hashPassword(password)) {
      throw Exception('Password salah');
    }

    final roleString = (data['role'] ?? 'warga').toString().toLowerCase();
    final role = UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == roleString.replaceAll('_', ''),
      orElse: () => UserRole.unauthenticated,
    );

    setCurrentUserRole(role);
    return LoginResult(
      role: roleString,
      identifier: normalizedIdentifier,
      isAdmin: false,
      userDocId: userDoc.id,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByIdentifier(
      String identifier,) async {
    final fields = ['identifier', 'hp', 'rumah', 'email'];

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

    // Pastikan userDoc dan datanya tidak null sebelum diakses
    if (userDoc == null || userDoc.data() == null) {
      throw Exception('Akun user tidak ditemukan');
    }

    final userData = userDoc.data()!; // Gunakan ! karena sudah dipastikan tidak null
    if (userData['password'] != hashPassword(currentPassword)) {
      throw Exception('Password saat ini salah');
    }

    await _db.collection('users').doc(userDoc.id).update({
      'password': hashPassword(newPassword),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  bool hasAnyRole(List<UserRole> allowedRoles) {
    if (allowedRoles.isEmpty) return true;
    return allowedRoles.contains(_currentUserRole);
  }
}