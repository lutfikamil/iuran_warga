import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ResidentAccountProvisionResult {
  final String wargaId;
  final String authUid;
  final String authEmail;
  final String? rawPassword;
  final bool isNewAccount;

  const ResidentAccountProvisionResult({
    required this.wargaId,
    required this.authUid,
    required this.authEmail,
    required this.rawPassword,
    required this.isNewAccount,
  });
}

String generateRandomPassword({int length = 10}) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  final random = Random.secure();

  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

String buildResidentAuthEmail(String wargaId) => '$wargaId@mulialand.auth';

Future<ResidentAccountProvisionResult> upsertUserLogin({
  required String wargaId,
  required String nama,
  required String rumah,
  required String noHpPenghuni,
  required String role,
  String? newRawPassword,
}) async {
  final firestore = FirebaseFirestore.instance;
  final usersRef = firestore.collection('users');
  final authEmail = buildResidentAuthEmail(wargaId);

  final existingByWarga = await usersRef.where('wargaId', isEqualTo: wargaId).limit(1).get();
  final existingDoc = existingByWarga.docs.isNotEmpty
      ? existingByWarga.docs.first
      : await _findUserByAuthEmail(usersRef, authEmail);

  final effectivePassword = (newRawPassword != null && newRawPassword.isNotEmpty)
      ? newRawPassword
      : (existingDoc == null ? generateRandomPassword() : null);

  final account = await _ensureFirebaseAuthAccount(
    authEmail: authEmail,
    currentAuthUid: (existingDoc?.data()['authUid'] ?? '').toString(),
    newPassword: effectivePassword,
  );

  final userDocRef = usersRef.doc(account.uid);
  final currentData = existingDoc?.data() ?? <String, dynamic>{};

  await userDocRef.set({
    'wargaId': wargaId,
    'nama': nama,
    'rumah': rumah,
    'noHpPenghuni': noHpPenghuni,
    'role': role,
    'authUid': account.uid,
    'authEmail': authEmail,
    'isActive': true,
    'updatedAt': FieldValue.serverTimestamp(),
    'createdAt': currentData['createdAt'] ?? FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  if (existingDoc != null && existingDoc.id != account.uid) {
    await existingDoc.reference.delete();
  }

  return ResidentAccountProvisionResult(
    wargaId: wargaId,
    authUid: account.uid,
    authEmail: authEmail,
    rawPassword: account.passwordWasChanged ? effectivePassword : null,
    isNewAccount: account.isNewAccount,
  );
}

Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserByAuthEmail(
  CollectionReference<Map<String, dynamic>> usersRef,
  String authEmail,
) async {
  final result = await usersRef.where('authEmail', isEqualTo: authEmail).limit(1).get();
  if (result.docs.isEmpty) return null;
  return result.docs.first;
}

class _AuthAccountResult {
  final String uid;
  final bool isNewAccount;
  final bool passwordWasChanged;

  const _AuthAccountResult({
    required this.uid,
    required this.isNewAccount,
    required this.passwordWasChanged,
  });
}

Future<_AuthAccountResult> _ensureFirebaseAuthAccount({
  required String authEmail,
  required String currentAuthUid,
  required String? newPassword,
}) async {
  final tempPassword = newPassword ?? generateRandomPassword();
  final appName = 'resident-auth-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
  FirebaseApp? secondaryApp;

  try {
    secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: tempPassword,
      );
      return _AuthAccountResult(
        uid: credential.user!.uid,
        isNewAccount: true,
        passwordWasChanged: true,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;

      if (currentAuthUid.isNotEmpty) {
        return _AuthAccountResult(
          uid: currentAuthUid,
          isNewAccount: false,
          passwordWasChanged: false,
        );
      }

      throw Exception(
        'Akun Firebase Auth untuk $authEmail sudah ada tetapi belum terhubung dengan data users. Sinkronisasi manual diperlukan.',
      );
    }
  } finally {
    if (secondaryApp != null) {
      await secondaryApp.delete();
    }
  }
}
