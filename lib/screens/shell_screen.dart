import 'dart:async';
import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/download_manager.dart';
import '../services/native_bridge.dart';
import '../services/update_service.dart';
import '../widgets/common.dart';
import '../widgets/neon.dart';
import '../widgets/sheets.dart';
import 'files_tab.dart';
import 'history_tab.dart';
import 'home_tab.dart';
import 'settings_tab.dart';

/// الهيكل الرئيسي: شريط تنقل بأربع تبويبات + استقبال الروابط المشاركة + فحص التحديث.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _tab = 0;
  final GlobalKey<HomeTabState> _homeKey = GlobalKey<HomeTabState>();
  StreamSubscription<DownloadEvent>? _eventSub;
  StreamSubscription<String>? _shareSub;

  @override
  void initState() {
    super.initState();
    NativeBridge.instance.init();
    _eventSub = DownloadManager.instance.events.listen(_onDownloadEvent);
    _shareSub = NativeBridge.instance.sharedText.listen(_onShared);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialShare();
      _checkUpdate();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialShare() async {
    final t = await NativeBridge.instance.initialText();
    if (t != null) _onShared(t);
  }

  void _onShared(String text) {
    final url = extractUrl(text);
    if (url == null || !mounted) return;
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.setUrl(url, openOptions: true);
    });
  }

  void _onDownloadEvent(DownloadEvent e) {
    if (!mounted) return;
    final msg = e.success
        ? '${context.tr('dl_done')}: ${e.name}'
        : '${context.tr('dl_failed')}: ${e.name}';
    showSnack(context, msg);
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService.check();
    if (!mounted || info == null || !info.shouldShow) return;
    await showUpdateDialog(context, info);
  }

  void _openUrlOnHome(String url) {
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.setUrl(url, openOptions: true);
    });
  }

  void _openCenter() {
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.quickLink();
    });
  }

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            IndexedStack(
              index: _tab,
              children: [
                HomeTab(
                  key: _homeKey,
                  onOpenSettings: () => setState(() => _tab = 3),
                  onOpenFiles: () => setState(() => _tab = 1),
                  onOpenHistory: () => setState(() => _tab = 2),
                ),
                const FilesTab(),
                HistoryTab(onRedownload: _openUrlOnHome),
                const SettingsTab(),
              ],
            ),
            if (_tab == 0) ...[
              Positioned(
                right: 8,
                bottom: 86,
                child: NeonFloatingBadge(
                  colors: const [Color(0xFF3B1A78), Color(0xFF120E3B)],
                  ring: AppColors.neonPurple,
                  onTap: () => showSnack(context, context.tr('soon')),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFC53D), size: 26),
                      Text('VIP',
                          style: TextStyle(
                              color: Color(0xFFFF9A3D),
                              fontSize: 10,
                              height: 1,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 18,
                child: NeonFloatingBadge(
                  colors: const [Color(0xFF3A4DFF), Color(0xFF1B1F8A)],
                  ring: AppColors.neonBlue,
                  onTap: _openCenter,
                  child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 30),
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: NeonBottomNav(
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
          onCenter: _openCenter,
        ),
      ),
    );
  }
}
