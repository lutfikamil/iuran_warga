import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreOfflineService {
  static Future<void> configure() async {
    final firestore = FirebaseFirestore.instance;

    if (kIsWeb) {
      try {
        await firestore.enablePersistence(
          const PersistenceSettings(synchronizeTabs: true),
        );
      } catch (_) {
        // Persistence bisa gagal jika tab lain sudah aktif; aplikasi tetap berjalan.
      }
      return;
    }

    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}
