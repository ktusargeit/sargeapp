# SARGE Bug Fix & İyileştirme Takip Listesi

- [x] 1. Member görsel yorum yükleyemiyor (storage.rules) — deploy edildi
- [x] 2. Silme butonları küçük (CustomDeleteButton, 44x44 + press feedback)
- [x] 3. Tüm Görevler'de silme butonu yok
- [x] 4. Yorum linkleri tıklanabilir değil (LinkifiedText)
- [x] 5. Ürün eklemede kamera butonu eksik
- [x] 6. Lokasyon seçme ekranı yavaş/takılıyor (_LocationPickerSheet ConsumerWidget)
- [x] 7. Ürün kaydetmede zorunlu alan hatası sessiz
- [x] 8. Takımım - birimler görünmüyor (Takımım listesine birim bölümü eklendi)
- [x] 9. Firestore index hatası (takım birim yönetimi) — sorgu equality-only yapıldı
- [x] 10. Depo > Lokasyon Seç: Firestore permission-denied — firestore.rules'ta koleksiyon adları düzeltildi (`depo_lokasyonlar`, `inventory_categories`, `inventory_statuses`, `aboutSections`, `aboutMembers`, `contact` eklendi/düzeltildi); deploy edildi
- [x] 11. Takım Detayı > Üyeler > Birim seçince tip hatası — `Map<String,dynamic>` vs `Map<String,String>` cast kaldırıldı (`_matchesUnitFilter`)
- [x] 12. Görsel yükleme gecikmesi — yorum görselleri için optimistic UI eklendi (lokal önizleme + yükleniyor göstergesi)
- [x] 13. Birime görev atama yetkilendirmesi — görev formuna birim seçimi + kaptan/birim sorumlusu rol kontrolleri (UI + firestore.rules)