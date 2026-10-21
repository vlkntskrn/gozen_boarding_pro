import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

/// Private app directory, AES-GCM ciphertext; key lives in Android Keystore.
/// No Firebase, analytics, cloud sync or Android automatic backup.
class FlightLocalStorage {
  static const _keys = FlutterSecureStorage();
  static final _cipher = AesGcm.with256bits();
  Future<String> deviceId() async {
    const name = 'recording_device_v1';
    var id = await _keys.read(key:name);
    if (id == null) {
      id = base64Url.encode(await (await _cipher.newSecretKey()).extractBytes());
      await _keys.write(key:name,value:id);
    }
    return sha256.convert(utf8.encode(id)).toString();
  }
  Future<SecretKey> _secret() async {
    var value = await _keys.read(key:'flight_aes_v1');
    if (value == null) {
      value = base64Encode(await (await _cipher.newSecretKey()).extractBytes());
      await _keys.write(key:'flight_aes_v1',value:value);
    }
    return SecretKey(base64Decode(value));
  }
  Future<File> _file(String key) async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive:true);
    return File('${dir.path}/flight_${sha256.convert(utf8.encode(key))}.aes');
  }
  Future<String?> read(String key) async {
    final f = await _file(key);
    if (!await f.exists()) return null;
    final box = SecretBox.fromConcatenation(await f.readAsBytes(), nonceLength:12,macLength:16);
    return utf8.decode(await _cipher.decrypt(box,secretKey:await _secret(),aad:utf8.encode(key)));
  }
  Future<void> write(String key, String value) async {
    final f = await _file(key);
    final box = await _cipher.encrypt(utf8.encode(value),secretKey:await _secret(),aad:utf8.encode(key));
    final tmp = File('${f.path}.pending');
    await tmp.writeAsBytes(box.concatenation(),flush:true);
    await tmp.rename(f.path); // Atomic replacement; previous committed file survives failed writes.
  }
  Future<List<String>> exportFiles(String batch, Map<String,List<int>> files) async {
    // Explicit report export only; phone-private temporary files for mail attachments.
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}/flight_mail_$batch');
    await dir.create(recursive:true);
    final paths = <String>[];
    for (final e in files.entries) {
      final f = File('${dir.path}/${e.key}');
      await f.writeAsBytes(e.value,flush:true); paths.add(f.path);
    }
    return paths;
  }
  Future<void> compose(List<String> recipients, String subject, List<String> files) =>
    FlutterEmailSender.send(Email(recipients:recipients,subject:subject,
      body:'Arama formu ve günlük uçuş raporu ektedir. İmza alanları ilgili kişilerce tamamlanmalıdır.',
      attachmentPaths:files,isHTML:false));
}
