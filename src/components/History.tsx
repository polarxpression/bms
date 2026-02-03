import { useEffect, useState } from 'react';
import { batteryService } from '../services/batteryService';
import type { HistoryEntry } from '../types';

export const History = () => {
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      try {
        const data = await batteryService.fetchHistory();
        // Filter: out events only from map
        const filtered = data.filter(entry => {
            if (entry.type === 'out' && entry.source !== 'map') return false;
            return true;
        });
        setHistory(filtered);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const formatDate = (ts: any) => {
    if (!ts) return '-';
    const date = ts.toDate ? ts.toDate() : new Date(ts);
    return date.toLocaleString('pt-BR');
  };

  if (loading) return <div className="p-8 text-center text-gray-500">Carregando histórico...</div>;

  return (
    <div className="space-y-4">
        <div className="bg-[#141414] rounded-xl border border-white/5 overflow-hidden">
            <table className="w-full text-left border-collapse">
                <thead>
                    <tr className="bg-black/20 text-xs font-bold text-gray-400 uppercase tracking-wider">
                        <th className="p-4">Data</th>
                        <th className="p-4">Bateria</th>
                        <th className="p-4">Tipo</th>
                        <th className="p-4">Local</th>
                        <th className="p-4">Qtd</th>
                        <th className="p-4">Motivo</th>
                        <th className="p-4">Origem</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-white/5">
                    {history.map(entry => (
                        <tr key={entry.id} className="hover:bg-white/5 transition-colors">
                            <td className="p-4 text-xs text-gray-400 font-mono whitespace-nowrap">{formatDate(entry.timestamp)}</td>
                            <td className="p-4 font-medium text-white">{entry.batteryName}</td>
                            <td className="p-4">
                                <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${entry.type === 'in' ? 'bg-green-500/10 text-green-400' : 'bg-red-500/10 text-red-400'}`}>
                                    {entry.type === 'in' ? 'Entrada' : 'Saída'}
                                </span>
                            </td>
                            <td className="p-4 text-xs text-gray-300 capitalize">{entry.location}</td>
                            <td className="p-4 font-bold text-white">{entry.quantity}</td>
                            <td className="p-4 text-xs text-gray-400 italic">{entry.reason}</td>
                            <td className="p-4">
                                <span className="text-[10px] bg-white/5 px-1.5 py-0.5 rounded text-gray-500 uppercase font-black">{entry.source}</span>
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>
            {history.length === 0 && (
                <div className="p-12 text-center text-gray-500">Nenhum registro encontrado.</div>
            )}
        </div>
    </div>
  );
};
