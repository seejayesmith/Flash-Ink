import 'package:cloud_firestore/cloud_firestore.dart';

class CoreConfig {
  final double platformFeePercent;
  final double minDepositAmount;
  final bool referralsEnabled;
  final int referralThreshold;
  final double referralRewardAmount;
  final bool isMaintenanceMode;
  final String minSupportedVersion;

  CoreConfig({
    this.platformFeePercent = 0.0,
    this.minDepositAmount = 20.0,
    this.referralsEnabled = false,
    this.referralThreshold = 3,
    this.referralRewardAmount = 0.0,
    this.isMaintenanceMode = false,
    this.minSupportedVersion = "1.0.0",
  });

  factory CoreConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    return CoreConfig(
      platformFeePercent: (data?['platformFeePercent'] as num?)?.toDouble() ?? 0.0,
      minDepositAmount: (data?['minDepositAmount'] as num?)?.toDouble() ?? 20.0,
      referralsEnabled: data?['referralsEnabled'] as bool? ?? false,
      referralThreshold: data?['referralThreshold'] as int? ?? 3,
      referralRewardAmount: (data?['referralRewardAmount'] as num?)?.toDouble() ?? 0.0,
      isMaintenanceMode: data?['isMaintenanceMode'] as bool? ?? false,
      minSupportedVersion: data?['minSupportedVersion'] as String? ?? "1.0.0",
    );
  }

  factory CoreConfig.fromJson(Map<String, dynamic> json) {
    return CoreConfig(
      platformFeePercent: (json['platformFeePercent'] as num?)?.toDouble() ?? 0.0,
      minDepositAmount: (json['minDepositAmount'] as num?)?.toDouble() ?? 20.0,
      referralsEnabled: json['referralsEnabled'] as bool? ?? false,
      referralThreshold: json['referralThreshold'] as int? ?? 3,
      referralRewardAmount: (json['referralRewardAmount'] as num?)?.toDouble() ?? 0.0,
      isMaintenanceMode: json['isMaintenanceMode'] as bool? ?? false,
      minSupportedVersion: json['minSupportedVersion'] as String? ?? "1.0.0",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platformFeePercent': platformFeePercent,
      'minDepositAmount': minDepositAmount,
      'referralsEnabled': referralsEnabled,
      'referralThreshold': referralThreshold,
      'referralRewardAmount': referralRewardAmount,
      'isMaintenanceMode': isMaintenanceMode,
      'minSupportedVersion': minSupportedVersion,
    };
  }
}
