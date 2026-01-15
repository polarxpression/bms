class BatteryMap {
  final String id;
  final String name;
  final String purpose;

  BatteryMap({required this.id, required this.name, required this.purpose});

  factory BatteryMap.fromMap(Map<String, dynamic> data, String id) {
    return BatteryMap(
      id: id,
      name: data['name'] ?? 'Sem Nome',
      purpose: data['purpose'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'purpose': purpose};
  }
}
