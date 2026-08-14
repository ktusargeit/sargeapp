# PROJECT_MAP.md — SARGE Depo App

Projenin "haritası". Her yeni görevde önce bu dosya okunur ve gerektiğinde güncellenir.

## 1. Klasör Yapısı Özeti

- `lib/core/` — tema (AppColors), sabitler, modeller (AppUser, UserProfile), routing, genel widget'lar, permission sistemi, auth/firestore provider'ları. Ayrıca `core/utils/operation_feedback.dart` (tüm silme ve async işlemlerde standart loading-overlay + başarı/hata SnackBar yardımcısı).
- `lib/features/tasks/` — görev ekranları, modelleri ve provider'ları (görev oluşturma, yorumlar, onaylama).
- `lib/features/team/` — takımlar, birimler (units), üyeler, takım/birim ekranları ve provider'ları.
- `lib/features/inventory/` — depo/envanter ürünleri, lokasyonlar, kategoriler, durumlar.
- `lib/features/announcements/` — duyurular ve yorumları.
- `lib/features/notifications/` — uygulama içi bildirimler + FCM cihaz token'ları.
- `lib/features/admin/` — admin paneli, üye yönetimi, ünvan yönetimi, başvuru onayları.
- `lib/features/about/` — hakkımızda bölümleri ve üyeleri.
- `lib/features/contact/` — iletişim bilgileri.
- `lib/features/reports/` — hata/öneri raporları ve mesajları.
- `lib/settings/` — uygulama ayarları ekranı. "Hesabımı Sil" (şifre doğrulama + onay dialog'u ile hesap silme) burada.
- `functions/` — Cloud Functions (FCM push bildirimleri + hesap silme temizliği).

## 2. Önemli Dosyalar

- `assets/images/sarge_logo.png` — uygulama içi logo (splash, login, register, sidebar). İçerik sınırına kırpılmış, 50px payla 837×837 kare tuvale ortalanmış.
- `assets/images/launcher_icon.png` — tam (legacy) launcher ikonu, siyah zemin üzerine ortalanmış logo. `pubspec.yaml` → `flutter_launcher_icons.image_path`.
- `assets/images/launcher_icon_foreground.png` — Android adaptive icon foreground (saydam, güvenli alana sığacak şekilde beyaz logo). `pubspec.yaml` → `flutter_launcher_icons.adaptive_icon_foreground`.
- `sarge_logo_original_backup.png` (proje kökü) — orijinal 1254×1254 logonun yedeği (asset paketi dışında tutuluyor).
- `lib/features/tasks/screens/tasks_screen.dart` — Tüm Görevler ekranı + görev detay sheet'i + görev oluşturma dialog'u. Yorumlar `tasks/{id}/comments` alt koleksiyonunda tutulur. Birim seçimi ve rol bazlı yetkilendirme burada. Görev oluşturma: Tekil Üye / Tüm Takım / Birim (segmented button) — toplu atamada her üyeye ayrı görev dokümanı, `bulkGroupId` + `assignmentMode` alanları. Yorum bildirimleri: atayan + aynı bulkGroup'daki TÜM ilgililere (yorumu yazan hariç).
- `lib/features/notifications/screens/notifications_screen.dart` — Bildirim merkezi; tıklayınca task_assigned/task_comment/task_submitted → göreve, team_application → takıma, announcement → dashboard'a gider.
- `lib/features/team/screens/team_detail_screen.dart` — Takım detayı, birimler sekmesi, üyeler sekmesi (birim filtresi). Üyeleri `teams/{id}.memberIds` ve `users` üzerinden çeker.
- `lib/features/team/providers/team_providers.dart` — `teamUnitsProvider` (birim listesi, `unitLeadUid` dahil), `teamMembersProvider`, `UnitService` (birim CRUD + sorumlu atama).
- `lib/features/inventory/providers/depo_providers.dart` — `locationsProvider` (`depo_lokasyonlar`), `inventoryCategoriesProvider`, `inventoryStatusesProvider`, `DepoRepository` CRUD. Lokasyon CRUD: `addLocationByName`, `updateLocationName`, `deleteLocation`, `countItemsInLocation`.
- `lib/core/models/app_user.dart` — `AppUser` (role, points, unitResponsibilities, titles, teamIds vb.).
- `lib/core/models/user_profile_models.dart` — `UserTitle`, `TitleType` (captain, unit_lead, board_member vb.).
- `lib/core/permissions/permission_system.dart` — merkezi RBAC (role → permission set).
- `lib/features/admin/admin_permissions.dart` — `effectiveRoleCodes` (role alanı + aktif titles birleşimi).
- `lib/core/providers/auth_providers.dart` — `currentAppUserProvider`, `isAdminProvider`, `firestoreProvider`, `AuthController.deleteAccount` (şifre ile re-auth + auth hesap silme).
- `lib/settings/screens/settings_screen.dart` — Ayarlar ekranı. En altta kırmızı "Hesabımı Sil": uyarı dialog'u → şifre doğrulama → `AuthController.deleteAccount` + loading/SnackBar feedback.
- `lib/features/admin/screens/admin_member_detail_screen.dart` — Üye yönetimi detay ekranı. `_PointsEditor` puan ekle/düş: artık açıklama alanı yok, sadece sayı; `points_history`'ye `reason` yazılmıyor.
- `lib/features/notifications/providers/notification_providers.dart` — bildirim oluşturma/okuma.
- `functions/index.js` — FCM push bildirim gönderimi (`onDocumentCreated`) + `onUserDeleted` Auth trigger ile hesap silme temizliği (teams/units üyelikleri, leadUid/unitLeadUid boşaltma, users doc, fcm_tokens, storage profil/kapak fotoğrafları).
- `lib/core/widgets/comment_tile.dart` — ortak yorum/mesaj widget'ları: `UserAvatar`, `UserAvatarWithName` (avatar/isim tıklayınca `/profile/:id`), `ChatBubble` (WhatsApp tarzı balon: kendi mesaj sağda yeşilimsi, başkası solda gri; avatar+isim+saat+linkli metin+resim tam ekran), `ReplyQuoteBlock` (balon içi alıntı), `ReplyPreviewBar` (input üstü "Yanıtlıyorsunuz" önizlemesi), `CommentTile` (legacy wrapper).
- `lib/core/services/fcm_service.dart` — FCM cihaz token yaşam döngüsü. Token `fcm_tokens/{uid}` dokümanına yazılır; login/token-rotate'da yenilenir, logout'ta silinir. Web için `kWebVapidKey` sabiti (VAPID public key) eklenmiştir; boş bırakılırsa web kaydı güvenle atlanır.
- `lib/core/utils/image_utils.dart` — `PickedImage`: çekilen/seçilen görselleri Storage'a yüklemeden önce max 1280px genişlik + %75 JPEG olarak sıkıştırır (`compressBytes` / `compressedUploadBytes`). `pick`/`pickMultiple` web'de de sıkıştırma yapar.
- `web/firebase-messaging-sw.js` — Web push service worker (FCM). Manifest/`index.html` ile birlikte Chrome/FF'ta arka plan bildirimlerini sağlar.

## 3. Firebase Yapısı (Firestore)

- `users/{uid}` — `role` (member/unit_lead/admin/board_member/board_president), `displayName`, `points`, `weeklyPoints`, `teamIds`, `unitResponsibilities`, `titles`, `fcmToken`, vb.
- `teams/{id}` — `name`, `description`, `photoUrl`, `memberIds`, `leadUid` (kaptan), `isActive`.
- `units/{id}` — `teamId`, `name`, `description`, `memberUids`, `unitLeadUid` (birim sorumlusu), `createdAt`.
- `tasks/{id}` — `title`, `description`, `assignedTo`, `assignedToName`, `assignedBy`, `assignedByName`, `points`, `status`, `teamId`, `teamName`, `unitId`, `unitName`, `pointsAwarded`, `imageUrl`, `createdAt`, `bulkGroupId` (toplu atamada aynı gruptaki tüm görevler aynı değeri taşır), `assignmentMode` (`single` | `team` | `unit`). Yorumlar: `tasks/{id}/comments/{commentId}`. Yorum dokümanı `senderUid`, `senderName`, `text`, `imageUrls`, `createdAt`, `isAdmin`, `replyToId`, `replyToText`, `replyToAuthor` içerir.
- `announcements/{id}` — `title`, `description`, `imageUrl`, `createdBy`, `targetType`, `targetTeamIds`. Yorumlar alt koleksiyonda (aynı reply alanlarıyla).
- `teamApplications/{id}` — `applicantUid`, `teamId`, `status`.
- `depo_urunler/{id}`, `depo_lokasyonlar/{id}`, `inventory_categories/{id}`, `inventory_statuses/{id}` — envanter.
- `aboutSections/{id}`, `aboutMembers/{id}` — hakkımızda.
- `contact/info` — iletişim bilgileri.
- `reports/{id}` — hata/öneri raporları. `messages` alanı dizi (her öğe `id`, `senderUid`, `senderName`, `text`, `imageUrl`, `createdAt`, `isAdmin`, `replyToId`, `replyToText`, `replyToAuthor` içerir).
- `notifications/{id}` — `recipientId`, `senderUid`, `title`, `body`, `isRead`, `type` (task_assigned, task_comment, task_submitted, team_application, announcement vb.), `relatedId`.
- `fcm_tokens/{uid}` — cihaz FCM token'ı (client'tan gizli, sadece owner yazabilir).
- `points_history/{id}` — puan geçmişi. `delta` (pozitif/negatif), `targetUid`, `targetName`, `changedBy`, `createdAt`. Açıklama (`reason`) alanı kaldırıldı (opsiyonel; mevcut eski kayıtlar bozulmaz).

