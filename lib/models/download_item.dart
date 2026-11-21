import 'dart:convert';

enum DownloadStatus { downloading, paused, failed }

/// تحميل جارٍ (يعيش في الذاكرة حتى يكتمل ثم ينتقل للسجل).
class DownloadItem {
  final int id;
  final String sourceUrl;
  final String directUrl;
  final String stem; // اسم الملف بدون الامتداد
  final String ext; // بدون نقطة
  final bool isAudio;
  final String platform;
  final String partPath;
  final String thumbUrl;
  final bool extractAudio; // يُستخرج الصوت من الفيديو بعد اكتماله
  final String quality; // مثل 720p أو audio

  DownloadStatus status = DownloadStatus.downloading;
  int downloaded = 0;
  int total = -1;
  String? error;
  double speedBps = 0; // بايت/ثانية
  int? etaSeconds; // الوقت المتبقي
  bool pauseRequested = false;
  bool cancelRequested = false;

  DownloadItem({
    required this.id,
    required this.sourceUrl,
    required this.directUrl,
    required this.stem,
    required this.ext,
    required this.isAudio,
    required this.platform,
    required this.partPath,
    this.thumbUrl = '',
    this.extractAudio = false,
    this.quality = '',
  });

  String get fileName => '$stem.$ext';

  /// نسبة التقدم 0..1 أو null إذا كان الحجم الكلي غير معروف.
  double? get progress =>
      total > 0 ? (downloaded / total).clamp(0.0, 1.0).toDouble() : null;
}

/// عنصر محفوظ في سجل التحميلات.
class HistoryEntry {
  final int id;
  final String fileName;
  final String sourceUrl;
  final String filePath;
  final String platform;
  final bool isAudio;
  final int sizeBytes;
  final int dateMs;
  final String thumb; // مسار محلي أو رابط، وقد يكون فارغًا
  final String quality;

  const HistoryEntry({
    required this.id,
    required this.fileName,
    required this.sourceUrl,
    required this.filePath,
    required this.platform,
    required this.isAudio,
    required this.sizeBytes,
    required this.dateMs,
    this.thumb = '',
    this.quality = '',
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'sourceUrl': sourceUrl,
        'filePath': filePath,
        'platform': platform,
        'isAudio': isAudio,
        'sizeBytes': sizeBytes,
        'dateMs': dateMs,
        'thumb': thumb,
        'quality': quality,
      };

  String encode() => jsonEncode(toJson());

  static HistoryEntry? decode(String s) {
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return HistoryEntry(
        id: (m['id'] as num).toInt(),
        fileName: (m['fileName'] ?? '').toString(),
        sourceUrl: (m['sourceUrl'] ?? '').toString(),
        filePath: (m['filePath'] ?? '').toString(),
        platform: (m['platform'] ?? 'web').toString(),
        isAudio: m['isAudio'] == true,
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
        dateMs: (m['dateMs'] as num?)?.toInt() ?? 0,
        thumb: (m['thumb'] ?? '').toString(),
        quality: (m['quality'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
