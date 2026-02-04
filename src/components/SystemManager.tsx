import { useEffect } from 'react';
import { db } from '../firebase/client';
import { 
  collection, 
  doc, 
  getDoc, 
  setDoc, 
  addDoc, 
  serverTimestamp 
} from 'firebase/firestore';

export const SystemManager = () => {
  useEffect(() => {
    const checkScheduledNotifications = async () => {
      const now = new Date();
      // Monday = 1
      if (now.getDay() === 1) {
        const todayStr = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
        const settingsCollection = collection(db, 'settings');
        const configRef = doc(settingsCollection, 'notifications_run');
        
        try {
          const configDoc = await getDoc(configRef);
          const data = configDoc.exists() ? configDoc.data() : {};
          
          const lastWeeklyRun = data.lastWeeklyRun;
          const lastMonthlyRun = data.lastMonthlyRun;

          // 1. Weekly Map Update (Every Monday)
          if (lastWeeklyRun !== todayStr) {
            await addDoc(collection(db, 'notifications'), {
              title: 'Atualizar Mapa',
              message: 'Lembrete semanal: Por favor, atualize o mapa de baterias.',
              type: 'reminder',
              isRead: false,
              timestamp: serverTimestamp()
            });
            await setDoc(configRef, { lastWeeklyRun: todayStr }, { merge: true });
          }

          // 2. Monthly Buy (1st Monday of Month)
          if (now.getDate() <= 7) {
            const monthKey = `${now.getFullYear()}-${now.getMonth() + 1}`;
            if (lastMonthlyRun !== monthKey) {
              await addDoc(collection(db, 'notifications'), {
                title: 'Comprar Baterias',
                message: 'Primeira segunda-feira do mês. Verifique o estoque e faça compras se necessário.',
                type: 'reminder',
                isRead: false,
                timestamp: serverTimestamp()
              });
              await setDoc(configRef, { lastMonthlyRun: monthKey }, { merge: true });
            }
          }
        } catch (err) {
          console.error("SystemManager error:", err);
        }
      }
    };

    checkScheduledNotifications();
  }, []);

  return null; // Background component
};
