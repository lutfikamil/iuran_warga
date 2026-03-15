import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

enum UserRole {
  admin,
  ketua,
  bendahara,
  sekertaris,
  petugas,
  warga,
  unauthenticated,
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() {
    return _instance;
  }
  AuthService._internal();
  UserRole _currentUserRole = UserRole.unauthenticated; // Default
  UserRole get currentUserRole => _currentUserRole;

  void setCurrentUserRole(UserRole role) {
    _currentUserRole = role;
  }

  String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<String> loginFlexible(String identifier, String password) async {
    // cek apakah email admin
    if (identifier.contains("@")) {
      try {
        await _auth.signInWithEmailAndPassword(
          email: identifier,
          password: password,
        );
        setCurrentUserRole(UserRole.admin);
        return "admin";
      } catch (e) {
        throw Exception("Login gagal: $e");
      }
    }

    // login warga
    final result = await _db
        .collection("users")
        .where("identifier", isEqualTo: identifier)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      throw Exception("User tidak ditemukan");
    }

    final data = result.docs.first.data();

    if (data["password"] == hashPassword(password)) {
      // Konversi string peran dari database ke enum
      UserRole role = UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data["role"]}',
        orElse: () => UserRole.unauthenticated,
      );
      setCurrentUserRole(role); // Set peran setelah login
      return data["role"];
    }
    throw Exception("Password salah");
  }

  bool hasAnyRole(List<UserRole> allowedRoles) {
    if (allowedRoles.isEmpty) return true;
    return allowedRoles.contains(_currentUserRole);
  }
}
