import type { HistoryEntry } from "../types";

export type GroupingType = 'day' | 'month' | 'trimester' | 'semester' | 'year';

export interface GroupedEntry {
  label: string;
  ins: number;
  outs: number;
  date: Date;
}

export class HistoryAnalysis {
  static group(entries: HistoryEntry[], type: GroupingType): GroupedEntry[] {
    // Sort by date asc
    const sorted = [...entries].sort((a, b) => {
        const dateA = a.timestamp?.toDate ? a.timestamp.toDate() : new Date(a.timestamp);
        const dateB = b.timestamp?.toDate ? b.timestamp.toDate() : new Date(b.timestamp);
        return dateA.getTime() - dateB.getTime();
    });

    const groups: Record<string, { ins: number; outs: number; date: Date }> = {};

    sorted.forEach(entry => {
      const ts = entry.timestamp?.toDate ? entry.timestamp.toDate() : new Date(entry.timestamp);
      let key = "";
      let dateKey = new Date();

      switch (type) {
        case 'day':
          key = ts.toISOString().split('T')[0];
          dateKey = new Date(ts.getFullYear(), ts.getMonth(), ts.getDate());
          break;
        case 'month':
          key = `${ts.getFullYear()}-${String(ts.getMonth() + 1).padStart(2, '0')}`;
          dateKey = new Date(ts.getFullYear(), ts.getMonth(), 1);
          break;
        case 'trimester':
          const trim = Math.floor(ts.getMonth() / 3) + 1;
          key = `${ts.getFullYear()}-T${trim}`;
          dateKey = new Date(ts.getFullYear(), (trim - 1) * 3, 1);
          break;
        case 'semester':
          const sem = ts.getMonth() < 6 ? 1 : 2;
          key = `${ts.getFullYear()}-S${sem}`;
          dateKey = new Date(ts.getFullYear(), sem === 1 ? 0 : 6, 1);
          break;
        case 'year':
          key = `${ts.getFullYear()}`;
          dateKey = new Date(ts.getFullYear(), 0, 1);
          break;
      }

      if (!groups[key]) {
        groups[key] = { ins: 0, outs: 0, date: dateKey };
      }

      if (entry.type === 'in') {
        groups[key].ins += entry.quantity;
      } else {
        groups[key].outs += entry.quantity;
      }
    });

    const results = Object.entries(groups).map(([key, value]) => {
      let label = "";
      switch (type) {
        case 'day':
          label = value.date.toLocaleDateString('pt-BR');
          break;
        case 'month':
          label = value.date.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
          break;
        case 'trimester':
          const tYear = key.split('-')[0];
          const tNum = key.split('-')[1].replace('T', '');
          label = `${tNum}º Tri ${tYear}`;
          break;
        case 'semester':
          const sYear = key.split('-')[0];
          const sNum = key.split('-')[1].replace('S', '');
          label = `${sNum}º Sem ${sYear}`;
          break;
        case 'year':
          label = key;
          break;
      }

      return {
        label: label.charAt(0).toUpperCase() + label.slice(1),
        ins: value.ins,
        outs: value.outs,
        date: value.date
      };
    });

    // Sort descending by date
    return results.sort((a, b) => b.date.getTime() - a.date.getTime());
  }
}
