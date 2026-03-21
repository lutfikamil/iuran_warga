import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';

String generateRandomPassword({int length = 10}) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  final random = Random.secure();

  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

Future<void> upsertUserLogin({
  required String wargaId,
  required String nama,
  required String rumah,
  required String noHpPenghuni,
  required String role,
  required String identifier,
  String? newRawPassword,
}) async {
  final usersRef = FirebaseFirestore.instance.collection('users');
  final batch = FirebaseFirestore.instance.batch();

  final byWarga = await usersRef
      .where('wargaId', isEqualTo: wargaId)
      .limit(1)
      .get();

  DocumentReference userDocRef;
  Map<String, dynamic> currentData = {};

  if (byWarga.docs.isNotEmpty) {
    userDocRef = byWarga.docs.first.reference;
    currentData = byWarga.docs.first.data();
  } else {
    final byIdentifier = await usersRef
        .where('identifier', isEqualTo: identifier)
        .limit(1)
        .get();

    if (byIdentifier.docs.isNotEmpty) {
      userDocRef = byIdentifier.docs.first.reference;
      currentData = byIdentifier.docs.first.data();
    } else {
      userDocRef = usersRef.doc();
    }
  }

  final effectivePassword = (newRawPassword != null && newRawPassword.isNotEmpty)
      ? newRawPassword
      : (currentData['password'] == null ? generateRandomPassword() : null);

  final passwordHash = effectivePassword != null
      ? AuthService().hashPassword(effectivePassword)
      : currentData['password'];

  batch.set(userDocRef, {
    'wargaId': wargaId,
    'nama': nama,
    'rumah': rumah,
    'noHpPenghuni': noHpPenghuni,
    'identifier': identifier,
    'role': role,
    'password': passwordHash,
    'isActive': true,
    'forceChangePassword': currentData['forceChangePassword'] ?? false,
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': currentData['createdAt'] ?? FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await batch.commit();
}
