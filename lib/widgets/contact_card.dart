import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/contact_config.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import 'common.dart';

/// بطاقة "تواصل مع المطور": واتساب وتليجرام.
class ContactCard extends StatelessWidget {
  const ContactCard({super.key});

  static const _whatsappGreen = Color(0xFF25D366);
  static const _telegramBlue = Color(0xFF229ED9);

  Future<void> _open(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) showSnack(context, context.tr('err_generic'));
    } catch (_) {
      if (context.mounted) showSnack(context, context.tr('err_generic'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wa = ContactConfig.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final tg = ContactConfig.telegram.trim().replaceAll('@', '');
    if (wa.isEmpty && tg.isEmpty) return const SizedBox.shrink();

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.gradient,
                ),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('contact_dev'),
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('contact_sub'),
                      style: TextStyle(color: context.mutedColor, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (wa.isNotEmpty)
                Expanded(
                  child: _button(
                    context,
                    color: _whatsappGreen,
                    icon: Icons.chat_rounded,
                    label: context.tr('whatsapp'),
                    onTap: () => _open(
                      context,
                      'https://wa.me/$wa?text=${Uri.encodeComponent(context.tr('contact_msg'))}',
                    ),
                  ),
                ),
              if (wa.isNotEmpty && tg.isNotEmpty) const SizedBox(width: 10),
              if (tg.isNotEmpty)
                Expanded(
                  child: _button(
                    context,
                    color: _telegramBlue,
                    icon: Icons.send_rounded,
                    label: context.tr('telegram'),
                    onTap: () => _open(context, 'https://t.me/$tg'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: context.textColor,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
