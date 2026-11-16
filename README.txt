LockScreenIP
============

Amac:
Windows kilit ekraninda aktif IPv4 adresini ve bilgisayar adini gostermek.

Kurulum:
1. ZIP'i acin.
2. Install.bat dosyasini calistirin.
3. UAC onayi verin.
4. Win+L ile test edin.

Varsayilan davranis:
- Aktif default route'u kullanan adaptörün IPv4 adresini bulur.
- IP + bilgisayar adi + son guncelleme zamanini resme yazar.
- Resmi Windows kilit ekrani olarak ayarlar.
- SYSTEM gorevi her 2 dakikada bir calisir.
- Kullanici oturumu kilitli olsa da gorev calismaya devam eder.

Kendi duvar kagidinizi kullanmak icin:
PowerShell'i Administrator acin ve:
  .\Install-LockScreenIP.ps1 -BaseImage "C:\Temp\wallpaper.jpg"

Not:
Microsoft'un resmi dokumanina gore GPO ile kilit ekrani zorlamasi
Windows Enterprise/Education surumlerinde desteklenir.
Windows Pro tarafinda kilit ekrani yonetimi surume/yonetim yontemine gore kisitli olabilir.

Guvenlik:
IP adresi kilit ekraninda gorunecegi icin cihaz yanindaki herkes tarafindan okunabilir.
