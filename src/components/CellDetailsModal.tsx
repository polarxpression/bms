import type { Battery } from '../types';

interface CellDetailsModalProps {
  battery: Battery;
  onClose: () => void;
  onAdjustGondola: (amount: number) => void;
  onRemove: () => void;
  onEdit: () => void;
}

export const CellDetailsModal = ({ battery, onClose, onAdjustGondola, onRemove, onEdit }: CellDetailsModalProps) => {
  if (!battery) return null;

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center" onClick={onClose}>
      <div className="bg-[#1E1E1E] rounded-2xl shadow-xl w-full max-w-md border border-white/10" onClick={e => e.stopPropagation()}>
        <div className="h-32 bg-black/20 rounded-t-2xl flex items-center justify-center">
          {battery.imageUrl ? (
            <img src={battery.imageUrl} alt={battery.name} className="max-h-full object-contain p-4" />
          ) : (
            <span className="material-icons text-gray-500 text-6xl">battery_std</span>
          )}
        </div>
        <div className="p-6 relative">
          <h2 className="text-2xl font-bold text-white">{battery.name}</h2>
          <p className="text-blue-400 font-semibold">{battery.brand} • {battery.model}</p>

          <div className="my-4 grid grid-cols-2 sm:grid-cols-3 gap-4 text-center">
            <DetailBadge label="Tipo" value={battery.type} />
            <DetailBadge label="Pack" value={`x${battery.packSize}`} />
            {battery.barcode && <DetailBadge label="EAN" value={battery.barcode} />}
            <DetailBadge label="Estoque" value={`${battery.quantity}`} />
          </div>

          <div className="my-4">
            <p className="text-sm text-gray-400 mb-2">Qtd. Gôndola</p>
            <div className="flex items-center justify-between bg-black/30 rounded-xl p-2 border border-white/10">
              <button onClick={() => onAdjustGondola(-1)} className="text-red-400 p-2 rounded-full hover:bg-red-400/10 transition-colors"><span className="material-icons">remove_circle</span></button>
              <span className="text-2xl font-bold text-white">{battery.gondolaQuantity ?? 0}</span>
              <button onClick={() => onAdjustGondola(1)} className="text-green-400 p-2 rounded-full hover:bg-green-400/10 transition-colors"><span className="material-icons">add_circle</span></button>
            </div>
          </div>
          
          {battery.notes && (
            <div className="my-4">
                <p className="text-sm text-gray-400 mb-2">Notas</p>
                <div className="bg-yellow-400/10 border border-yellow-400/20 p-3 rounded-lg text-yellow-200 text-sm italic">
                    {battery.notes}
                </div>
            </div>
          )}

          <div className="absolute top-4 right-4">
            <button onClick={onClose} className="text-gray-400 hover:text-white"><span className="material-icons">close</span></button>
          </div>

          <div className="mt-4 flex flex-col gap-2">
            <a 
                href={`/history?q=${battery.barcode || battery.name}`}
                className="w-full flex items-center justify-center gap-2 py-2 px-4 bg-white/5 hover:bg-white/10 border border-white/10 rounded-xl text-white transition-all text-sm font-bold"
            >
                <span className="material-icons text-sm">history</span>
                Ver Histórico Individual
            </a>

            <div className="flex justify-between items-center mt-2">
                <button onClick={onEdit} className="flex items-center gap-2 text-blue-400 hover:text-blue-300 transition-colors text-sm font-semibold">
                    <span className="material-icons">edit</span>
                    Editar
                </button>
                <button onClick={onRemove} className="flex items-center gap-2 text-red-400 hover:text-red-300 transition-colors text-sm font-semibold">
                    <span className="material-icons">delete_outline</span>
                    Remover do Mapa
                </button>
            </div>
          </div>

        </div>
      </div>
    </div>
  );
};


const DetailBadge = ({ label, value }: { label: string; value: string | number }) => (
    <div className="bg-white/5 border border-white/10 rounded-lg px-3 py-2">
        <p className="text-xs text-gray-400">{label}</p>
        <p className="font-bold text-white text-sm">{value}</p>
    </div>
);
