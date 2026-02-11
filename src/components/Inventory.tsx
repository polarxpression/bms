import { useEffect, useState, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import { type Battery, SortOption } from '../types';
import { BatteryForm } from './BatteryForm';
import { SearchQueryParser } from '../utils/searchQueryParser';

export const Inventory = () => {
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [query, setQuery] = useState('');
  const [sortOption, setSortOption] = useState<SortOption>(SortOption.Name);
  const [sortAsc, setSortAsc] = useState(true);
  const [loading, setLoading] = useState(true);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editingBattery, setEditingBattery] = useState<Battery | undefined>(undefined);

  useEffect(() => {
    const unsubscribe = batteryService.subscribeToBatteries((data) => {
      setBatteries(data);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  const handleSort = (option: SortOption) => {
    if (sortOption === option) {
      setSortAsc(!sortAsc);
    } else {
      setSortOption(option);
      setSortAsc(true);
    }
  };

  const filteredBatteries = useMemo(() => {
    let result = [...batteries];
    
    if (query) {
      result = result.filter(b => SearchQueryParser.matches(b, query));
    }

    return result.sort((a, b) => {
      let cmp = 0;
      switch (sortOption) {
        case SortOption.Name:
          cmp = (a.brand + a.model).localeCompare(b.brand + b.model);
          break;
        case SortOption.Brand:
            cmp = a.brand.localeCompare(b.brand);
            break;
        case SortOption.Type:
            cmp = (a.type || '').localeCompare(b.type || '');
            break;
        case SortOption.StockQty:
            cmp = a.quantity - b.quantity;
            break;
        case SortOption.GondolaQty:
            cmp = (a.gondolaQuantity || 0) - (b.gondolaQuantity || 0);
            break;
      }
      return sortAsc ? cmp : -cmp;
    });
  }, [batteries, query, sortOption, sortAsc]);

  const toggleSelection = (id: string) => {
    const newSet = new Set(selectedIds);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setSelectedIds(newSet);
  };

  const handleDelete = async () => {
    if (!confirm(`Excluir ${selectedIds.size} itens permanentemente?`)) return;
    for (const id of selectedIds) {
      await batteryService.deleteBattery(id);
    }
    setSelectedIds(new Set());
  };

  const adjustQty = async (b: Battery, delta: number, isGondola: boolean) => {
      await batteryService.adjustQuantity(b, delta, isGondola);
  };

  const openAdd = () => {
      setEditingBattery(undefined);
      setIsFormOpen(true);
  };

  const openEdit = (b: Battery) => {
      setEditingBattery(b);
      setIsFormOpen(true);
  };

  if (loading) return (
    <div className="space-y-4 animate-pulse">
        <div className="h-16 bg-white/5 rounded-2xl"></div>
        <div className="h-96 bg-white/5 rounded-2xl"></div>
    </div>
  );

  return (
    <div className="space-y-6 animate-fade-in">
        {/* Toolbar */}
        <div className="flex flex-col md:flex-row justify-between items-stretch md:items-center gap-4 bg-[#141414] p-4 md:p-6 rounded-[2rem] border border-white/5 shadow-2xl relative overflow-hidden group">
            <div className="absolute inset-0 bg-gradient-to-r from-[#EC4899]/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"></div>
            
            {selectedIds.size > 0 ? (
                <div className="flex items-center w-full justify-between animate-fade-in z-10">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-[#EC4899] flex items-center justify-center text-white shadow-lg shadow-pink-500/20">
                            <span className="text-sm font-black">{selectedIds.size}</span>
                        </div>
                        <span className="font-bold text-white tracking-tight">Itens selecionados</span>
                    </div>
                    <div className="flex items-center gap-3">
                         <button 
                            onClick={() => setSelectedIds(new Set())}
                            className="px-4 py-2 text-sm font-bold text-gray-500 hover:text-white transition-colors"
                        >
                            Cancelar
                        </button>
                        <button 
                            onClick={handleDelete}
                            className="px-6 py-2 bg-red-500 text-white rounded-xl hover:bg-red-600 font-black uppercase tracking-widest text-[10px] flex items-center shadow-lg shadow-red-500/20 transition-all active:scale-95"
                        >
                            <span className="material-icons text-sm mr-2">delete_forever</span>
                            Excluir Itens
                        </button>
                    </div>
                </div>
            ) : (
                <>
                    <div className="relative flex-1 w-full md:max-w-xl group/search">
                         <span className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                            <span className="material-icons text-gray-500 group-focus-within/search:text-[#EC4899] transition-colors">search</span>
                        </span>
                        <input 
                            type="text"
                            placeholder="Buscar por marca, modelo ou código EAN..."
                            className="w-full bg-black/40 text-white pl-12 pr-4 py-3.5 rounded-2xl border border-white/5 focus:border-[#EC4899]/50 focus:outline-none focus:bg-black/60 transition-all placeholder:text-gray-600 font-medium"
                            value={query}
                            onChange={e => setQuery(e.target.value)}
                        />
                    </div>
                    <button 
                        className="px-8 py-3.5 bg-[#EC4899] text-white rounded-2xl hover:bg-[#D61F69] font-black uppercase tracking-[0.1em] text-xs shadow-xl shadow-pink-500/20 flex items-center justify-center transition-all active:scale-95 hover:translate-y-[-2px]"
                        onClick={openAdd}
                    >
                        <span className="material-icons text-base mr-2">add_circle</span>
                        Adicionar Item
                    </button>
                </>
            )}
        </div>

        {/* Desktop Table View */}
        <div className="hidden md:block bg-[#141414] rounded-[2.5rem] border border-white/5 overflow-hidden shadow-2xl">
            <table className="w-full text-left border-collapse">
                <thead>
                    <tr className="bg-black/40 text-[10px] font-black text-gray-500 uppercase tracking-[0.2em]">
                        <th className="p-6 w-16 text-center">
                            <div className="w-5 h-5 rounded border-2 border-white/10 mx-auto"></div>
                        </th>
                        <th 
                            className="p-6 cursor-pointer hover:text-white transition-colors group"
                            onClick={() => handleSort(SortOption.Name)}
                        >
                            <div className="flex items-center gap-2">
                                Produto {sortOption === SortOption.Name && <span className="material-icons text-xs text-[#EC4899]">{sortAsc ? 'north' : 'south'}</span>}
                            </div>
                        </th>
                        <th className="p-6">Marca</th>
                        <th className="p-6">Categoria</th>
                        <th className="p-6 text-center cursor-pointer hover:text-white" onClick={() => handleSort(SortOption.GondolaQty)}>
                            <div className="flex items-center justify-center gap-2">
                                Gôndola {sortOption === SortOption.GondolaQty && <span className="material-icons text-xs text-[#EC4899]">{sortAsc ? 'north' : 'south'}</span>}
                            </div>
                        </th>
                        <th className="p-6 text-center cursor-pointer hover:text-white" onClick={() => handleSort(SortOption.StockQty)}>
                            <div className="flex items-center justify-center gap-2">
                                Estoque {sortOption === SortOption.StockQty && <span className="material-icons text-xs text-[#EC4899]">{sortAsc ? 'north' : 'south'}</span>}
                            </div>
                        </th>
                        <th className="p-6 text-right">Editar</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-white/5">
                    {filteredBatteries.map(b => {
                        const isSelected = selectedIds.has(b.id);
                        const isLowStock = b.quantity <= (b.minStockThreshold || 10);
                        return (
                            <tr 
                                key={b.id} 
                                className={`group transition-all duration-200 ${isSelected ? 'bg-[#EC4899]/10' : 'hover:bg-white/[0.02]'} cursor-pointer`}
                                onClick={(e) => {
                                    if ((e.target as HTMLElement).closest('input[type="checkbox"], button')) return;
                                    openEdit(b);
                                }}
                            >
                                <td className="p-6 text-center">
                                    <label className="relative flex items-center justify-center cursor-pointer">
                                        <input 
                                            type="checkbox" 
                                            checked={isSelected}
                                            onChange={() => toggleSelection(b.id)}
                                            className="sr-only peer"
                                        />
                                        <div className="w-5 h-5 rounded border-2 border-white/10 peer-checked:border-[#EC4899] peer-checked:bg-[#EC4899] transition-all flex items-center justify-center">
                                            {isSelected && <span className="material-icons text-white text-[14px] font-black">check</span>}
                                        </div>
                                    </label>
                                </td>
                                <td className="p-6">
                                    <div className="flex items-center gap-4">
                                        <div className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center border border-white/5 group-hover:scale-110 transition-transform">
                                            <span className="material-icons text-gray-500 text-sm">battery_full</span>
                                        </div>
                                        <div>
                                            <div className="font-bold text-white text-sm group-hover:text-[#EC4899] transition-colors">{b.model}</div>
                                            <div className="text-[10px] text-gray-500 font-mono tracking-wider flex items-center gap-2">
                                                {b.barcode || 'SEM EAN'}
                                                {(b.voltage || b.chemistry) && (
                                                    <span className="text-[#EC4899]/80 font-black uppercase tracking-tighter bg-[#EC4899]/5 px-1.5 py-0.5 rounded border border-[#EC4899]/10">
                                                        {b.voltage} {b.chemistry}
                                                    </span>
                                                )}
                                            </div>
                                        </div>
                                    </div>
                                </td>
                                <td className="p-6">
                                    <span className="text-xs font-bold text-gray-300 uppercase tracking-wider">{b.brand}</span>
                                </td>
                                <td className="p-6">
                                    <span className="bg-white/5 px-2.5 py-1 rounded-lg text-[10px] font-black uppercase text-gray-500 tracking-wider group-hover:bg-[#EC4899]/10 group-hover:text-[#EC4899] transition-colors">
                                        {b.type || 'BATERIA'}
                                    </span>
                                </td>
                                <td className="p-6 text-center">
                                    <div className="inline-flex items-center justify-center bg-black/20 p-1.5 rounded-xl border border-white/5 group-hover:border-white/10 transition-all">
                                        <button onClick={() => adjustQty(b, -1, true)} className="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-white hover:bg-white/5 rounded-lg transition-all">
                                            <span className="material-icons text-sm">remove</span>
                                        </button>
                                        <div className="px-4 min-w-[3rem]">
                                            <span className="font-mono text-[#EC4899] font-black text-sm">{b.gondolaQuantity || 0}</span>
                                            <div className="text-[8px] text-gray-600 font-black uppercase tracking-tighter">Lim: {b.gondolaLimit || 20}</div>
                                        </div>
                                        <button onClick={() => adjustQty(b, 1, true)} className="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-white hover:bg-white/5 rounded-lg transition-all">
                                            <span className="material-icons text-sm">add</span>
                                        </button>
                                    </div>
                                </td>
                                <td className="p-6 text-center">
                                    <div className="inline-flex items-center justify-center bg-black/20 p-1.5 rounded-xl border border-white/5 group-hover:border-white/10 transition-all">
                                        <button onClick={() => adjustQty(b, -1, false)} className="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-white hover:bg-white/5 rounded-lg transition-all">
                                            <span className="material-icons text-sm">remove</span>
                                        </button>
                                        <div className="px-4 min-w-[3rem]">
                                            <span className={`font-mono font-black text-sm ${isLowStock ? 'text-red-500' : 'text-green-400'}`}>
                                                {b.quantity}
                                            </span>
                                            <div className="text-[8px] text-gray-600 font-black uppercase tracking-tighter">ESTOQUE</div>
                                        </div>
                                        <button onClick={() => adjustQty(b, 1, false)} className="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-white hover:bg-white/5 rounded-lg transition-all">
                                            <span className="material-icons text-sm">add</span>
                                        </button>
                                    </div>
                                </td>
                                <td className="p-6 text-right">
                                    <button 
                                        className="w-10 h-10 inline-flex items-center justify-center text-gray-500 hover:text-white rounded-xl hover:bg-[#EC4899] hover:shadow-lg hover:shadow-pink-500/20 transition-all"
                                        onClick={() => openEdit(b)}
                                    >
                                        <span className="material-icons text-sm">edit_note</span>
                                    </button>
                                </td>
                            </tr>
                        );
                    })}
                </tbody>
            </table>
            {filteredBatteries.length === 0 && (
                <div className="p-20 text-center text-gray-500 flex flex-col items-center">
                    <div className="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mb-4">
                        <span className="material-icons text-3xl">search_off</span>
                    </div>
                    <p className="font-bold">Nenhum item encontrado.</p>
                    <p className="text-sm opacity-60">Tente ajustar seus filtros de busca.</p>
                </div>
            )}
        </div>

        {/* Mobile View */}
        <div className="md:hidden space-y-4">
             {filteredBatteries.map(b => (
                <div key={b.id} className="bg-[#141414] p-6 rounded-3xl border border-white/5 shadow-xl relative overflow-hidden">
                    <div className="flex justify-between items-start mb-4">
                        <div onClick={() => openEdit(b)} className="flex-1">
                            <h3 className="font-black text-white text-lg leading-tight">{b.brand}</h3>
                            <p className="text-xs text-[#EC4899] font-black uppercase tracking-wider">{b.model}</p>
                            <div className="mt-2 flex gap-2">
                                <span className="bg-white/5 px-2 py-0.5 rounded text-[9px] font-black text-gray-500 uppercase">{b.type}</span>
                            </div>
                        </div>
                        <button 
                             onClick={() => openEdit(b)}
                             className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center text-gray-400 active:bg-[#EC4899] active:text-white transition-colors"
                        >
                            <span className="material-icons text-sm">edit</span>
                        </button>
                    </div>

                    <div className="grid grid-cols-2 gap-3 mt-6">
                        <div className="bg-black/20 p-3 rounded-2xl border border-white/5">
                            <span className="text-[9px] text-gray-600 font-black uppercase tracking-widest block mb-1">Gôndola</span>
                            <div className="flex items-center justify-between">
                                <span className="font-mono text-[#EC4899] font-black text-lg">{b.gondolaQuantity || 0}</span>
                                <div className="flex gap-1">
                                    <button onClick={() => adjustQty(b, -1, true)} className="w-7 h-7 flex items-center justify-center bg-white/5 rounded-lg">-</button>
                                    <button onClick={() => adjustQty(b, 1, true)} className="w-7 h-7 flex items-center justify-center bg-white/5 rounded-lg">+</button>
                                </div>
                            </div>
                        </div>
                        <div className="bg-black/20 p-3 rounded-2xl border border-white/5">
                            <span className="text-[9px] text-gray-600 font-black uppercase tracking-widest block mb-1">Estoque</span>
                            <div className="flex items-center justify-between">
                                <span className={`font-mono font-black text-lg ${b.quantity <= 10 ? 'text-red-500' : 'text-green-400'}`}>{b.quantity}</span>
                                <div className="flex gap-1">
                                    <button onClick={() => adjustQty(b, -1, false)} className="w-7 h-7 flex items-center justify-center bg-white/5 rounded-lg">-</button>
                                    <button onClick={() => adjustQty(b, 1, false)} className="w-7 h-7 flex items-center justify-center bg-white/5 rounded-lg">+</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
             ))}
        </div>

        {isFormOpen && (
            <BatteryForm 
                battery={editingBattery} 
                batteries={batteries}
                onClose={() => setIsFormOpen(false)} 
            />
        )}
    </div>
  );
};

