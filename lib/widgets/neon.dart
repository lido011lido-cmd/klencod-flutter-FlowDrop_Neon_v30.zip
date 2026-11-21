import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/download_item.dart';
import '../services/download_manager.dart';
import 'common.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FlowDrop Neon — عناصر الواجهة الجديدة (مطابقة للتصميم المرجعي)
// ─────────────────────────────────────────────────────────────────────────────

/// ألوان العناصر النيون في الوضعين الداكن والفاتح.
class NeonPalette {
  final bool dark;
  const NeonPalette(this.dark);
  static NeonPalette of(BuildContext c) => NeonPalette(c.isDark);

  Color get text => dark ? Colors.white : AppColors.textLight;
  Color get muted => dark ? const Color(0xFF9FB6E3) : AppColors.mutedLight;
  Color get subBlue => dark ? const Color(0xFF5AA2FF) : AppColors.primary;
  Color get border => dark
      ? AppColors.neonBlue.withOpacity(.55)
      : AppColors.primary.withOpacity(.30);
  Color get track => dark ? AppColors.trackBlue.withOpacity(.55) : Colors.black12;
  Color get stripFill =>
      dark ? const Color(0xFF0A1B4A).withOpacity(.65) : const Color(0xFFEAF1FF);
  LinearGradient get cardFill => dark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF06194A), Color(0xFF020C2C)],
        )
      : const LinearGradient(colors: [Colors.white, Color(0xFFF1F6FF)]);
}

String formatSpeed(double bps) => '${formatBytes(bps.round())}/s';

String formatEta(int? seconds) {
  if (seconds == null) return '--:--:--';
  String two(int n) => n.toString().padLeft(2, '0');
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '${two(h)}:${two(m)}:${two(s)}';
}

Widget _glow(Color c, double opacity, double size) => IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.withOpacity(opacity), Colors.transparent]),
        ),
      ),
    );

/// خلفية التطبيق: تدرج أزرق داكن مع توهج بنفسجي/أزرق.
class NeonBackground extends StatelessWidget {
  final Widget child;
  const NeonBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!context.isDark) return ColoredBox(color: AppColors.bgLight, child: child);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF01010C), Color(0xFF020A24), Color(0xFF00102B), Color(0xFF000C2A)],
          stops: [0, .25, .6, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -90, right: -70, child: _glow(AppColors.neonPurple, .24, 280)),
          Positioned(bottom: 140, left: -100, child: _glow(AppColors.neonBlue, .16, 300)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// بطاقة نيون بحدود زرقاء متوهجة.
class NeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double radius;
  final bool glow;
  final VoidCallback? onTap;
  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.radius = 22,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = NeonPalette.of(context);
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: p.cardFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          if (glow && p.dark)
            BoxShadow(color: AppColors.neonBlue.withOpacity(.28), blurRadius: 24, spreadRadius: 1),
          if (glow && p.dark)
            BoxShadow(
                color: AppColors.neonPurple.withOpacity(.18),
                blurRadius: 30,
                offset: const Offset(8, 8)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

// ───────────────────────────── الترويسة ─────────────────────────────

class _SunsetPainter extends CustomPainter {
  const _SunsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2A8F), Color(0xFF4B3AA8), Color(0xFF8A3E9E), Color(0xFFFF8A3D)],
          stops: [0, .4, .72, 1],
        ).createShader(rect),
    );
    final sun = Offset(w * .5, h * .8);
    canvas.drawCircle(
      sun,
      w * .38,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xCCFFD9A0), Color(0x00FFB070)],
        ).createShader(Rect.fromCircle(center: sun, radius: w * .38)),
    );
    canvas.drawCircle(sun, 5, Paint()..color = const Color(0xFFFFF6DC));

    final hills = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * .86)
      ..cubicTo(w * .2, h * .78, w * .35, h * .9, w * .55, h * .84)
      ..cubicTo(w * .75, h * .78, w * .9, h * .88, w, h * .82)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFF1A1440));

    final rock = Path()
      ..moveTo(w * .1, h)
      ..lineTo(w * .2, h * .8)
      ..lineTo(w * .45, h * .74)
      ..lineTo(w * .64, h * .82)
      ..lineTo(w * .82, h)
      ..close();
    final dark = Paint()..color = const Color(0xFF06061A);
    canvas.drawPath(rock, dark);

    // شخص جالس (ظل).
    final px = w * .38, py = h * .76;
    canvas.drawCircle(Offset(px, py - h * .2), h * .06, dark);
    final torso = Path()
      ..moveTo(px - h * .1, py)
      ..quadraticBezierTo(px - h * .12, py - h * .14, px - h * .04, py - h * .15)
      ..lineTo(px + h * .05, py - h * .15)
      ..quadraticBezierTo(px + h * .14, py - h * .12, px + h * .12, py)
      ..close();
    canvas.drawPath(torso, dark);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(px + h * .1, py - h * .05), width: h * .18, height: h * .1),
      dark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _fade(Widget child, Alignment begin, Alignment end, List<double> stops) {
  return ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => LinearGradient(
      begin: begin,
      end: end,
      colors: const [Colors.transparent, Colors.black],
      stops: stops,
    ).createShader(r),
    child: child,
  );
}

