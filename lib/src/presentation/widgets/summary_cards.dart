import 'package:flutter/material.dart';
import 'package:bms/src/data/models/battery.dart';

/// A widget that displays summary statistics for the battery inventory.
class SummaryCards extends StatelessWidget {
  final List<Battery> batteries;

  const SummaryCards({super.key, required this.batteries});

  @override
  Widget build(BuildContext context) {
    // Calculate the statistics from the list of batteries.
    // Using fold for safe summation of num types.
    final totalQuantity = batteries.fold<num>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final gondolaQuantity = batteries
        .where((b) => b.location == BatteryLocation.gondola)
        .fold<num>(0, (sum, item) => sum + item.quantity);
    final stockQuantity = batteries
        .where((b) => b.location == BatteryLocation.stock)
        .fold<num>(0, (sum, item) => sum + item.quantity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCard(context, 'Total', totalQuantity.toStringAsFixed(0)),
          _buildCard(context, 'Gondola', gondolaQuantity.toStringAsFixed(0)),
          _buildCard(context, 'Stock', stockQuantity.toStringAsFixed(0)),
        ],
      ),
    );
  }

  /// Helper method to build a single card.
  Widget _buildCard(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 2.0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
