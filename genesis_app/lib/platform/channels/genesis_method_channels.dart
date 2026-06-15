import 'package:flutter/services.dart';

class GenesisMethodChannels {
  const GenesisMethodChannels._();

  static const deviceChannelName = 'com.genesis.ai/device';
  static const device = MethodChannel(deviceChannelName);

  static const getAndroidId = 'getAndroidId';
  static const getDeviceId = 'getDeviceId';
  static const setUid = 'setUid';
  static const getUid = 'getUid';
  static const clearUid = 'clearUid';
  static const setAuthToken = 'setAuthToken';
  static const getAuthToken = 'getAuthToken';
  static const setUserInfo = 'setUserInfo';
  static const getUserInfo = 'getUserInfo';
  static const getSignInDiagnostics = 'getSignInDiagnostics';
  static const getAppName = 'getAppName';
}
