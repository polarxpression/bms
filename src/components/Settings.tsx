import { useEffect, useState } from 'react';
import { batteryService } from '../services/batteryService';
import type { AppSettings } from '../types';

export const Settings = () => {
  const [settings, setSettings] = useState<AppSettings>({
    defaultGondolaCapacity: 20,
    defaultMinStockThreshold: 10,
    daysToAnalyze: 90
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const unsub = batteryService.subscribeToSettings((s) => {
      setSettings(s);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await batteryService.updateSettings(settings);
      alert("Configurações salvas com sucesso!");
    } catch (err) {
      console.error(err);
      alert("Erro ao salvar configurações.");
    } finally {
      setSaving(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value, type } = e.target;
    const val = type === 'number' ? Number(value) : value;
    setSettings((prev: AppSettings) => ({ ...prev, [name]: val }));
  };

  if (loading) return <div className="p-8 text-center text-gray-500">Carregando configurações...</div>;

  return (
    <div className="max-w-2xl mx-auto">
        <form onSubmit={handleSave} className="space-y-6 bg-[#141414] p-8 rounded-2xl border border-white/5 shadow-xl">
            <h2 className="text-xl font-bold text-white flex items-center mb-6">
                <span className="material-icons mr-2 text-[#EC4899]">settings</span>
                Ajustes do Sistema
            </h2>

            <div className="space-y-4">
                <div>
                    <label className="block text-xs font-black text-gray-400 uppercase tracking-[0.2em] mb-3 ml-1">Integração ImgBB</label>
                    <div className="relative group">
                        <span className="material-icons absolute left-4 top-1/2 -translate-y-1/2 text-gray-500 group-focus-within:text-pink-500 transition-colors">vpn_key</span>
                        <input 
                            type="password" 
                            name="imgbbApiKey" 
                            value={settings.imgbbApiKey || ''} 
                            onChange={(e) => setSettings(prev => ({ ...prev, imgbbApiKey: e.target.value }))}
                            placeholder="Chave da API para upload de imagens..."
                            className="w-full bg-black/40 text-white pl-12 pr-4 py-3.5 rounded-2xl border border-white/5 focus:border-pink-500 outline-none transition-all placeholder:text-gray-700 font-mono text-sm" 
                        />
                    </div>
                    <p className="text-[10px] text-gray-600 mt-2 ml-1">Obtenha sua chave em <a href="https://api.imgbb.com/" target="_blank" className="text-pink-500 hover:underline">api.imgbb.com</a></p>
                </div>

                <div>
                    <label className="block text-xs font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Capacidade Padrão da Gôndola</label>
                    <input 
                        type="number" 
                        name="defaultGondolaCapacity" 
                        value={settings.defaultGondolaCapacity} 
                        onChange={handleChange}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/5 focus:border-[#EC4899] outline-none font-mono" 
                    />
                    <p className="text-[10px] text-gray-500 mt-1 ml-1 italic">Usado quando um item não possui limite específico definido.</p>
                </div>

                <div>
                    <label className="block text-xs font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Estoque Mínimo Padrão</label>
                    <input 
                        type="number" 
                        name="defaultMinStockThreshold" 
                        value={settings.defaultMinStockThreshold} 
                        onChange={handleChange}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/5 focus:border-[#EC4899] outline-none font-mono" 
                    />
                    <p className="text-[10px] text-gray-500 mt-1 ml-1 italic">Nível crítico para alerta de reposição externa (compra).</p>
                </div>

                <div>
                    <label className="block text-xs font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Dias para Análise de Consumo</label>
                    <input 
                        type="number" 
                        name="daysToAnalyze" 
                        value={settings.daysToAnalyze} 
                        onChange={handleChange}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/5 focus:border-[#EC4899] outline-none font-mono" 
                    />
                    <p className="text-[10px] text-gray-500 mt-1 ml-1 italic">Período retroativo usado para calcular o consumo médio mensal.</p>
                </div>
            </div>

            <div className="pt-6">
                <button 
                    type="submit" 
                    disabled={saving}
                    className="w-full py-4 bg-[#EC4899] hover:bg-[#D61F69] disabled:opacity-50 text-white rounded-xl font-black uppercase tracking-[0.2em] shadow-lg shadow-pink-900/20 transition-all active:scale-[0.98]"
                >
                    {saving ? 'Salvando...' : 'Salvar Alterações'}
                </button>
            </div>
        </form>
    </div>
  );
};
