# Telefon yerel uçuş operasyonu

Bu dal, yolcu listesini Firestore'da tutan önceki akışın yerine geçer. main ve
mevcut canlı Firebase kuralları otomatik değiştirilmez. Önceki ekran kodları
geçiş incelemesi için duruyor; AuthGate yalnız yeni DispatchScreen'i açar.

## Erişim ve kayıt telefonu

Admin uçuş oluşturur, DLM kalkışını ve varış IATA kodunu, uçuş gününü, atanmış
kullanıcıları ve rapor e-posta alıcılarını tanımlar. Agent yalnız atandığı uçuşu
görür. Aktif Supervisor bütün uçuşları görebilir. Rol/aktivasyon yalnız güvenilir
Admin SDK yönetimiyle verilir; istemcinin kendi yetkisini değiştirmesi yasaktır.

Kullanıcının kararı: uçuş başına tek kayıt telefonu. İlk yetkili talep cihazı
transaction ile bağlar. Başka telefon aynı uçuş için yolcu işlemi yapamaz.
Diğer atanan kişiler/SPV uçuş bilgisini görür, telefondaki yolcu listesini uzaktan
göremez. Uçuşu kaydeden kullanıcı aynı telefonda yeniden giriş yapmalıdır.
Otomatik cihaz devri yoktur; telefon kaybında veri kaybı mümkündür.

Her değişiklikten önce sunucudan erişim kontrolü alınır. Bu sürüm offline
boarding iddiasında bulunmaz; yetki yenilenemezse işlem durur.

## Verinin yeri

Yolcu, PNR, koltuk, LP, watchlist, detaylı audit ve rapor alanları uygulamanın
özel dizininde AES-256-GCM ile şifreli tutulur. Anahtar flutter_secure_storage
üzerinden Android Keystore'dadır. Android otomatik yedek kapalıdır. Firestore
kalıcı önbelleği açılışta temizlenir ve kapatılır. Ham barkod kaydedilmez.
Gelen LP'nin yalnız yolcu tablosu alınır; tıbbi/serbest metin notları alınmaz.

Firestore yalnız uçuş/atama, kayıt cihazının rastgele kimliğinin hash'i, merkezi
uçuş yönetim olayları ve e-posta gönderiminin hash/durum bilgilerini tutar.
Yolcu koleksiyonlarının okunması ve yazılması Admin dahil istemcilere yasaktır.
İşlem geçmişi yerel dosyada hash zinciriyle korunur; bu bir harici zaman damgası
veya adli değişmezlik garantisi değildir. Telefonda saat değişirse zaman bilgisi
bundan etkilenebilir. Şifreli kalıcı yazma bitmeden başarı gösterilmez.

Rapor dışa aktarma ve e-posta, kullanıcının istediği açık veri çıkışlarıdır.
Mail uygulaması için oluşturulan ekler yalnız telefonun özel geçici dizinindedir.
E-posta kutuları gönderilen raporları saklar; bu, sunucuda yolcu veritabanı değildir.
Telefon kayıtlarının saklama/silme süresi kurum tarafından ayrıca belirlenmelidir.

## Kart ve LP doğrulaması

Uçuş kodu/alias, gün, kalkış ve varış birlikte kesin eşleşir. Eksik varış kabul
edilmez. Sabit alanlı BCBP yapısı korunur. Çok segmentli kartta tek bir eşleşen
segment bulunmalıdır. Manuel girişte aynı kontroller çalışır. Infant, dolu
koltuktaki yetişkine açık onayla bağlanır; yetişkin offload'unda infant da düşer.
Standart zorunlu BCBP alanı yıl değil yılın gününü taşır. Uçuş tarihi yılı sağlar;
aynı Julian günlü eski yıl kartını ayırt etmek için havayolu/DCS doğrulaması gerekir.

LP yükleme biçimi eklenen Jet2 Word belgesidir: Flight Number / Flight Date &
Time başlıkları ve 7 kolonlu tablo. Uçuş/güzergah/gün uyuşmazlığı veya bozuk
satırda dosyanın tamamı reddedilir. İsim ve PNR eşleşmesi tekilse LP etiketi
gösterilir. LP etiketi tek başına DFT araması yapıldığı anlamına gelmez.

## Resmi formlar

