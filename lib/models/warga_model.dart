class WargaModel {
  final String id;
  final String nama;
  final String rumah;
  final String hp;
  final String status;

  WargaModel({
    required this.id,
    required this.nama,
    required this.rumah,
    required this.hp,
    required this.status,
  });

  factory WargaModel.fromMap(String id, Map<String, dynamic> data) {
    return WargaModel(
      id: id,
      nama: data['nama'] ?? '',
      rumah: data['rumah'] ?? '',
      hp: data['hp'] ?? '',
      status: data['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'nama': nama, 'rumah': rumah, 'hp': hp, 'status': status};
  }
}
