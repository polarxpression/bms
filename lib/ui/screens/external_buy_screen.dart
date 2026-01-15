import 'package:flutter/material.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/core/utils/report_generator.dart';
import 'package:bms/core/models/battery.dart';

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
    final brands =
        allBuyList
            .map((b) => b.brand)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final types =
        allBuyList
            .map((b) => b.type)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

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
                : () => _showReportDialog(context, filteredList),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: Theme.of(
              context,
            ).appBarTheme.backgroundColor, // Blend with header
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBrand,
                    dropdownColor: const Color(0xFF27272A),
                    decoration: const InputDecoration(
                      labelText: 'Marca',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...brands.map(
                        (b) => DropdownMenuItem(value: b, child: Text(b)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedBrand = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    dropdownColor: const Color(0xFF27272A),
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...types.map(
                        (t) => DropdownMenuItem(value: t, child: Text(t)),
                      ),
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
                                allBuyList.isEmpty
                                    ? Icons.check_circle_outline
                                    : Icons.filter_list_off,
                                size: 48,
                                color: allBuyList.isEmpty
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                allBuyList.isEmpty
                                    ? 'Estoque abastecido!'
                                    : 'Nenhum item com os filtros selecionados.',
                                style: const TextStyle(color: Colors.grey),
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
                        final needed = (b.minStockThreshold - b.quantity).clamp(
                          0,
                          9999,
                        );
                        return Card(
                          color: const Color(0xFF141414),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
                                Icons.shopping_bag,
                                color: Colors.blueAccent,
                              ),
                            ),
                            title: Text(
                              b.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${b.brand} • ${b.type}'),
                                Text(
                                  'Estoque Atual: ${b.quantity} (Min: ${b.minStockThreshold})',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Comprar +$needed',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
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

  void _showReportDialog(BuildContext context, List<Battery> sourceBatteries) {
    final allTypes = sourceBatteries.map((b) => b.type).toSet().toList()
      ..sort();
    final allBrands = sourceBatteries.map((b) => b.brand).toSet().toList()
      ..sort();

    final selectedTypes = Set<String>.from(allTypes);
    final selectedBrands = Set<String>.from(allBrands);

    final multiplierController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return DefaultTabController(
            length: 2,
            child: AlertDialog(
              backgroundColor: const Color(0xFF141414),
              title: const Text(
                'Configurar Relatório',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400, // Fixed height for tabs
                child: Column(
                  children: [
                    TextField(
                      controller: multiplierController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Arredondar para múltiplos de',
                        helperText: 'Ex: 12 para dúzias',
                        prefixIcon: Icon(
                          Icons.numbers,
                          color: Colors.blueAccent,
                        ),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TabBar(
                      tabs: [
                        Tab(text: 'Marcas'),
                        Tab(text: 'Tipos'),
                      ],
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blueAccent,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Brands Tab
                          _buildSelectionList(
                            items: allBrands,
                            selected: selectedBrands,
                            onChanged: (newSet) => setState(() {
                              selectedBrands.clear();
                              selectedBrands.addAll(newSet);
                            }),
                          ),
                          // Types Tab
                          _buildSelectionList(
                            items: allTypes,
                            selected: selectedTypes,
                            onChanged: (newSet) => setState(() {
                              selectedTypes.clear();
                              selectedTypes.addAll(newSet);
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final finalBatteries = sourceBatteries
                        .where(
                          (b) =>
                              selectedTypes.contains(b.type) &&
                              selectedBrands.contains(b.brand),
                        )
                        .toList();

                    final multiplier = int.tryParse(multiplierController.text);

                    if (finalBatteries.isNotEmpty) {
                      ReportGenerator.generateBuyReport(
                        finalBatteries,
                        roundToMultiplesOf: multiplier,
                      );
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Selecione pelo menos uma marca e um tipo.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Gerar PDF'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionList({
    required List<String> items,
    required Set<String> selected,
    required Function(Set<String>) onChanged,
  }) {
    final areAllSelected = selected.length == items.length;
    final isPartial = selected.isNotEmpty && !areAllSelected;

    return Column(
      children: [
        CheckboxListTile(
          title: const Text(
            'Selecionar Todos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          value: areAllSelected ? true : (isPartial ? null : false),
          tristate: true,
          activeColor: Colors.blueAccent,
          checkColor: Colors.white,
          onChanged: (val) {
            if (val == true || (val == null && !areAllSelected)) {
              onChanged(Set.from(items));
            } else {
              onChanged({});
            }
          },
        ),
        const Divider(height: 1, color: Colors.white24),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              final isSelected = selected.contains(item);
              return CheckboxListTile(
                title: Text(item, style: const TextStyle(color: Colors.white)),
                value: isSelected,
                activeColor: Colors.blueAccent,
                checkColor: Colors.white,
                contentPadding: const EdgeInsets.only(left: 16, right: 8),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) {
                  final newSet = Set<String>.from(selected);
                  if (val == true) {
                    newSet.add(item);
                  } else {
                    newSet.remove(item);
                  }
                  onChanged(newSet);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
