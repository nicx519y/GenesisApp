import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/native_image_picker.dart';

void main() {
  test('native picker forwards Opening upload normalization', () {
    expect(
      genesisNativeImagePickerArguments(limit: 1, normalizeForUpload: true),
      <String, Object>{'limit': 1, 'normalizeForUpload': true},
    );
  });

  test('native picker leaves normal image selection unchanged', () {
    expect(
      genesisNativeImagePickerArguments(limit: 6, normalizeForUpload: false),
      <String, Object>{'limit': 6, 'normalizeForUpload': false},
    );
  });
}
