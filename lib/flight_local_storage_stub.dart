class FlightLocalStorage {
  Future<String> deviceId() async => throw UnsupportedError('Yolcu kaydı yalnız kayıt telefonunda kullanılabilir.');
  Future<String?> read(String key) async => throw UnsupportedError('Telefon gerekli.');
  Future<void> write(String key, String value) async => throw UnsupportedError('Telefon gerekli.');
  Future<List<String>> exportFiles(String batch, Map<String, List<int>> files) async => throw UnsupportedError('Telefon gerekli.');
  Future<void> compose(List<String> recipients, String subject, List<String> files) async => throw UnsupportedError('Telefon gerekli.');
}
