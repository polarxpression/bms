import { useEffect, useState } from 'react';
import { batteryService } from '../services/batteryService';
import type { AppNotification } from '../types';

export const Notifications = () => {
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = batteryService.subscribeToNotifications(setNotifications);
    setLoading(false);
    return () => unsub();
  }, []);

  const handleMarkRead = async (id: string) => {
    await batteryService.markNotificationAsRead(id);
  };

  const handleClearAll = async () => {
    if (confirm("Deseja excluir todas as notificações?")) {
      await batteryService.clearAllNotifications();
    }
  };

  const getIcon = (type?: string) => {
    switch (type) {
      case 'update': return 'system_update';
      case 'reminder': return 'alarm';
      case 'system': return 'info_outline';
      default: return 'notifications';
    }
  };

  if (loading) return <div className="p-8 text-center text-gray-500">Carregando notificações...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-black text-white tracking-tight flex items-center">
            <span className="w-8 h-8 rounded-lg bg-[#EC4899]/20 flex items-center justify-center mr-3">
                <span className="material-icons text-sm text-[#EC4899]">notifications</span>
            </span>
            Notificações
        </h2>
        {notifications.length > 0 && (
            <button 
                onClick={handleClearAll}
                className="text-xs font-bold text-red-500 hover:text-red-400 uppercase tracking-widest transition-colors flex items-center"
            >
                <span className="material-icons text-sm mr-1">clear_all</span>
                Limpar Todas
            </button>
        )}
      </div>

      {notifications.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 bg-[#141414]/30 rounded-[2.5rem] border-2 border-dashed border-white/5">
            <div className="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mb-4">
                <span className="material-icons text-3xl text-gray-700">notifications_off</span>
            </div>
            <p className="text-gray-400 font-bold">Nenhuma notificação</p>
            <p className="text-sm text-gray-600 mt-1">Você está em dia com tudo!</p>
        </div>
      ) : (
        <div className="space-y-3">
          {notifications.map((n) => (
            <div 
              key={n.id} 
              onClick={() => !n.isRead && handleMarkRead(n.id)}
              className={`bg-[#141414] p-5 rounded-3xl border ${n.isRead ? 'border-white/5 opacity-60' : 'border-[#EC4899]/30 shadow-lg shadow-pink-500/5'} flex items-start gap-4 transition-all hover:bg-[#1c1c1c] cursor-pointer`}
            >
              <div className={`w-12 h-12 rounded-2xl flex items-center justify-center shrink-0 ${n.isRead ? 'bg-white/5 text-gray-600' : 'bg-[#EC4899]/20 text-[#EC4899]'}`}>
                <span className="material-icons">{getIcon(n.type)}</span>
              </div>
              <div className="flex-1">
                <div className="flex items-center justify-between mb-1">
                    <h3 className={`font-bold ${n.isRead ? 'text-gray-400' : 'text-white'}`}>{n.title}</h3>
                    <span className="text-[10px] font-medium text-gray-600 uppercase tracking-wider">
                        {n.timestamp?.toDate ? n.timestamp.toDate().toLocaleString('pt-BR') : new Date(n.timestamp).toLocaleString('pt-BR')}
                    </span>
                </div>
                <p className={`text-sm ${n.isRead ? 'text-gray-500' : 'text-gray-300'} leading-relaxed`}>{n.message}</p>
                {n.actionUrl && (
                    <a 
                        href={n.actionUrl} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        className="inline-flex items-center mt-3 text-xs font-black text-[#EC4899] uppercase tracking-widest hover:underline"
                    >
                        Ver Detalhes
                        <span className="material-icons text-xs ml-1">open_in_new</span>
                    </a>
                )}
              </div>
              {!n.isRead && (
                <div className="w-2 h-2 rounded-full bg-[#EC4899] shadow-[0_0_8px_#EC4899] mt-2"></div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
