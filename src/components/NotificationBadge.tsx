import { useEffect, useState } from 'react';
import { batteryService } from '../services/batteryService';

export const NotificationBadge = () => {
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    const unsub = batteryService.subscribeToNotifications((notifications) => {
      const count = notifications.filter(n => !n.isRead).length;
      setUnreadCount(count);
    });
    return () => unsub();
  }, []);

  if (unreadCount === 0) return null;

  return (
    <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-pink-500 text-[10px] font-bold text-white shadow-lg shadow-pink-500/50">
      {unreadCount}
    </span>
  );
};
