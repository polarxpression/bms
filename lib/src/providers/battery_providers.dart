import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bms/src/data/models/battery.dart';
import 'package:bms/src/data/services/firestore_service.dart';

/// Provider for the FirestoreService instance.
///
/// This allows other providers and UI components to access the service
/// while keeping it testable and decoupled.
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider that streams the list of all batteries from Firestore.
///
/// The UI will listen to this provider to get real-time updates
/// and rebuild automatically when the battery data changes.
final batteriesStreamProvider = StreamProvider<List<Battery>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchBatteries();
});
