/// What this install reports about itself in `public.devices` heartbeats
/// (platform and app version), handed to the sync engine as the data
/// package's `DeviceInfo`. Built once per app run from the build constant;
/// `main` or a test may override the provider.
library;

import 'package:ampdent_data/ampdent_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_config.dart' show appBuildVersion;

/// The running platform as `devices.platform` names it.
DevicePlatform devicePlatform() => switch (defaultTargetPlatform) {
  TargetPlatform.android => DevicePlatform.android,
  TargetPlatform.iOS => DevicePlatform.ios,
  _ => DevicePlatform.other,
};

/// This install's [DeviceInfo]: the platform and [appBuildVersion].
final Provider<DeviceInfo> deviceInfoProvider = Provider<DeviceInfo>(
  (ref) => DeviceInfo(appVersion: appBuildVersion, platform: devicePlatform()),
);
