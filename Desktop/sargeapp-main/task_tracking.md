# task_tracking.md — v4.4.0 (Play Store hazırlığı)

## AŞAMA 1 — Görev Atama Dialog Çökme Hatası (Bug Fix)
- [x] Hatanın kaynağını bul: `task_add_dialog.dart` → `_buildBoardScopeSelector()`
- [x] `Container(maxHeight: 220)` + `ListView(shrinkWrap: true)` kombinasyonunu kaldır
- [x] `SizedBox(width: double.maxFinite, height: 250)` + `ListView.builder` (shrinkWrap YOK) ile değiştir
- [x] `RenderShrinkWrappingViewport does not support returning intrinsic dimensions` hatasının kök nedenini yorum olarak dosyaya yaz
- [x] `_buildBoardScopeSelector()` listesinde `Container(decoration: BoxDecoration(color: ...))` → `Material(color: ..., shape: ..., clipBehavior: Clip.antiAlias)` yap (ink splash assertion'ı: "ListTile background color or ink splashes may be invisible.")
- [x] Regresyon testi: `test/task_board_scope_layout_test.dart` (4 test — bounded height/shrinkWrap yok + Material surface + seçim toggle)

## AŞAMA 2 — Sürüm Güncellemesi ve Misafir Girişinin Kaldırılması
- [x] `app_constants.dart` → `appVersion = '4.4.0'`
- [x] `pubspec.yaml` → `version: 4.4.0+4`
- [x] `login_screen.dart` → "Misafir olarak devam et" butonunu kaldır
- [x] `auth_providers.dart` → `guestSessionProvider`, `isGuestProvider`, `continueAsGuest` kaldır
- [x] `app_router.dart` → `isGuest` / `_guestAllowedRoutes` mantığını kaldır, `guestSessionProvider` listener'ını kaldır
- [x] `splash_screen.dart` → `isGuest` dalını kaldır
- [x] `app_shell.dart` → çıkış yaparken `guestSessionProvider` sıfırlamayı kaldır

## AŞAMA 3 — Veritabanı ve Model: "Kayıt Onay" Sistemi
- [x] `AppUser` modeline `approvalStatus` alanı ekle
- [x] `approvalPending` / `approvalApproved` / `approvalRejected` sabitlerini ekle
- [x] `isApproved` / `isPendingApproval` / `isRejected` / `needsApproval` getter'larını ekle
- [x] `applyApprovalFallback()` ile null/eksik alan fallback'i = `'approved'` (eski kullanıcılar kilitlenmesin)
- [x] `fromDoc` bu fallback'i kullansın
- [x] `AuthController.signUp` yeni kayıtları `'pending'` olarak yazsın
- [x] `approveUser` / `rejectUser` / `deleteUserDocument` metotlarını ekle
- [x] `pendingApprovalsProvider` (+ `isApprovedProvider`, `isPendingApprovalProvider`) ekle

## AŞAMA 4 — "Onay Bekliyor" Ekranı ve Admin Kontrol Paneli
- [x] `pending_approval_screen.dart` oluştur (koyu/sade tema, logo, durum başlığı, "Durumu Yenile" + "Çıkış Yap")
- [x] Onay bekleyen DİĞER kişilerin listesini bu ekranda göster (kendisi "(siz)" olarak vurgulanır)
- [x] `app_router.dart` → `kPendingApprovalRoute` + `/pending-approval` GoRoute ekle
- [x] `app_router.dart` → 'pending'/'rejected' kullanıcıyı shell'e SOKMAYAN onay guard'ı ekle
- [x] Onaylı kullanıcıyı `/pending-approval`'dan `/dashboard`'a geri yönlendir
- [x] `admin_approvals_tab.dart` oluştur ("Onayla" / "Reddet & Sil" butonları, boş durum, hata durumu)
- [x] `admin_panel_screen.dart` → "Kayıt Onayları" sekmesini ekle (length 6 → 7)
- [x] `firestore.rules` → `approvalStatusOf` / `isApproved` / `isWaitingForApproval` helper'ları
- [x] `firestore.rules` → create kuralı `approvalStatus in ['pending','approved']`
- [x] `firestore.rules` → owner-update dalına kendi kendini onaylamayı engelleyen gate ekle

## Doğrulama
- [x] `flutter analyze` → 0 error (12 issue, hepsi mevcut baseline: cleaning/store/tasks)
- [x] `flutter test` → 26/26 PASS (22 mevcut + 4 yeni `task_board_scope_layout_test.dart`)
- [x] `test/task_board_scope_layout_test.dart` → 4 yeni regresyon testi (ink/Material assertion + bounded height)
- [x] `test/approval_status_test.dart` → 7 yeni regresyon testi (legacy fallback + 3 durum)
- [x] `test/async_value_safety_test.dart` → kaldırılan `isGuestProvider` yerine yeni provider'lar
- [x] `PROJECT_MAP.md` güncellendi

## NOTLAR / BİLİNEN KISITLAR
- Firebase Auth hesabı istemciden silinemez → "Reddet & Sil" sadece Firestore dokümanını siler.
  Kullanıcı tekrar giriş yaparsa `signUp` akışı dokümanı yeniden oluşturur (pending/approved).
- `users` koleksiyonunda `approvalStatus` WHERE sorgusu tek alanlı eşitlik → **composite index GEREKMEZ**.
- `firestore.rules` değişiklikleri deploy edilmeden canlı ortamda etkili olmaz:
  `firebase deploy --only firestore:rules --project sargeapp`
- Bootstrap kuralı: admin yokken ilk kullanıcı `'approved'` yazabilir (yoksa sistem yönetilemez hale gelir).
