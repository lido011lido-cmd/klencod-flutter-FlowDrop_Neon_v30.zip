import 'dart:convert';
import 'package:http/http.dart' as http;
import 'native_extractor.dart' show MediaOption;

/// استخراج فيسبوك على الهاتف نفسه (عنوان IP منزلي): فيسبوك يحجب غالبًا عناوين السيرفرات.
/// لا يحتوي أي سر: مجرد قراءة صفحة الفيديو العامة.
class FbLocal {
  static const String _ua = 'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static const Map<String, String> _headers = {
    'User-Agent': _ua,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124"',
    'sec-ch-ua-mobile': '?1',
    'sec-ch-ua-platform': '"Android"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Upgrade-Insecure-Requests': '1',
  };

  static const Map<String, String> _crawler = {
    'User-Agent': 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static Future<List<MediaOption>> options(String raw) async {
    var url = raw.trim();
    if (url.contains('/share/') || url.contains('fb.watch') || url.contains('fb.com/')) {
      url = _canon(await _follow(url));
    } else {
      url = _canon(url);
    }

    final vid = RegExp(r'(?:[?&]v=|/reel/|/videos/)(\d+)').firstMatch(url);
    final attempts = <MapEntry<String, Map<String, String>>>[
      MapEntry(url, _headers),
      MapEntry(
          'https://www.facebook.com/plugins/video.php?height=476&show_text=false&width=476&href=${Uri.encodeComponent(url)}',
          _headers),
      if (vid != null) MapEntry('https://www.facebook.com/video/embed?video_id=${vid.group(1)}', _headers),
      MapEntry(url.replaceFirst('www.facebook.com', 'm.facebook.com'), _headers),
      MapEntry(url.replaceFirst('www.facebook.com', 'mbasic.facebook.com'), _headers),
      MapEntry(url, _crawler),
    ];

    var thumb = '';
    for (final a in attempts) {
      final html = await _fetch(a.key, a.value);
      if (html.isEmpty) continue;
      if (thumb.isEmpty) thumb = _ogImage(html) ?? '';
      final got = _parse(html, thumb)
          .where((o) => !o.url.contains('lookaside.fbsbx.com') && !o.url.contains('/lookaside/crawler'))
          .toList();
      if (got.isNotEmpty) return got;
    }
    return [];
  }

  static Future<String> _fetch(String url, Map<String, String> headers) async {
    try {
      final res = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) return '';
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  static Future<String> _follow(String url, {int maxHops = 10}) async {
    var current = url;
    final client = http.Client();
    try {
      for (var i = 0; i < maxHops; i++) {
        final req = http.Request('GET', Uri.parse(current))
          ..followRedirects = false
          ..headers.addAll(_headers);
        final res = await client.send(req).timeout(const Duration(seconds: 10));
        await res.stream.drain();
        final code = res.statusCode;
        if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
          var loc = res.headers['location'];
          if (loc == null || loc.isEmpty) break;
          if (loc.startsWith('/')) {
            final u = Uri.parse(current);
            loc = '${u.scheme}://${u.host}$loc';
          }
          current = loc;
        } else {
          break;
        }
      }
    } catch (_) {
      // نكتفي بآخر رابط وصلنا إليه.
    } finally {
      client.close();
    }
    return current;
  }

  /// يوحّد رابط فيسبوك: يحافظ على معرّف الفيديو ويحذف بارامترات التتبع.
  static String _canon(String raw) {
    var r = raw;
    final lm = RegExp(r'[?&]next=([^&]+)').firstMatch(r);
    if (r.contains('/login') && lm != null) {
      try {
        r = Uri.decodeComponent(lm.group(1)!);
      } catch (_) {}
    }
    final u = Uri.tryParse(r);
    if (u == null || u.host.isEmpty) return r;
    final v = u.queryParameters['v'];
    if (v != null && v.isNotEmpty) return 'https://www.facebook.com/watch/?v=$v';
    if (u.path.contains('/reel/') || u.path.contains('/videos/')) {
      return 'https://www.facebook.com${u.path}';
    }
    return r;
  }

  /// يحذف bytestart/byteend: وجودهما يجعل الملف مقطعًا صغيرًا بدل الفيديو كاملًا.
  static String _stripRange(String u) {
    final i = u.indexOf('?');
    if (i < 0) return u;
    final kept = u
        .substring(i + 1)
        .split('&')
        .where((p) => !p.startsWith('bytestart=') && !p.startsWith('byteend='))
        .toList();
    return u.substring(0, i) + (kept.isEmpty ? '' : '?${kept.join('&')}');
  }

  static List<MediaOption> _parse(String html, String thumb) {
    if (html.isEmpty) return [];
    final clean = html
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u0025', '%')
        .replaceAll('&amp;', '&');

    String? firstOf(List<String> keys) {
      for (final key in keys) {
        final m = RegExp('"$key"\\s*:\\s*"(https:[^"]+)"').firstMatch(clean);
        if (m != null) return m.group(1);
      }
      return null;
    }

    final out = <MediaOption>[];
    final seenLabels = <String>{};
    void add(String url, String label, int h, {bool audio = true}) {
      if (url.contains('lookaside.fbsbx.com')) return;
      if (seenLabels.add(label)) {
        out.add(MediaOption(url: _stripRange(url), label: label, height: h, hasAudio: audio, thumb: thumb));
      }
    }

    final hd = firstOf(const ['browser_native_hd_url', 'playable_url_quality_hd', 'hd_src_no_ratelimit', 'hd_src']);
    final sd = firstOf(const ['browser_native_sd_url', 'playable_url', 'sd_src_no_ratelimit', 'sd_src']);
    if (hd != null) add(hd, 'HD', 720);
    if (sd != null && sd != hd) add(sd, 'SD', 360);

    // البنية الحديثة: progressive_url مع quality بعدها مباشرة.
    for (final m in RegExp(r'"progressive_url"\s*:\s*"(https:[^"]+)"').allMatches(clean)) {
      final tailEnd = m.end + 200 > clean.length ? clean.length : m.end + 200;
      final tail = clean.substring(m.end, tailEnd);
      final q = RegExp(r'"quality"\s*:\s*"(\w+)"').firstMatch(tail)?.group(1);
      if (q == 'HD') {
        add(m.group(1)!, 'HD', 720);
      } else {
        add(m.group(1)!, 'SD', 360);
      }
    }
    if (out.isNotEmpty) return out;

    final vr = RegExp(r'video_redirect/\?src=([^"&]+)').firstMatch(clean);
    if (vr != null) {
      try {
        final u = Uri.decodeComponent(vr.group(1)!);
        if (u.startsWith('http')) return [MediaOption(url: u, label: 'SD', height: 360, thumb: thumb)];
      } catch (_) {}
    }

    // آخر حل: أي روابط mp4 في الصفحة. مقاطع DASH (bytestart) فيديو بلا صوت غالبًا.
    final seen = <String>{};
    for (final cand in _allMp4(clean)) {
      final key = cand.split('?').first;
      if (!seen.add(key)) continue;
      final dash = cand.contains('bytestart=') || cand.contains('byteend=');
      final int h;
      final String label;
      if (cand.contains('1080') || cand.contains('fhd')) {
        h = 1080;
        label = '1080p';
      } else if (cand.contains('720')) {
        h = 720;
        label = '720p';
      } else if (cand.contains('hd') || cand.contains('HD') || cand.contains('high')) {
        h = 720;
        label = 'HD';
      } else {
        h = 360;
        label = 'SD';
      }
      add(cand, label, h, audio: !dash);
    }
    if (out.isNotEmpty) return out;

    final og = _ogVideo(clean);
    return og == null ? [] : [MediaOption(url: og, label: 'MP4', height: 360, thumb: thumb)];
  }

  static List<String> _allMp4(String html) {
    final out = <String>[];
    var from = 0;
    while (true) {
      final idx = html.indexOf('.mp4', from);
      if (idx < 0) break;
      final h = html.lastIndexOf('https://', idx);
      if (h >= 0 && idx - h < 800) {
        var e = idx + 4;
        while (e < html.length && !'"\')< \n'.contains(html[e])) {
          e++;
        }
        final cand = html.substring(h, e).replaceAll('&amp;', '&');
        if (cand.startsWith('https://') && cand.contains('.mp4')) out.add(cand);
      }
      from = idx + 4;
    }
    return out;
  }

  static String? _ogImage(String html) {
    final h = html.replaceAll('&amp;', '&');
    for (final marker in const [
      'property="og:image" content="',
      'property="og:image:secure_url" content="',
      'name="twitter:image" content="',
    ]) {
      final idx = h.indexOf(marker);
      if (idx >= 0) {
        final st = idx + marker.length;
        final e = h.indexOf('"', st);
        if (e > st) return h.substring(st, e);
      }
    }
    return null;
  }

  static String? _ogVideo(String html) {
    final h = html.replaceAll('&amp;', '&');
    for (final marker in const [
      'property="og:video:secure_url" content="',
      'property="og:video" content="',
      'property="og:video:url" content="',
    ]) {
      final idx = h.indexOf(marker);
      if (idx >= 0) {
        final s = idx + marker.length;
        final e = h.indexOf('"', s);
        if (e > s) {
          final v = h.substring(s, e);
          return v.contains('lookaside.fbsbx.com') ? null : v;
        }
      }
    }
    return null;
  }
}
