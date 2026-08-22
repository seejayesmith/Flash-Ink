import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final String? role;
  final List<String> aesthetics;
  final bool isAnonymous;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
    this.role,
    this.aesthetics = const [],
    this.isAnonymous = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      role: json['role'] as String?,
      aesthetics: (json['aesthetics'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      isAnonymous: json['isAnonymous'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (role != null) 'role': role,
      'aesthetics': aesthetics,
      'isAnonymous': isAnonymous,
    };
  }
}