/// الترويسة: الشعار + الاسم + الصورة الغروب + الملف الشخصي + الإشعارات.
class NeonHeader extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onBell;
  final bool showDot;
  const NeonHeader({
    super.key,
    required this.onProfile,
    required this.onBell,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = NeonPalette.of(context);
    return SizedBox(
      height: 142,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (p.dark)
            Positioned(
              top: 0,
              right: -18,
              width: 270,
              height: 150,
              child: _fade(
                _fade(
                  const CustomPaint(painter: _SunsetPainter()),
                  Alignment.centerLeft,
                  Alignment.centerRight,
                  const [0, .6],
                ),
                Alignment.bottomCenter,
                Alignment.topCenter,
                const [0, .5],
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _logo(),
                    const SizedBox(width: 12),
                    Expanded(child: _titles(context, p)),
                    _avatar(),
                    const SizedBox(width: 10),
                    _bell(p),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 76,
            child: Transform.rotate(
              angle: -.36,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('slogan'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.dark ? Colors.white : AppColors.textLight,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(Icons.favorite_border_rounded,
                      size: 16, color: AppColors.neonPink.withOpacity(.9)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() => Container(
        width: 66,
        height: 66,
        padding: const EdgeInsets.all(2.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.neonBlue, AppColors.neonPurple],
          ),
          boxShadow: [
            BoxShadow(color: AppColors.neonPurple.withOpacity(.45), blurRadius: 18),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
        ),
      );

  Widget _titles(BuildContext context, NeonPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Flow',
                  style: TextStyle(
                      color: p.text, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [AppColors.neonCyan, AppColors.neonBlue, AppColors.neonPurple],
                ).createShader(r),
                child: const Text('Drop',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1.1)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            context.tr('tagline_home'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.text.withOpacity(.9), fontSize: 11.5, height: 1.3),
          ),
        ],
      );

  Widget _avatar() => GestureDetector(
        onTap: onProfile,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.neonCyan, AppColors.neonBlue],
            ),
            border: Border.all(color: Colors.white.withOpacity(.85), width: 1.6),
            boxShadow: [BoxShadow(color: AppColors.neonCyan.withOpacity(.4), blurRadius: 12)],
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
        ),
      );

  Widget _bell(NeonPalette p) => GestureDetector(
        onTap: onBell,
        child: SizedBox(
          width: 34,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.notifications_none_rounded, color: p.text, size: 28),
              if (showDot)
                Positioned(
                  top: 8,
                  right: 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: Color(0xFFFF3B5C), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      );
}

// ───────────────────────────── الإجراءات السريعة ─────────────────────────────

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const QuickAction(this.icon, this.label, this.color, this.onTap);
}

class NeonQuickBar extends StatelessWidget {
  final List<QuickAction> actions;
  const NeonQuickBar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final p = NeonPalette.of(context);
    return NeonCard(
      radius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      glow: true,
      child: Row(
        children: [
          for (final a in actions)
            Expanded(
              child: InkResponse(
                onTap: a.onTap,
                radius: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [a.color.withOpacity(.32), a.color.withOpacity(.06)],
                        ),
                        border: Border.all(color: a.color.withOpacity(.9), width: 1.6),
                        boxShadow: [
                          if (p.dark) BoxShadow(color: a.color.withOpacity(.35), blurRadius: 14),
                        ],
                      ),
                      child: Icon(a.icon, color: a.color, size: 29),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: a.color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── الدائرة + شريط التقدم ─────────────────────────────

class _RingPainter extends CustomPainter {
  final double? value;
  const _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: c, radius: r);

    // حلقة خارجية خافتة + توهج.
    canvas.drawCircle(
      c,
      r + 9,
      Paint()
        ..color = const Color(0xFF1C1F80).withOpacity(.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      c,
      r + 3,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, AppColors.neonPurple.withOpacity(.18)],
          stops: const [.8, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r + 14)),
    );

    final track = Paint()
      ..color = AppColors.trackBlue.withOpacity(.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(c, r, track);

    final v = (value ?? 1.0).clamp(0.0, 1.0).toDouble();
    if (v <= 0) return;
    final shader = const SweepGradient(
      colors: [AppColors.neonCyan, AppColors.neonBlue, AppColors.neonPurple, AppColors.neonPink],
      transform: GradientRotation(-math.pi / 2),
    ).createShader(rect);
    final sweep = 2 * math.pi * v;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

/// دائرة التقدم الكبيرة مع زر في المنتصف.
class NeonRing extends StatelessWidget {
  final double? value;
  final double size;
  final IconData icon;
  final VoidCallback? onTap;
  const NeonRing({
    super.key,
    required this.value,
    required this.icon,
    this.size = 100,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size(size, size), painter: _RingPainter(value)),
            Container(
              width: size * .5,
              height: size * .5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B1F6E), Color(0xFF050E3A)],
                ),
                border: Border.all(color: AppColors.neonBlue.withOpacity(.6), width: 1.2),
              ),
              child: Icon(icon, color: Colors.white, size: size * .28),
            ),
          ],
        ),
      ),
    );
  }
}