Eklenen Word/XLS şablonları yerel LibreOffice dönüşümüyle DOCX/XLSX'e
çevrilmiştir. Logo, hücre düzeni, birleşimler, baskı ayarları ve Word onay
metinleri korunur. Çıktı modern Office biçimindedir; eski .doc/.xls değildir.

OPR-FRM-0098 yalnız DFT Random ile aranan yolcuları içerir. LP ibaresi ve
güvenlik numarası taşınır; tabiiyet/notlar operatör tarafından girilir. Offload
edilen ama daha önce aranmış kişi listede OFFLOADED notuyla kalır. Yolcu/TL/
havayolu temsilcisi/personel imzaları taklit edilmez; kağıtta tamamlanır. Her
15 aranan yolcuda tam form yeniden oluşturulur, çok dilli ek sayfa korunur.

BA/BAW için yalnız OPR-FRM-0012 revizyon 7; diğer havayollarında OPR-FRM-0011
revizyon 4 seçilir. Operasyon ekranından formun diğer alanları ve personel/
ekipman/saat bilgileri girilir. Bilinmeyen alanlar uydurulmaz, boş kalır.

## Kapatma ve otomatik e-posta kurulumu

1. Kayıt telefonu iki raporu üretir ve tam baytlarını şifreli dosyada dondurur.
2. Yerel kapanış kalıcılaşır; yeni boarding durur. Merkezi kapanış başarısızsa
   tekrar deneme düğmesi aynı kapanışı tamamlar.
3. sendFlightClosure çağrısı raporları yalnız bellekte SMTP'ye aktarır. Cloud
   Storage veya Firestore'a ek dosya/yolcu listesi yazmaz, içeriği loglamaz.
4. Alıcılar istemci isteğinden değil Admin'in uçuş kaydından alınır. Sunucu
   atanmış aktif kayıt kullanıcısını, kapanışı ve BA form seçimini doğrular.
5. reportDeliveries/{flightId} hash/durum kaydı aynı dosyaların tekrar
   gönderilmesini engeller. SMTP cevabı belirsizse NEEDS_REVIEW olur; otomatik
   yeniden gönderim yapılmaz. Yetkili operatör SMTP kayıtlarından incelemelidir.
6. ACCEPTED, SMTP sunucusunun kabulüdür; alıcının okuduğu/teslim aldığı garantisi
   değildir. Mail uygulaması alternatifi gönderildi sayılmaz; kullanıcı Gönder'e basar.

Canlı gönderim için Firebase Functions/billing, Firebase App Check Play Integrity
ve yetkili kurumsal SMTP gerekir. REPORT_SMTP_HOST, REPORT_SMTP_USER,
REPORT_SMTP_FROM parametreleri ve REPORT_SMTP_PASSWORD Secret Manager sırrı
sunucuda tanımlanmalıdır. SMTP TLS 465 kullanır; parola APK'ya konulmaz.
Gönderen domain doğrulaması/SPF/DKIM ve Android imza sertifikasının Firebase /
Play Integrity kaydı tamamlanmalıdır. Debug imzalı test APK'sı production App
Check doğrulamasını geçmeyebilir. Bu kurulumlar bu dal tarafından yayımlanmaz.

## Geçiş ve doğrulama

Eski Firebase yolcu kayıtları bu değişiklikle silinmez. Canlıya geçmeden önce
yetkili yönetici, mevcut pax/watchlist/boarding_keys/seat_locks ve kişisel veri
içeren log/arşiv kayıtlarını kurumun saklama yükümlülüğüne göre temizlemelidir.
Eski flight dokümanları yeni metadata şemasına taşınmalı, varış ve atamalar
Admin tarafından belirlenmelidir. Önce kurallar ve yeni sürüm kontrollü test
ortamında birlikte doğrulanmalı; eski istemciler erişimi kaybeder.

CI: Flutter analiz/test, Chrome önizleme testi, release web/APK, Firestore
emulator erişim/PII engeli, sunucu form doğrulama testleri. Synthetic form
örnekleri build/form-qa altındadır. Gerçek cihaz Keystore, yeniden başlatma,
kamera/fener, imza sonrası çıktı ve gerçek SMTP/App Check uçtan uca testi ayrıca
gereklidir. Canlı hesap/parola ve gerçek yolcu fixture'ı depoya eklenmez.
