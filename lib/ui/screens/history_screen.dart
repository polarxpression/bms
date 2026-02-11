import 'package:flutter/material.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/core/models/history_entry.dart';
import 'package:bms/core/models/battery.dart';
import 'package:bms/core/utils/history_analysis.dart';
import 'package:bms/core/utils/search_query_parser.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  final String? initialQuery;
  const HistoryScreen({super.key, this.initialQuery});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  GroupingType _topLevelGrouping = GroupingType.brand;
  DateTimeRange? _dateRange;
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _searchQuery = widget.initialQuery ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    const accentColor = Color(0xFFEC4899);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        title: const Text(
          'HISTÓRICO',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Unified Filter Panel (Matching Web)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Filtrar histórico (Bateria, Marca, Motivo...)',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.4),
                    prefixIcon: Icon(Icons.search, color: _searchQuery.isNotEmpty ? accentColor : Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: accentColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Grouping Selector
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            ' ORGANIZAR POR',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<GroupingType>(
                            initialValue: _topLevelGrouping,
                            dropdownColor: const Color(0xFF141414),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: GroupingType.model,
                                child: Text('Bateria (Modelo)', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: GroupingType.brand,
                                child: Text('Marca', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _topLevelGrouping = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Picker
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            ' PERÍODO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _pickDateRange,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_note, size: 16, color: accentColor.withValues(alpha: 0.7)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _dateRange == null
                                          ? 'Sempre'
                                          : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search indicator matching web
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      'MOSTRANDO RESULTADOS PARA "$_searchQuery"',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: FutureBuilder<List<HistoryEntry>>(
              future: state.fetchHistory(
                start: _dateRange?.start,
                end: _dateRange?.end,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: accentColor),
                  );
                }

                List<HistoryEntry> entries = snapshot.data ?? [];

                // Unified Filtering Logic
                final filtered = entries.where((entry) {
                  if (_searchQuery.isNotEmpty) {
                    final battery = state.batteries.firstWhere(
                      (b) => b.id == entry.batteryId,
                      orElse: () => Battery(
                        id: entry.batteryId,
                        name: entry.batteryName,
                        type: '',
                        brand: '',
                        model: '',
                        barcode: '',
                        quantity: 0,
                        purchaseDate: DateTime.now(),
                        lastChanged: DateTime.now(),
                      ),
                    );

                    final searchableMap = {
                      'batteryName': entry.batteryName,
                      'brand': battery.brand,
                      'model': battery.model,
                      'type': battery.type,
                      'barcode': battery.barcode,
                      'reason': entry.reason,
                      'source': entry.source,
                      'location': entry.location,
                      'movement': entry.type == 'in' ? 'Entrada' : 'Saída',
                    };

                    if (!SearchQueryParser.matches(searchableMap, _searchQuery)) {
                      return false;
                    }
                  } else {
                    // "On the history, the out should only be counted if the battery is modified via the map"
                    if (entry.type == 'out' && entry.source != 'map') {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 64, color: Colors.white.withValues(alpha: 0.05)),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhum registro encontrado.',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                }

                final hierarchy = HistoryAnalysis.buildHierarchy(
                  filtered,
                  state.batteries,
                  _topLevelGrouping,
                );

                return ListView.builder(
                  itemCount: hierarchy.length,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemBuilder: (ctx, idx) {
                    return GroupNode(
                      group: hierarchy[idx],
                      level: 0,
                      batteries: state.batteries,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _searchQuery.isNotEmpty || _dateRange != null
          ? FloatingActionButton.extended(
              onPressed: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
                _dateRange = null;
              }),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              elevation: 0,
              label: const Text('LIMPAR FILTROS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
              icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
            )
          : null,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFEC4899),
              onPrimary: Colors.white,
              surface: Color(0xFF141414),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }
}

class GroupNode extends StatefulWidget {
  final HierarchicalGroup group;
  final int level;
  final List<Battery> batteries;

  const GroupNode({
    super.key,
    required this.group,
    required this.level,
    required this.batteries,
  });

  @override
  State<GroupNode> createState() => _GroupNodeState();
}

class _GroupNodeState extends State<GroupNode> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.level == 0 && widget.group.subgroups.length == 1;
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFEC4899);
    final group = widget.group;
    final hasSubgroups = group.subgroups.isNotEmpty;

    return Container(
      margin: widget.level == 0 
          ? const EdgeInsets.only(bottom: 16)
          : const EdgeInsets.only(left: 12, top: 8),
      decoration: BoxDecoration(
        color: widget.level == 0 ? const Color(0xFF141414) : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(widget.level == 0 ? 32 : 16),
        border: Border.all(
          color: widget.level == 0 
              ? Colors.white.withValues(alpha: 0.05)
              : accentColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(widget.level == 0 ? 32 : 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getGroupColor(group.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getGroupIcon(group.type),
                      color: _getGroupColor(group.type),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Labels
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: widget.level == 0 ? 16 : 14,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (widget.level == 0 && group.battery != null && group.type == GroupingType.model)
                          Text(
                            '${group.battery!.brand} • ${group.battery!.type} • ESTOQUE: ${group.battery!.quantity}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Totals
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TotalBadge(count: group.ins, isPositive: true),
                        const SizedBox(width: 4),
                        _TotalBadge(count: group.outs, isPositive: false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: _isExpanded ? accentColor : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: hasSubgroups
                  ? Column(
                      children: group.subgroups
                          .map((sub) => GroupNode(
                                group: sub,
                                level: widget.level + 1,
                                batteries: widget.batteries,
                              ))
                          .toList(),
                    )
                  : _HistoryList(entries: group.entries, batteries: widget.batteries),
            ),
        ],
      ),
    );
  }

  IconData _getGroupIcon(GroupingType type) {
    switch (type) {
      case GroupingType.model: return Icons.battery_charging_full;
      case GroupingType.brand: return Icons.branding_watermark;
      case GroupingType.year: return Icons.event;
      case GroupingType.month: return Icons.calendar_view_month;
    }
  }

  Color _getGroupColor(GroupingType type) {
    switch (type) {
      case GroupingType.model: return const Color(0xFFEC4899);
      case GroupingType.brand: return Colors.blueAccent;
      case GroupingType.year: return Colors.purpleAccent;
      case GroupingType.month: return Colors.amberAccent;
    }
  }
}

class _TotalBadge extends StatelessWidget {
  final int count;
  final bool isPositive;
  const _TotalBadge({required this.count, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? Colors.greenAccent : Colors.redAccent;
    return Column(
      children: [
        Text(
          isPositive ? 'INS' : 'OUTS',
          style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: color.withValues(alpha: 0.6)),
        ),
        Text(
          '${isPositive ? '+' : '-'}$count',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<HistoryEntry> entries;
  final List<Battery> batteries;

  const _HistoryList({required this.entries, required this.batteries});

  @override
  Widget build(BuildContext context) {
    final sorted = List<HistoryEntry>.from(entries);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sorted.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
        itemBuilder: (context, index) {
          final entry = sorted[index];
          final isIn = entry.type == 'in';
          final battery = batteries.firstWhere((b) => b.id == entry.batteryId, orElse: () => batteries.first);

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Type & Date
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd/MM HH:mm').format(entry.timestamp),
                        style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.batteryName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              battery.type.toUpperCase(),
                              style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _translateReason(entry.reason),
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Location & Source
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.location.toUpperCase(),
                          style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.source.toUpperCase(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 8, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                // Quantity
                SizedBox(
                  width: 50,
                  child: Text(
                    '${isIn ? '+' : '-'}${entry.quantity}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isIn ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _translateReason(String reason) {
    const map = {
      'adjustment': 'Ajuste Manual',
      'restock': 'Reposição',
      'sale': 'Venda/Saída',
      'external_buy': 'Compra Externa'
    };
    return map[reason.toLowerCase()] ?? reason.replaceAll('_', ' ');
  }
}

