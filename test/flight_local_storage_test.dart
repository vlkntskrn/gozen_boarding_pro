import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:gozen_boarding_pro/flight_local_storage_io.dart';

class TestPaths extends PathProviderPlatform {
 final String root;
 TestPaths(this.root);
 @override Future<String?> getApplicationSupportPath() async=>root;
 @override Future<String?> getTemporaryPath() async=>root;
}
void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 test('phone file is encrypted, restart preserves data, tampering is rejected',() async {
  final dir=await Directory.systemTemp.createTemp('gozen_encryption_test_');
  final prior=PathProviderPlatform.instance;
  PathProviderPlatform.instance=TestPaths(dir.path);
  FlutterSecureStorage.setMockInitialValues({});
  addTearDown(()async {PathProviderPlatform.instance=prior;await dir.delete(recursive:true);});
  final store=FlightLocalStorage();
  final device=await store.deviceId();
  await store.write('flight1','{"name":"SYNTHETIC/TEST","pnr":"ABC123"}');
  final file=dir.listSync().whereType<File>().single;
  final bytes=await file.readAsBytes();
  expect(String.fromCharCodes(bytes),isNot(contains('SYNTHETIC')));
  expect(String.fromCharCodes(bytes),isNot(contains('ABC123')));
  final restart=FlightLocalStorage();
  expect(await restart.deviceId(),device);
  expect(await restart.read('flight1'),contains('SYNTHETIC/TEST'));
  bytes[bytes.length-1]^=1;await file.writeAsBytes(bytes);
  await expectLater(restart.read('flight1'),throwsA(anything));
 });
}
