import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreOfflineService {
  static Future<void> configure() async {
    final firestore = FirebaseFirestore.instance;

    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}
