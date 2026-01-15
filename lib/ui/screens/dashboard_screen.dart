import 'package:flutter/material.dart';
import 'package:bms/core/models/battery.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/core/utils/search_query_parser.dart';

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
      lowStock = lowStock.where((b) => SearchQueryParser.matches(b, _filterQuery)).toList();
    }

    const Color accentPink = Color(0xFFEC4899);
    const Color cardColor = Color(0xFF141414);
    const Color surfaceColor = Color(0xFF141414);

    return Scaffold(
      appBar: AppBar(title: const Text('Visão Geral')),
      body: RefreshIndicator(
        onRefresh: () => state.refreshData(),
        displacement: 20,
        color: accentPink,
        backgroundColor: cardColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _statBox('Total em Estoque', '${state.totalBatteries}', accentPink, cardColor),
                const SizedBox(width: 12),
                _statBox('Sugestões', '${state.lowStockBatteries.length}', Colors.orangeAccent, cardColor),
              ],
            ),
            const SizedBox(height: 28),
            
            // Filter Field
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _filterQuery = v),
              decoration: InputDecoration(
                hintText: 'Filtrar sugestões...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFEC4899)),
                suffixIcon: _filterQuery.isNotEmpty ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() => _filterQuery = '');
                    _searchController.clear();
                  },
                ) : null,
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEC4899), width: 1)),
              ),
            ),
            const SizedBox(height: 16),

            if (lowStock.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text('Reposição Sugerida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ...lowStock.map((b) => _RestockItem(battery: b, cardColor: cardColor)),
            ] else if (state.lowStockBatteries.isNotEmpty && _filterQuery.isNotEmpty)
               const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text('Nenhum item encontrado para o filtro.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                      SizedBox(height: 12),
                      Text('Nenhuma reposição necessária', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String val, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor, 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withOpacity(0.3))
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    
    // Effective Limit
    final int limit = battery.gondolaLimit > 0 ? battery.gondolaLimit : state.defaultGondolaCapacity;
    
    // How many does the shelf need?
    final int needed = (limit - battery.gondolaQuantity).clamp(0, 9999);
    
    // How many can we actually give?
    final int canMove = needed > battery.quantity ? battery.quantity : needed;
    
    final bool isOutOfStock = battery.quantity == 0;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isOutOfStock ? Colors.red.withOpacity(0.1) : Colors.white10, 
            borderRadius: BorderRadius.circular(8)
          ),
          child: Icon(
            isOutOfStock ? Icons.production_quantity_limits : Icons.battery_alert, 
            color: isOutOfStock ? Colors.red : const Color(0xFFEC4899)
          ),
        ),
        title: Text(battery.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${battery.type} • Pack x${battery.packSize} • ${battery.location.isNotEmpty ? battery.location : "Sem Local"}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Gôndola: ${battery.gondolaQuantity}/$limit', 
                     style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(width: 8),
                Text('Estoque: ${battery.quantity}', 
                     style: TextStyle(fontSize: 12, color: isOutOfStock ? Colors.redAccent : Colors.white70)),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOutOfStock ? Colors.red.withOpacity(0.2) : const Color(0xFFEC4899).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Repor: $canMove',
                style: TextStyle(
                  fontSize: 11, 
                  color: isOutOfStock ? Colors.redAccent : const Color(0xFFEC4899), 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton.filledTonal(
          onPressed: canMove > 0 
              ? () => state.moveToGondola(battery, canMove) 
              : null,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFEC4899).withOpacity(0.1),
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