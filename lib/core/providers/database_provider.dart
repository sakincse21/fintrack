import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/notification_service.dart';
import '../services/recurring_engine_service.dart';
import '../services/sample_data_seeder.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final recurringEngineProvider = Provider<RecurringEngineService>((ref) {
  final db = ref.watch(databaseProvider);
  final notif = ref.watch(notificationServiceProvider);
  return RecurringEngineService(db, notif);
});

final sampleDataSeederProvider = Provider<SampleDataSeeder>((ref) {
  final db = ref.watch(databaseProvider);
  return SampleDataSeeder(db);
});

