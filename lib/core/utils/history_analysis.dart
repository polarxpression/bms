import 'package:bms/core/models/history_entry.dart';
import 'package:intl/intl.dart';

enum GroupingType { day, month, trimester, semester, year }

class GroupedEntry {
  final String label;
  final int ins;
  final int outs;
  final DateTime date;

  GroupedEntry({
    required this.label,
    required this.ins,
    required this.outs,
    required this.date,
  });
}

class HistoryAnalysis {
  static List<GroupedEntry> group(
    List<HistoryEntry> entries,
    GroupingType type,
  ) {
    // Sort by date
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final Map<String, _Aggregator> groups = {};

    for (var entry in entries) {
      String key;
      DateTime dateKey;

      switch (type) {
        case GroupingType.day:
          key = DateFormat('yyyy-MM-dd').format(entry.timestamp);
          dateKey = DateTime(
            entry.timestamp.year,
            entry.timestamp.month,
            entry.timestamp.day,
          );
          break;
        case GroupingType.month:
          key = DateFormat('yyyy-MM').format(entry.timestamp);
          dateKey = DateTime(entry.timestamp.year, entry.timestamp.month);
          break;
        case GroupingType.trimester:
          final trim = ((entry.timestamp.month - 1) / 3).floor() + 1;
          key = '${entry.timestamp.year}-T$trim';
          dateKey = DateTime(entry.timestamp.year, (trim - 1) * 3 + 1);
          break;
        case GroupingType.semester:
          final sem = entry.timestamp.month <= 6 ? 1 : 2;
          key = '${entry.timestamp.year}-S$sem';
          dateKey = DateTime(entry.timestamp.year, sem == 1 ? 1 : 7);
          break;
        case GroupingType.year:
          key = DateFormat('yyyy').format(entry.timestamp);
          dateKey = DateTime(entry.timestamp.year);
          break;
      }

      if (!groups.containsKey(key)) {
        groups[key] = _Aggregator(date: dateKey);
      }

      if (entry.type == 'in') {
        groups[key]!.ins += entry.quantity;
      } else {
        groups[key]!.outs += entry.quantity;
      }
    }

    // Convert map to list
    final results = groups.entries.map((e) {
      String label;
      switch (type) {
        case GroupingType.day:
          label = DateFormat('dd/MM/yyyy').format(e.value.date);
          break;
        case GroupingType.month:
          label = DateFormat('MMM yyyy', 'pt_BR').format(e.value.date);
          break;
        case GroupingType.trimester:
          final trim = e.key.split('-')[1];
          final year = e.key.split('-')[0];
          label = '${trim.replaceAll("T", "")}º Tri $year';
          break;
        case GroupingType.semester:
          final sem = e.key.split('-')[1];
          final year = e.key.split('-')[0];
          label = '${sem.replaceAll("S", "")}º Sem $year';
          break;
        case GroupingType.year:
          label = e.key;
          break;
      }

      return GroupedEntry(
        label: label,
        ins: e.value.ins,
        outs: e.value.outs,
        date: e.value.date,
      );
    }).toList();

    // Sort descending by date
    results.sort((a, b) => b.date.compareTo(a.date));

    return results;
  }
}

class _Aggregator {
  int ins = 0;
  int outs = 0;
  final DateTime date;
  _Aggregator({required this.date});
}
