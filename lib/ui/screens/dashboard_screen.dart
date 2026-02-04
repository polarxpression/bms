import 'package:flutter/material.dart';
import 'package:bms/core/models/battery.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/core/utils/search_query_parser.dart';
import 'package:bms/ui/screens/notifications_screen.dart';
import 'package:bms/ui/screens/history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _filterQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    var lowStock = state.lowStockBatteries;

    // Apply filter
    if (_filterQuery.isNotEmpty) {
      lowStock = lowStock
          .where((b) => SearchQueryParser.matches(b, _filterQuery))
          .toList();
    }

    const Color accentPink = Color(0xFFEC4899);
    const Color cardColor = Color(0xFF141414);
    const Color surfaceColor = Color(0xFF141414);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Histórico',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: Badge(
              label: state.unreadNotificationsCount > 0
                  ? Text('${state.unreadNotificationsCount}')
                  : null,
              isLabelVisible: state.unreadNotificationsCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;

          return RefreshIndicator(
            onRefresh: () => state.refreshData(),
            displacement: 20,
            color: accentPink,
            backgroundColor: cardColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          _statBox(
                            'Total em Estoque',
                            '${state.totalBatteries}',
                            accentPink,
                            cardColor,
                          ),
                          const SizedBox(width: 12),
                          _statBox(
                            'Sugestões',
                            '${state.lowStockBatteries.length}',
                            Colors.orangeAccent,
                            cardColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Filter Field
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _filterQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Filtrar sugestões...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFFEC4899),
                          ),
                          suffixIcon: _filterQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() => _filterQuery = '');
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEC4899),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (lowStock.isNotEmpty ||
                          (state.lowStockBatteries.isNotEmpty &&
                              _filterQuery.isNotEmpty)) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            'Reposição Sugerida',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),

                if (lowStock.isEmpty &&
                    (state.lowStockBatteries.isEmpty || _filterQuery.isEmpty))
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: Colors.green,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nenhuma reposição necessária',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (lowStock.isEmpty && _filterQuery.isNotEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Nenhum item encontrado para o filtro.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else if (isWide)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 350, // Reduced from 400
                            mainAxisExtent: 120, // Reduced from 140
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) => _RestockItem(
                          battery: lowStock[index],
                          cardColor: cardColor,
                        ),
                        childCount: lowStock.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) => _RestockItem(
                          battery: lowStock[index],
                          cardColor: cardColor,
                        ),
                        childCount: lowStock.length,
                      ),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statBox(String label, String val, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12), // Reduced padding
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12), // Slightly smaller radius
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              val,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ), // Reduced font size
          ],
        ),
      ),
    );
  }
}

class _RestockItem extends StatelessWidget {
  final Battery battery;
  final Color cardColor;
  const _RestockItem({required this.battery, required this.cardColor});

  void _showMapInfo(BuildContext context, Battery b, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Localização: ${b.name}'),
        content: FutureBuilder<List<Map<String, String>>>(
          future: state.findBatteryInMaps(b.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final maps = snapshot.data ?? [];
            if (maps.isEmpty) {
              return const Text(
                'Este item não está posicionado em nenhum mapa.',
              );
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: maps.length,
                itemBuilder: (ctx, idx) {
                  final m = maps[idx];
                  return ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      color: Colors.blueAccent,
                    ),
                    title: Text(m['name']!),
                    subtitle: Text(m['purpose']!),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      Navigator.pop(ctx); // Close dialog
                      await state.navigateToMapHighlight(m['id']!, b.id);

                      // Switch to the map tab.
                      // This depends on where we are. In DashboardScreen, we are in MainLayoutShell.
                      // We might need a global navigator or a way to change tabs.
                      // Since MainLayoutShell is the parent, we can try to find its state if we have a global key.
                      // Or just let the user know they should click the map tab?
                      // No, that's bad UX.
                      // Let's assume we can notify the shell.
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    // Effective Limit
    final int limit = battery.gondolaLimit > 0
        ? battery.gondolaLimit
        : state.defaultGondolaCapacity;

    // How many does the shelf need?
    final int needed = (limit - battery.gondolaQuantity).clamp(0, 9999);

    // How many can we actually give?
    final int canMove = needed > battery.quantity ? battery.quantity : needed;

    final bool isOutOfStock = battery.quantity == 0;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8), // Reduced margin
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true, // Compact mode
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ), // Reduced padding
        leading: Container(
          width: 36,
          height: 36, // Smaller icon container
          decoration: BoxDecoration(
            color: isOutOfStock
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isOutOfStock
                ? Icons.production_quantity_limits
                : Icons.battery_alert,
            color: isOutOfStock ? Colors.red : const Color(0xFFEC4899),
            size: 20, // Smaller icon
          ),
        ),
        title: Text(
          battery.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ), // Refined text
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${battery.type} • Pack x${battery.packSize} • ${battery.location.isNotEmpty ? battery.location : "Sem Local"}',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Gôndola: ${battery.gondolaQuantity}/$limit',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                Text(
                  'Estoque: ${battery.quantity}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOutOfStock ? Colors.redAccent : Colors.white70,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.map,
                    size: 16,
                    color: Colors.blueAccent,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showMapInfo(context, battery, state),
                  tooltip: 'Ver nos Mapas',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.red.withValues(alpha: 0.2)
                        : const Color(0xFFEC4899).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Repor: $canMove',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOutOfStock
                          ? Colors.redAccent
                          : const Color(0xFFEC4899),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (battery.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                battery.notes,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: IconButton.filledTonal(
          onPressed: canMove > 0
              ? () => state.moveToGondola(battery, canMove)
              : null,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFEC4899).withValues(alpha: 0.1),
            foregroundColor: const Color(0xFFEC4899),
            disabledBackgroundColor: Colors.white10,
            disabledForegroundColor: Colors.grey,
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'Mover $canMove para Gôndola',
        ),
      ),
    );
  }
}
