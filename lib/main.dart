import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/providers/theme_provider.dart';
import 'core/routing/app_router.dart';
import 'core/routing/notification_router.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Firebase Init (critical — must not fail silently) ---
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, st) {
    debugPrint('FATAL: Firebase init failed: $e\n$st');
    runApp(_ErrorApp(message: 'Firebase başlatılamadı.\n\nHata: ${e.toString()}\n\nİnternet bağlantınızı kontrol edin ve uygulamayı yeniden başlatın.'));
    return;
  }

  // --- Date Formatting (non-fatal) ---
  try {
    await initializeDateFormatting('tr_TR', null);
    Intl.defaultLocale = 'tr_TR';
  } catch (e, st) {
    debugPrint('Date format init failed (non-fatal): $e\n$st');
  }

  // --- Auth Persistence (web only, non-fatal) ---
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (e, st) {
      debugPrint('Auth persistence set failed (non-fatal): $e\n$st');
    }
  }

  // --- Firestore Settings (non-fatal) ---
  try {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true, cacheSizeBytes: 50 * 1024 * 1024);
  } catch (e, st) {
    debugPrint('Firestore settings failed (non-fatal): $e\n$st');
  }

  // --- Notifications (non-fatal) ---
  try {
    await _initNotifications();
  } catch (e, st) {
    debugPrint('Notification init failed (non-fatal): $e\n$st');
  }

  // --- FCM token lifecycle (non-fatal) ---
  try {
    FcmService(FirebaseMessaging.instance, FirebaseFirestore.instance).init();
  } catch (e, st) {
    debugPrint('FCM init failed (non-fatal): $e\n$st');
  }

  // --- Launch App ---
  runApp(const ProviderScope(child: SargeDepoApp()));
}

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Color(0xFFEF4444)),
                const SizedBox(height: 24),
                const Text('SARGE',
                    style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4)),
                const SizedBox(height: 16),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFF1F5F9), fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Android 13+ (API 33) runtime notification permission is requested here;
/// `POST_NOTIFICATIONS` is also declared in the manifest.
Future<void> _initNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await localNotifications.initialize(initSettings);

  final messaging = FirebaseMessaging.instance;

  final permission = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: true,
  );
  debugPrint('FCM permission: ${permission.authorizationStatus}');

  // Android 13+ requires an explicit POST_NOTIFICATIONS runtime permission.
  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  FirebaseMessaging.onMessage.listen((message) {
    _showLocalNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleTappedNotification);
}

/// Same as [FirebaseMessaging.onMessageOpenedApp] but also handles the case
/// where the app was launched from a terminated state via a notification tap.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // No UI action is taken in background; the OS already shows the notification.
}

void _handleTappedNotification(RemoteMessage message) {
  final type = message.data['type'];
  final targetId = targetIdOf(message);
  final location = locationForNotificationType(type);
  debugPrint('Notification tapped: type=$type targetId=$targetId');

  final navigator = rootNavigatorKey.currentState;
  final context = rootNavigatorKey.currentContext;

  if (navigator != null && context != null) {
    final router = GoRouter.of(context);
    router.go(location,
        extra: targetId != null && targetId.isNotEmpty ? targetId : null);
  } else {
    // App is still starting (router not built yet). Stash the target so the
    // splash screen can navigate after its own auth redirect.
    pendingNotificationLocation = location;
    pendingNotificationTargetId =
        targetId != null && targetId.isNotEmpty ? targetId : null;
  }
}

void _showLocalNotification(RemoteMessage message) {
  const androidDetails = AndroidNotificationDetails(
    'announcements',
    'Duyurular',
    channelDescription: 'Yeni duyuru ve görev bildirimleri',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(android: androidDetails);
  localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? 'SARGE',
    message.notification?.body ?? '',
    details,
  );
}

class SargeDepoApp extends ConsumerWidget {
  const SargeDepoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Keyed on the theme mode so that a theme toggle rebuilds the entire
    // widget tree. Screens read theme-aware `AppColors` tokens, which would
    // otherwise stay stale until an unrelated rebuild.
    return MaterialApp.router(
      key: ValueKey('sarge_${themeMode.name}'),
      title: 'SARGE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}