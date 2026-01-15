import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bms/src/providers/app_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Shows a dialog to edit the gondola capacity.
  void _showEditGondolaCapacityDialog(
      BuildContext context, WidgetRef ref, int currentCapacity) {
    final controller = TextEditingController(text: currentCapacity.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Gondola Capacity'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Capacity'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newCapacity = int.tryParse(controller.text);
                if (newCapacity != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .updateGondolaCapacity(newCapacity);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (appSettings) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Show Discontinued Batteries'),
                subtitle:
                    const Text('If enabled, discontinued items will appear in lists.'),
                value: appSettings.showDiscontinuedBatteries,
                onChanged: (newValue) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .toggleShowDiscontinued(newValue);
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Default Gondola Capacity'),
                subtitle: Text(
                    'Default max quantity for items in the "gondola" location.'),
                trailing: Text(
                  '${appSettings.gondolaCapacity}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                onTap: () => _showEditGondolaCapacityDialog(
                    context, ref, appSettings.gondolaCapacity),
              ),
              const Divider(),
            ],
          );
        },
      ),
    );
  }
}
