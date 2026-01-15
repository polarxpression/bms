import 'package:flutter/material.dart';
import 'package:bms/src/data/models/battery.dart';
import 'package:flutter/foundation.dart';

class BatteryListItem extends StatelessWidget {
  final Battery battery;
  final VoidCallback onTap;

  const BatteryListItem({
    super.key,
    required this.battery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationText = battery.location != null
        ? describeEnum(battery.location!)
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 2.0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          battery.model,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Brand: ${battery.brand}\nBarcode: ${battery.barcode}',
          style: theme.textTheme.bodyMedium,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Qty: ${battery.quantity.toStringAsFixed(0)}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(locationText),
              padding: EdgeInsets.zero,
              labelStyle: theme.textTheme.labelSmall,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
