import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/store_models.dart';
import '../providers/store_providers.dart';

/// Mağaza Ayarları — IBAN listesi yönetimi.
/// 
/// Sadece `manageStore` yetkisine sahip kullanıcılar bu ekrana erişebilir.
class StoreSettingsScreen extends ConsumerStatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  final _ibanCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ibanCtrl.dispose();
    _accountHolderCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _addIban() async {
    final iban = _ibanCtrl.text.trim().replaceAll(' ', '');
    final holder =
        _accountHolderCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (iban.isEmpty) return;
    setState(() => _loading = true);
    try {
      final current = await ref.read(storeRepositoryProvider).loadIbans();
      if (current.any((e) => e.iban == iban)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Bu IBAN zaten listede.'),
                  backgroundColor: AppColors.warning));
        }
        _ibanCtrl.clear();
        _accountHolderCtrl.clear();
        _labelCtrl.clear();
        return;
      }
      await ref.read(storeRepositoryProvider).saveIbans([
        ...current,
        IbanEntry(
          iban: iban,
          accountHolderName: holder,
          label: _labelCtrl.text.trim(),
        ),
      ]);
      _ibanCtrl.clear();
      _accountHolderCtrl.clear();
      _labelCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('IBAN eklendi.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeIban(String iban) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('IBAN\'ı Sil'),
        content: Text('"$iban" silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final current = await ref.read(storeRepositoryProvider).loadIbans();
      await ref
          .read(storeRepositoryProvider)
          .saveIbans(current.where((e) => e.iban != iban).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('IBAN silindi.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mağaza Ayarları'),
        backgroundColor: AppColors.surface,
      ),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('IBAN Listesi',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Kullanıcılar sipariş verirken bu IBAN\'lara havale/EFT yapar.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            // Add IBAN
            TextField(
              controller: _ibanCtrl,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Yeni IBAN *',
                hintText: 'TR00 0000 0000 0000 0000 0000 00',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountHolderCtrl,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Hesap Sahibi Adı *',
                hintText: 'Örn: Muhammet Mete Aksoy',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _labelCtrl,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Etiket (opsiyonel)',
                hintText: 'Örn: Kulüp Kasası',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _loading || _accountHolderCtrl.text.trim().isEmpty
                    ? null
                    : _addIban,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('IBAN Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sargeGold,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // IBAN list
            if (settings.ibans.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    'Henüz IBAN eklenmedi.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              ...settings.ibans.map((entry) => Card(
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.account_balance,
                          color: AppColors.sargeGold),
                      title: SelectableText(entry.displayText,
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        tooltip: 'Sil',
                        onPressed: _loading ? null : () => _removeIban(entry.iban),
                      ),
                    ),
                  )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}