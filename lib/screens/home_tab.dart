import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_scope.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/download_item.dart';
import '../services/cobalt_service.dart';
import '../services/download_manager.dart';
import '../services/guard.dart';
import '../services/native_bridge.dart';
import '../services/native_extractor.dart';
import '../services/history_store.dart';
import '../widgets/common.dart';
import '../widgets/neon.dart';
import '../widgets/sheets.dart';
import 'player_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenHistory;
  const HomeTab({
    super.key,
    required this.onOpenSettings,
    required this.onOpenFiles,
    required this.onOpenHistory,
  });

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final TextEditingController _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// زر "لصق الرابط": يلصق من الحافظة ويبدأ، وإن لم يوجد رابط يفتح نافذة إدخال.
  Future<void> quickLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final fromClip = data?.text == null ? null : extractUrl(data!.text!);
    if (fromClip != null) {
      setUrl(fromClip, openOptions: true);
      return;
    }
    if (!mounted) return;
    final typed = await _askLink();
    if (typed == null || !mounted) return;
    final url = extractUrl(typed);
    if (url == null) {
      showSnack(context, context.tr('invalid_url'));
      return;
    }
    setUrl(url, openOptions: true);
  }

  Future<String?> _askLink() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.isDark ? const Color(0xFF06194A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.neonBlue.withOpacity(.6)),
        ),
        title: Text(ctx.tr('quick_link'),
            style: TextStyle(color: ctx.textColor, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (v) => Navigator.pop(ctx, v),
          style: TextStyle(color: ctx.textColor),
          decoration: InputDecoration(
            hintText: ctx.tr('paste_hint'),
            hintStyle: TextStyle(color: ctx.mutedColor),
            prefixIcon: const Icon(Icons.link_rounded, color: AppColors.neonCyan),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: Text(ctx.tr('download'),
                style: const TextStyle(color: AppColors.neonCyan, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// يستدعيه الهيكل عند استقبال رابط مشارك أو "إعادة تحميل" من السجل.
  void setUrl(String url, {bool openOptions = false}) {
    _ctrl.text = url;
    setState(() {});
    if (openOptions) _onDownload();
  }

  Future<void> _onDownload() async {
    if (_busy) return;
    final settings = AppScope.of(context);
    final mgr = DownloadManager.instance;

    final url = extractUrl(_ctrl.text.trim());
    if (url == null) {
      showSnack(context, context.tr('invalid_url'));
      return;
    }
    if (!mgr.canStart) {
      showSnack(context, context.tr('max_active'));
      return;
    }

    // حماية: لا نكمل إن كان الجهاز يعترض الاتصال أو يفحص التطبيق (في نسخة release فقط).
    if (await Guard.blocked()) {
      if (mounted) showSnack(context, context.tr('guard_blocked'));
      return;
    }

    // رابط مباشر لملف وسائط: لا حاجة لأي محرك.
    if (isDirectMediaUrl(url)) {
      await mgr.start(
        directUrl: url,
        sourceUrl: url,
        isAudio: isAudioExt(extensionOf(Uri.parse(url).path) ?? ''),
        quality: 'original',
      );
      if (mounted) setState(() => _ctrl.clear());
      return;
    }

    // محرك API خاص: نسأل عن النوع/الجودة أولًا (المحرك لا يعرض الجودات مسبقًا).
    DownloadChoice? choice;
    if (settings.useEngine) {
      choice = await showDownloadOptions(context);
      if (choice == null || !mounted) return;
      await settings.saveChoice(
        audio: choice.audio,
        quality: choice.quality,
        bitrate: choice.bitrate,
      );
    }

    setState(() => _busy = true);
    CobaltException? engineError;
    try {
      if (choice != null) {
        try {
          final result = await CobaltService.resolve(
            url: url,
            endpoint: settings.endpoint,
            apiKey: settings.apiKey,
            audio: choice.audio,
            quality: choice.quality,
            bitrate: choice.bitrate,
          );
          if (!mounted) return;
          CobaltPickerItem? picked;
          if (result.isPicker) {
            picked = await showPickerSheet(context, result.items);
            if (picked == null) return;
          } else {
            picked = result.items.first;
          }
          await mgr.start(
            directUrl: picked.url,
            sourceUrl: url,
            isAudio: choice.audio || picked.type == 'audio',
            quality: choice.quality,
            suggestedName: result.isPicker ? null : result.filename,
          );
          if (mounted) setState(() => _ctrl.clear());
          return;
        } on CobaltException catch (e) {
          engineError = e; // نجرب التحميل المدمج بعده
        }
      }

      // التحميل المدمج: نفحص الرابط ونعرض الجودات الحقيقية المتاحة له.
      final options = await NativeExtractor.options(url);
      if (!mounted) return;
      if (options.isEmpty) {
        throw engineError ??
            CobaltException(NativeExtractor.lastFailure ??
                (platformOf(url) == 'web' ? 'unsupported' : 'fetch'));
      }
      final picked = await showQualitySheet(context, options);
      if (picked == null || !mounted) return;
      final thumb = options.first.thumb;

      if (picked.audio) {
        MediaOption? direct;
        for (final o in options) {
          if (o.audioOnly) {
            direct = o;
            break;
          }
        }
        if (direct != null) {
          await mgr.start(
            directUrl: direct.url,
            sourceUrl: url,
            isAudio: true,
            quality: 'audio',
            forceExt: direct.ext,
            thumbUrl: thumb,
          );
        } else {
          // نحمّل أصغر فيديو فيه صوت ثم نستخرج منه الصوت.
          final vids = options.where((o) => !o.audioOnly && o.hasAudio).toList()
            ..sort((a, b) => a.height.compareTo(b.height));
          if (vids.isEmpty) {
            showSnack(context, context.tr('audio_err'));
            return;
          }
          await mgr.start(
            directUrl: vids.first.url,
            sourceUrl: url,
            isAudio: true,
            quality: 'audio',
            extractAudio: true,
            thumbUrl: thumb,
          );
        }
      } else {
        final o = picked.option!;
        await mgr.start(
          directUrl: o.url,
          sourceUrl: url,
          isAudio: false,
          quality: o.label,
          thumbUrl: thumb,
        );
      }
      if (mounted) setState(() => _ctrl.clear());
    } on CobaltException catch (e) {
      if (!mounted) return;
      final key = 'err_${e.code}';
      final msg = context.tr(key);
      final needsSettings = e.code == 'auth' || e.code == 'network';
      final detail = e.code == 'unsupported' ? null : NativeExtractor.lastDetail;
      final base = msg == key ? context.tr('err_generic') : msg;
      showSnack(
        context,
        detail == null
            ? base
            : '$base\n${detail.length > 160 ? detail.substring(0, 160) : detail}',
        actionLabel: needsSettings ? context.tr('open_settings') : null,
        onAction: needsSettings ? widget.onOpenSettings : null,
      );
    } catch (_) {
      if (mounted) showSnack(context, context.tr('err_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _play(HistoryEntry e) async {
    if (!await File(e.filePath).exists()) {
      if (mounted) showSnack(context, context.tr('file_missing'));
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(path: e.filePath, title: e.fileName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppScope.of(context).isArabic;
    final actions = [
      QuickAction(Icons.link_rounded, context.tr('quick_link'), AppColors.neonCyan, quickLink),
      QuickAction(Icons.music_note_rounded, context.tr('quick_audio'), const Color(0xFFB45CFF), quickLink),
      QuickAction(Icons.play_arrow_rounded, context.tr('quick_video'), const Color(0xFFFF4F9A), quickLink),
      QuickAction(Icons.folder_open_rounded, context.tr('quick_files'), const Color(0xFF1FE0B5), widget.onOpenFiles),
    ];
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: Listenable.merge([DownloadManager.instance, HistoryStore.instance]),
        builder: (context, _) {
          final active = DownloadManager.instance.active;
          final recent = HistoryStore.instance.entries.take(3).toList();
          final hasFailed = active.any((e) => e.status == DownloadStatus.failed);
          final p = NeonPalette.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: NeonHeader(
                  onProfile: widget.onOpenSettings,
                  onBell: () => showSnack(context, context.tr('soon')),
                  showDot: hasFailed,
                ),
              ),
              NeonQuickBar(actions: isAr ? actions.reversed.toList() : actions),
              const SizedBox(height: 14),
              Directionality(
                textDirection: TextDirection.ltr,
                child: NeonHeroCard(
                  item: active.isEmpty ? null : active.first,
                  onNew: quickLink,
                ),
              ),
              NeonSectionHeader(
                leading: const NeonBarsIcon(),
                title: context.tr('active_title'),
                count: active.length,
                onViewAll: widget.onOpenHistory,
              ),
              if (active.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(context.tr('no_recent'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.muted, height: 1.6)),
                )
              else
                for (final it in active)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: NeonActiveRow(key: ValueKey(it.id), item: it),
                  ),
              NeonSectionHeader(
                leading: const NeonCheckIcon(),
                title: context.tr('completed_downloads'),
                count: HistoryStore.instance.entries.length,
                onViewAll: widget.onOpenHistory,
              ),
              for (final e in recent)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: NeonCompletedRow(
                    key: ValueKey(e.id),
                    entry: e,
                    onPlay: () => _play(e),
                    onRemove: () => HistoryStore.instance.remove(e.id),
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                context.tr('legal'),
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 11.5, height: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }
}
