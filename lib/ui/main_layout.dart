import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bms/core/models/battery.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/src/data/services/update_service.dart';
import 'package:bms/ui/screens/dashboard_screen.dart';
import 'package:bms/ui/screens/external_buy_screen.dart';
import 'package:bms/ui/screens/inventory_screen.dart';
import 'package:bms/ui/screens/settings_screen.dart';
import 'package:bms/ui/screens/battery_form_screen.dart';
import 'package:bms/ui/screens/table_map_screen.dart';

class MainLayoutShell extends StatefulWidget {
  const MainLayoutShell({super.key});
  @override
  State<MainLayoutShell> createState() => _MainLayoutShellState();
}

class _MainLayoutShellState extends State<MainLayoutShell> {
  int _currentIndex = 0;
  final _pages = const [
    DashboardScreen(),
    ExternalBuyScreen(),
    TableMapScreen(),
    InventoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final service = UpdateService();
    final info = await service.checkForUpdate();
    if (info != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Nova versão disponível: ${info.version}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Uma nova versão está disponível para download.'),
                const SizedBox(height: 8),
                const Text('Notas de lançamento:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(info.releaseNotes),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mais tarde'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                service.downloadAndInstall(info.downloadUrl);
              },
              child: const Text('Atualizar Agora'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _showForm(context),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (idx) =>
                        setState(() => _currentIndex = idx),
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        label: Text('Painel'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.shopping_cart_outlined),
                        label: Text('Comprar'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.map_outlined),
                        label: Text('Mapa'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        label: Text('Estoque'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        label: Text('Ajustes'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(child: _pages[_currentIndex]),
                ],
              ),
              floatingActionButton: _currentIndex == 3
                  ? FloatingActionButton(
                      onPressed: () => _showForm(context),
                      child: const Icon(Icons.add),
                    )
                  : null,
            );
          } else {
            return Scaffold(
              body: _pages[_currentIndex],
              bottomNavigationBar: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (idx) =>
                    setState(() => _currentIndex = idx),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    label: 'Painel',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.shopping_cart_outlined),
                    label: 'Comprar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    label: 'Mapa',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    label: 'Estoque',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: 'Ajustes',
                  ),
                ],
              ),
              floatingActionButton:
                  _currentIndex ==
                      3 // Inventory is now index 3
                  ? FloatingActionButton(
                      onPressed: () => _showForm(context),
                      child: const Icon(Icons.add),
                    )
                  : null,
            );
          }
        },
      ),
    );
  }

  void _showForm(BuildContext context, [Battery? b]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatteryFormScreen(batteryToEdit: b),
    );
  }
}
