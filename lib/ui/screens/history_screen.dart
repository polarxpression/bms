import 'package:flutter/material.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/core/models/history_entry.dart';
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
  GroupingType _grouping = GroupingType.day;
  DateTimeRange? _dateRange;
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Movimentações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Selecionar Período',
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Bateria (Nome/EAN)',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<GroupingType>(
                        initialValue: _grouping,
                        dropdownColor: const Color(0xFF27272A),
                        decoration: const InputDecoration(
                          labelText: 'Agrupar por',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: GroupingType.day,
                            child: Text('Dia'),
                          ),
                          DropdownMenuItem(
                            value: GroupingType.month,
                            child: Text('Mês'),
                          ),
                          DropdownMenuItem(
                            value: GroupingType.trimester,
                            child: Text('Trimestre'),
                          ),
                          DropdownMenuItem(
                            value: GroupingType.semester,
                            child: Text('Semestre'),
                          ),
                          DropdownMenuItem(
                            value: GroupingType.year,
                            child: Text('Ano'),
                          ),
                        ],
                        onChanged: _searchQuery.isNotEmpty
                            ? null // Disable grouping when searching
                            : (v) {
                                if (v != null) setState(() => _grouping = v);
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDateRange,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Período',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _dateRange == null
                                ? 'Todo o Período'
                                : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erro ao carregar: ${snapshot.error}'),
                  );
                }

                List<HistoryEntry> entries = snapshot.data ?? [];

                // Filter by Search Query
                if (_searchQuery.isNotEmpty) {
                  // Find matching battery IDs first
                  final matchingIds = state.batteries
                      .where((b) => SearchQueryParser.matches(b, _searchQuery))
                      .map((b) => b.id)
                      .toSet();

                  entries = entries.where((e) {
                    return matchingIds.contains(e.batteryId) ||
                        e.batteryName
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                  }).toList();
                } else {
                  // Standard filter for global view
                  entries = entries.where((entry) {
                    // Requirement: "On the history, the out should only be counted if the battery is modified via the map"
                    if (entry.type == 'out' && entry.source != 'map') {
                      return false;
                    }
                    return true;
                  }).toList();
                }

                if (entries.isEmpty) {
                  return const Center(
                    child: Text('Nenhum registro encontrado.'),
                  );
                }

                // If searching, show detailed list. Else show grouped.
                if (_searchQuery.isNotEmpty) {
                  return ListView.builder(
                    itemCount: entries.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (ctx, idx) {
                      final entry = entries[idx];
                      final isIn = entry.type == 'in';
                      final isMap = entry.source == 'map';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isIn ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIn ? Colors.greenAccent : Colors.redAccent,
                          ),
                          title: Text(entry.batteryName),
                          subtitle: Text(
                            '${DateFormat('dd/MM/yyyy HH:mm').format(entry.timestamp)}\n'
                            '${entry.reason} • ${entry.location}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isMap) ...[
                                const Chip(
                                  label: Text(
                                    'MAPA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: Colors.blueAccent,
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                '${isIn ? '+' : '-'}${entry.quantity}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isIn
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                final grouped = HistoryAnalysis.group(entries, _grouping);

                return ListView.builder(
                  itemCount: grouped.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (ctx, idx) {
                    final group = grouped[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Entradas',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '+${group.ins}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Saídas',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '-${group.outs}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
              primary: Colors.blueAccent,
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
