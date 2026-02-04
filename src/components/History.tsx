import { useEffect, useState, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import { HistoryAnalysis, type GroupingType } from '../utils/historyAnalysis';
import type { HistoryEntry } from '../types';

export const History = () => {
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [grouping, setGrouping] = useState<GroupingType>('day');
  const [startDate, setStartDate] = useState<string>('');
  const [endDate, setEndDate] = useState<string>('');

  useEffect(() => {
    const load = async () => {
      try {
        const data = await batteryService.fetchHistory();
        setHistory(data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const filteredHistory = useMemo(() => {
    return history.filter(entry => {
        // Core filter rule
        if (entry.type === 'out' && entry.source !== 'map') return false;
        
        // Date filter
        if (startDate || endDate) {
            const ts = entry.timestamp?.toDate ? entry.timestamp.toDate() : new Date(entry.timestamp);
            if (startDate && ts < new Date(startDate)) return false;
            if (endDate) {
                const end = new Date(endDate);
                end.setHours(23, 59, 59, 999);
                if (ts > end) return false;
            }
        }
        return true;
    });
  }, [history, startDate, endDate]);

  const groupedData = useMemo(() => {
    return HistoryAnalysis.group(filteredHistory, grouping);
  }, [filteredHistory, grouping]);

  if (loading) return (
    <div className="flex flex-col items-center justify-center py-20">
        <div className="w-12 h-12 border-4 border-[#EC4899]/20 border-t-[#EC4899] rounded-full animate-spin mb-4"></div>
        <p className="text-gray-500 font-bold animate-pulse">Analisando histórico...</p>
    </div>
  );

  return (
    <div className="space-y-8">
        <div className="flex flex-col lg:flex-row gap-4 items-end bg-[#141414] p-6 rounded-3xl border border-white/5 shadow-xl">
            <div className="flex-1 w-full">
                <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Agrupar por</label>
                <select 
                    value={grouping}
                    onChange={(e) => setGrouping(e.target.value as GroupingType)}
                    className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                >
                    <option value="day">Dia</option>
                    <option value="month">Mês</option>
                    <option value="trimester">Trimestre</option>
                    <option value="semester">Semestre</option>
                    <option value="year">Ano</option>
                </select>
            </div>
            <div className="flex-[2] w-full grid grid-cols-2 gap-3">
                <div>
                    <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">De</label>
                    <input 
                        type="date" 
                        value={startDate}
                        onChange={(e) => setStartDate(e.target.value)}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                    />
                </div>
                <div>
                    <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Até</label>
                    <input 
                        type="date" 
                        value={endDate}
                        onChange={(e) => setEndDate(e.target.value)}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                    />
                </div>
            </div>
            <button 
                onClick={() => { setStartDate(''); setEndDate(''); }}
                className="px-6 py-3 bg-white/5 hover:bg-white/10 text-gray-400 hover:text-white rounded-xl transition-all font-bold text-sm whitespace-nowrap"
            >
                Limpar Filtros
            </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {groupedData.map((group) => (
                <div key={group.label} className="bg-[#141414] p-6 rounded-[2rem] border border-white/5 hover:border-white/10 transition-all group shadow-lg">
                    <div className="flex items-center justify-between mb-6">
                        <h3 className="text-lg font-black text-white tracking-tight">{group.label}</h3>
                        <div className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center">
                            <span className="material-icons text-gray-600">calendar_today</span>
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div className="bg-green-500/[0.03] p-4 rounded-2xl border border-green-500/10 group-hover:bg-green-500/[0.05] transition-colors">
                            <p className="text-[10px] font-black text-green-500/60 uppercase tracking-widest mb-1">Entradas</p>
                            <p className="text-2xl font-black text-green-400">+{group.ins}</p>
                        </div>
                        <div className="bg-red-500/[0.03] p-4 rounded-2xl border border-red-500/10 group-hover:bg-red-500/[0.05] transition-colors">
                            <p className="text-[10px] font-black text-red-500/60 uppercase tracking-widest mb-1">Saídas</p>
                            <p className="text-2xl font-black text-red-400">-{group.outs}</p>
                        </div>
                    </div>
                </div>
            ))}
        </div>

        {groupedData.length === 0 && (
            <div className="flex flex-col items-center justify-center py-20 bg-[#141414]/30 rounded-[2.5rem] border-2 border-dashed border-white/5">
                <span className="material-icons text-5xl mb-3 text-gray-700">history_toggle_off</span>
                <p className="text-gray-500 font-bold">Nenhum registro encontrado no período.</p>
            </div>
        )}
    </div>
  );
};
