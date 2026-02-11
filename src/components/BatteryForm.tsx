import { useState, useEffect, useMemo, useRef } from 'react';
import type { Battery, AppSettings } from '../types';
import { batteryService } from '../services/batteryService';
import { imageUploadService } from '../services/imageUploadService';
import { SearchQueryParser } from '../utils/searchQueryParser';

interface Props {
  battery?: Battery;
  batteries?: Battery[]; // For linking
  onClose: () => void;
}

export const BatteryForm = ({ battery, batteries = [], onClose }: Props) => {
  const [settings, setSettings] = useState<AppSettings>({
    defaultGondolaCapacity: 20,
    defaultMinStockThreshold: 10,
    daysToAnalyze: 90
  });

  const [formData, setFormData] = useState<Partial<Battery>>({
    brand: '',
    model: '',
    type: '',
    quantity: 0,
    gondolaQuantity: 0,
    gondolaLimit: 0,
    packSize: 1,
    minStockThreshold: 0,
    useDefaultMinStock: true,
    barcode: '',
    location: 'Estoque',
    notes: '',
    discontinued: false,
    imageUrl: '',
    linkedBatteryId: '',
    voltage: '',
    chemistry: ''
  });

  const [uploading, setUploading] = useState(false);
  const [showPicker, setShowPicker] = useState(false);
  const [pickerQuery, setPickerQuery] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const unsub = batteryService.subscribeToSettings(setSettings);
    return () => unsub();
  }, []);

  useEffect(() => {
    if (battery) {
      setFormData(prev => ({ ...prev, ...battery }));
    } else {
        // Use defaults for new battery
        setFormData(prev => ({
            ...prev,
            gondolaLimit: settings.defaultGondolaCapacity,
            minStockThreshold: settings.defaultMinStockThreshold
        }));
    }
  }, [battery, settings]);

  const existingBrands = useMemo(() => 
    Array.from(new Set(batteries.map(b => b.brand).filter(Boolean))).sort(), 
  [batteries]);

  const existingTypes = useMemo(() => 
    Array.from(new Set(batteries.map(b => b.type).filter(Boolean))).sort(), 
  [batteries]);

  const stockBatteries = useMemo(() => {
    return batteries.filter(b => {
        if (battery && b.id === battery.id) return false;
        return b.location === 'Estoque';
    });
  }, [batteries, battery]);

  const filteredPickerBatteries = useMemo(() => {
    if (!pickerQuery) return stockBatteries;
    return stockBatteries.filter(b => SearchQueryParser.matches(b, pickerQuery));
  }, [stockBatteries, pickerQuery]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (battery && battery.id) {
        await batteryService.updateBattery(battery.id, formData);
      } else {
        await batteryService.addBattery(formData as Battery);
      }
      onClose();
    } catch (error) {
      console.error("Error saving battery:", error);
      alert("Erro ao salvar.");
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    let val: any = value;
    if (type === 'number') val = Number(value);
    if (type === 'checkbox') val = (e.target as HTMLInputElement).checked;
    setFormData(prev => ({ ...prev, [name]: val }));
  };

  const handleImageClick = () => {
      fileInputRef.current?.click();
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (!file) return;

      if (!settings.imgbbApiKey) {
          alert("Configure a chave da API do ImgBB nas Configurações primeiro.");
          return;
      }

      setUploading(true);
      try {
          const url = await imageUploadService.uploadImage(file, settings.imgbbApiKey);
          if (url) {
              setFormData(prev => ({ ...prev, imageUrl: url }));
          } else {
              alert("Falha ao enviar imagem. Verifique sua chave API.");
          }
      } catch (err) {
          console.error(err);
          alert("Erro no upload.");
      } finally {
          setUploading(false);
      }
  };

  const linkedBatteryName = useMemo(() => {
    if (!formData.linkedBatteryId) return 'Sem vínculo (Nenhum)';
    return stockBatteries.find(b => b.id === formData.linkedBatteryId)?.name || 'Item vinculado';
  }, [formData.linkedBatteryId, stockBatteries]);

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-md p-4 overflow-y-auto animate-fade-in">
      <div className="bg-[#141414] w-full max-w-2xl rounded-[2.5rem] border border-white/10 shadow-[0_0_50px_rgba(0,0,0,0.5)] overflow-hidden animate-fade-in-up my-auto relative">
        <div className="p-8 border-b border-white/5 flex justify-between items-center bg-gradient-to-r from-black/40 to-transparent">
          <div>
            <h2 className="text-2xl font-black text-white flex items-center tracking-tight">
                <div className="w-10 h-10 rounded-xl bg-[#EC4899]/20 flex items-center justify-center mr-4">
                    <span className="material-icons text-[#EC4899]">{battery ? 'edit' : 'add_circle'}</span>
                </div>
                {battery ? 'Editar Item' : 'Novo Registro'}
            </h2>
            <p className="text-[10px] text-gray-500 font-black uppercase tracking-[0.2em] mt-1 ml-14">Battery Management Hub</p>
          </div>
          <button 
            onClick={onClose} 
            className="w-10 h-10 rounded-full hover:bg-white/5 flex items-center justify-center text-gray-500 hover:text-white transition-all"
          >
            <span className="material-icons">close</span>
          </button>
        </div>
        
        <form onSubmit={handleSubmit} className="p-8 space-y-8 max-h-[75vh] overflow-y-auto custom-scrollbar">
            {/* Image & Main Info */}
            <div className="flex flex-col md:flex-row gap-8">
                <div className="flex-shrink-0 flex flex-col items-center">
                    <input 
                        type="file" 
                        ref={fileInputRef} 
                        onChange={handleFileChange} 
                        accept="image/*" 
                        className="hidden" 
                    />
                    <div 
                        onClick={handleImageClick}
                        className="w-40 h-40 bg-black/40 rounded-[2rem] border-2 border-dashed border-white/10 flex flex-col items-center justify-center cursor-pointer hover:border-[#EC4899]/50 transition-all overflow-hidden relative group shadow-inner"
                    >
                        {uploading ? (
                            <div className="flex flex-col items-center">
                                <div className="w-8 h-8 border-2 border-[#EC4899]/20 border-t-[#EC4899] rounded-full animate-spin mb-2"></div>
                                <span className="text-[10px] text-[#EC4899] font-black uppercase tracking-widest">Enviando...</span>
                            </div>
                        ) : formData.imageUrl ? (
                            <img src={formData.imageUrl} className="w-full h-full object-cover" />
                        ) : (
                            <>
                                <span className="material-icons text-4xl text-gray-700 group-hover:text-[#EC4899] transition-colors">add_a_photo</span>
                                <span className="text-[10px] text-gray-600 font-black uppercase mt-2 tracking-widest">Foto do Produto</span>
                            </>
                        )}
                        <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                            <span className="text-xs font-black text-white uppercase tracking-widest">{formData.imageUrl ? 'Alterar' : 'Upload'}</span>
                        </div>
                    </div>
                </div>

                <div className="flex-1 grid grid-cols-1 md:grid-cols-2 gap-5">
                    <FormInput label="Marca" name="brand" list="brands" value={formData.brand} onChange={handleChange} required />
                    <FormInput label="Modelo" name="model" value={formData.model} onChange={handleChange} required />
                    <FormInput label="Tipo / Categoria" name="type" list="types" value={formData.type} onChange={handleChange} />
                    <FormInput label="Pack Size" name="packSize" type="number" value={formData.packSize} onChange={handleChange} />
                    <FormInput label="EAN / Código de Barras" name="barcode" value={formData.barcode} onChange={handleChange} icon="qr_code" />
                    
                    <datalist id="brands">
                        {existingBrands.map(b => <option key={b} value={b} />)}
                    </datalist>
                    <datalist id="types">
                        {existingTypes.map(t => <option key={t} value={t} />)}
                    </datalist>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-8 p-6 bg-black/30 rounded-[2rem] border border-white/5 relative overflow-hidden">
                <div className="space-y-5 relative z-10">
                    <h3 className="text-[10px] font-black text-green-500 uppercase tracking-[0.3em] mb-4 flex items-center">
                        <span className="w-6 h-6 rounded bg-green-500/10 flex items-center justify-center mr-2">
                            <span className="material-icons text-[14px]">warehouse</span>
                        </span>
                        Estoque Principal
                    </h3>
                    <div className="grid grid-cols-2 gap-4">
                        <FormInput label="Qtd. Atual" name="quantity" type="number" value={formData.quantity} onChange={handleChange} />
                        <FormInput label="Mín. Crítico" name="minStockThreshold" type="number" value={formData.minStockThreshold} onChange={handleChange} disabled={formData.useDefaultMinStock} />
                    </div>
                    <label className="flex items-center text-[10px] font-bold text-gray-500 cursor-pointer group uppercase tracking-widest">
                        <input type="checkbox" name="useDefaultMinStock" checked={formData.useDefaultMinStock} onChange={handleChange} className="mr-3 w-4 h-4 rounded border-gray-600 bg-black/40 text-[#EC4899] focus:ring-[#EC4899]" />
                        Herdar limite padrão do sistema
                    </label>
                </div>

                <div className="space-y-5 relative z-10 md:border-l md:border-white/5 md:pl-8">
                    <h3 className="text-[10px] font-black text-amber-500 uppercase tracking-[0.3em] mb-4 flex items-center">
                        <span className="w-6 h-6 rounded bg-amber-500/10 flex items-center justify-center mr-2">
                            <span className="material-icons text-[14px]">storefront</span>
                        </span>
                        Gôndola (PDV)
                    </h3>
                    <div className="grid grid-cols-2 gap-4">
                        <FormInput label="Qtd. Exposta" name="gondolaQuantity" type="number" value={formData.gondolaQuantity} onChange={handleChange} />
                        <FormInput label="Capacidade" name="gondolaLimit" type="number" value={formData.gondolaLimit} onChange={handleChange} />
                    </div>
                    
                    <div className="space-y-1.5">
                        <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest ml-1">Vincular ao Estoque</label>
                        <button 
                            type="button"
                            onClick={() => setShowPicker(true)}
                            className="w-full flex items-center justify-between bg-black/40 text-white p-3.5 rounded-xl border border-white/5 hover:border-[#EC4899]/30 transition-all text-xs font-bold"
                        >
                            <span className="truncate">{linkedBatteryName}</span>
                            <span className="material-icons text-gray-600 text-sm">link</span>
                        </button>
                    </div>
                    <FormInput label="Localização no Mapa" name="location" value={formData.location} onChange={handleChange} placeholder="Ex: G-01, Setor B" />
                </div>
            </div>

            <div>
                <label className="block text-[10px] font-black text-gray-500 uppercase tracking-[0.2em] mb-2 ml-1">Notas e Observações</label>
                <textarea 
                    name="notes" 
                    value={formData.notes} 
                    onChange={handleChange} 
                    rows={3}
                    className="w-full bg-black/40 text-white p-4 rounded-2xl border border-white/5 focus:border-[#EC4899]/50 outline-none transition-all resize-none text-sm placeholder:text-gray-700 shadow-inner"
                    placeholder="Detalhes sobre lote, fornecedor ou características específicas..."
                ></textarea>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                <FormInput label="Voltagem" name="voltage" value={formData.voltage} onChange={handleChange} />
                <FormInput label="Química" name="chemistry" value={formData.chemistry} onChange={handleChange} />
            </div>

            <div className="flex items-center justify-between p-5 bg-red-500/[0.03] rounded-2xl border border-red-500/10">
                <div className="flex flex-col">
                    <span className="text-sm font-black text-red-500 tracking-tight">Status Descontinuado</span>
                    <span className="text-[10px] text-red-500/50 uppercase font-black tracking-widest">Remover das sugestões automáticas</span>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                    <input type="checkbox" name="discontinued" checked={formData.discontinued} onChange={handleChange} className="sr-only peer" />
                    <div className="w-12 h-6 bg-gray-800 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-red-600 shadow-inner"></div>
                </label>
            </div>

            <div className="pt-6 flex flex-col md:flex-row gap-4">
                <button type="button" onClick={onClose} className="flex-1 px-6 py-4 text-gray-500 hover:text-white font-black uppercase tracking-widest text-xs transition-colors">
                    Descartar
                </button>
                <button type="submit" className="flex-[2] px-10 py-4 bg-[#EC4899] hover:bg-[#D61F69] text-white rounded-2xl font-black uppercase tracking-[0.2em] text-xs shadow-2xl shadow-pink-500/20 transition-all active:scale-[0.98] hover:translate-y-[-2px]">
                    Salvar Registro
                </button>
            </div>
        </form>

        {showPicker && (
            <div className="fixed inset-0 z-[110] bg-black/90 backdrop-blur-xl flex items-center justify-center p-4 animate-fade-in">
                <div className="bg-[#141414] w-full max-w-lg rounded-[2.5rem] border border-white/10 shadow-2xl overflow-hidden flex flex-col max-h-[80vh]">
                    <div className="p-6 border-b border-white/5 flex justify-between items-center">
                        <h3 className="text-sm font-black text-white uppercase tracking-widest">Vincular ao Estoque</h3>
                        <button onClick={() => setShowPicker(false)} className="text-gray-500 hover:text-white">
                            <span className="material-icons">close</span>
                        </button>
                    </div>
                    
                    <div className="p-6 space-y-4 flex-1 overflow-hidden flex flex-col">
                        <div className="relative group">
                            <span className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                                <span className="material-icons text-gray-500 text-sm group-focus-within:text-[#EC4899]">search</span>
                            </span>
                            <input 
                                type="text"
                                placeholder="Procurar no estoque..."
                                className="w-full bg-black/40 text-white pl-10 pr-4 py-3 rounded-xl border border-white/5 focus:border-[#EC4899]/50 outline-none text-xs"
                                value={pickerQuery}
                                onChange={(e) => setPickerQuery(e.target.value)}
                            />
                        </div>

                        <div className="flex-1 overflow-y-auto custom-scrollbar space-y-2">
                            <button 
                                type="button"
                                onClick={() => { setFormData(p => ({ ...p, linkedBatteryId: '' })); setShowPicker(false); }}
                                className="w-full flex items-center gap-3 p-3 bg-red-500/5 hover:bg-red-500/10 text-red-500 rounded-xl transition-colors border border-red-500/10"
                            >
                                <span className="material-icons text-sm">link_off</span>
                                <span className="text-xs font-bold uppercase tracking-widest">Remover Vínculo</span>
                            </button>

                            {filteredPickerBatteries.map(b => (
                                <button 
                                    key={b.id}
                                    type="button"
                                    onClick={() => { setFormData(p => ({ ...p, linkedBatteryId: b.id })); setShowPicker(false); }}
                                    className={`w-full flex items-center gap-4 p-3 rounded-2xl border transition-all ${formData.linkedBatteryId === b.id ? 'bg-[#EC4899]/10 border-[#EC4899]/30' : 'bg-white/5 border-white/5 hover:border-white/10'}`}
                                >
                                    <div className="w-10 h-10 rounded-lg bg-black/40 overflow-hidden flex-shrink-0">
                                        {b.imageUrl ? <img src={b.imageUrl} className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-gray-700"><span className="material-icons text-sm">battery_std</span></div>}
                                    </div>
                                    <div className="text-left flex-1 min-w-0">
                                        <p className="text-xs font-bold text-white truncate">{b.name}</p>
                                        <p className="text-[10px] text-gray-500 truncate">{b.brand} • {b.type}</p>
                                    </div>
                                    <div className="text-right">
                                        <p className="text-[10px] font-black text-[#EC4899]">{b.quantity} un</p>
                                    </div>
                                </button>
                            ))}
                        </div>
                    </div>
                </div>
            </div>
        )}
      </div>
    </div>
  );
};

const FormInput = ({ label, icon, ...props }: any) => (
    <div className="space-y-1.5">
        <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest ml-1">{label}</label>
        <div className="relative group/input">
            <input 
                {...props} 
                className={`w-full bg-black/40 text-white p-3.5 rounded-xl border border-white/5 focus:border-[#EC4899]/50 outline-none transition-all text-sm font-medium shadow-inner ${icon ? 'pr-10' : ''} ${props.disabled ? 'opacity-30' : ''}`} 
            />
            {icon && (
                <span className="absolute right-3 top-1/2 -translate-y-1/2 material-icons text-gray-600 text-lg group-focus-within/input:text-[#EC4899] transition-colors">{icon}</span>
            )}
        </div>
    </div>
);