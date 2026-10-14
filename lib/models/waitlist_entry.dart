import 'package:flutter/material.dart';

/// Status of a client on an artist's VIP waitlist.
enum WaitlistStatus {
  waiting('Waiting', Color(0xFFEEC200), Icons.hourglass_top_rounded),
  earlyAccessSent('Early Access Sent', Color(0xFF38BDF8), Icons.send_rounded),
  booked('Booked', Color(0xFF22C55E), Icons.check_circle_rounded),
  archived('Archived', Color(0xFF919696), Icons.archive_outlined);

  final String label;
  final Color badgeColor;
  final IconData icon;

  const WaitlistStatus(this.label, this.badgeColor, this.icon);

  static WaitlistStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'earlyaccesssent':
      case 'early_access_sent':
      case 'invited':
        return WaitlistStatus.earlyAccessSent;
      case 'booked':
      case 'scheduled':
        return WaitlistStatus.booked;
      case 'archived':
        return WaitlistStatus.archived;
      case 'waiting':
      default:
        return WaitlistStatus.waiting;
    }
  }
}

/// Represents a friend, family member, or VIP client on an artist's waitlist.
class WaitlistEntry {
  final String id;
  final String artistId;
  final String clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? flashUserId;
  final String? avatarUrl;
  final String relationshipTag; // 'Friends & Family', 'VIP Client', 'Regular', 'Direct Inquiry'
  final String designType; // 'Custom' or 'Flash'
  final String conceptDescription;
  final String placement;
  final int? budget;
  final String availabilityPreference; // e.g. 'Weekends', 'Weekday Evenings', 'Flexible'
  final String? referenceImageUrl;
  final String? notes;
  final WaitlistStatus status;
  final DateTime createdAt;
  final DateTime? invitedAt;
  final DateTime? bookedAt;
  final String vipAccessCode;
  final String vipBookingLink;

  const WaitlistEntry({
    required this.id,
    this.artistId = 'artist_odd_maree',
    required this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.flashUserId,
    this.avatarUrl,
    this.relationshipTag = 'Friends & Family',
    this.designType = 'Custom',
    required this.conceptDescription,
    this.placement = 'Forearm',
    this.budget,
    this.availabilityPreference = 'Flexible',
    this.referenceImageUrl,
    this.notes,
    this.status = WaitlistStatus.waiting,
    required this.createdAt,
    this.invitedAt,
    this.bookedAt,
    this.vipAccessCode = 'VIP-FLASH-2026',
    this.vipBookingLink = 'https://flashink.app/vip/oddmaree',
  });

  bool get isRegisteredFlashUser => flashUserId != null && flashUserId!.isNotEmpty;
  bool get hasEarlyAccessSent => status == WaitlistStatus.earlyAccessSent;
  bool get isBooked => status == WaitlistStatus.booked;

  WaitlistEntry copyWith({
    String? id,
    String? artistId,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    String? flashUserId,
    String? avatarUrl,
    String? relationshipTag,
    String? designType,
    String? conceptDescription,
    String? placement,
    int? budget,
    String? availabilityPreference,
    String? referenceImageUrl,
    String? notes,
    WaitlistStatus? status,
    DateTime? createdAt,
    DateTime? invitedAt,
    DateTime? bookedAt,
    String? vipAccessCode,
    String? vipBookingLink,
  }) {
    return WaitlistEntry(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      flashUserId: flashUserId ?? this.flashUserId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      relationshipTag: relationshipTag ?? this.relationshipTag,
      designType: designType ?? this.designType,
      conceptDescription: conceptDescription ?? this.conceptDescription,
      placement: placement ?? this.placement,
      budget: budget ?? this.budget,
      availabilityPreference: availabilityPreference ?? this.availabilityPreference,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      invitedAt: invitedAt ?? this.invitedAt,
      bookedAt: bookedAt ?? this.bookedAt,
      vipAccessCode: vipAccessCode ?? this.vipAccessCode,
      vipBookingLink: vipBookingLink ?? this.vipBookingLink,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artistId': artistId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'flashUserId': flashUserId,
      'avatarUrl': avatarUrl,
      'relationshipTag': relationshipTag,
      'designType': designType,
      'conceptDescription': conceptDescription,
      'placement': placement,
      'budget': budget,
      'availabilityPreference': availabilityPreference,
      'referenceImageUrl': referenceImageUrl,
      'notes': notes,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'invitedAt': invitedAt?.toIso8601String(),
      'bookedAt': bookedAt?.toIso8601String(),
      'vipAccessCode': vipAccessCode,
      'vipBookingLink': vipBookingLink,
    };
  }

