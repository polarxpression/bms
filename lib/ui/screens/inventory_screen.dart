import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bms/core/models/battery.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/core/utils/search_query_parser.dart';
import 'package:bms/ui/screens/battery_form_screen.dart';

enum SortOption { name, brand, type, stockQty, gondolaQty }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _query = '';
  SortOption _sortOption = SortOption.name;
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }

      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _deleteSelected(AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir ${_selectedIds.length} item(ns)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (var id in _selectedIds) {
        await state.deleteBattery(id);
      }
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
    }
  }

  Future<void> _cloneSelected(AppState state) async {
    if (_selectedIds.length != 1) return;

    final id = _selectedIds.first;
    final original = state.batteries.firstWhere((b) => b.id == id);

    final copy = Battery(
      id: '', // New ID will be generated
      name: original.name,
      type: original.type,
      brand: original.brand,
      model: original.model,
      barcode: original.barcode,
      imageUrl: original.imageUrl,
      quantity: original.quantity,
      location: original.location,
      lowStockThreshold: original.lowStockThreshold,
      minStockThreshold: original.minStockThreshold,
      purchaseDate: DateTime.now(),
      lastChanged: DateTime.now(),
      voltage: original.voltage,
      chemistry: original.chemistry,
      notes: original.notes,
      gondolaLimit: original.gondolaLimit,
      packSize: original.packSize,
      gondolaQuantity: 0,
    );

    await state.addBattery(copy);

    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item clonado com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    const Color surfaceColor = Color(0xFF141414);

    // Filter
    final filtered = state.batteries
        .where((b) => SearchQueryParser.matches(b, _query))
        .toList();

    // Sort logic
    filtered.sort((a, b) {
      int cmp;
      switch (_sortOption) {
        case SortOption.brand:
          cmp = a.brand.compareTo(b.brand);
          if (cmp == 0) cmp = a.model.compareTo(b.model);
          break;
        case SortOption.type:
          cmp = a.type.compareTo(b.type);
          break;
        case SortOption.stockQty:
          cmp = a.quantity.compareTo(b.quantity);
          break;
        case SortOption.gondolaQty:
          cmp = a.gondolaQuantity.compareTo(b.gondolaQuantity);
          break;
        case SortOption.name:
          cmp = a.name.compareTo(b.name);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Scaffold(
        appBar: _isSelectionMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectedIds.clear();
                    _isSelectionMode = false;
                  }),
                ),
                title: Text('${_selectedIds.length} selecionado(s)'),
                backgroundColor: Colors.grey[900],
                actions: [
                  if (_selectedIds.length == 1)
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Clonar',
                      onPressed: () => _cloneSelected(state),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Excluir',
                    onPressed: () => _deleteSelected(state),
                  ),
                ],
              )
            : AppBar(
                title: const Text('Inventário'),
                actions: [
                  if (MediaQuery.of(context).size.width <=
                      900) // Only show sort menu on mobile
                    PopupMenuButton<SortOption>(
                      icon: const Icon(Icons.sort, color: Colors.grey),
                      tooltip: 'Ordenar',
                      onSelected: (SortOption result) {
                        if (_sortOption == result) {
                          setState(() => _sortAscending = !_sortAscending);
                        } else {
                          setState(() {
                            _sortOption = result;
                            _sortAscending = true;
                          });
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<SortOption>>[
                            _buildSortItem(SortOption.name, 'Nome'),
                            _buildSortItem(SortOption.brand, 'Marca'),
                            _buildSortItem(SortOption.type, 'Tipo'),
                            _buildSortItem(SortOption.stockQty, 'Qtd. Estoque'),
                            _buildSortItem(
                              SortOption.gondolaQty,
                              'Qtd. Gôndola',
                            ),
                          ],
                    ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.grey),
                    tooltip: 'Sintaxe de Busca',
                    onPressed: () => _showSearchHelp(context),
                  ),
                ],
              ),
        body: Column(
          children: [
            if (!_isSelectionMode)
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Procurar baterias... (Ctrl+F)',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFEC4899),
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() => _query = '');
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
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey[800],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum resultado para "$_query"',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 900) {
                          return _buildDataTable(filtered, state);
                        } else {
                          return RefreshIndicator(
                            onRefresh: () => state.refreshData(),
                            color: const Color(0xFFEC4899),
                            backgroundColor: surfaceColor,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Colors.white10,
                                height: 1,
                              ),
                              itemBuilder: (ctx, idx) =>
                                  _buildListItem(filtered[idx], state),
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(List<Battery> batteries, AppState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _getSortColumnIndex(),
          sortAscending: _sortAscending,
          headingRowColor: WidgetStateProperty.all(Colors.white10),
          columns: [
            const DataColumn(label: Text('Status')),
            DataColumn(
              label: const Text('Nome'),
              onSort: (idx, asc) => _handleSort(SortOption.name, asc),
            ),
            const DataColumn(label: Text('Código de Barras')),
            DataColumn(
              label: const Text('Marca'),
              onSort: (idx, asc) => _handleSort(SortOption.brand, asc),
            ),
            DataColumn(
              label: const Text('Tipo'),
              onSort: (idx, asc) => _handleSort(SortOption.type, asc),
            ),
            const DataColumn(label: Text('Local')),
            DataColumn(
              label: const Text('Gôndola'),
              onSort: (idx, asc) => _handleSort(SortOption.gondolaQty, asc),
            ),
            DataColumn(
              label: const Text('Estoque'),
              onSort: (idx, asc) => _handleSort(SortOption.stockQty, asc),
            ),
            const DataColumn(label: Text('Ações')),
          ],
          rows: batteries.map((b) {
            final hasExpiry = b.expiryDate != null;
            final isExpired =
                hasExpiry && b.expiryDate!.isBefore(DateTime.now());
            final isSelected = _selectedIds.contains(b.id);
            final isGondola =
                b.location.toLowerCase().contains('gondola') ||
                b.location.toLowerCase().contains('gôndola');

            return DataRow(
              selected: isSelected,
              onSelectChanged: (selected) {
                if (selected != null) _toggleSelection(b.id);
              },
              cells: [
                DataCell(
                  Icon(
                    Icons.battery_full,
                    color: isExpired ? Colors.red : const Color(0xFFEC4899),
                  ),
                ),
                DataCell(
                  Text(
                    b.name,
                    style: TextStyle(
                      decoration: isExpired ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    b.barcode.isNotEmpty ? b.barcode : '-',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
                DataCell(Text(b.brand)),
                DataCell(Text(b.type)),
                DataCell(Text(b.location.isNotEmpty ? b.location : '-')),
                DataCell(Text('${b.gondolaQuantity}/${b.gondolaLimit}')),
                DataCell(Text('${b.quantity}')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEdit(context, b),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          size: 20,
                          color: Colors.white38,
                        ),
                        onPressed: () => isGondola
                            ? state.adjustGondolaQuantity(b, -1)
                            : state.adjustQuantity(b, -1),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: Color(0xFFEC4899),
                        ),
                        onPressed: () => isGondola
                            ? state.adjustGondolaQuantity(b, 1)
                            : state.adjustQuantity(b, 1),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildListItem(Battery b, AppState state) {
    final hasExpiry = b.expiryDate != null;
    final isExpired = hasExpiry && b.expiryDate!.isBefore(DateTime.now());
    final isSelected = _selectedIds.contains(b.id);
    final isGondola =
        b.location.toLowerCase().contains('gondola') ||
        b.location.toLowerCase().contains('gôndola');
    final sharedStock = isGondola ? state.getStockForBattery(b) : 0;

    return ListTile(
      selected: isSelected,
      selectedTileColor: Colors.blueAccent.withValues(alpha: 0.2),
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _toggleSelection(b.id);
        });
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(b.id);
        } else {
          _showEdit(context, b);
        }
      },
      leading: _isSelectionMode
          ? Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blueAccent : Colors.grey,
            )
          : CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(
                Icons.battery_full,
                color: isExpired ? Colors.red : const Color(0xFFEC4899),
              ),
            ),
      title: Text(
        b.name,
        style: TextStyle(
          decoration: isExpired ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${b.brand} • ${b.type} • Pack x${b.packSize} ${b.voltage.isNotEmpty ? '• ${b.voltage}' : ''}',
          ),
          if (b.barcode.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, size: 10, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    b.barcode,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(Icons.location_on, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                b.location.isNotEmpty ? b.location : "Sem Local Definido",
                style: TextStyle(
                  fontSize: 12,
                  color: isGondola ? Colors.amberAccent : Colors.white70,
                ),
              ),
            ],
          ),
          if (isGondola)
            Text(
              'Gôndola: ${b.gondolaQuantity}/${b.gondolaLimit} • Estoque Total: $sharedStock',
              style: const TextStyle(fontSize: 11, color: Color(0xFFEC4899)),
            )
          else if (b.gondolaLimit > 0)
            // Fallback for non-gondola items that might have limit set (unlikely but safe)
            Text(
              'Meta Gôndola: ${b.gondolaLimit}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFEC4899)),
            ),
          if (b.notes.isNotEmpty)
            Text(
              b.notes,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: _isSelectionMode
          ? null // Hide controls in selection mode
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white38,
                  ),
                  onPressed: () => isGondola
                      ? state.adjustGondolaQuantity(b, -1)
                      : state.adjustQuantity(b, -1),
                ),
                Text(
                  isGondola ? '${b.gondolaQuantity}' : '${b.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFFEC4899),
                  ),
                  onPressed: () => isGondola
                      ? state.adjustGondolaQuantity(b, 1)
                      : state.adjustQuantity(b, 1),
                ),
                IconButton(
                  icon: const Icon(Icons.map, color: Colors.blueAccent),
                  tooltip: 'Ver nos Mapas',
                  onPressed: () => _showMapInfo(context, b, state),
                ),
              ],
            ),
    );
  }

  int? _getSortColumnIndex() {
    switch (_sortOption) {
      case SortOption.name:
        return 1;
      case SortOption.brand:
        return 2;
      case SortOption.type:
        return 3;
      case SortOption.gondolaQty:
        return 5;
      case SortOption.stockQty:
        return 6;
      // default:
      //   return null;
    }
  }

  void _handleSort(SortOption option, bool ascending) {
    setState(() {
      _sortOption = option;
      _sortAscending = ascending;
    });
  }

  void _showMapInfo(BuildContext context, Battery b, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Localização: ${b.name}'),
        content: FutureBuilder<List<String>>(
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
                itemBuilder: (ctx, idx) => ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: Colors.blueAccent,
                  ),
                  title: Text(maps[idx]),
                ),
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

  PopupMenuItem<SortOption> _buildSortItem(SortOption value, String label) {
    final isSelected = _sortOption == value;
    return PopupMenuItem<SortOption>(
      value: value,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFEC4899) : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: const Color(0xFFEC4899),
            ),
          ],
        ],
      ),
    );
  }

  void _showEdit(BuildContext context, Battery b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatteryFormScreen(batteryToEdit: b),
    );
  }

  void _showSearchHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Guia de Busca Avançada',
          style: TextStyle(color: Color(0xFFEC4899)),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HelpItem(
                title: 'Termos Simples',
                ex: 'duracell pilha',
                desc: 'Busca itens que contenham "duracell" E "pilha".',
              ),
              _HelpItem(
                title: 'Exclusão (-)',
                ex: '-alcalina',
                desc: 'Remove resultados que contenham "alcalina".',
              ),
              _HelpItem(
                title: 'Grupos (OR)',
                ex: '(AA ~ AAA)',
                desc: 'Encontra itens que sejam AA OU AAA. Use ~ para separar.',
              ),
              _HelpItem(
                title: 'Curinga (*)',
                ex: 'lit*o',
                desc: 'Encontra "lítio", "litio", etc.',
              ),
              _HelpItem(
                title: 'Metadados (:)',
                ex: 'estoque:>10 gondola:<5',
                desc:
                    'Filtra campos específicos.\nCampos: estoque/stock, gondola/gôndola, limit, brand, model, type, barcode/ean, loc, volt, chem, notes.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String title, ex, desc;
  const _HelpItem({required this.title, required this.ex, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ex,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.orangeAccent,
              ),
            ),
          ),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
