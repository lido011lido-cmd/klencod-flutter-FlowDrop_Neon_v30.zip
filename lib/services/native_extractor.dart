import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' show YoutubeExplode;

import '../core/utils.dart';
import 'fb_local.dart';
import 'package:http/http.dart' as http;

/// جودة واحدة متاحة فعليًا للفيديو.
class MediaOption {
  final String url;
  final String label; // نص قصير ASCII مثل 720p أو HD (يُستعمل أيضًا في اسم الملف)
  final int height; // 0 إذا غير معروف (للترتيب فقط)
  final int sizeBytes; // 0 إذا غير معروف
  final bool hasAudio;
  final bool audioOnly; // ملف صوت فقط
  final String? ext; // امتداد مُحدَّد إن لم يظهر من الرابط
  final String thumb; // صورة مصغرة (رابط) إن وُجدت
  const MediaOption({
    required this.url,
    required this.label,
    required this.height,
    this.sizeBytes = 0,
    this.hasAudio = true,
    this.audioOnly = false,
    this.ext,
    this.thumb = '',
  });

  MediaOption withSize(int size) => MediaOption(
        url: url,
        label: label,
        height: height,
        sizeBytes: size,
        hasAudio: hasAudio,
        audioOnly: audioOnly,
        ext: ext,
        thumb: thumb,
      );

  factory MediaOption.fromJson(Map<String, dynamic> m) => MediaOption(
        url: (m['url'] ?? '').toString(),
        label: (m['label'] ?? 'MP4').toString(),
        height: (m['height'] as num?)?.toInt() ?? 0,
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
        hasAudio: m['hasAudio'] != false,
        audioOnly: m['audioOnly'] == true,
        ext: m['ext']?.toString(),
        thumb: (m['thumb'] ?? '').toString(),
      );
}

/// اختيار المستخدم من نافذة الجودات: فيديو بجودة محددة أو صوت فقط.
class MediaPick {
  final MediaOption? option; // null عند اختيار الصوت
  final bool audio;
  const MediaPick.video(MediaOption o)
      : option = o,
        audio = false;
  const MediaPick.audio()
      : option = null,
        audio = true;
}

/// عميل رفيع: كل منطق الاستخراج والواجهات الخارجية على السيرفر.
/// كل طلب موقَّع (HMAC-SHA256) بسر مشترك مع السيرفر، ويحمل معرّف جهاز ووقتًا وnonce،
/// والسيرفر يضع حدودًا للاستعمال لكل جهاز ولكل IP.
class NativeExtractor {
  static const String _server =
      String.fromEnvironment('FD_SERVER', defaultValue: 'http://78.154.103.45:11987');

  // السر المشترك مخزَّن مموَّهًا (XOR) وليس نصًا صريحًا داخل الملف المترجم.
  static const List<int> _blob = [250, 244, 239, 200, 167, 217, 114, 208, 70, 112, 229, 131, 230, 170, 232, 100, 251, 253, 224, 155, 175, 139, 38, 134, 70, 43, 224, 213, 179, 253, 185, 101, 248, 253, 188, 205, 166, 141, 39, 213, 70, 35, 224, 217, 229, 175, 237, 105, 168, 169, 232, 159, 255, 220, 116, 133, 68, 113, 179, 209, 179, 250, 186, 103];
  static const List<int> _mask = [224, 217, 18, 201, 228, 220, 233, 128, 174, 131, 205, 113, 80, 16, 152, 158];
  static String get _secret => String.fromCharCodes([
        for (var i = 0; i < _blob.length; i++) _blob[i] ^ _mask[(i * 7 + 3) % _mask.length],
      ]);

  static const String _ua = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36';

  /// سبب آخر فشل: nosetup | denied | rate | server (أو null).
  static String? lastFailure;

  /// تفاصيل تقنية قصيرة عن آخر فشل (للتشخيص).
  static String? lastDetail;

  /// يُرجع الجودات المتاحة فعليًا للرابط (الأعلى أولًا). قائمة فارغة إذا فشل الاستخراج.
  static Future<List<MediaOption>> options(String url) async {
    List<MediaOption> list;
    lastFailure = null;
    lastDetail = null;
    final isYoutube = platformOf(url.trim()) == 'youtube';
    try {
      if (isYoutube) {
        // يوتيوب: يُستخرج على الجهاز نفسه (روابطه مقيّدة بعنوان IP الذي طلبها).
        list = await _youtube(url.trim());
      } else if (platformOf(url.trim()) == 'facebook') {
        // فيسبوك يحجب عناوين السيرفرات، فنجرب على الهاتف أولًا ثم السيرفر.
        list = [];
        try {
          list = await FbLocal.options(url.trim());
        } catch (_) {}
        if (list.isEmpty) list = await _remote(url.trim());
      } else {
        list = await _remote(url.trim());
      }
    } catch (e) {
      lastFailure ??= isYoutube ? 'youtube' : 'server';
      lastDetail = e.toString();
      list = [];
    }
    list = list.where((o) => o.url.startsWith('http')).toList();
    if (list.isEmpty) return list;

    // حجم كل ملف الفعلي عبر HEAD (بالتوازي) إن لم يكن معروفًا.
    final sized = await Future.wait(list.map((o) async {
      if (o.sizeBytes > 0) return o;
      final size = await _probeSize(o.url);
      return size > 0 ? o.withSize(size) : o;
    }));
    sized.sort((a, b) {
      if (a.audioOnly != b.audioOnly) return a.audioOnly ? 1 : -1;
      return b.height.compareTo(a.height);
    });
    return sized;
  }

