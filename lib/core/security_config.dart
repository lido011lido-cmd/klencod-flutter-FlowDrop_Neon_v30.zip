/// إعدادات الحماية. غيّر القيم حسب رغبتك.
class SecurityConfig {
  /// منع التحميل أثناء تشغيل VPN. أدوات الاعتراض مثل Reqable وPCAPdroid تعمل عبر VPN،
  /// لكن مستخدمين عاديين كثيرين يستعملون VPN أيضًا، فضعها false إن أزعجهم ذلك.
  static const bool blockOnVpn = true;

  /// منع التحميل عند وجود وكيل (proxy) أو مصحح أخطاء أو Frida.
  static const bool blockOnProxyOrDebugger = true;

  // ───────── freeRASP (حماية وقت التشغيل) ─────────

  /// اسم الحزمة المتوقَّع للتطبيق.
  static const String packageName = 'com.smali.fox';

  /// بصمة شهادة توقيع نسخة release (SHA-256 بصيغة Base64).
  /// القيمة الحالية مجرد مثال: استبدلها ببصمة مفتاحك (انظر SECURITY_AR.md)،
  /// وإلا يتجاهل التطبيق فحص "التلاعب بالتطبيق".
  static const String _exampleHash = 'AKoRuyLMM91E7lX/Zqp3u4jMmd0A7hH/Iqozu0TMVd0=';
  static const String signingCertHash = _exampleHash;
  static bool get signingConfigured => signingCertHash != _exampleHash;

  /// بريد تقارير Talsec (اختياري لكن مطلوب في الإعداد). ضع بريدك.
  static const String watcherMail = 'security@example.com';

  /// منع الميزات عند اكتشاف: روت / محاكي / تعديل التطبيق (إعادة توقيع).
  static const bool blockOnRoot = true;
  static const bool blockOnEmulator = false; // مستخدمو المحاكيات على الحاسوب كثيرون
  static const bool blockOnTamper = true;
}
