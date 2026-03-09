import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryEntry {
  String id;
  String batteryId;
  String batteryName;
  String batteryType;
  int packSize;
  String type; // 'in' or 'out'
  String location; // 'stock' or 'gondola'
  int quantity;
  DateTime timestamp;
  String reason; // 'purchase', 'sale', 'adjustment', 'transfer', 'restock'
  String source; // 'map', 'form', 'restock', etc.

  HistoryEntry({
    required this.id,
    required this.batteryId,
    required this.batteryName,
    this.batteryType = 'AA',
    this.packSize = 1,
    required this.type,
    required this.location,
    required this.quantity,
    required this.timestamp,
    this.reason = '',
    this.source = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'batteryId': batteryId,
      'batteryName': batteryName,
      'batteryType': batteryType,
      'packSize': packSize,
      'type': type,
      'location': location,
      'quantity': quantity,
      'timestamp': Timestamp.fromDate(timestamp),
      'reason': reason,
      'source': source,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map, String id) {
    return HistoryEntry(
      id: id,
      batteryId: map['batteryId'] ?? '',
      batteryName: map['batteryName'] ?? '',
      batteryType: map['batteryType'] ?? 'AA',
      packSize: map['packSize'] ?? 1,
      type: map['type'] ?? '',
      location: map['location'] ?? '',
      quantity: map['quantity'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      reason: map['reason'] ?? '',
      source: map['source'] ?? '',
    );
  }
}