  static Future<List<MediaOption>> _remote(String url) async {
    if (_server.isEmpty) {
      lastFailure = 'nosetup';
      return [];
    }
    final dev = await _deviceId();
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = _rand(24);
    final sig = Hmac(sha256, utf8.encode(_secret))
        .convert(utf8.encode('$dev.$ts.$nonce.$url'))
        .toString();
    final res = await http
        .post(
          Uri.parse('$_server/v1/resolve'),
          headers: {
            'Content-Type': 'application/json',
            'X-FD-Dev': dev,
            'X-FD-Ts': '$ts',
            'X-FD-Nonce': nonce,
            'X-FD-Sig': sig,
          },
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 45));
    if (res.statusCode == 401) {
      lastFailure = 'denied';
      return [];
    }
    if (res.statusCode == 429) {
      lastFailure = 'rate';
      return [];
    }
    if (res.statusCode != 200) {
      lastFailure = 'server';
      return [];
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final list = data is Map ? data['options'] : null;
    if (list is! List) return [];
    if (list.isEmpty && data is Map && (data['hint'] ?? '').toString().isNotEmpty) {
      lastDetail = data['hint'].toString(); // سبب الفشل كما رآه السيرفر
    }
    return [
      for (final m in list)
        if (m is Map) MediaOption.fromJson(Map<String, dynamic>.from(m)),
    ];
  }

  /// يوتيوب: جودات الفيديو المدمجة بالصوت + ملف صوت. الرابط داخليًا yt://معرّف/itag
  /// ويُحمَّل عبر مكتبة الاستخراج نفسها (انظر DownloadManager).
  static Future<List<MediaOption>> _youtube(String url) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url).timeout(const Duration(seconds: 25));
      final manifest = await yt.videos.streamsClient
          .getManifest(video.id)
          .timeout(const Duration(seconds: 35));
      final id = video.id.value;
      final thumb = video.thumbnails.highResUrl;
      final out = <MediaOption>[];

      final muxed = manifest.muxed.toList()
        ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
      final seen = <int>{};
      for (final s in muxed) {
        final h = s.videoResolution.height;
        if (!seen.add(h)) continue;
        out.add(MediaOption(
          url: 'yt://$id/${s.tag}',
          label: '${h}p',
          height: h,
          sizeBytes: s.size.totalBytes,
          ext: s.container.name,
          thumb: thumb,
        ));
      }

      final audios = manifest.audioOnly.toList();
      if (audios.isNotEmpty) {
        final mp4 = audios.where((a) => a.container.name == 'mp4').toList();
        final pool = mp4.isNotEmpty ? mp4 : audios;
        pool.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        final a = pool.first;
        out.add(MediaOption(
          url: 'yt://$id/${a.tag}',
          label: 'M4A',
          height: 0,
          sizeBytes: a.size.totalBytes,
          audioOnly: true,
          ext: a.container.name == 'mp4' ? 'm4a' : a.container.name,
          thumb: thumb,
        ));
      }
      return out;
    } finally {
      yt.close();
    }
  }

  static String? _dev;

  static String _rand(int n) {
    final r = Random.secure();
    const c = '0123456789abcdef';
    return List.generate(n, (_) => c[r.nextInt(16)]).join();
  }

  /// معرّف عشوائي للجهاز يُنشأ مرة واحدة ويُحفظ (للحدود اليومية على السيرفر).
  static Future<String> _deviceId() async {
    if (_dev != null) return _dev!;
    final p = await SharedPreferences.getInstance();
    var id = p.getString('fd_dev');
    if (id == null || !RegExp(r'^[a-f0-9]{16,64}$').hasMatch(id)) {
      id = _rand(32);
      await p.setString('fd_dev', id);
    }
    return _dev = id;
  }

  static Future<int> _probeSize(String url) async {
    try {
      final res = await http
          .head(Uri.parse(url), headers: const {'User-Agent': _ua})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode >= 400) return 0;
      return int.tryParse(res.headers['content-length'] ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
