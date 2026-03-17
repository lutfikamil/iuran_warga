import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';

Future<void> upsertUserLogin({
  required String wargaId,
  required String nama,
  required String rumah,
  required String hp,
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

  final passwordHash = (newRawPassword != null && newRawPassword.isNotEmpty)
      ? AuthService().hashPassword(newRawPassword)
      : (currentData['password'] ?? AuthService().hashPassword('123456'));

  batch.set(userDocRef, {
    'wargaId': wargaId,
    'nama': nama,
    'rumah': rumah,
    'hp': hp,
    'identifier': identifier,
    'role': role,
    'password': passwordHash,
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': currentData['createdAt'] ?? FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await batch.commit();
}
