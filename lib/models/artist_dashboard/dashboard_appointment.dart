import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Represents a scheduled appointment for an artist.
class DashboardAppointment {
  final String id;
  final String? clientId;
  final String? artistId;
  final String clientName;
  final String? clientAvatar;
  final String serviceType;
  final String duration;
  final String time;
  final String date;
  final String placement;
  final String notes;
  final int depositPaid;
  final int fullPrice;
  final String artworkImageUrl;
  final bool isConsultation;
  final Color dotColor;
  final DateTime? scheduledDate;
  final String? visitType;
  final bool isTouchUp;
  final String? parentAppointmentId;
  final String? parentTattooTitle;
  final String? healedPhotoUrl;

  const DashboardAppointment({
    required this.id,
    this.clientId,
    this.artistId,
    required this.clientName,
    this.clientAvatar,
    required this.serviceType,
    required this.duration,
    required this.time,
    this.date = 'Today',
    this.placement = 'Forearm',
    this.notes = '',
    this.depositPaid = 50,
    this.fullPrice = 250,
    this.artworkImageUrl = '',
    this.isConsultation = false,
    this.dotColor = const Color(0xFF22C55E),
    this.scheduledDate,
    this.visitType,
    this.isTouchUp = false,
    this.parentAppointmentId,
    this.parentTattooTitle,
    this.healedPhotoUrl,
  });

  DashboardAppointment copyWith({
    String? id,
    String? clientId,
    String? artistId,
    String? clientName,
    String? clientAvatar,
    String? serviceType,
    String? duration,
    String? time,
    String? date,
    String? placement,
    String? notes,
    int? depositPaid,
    int? fullPrice,
    String? artworkImageUrl,
    bool? isConsultation,
    Color? dotColor,
    DateTime? scheduledDate,
    String? visitType,
    bool? isTouchUp,
    String? parentAppointmentId,
    String? parentTattooTitle,
    String? healedPhotoUrl,
  }) {
    return DashboardAppointment(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      artistId: artistId ?? this.artistId,
      clientName: clientName ?? this.clientName,
      clientAvatar: clientAvatar ?? this.clientAvatar,
      serviceType: serviceType ?? this.serviceType,
      duration: duration ?? this.duration,
      time: time ?? this.time,
      date: date ?? this.date,
      placement: placement ?? this.placement,
      notes: notes ?? this.notes,
      depositPaid: depositPaid ?? this.depositPaid,
      fullPrice: fullPrice ?? this.fullPrice,
      artworkImageUrl: artworkImageUrl ?? this.artworkImageUrl,
      isConsultation: isConsultation ?? this.isConsultation,
      dotColor: dotColor ?? this.dotColor,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      visitType: visitType ?? this.visitType,
      isTouchUp: isTouchUp ?? this.isTouchUp,
      parentAppointmentId: parentAppointmentId ?? this.parentAppointmentId,
      parentTattooTitle: parentTattooTitle ?? this.parentTattooTitle,
      healedPhotoUrl: healedPhotoUrl ?? this.healedPhotoUrl,
    );
  }

  int get balanceDue => fullPrice - depositPaid;

  String get effectiveVisitType {
    if (visitType != null && visitType!.trim().isNotEmpty) {
      return visitType!.trim();
    }
    if (isConsultation) {
      return 'Consultation';
    }
    final lower = serviceType.toLowerCase();
    if (lower.contains('cover-up') || lower.contains('cover up')) {
      return 'Cover-up';
    }
    if (lower.contains('touch-up') || lower.contains('touch up')) {
      return 'Touch-up';
    }
    if (lower.contains('flash')) {
      return 'Flash Tattoo';
    }
    if (lower.contains('custom')) {
      return 'Custom Tattoo';
    }
    if (lower.contains('fine line') || lower.contains('fineline')) {
      return 'Fine Line';
    }
    if (lower.contains('traditional')) {
      return 'Traditional';
    }
    if (lower.contains('session')) {
      return 'Session Inking';
    }
    return 'Tattoo Session';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'artistId': artistId,
      'clientName': clientName,
      if (clientAvatar != null && clientAvatar!.isNotEmpty) 'clientAvatar': clientAvatar,
      'serviceType': serviceType,
      'duration': duration,
      'time': time,
      'date': date,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'placement': placement,
      'notes': notes,
      'depositPaid': depositPaid,
      'fullPrice': fullPrice,
      'artworkImageUrl': artworkImageUrl,
      'isConsultation': isConsultation,
      'visitType': effectiveVisitType,
      if (isTouchUp) 'isTouchUp': true,
      if (parentAppointmentId != null && parentAppointmentId!.isNotEmpty)
        'parentAppointmentId': parentAppointmentId,
      if (parentTattooTitle != null && parentTattooTitle!.isNotEmpty)
        'parentTattooTitle': parentTattooTitle,
      if (healedPhotoUrl != null && healedPhotoUrl!.isNotEmpty)
        'healedPhotoUrl': healedPhotoUrl,
    };
  }

  factory DashboardAppointment.fromMap(Map<String, dynamic> map, [String? docId]) {
    final isConsult = map['isConsultation'] == true;
    final parsedDate = map['scheduledDate'] is String
        ? DateTime.tryParse(map['scheduledDate'] as String)
        : null;
    final visitTypeStr = map['visitType']?.toString();
    final serviceTypeStr = map['serviceType']?.toString() ?? 'Tattoo Session';
    final detectedTouchUp = map['isTouchUp'] == true ||
        (visitTypeStr?.toLowerCase().contains('touch') ?? false) ||
        serviceTypeStr.toLowerCase().contains('touch-up') ||
        serviceTypeStr.toLowerCase().contains('touch up');
    return DashboardAppointment(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ?? 'apt_${DateTime.now().millisecondsSinceEpoch}'),
      clientId: map['clientId']?.toString(),
      artistId: map['artistId']?.toString(),
      clientName: map['clientName']?.toString() ?? 'Client',
      clientAvatar: (map['clientAvatar'] ??
              map['clientPhotoUrl'] ??
              map['clientPhotoURL'])
          ?.toString(),
      serviceType: serviceTypeStr,
      duration: map['duration']?.toString() ?? '2 hrs',
      time: map['time']?.toString() ?? '1:00 PM',
      date: map['date']?.toString() ?? 'Today',
      scheduledDate: parsedDate,
      placement: map['placement']?.toString() ?? 'Forearm',
      notes: map['notes']?.toString() ?? '',
      depositPaid: (map['depositPaid'] as num?)?.toInt() ?? 50,
      fullPrice: (map['fullPrice'] as num?)?.toInt() ?? 250,
      artworkImageUrl: (map['artworkImageUrl'] ??
              map['flashImageUrl'] ??
              map['imageUrl'] ??
              map['sketchImageUrl'] ??
              '')
          .toString()
          .trim(),
      isConsultation: isConsult,
      visitType: visitTypeStr,
      isTouchUp: detectedTouchUp,
      parentAppointmentId: map['parentAppointmentId']?.toString(),
      parentTattooTitle: map['parentTattooTitle']?.toString(),
      healedPhotoUrl: map['healedPhotoUrl']?.toString(),
      dotColor: isConsult
          ? AppTheme.navInactive
          : (detectedTouchUp ? const Color(0xFFEEC200) : const Color(0xFF22C55E)),
    );
  }
}