## 4. Bilinen Kısıtlar / Kurallar

- **Terminal Git Bash'tir** (kural gereği: komutlarda `;` kullan, `&&` yerine — ancak PowerShell kullanılıyorsa duruma göre değişebilir).
- **Firebase project ID: `sargeapp`.** Deploy komutu `firebase deploy --only firestore:rules --project sargeapp`.
- Kaptan bilgisi global `role` alanında DEĞİL, `teams/{id}.leadUid` alanında tutulur. Birim sorumlusu ise `units/{id}.unitLeadUid` alanında tutulur.
- Bir kullanıcı birden fazla birimin sorumlusu olabilir (`unitLeadUid == uid` olan birden çok unit).
- `member` ve `admin` rolleri farklı yetkilere sahiptir. Storage ve Firestore Rules'da buna dikkat edilir.
- Firestore kurallarında `isAdmin()` yalnızca `users/{uid}.role == 'admin'` kontrol eder.
- **Hesap silme**: İstemci sadece Firebase Auth `user.delete()` çağırır (re-auth sonrası). Firestore/Storage temizliği `functions/` içindeki `cleanupDeletedUser` (`onUserDeleted`) Auth trigger'ı ile Admin SDK üzerinden yapılır — normal üye Firestore'da teams/units güncelleyemez veya kendi users doc'unu silemez (rules engeller).
- **Toplu görev atama**: Takım/Birim modunda kaptan tüm birimlere atayabilir; birim sorumlusu yalnızca kendi birimine atayabilir (UI `_allowedUnitIdsFor` + firestore.rules `isCaptainOfTeam`/`isUnitLeadOfUnit`).

