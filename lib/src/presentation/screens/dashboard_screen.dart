import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:bms/src/providers/battery_providers.dart';
import 'package:bms/src/providers/suggestion_providers.dart';
import 'package:bms/src/presentation/widgets/summary_cards.dart';
import 'package:bms/src/presentation/widgets/battery_list_item.dart';
import 'package:bms/src/presentation/screens/add_edit_battery_screen.dart';
import 'package:bms/src/presentation/screens/settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _exportToCsv(BuildContext context, WidgetRef ref) async {
    final batteries = ref.read(batteriesStreamProvider).value ?? [];
    if (batteries.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No inventory data to export.')),
      );
      return;
    }

    final List<String> header = [
      'ID',
      'Model',
      'Brand',
      'Type',
      'Quantity',
      'Pack Size',
      'Barcode',
      'Discontinued',
      'Location',
      'Gondola Capacity',
      'Gondola Name',
      'Image URL',
      'Created At',
      'Updated At',
      'Last Used',
    ];
    final List<List<dynamic>> rows = [header];

    for (final battery in batteries) {
      rows.add([
        battery.id,
        battery.model,
        battery.brand,
        battery.type ?? '',
        battery.quantity,
        battery.packSize,
        battery.barcode,
        battery.discontinued ?? false,
        battery.location != null ? battery.location!.name : '',
        battery.gondolaCapacity ?? '',
        battery.gondolaName ?? '',
        battery.imageUrl ?? '',
        battery.createdAt?.toIso8601String() ?? '',
        battery.updatedAt?.toIso8601String() ?? '',
        battery.lastUsed?.toIso8601String() ?? '',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvString);

    try {
      final now = DateTime.now();
      final path = await FileSaver.instance.saveFile(
        name: 'battery_inventory_${now.year}-${now.month}-${now.day}.csv',
        bytes: Uint8List.fromList(bytes),
        mimeType: MimeType.csv,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully exported to $path')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteriesAsync = ref.watch(batteriesStreamProvider);
    final itemsToRestock = ref.watch(internalRestockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Buddy Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: () => _exportToCsv(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: batteriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('An error occurred: $error')),
        data: (batteries) {
          final debugInfo = ref.watch(debugStockInfoProvider);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DEBUG INFO CARD
              Card(
                color: Colors.red.shade100,
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    debugInfo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              SummaryCards(batteries: batteries),
              if (itemsToRestock.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ExpansionTile(
                    title: Text(
                      'Internal Restock Suggestions (${itemsToRestock.length})',
                    ),
                    children: itemsToRestock
                        .map(
                          (b) => BatteryListItem(
                            battery: b,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (c) =>
                                    AddEditBatteryScreen(battery: b),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Full Inventory',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 0),
                  itemCount: batteries.length,
                  itemBuilder: (context, index) {
                    final battery = batteries[index];
                    return BatteryListItem(
                      battery: battery,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (c) =>
                              AddEditBatteryScreen(battery: battery),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (c) => const AddEditBatteryScreen())),
        tooltip: 'Add Battery',
        child: const Icon(Icons.add),
      ),
    );
  }
}
