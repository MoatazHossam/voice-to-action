import 'package:get/get.dart';

/// Minimal GetX translations to establish the Arabic-first / RTL pattern.
/// Screen-specific Arabic copy inside modules/ai_intake is written directly
/// as literals (this is a demo shell concern, not a feature dependency) —
/// this file only covers shared chrome strings used by the app shell.
class AppTranslations extends Translations {
  static const String arabicAe = 'ar_AE';
  static const String englishUs = 'en_US';

  @override
  Map<String, Map<String, String>> get keys => {
        arabicAe: _ar,
        englishUs: _en,
      };

  static const Map<String, String> _ar = {
    'app.title': 'إثبات مفهوم: الاستقبال الذكي',
    'common.cancel': 'إلغاء',
    'common.retry': 'إعادة المحاولة',
    'common.back': 'رجوع',
    'common.next': 'متابعة',
    'common.close': 'إغلاق',
    'home.subtitle': 'واجهة تجريبية مستقلة لميزة الاستقبال الذكي (ai_intake)',
    'home.openVoice': 'إدخال صوتي',
    'home.openImage': 'إدخال صورة',
  };

  static const Map<String, String> _en = {
    'app.title': 'POC: AI Intake',
    'common.cancel': 'Cancel',
    'common.retry': 'Retry',
    'common.back': 'Back',
    'common.next': 'Continue',
    'common.close': 'Close',
    'home.subtitle': 'Standalone demo shell around the portable ai_intake feature',
    'home.openVoice': 'Voice entry',
    'home.openImage': 'Image entry',
  };
}
