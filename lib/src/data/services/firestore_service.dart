import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bms/src/data/models/battery.dart';

/// A service class to handle all interactions with the Firestore database.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference<Battery> _batteriesRef;

  FirestoreService() {
    _batteriesRef = _db.collection('batteries').withConverter<Battery>(
          fromFirestore: (snapshot, _) => Battery.fromJson(snapshot.data()!),
          toFirestore: (battery, _) => battery.toJson(),
        );
  }

  /// Returns a stream of all batteries, ordered by brand and model.
  /// The UI will listen to this stream for real-time updates.
  Stream<List<Battery>> watchBatteries() {
    return _batteriesRef
        .orderBy('brand')
        .orderBy('model')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  /// Adds a new battery document to Firestore.
  Future<void> addBattery(Battery battery) {
    return _batteriesRef.doc(battery.id).set(battery);
  }

  /// Updates an existing battery document in Firestore.
  Future<void> updateBattery(Battery battery) {
    return _batteriesRef.doc(battery.id).update(battery.toJson());
  }

  /// Deletes a battery document from Firestore using its ID.
  Future<void> deleteBattery(String id) {
    return _batteriesRef.doc(id).delete();
  }
}
