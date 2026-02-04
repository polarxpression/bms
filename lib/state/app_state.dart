import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart';
import 'package:bms/core/models/battery.dart';
import 'package:bms/core/models/battery_map.dart';
import 'package:bms/core/models/history_entry.dart';
import 'package:bms/core/models/app_notification.dart';

class AppState extends ChangeNotifier {
  List<Battery> _batteries = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _subscription;
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;
  StreamSubscription<QuerySnapshot>? _cellsSubscription;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  final CollectionReference _collection = FirebaseFirestore.instance.collection(
    'batteries',
  );
  final CollectionReference _settingsCollection = FirebaseFirestore.instance
      .collection('settings');
  final CollectionReference _mapsCollection = FirebaseFirestore.instance
      .collection('maps');
  final CollectionReference _historyCollection = FirebaseFirestore.instance
      .collection('history');
  final CollectionReference _notificationsCollection = FirebaseFirestore
      .instance
      .collection('notifications');

  // Settings
  int _defaultGondolaCapacity = 20;
  int _defaultMinStockThreshold = 10;
  int _daysToAnalyze = 90; // Default days for analysis
  String _imgbbApiKey = ''; // NEW

  // Maps Data
  List<BatteryMap> _maps = [];
  String? _currentMapId;
  Map<String, String> _batteryMap = {}; // Cells of current map

  // Highlight State
  String? _targetBatteryId;
  String? _targetCell;

  // Analysis Data
  Map<String, double> _monthlyConsumption = {}; // BatteryId -> Avg Qty/Month

  // Notifications Data
  List<AppNotification> _notifications = [];

  // Navigation State
  int _currentTabIndex = 0;

