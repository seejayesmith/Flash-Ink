/// Represents an incoming booking / custom request waiting for artist review.
class BookingRequest {
  final String id;
  final String? clientId;
  final String? artistId;
  final String clientName;
  final String? clientAvatar;
  final String timeAgo;
  final String conceptDescription;
  final String placement;
  final String category;
  final String sketchImageUrl;
  final List<String> referenceImageUrls;
  final int estimatedPrice;
  final int deposit;
  final String size;
  final bool isSilentAppointment;
  final String artistName;
  final DateTime? preferredDate;
  final String? preferredTimeSlot;

  const BookingRequest({
    required this.id,
    this.clientId,
    this.artistId,
    required this.clientName,
    this.clientAvatar,
    required this.timeAgo,
    required this.conceptDescription,
    this.placement = 'Outer Thigh',
    this.category = 'Neo-traditional',
    required this.sketchImageUrl,
    this.referenceImageUrls = const [],
    this.estimatedPrice = 300,
    this.deposit = 80,
    this.size = 'Medium (4"-7")',
    this.isSilentAppointment = false,
    this.artistName = 'OddMaree',
    this.preferredDate,
    this.preferredTimeSlot,
  });

  BookingRequest copyWith({
    String? id,
    String? clientId,
    String? artistId,
    String? clientName,
    String? clientAvatar,
    String? timeAgo,
    String? conceptDescription,
    String? placement,
    String? category,
    String? sketchImageUrl,
    List<String>? referenceImageUrls,
    int? estimatedPrice,
    int? deposit,
    String? size,
    bool? isSilentAppointment,
    String? artistName,
    DateTime? preferredDate,
    String? preferredTimeSlot,
  }) {
    return BookingRequest(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      artistId: artistId ?? this.artistId,
      clientName: clientName ?? this.clientName,
      clientAvatar: clientAvatar ?? this.clientAvatar,
      timeAgo: timeAgo ?? this.timeAgo,
      conceptDescription: conceptDescription ?? this.conceptDescription,
      placement: placement ?? this.placement,
      category: category ?? this.category,
      sketchImageUrl: sketchImageUrl ?? this.sketchImageUrl,
      referenceImageUrls: referenceImageUrls ?? this.referenceImageUrls,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      deposit: deposit ?? this.deposit,
      size: size ?? this.size,
      isSilentAppointment: isSilentAppointment ?? this.isSilentAppointment,
      artistName: artistName ?? this.artistName,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTimeSlot: preferredTimeSlot ?? this.preferredTimeSlot,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'artistId': artistId,
      'clientName': clientName,
      if (clientAvatar != null && clientAvatar!.isNotEmpty) 'clientAvatar': clientAvatar,
      'timeAgo': timeAgo,
      'conceptDescription': conceptDescription,
      'placement': placement,
      'category': category,
      'sketchImageUrl': sketchImageUrl,
      'referenceImageUrls': referenceImageUrls,
      'estimatedPrice': estimatedPrice,
      'deposit': deposit,
      'size': size,
      'isSilentAppointment': isSilentAppointment,
      'artistName': artistName,
      'preferredDate': preferredDate?.toIso8601String(),
      'preferredTimeSlot': preferredTimeSlot,
    };
  }

  factory BookingRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    final parsedDate = map['preferredDate'] is String
        ? DateTime.tryParse(map['preferredDate'] as String)
        : null;
    final rawRefs = map['referenceImageUrls'];
    final parsedRefs = rawRefs is List
        ? rawRefs.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return BookingRequest(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ?? 'req_${DateTime.now().millisecondsSinceEpoch}'),
      clientId: map['clientId']?.toString(),
      artistId: map['artistId']?.toString(),
      clientName: map['clientName']?.toString() ?? 'Client',
      clientAvatar: (map['clientAvatar'] ??
              map['clientPhotoUrl'] ??
              map['clientPhotoURL'])
          ?.toString(),
      timeAgo: map['timeAgo']?.toString() ?? 'Recently',
      conceptDescription: map['conceptDescription']?.toString() ?? '',
      placement: map['placement']?.toString() ?? 'Forearm',
      category: map['category']?.toString() ?? 'Custom Design',
      sketchImageUrl: map['sketchImageUrl']?.toString() ?? '',
      referenceImageUrls: parsedRefs,
      estimatedPrice: (map['estimatedPrice'] as num?)?.toInt() ?? 300,
      deposit: (map['deposit'] as num?)?.toInt() ?? 80,
      size: map['size']?.toString() ?? 'Medium (4"-7")',
      isSilentAppointment: map['isSilentAppointment'] == true,
      artistName: map['artistName']?.toString() ?? 'Artist',
      preferredDate: parsedDate,
      preferredTimeSlot: map['preferredTimeSlot']?.toString(),
    );
  }
}
