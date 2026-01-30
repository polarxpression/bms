import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryEntry {
  String id;
  String batteryId;
  String batteryName;
  String type; // 'in' or 'out'
  String location; // 'stock' or 'gondola'
  int quantity;
  DateTime timestamp;
  String reason; // 'purchase', 'sale', 'adjustment', 'transfer', 'restock'

  HistoryEntry({
    required this.id,
    required this.batteryId,
    required this.batteryName,
    required this.type,
    required this.location,
    required this.quantity,
    required this.timestamp,
    this.reason = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'batteryId': batteryId,
      'batteryName': batteryName,
      'type': type,
      'location': location,
      'quantity': quantity,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map, String id) {
    return HistoryEntry(
      id: id,
      batteryId: map['batteryId'] ?? '',
      batteryName: map['batteryName'] ?? '',
      type: map['type'] ?? '',
      location: map['location'] ?? '',
      quantity: map['quantity'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      reason: map['reason'] ?? '',
    );
  }
}