  factory WaitlistEntry.fromMap(Map<String, dynamic> map) {
    return WaitlistEntry(
      id: map['id'] as String? ?? 'wl_${DateTime.now().millisecondsSinceEpoch}',
      artistId: map['artistId'] as String? ?? 'artist_odd_maree',
      clientName: map['clientName'] as String? ?? 'Guest Friend',
      clientEmail: map['clientEmail'] as String?,
      clientPhone: map['clientPhone'] as String?,
      flashUserId: map['flashUserId'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      relationshipTag: map['relationshipTag'] as String? ?? 'Friends & Family',
      designType: map['designType'] as String? ?? 'Custom',
      conceptDescription: map['conceptDescription'] as String? ?? '',
      placement: map['placement'] as String? ?? 'Forearm',
      budget: (map['budget'] as num?)?.toInt(),
      availabilityPreference: map['availabilityPreference'] as String? ?? 'Flexible',
      referenceImageUrl: map['referenceImageUrl'] as String?,
      notes: map['notes'] as String?,
      status: WaitlistStatus.fromString(map['status'] as String? ?? 'waiting'),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      invitedAt: map['invitedAt'] != null
          ? DateTime.tryParse(map['invitedAt'] as String)
          : null,
      bookedAt: map['bookedAt'] != null
          ? DateTime.tryParse(map['bookedAt'] as String)
          : null,
      vipAccessCode: map['vipAccessCode'] as String? ?? 'VIP-FLASH-2026',
      vipBookingLink: map['vipBookingLink'] as String? ?? 'https://flashink.app/vip/oddmaree',
    );
  }

  /// Initial sample waitlist roster representing friends, family, and VIP clients.
  static List<WaitlistEntry> get mockWaitlistEntries => [
        WaitlistEntry(
          id: 'wl_001',
          clientName: 'Chloe Bennett',
          clientEmail: 'chloe.bennett@example.com',
          clientPhone: '(503) 555-0192',
          flashUserId: 'user_chloe_b',
          avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
          relationshipTag: 'Friends & Family',
          designType: 'Custom',
          conceptDescription: 'Micro realism lavender sprig & moon with sister. Fine line needlework.',
          placement: 'Inner Forearm',
          budget: 280,
          availabilityPreference: 'Saturdays or Weekday Evenings',
          referenceImageUrl: 'assets/images/flash_fineline_flora.jpg',
          notes: 'Sister of Maya. Promised her a spot as soon as October books open!',
          status: WaitlistStatus.waiting,
          createdAt: DateTime.now().subtract(const Duration(days: 12)),
          vipAccessCode: 'VIP-CHLOE-77',
          vipBookingLink: 'https://flashink.app/vip/oddmaree?code=VIP-CHLOE-77',
        ),
        WaitlistEntry(
          id: 'wl_002',
          clientName: 'Julian Alvarez',
          clientEmail: 'julian.ink@example.com',
          clientPhone: '(503) 555-0841',
          flashUserId: 'user_julian_a',
          avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
          relationshipTag: 'VIP Regular',
          designType: 'Custom',
          conceptDescription: 'Blackwork skull & dagger continuation to connect upper arm sleeve.',
          placement: 'Upper Arm / Tricep',
          budget: 550,
          availabilityPreference: 'Flexible anytime',
          referenceImageUrl: 'assets/images/flash_traditional_dagger.jpg',
          notes: 'Returning client for 3rd piece. Wants 4hr dedicated session.',
          status: WaitlistStatus.waiting,
          createdAt: DateTime.now().subtract(const Duration(days: 8)),
          vipAccessCode: 'VIP-JULIAN-94',
          vipBookingLink: 'https://flashink.app/vip/oddmaree?code=VIP-JULIAN-94',
        ),
        WaitlistEntry(
          id: 'wl_003',
          clientName: 'Aunt Michelle',
          clientEmail: 'michelle.miller@gmail.com',
          clientPhone: '(503) 555-7320',
          flashUserId: null, // Manual non-app contact
          avatarUrl: null,
          relationshipTag: 'Friends & Family',
          designType: 'Flash',
          conceptDescription: 'Botanical hummingbird flash piece or gentle floral branch.',
          placement: 'Ankle / Calf',
          budget: 200,
          availabilityPreference: 'Sunday afternoons only',
          referenceImageUrl: null,
          notes: 'Family member. Needs quick SMS link when books open since she does not have the app.',
          status: WaitlistStatus.waiting,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          vipAccessCode: 'VIP-MICHELLE-21',
          vipBookingLink: 'https://flashink.app/vip/oddmaree?code=VIP-MICHELLE-21',
        ),
        WaitlistEntry(
          id: 'wl_004',
          clientName: 'Marcus Cole',
          clientEmail: 'marcus.cole@example.com',
          clientPhone: '(503) 555-9923',
          flashUserId: 'user_marcus_c',
          avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
          relationshipTag: 'VIP Regular',
          designType: 'Custom',
          conceptDescription: 'Japanese traditional koi dragon half-chest panel.',
          placement: 'Left Chest',
          budget: 450,
          availabilityPreference: 'Thursdays or Fridays',
          referenceImageUrl: 'assets/images/flash_japanese_koi.jpg',
          notes: 'Already pre-discussed consultation on Sep 9.',
          status: WaitlistStatus.earlyAccessSent,
          createdAt: DateTime.now().subtract(const Duration(days: 14)),
          invitedAt: DateTime.now().subtract(const Duration(hours: 4)),
          vipAccessCode: 'VIP-MARCUS-33',
          vipBookingLink: 'https://flashink.app/vip/oddmaree?code=VIP-MARCUS-33',
        ),
      ];
}