## 5. Sık Karışan Noktalar

- **Logo / launcher ikonu**: Orijinal kaynak görselde gömülü büyük siyah boşluklar vardı (logo, kare tuvalin küçük bir kısmına sıkışmış ve üst-alt boşluklar eşit olmadığı için kayık duruyordu). Uygulama içi kullanım için `sarge_logo.png` kırpıldı; launcher/adaptive iconlar için ayrıca `launcher_icon.png` ve `launcher_icon_foreground.png` üretildi. Yeni görsel eklenirse `flutter pub run flutter_launcher_icons` ile native ikonlar yeniden üretilmeli.
- **Firestore koleksiyon adları** geçmişte yanlış eşleşti: kurallar `depo_lokasyon_options`, `depo_birimler`, `depo_kategoriler`, `depo_unitler` kullanırken kod `depo_lokasyonlar`, `inventory_categories`, `inventory_statuses` kullanıyordu → `permission-denied`. Benzer şekilde `about_us` / `about_members` yerine kod `aboutSections` / `aboutMembers` kullanıyor. (Düzeltildi.)
- **Storage Rules**: catch-all `allow write` eklenirse, daha spesifik `isSignedIn()` kurallarını da bloklar (AND semantiği). Bu yüzden catch-all write bırakılmadı.
- **Map tipi**: Firestore'dan gelen veriler `Map<String, dynamic>` olarak ele alınmalı; `Map<String, String>`'e doğrudan cast yapılmamalı (Timestamp/int/bool/nested map içerebilir).
- **points_history `reason` alanı**: Eski kayıtlarda `reason` varsa sorun değil. Yeni kayıtlarda yazılmıyor. Bir puan geçmişi ekranı ileride eklenirse `reason` null-safe gösterilmeli.
- **Auth silme trigger'ı**: `firebase-functions/v1/auth` `onUserDeleted` kullanılıyor (v2 auth trigger henüz desteklenmiyor). Deploy ederken `functions` klasöründen `firebase deploy --only functions --project sargeapp` çalıştırılmalı.
- **Bulk görev sorgusu**: Yorum bildirimlerinde `bulkGroupId` eşitlik sorgusu kullanılır. `bulkGroupId` alanı Firestore'da index gerektirmez (tek alan eşitlik).