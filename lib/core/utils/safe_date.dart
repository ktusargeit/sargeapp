import 'package:intl/intl.dart';

/// Fail-safe date formatting helpers.
///
/// WHY THIS EXISTS — THE "BOTTOM NAVIGATION BAR DISAPPEARS" BUG
/// -----------------------------------------------------------
/// Every `DateFormat(pattern, 'tr_TR')` call throws `LocaleDataException`
/// ("Locale data has not been initialized, call initializeDateFormatting")
/// unless `initializeDateFormatting('tr_TR')` has completed successfully.
///
/// `DashboardHeader.build` formatted a date with an explicit `'tr_TR'` locale.
/// When the locale data was missing, that widget threw **while `AppShell` was
/// building its body**, so Flutter aborted the entire `Scaffold` build — and
/// with it the `bottomNavigationBar`. There was no visible crash: only the bar
/// vanished.
///
/// These helpers make date formatting **total**: they try the Turkish locale
/// and transparently fall back to a locale-less (still Turkish-ordered) format
/// instead of throwing. Any widget that formats a date MUST use them so a
/// missing/uninitialised locale can never take down the shell again.
class SafeDate {
  SafeDate._();

  /// `d MMMM yyyy, EEEE` in Turkish, e.g. "27 Eylül 2026, Pazar".
  static String longWithWeekday(DateTime date) =>
      _format('d MMMM yyyy, EEEE', date, fallback: 'd MMMM yyyy');

  /// `d MMMM` in Turkish, e.g. "27 Eylül".
  static String dayMonth(DateTime date) =>
      _format('d MMMM', date, fallback: 'd MMM');

  /// `dd MMM yyyy` in Turkish, e.g. "27 Eyl 2026".
  static String dayShortMonthYear(DateTime date) =>
      _format('dd MMM yyyy', date, fallback: 'dd/MM/yyyy');

  /// `dd MMM yyyy, HH:mm` in Turkish.
  static String dayShortMonthYearTime(DateTime date) =>
      _format('dd MMM yyyy, HH:mm', date, fallback: 'dd/MM/yyyy HH:mm');

  /// `dd MMMM yyyy, HH:mm` in Turkish.
  static String dayMonthYearTime(DateTime date) =>
      _format('dd MMMM yyyy, HH:mm', date, fallback: 'dd/MM/yyyy HH:mm');

  /// `dd MMM HH:mm` in Turkish.
  static String dayShortMonthTime(DateTime date) =>
      _format('dd MMM HH:mm', date, fallback: 'dd/MM HH:mm');

  /// `d MMMM, HH:mm` in Turkish.
  static String dayMonthCommaTime(DateTime date) =>
      _format('d MMMM, HH:mm', date, fallback: 'dd/MM HH:mm');

  /// `dd.MM.yyyy` — locale-independent numeric format.
  static String numericDate(DateTime date) =>
      _format('dd.MM.yyyy', date, fallback: 'dd.MM.yyyy');

  /// Formats [date] with the Turkish locale, falling back to [fallback]
  /// (a locale-less pattern) when the locale data is unavailable.
  ///
  /// Never throws.
  static String _format(
    String pattern,
    DateTime date, {
    required String fallback,
  }) {
    try {
      return DateFormat(pattern, 'tr_TR').format(date);
    } catch (_) {
      // Locale data missing -> use the locale-less pattern. `DateFormat` with
      // the default (en_US) locale is always available.
      try {
        return DateFormat(fallback).format(date);
      } catch (_) {
        // Even the fallback failed -> return the ISO-ish date so UI never
        // crashes (last line of defence; keeps the shell alive).
        return '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.'
            '${date.year}';
      }
    }
  }
}
