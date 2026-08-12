import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreler eşleşmiyor.'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider).signUp(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            displayName: _displayNameCtrl.text,
          );
      if (mounted) context.go('/dashboard');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapAuthError(e)), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      default:
        return 'Kayıt başarısız: ${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: AppConstants.spacingXl),
                    const Text(
                      'Kayıt Ol',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'SARGE Kulüp Yönetim Sistemine katılın',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: AppConstants.spacingXl),
                    const _FieldLabel('Ad Soyad'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _displayNameCtrl,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Adınız Soyadınız',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'İsim zorunlu';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    const _FieldLabel('E-posta'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'ornek@sarge.org',
                        prefixIcon: Icon(Icons.mail_outline, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'E-posta zorunlu';
                        if (!v.contains('@')) return 'Geçerli bir e-posta girin';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    const _FieldLabel('Şifre'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Şifre en az 6 karakter olmalı' : null,
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    const _FieldLabel('Şifre Tekrar'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) return 'Şifre en az 6 karakter olmalı';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.spacingLg),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style:
                          ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                            )
                          : const Text('Kayıt Ol', style: TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Zaten hesabın var mı?',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        TextButton(
                          onPressed: () => context.push('/login'),
                          child: const Text('Giriş Yap',
                              style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.sargeGold.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.sargeGold.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/sarge_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.hexagon_outlined,
                size: 40, color: AppColors.sargeGold),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}