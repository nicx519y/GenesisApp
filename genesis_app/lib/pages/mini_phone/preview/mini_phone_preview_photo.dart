import 'dart:typed_data';
import 'mini_phone_demo_store.dart';

class MiniPhonePreviewPhoto {
  const MiniPhonePreviewPhoto({this.asset, this.bytes, required this.author});
  final String? asset;
  final Uint8List? bytes;
  final MiniDemoPerson author;
}
