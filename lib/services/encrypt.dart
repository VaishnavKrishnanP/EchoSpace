import 'dart:convert';
import 'package:encrypt/encrypt.dart';

// Static AES-256 key and IV
final Key _key = Key.fromBase64("4rzkBpEADcH37nhH0PGp0j/Grg8bYm16WDY2jdt9VU4=");
final IV _iv = IV.fromBase64("SSOO7267st15b8ov35W21w==");

// Singleton crypto instance
final AESCrypto crypto = AESCrypto(_key, _iv);

class AESCrypto {
  final Key key;
  final IV iv;

  AESCrypto(this.key, this.iv);

  String encrypt(String plainText) {
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String decrypt(String encryptedText) {
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
    return decrypted;
  }
}
