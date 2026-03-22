import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'session_service.dart';

class LogService {
  final FirebaseFirestore _firestore;

  LogService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> logEvent({
    required String action,
    required String target,
    required String detail,
  }) async {
    final role = AuthService.normalizeRole(SessionService.getRole());

    await _firestore.collection('logs').add({
      'action': action,
      'target': target,
      'detail': detail,
      'actorRole': role.isEmpty ? 'unknown' : role,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> streamLogs() {
    return _firestore
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
