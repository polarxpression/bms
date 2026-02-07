import { useState, useMemo } from 'react';
import type { Battery } from '../types';

interface BatteryPickerModalProps {
  batteries: Battery[];
  onClose: () => void;
  onSelect: (batteryId: string) => void;
}

export const BatteryPickerModal = ({ batteries, onClose, onSelect }: BatteryPickerModalProps) => {
  const [query, setQuery] = useState('');

  const gondolaItems = useMemo(() => {
    return batteries.filter(b => {
        const loc = (b.location || '').toLowerCase();
        const isGondola = loc.includes('gondola') || loc.includes('gôndola');
        if (!isGondola) return false;
        
        const q = query.toLowerCase();
        return b.name?.toLowerCase().includes(q) || 
               b.brand?.toLowerCase().includes(q) ||
               b.model?.toLowerCase().includes(q);
    });
  }, [batteries, query]);

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center" onClick={onClose}>
      <div className="bg-[#1E1E1E] rounded-2xl shadow-xl w-full max-w-2xl border border-white/10 flex flex-col h-[70vh]" onClick={e => e.stopPropagation()}>
        <div className="p-6 border-b border-white/10">
            <h2 className="text-xl font-bold text-white">Selecionar Bateria (Gôndola)</h2>
            <div className="relative mt-4">
                <span className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <span className="material-icons text-gray-500">search</span>
                </span>
                <input 
                    type="text" 
                    placeholder="Filtrar por nome, marca, modelo..." 
                    value={query}
                    onChange={e => setQuery(e.target.value)}
                    className="w-full bg-black/40 text-white pl-10 pr-3 py-2 rounded-lg border border-white/10 focus:border-blue-500 outline-none"
                />
            </div>
        </div>
        
        <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
            {gondolaItems.length === 0 ? (
                <div className="text-center py-10 text-gray-500">
                    <p>Nenhuma bateria de gôndola encontrada.</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                    {gondolaItems.map(b => (
                        <div 
                            key={b.id}
                            onClick={() => onSelect(b.id)}
                            className="bg-white/5 p-3 rounded-xl border border-white/5 hover:bg-white/10 cursor-pointer flex items-center gap-4"
                        >
                            <div className="w-12 h-12 rounded-lg bg-black/40 flex items-center justify-center overflow-hidden flex-shrink-0">
                                {b.imageUrl ? <img src={b.imageUrl} className="w-full h-full object-contain" /> : <span className="material-icons text-2xl text-gray-600">battery_std</span>}
                            </div>
                            <div className="flex-1 min-w-0">
                                <p className="font-bold text-white truncate">{b.name}</p>
                                <p className="text-sm text-gray-400 truncate">{b.brand} • {b.model}</p>
                            </div>
                             <div className="text-right">
                                <p className="text-xs text-gray-500">Gôn.</p>
                                <p className="font-bold text-blue-400">{b.gondolaQuantity ?? 0}</p>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
        <div className="p-4 border-t border-white/10 flex justify-end">
            <button onClick={onClose} className="text-gray-400">Fechar</button>
        </div>
      </div>
    </div>
  );
};
