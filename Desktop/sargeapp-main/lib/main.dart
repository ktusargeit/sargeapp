import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/providers/theme_provider.dart';
import 'core/routing/app_router.dart';
import 'core/routing/notification_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/local_backend_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

/// Whether the Turkish (`tr_TR`) `intl` locale data was loaded successfully.
///
/// Set by [_initDateFormatting]. When this is `false`, any
/// `DateFormat(pattern, 'tr_TR')` call WILL throw `LocaleDataException`, so UI
/// that formats dates must fall back to a locale-less formatter (see
/// `core/utils/date_format_utils.dart`).
bool intlLocaleReady = false;

/// Loads the `tr_TR` locale data required by every `DateFormat(..., 'tr_TR')`
/// call in the app.
///
/// Retries once (the first call can race with plugin/channel setup on some
/// platforms) and records the outcome in [intlLocaleReady] instead of silently
/// swallowing the failure — a swallowed failure is exactly what used to make
/// the bottom navigation bar vanish.
Future<void> _initDateFormatting() async {
  for (var attempt = 1; attempt <= 2; attempt++) {
    try {
      await initializeDateFormatting('tr_TR', null);
      Intl.defaultLocale = 'tr_TR';
      // Verify it actually took effect: this is the call that throws when the
      // data is missing.
      DateFormat('d MMMM yyyy', 'tr_TR').format(DateTime.now());
      intlLocaleReady = true;
      debugPrint('Date formatting ready (tr_TR), attempt $attempt');
      return;
    } catch (e, st) {
      debugPrint('Date format init attempt $attempt failed: $e');
      if (attempt == 2) {
        debugPrint('Date format init FAILED - falling back to locale-less '
            'formatting. UI will not crash. $st');
      }
    }
  }
  intlLocaleReady = false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('DotEnv load failed: $e');
  }

  // --- Firebase Init (critical — must not fail silently) ---
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, st) {
    debugPrint('FATAL: Firebase init failed: $e\n$st');
    runApp(_ErrorApp(
        message:
            'Firebase başlatılamadı.\n\nHata: ${e.toString()}\n\nİnternet bağlantınızı kontrol edin ve uygulamayı yeniden başlatın.'));
    return;
  }

  // --- Date Formatting (CRITICAL — must NOT be swallowed) ---
  //
  // Every `DateFormat(pattern, 'tr_TR')` call in the app (dashboard header,
  // announcement feed, reports, cleaning, ...) throws `LocaleDataException`
  // ("Locale data has not been initialized") unless the Turkish locale data has
  // been loaded here first.
  //
  // This used to be wrapped in a silent try-catch that CONTINUED on failure.
  // When it failed, `DashboardHeader.build` threw while the shell was building
  // its body, which aborted the whole `AppShell` Scaffold — and so the bottom
  // navigation bar silently disappeared (no visible crash, just a missing bar).
  //
  // Now we (1) initialise it before `runApp`, (2) retry once, and (3) record
  // whether it succeeded so `intlLocaleReady` can be checked by the UI.
  await _initDateFormatting();

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
    FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true, cacheSizeBytes: 50 * 1024 * 1024);
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
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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
  await localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _handleLocalNotificationTap,
  );

  const channel = AndroidNotificationChannel(
    'announcements',
    'Duyurular',
    description: 'Yeni duyuru ve görev bildirimleri',
    importance: Importance.high,
  );
  final androidImplementation = localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidImplementation?.createNotificationChannel(channel);
  await androidImplementation?.requestNotificationsPermission();

  // Replaces the former Cloud Functions (push + weekly jobs) — runs in-app.
  NotificationWatcher(localNotifications).start();

  final messaging = FirebaseMessaging.instance;

  final permission = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: true,
  );
  debugPrint('FCM permission: ${permission.authorizationStatus}');

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
  _navigateForNotification(message.data['type'], targetIdOfMap(message.data));
}

void _handleLocalNotificationTap(NotificationResponse response) {
  final parts = (response.payload ?? '').split('|');
  final type = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;
  final relatedId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  _navigateForNotification(type, relatedId);
}

void _navigateForNotification(String? type, String? targetId) {
  final location = locationForNotificationType(type, relatedId: targetId);
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
      title: 'SARGE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
