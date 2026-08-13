import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';

class LocationScreen extends ConsumerWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Lokasyonlar'), backgroundColor: AppColors.surface),
      body:  Center(
        child: Text('Lokasyon yönetimi', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}