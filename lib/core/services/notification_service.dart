import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _initialized = true;

    await _scheduleWeeklyMapReminder();
    await _scheduleMonthlyBuyReminder();
  }

  Future<void> _scheduleWeeklyMapReminder() async {
    // ID 1: Map Reminder
    // Schedule for next Monday at 9:00 AM
    var date = _nextInstanceOfMonday(9, 0);
    
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1,
      'Atualizar Mapa',
      'Lembre-se de atualizar o mapa de baterias hoje!',
      date,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_reminders',
          'Lembretes Semanais',
          channelDescription: 'Lembretes para tarefas semanais',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _scheduleMonthlyBuyReminder() async {
    // ID 2-13: Monthly Buy Reminders (Schedule next 12 occurrences)
    // 1st Monday of the month.
    
    List<tz.TZDateTime> dates = _getNextFirstMondays(12, 9, 0);

    for (int i = 0; i < dates.length; i++) {
       await flutterLocalNotificationsPlugin.zonedSchedule(
        2 + i,
        'Comprar Baterias',
        'Hoje é a primeira segunda-feira do mês. Verifique o estoque!',
        dates[i],
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'monthly_reminders',
            'Lembretes Mensais',
            channelDescription: 'Lembretes para tarefas mensais',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> showUpdateNotification(String version, String url) async {
    const int id = 999;
    await flutterLocalNotificationsPlugin.show(
      id,
      'Atualização Disponível',
      'Nova versão $version disponível. Toque para baixar.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'updates',
          'Atualizações',
          channelDescription: 'Notificações de atualização do app',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: url,
    );
  }

  tz.TZDateTime _nextInstanceOfMonday(int hour, int minute) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != DateTime.monday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }

  List<tz.TZDateTime> _getNextFirstMondays(int count, int hour, int minute) {
    List<tz.TZDateTime> dates = [];
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // Start checking from today
    tz.TZDateTime cursor = tz.TZDateTime(tz.local, now.year, now.month, 1, hour, minute);
    
    // If we passed the 1st monday of this month, start next month
    // But first, let's find the 1st monday of the current cursor month
    while (dates.length < count) {
      // Find 1st Monday of cursor.month
      tz.TZDateTime temp = tz.TZDateTime(tz.local, cursor.year, cursor.month, 1, hour, minute);
      while (temp.weekday != DateTime.monday) {
        temp = temp.add(const Duration(days: 1));
      }
      
      // If temp is in the past, ignore and move to next month
      if (temp.isAfter(now)) {
        dates.add(temp);
      }
      
      // Move cursor to next month
      if (cursor.month == 12) {
        cursor = tz.TZDateTime(tz.local, cursor.year + 1, 1, 1, hour, minute);
      } else {
        cursor = tz.TZDateTime(tz.local, cursor.year, cursor.month + 1, 1, hour, minute);
      }
    }
    
    return dates;
  }
}
