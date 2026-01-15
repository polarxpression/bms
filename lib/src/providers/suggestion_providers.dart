import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bms/src/data/models/battery.dart';
import 'package:bms/src/providers/battery_providers.dart';
import 'package:bms/src/providers/app_settings_provider.dart';

final debugStockInfoProvider = Provider<String>((ref) {
  final batteriesAsync = ref.watch(batteriesStreamProvider);
  final batteries = batteriesAsync.value ?? [];

  final gondola = batteries
      .where((b) => b.location == BatteryLocation.gondola)
      .length;
  final stock = batteries
      .where((b) => b.location == BatteryLocation.stock)
      .length;
  final unknown = batteries.where((b) => b.location == null).length;

  final stockBarcodes = batteries
      .where((b) => b.location == BatteryLocation.stock && b.quantity > 0)
      .map((b) => b.barcode.trim())
      .toSet();

  return 'DEBUG INFO:\nTotal: ${batteries.length}\nGondola: $gondola\nStock: $stock\nUnknown: $unknown\nUnique Stock Barcodes: ${stockBarcodes.length}';
});

/// Provides a list of batteries from stock that should be moved to the gondola.
final internalRestockProvider = Provider<List<Battery>>((ref) {
  // Watch the main batteries list and the app settings
  final batteriesAsync = ref.watch(batteriesStreamProvider);
  final settingsAsync = ref.watch(appSettingsProvider);

  // Get the current data or a default/empty state
  final batteries = batteriesAsync.value ?? [];
  final settings = settingsAsync.value;

  debugPrint('DEBUG: Total batteries fetched: ${batteries.length}');

  final gondolaBatteries = batteries
      .where((b) => b.location == BatteryLocation.gondola)
      .toList();
  // Assuming anything NOT gondola is potential stock, or explicitly check for stock.
  // Note: Current logic only takes explicit BatteryLocation.stock.
  // If "Estoque" items have null location, they might be missed here.
  final stockBatteries = batteries
      .where((b) => b.location == BatteryLocation.stock)
      .toList();

  final unknownLocationBatteries = batteries
      .where((b) => b.location == null)
      .toList();

  debugPrint('DEBUG: Gondola items: ${gondolaBatteries.length}');
  debugPrint('DEBUG: Stock items (explicit): ${stockBatteries.length}');
  debugPrint(
    'DEBUG: Unknown location items: ${unknownLocationBatteries.length}',
  );

  // Create a set of barcodes for items currently in stock with quantity > 0
  final stockBarcodes = stockBatteries
      .where((b) => b.quantity > 0 && b.barcode.trim().isNotEmpty)
      .map((b) => b.barcode.trim())
      .toSet();

  debugPrint('DEBUG: Unique Stock Barcodes available: ${stockBarcodes.length}');
  if (stockBarcodes.isNotEmpty) {
    debugPrint('DEBUG: Sample Stock Barcode: ${stockBarcodes.first}');
  }

  final List<Battery> itemsToRestock = [];

  for (final battery in gondolaBatteries) {
    // Determine the capacity, using the item's specific capacity,
    // or falling back to the global app setting, or a final default.
    final limit = battery.gondolaCapacity ?? settings?.gondolaCapacity ?? 20;

    // Check if quantity is equal or below half of the limit
    if (battery.quantity <= (limit / 2)) {
      final barcode = battery.barcode.trim();
      // Check if available in stock by barcode
      if (barcode.isNotEmpty && stockBarcodes.contains(barcode)) {
        debugPrint(
          'DEBUG: SUGGESTION FOUND -> ${battery.brand} ${battery.model} (Barcode: $barcode) [Gondola Qty: ${battery.quantity}, Limit: $limit]',
        );
        itemsToRestock.add(battery);
      } else {
        debugPrint(
          'DEBUG: Needs restock but NO STOCK -> ${battery.brand} ${battery.model} (Barcode: $barcode) [Gondola Qty: ${battery.quantity}, Limit: $limit]',
        );
      }
    }
  }

  debugPrint('DEBUG: Total Suggestions returned: ${itemsToRestock.length}');

  return itemsToRestock;
});
