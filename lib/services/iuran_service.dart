import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:iuran_perumahan/services/session_service.dart';
import 'package:logger/logger.dart';
import 'settings_service.dart';
import 'log_service.dart';
import '../utils/bulan_util.dart';
import 'whatsapp_service.dart';

final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);

class IuranService {
  final FirebaseFirestore _firestore;

  IuranService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  void _log(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  bool _isIuranEnabledForWarga(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    if (status != 'kosong') {
      return true;
    }

    return data['iuranAktif'] == true;
  }

  Future<void> generateIuran(String bulan, int tahun) async {
    final existingIuran = await _firestore
        .collection("iuran")
        .where("bulan", isEqualTo: bulan)
        .where("tahun", isEqualTo: tahun)
        .limit(1)
        .get();

    if (existingIuran.docs.isNotEmpty) {
      throw Exception("Iuran $bulan $tahun sudah pernah dibuat");
    }
    final bulanIndex = BulanUtil.toInt(bulan);
    final wargaSnapshot = await _firestore
        .collection("warga")
        .where("iuranAktif", isEqualTo: true)
        .get();
    final iuranAmount = await SettingsService().getIuranAmount();
    final jatuhTempo = DateTime(tahun, bulanIndex, 10);
    WriteBatch batch = _firestore.batch();
    int counter = 0;

    for (var warga in wargaSnapshot.docs) {
      final wargaData = warga.data();
      if (!_isIuranEnabledForWarga(wargaData)) {
        continue;
      }

      final ref = _firestore.collection("iuran").doc();

      batch.set(ref, {
        "wargaId": warga.id,
        "bulan": bulan,
        "tahun": tahun,
        "jumlah": iuranAmount,
        "status": "belum",
        "notifTerkirim": false,
        "jatuhTempo": Timestamp.fromDate(jatuhTempo),
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      counter++;

      if (counter % 400 == 0) {
        await batch.commit();
        batch = _firestore.batch();
      }
    }

    await batch.commit();
  }

  Future<void> generateIuranSetahun(int tahun) async {
    final bulanList = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];

    for (var bulan in bulanList) {
      try {
        await generateIuran(bulan, tahun);
      } catch (_) {
        // jika sudah ada, skip
      }
    }
  }

  Future<int> generateIuranMulaiBulanBerikutnyaUntukWargaBaru({
    required String wargaId,
    DateTime? tanggalDaftar,
  }) async {
    final now = tanggalDaftar ?? DateTime.now();
    final dataWarga = (await _firestore.collection('warga').doc(wargaId).get())
        .data();

    if (dataWarga == null || !_isIuranEnabledForWarga(dataWarga)) {
      return 0;
    }

    final targetDate = DateTime(now.year, now.month + 1);
    final startMonth = targetDate.month;
    final tahun = targetDate.year;
    final iuranAmount = await SettingsService().getIuranAmount();
    final existingIuranSnapshot = await _firestore
        .collection('iuran')
        .where('wargaId', isEqualTo: wargaId)
        .where('tahun', isEqualTo: tahun)
        .get();

    final existingMonthsForWarga = <int>{
      for (final doc in existingIuranSnapshot.docs)
        BulanUtil.toInt((doc.data()['bulan'] ?? '').toString()),
    };

    final existingYearSnapshot = await _firestore
        .collection('iuran')
        .where('tahun', isEqualTo: tahun)
        .get();

    final availableMonths = <int>{
      for (final doc in existingYearSnapshot.docs)
        BulanUtil.toInt((doc.data()['bulan'] ?? '').toString()),
    };

    WriteBatch batch = _firestore.batch();
    int counter = 0;
    int createdCount = 0;

    for (var month = startMonth; month <= 12; month++) {
      if (!availableMonths.contains(month) ||
          existingMonthsForWarga.contains(month)) {
        continue;
      }

      final bulan = BulanUtil.toStringMonth(month);
      final jatuhTempo = DateTime(tahun, month, 10);
      final ref = _firestore.collection('iuran').doc();

      batch.set(ref, {
        'wargaId': wargaId,
        'bulan': bulan,
        'tahun': tahun,
        'jumlah': iuranAmount,
        'status': 'belum',
        'notifTerkirim': false,
        'jatuhTempo': Timestamp.fromDate(jatuhTempo),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      counter++;
      createdCount++;

      if (counter % 400 == 0) {
        await batch.commit();
        batch = _firestore.batch();
      }
    }

    if (counter > 0) {
      await batch.commit();
    }

    return createdCount;
  }

  Future<String> bayarIuranWarga({
    required String wargaId,
    required String bulan,
    required int tahun,
  }) async {
    final iuranSnapshot = await _firestore
        .collection("iuran")
        .where("wargaId", isEqualTo: wargaId)
        .where("bulan", isEqualTo: bulan)
        .where("tahun", isEqualTo: tahun)
        .limit(1)
        .get();

    if (iuranSnapshot.docs.isEmpty) {
      throw Exception("Data iuran $bulan $tahun untuk warga tidak ditemukan.");
    }

    final iuranId = iuranSnapshot.docs.first.id;
    await bayar(iuranId);
    return iuranId;
  }

  /// Memproses pembayaran iuran.
  /// Menggunakan Firestore transaction untuk memastikan atomisitas operasi,
  /// dan menulis ke koleksi 'transaksi'.
  Future<void> bayar(String iuranId) async {
    _log('Memulai proses pembayaran untuk iuran ID: $iuranId');
    try {
      await _firestore.runTransaction((transaction) async {
        final iuranRef = _firestore.collection("iuran").doc(iuranId);
        final iuranSnapshot = await transaction.get(iuranRef);

        if (!iuranSnapshot.exists) {
          throw Exception("Iuran dengan ID $iuranId tidak ditemukan.");
        }

        final data = iuranSnapshot.data()!;
        if (data["status"] == "lunas") {
          throw Exception("Iuran sudah lunas.");
        }

        final wargaRef = _firestore.collection("warga").doc(data["wargaId"]);
        final wargaSnapshot = await transaction.get(wargaRef);
        final wargaData = wargaSnapshot.data();
        final String namaWarga = wargaData?['nama'] ?? 'Warga Tidak Diketahui';
        final String rumahWarga = wargaData?['rumah'] ?? '-';
        final String dariKeterangan = '$namaWarga (Rumah $rumahWarga)';
        final role = SessionService.getRole();
        //final namaUser = user?["user"] ?? "Unknown";
        final transaksiRef = _firestore.collection("transaksi").doc();
        transaction.set(transaksiRef, {
          "tanggal": FieldValue.serverTimestamp(),
          "jenis": "masuk",
          "sumberPemasukan": "iuran",
          "wargaId": data["wargaId"],
          "bulanIuran": data["bulan"],
          "tahunIuran": data["tahun"],
          "jumlah": data["jumlah"],
          "dari": dariKeterangan,
          "penerima": role, // Ambil dari session user yang login
          "keterangan": "Iuran bulan ${data["bulan"]} ID Iuran: $iuranId",
          "statusBendahara": "menunggu", // Status awal saat dimasukkan
          "referensiId": iuranId,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

        // Update status iuran menjadi lunas
        transaction.update(iuranRef, {
          "status": "lunas",
          "updatedAt": FieldValue.serverTimestamp(),
          "tanggalBayar": FieldValue.serverTimestamp(),
        });
      });
      _log('Pembayaran iuran ID: $iuranId berhasil.');
      await LogService().logEvent(
        action: 'pembayaran_iuran',
        target: 'iuran',
        detail: 'Pembayaran berhasil untuk iuranId=$iuranId',
      );
    } catch (e, st) {
      _log(
        'Gagal memproses pembayaran untuk iuran ID: $iuranId: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> kirimTagihan({
    required String nama,
    required String hp,
    required String bulan,
    required int tahun,
    required num jumlah,
  }) async {
    await WhatsappService.sendMessage(
      phone: hp,
      message:
          '''
Halo Bapak/Ibu $nama 👋

 Tagihan Iuran:
Bulan: $bulan $tahun
Jumlah: Rp $jumlah

Mohon segera melakukan pembayaran demi kelancaran
kegiatan lingkungan perumahan Muli Land Patria.

Terimaksih.
Pengurus Perumahan Mulia Land Patria.
''',
    );
  }

  Future<int> kirimTagihanBulanIniManual() async {
    final now = DateTime.now();
    final bulan = BulanUtil.toStringMonth(now.month);
    final tahun = now.year;

    final iuranSnapshot = await _firestore
        .collection("iuran")
        .where("bulan", isEqualTo: bulan)
        .where("tahun", isEqualTo: tahun)
        .get();

    final wargaSnapshot = await _firestore
        .collection("warga")
        .where("hp", isGreaterThan: "")
        .where("iuranAktif", isEqualTo: true)
        .get();

    final Map<String, Map<String, dynamic>> wargaMap = {
      for (var w in wargaSnapshot.docs) w.id: w.data(),
    };

    WriteBatch batch = _firestore.batch();
    int sent = 0;

    for (var doc in iuranSnapshot.docs) {
      final data = doc.data();

      /// ❌ skip kalau sudah lunas
      if (data['status'] == 'lunas') continue;

      /// ❌ skip kalau sudah pernah dikirim
      if (data['notifTerkirim'] == true) continue;

      final warga = wargaMap[data['wargaId']];
      if (warga == null) continue;

      final nama = warga['nama'] ?? '';
      final hp = warga['hp'] ?? '';

      if (hp.isEmpty) continue;

      try {
        await kirimTagihan(
          nama: nama,
          hp: hp,
          bulan: bulan,
          tahun: tahun,
          jumlah: data['jumlah'],
        );

        /// tandai sudah dikirim
        batch.update(doc.reference, {
          "notifTerkirim": true,
          "updatedAt": FieldValue.serverTimestamp(),
        });

        sent++;

        /// delay biar aman dari limit WA API
        await Future.delayed(const Duration(seconds: 6));
      } catch (e) {
        _log("Gagal kirim ke $nama: $e");
      }
    }

    await batch.commit();

    return sent;
  }

  //  Future<void> kirimTagihanBulananOtomatis() async {
  //    final now = DateTime.now();
  //    final bulan = BulanUtil.toStringMonth(now.month);
  //    final tahun = now.year;
  //
  //    /// 🔥 ambil hanya bulan ini + belum dikirim
  //    final iuranSnapshot = await _firestore
  //        .collection("iuran")
  //        .where("bulan", isEqualTo: bulan)
  //        .where("tahun", isEqualTo: tahun)
  //        .where("notifTerkirim", isEqualTo: false)
  //        .get();
  //
  //    final wargaSnapshot = await _firestore.collection("warga").where("iuranAktif", isEqualTo: true).get();
  //
  //    final Map<String, Map<String, dynamic>> wargaMap = {
  //      for (var w in wargaSnapshot.docs) w.id: w.data(),
  //    };
  //
  //    WriteBatch batch = _firestore.batch();
  //    int sent = 0;
  //
  //    for (var doc in iuranSnapshot.docs) {
  //      final data = doc.data();
  //
  //      /// skip kalau sudah lunas
  //      if (data['status'] == 'lunas') continue;
  //
  //      final warga = wargaMap[data['wargaId']];
  //      if (warga == null) continue;
  //
  //      final nama = warga['nama'] ?? '';
  //      final hp = warga['hp'] ?? '';
  //
  //      if (hp.isEmpty) continue;
  //
  //      try {
  //        await kirimTagihan(
  //          nama: nama,
  //          hp: hp,
  //          bulan: bulan,
  //          tahun: tahun,
  //          jumlah: data['jumlah'],
  //        );
  //
  //        /// 🔥 tandai sudah kirim
  //        batch.update(doc.reference, {
  //          "notifTerkirim": true,
  //          "updatedAt": FieldValue.serverTimestamp(),
  //        });
  //
  //        sent++;
  //
  //        await Future.delayed(const Duration(seconds: 5));
  //      } catch (e) {
  //        _log("Gagal kirim ke $nama: $e");
  //      }
  //    }
  //
  //    await batch.commit();
  //
  //    _log("Berhasil kirim $sent tagihan bulan $bulan");
  //  }
}
