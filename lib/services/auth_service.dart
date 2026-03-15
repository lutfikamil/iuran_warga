import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

        return "admin";
      } catch (e) {}
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
      return data["role"];
    }

    throw Exception("Password salah");
  }
}