  List<Battery> get batteries => List.unmodifiable(_batteries);
  bool get isLoading => _isLoading;
  int get defaultGondolaCapacity => _defaultGondolaCapacity;
  int get defaultMinStockThreshold => _defaultMinStockThreshold;
  int get daysToAnalyze => _daysToAnalyze;
  String get imgbbApiKey => _imgbbApiKey; // NEW
  Map<String, String> get batteryMap => Map.unmodifiable(_batteryMap);
  List<BatteryMap> get maps => List.unmodifiable(_maps);
  Map<String, double> get monthlyConsumption =>
      Map.unmodifiable(_monthlyConsumption);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.isRead).length;
  String? get targetBatteryId => _targetBatteryId;
  String? get targetCell => _targetCell;
  int get currentTabIndex => _currentTabIndex;

  BatteryMap? get currentMap => _maps.isEmpty || _currentMapId == null
      ? null
      : _maps.firstWhere(
          (m) => m.id == _currentMapId,
          orElse: () => _maps.first,
        );

  AppState() {
    _initRealtimeUpdates();
    _checkScheduledNotifications();
  }

  Future<void> _checkScheduledNotifications() async {
    final now = DateTime.now();
    // Monday = 1
    if (now.weekday == DateTime.monday) {
      final todayStr = '${now.year}-${now.month}-${now.day}';

      // Check last run from settings/local storage (using Firestore config for persistence across devices/restarts)
      final configDoc = await _settingsCollection
          .doc('notifications_run')
          .get();
      final data = configDoc.exists
          ? configDoc.data() as Map<String, dynamic>
          : {};

      final lastWeeklyRun = data['lastWeeklyRun'] as String?;
      final lastMonthlyRun = data['lastMonthlyRun'] as String?;

      // 1. Weekly Map Update (Every Monday)
      if (lastWeeklyRun != todayStr) {
        await addNotification(
          title: 'Atualizar Mapa',
          message: 'Lembrete semanal: Por favor, atualize o mapa de baterias.',
          type: 'reminder',
        );
        await _settingsCollection.doc('notifications_run').set({
          'lastWeeklyRun': todayStr,
        }, SetOptions(merge: true));
      }

      // 2. Monthly Buy (1st Monday of Month)
      // Check if this is the first Monday of the month
      // If day is <= 7, it's the first occurrence of this weekday in the month
      if (now.day <= 7) {
        // Construct a unique key for this month's run: YYYY-MM
        final monthKey = '${now.year}-${now.month}';
        if (lastMonthlyRun != monthKey) {
          await addNotification(
            title: 'Comprar Baterias',
            message:
                'Primeira segunda-feira do mês. Verifique o estoque e faça compras se necessário.',
            type: 'reminder',
          );
          await _settingsCollection.doc('notifications_run').set({
            'lastMonthlyRun': monthKey,
          }, SetOptions(merge: true));
        }
      }
    }
  }

  Future<void> addNotification({
    required String title,
    required String message,
    String? type,
    String? actionUrl,
  }) async {
    await _notificationsCollection.add({
      'title': title,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': type,
      'actionUrl': actionUrl,
    });
  }

  Future<void> markNotificationAsRead(String id) async {
    await _notificationsCollection.doc(id).update({'isRead': true});
  }

  Future<void> clearAllNotifications() async {
    final batch = FirebaseFirestore.instance.batch();
    for (var n in _notifications) {
      batch.delete(_notificationsCollection.doc(n.id));
    }
    await batch.commit();
  }

  void setTabIndex(int index) {
    _currentTabIndex = index;
    // Clear highlight if navigating away or re-selecting
    _targetBatteryId = null;
    _targetCell = null;
    notifyListeners();
  }

  void clearHighlight() {
    _targetBatteryId = null;
    _targetCell = null;
    notifyListeners();
  }

  Future<void> navigateToMapHighlight(String mapId, String batteryId) async {
    // 1. Select the map
    selectMap(mapId);

    // 2. Set target
    _targetBatteryId = batteryId;
    _targetCell = null;

    // 3. Switch to Map Tab (Index 2 in MainLayoutShell)
    _currentTabIndex = 2;

    notifyListeners();
  }

  void _initRealtimeUpdates() {
    // Batteries
    _subscription = _collection.snapshots().listen((snapshot) {
      _batteries = snapshot.docs.map((doc) {
        return Battery.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      _isLoading = false;
      notifyListeners();
    });

    // Settings
    _settingsSubscription = _settingsCollection
        .doc('config')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            if (data.containsKey('defaultGondolaCapacity')) {
              _defaultGondolaCapacity = data['defaultGondolaCapacity'];
            }
            if (data.containsKey('defaultMinStockThreshold')) {
              _defaultMinStockThreshold = data['defaultMinStockThreshold'];
            }
            if (data.containsKey('daysToAnalyze')) {
              _daysToAnalyze = data['daysToAnalyze'];
            }
            if (data.containsKey('imgbbApiKey')) {
              _imgbbApiKey = data['imgbbApiKey'];
            }
            notifyListeners();
            // Trigger analysis when batteries are loaded or settings change
            if (_batteries.isNotEmpty) {
              refreshAnalysis();
            }
          }
        });

    // Maps List
    _mapsCollection.snapshots().listen((snapshot) {
      _maps = snapshot.docs.map((doc) {
        return BatteryMap.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Auto-select or create if empty
      if (_maps.isEmpty) {
        createMap('Mapa Principal', 'Mapa padrão do sistema');
      } else if (_currentMapId == null ||
          !_maps.any((m) => m.id == _currentMapId)) {
        selectMap(_maps.first.id);
      }

      // Attempt migration once maps are loaded
      if (_maps.isNotEmpty) {
        _migrateLegacyMapData();
      }

      notifyListeners();
    });

    // Notifications
    _notificationsSubscription = _notificationsCollection
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
          _notifications = snapshot.docs.map((doc) {
            return AppNotification.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _settingsSubscription?.cancel();
    _cellsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> updateDefaultCapacity(int newCap) async {
    _defaultGondolaCapacity = newCap;
    notifyListeners();
    await _settingsCollection.doc('config').set({
      'defaultGondolaCapacity': newCap,
    }, SetOptions(merge: true));
  }

  Future<void> updateDefaultMinStockThreshold(int newThreshold) async {
    _defaultMinStockThreshold = newThreshold;
    notifyListeners();
    await _settingsCollection.doc('config').set({
      'defaultMinStockThreshold': newThreshold,
    }, SetOptions(merge: true));
  }

  Future<void> updateDaysToAnalyze(int days) async {
    _daysToAnalyze = days;
    notifyListeners();
    await _settingsCollection.doc('config').set({
      'daysToAnalyze': days,
    }, SetOptions(merge: true));
    refreshAnalysis();
  }

  Future<void> updateImgbbApiKey(String key) async {
    _imgbbApiKey = key;
    notifyListeners();
    await _settingsCollection.doc('config').set({
      'imgbbApiKey': key,
    }, SetOptions(merge: true));
  }

  Future<void> _migrateLegacyMapData() async {
    try {
      final migrationDoc = await _settingsCollection.doc('migration').get();
      if (migrationDoc.exists &&
          (migrationDoc.data() as Map)['legacyMapMigrated'] == true) {
        return;
      }

      final legacyCollection = FirebaseFirestore.instance.collection(
        'battery_map',
      );
      final legacyDocs = await legacyCollection.get();

      if (legacyDocs.docs.isEmpty) {
        // No data to migrate, just mark as done
        await _settingsCollection.doc('migration').set({
          'legacyMapMigrated': true,
        }, SetOptions(merge: true));
        return;
      }

      // We need a target map. Use the first one (likely 'Mapa Principal')
      final targetMapId = _maps.first.id;
      final targetCellsRef = _mapsCollection
          .doc(targetMapId)
          .collection('cells');

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in legacyDocs.docs) {
        final data = doc.data();
        batch.set(targetCellsRef.doc(doc.id), {
          ...data,
          'migratedAt': Timestamp.now(),
        });
      }

      await batch.commit();
      await _settingsCollection.doc('migration').set({
        'legacyMapMigrated': true,
      }, SetOptions(merge: true));
      // print('Legacy map data migrated to map: $targetMapId');
    } catch (e) {
      // print('Migration error: $e');
    }
  }

  void selectMap(String mapId) {
    if (_currentMapId == mapId) return;

    _currentMapId = mapId;
    _batteryMap = {};
    notifyListeners(); // Clear current view temporarily

    _cellsSubscription?.cancel();
    _cellsSubscription = _mapsCollection
        .doc(mapId)
        .collection('cells')
        .snapshots()
        .listen((snapshot) {
          final Map<String, String> newMap = {};
          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data.containsKey('x') &&
                data.containsKey('y') &&
                data.containsKey('batteryId')) {
              newMap['${data['x']},${data['y']}'] = data['batteryId'];
            }
          }
          _batteryMap = newMap;
          notifyListeners();
        });
  }

  Future<void> createMap(String name, String purpose) async {
    final docRef = await _mapsCollection.add({
      'name': name,
      'purpose': purpose,
      'createdAt': Timestamp.now(),
    });
    // If it's the first map, select it
    if (_maps.length == 1) {
      selectMap(docRef.id);
    }
  }

  Future<void> updateMap(String id, String name, String purpose) async {
    await _mapsCollection.doc(id).update({'name': name, 'purpose': purpose});
  }

  Future<void> deleteMap(String id) async {
    // Delete cells subcollection? Firestore doesn't auto-delete subcollections.
    // For this app, we'll just delete the metadata doc.
    // Ideally we should delete subcollection docs via a Cloud Function or client-side loop.
    // Let's do client-side delete for robustness in this small scale.
    final cells = await _mapsCollection.doc(id).collection('cells').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in cells.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_mapsCollection.doc(id));
    await batch.commit();
  }

  Future<void> refreshData() async {
    // Manually fetch batteries
    final batterySnapshot = await _collection.get();
    _batteries = batterySnapshot.docs.map((doc) {
      return Battery.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    // Refresh Settings
    final settingsSnapshot = await _settingsCollection.doc('config').get();
    if (settingsSnapshot.exists) {
      final data = settingsSnapshot.data() as Map<String, dynamic>;
      if (data.containsKey('defaultGondolaCapacity')) {
        _defaultGondolaCapacity = data['defaultGondolaCapacity'];
      }
      if (data.containsKey('defaultMinStockThreshold')) {
        _defaultMinStockThreshold = data['defaultMinStockThreshold'];
      }
      if (data.containsKey('daysToAnalyze')) {
        _daysToAnalyze = data['daysToAnalyze'];
      }
    }

    // Refresh Analysis
    refreshAnalysis();

    // Refresh Maps List
    final mapsSnapshot = await _mapsCollection.get();
    _maps = mapsSnapshot.docs.map((doc) {
      return BatteryMap.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    // Refresh Current Map Cells
    if (_currentMapId != null) {
      final cellsSnapshot = await _mapsCollection
          .doc(_currentMapId)
          .collection('cells')
          .get();
      final Map<String, String> newMap = {};
      for (var doc in cellsSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('x') &&
            data.containsKey('y') &&
            data.containsKey('batteryId')) {
          newMap['${data['x']},${data['y']}'] = data['batteryId'];
        }
      }
      _batteryMap = newMap;
    }

    notifyListeners();
  }

  // History & Analysis
  Future<List<HistoryEntry>> fetchHistory({
    DateTime? start,
    DateTime? end,
  }) async {
    Query query = _historyCollection.orderBy('timestamp', descending: true);

    if (start != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (end != null) {
      // End of the day
      final e = DateTime(end.year, end.month, end.day, 23, 59, 59);
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(e),
      );
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return HistoryEntry.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  Future<void> logHistory({
    required String batteryId,
    required String batteryName,
    required String type, // 'in' or 'out'
    required String location, // 'stock' or 'gondola'
    required int quantity,
    required String reason,
    String source = 'form', // 'form' or 'map' or 'system'
  }) async {
    if (quantity == 0) return;
    final entry = HistoryEntry(
      id: '', // Auto-gen
      batteryId: batteryId,
      batteryName: batteryName,
      type: type,
      location: location,
      quantity: quantity,
      timestamp: DateTime.now(),
      reason: reason,
      source: source,
    );
    await _historyCollection.add(entry.toMap());
  }

  Future<void> refreshAnalysis() async {
    if (_batteries.isEmpty) return;

    final cutoff = DateTime.now().subtract(Duration(days: _daysToAnalyze));

    // Fetch OUT history for the last X days
    final snapshot = await _historyCollection
        .where('type', isEqualTo: 'out')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .get();

    final Map<String, int> totalOuts = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final qty = data['quantity'] as int? ?? 0;
      final bid = data['batteryId'] as String? ?? '';
      final source = data['source'] as String? ?? '';

      // If OUT event, only count if source is MAP (as per requirement)
      if (data['type'] == 'out' && source != 'map') continue;

      // We only care about consumption (Sales/Usage), not transfers
      // Transfers usually show as 'out' from Stock with reason 'restock'
      // Adjustments can be 'adjustment'
      final reason = data['reason'] as String? ?? '';

      // If reason is 'restock', it means it moved to Gondola, NOT sold yet.
      // Real consumption is usually from Gondola (reason 'sale' or 'usage' or 'adjustment' if negative)
      // Or from Stock if direct sale.
      // Let's assume 'restock' is internal transfer.
      if (reason == 'restock') continue;

      if (bid.isNotEmpty) {
        totalOuts[bid] = (totalOuts[bid] ?? 0) + qty;
      }
    }

    final Map<String, double> newConsumption = {};
    // Calculate Monthly Rate
    // If we analyze 90 days, monthly rate = total / 3
    final months = _daysToAnalyze / 30.0;
    if (months <= 0) return;

    // We need to map battery IDs to their "Group" (Barcode) because external buy is grouped
    // Actually, `externalBuyBatteries` groups them.
    // We can just store per batteryId and aggregate later, OR aggregate here.
    // Storing per batteryId is more flexible.

    totalOuts.forEach((bid, qty) {
      newConsumption[bid] = qty / months;
    });

    _monthlyConsumption = newConsumption;
    notifyListeners();
  }

  // Map Methods
  Future<void> placeBatteryOnMap(int x, int y, String batteryId) async {
    if (_currentMapId == null) return;
    final docId = 'cell_${x}_$y';
    await _mapsCollection.doc(_currentMapId).collection('cells').doc(docId).set(
      {'x': x, 'y': y, 'batteryId': batteryId, 'updatedAt': Timestamp.now()},
    );
  }

  Future<void> removeBatteryFromMap(int x, int y) async {
    if (_currentMapId == null) return;
    final docId = 'cell_${x}_$y';

    // We need to know WHICH battery was there to log history?
    // The previous implementation just deleted.
    // Usually removing from map DOES NOT mean sold. It just means removed from map.
    // So we don't log 'out' here unless the user explicitly says "sold".
    // The requirement says "out should only be counted if modified via the map".
    // This usually implies decrementing quantity ON THE MAP.

    await _mapsCollection
        .doc(_currentMapId)
        .collection('cells')
        .doc(docId)
        .delete();
  }

  Future<void> moveBatteryOnMap(int fromX, int fromY, int toX, int toY) async {
    if (_currentMapId == null) return;
    final sourceKey = '$fromX,$fromY';
    if (!_batteryMap.containsKey(sourceKey)) return;

    final batteryId = _batteryMap[sourceKey]!;

    final batch = FirebaseFirestore.instance.batch();
    final cellsRef = _mapsCollection.doc(_currentMapId).collection('cells');

    // 1. Write to new location
    batch.set(cellsRef.doc('cell_${toX}_$toY'), {
      'x': toX,
      'y': toY,
      'batteryId': batteryId,
      'updatedAt': Timestamp.now(),
    });

    // 2. Delete from old location
    batch.delete(cellsRef.doc('cell_${fromX}_$fromY'));

    await batch.commit();
  }

  Future<void> swapBatteriesOnMap(int x1, int y1, int x2, int y2) async {
    if (_currentMapId == null) return;
    final key1 = '$x1,$y1';
    final key2 = '$x2,$y2';

    final id1 = _batteryMap[key1];
    final id2 = _batteryMap[key2];

    if (id1 != null && id2 != null) {
      final batch = FirebaseFirestore.instance.batch();
      final cellsRef = _mapsCollection.doc(_currentMapId).collection('cells');

      batch.set(cellsRef.doc('cell_${x1}_$y1'), {
        'x': x1,
        'y': y1,
        'batteryId': id2,
        'updatedAt': Timestamp.now(),
      });

      batch.set(cellsRef.doc('cell_${x2}_$y2'), {
        'x': x2,
        'y': y2,
        'batteryId': id1,
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();
    }
  }

  // Inventory Helper
  int getStockForBattery(Battery battery) {
    final bc = battery.barcode.trim();
    final nameKey =
        '${removeDiacritics(battery.brand.trim().toLowerCase())}|${removeDiacritics(battery.model.trim().toLowerCase())}';

    int total = 0;
    for (var other in _batteries) {
      // Only count stock from items that are NOT in Gondola
      final isGondola =
          other.location.toLowerCase().contains('gondola') ||
          other.location.toLowerCase().contains('gôndola');
      if (isGondola) continue;

      // Match
      bool match = false;
      if (bc.isNotEmpty && other.barcode.trim() == bc) {
        match = true;
      } else if (bc.isEmpty || other.barcode.trim().isEmpty) {
        // Fallback name match
        final k =
            '${removeDiacritics(other.brand.trim().toLowerCase())}|${removeDiacritics(other.model.trim().toLowerCase())}';
        if (k == nameKey) match = true;
      }

      if (match) {
        total += other.quantity;
      }
    }
    return total;
  }

  Future<List<Map<String, String>>> findBatteryInMaps(String batteryId) async {
    final List<Map<String, String>> results = [];

    // Iterate all maps to check their cells collection
    for (var map in _maps) {
      try {
        final query = await _mapsCollection
            .doc(map.id)
            .collection('cells')
            .where('batteryId', isEqualTo: batteryId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          results.add({
            'id': map.id,
            'name': map.name,
            'purpose': map.purpose,
          });
        }
      } catch (e) {
        // Ignore error
      }
    }

    return results;
  }

  int get totalBatteries =>
      _batteries.fold(0, (acc, item) => acc + item.quantity);

  // Restock Logic: Gondola items <= 50% capacity that have matching Stock (by barcode)
  List<Battery> get lowStockBatteries {
    final List<Battery> suggestions = [];

    // 1. Identify all items currently on the Gondola
    final gondolaItems = _batteries.where((b) {
      final loc = b.location.toLowerCase();
      return loc.contains('gondola') || loc.contains('gôndola');
    }).toList();

    // 2. Create a map of Barcode -> Total Stock Quantity
    // We sum up 'quantity' (which represents stock/backroom) for all items.
    final Map<String, int> stockByBarcode = {};
    for (var b in _batteries) {
      // Only count stock from items that are NOT in Gondola
      final isGondola =
          b.location.toLowerCase().contains('gondola') ||
          b.location.toLowerCase().contains('gôndola');
      if (!isGondola && b.quantity > 0) {
        final bc = b.barcode.trim();
        if (bc.isNotEmpty) {
          stockByBarcode[bc] = (stockByBarcode[bc] ?? 0) + b.quantity;
        }
      }
    }

    // 3. Evaluate Gondola Items
    for (var b in gondolaItems) {
      final limit = b.gondolaLimit > 0
          ? b.gondolaLimit
          : _defaultGondolaCapacity;
      if (limit <= 0) continue;

      // Condition: Equal or below half of limit
      if (b.gondolaQuantity <= (limit / 2.0)) {
        // Check Stock by Barcode
        final bc = b.barcode.trim();
        final availableStock = stockByBarcode[bc] ?? 0;

        if (availableStock > 0) {
          // Suggest this item
          // We clone it to show the TOTAL available stock in the UI,
          // not just what might be in this specific document (though usually they are separate).
          suggestions.add(
            Battery(
              id: b.id,
              name: b.name,
              type: b.type,
              brand: b.brand,
              model: b.model,
              barcode: b.barcode,
              imageUrl: b.imageUrl,
              quantity:
                  availableStock, // VISUAL: Total available stock found by barcode
              gondolaQuantity: b.gondolaQuantity,
              location: b.location,
              gondolaLimit: limit,
              lowStockThreshold: b.lowStockThreshold,
              packSize: b.packSize,
              purchaseDate: b.purchaseDate,
              lastChanged: b.lastChanged,
              // Copy other fields as needed
              voltage: b.voltage,
              chemistry: b.chemistry,
              notes: b.notes,
              expiryDate: b.expiryDate,
              discontinued: b.discontinued,
            ),
          );
        }
      }
    }

    return suggestions..sort((a, b) {
      final neededA = a.gondolaLimit - a.gondolaQuantity;
      final neededB = b.gondolaLimit - b.gondolaQuantity;
      return neededB.compareTo(neededA);
    });
  }

  // NEW: External Buy List logic
  List<Battery> get externalBuyBatteries {
    final Map<String, List<Battery>> groups = {};

    // Group items
    for (var b in _batteries) {
      if (b.discontinued) continue;

      // Group by Barcode if present, otherwise Brand|Model
      String key;
      final bc = b.barcode.trim();
      if (bc.isNotEmpty) {
        key = 'bc:$bc';
      } else {
        key =
            'name:${removeDiacritics(b.brand.trim().toLowerCase())}|${removeDiacritics(b.model.trim().toLowerCase())}';
      }

      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(b);
    }

    final List<Battery> buyList = [];

    groups.forEach((key, items) {
      int totalStock = 0;
      int totalGondola = 0;
      int maxGondolaLimit = 0;

      // Logic for Min Stock Threshold
      bool anyManual = false;
      int maxManualThreshold = 0;

      Battery primary = items.first;

      double groupMonthlyConsumption = 0;

      for (var b in items) {
        // Only count stock from non-gondola items to match restock logic
        final isGondola =
            b.location.toLowerCase().contains('gondola') ||
            b.location.toLowerCase().contains('gôndola');
        if (!isGondola) {
          totalStock += b.quantity;
        }

        // Sum Gondola Quantities
        totalGondola += b.gondolaQuantity;

        // Sum Consumption
        groupMonthlyConsumption += _monthlyConsumption[b.id] ?? 0;

        if (!b.useDefaultMinStock) {
          anyManual = true;
          if (b.minStockThreshold > maxManualThreshold) {
            maxManualThreshold = b.minStockThreshold;
          }
        }

        if (b.gondolaLimit > maxGondolaLimit) {
          maxGondolaLimit = b.gondolaLimit;
        }

        if (primary.location != 'Estoque' && b.location == 'Estoque') {
          primary = b;
        }
      }

      int effectiveThreshold = anyManual
          ? maxManualThreshold
          : _defaultMinStockThreshold;

      // DYNAMIC BUY LOGIC:
      // If consumption suggests we need more, increase threshold.
      // Target: Maintain 1 month of stock based on recent consumption.
      // Or 1.5 months? Let's use 1 month for now or make it configurable?
      // Defaulting to 1 month cover.
      final dynamicThreshold = groupMonthlyConsumption.ceil();
      bool isDynamic = false;

      if (dynamicThreshold > effectiveThreshold) {
        effectiveThreshold = dynamicThreshold;
        isDynamic = true;
      }

      // final effectiveGondolaLimit = maxGondolaLimit > 0 ? maxGondolaLimit : _defaultGondolaCapacity;

      bool shouldAdd = false;

      // Rule: Always use totalStock (Reserve) as the primary stock to check.
      // We do not fall back to gondola stock because that masks 'Empty Reserve' situations
      // (e.g., when Gondola is full but Reserve is empty, we still want to buy if threshold > 0).
      int stockToCheck = totalStock;

      // Special case: If user set manual threshold to 0, they likely want to DISABLE the alert.
      // So if anyManual is true and effectiveThreshold is 0, we SKIP adding it.
      if (anyManual && effectiveThreshold == 0 && !isDynamic) {
        shouldAdd = false;
      } else if (stockToCheck <= effectiveThreshold) {
        shouldAdd = true;
      }

      if (shouldAdd) {
        buyList.add(
          Battery(
            id: primary.id,
            name: primary.name,
            type: primary.type,
            brand: primary.brand,
            model: primary.model,
            barcode: primary.barcode,
            imageUrl: primary.imageUrl,
            quantity:
                stockToCheck, // VISUAL: Effective Stock used for decision (Stock or Gondola fallback)
            gondolaQuantity: totalGondola,
            location: primary.location,
            minStockThreshold:
                effectiveThreshold, // VISUAL: Target Threshold (Dynamic or Static)
            useDefaultMinStock: !anyManual, // VISUAL
            // Hack: Use 'notes' to pass metadata to UI about dynamic nature
            notes: isDynamic
                ? 'dynamic:${groupMonthlyConsumption.toStringAsFixed(1)}'
                : '',
            gondolaLimit: maxGondolaLimit > 0
                ? maxGondolaLimit
                : _defaultGondolaCapacity,
            purchaseDate: primary.purchaseDate,
            lastChanged: primary.lastChanged,
            packSize: primary.packSize,
          ),
        );
      }
    });

    return buyList;
  }

  Future<void> addBattery(Battery battery) async {
    final docRef = await _collection.add(battery.toMap());
    // Log Initial Stock
    if (battery.quantity > 0) {
      await logHistory(
        batteryId: docRef.id,
        batteryName: battery.name,
        type: 'in',
        location: 'stock',
        quantity: battery.quantity,
        reason: 'initial_stock',
        source: 'form',
      );
    }
    if (battery.gondolaQuantity > 0) {
      await logHistory(
        batteryId: docRef.id,
        batteryName: battery.name,
        type: 'in',
        location: 'gondola',
        quantity: battery.gondolaQuantity,
        reason: 'initial_stock',
        source: 'form',
      );
    }
  }

  Future<void> updateBattery(Battery updated) async {
    // Find old to compare
    final old = _batteries.firstWhere(
      (b) => b.id == updated.id,
      orElse: () => updated,
    );

    await _collection.doc(updated.id).update(updated.toMap());

    // Check Stock Change
    final stockDelta = updated.quantity - old.quantity;
    if (stockDelta != 0) {
      await logHistory(
        batteryId: updated.id,
        batteryName: updated.name,
        type: stockDelta > 0 ? 'in' : 'out',
        location: 'stock',
        quantity: stockDelta.abs(),
        reason: 'edit_form',
        source: 'form',
      );
    }

    // Check Gondola Change
    final gondolaDelta = updated.gondolaQuantity - old.gondolaQuantity;
    if (gondolaDelta != 0) {
      await logHistory(
        batteryId: updated.id,
        batteryName: updated.name,
        type: gondolaDelta > 0 ? 'in' : 'out',
        location: 'gondola',
        quantity: gondolaDelta.abs(),
        reason: 'edit_form',
        source: 'form',
      );
    }
  }

  Future<void> deleteBattery(String id) async =>
      await _collection.doc(id).delete();

  Future<void> adjustQuantity(
    Battery battery,
    int delta, {
    String reason = 'adjustment',
    String source = 'form',
  }) async {
    final newQty = (battery.quantity + delta).clamp(0, 9999);
    await _collection.doc(battery.id).update({
      'quantity': newQty,
      'lastChanged': Timestamp.now(),
    });

    // Log History
    if (delta != 0) {
      await logHistory(
        batteryId: battery.id,
        batteryName: battery.name,
        type: delta > 0 ? 'in' : 'out',
        location: 'stock',
        quantity: delta.abs(),
        reason: reason,
        source: source,
      );
    }
  }

  // NEW: Adjust gondola quantity
  Future<void> adjustGondolaQuantity(
    Battery battery,
    int delta, {
    String reason = 'adjustment',
    String source = 'form',
  }) async {
    final limit = battery.gondolaLimit > 0
        ? battery.gondolaLimit
        : _defaultGondolaCapacity;
    final newQty = (battery.gondolaQuantity + delta).clamp(0, limit);
    await _collection.doc(battery.id).update({
      'gondolaQuantity': newQty,
      'lastChanged': Timestamp.now(),
    });

    // Log History
    if (delta != 0) {
      await logHistory(
        batteryId: battery.id,
        batteryName: battery.name,
        type: delta > 0 ? 'in' : 'out',
        location: 'gondola',
        quantity: delta.abs(),
        reason: reason,
        source: source,
      );
    }
  }

  // FIXED: Move to gondola - transfers from stock to gondola with safety checks
  // Now handles "Smart Restock" by looking for stock in sibling items if needed.
  Future<void> moveToGondola(Battery battery, int amount) async {
    // 0. Use Real Battery Data
    // We must find the real document in our local list to ensure we aren't using
    // a "Synthetic" battery from the UI which has aggregated counts.
    final realBattery = _batteries.firstWhere(
      (b) => b.id == battery.id,
      orElse: () => battery,
    );

    final limit = realBattery.gondolaLimit > 0
        ? realBattery.gondolaLimit
        : _defaultGondolaCapacity;

    // 1. Identify Siblings (Same Product)
    // Priority: Barcode match. Fallback: Name match.
    final bc = realBattery.barcode.trim();
    final nameKey =
        '${removeDiacritics(realBattery.brand.trim().toLowerCase())}|${removeDiacritics(realBattery.model.trim().toLowerCase())}';

    final siblings = _batteries.where((b) {
      if (b.id == realBattery.id) return false;

      // Match by Barcode
      if (bc.isNotEmpty && b.barcode.trim() == bc) return true;

      // Fallback: Match by Name if barcode missing on either side
      if (bc.isEmpty || b.barcode.trim().isEmpty) {
        final k =
            '${removeDiacritics(b.brand.trim().toLowerCase())}|${removeDiacritics(b.model.trim().toLowerCase())}';
        return k == nameKey;
      }

      return false;
    }).toList();

    // 2. Calculate Total Available Stock across all siblings + self
    int totalStock = realBattery.quantity;
    for (var s in siblings) {
      totalStock += s.quantity;
    }

    // Safety: Don't move more than we have in total stock
    final int safeAmount = (amount > totalStock) ? totalStock : amount;
    if (safeAmount <= 0) return;

    // 3. Update Gondola Count (Target)
    // We strictly update the target battery's gondola count.
    final newGondolaQty = (realBattery.gondolaQuantity + safeAmount).clamp(
      0,
      limit,
    );
    await _collection.doc(realBattery.id).update({
      'gondolaQuantity': newGondolaQty,
      'lastChanged': Timestamp.now(),
    });

    // Log IN Gondola (Restock)
    await logHistory(
      batteryId: realBattery.id,
      batteryName: realBattery.name,
      type: 'in',
      location: 'gondola',
      quantity: safeAmount,
      reason: 'restock',
      source: 'form',
    );

    // 4. Deduct Stock (Distributed)
    // First try to take from the target itself
    int remainingToDeduct = safeAmount;

    if (realBattery.quantity > 0) {
      final deduct = (realBattery.quantity >= remainingToDeduct)
          ? remainingToDeduct
          : realBattery.quantity;
      await _collection.doc(realBattery.id).update({
        'quantity': realBattery.quantity - deduct,
      });

      // Log OUT Stock (Restock)
      await logHistory(
        batteryId: realBattery.id,
        batteryName: realBattery.name,
        type: 'out',
        location: 'stock',
        quantity: deduct,
        reason: 'restock',
        source: 'form',
      );

      remainingToDeduct -= deduct;
    }

    // If still need to deduct, take from siblings (prioritize 'Stock' location ones)
    if (remainingToDeduct > 0) {
      // Sort siblings: 'Stock' location first, then others
      siblings.sort((a, b) {
        if (a.location == 'Estoque' && b.location != 'Estoque') return -1;
        if (a.location != 'Estoque' && b.location == 'Estoque') return 1;
        return 0;
      });

      for (var s in siblings) {
        if (remainingToDeduct <= 0) break;
        if (s.quantity > 0) {
          final deduct = (s.quantity >= remainingToDeduct)
              ? remainingToDeduct
              : s.quantity;
          await _collection.doc(s.id).update({'quantity': s.quantity - deduct});

          // Log OUT Stock (Restock from Sibling)
          await logHistory(
            batteryId: s.id,
            batteryName: s.name,
            type: 'out',
            location: 'stock',
            quantity: deduct,
            reason: 'restock',
            source: 'form',
          );

          remainingToDeduct -= deduct;
        }
      }
    }
  }
}

class AppStateProvider extends InheritedNotifier<AppState> {
  const AppStateProvider({
    super.key,
    required AppState super.notifier,
    required super.child,
  });
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateProvider>()!.notifier!;
}
