# PROJECT_MAP.md — SARGE Depo App

Projenin "haritası". Her yeni görevde önce bu dosya okunur ve gerektiğinde güncellenir.

## 1. Klasör Yapısı Özeti

- `lib/core/` — tema (AppColors), sabitler, modeller (AppUser, UserProfile), routing, genel widget'lar, permission sistemi, auth/firestore provider'ları. Ayrıca `core/utils/operation_feedback.dart` (tüm silme ve async işlemlerde standart loading-overlay + başarı/hata SnackBar yardımcısı).
- `lib/features/tasks/` — görev ekranları, modelleri ve provider'ları (görev oluşturma, yorumlar, onaylama).
- `lib/features/team/` — takımlar, birimler (units), üyeler, takım/birim ekranları ve provider'ları.
 - `lib/features/inventory/` — depo/envanter ürünleri, lokasyonlar, lokasyon kategorileri (Toplantı Salonu/Atölye/Depo), durumlar; ayrıca `services/location_migration_service.dart` (eski lokasyon göçü).
 - `lib/features/cleaning/` — KULÜP > Temizlik modülü: döngü (`cleaning_rotation`), haftalık takvim (`cleaning_schedule`), alışveriş listesi, bildirim. `models/`, `providers/` (`cleaning_providers`, `cleaning_resolver`, `cleaning_permissions`), `screens/`, `widgets/`.
 - `lib/features/shell/screens/club_screen.dart` — "KULÜP" üst sekme kabı (Temizlik + Malzemeler tab'ları).
- `lib/features/announcements/` — duyurular ve yorumları.
- `lib/features/notifications/` — uygulama içi bildirimler + FCM cihaz token'ları.
- `lib/features/admin/` — admin paneli, üye yönetimi, ünvan yönetimi, başvuru onayları.
- `lib/features/about/` — hakkımızda bölümleri ve üyeleri.
- `lib/features/contact/` — iletişim bilgileri.
- `lib/features/reports/` — hata/öneri raporları ve mesajları.
- `lib/features/store/` — Mağaza modülü: ürünler (CRUD + görsel galeri), siparişler (dekont/EFT bazlı, ödeme yok), IBAN listesi, sipariş durum akışı ve bildirimler. Modeller `store_models.dart`, provider'lar `store_providers.dart`, ekranlar `screens/`.
- `lib/settings/` — uygulama ayarları ekranı. "Hesabımı Sil" (şifre doğrulama + onay dialog'u ile hesap silme) burada.
- `functions/` — Cloud Functions (FCM push bildirimleri + hesap silme temizliği).

## 2. Önemli Dosyalar

- `assets/images/sarge_logo.png` — uygulama içi logo (splash, login, register, sidebar). İçerik sınırına kırpılmış, 50px payla 837×837 kare tuvale ortalanmış.
- `assets/images/launcher_icon.png` — tam (legacy) launcher ikonu, siyah zemin üzerine ortalanmış logo. `pubspec.yaml` → `flutter_launcher_icons.image_path`.
- `assets/images/launcher_icon_foreground.png` — Android adaptive icon foreground (saydam, güvenli alana sığacak şekilde beyaz logo). `pubspec.yaml` → `flutter_launcher_icons.adaptive_icon_foreground`.
- `sarge_logo_original_backup.png` (proje kökü) — orijinal 1254×1254 logonun yedeği (asset paketi dışında tutuluyor).
- `lib/features/tasks/screens/tasks_screen.dart` — Tüm Görevler ekranı + görev detay sheet'i + görev oluşturma dialog'u. Yorumlar `tasks/{id}/comments` alt koleksiyonunda tutulur. Birim seçimi ve rol bazlı yetkilendirme burada. Görev oluşturma: Tekil Üye / Tüm Takım / Birim (segmented button) — toplu atamada her üyeye ayrı görev dokümanı, `bulkGroupId` + `assignmentMode` alanları. Yorum bildirimleri: atayan + aynı bulkGroup'daki TÜM ilgililere (yorumu yazan hariç). **Görev silme**: `_deleteTask`, aynı `bulkGroupId`'li tüm görev kopyalarını + her görevin `comments` alt koleksiyonunu batch delete ile (500'lük parçalar) temizler.
- `lib/features/reports/screens/report_bug_screen.dart` — hata/öneri raporları + mesajlaşma (WhatsApp balonları + yanıtla). Normal üye `reports.messages` array'ine `arrayUnion` ile yanıt ekleyebilir (firestore.rules izni). Mesaj map'i null-free (Firestore array içinde null → invalid-argument çökmesi). Mesaj sayısı artınca otomatik en alta kaydırma yapılır.
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
 - `functions/index.js` — FCM push bildirim gönderimi (`onDocumentCreated` + `onDocumentUpdated`) + gruplu yorum bildirimleri (`notifyTaskComment`, `notifyAnnouncementComment`, `notifyReportReply`) + `onUserDeleted` Auth trigger ile hesap silme temizliği. Push payload'ı `type`/`targetId`/`relatedId`/`count` taşır; aynı thread'e gelen bildirimler aynı collapseKey ile OS tarafında birleşir. `presence/{uid}.activeThreadId` açıksa push bastırılır.
 - `lib/core/routing/notification_router.dart` — bildirim `type` → GoRouter lokasyonu eşlemesi + push deep-link için `pendingNotificationLocation`/`pendingNotificationTargetId`.
- `lib/core/widgets/comment_tile.dart` — ortak yorum/mesaj widget'ları: `UserAvatar`, `UserAvatarWithName` (avatar/isim tıklayınca `/profile/:id`), `ChatBubble` (WhatsApp tarzı balon: kendi mesaj sağda yeşilimsi, başkası solda gri; avatar+isim+saat+linkli metin+resim tam ekran), `ReplyQuoteBlock` (balon içi alıntı), `ReplyPreviewBar` (input üstü "Yanıtlıyorsunuz" önizlemesi), `CommentTile` (legacy wrapper).
- `lib/core/widgets/pending_message.dart` — optimistic UI yardımcısı: `PendingMessage`/`PendingMessageBubble`/`PendingAttachedImage`. Görev/duyuru/rapor mesajlarında görsel seçilir seçilmez yerel önizleme anında balonda gösterilir; üzerine yarı saydam spinner overlay biner; hata olursa balon üzerinde "Gönderilemedi · Tekrar Dene" aksiyonu çıkar. Ayrıca eski `_PendingComment`/`_PendingCommentTile` yapısının yerini alan ortak widget.
- `lib/features/store/providers/store_providers.dart` — `storeProductsProvider`/`storeSettingsProvider`/`allOrdersProvider`/`myOrdersProvider` stream'leri + `StoreRepository` (ürün CRUD, sipariş oluşturma, IBAN yönetimi, Storage yükleme) + `pickReceiptPdf` (sadece PDF, maks 10MB) + `StoreNotifier` (yeni sipariş → `manageStore` sahiplerine, durum değişimi → sipariş verene bildirim). Firestore: `store_products`, `orders`, `store_meta`; Storage: `store_products/...`, `store_receipts/...`.
- `lib/features/store/models/store_models.dart` — `StoreProduct`, `StoreOrder`, `StoreOrderStatus` (esnek durum listesi: Ödeme Bekleniyor → Onaylandı → Üretimde/Basımda → Kargoya Verildi → Tamamlandı; + İptal Edildi), `StoreSettings` (IBAN listesi).
- `lib/features/store/screens/store_screen.dart` — Mağaza ana ekranı (ürün grid/listesi, "Ürün Ekle" butonu `manageStore` sahiplerine, sipariş+ayarlar kısayolları).
- `lib/features/store/screens/store_order_form_screen.dart` — sipariş formu (IBAN gösterimi + bilgilendirme metni + PDF dekont yükleme + opsiyonel not).
- `lib/features/store/screens/store_orders_screen.dart` — "Tüm Siparişler" (Tümü / Benim Siparişlerim filtresi; bildirim derin bağlantısında otomatik detay açma).
- `lib/features/store/screens/store_order_detail_screen.dart` — sipariş detayı (dekont görüntüleme + admin durum geçiş butonları + durum değişince bildirim).
- `lib/features/store/screens/store_settings_screen.dart` — Mağaza Ayarları (IBAN ekle/sil/düzenle).
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
 - `depo_urunler/{id}`, `depo_lokasyonlar/{id}`, `inventory_categories/{id}`, `inventory_statuses/{id}` — envanter. `depo_lokasyonlar` artık `categoryId`/`categoryName`/`parentId` taşır.
 - `location_categories/{id}` — sabit lokasyon kategorileri (Toplantı Salonu / Atölye / Depo; extensible).
 - `cleaning_rotation/{id}` — temizlik döngüsü sıraları (`order`, `assignmentType` team/unit/individual/custom_group, `targetIds`, `label`).
 - `cleaning_schedule/{weekKey}` — haftalık gerçekleşen kayıtlar (`weekKey` = Pazartesi YYYY-MM-DD; `assignmentType`/`targetIds` + opsiyonel `override*`, `items[]` alışveriş listesi, `completed`, `notifiedAt`).
 - `cleaning_meta/config` — temizlik başlangıç haftası (`startWeekKey`) + alışveriş listesi şablonu (`shoppingTemplate`).
 - `locations_backup_pre_migration/{id}` — lokasyon göçü öncesi yedek.
- `club_info/info` — kulüp hikayesi + `galleryPhotos` + iletişim bilgileri (tek doküman).
- `honorary_members/{id}` — `userId`, `note`, `addedDate`, `addedBy`.
- `role_permissions/{role}` — rol bazlı yetki override'ları (`permissions: []`).
- `aboutSections/{id}`, `aboutMembers/{id}` — hakkımızda.
- `contact/info` — iletişim bilgileri.
- `reports/{id}` — hata/öneri raporları. `messages` alanı dizi (her öğe `id`, `senderUid`, `senderName`, `text`, `imageUrl`, `createdAt`, `isAdmin`, `replyToId`, `replyToText`, `replyToAuthor` içerir).
- `notifications/{id}` — `recipientId`, `senderUid`, `senderName`, `title`, `body`, `isRead`, `type` (task_assigned, task_comment, task_submitted, team_application, announcement, announcement_comment, report_reply, cleaning vb.), `relatedId`, `count` (gruplu thread sayaç), `createdAt`/`updatedAt`.
- `presence/{uid}` — `activeThreadId` (kullanıcının anlık açık tuttuğu `type:relatedId` thread anahtarı; bildirim/push bastırma için).
- `fcm_tokens/{uid}` — cihaz FCM token'ı (client'tan gizli, sadece owner yazabilir).
- `points_history/{id}` — puan geçmişi. `delta` (pozitif/negatif), `targetUid`, `targetName`, `changedBy`, `createdAt`. Açıklama (`reason`) alanı kaldırıldı (opsiyonel; mevcut eski kayıtlar bozulmaz).
- `store_products/{id}` — Mağaza ürünü: `name`, `price`, `description`, `imageUrls` (ilk görsel kapak), `inStock`, `createdBy`, `createdAt`. Yazma: `manageStore` yetkisi; okuma: herkes.
- `orders/{id}` — Mağaza siparişi: `userId`, `userName`, `productId`, `productName`, `price`, `receiptUrl` (dekont PDF), `note`, `status` (Ödeme Bekleniyor varsayılan), `createdAt`. Okuma: sahibi veya `manageStore`; oluşturma: giriş yapmış kullanıcı (kendi `userId`'si); durum güncelleme: `manageStore`.
- `store_meta/settings` — Mağaza ayarları: `ibans` (string listesi). Yazma: `manageStore`; okuma: herkes.

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
- **Riverpod `ConsumerState.dispose()` içinde `ref.read()` yasak**: Riverpod, widget unmount olmadan `ref`'i iptal eder; `dispose()` içinde `ref.read(...)` çağrılırsa `Bad state: Cannot use "ref" after the widget was disposed.` fırlar ve uygulama geçişlerde beyaz ekranda kalır. Thread-detay sheet'lerinde (`_AnnouncementDetailSheetState`, `_TaskDetailSheetState`, `_ReportDetailViewState`) `PresenceService` `initState`'te `late final _presenceService` alanına cache'lenir, `dispose`'ta bu instance kullanılır.
