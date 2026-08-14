# PROJECT_MAP.md — SARGE Depo App

Projenin "haritası". Her yeni görevde önce bu dosya okunur ve gerektiğinde güncellenir.

## 1. Klasör Yapısı Özeti

- `lib/core/` — tema (AppColors), sabitler, modeller (AppUser, UserProfile), routing, genel widget'lar, permission sistemi, auth/firestore provider'ları.
- `lib/features/tasks/` — görev ekranları, modelleri ve provider'ları (görev oluşturma, yorumlar, onaylama).
- `lib/features/team/` — takımlar, birimler (units), üyeler, takım/birim ekranları ve provider'ları.
- `lib/features/inventory/` — depo/envanter ürünleri, lokasyonlar, kategoriler, durumlar.
- `lib/features/announcements/` — duyurular ve yorumları.
- `lib/features/notifications/` — uygulama içi bildirimler + FCM cihaz token'ları.
- `lib/features/admin/` — admin paneli, üye yönetimi, ünvan yönetimi, başvuru onayları.
- `lib/features/about/` — hakkımızda bölümleri ve üyeleri.
- `lib/features/contact/` — iletişim bilgileri.
- `lib/features/reports/` — hata/öneri raporları ve mesajları.
- `lib/settings/` — uygulama ayarları ekranı.
- `functions/` — Cloud Functions (FCM push bildirimleri).

## 2. Önemli Dosyalar

- `lib/features/tasks/screens/tasks_screen.dart` — Tüm Görevler ekranı + görev detay sheet'i + görev oluşturma dialog'u. Yorumlar `tasks/{id}/comments` alt koleksiyonunda tutulur. Birim seçimi ve rol bazlı yetkilendirme burada.
- `lib/features/team/screens/team_detail_screen.dart` — Takım detayı, birimler sekmesi, üyeler sekmesi (birim filtresi). Üyeleri `teams/{id}.memberIds` ve `users` üzerinden çeker.
- `lib/features/team/providers/team_providers.dart` — `teamUnitsProvider` (birim listesi, `unitLeadUid` dahil), `teamMembersProvider`, `UnitService` (birim CRUD + sorumlu atama).
- `lib/features/inventory/providers/depo_providers.dart` — `locationsProvider` (`depo_lokasyonlar`), `inventoryCategoriesProvider`, `inventoryStatusesProvider`, `DepoRepository` CRUD.
- `lib/core/models/app_user.dart` — `AppUser` (role, points, unitResponsibilities, titles, teamIds vb.).
- `lib/core/models/user_profile_models.dart` — `UserTitle`, `TitleType` (captain, unit_lead, board_member vb.).
- `lib/core/permissions/permission_system.dart` — merkezi RBAC (role → permission set).
- `lib/features/admin/admin_permissions.dart` — `effectiveRoleCodes` (role alanı + aktif titles birleşimi).
- `lib/core/providers/auth_providers.dart` — `currentAppUserProvider`, `isAdminProvider`, `firestoreProvider`.
- `lib/features/notifications/providers/notification_providers.dart` — bildirim oluşturma/okuma.
- `functions/index.js` — FCM push bildirim gönderimi (notifications koleksiyonuna `onDocumentCreated`).

## 3. Firebase Yapısı (Firestore)

- `users/{uid}` — `role` (member/unit_lead/admin/board_member/board_president), `displayName`, `points`, `weeklyPoints`, `teamIds`, `unitResponsibilities`, `titles`, `fcmToken`, vb.
- `teams/{id}` — `name`, `description`, `photoUrl`, `memberIds`, `leadUid` (kaptan), `isActive`.
- `units/{id}` — `teamId`, `name`, `description`, `memberUids`, `unitLeadUid` (birim sorumlusu), `createdAt`.
- `tasks/{id}` — `title`, `description`, `assignedTo`, `assignedToName`, `assignedBy`, `assignedByName`, `points`, `status`, `teamId`, `teamName`, `unitId`, `unitName`, `pointsAwarded`, `imageUrl`, `createdAt`. Yorumlar: `tasks/{id}/comments/{commentId}`.
- `announcements/{id}` — `title`, `description`, `imageUrl`, `createdBy`, `targetType`, `targetTeamIds`. Yorumlar alt koleksiyonda.
- `teamApplications/{id}` — `applicantUid`, `teamId`, `status`.
- `depo_urunler/{id}`, `depo_lokasyonlar/{id}`, `inventory_categories/{id}`, `inventory_statuses/{id}` — envanter.
- `aboutSections/{id}`, `aboutMembers/{id}` — hakkımızda.
- `contact/info` — iletişim bilgileri.
- `reports/{id}` — hata/öneri raporları. `messages` alanı dizi.
- `notifications/{id}` — `recipientId`, `senderUid`, `title`, `body`, `isRead`.
- `fcm_tokens/{uid}` — cihaz FCM token'ı (client'tan gizli, sadece owner yazabilir).
- `points_history/{id}` — puan geçmişi.

## 4. Bilinen Kısıtlar / Kurallar

- **Terminal Git Bash'tir** (kural gereği: komutlarda `;` kullan, `&&` yerine — ancak PowerShell kullanılıyorsa duruma göre değişebilir).
- **Firebase project ID: `sargeapp`.** Deploy komutu `firebase deploy --only firestore:rules --project sargeapp`.
- Kaptan bilgisi global `role` alanında DEĞİL, `teams/{id}.leadUid` alanında tutulur. Birim sorumlusu ise `units/{id}.unitLeadUid` alanında tutulur.
- Bir kullanıcı birden fazla birimin sorumlusu olabilir (`unitLeadUid == uid` olan birden çok unit).
- `member` ve `admin` rolleri farklı yetkilere sahiptir. Storage ve Firestore Rules'da buna dikkat edilir.
- Firestore kurallarında `isAdmin()` yalnızca `users/{uid}.role == 'admin'` kontrol eder.

## 5. Sık Karışan Noktalar

- **Firestore koleksiyon adları** geçmişte yanlış eşleşti: kurallar `depo_lokasyon_options`, `depo_birimler`, `depo_kategoriler`, `depo_unitler` kullanırken kod `depo_lokasyonlar`, `inventory_categories`, `inventory_statuses` kullanıyordu → `permission-denied`. Benzer şekilde `about_us` / `about_members` yerine kod `aboutSections` / `aboutMembers` kullanıyor. (Düzeltildi.)
- **Storage Rules**: catch-all `allow write` eklenirse, daha spesifik `isSignedIn()` kurallarını da bloklar (AND semantiği). Bu yüzden catch-all write bırakılmadı.
- **Map tipi**: Firestore'dan gelen veriler `Map<String, dynamic>` olarak ele alınmalı; `Map<String, String>`'e doğrudan cast yapılmamalı (Timestamp/int/bool/nested map içerebilir).