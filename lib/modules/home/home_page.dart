import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_routes.dart';
import 'home_controller.dart';

/// Demo shell landing page. This and the rest of modules/home are NOT part
/// of the portable feature — they exist only to host and demonstrate
/// modules/ai_intake in this standalone POC.
class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إثبات مفهوم: الاستقبال الذكي')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'واجهة تجريبية مستقلة حول ميزة ai_intake القابلة لإعادة الاستخدام. '
                'لا تُنفَّذ أي إجراءات حقيقية من هذا التطبيق.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => controller.openRoute(AppRoutes.aiIntakeVoice),
                icon: const Icon(Icons.mic_none),
                label: const Text('إدخال صوتي'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => controller.openRoute(AppRoutes.aiIntakeImage),
                icon: const Icon(Icons.image_outlined),
                label: const Text('إدخال صورة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
