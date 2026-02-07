import { useState } from 'react';
import type { BatteryMap } from '../types';

interface MapManagerModalProps {
  maps: BatteryMap[];
  currentMapId: string | null;
  onClose: () => void;
  onCreate: (name: string, purpose: string) => Promise<void>;
  onUpdate: (id: string, name: string, purpose: string) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onSelect: (id: string) => void;
}

export const MapManagerModal = (props: MapManagerModalProps) => {
  const [editingMap, setEditingMap] = useState<Partial<BatteryMap> | null>(null);

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center" onClick={props.onClose}>
      <div className="bg-[#1E1E1E] rounded-2xl shadow-xl w-full max-w-lg border border-white/10 flex flex-col max-h-[80vh]" onClick={e => e.stopPropagation()}>
        <div className="p-6 border-b border-white/10">
            <h2 className="text-xl font-bold text-white">Gerenciar Mapas</h2>
        </div>
        
        <div className="flex-1 overflow-y-auto p-4 space-y-2">
            {props.maps.map(map => (
                <div key={map.id} className={`p-4 rounded-lg flex justify-between items-center ${map.id === props.currentMapId ? 'bg-blue-500/10 border border-blue-500' : 'bg-white/5 border border-transparent'}`}>
                    <div>
                        <p className="font-bold text-white">{map.name}</p>
                        <p className="text-sm text-gray-400">{map.purpose}</p>
                    </div>
                    <div className="flex items-center gap-2">
                         <button onClick={() => setEditingMap(map)} className="text-blue-400 hover:text-blue-300 p-2"><span className="material-icons text-base">edit</span></button>
                         <button onClick={() => { if(confirm(`Excluir "${map.name}"?`)) props.onDelete(map.id) }} className="text-red-400 hover:text-red-300 p-2"><span className="material-icons text-base">delete</span></button>
                         <button onClick={() => props.onSelect(map.id)} className="bg-white/10 text-white px-3 py-1 rounded-md text-xs hover:bg-white/20">Selecionar</button>
                    </div>
                </div>
            ))}
        </div>

        <div className="p-6 border-t border-white/10 flex justify-between">
          <button onClick={props.onClose} className="text-gray-400">Fechar</button>
          <button onClick={() => setEditingMap({})} className="bg-blue-600 hover:bg-blue-500 text-white font-bold px-4 py-2 rounded-lg">Criar Novo Mapa</button>
        </div>

        {editingMap && (
            <MapFormModal 
                map={editingMap}
                onClose={() => setEditingMap(null)}
                onSave={async (id, name, purpose) => {
                    if (id) {
                        await props.onUpdate(id, name, purpose);
                    } else {
                        await props.onCreate(name, purpose);
                    }
                    setEditingMap(null);
                }}
            />
        )}
      </div>
    </div>
  );
};

const MapFormModal = ({ map, onClose, onSave }: { map: Partial<BatteryMap>, onClose: () => void, onSave: (id: string | undefined, name: string, purpose: string) => Promise<void> }) => {
    const [name, setName] = useState(map.name || '');
    const [purpose, setPurpose] = useState(map.purpose || '');

    const handleSave = () => {
        if (!name.trim()) return;
        onSave(map.id, name, purpose);
    }

    return (
        <div className="fixed inset-0 bg-black/70 z-[60] flex items-center justify-center" onClick={onClose}>
            <div className="bg-[#2a2a2a] rounded-xl shadow-2xl w-full max-w-sm border border-white/10" onClick={e => e.stopPropagation()}>
                <div className="p-6">
                    <h3 className="text-lg font-bold text-white mb-4">{map.id ? 'Editar Mapa' : 'Novo Mapa'}</h3>
                    <div className="space-y-4">
                        <input 
                            type="text"
                            placeholder="Nome do Mapa"
                            value={name}
                            onChange={e => setName(e.target.value)}
                            className="w-full bg-black/40 text-white px-4 py-2 rounded-lg border border-white/10 focus:border-blue-500 outline-none"
                        />
                        <input
                            type="text"
                            placeholder="Propósito / Descrição"
                            value={purpose}
                            onChange={e => setPurpose(e.target.value)}
                            className="w-full bg-black/40 text-white px-4 py-2 rounded-lg border border-white/10 focus:border-blue-500 outline-none"
                        />
                    </div>
                </div>
                 <div className="p-4 bg-black/20 rounded-b-xl flex justify-end gap-4">
                    <button onClick={onClose} className="text-gray-300">Cancelar</button>
                    <button onClick={handleSave} className="bg-blue-600 hover:bg-blue-500 text-white font-bold px-4 py-2 rounded-lg">Salvar</button>
                </div>
            </div>
        </div>
    )
}
