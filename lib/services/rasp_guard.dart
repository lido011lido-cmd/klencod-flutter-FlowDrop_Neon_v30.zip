import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:freerasp/freerasp.dart';
import '../core/security_config.dart';

/// حماية وقت التشغيل عبر freeRASP: Hooks (Frida) / Debug / Root / تعديل التطبيق.
/// تعمل في نسخة release على أندرويد فقط. التهديدات المكتشفة تمنع الشبكة عبر Guard.
class RaspGuard {
  static final Set<String> threats = <String>{};
  static final Completer<void> _ready = Completer<void>();

  static bool get compromised => threats.isNotEmpty;

  static void _done() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// ينتظر انتهاء الفحوص الأولى (بحد أقصى 4 ثوانٍ).
  static Future<void> waitReady() =>
      _ready.future.timeout(const Duration(seconds: 4), onTimeout: () {});

  static Future<void> start() async {
    if (!kReleaseMode || !Platform.isAndroid) {
      _done();
      return;
    }
    try {
      final config = TalsecConfig(
        androidConfig: AndroidConfig(
          packageName: SecurityConfig.packageName,
          signingCertHashes: [SecurityConfig.signingCertHash],
        ),
        watcherMail: SecurityConfig.watcherMail,
        isProd: true,
        killOnBypass: true,
      );

      final callback = ThreatCallback(
        onHooks: () => threats.add('hooks'),
        onDebug: () => threats.add('debug'),
        onPrivilegedAccess: () {
          if (SecurityConfig.blockOnRoot) threats.add('root');
        },
        onSimulator: () {
          if (SecurityConfig.blockOnEmulator) threats.add('emulator');
        },
        onAppIntegrity: () {
          if (SecurityConfig.signingConfigured && SecurityConfig.blockOnTamper) {
            threats.add('tamper');
          }
        },
      );
      Talsec.instance.attachListener(callback);
      Talsec.instance.attachExecutionStateListener(
        RaspExecutionStateCallback(onAllChecksFinished: _done),
      );
      await Talsec.instance.start(config);
    } catch (_) {
      _done(); // فشل التشغيل لا يوقف التطبيق
    }
  }
}
