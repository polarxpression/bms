import 'package:flutter/material.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/core/models/history_entry.dart';
import 'package:bms/core/utils/history_analysis.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  GroupingType _grouping = GroupingType.day;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
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
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<GroupingType>(
                    value: _grouping,
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
                    onChanged: (v) {
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

                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('Nenhum registro encontrado no período.'),
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
                                  color: Colors.grey.withOpacity(0.3),
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
