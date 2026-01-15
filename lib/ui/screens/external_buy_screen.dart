import 'package:flutter/material.dart';
import 'package:bms/state/app_state.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';

class ExternalBuyScreen extends StatefulWidget {
  const ExternalBuyScreen({super.key});

  @override
  State<ExternalBuyScreen> createState() => _ExternalBuyScreenState();
}

class _ExternalBuyScreenState extends State<ExternalBuyScreen> {
  String? _selectedBrand;
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final allBuyList = state.externalBuyBatteries;

    // Extract available options
    final brands = allBuyList
        .map((b) => b.brand)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()..sort();
        
    final types = allBuyList
        .map((b) => b.type)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()..sort();

    // Validate selections
    if (_selectedBrand != null && !brands.contains(_selectedBrand)) {
      _selectedBrand = null;
    }
    if (_selectedType != null && !types.contains(_selectedType)) {
      _selectedType = null;
    }

    // Apply Filters
    final filteredList = allBuyList.where((b) {
      if (_selectedBrand != null && b.brand != _selectedBrand) return false;
      if (_selectedType != null && b.type != _selectedType) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprar (Reposição Externa)'),
        actions: [
          IconButton(
            tooltip: 'Gerar Relatório (PDF)',
            icon: const Icon(Icons.print),
            onPressed: filteredList.isEmpty 
                ? null 
                : () => ReportGenerator.generateBuyReport(filteredList),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: Theme.of(context).appBarTheme.backgroundColor, // Blend with header
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBrand,
                    dropdownColor: const Color(0xFF27272A),
                    decoration: const InputDecoration(
                      labelText: 'Marca',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...brands.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                    ],
                    onChanged: (v) => setState(() => _selectedBrand = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    dropdownColor: const Color(0xFF27272A),
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...types.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => state.refreshData(),
              color: Colors.blueAccent,
              backgroundColor: const Color(0xFF141414),
              child: filteredList.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 300,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                allBuyList.isEmpty ? Icons.check_circle_outline : Icons.filter_list_off,
                                size: 48, 
                                color: allBuyList.isEmpty ? Colors.green : Colors.grey
                              ),
                              const SizedBox(height: 12),
                              Text(
                                allBuyList.isEmpty ? 'Estoque abastecido!' : 'Nenhum item com os filtros selecionados.',
                                style: const TextStyle(color: Colors.grey)
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      itemBuilder: (ctx, idx) {
                        final b = filteredList[idx];
                        final needed = (b.minStockThreshold - b.quantity).clamp(0, 9999);
                        return Card(
                          color: const Color(0xFF141414),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent.withOpacity(0.2),
                              child: const Icon(Icons.shopping_bag, color: Colors.blueAccent),
                            ),
                            title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${b.brand} • ${b.type}'),
                                Text(
                                  'Estoque Atual: ${b.quantity} (Min: ${b.minStockThreshold})',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Comprar +$needed',
                                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