class NeonProgressBar extends StatelessWidget {
  final double? value;
  final double height;
  const NeonProgressBar({super.key, required this.value, this.height = 7});

  @override
  Widget build(BuildContext context) {
    final p = NeonPalette.of(context);
    if (value == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          minHeight: height,
          backgroundColor: p.track,
          valueColor: const AlwaysStoppedAnimation(AppColors.neonCyan),
        ),
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(height),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value!.clamp(0.0, 1.0).toDouble(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.progressGradient,
            borderRadius: BorderRadius.circular(height),
            boxShadow: [
              if (p.dark) BoxShadow(color: AppColors.neonCyan.withOpacity(.35), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── الصورة المصغّرة ─────────────────────────────

class NeonThumb extends StatelessWidget {
  final String thumb;
  final String platform;
  final double width;
  final double height;
  final bool audio;
  const NeonThumb({
    super.key,
    required this.thumb,
    required this.platform,
    this.width = 74,
    this.height = 60,
    this.audio = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = platformVisual(platform);
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [v.color.withOpacity(.55), const Color(0xFF1B2A8F)],
        ),
      ),
      child: Icon(v.icon, color: Colors.white.withOpacity(.85), size: height * .5),
    );
    Widget err(BuildContext _, Object __, StackTrace? ___) => fallback;
    Widget img = fallback;
    if (thumb.isNotEmpty) {
      img = thumb.startsWith('http')
          ? Image.network(thumb, width: width, height: height, fit: BoxFit.cover, errorBuilder: err)
          : Image.file(File(thumb), width: width, height: height, fit: BoxFit.cover, errorBuilder: err);
    }
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: width, height: height, child: img),
          ),
          if (audio)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(.92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
            )
          else
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(.7), width: 1.2),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── بطاقة التحميل الرئيسية ─────────────────────────────

String _qualityLabel(DownloadItem it) {
  final q = it.quality;
  if (q.isEmpty || q == 'original' || q == 'audio') return it.isAudio ? 'MP3' : it.ext.toUpperCase();
  return q;
}

class NeonHeroCard extends StatelessWidget {
  final DownloadItem? item;
  final VoidCallback onNew;
  const NeonHeroCard({super.key, required this.item, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final it = item;
    if (it == null) return _idle(context);
    final p = NeonPalette.of(context);
    final mgr = DownloadManager.instance;
    final failed = it.status == DownloadStatus.failed;
    final paused = it.status == DownloadStatus.paused;
    final prog = it.progress;
    final pct = prog == null ? '' : '${(prog * 100).round()}%';
    final ringIcon = failed
        ? Icons.refresh_rounded
        : (paused ? Icons.play_arrow_rounded : Icons.pause_rounded);
    final VoidCallback ringTap =
        (failed || paused) ? () => mgr.resume(it) : () => mgr.pause(it);

    return NeonCard(
      radius: 30,
      glow: true,
      padding: const EdgeInsets.fromLTRB(12, 14, 8, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              NeonThumb(thumb: it.thumbUrl, platform: it.platform, width: 66, height: 66, audio: it.isAudio),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.text, fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(it.isAudio ? 'MP3' : it.ext.toUpperCase(), p),
                        if (!it.isAudio) _chip(_qualityLabel(it), p),
                        Text(
                          it.total > 0 ? formatBytes(it.total) : '—',
                          style: TextStyle(color: p.muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: NeonProgressBar(value: failed ? 0 : prog)),
                        const SizedBox(width: 8),
                        Text(pct, style: TextStyle(color: p.text, fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    failed
                        ? Text(
                            context.tr('failed'),
                            style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                          )
                        : Row(
                            children: [
                              const Icon(Icons.download_rounded, color: AppColors.neonCyan, size: 17),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  paused ? context.tr('paused') : formatSpeed(it.speedBps),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: p.muted, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.schedule_rounded, color: p.muted, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  formatEta(it.etaSeconds),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: p.muted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              NeonRing(value: failed ? 0 : prog, icon: ringIcon, size: 96, onTap: ringTap),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: p.stripFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border.withOpacity(.4)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _stat(Icons.cloud_download_rounded, context.tr('downloaded_lbl'),
                      formatBytes(it.downloaded), p),
                  _divider(p),
                  _stat(Icons.alarm_rounded, context.tr('remaining_lbl'),
                      formatEta(it.etaSeconds), p),
                  _divider(p),
                  _stat(Icons.folder_special_rounded, context.tr('folder_lbl'),
                      '/Download/FlowDrop', p),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t, NeonPalette p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.neonBlue.withOpacity(.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t, style: TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );

  Widget _divider(NeonPalette p) =>
      VerticalDivider(width: 10, thickness: 1, color: p.border.withOpacity(.35));

  Widget _stat(IconData icon, String label, String value, NeonPalette p) => Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.neonBlue, size: 24),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.muted, fontSize: 10.5)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _idle(BuildContext context) {
    final p = NeonPalette.of(context);
    return NeonCard(
      radius: 30,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('start_new'),
                    style: TextStyle(color: p.text, fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(context.tr('start_new_hint'),
                    style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5)),
                const SizedBox(height: 12),
                _GradientPill(label: context.tr('quick_link'), icon: Icons.link_rounded, onTap: onNew),
              ],
            ),
          ),
          const SizedBox(width: 8),
          NeonRing(value: 0, icon: Icons.add_rounded, size: 96, onTap: onNew),
        ],
      ),
    );
  }
}

class _GradientPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GradientPill({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(.35), blurRadius: 14)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── عناوين الأقسام ─────────────────────────────

class NeonSectionHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final int count;
  final VoidCallback? onViewAll;
  const NeonSectionHeader({
    super.key,
    required this.leading,
    required this.title,
    required this.count,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final p = NeonPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.navy2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.neonBlue.withOpacity(.6)),
                    ),
                    child: Text('$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left_rounded, color: p.subBlue, size: 22),
                  Text(context.tr('view_all'),
                      style: TextStyle(
                          color: p.subBlue, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// أيقونة القسم "التنزيلات الجارية" (أعمدة صوتية ملوّنة).
class NeonBarsIcon extends StatelessWidget {
  const NeonBarsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    const hs = [12.0, 24.0, 32.0, 20.0, 10.0];
    return SizedBox(
      width: 34,
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < hs.length; i++)
            Container(
              width: 4,
              height: hs[i],
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.neonPink, AppColors.neonPurple],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NeonCheckIcon extends StatelessWidget {
  const NeonCheckIcon({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(.9), width: 1.8),
          boxShadow: [BoxShadow(color: AppColors.success.withOpacity(.45), blurRadius: 12)],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
      );
}

// ───────────────────────────── صفوف التحميل ─────────────────────────────

class NeonActiveRow extends StatelessWidget {
  final DownloadItem item;
  const NeonActiveRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final p = NeonPalette.of(context);
    final mgr = DownloadManager.instance;
    final failed = item.status == DownloadStatus.failed;
    final paused = item.status == DownloadStatus.paused;
    final prog = item.progress;
    final pct = prog == null ? '' : '${(prog * 100).round()}%';
    final sub = [
      if (item.total > 0) formatBytes(item.total),
      _qualityLabel(item),
    ].join('  •  ');

    return NeonCard(
      margin: const EdgeInsets.only(bottom: 10),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      child: Row(
        children: [
          NeonThumb(thumb: item.thumbUrl, platform: item.platform, width: 74, height: 62, audio: item.isAudio),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(failed ? context.tr('failed') : (paused ? context.tr('paused') : sub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: failed ? AppColors.danger : p.subBlue, fontSize: 12.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: NeonProgressBar(value: failed ? 0 : prog, height: 6)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(pct, style: TextStyle(color: p.text, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: (failed || paused) ? () => mgr.resume(item) : () => mgr.pause(item),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D2A7A),
                border: Border.all(color: AppColors.neonBlue.withOpacity(.5)),
              ),
              child: Icon(
                failed
                    ? Icons.refresh_rounded
                    : (paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert_rounded, color: p.muted),
            onSelected: (v) {
              if (v == 'cancel') mgr.cancel(item);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'cancel', child: Text(ctx.tr('cancel'))),
            ],
          ),
        ],
      ),
    );
  }
}

class NeonCompletedRow extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  const NeonCompletedRow({
    super.key,
    required this.entry,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = NeonPalette.of(context);
    final q = entry.quality.isEmpty || entry.quality == 'original' || entry.quality == 'audio'
        ? (entry.isAudio ? 'MP3' : '')
        : entry.quality;
    final sub = [formatBytes(entry.sizeBytes), if (q.isNotEmpty) q].join('  •  ');

    return NeonCard(
      margin: const EdgeInsets.only(bottom: 10),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      onTap: onPlay,
      child: Row(
        children: [
          NeonThumb(
              thumb: entry.thumb, platform: entry.platform, width: 74, height: 58, audio: entry.isAudio),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(sub, style: TextStyle(color: p.subBlue, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
          const SizedBox(width: 4),
          Text(context.tr('done_label'),
              style: const TextStyle(
                  color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w700)),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert_rounded, color: p.muted),
            onSelected: (v) {
              if (v == 'play') onPlay();
              if (v == 'remove') onRemove();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'play', child: Text(ctx.tr('play'))),
              PopupMenuItem(value: 'remove', child: Text(ctx.tr('remove_from_list'))),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── أزرار عائمة (VIP / صاروخ) ─────────────────────────────

class NeonFloatingBadge extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final Color ring;
  final VoidCallback onTap;
  const NeonFloatingBadge({
    super.key,
    required this.child,
    required this.colors,
    required this.ring,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(color: ring, width: 1.8),
          boxShadow: [BoxShadow(color: ring.withOpacity(.4), blurRadius: 14)],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ───────────────────────────── الشريط السفلي ─────────────────────────────

class _NavPainter extends CustomPainter {
  final bool dark;
  const _NavPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cx = w / 2;
    const s = 18.0; // ارتفاع حافة الجانبين
    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, s + 30)
      ..quadraticBezierTo(0, s, 30, s)
      ..lineTo(cx - 104, s)
      ..cubicTo(cx - 64, s, cx - 52, 0, cx, 0)
      ..cubicTo(cx + 52, 0, cx + 64, s, cx + 104, s)
      ..lineTo(w - 30, s)
      ..quadraticBezierTo(w, s, w, s + 30)
      ..lineTo(w, h)
      ..close();
    final rect = Offset.zero & size;

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF071A5E), Color(0xFF030B2E)]
              : const [Colors.white, Color(0xFFEAF1FF)],
        ).createShader(rect),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = const LinearGradient(
        colors: [AppColors.neonBlue, AppColors.neonPurple, AppColors.neonBlue],
      ).createShader(rect);
    if (dark) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..shader = stroke.shader,
      );
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _NavPainter old) => old.dark != dark;
}

class NeonBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onCenter;
  const NeonBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onCenter,
  });

  @override
  Widget build(BuildContext context) {
    final p = NeonPalette.of(context);
    final inset = MediaQuery.of(context).padding.bottom;
    const barH = 76.0;
    const over = 36.0;

    Widget item(int i, IconData icon, IconData activeIcon, String key) {
      final sel = i == index;
      final color = sel ? AppColors.neonBlue : (p.dark ? const Color(0xFF8FA8D8) : AppColors.mutedLight);
      return Expanded(
        child: InkResponse(
          onTap: () => onChanged(i),
          radius: 36,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  sel ? activeIcon : icon,
                  color: color,
                  size: 28,
                  shadows: sel && p.dark
                      ? [Shadow(color: AppColors.neonBlue.withOpacity(.9), blurRadius: 14)]
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(key),
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: barH + over + inset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: barH + inset,
              child: CustomPaint(painter: _NavPainter(p.dark)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: inset,
              height: barH - 8,
              child: Row(
                children: [
                  item(0, Icons.home_outlined, Icons.home_rounded, 'tab_home'),
                  item(1, Icons.folder_outlined, Icons.folder_rounded, 'tab_files'),
                  const SizedBox(width: 88),
                  item(2, Icons.schedule_rounded, Icons.schedule_rounded, 'tab_history'),
                  item(3, Icons.settings_outlined, Icons.settings_rounded, 'tab_settings'),
                ],
              ),
            ),
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onCenter,
                  child: Container(
                    width: 66,
                    height: 66,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          AppColors.neonBlue,
                          AppColors.neonPurple,
                          AppColors.neonCyan,
                          AppColors.neonBlue,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(color: AppColors.neonBlue.withOpacity(.55), blurRadius: 20),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF050E3A),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
