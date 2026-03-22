class TunggakanUtil {
  static int hitung(Map<String, dynamic>? pembayaran) {
    if (pembayaran == null || pembayaran.isEmpty) return 0;

    final now = DateTime.now();
    int tunggakan = 0;

    pembayaran.forEach((key, value) {
      final parts = key.split('-');
      if (parts.length != 2) return;

      final tahun = int.tryParse(parts[0]) ?? 0;
      final bulan = int.tryParse(parts[1]) ?? 0;

      final date = DateTime(tahun, bulan);

      // hanya hitung sebelum bulan sekarang
      if (date.isBefore(DateTime(now.year, now.month))) {
        final isPaid = value == true;
        if (!isPaid) tunggakan++;
      }
    });

    return tunggakan;
  }
}
