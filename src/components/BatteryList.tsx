import { useEffect, useState } from 'react';
import { collection, onSnapshot, query, orderBy } from 'firebase/firestore';
import { db } from '../firebase/client';
import type { Battery } from '../types';

const BatteryCard = ({ battery }: { battery: Battery }) => {
  return (
    <div className="bg-[#141414] rounded-3xl border border-white/5 p-6 flex flex-col hover:border-[#EC4899]/30 transition-all duration-300 group shadow-lg hover:shadow-[#EC4899]/5">
      {battery.imageUrl && (
        <div className="h-48 w-full mb-6 overflow-hidden rounded-2xl bg-black/40 flex items-center justify-center border border-white/5 relative group-hover:scale-[1.02] transition-transform">
            <img 
                src={battery.imageUrl} 
                alt={`${battery.brand} ${battery.model}`} 
                className="object-contain h-full w-full p-4"
                onError={(e) => {
                    (e.target as HTMLImageElement).style.display = 'none'; 
                }}
            />
            <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent"></div>
        </div>
      )}
      {!battery.imageUrl && (
          <div className="h-48 w-full mb-6 rounded-2xl bg-black/40 border-2 border-dashed border-white/5 flex flex-col items-center justify-center text-gray-700">
              <span className="material-icons text-4xl mb-2">image_not_supported</span>
              <span className="text-[10px] font-black uppercase tracking-widest">Sem Imagem</span>
          </div>
      )}

      <div className="flex justify-between items-start mb-4">
        <div>
            <h3 className="text-lg font-black text-white leading-tight group-hover:text-[#EC4899] transition-colors">{battery.brand}</h3>
            <p className="text-xs text-gray-500 font-bold uppercase tracking-wider mt-1">{battery.model}</p>
        </div>
        <div className={`px-3 py-1 text-[10px] font-black uppercase rounded-full tracking-widest ${battery.quantity > 0 ? 'bg-green-500/10 text-green-400' : 'bg-red-500/10 text-red-400'}`}>
            {battery.quantity} UN
        </div>
      </div>

      <div className="mt-auto space-y-3 pt-4 border-t border-white/5">
        <div className="flex justify-between items-center">
            <span className="text-[10px] font-black text-gray-600 uppercase tracking-widest">Localização</span>
            <span className="text-xs font-bold text-gray-400">{battery.location || 'ESTOQUE'}</span>
        </div>
        <div className="flex justify-between items-center">
            <span className="text-[10px] font-black text-gray-600 uppercase tracking-widest">Tipo</span>
            <span className="text-xs font-bold text-gray-400">
                {battery.type || 'BATERIA'}
                {(battery.voltage || battery.chemistry) && ` (${battery.voltage || ''} ${battery.chemistry || ''})`}
            </span>
        </div>
        <div className="bg-black/20 p-2 rounded-xl border border-white/5 flex items-center justify-between">
            <span className="material-icons text-gray-600 text-sm">qr_code</span>
            <span className="font-mono text-[10px] text-gray-500">{battery.barcode || '-----------'}</span>
        </div>
      </div>
    </div>
  );
};

export default function BatteryList() {
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'batteries'), orderBy('brand'), orderBy('model'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const bats: Battery[] = [];
      snapshot.forEach((doc) => {
        bats.push({ id: doc.id, ...doc.data() } as Battery);
      });
      setBatteries(bats);
      setLoading(false);
    }, (error) => {
        console.error("Error fetching batteries: ", error);
        setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  if (loading) {
    return (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6 p-6 animate-pulse">
            {[1,2,3,4].map(i => (
                <div key={i} className="h-80 bg-white/5 rounded-3xl border border-white/5"></div>
            ))}
        </div>
    );
  }

  if (batteries.length === 0) {
      return (
          <div className="flex flex-col items-center justify-center py-32 text-gray-600">
              <span className="material-icons text-6xl mb-4 opacity-20">inventory_2</span>
              <p className="font-bold uppercase tracking-[0.2em] text-sm">Inventário Vazio</p>
          </div>
      );
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6 p-6 animate-fade-in">
      {batteries.map((battery) => (
        <BatteryCard key={battery.id} battery={battery} />
      ))}
    </div>
  );
}
