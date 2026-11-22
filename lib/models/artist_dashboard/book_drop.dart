enum BookingMode {
  alwaysOpen,
  drops,
}

enum BookDropStatus {
  scheduled,
  earlyAccess,
  open,
  full,
  closed,
}

/// Represents an intentional booking release or drop window.
class BookDrop {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final BookDropStatus status;
  final Set<int> selectedDays; // Month day numbers or timestamps
  final bool acceptFlash;
  final bool acceptCustom;
  final bool acceptTouchUps;
  final int? requestCap;
  final int requestCount;
  final DateTime? opensAt;
  final int earlyAccessHours;
  final DateTime? earlyAccessEndsAt;

  const BookDrop({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.status = BookDropStatus.open,
    this.selectedDays = const {},
    this.acceptFlash = true,
    this.acceptCustom = true,
    this.acceptTouchUps = true,
    this.requestCap,
    this.requestCount = 0,
    this.opensAt,
    this.earlyAccessHours = 24,
    this.earlyAccessEndsAt,
  });

  BookDrop copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    BookDropStatus? status,
    Set<int>? selectedDays,
    bool? acceptFlash,
    bool? acceptCustom,
    bool? acceptTouchUps,
    int? requestCap,
    int? requestCount,
    DateTime? opensAt,
    int? earlyAccessHours,
    DateTime? earlyAccessEndsAt,
  }) {
    return BookDrop(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      selectedDays: selectedDays ?? this.selectedDays,
      acceptFlash: acceptFlash ?? this.acceptFlash,
      acceptCustom: acceptCustom ?? this.acceptCustom,
      acceptTouchUps: acceptTouchUps ?? this.acceptTouchUps,
      requestCap: requestCap ?? this.requestCap,
      requestCount: requestCount ?? this.requestCount,
      opensAt: opensAt ?? this.opensAt,
      earlyAccessHours: earlyAccessHours ?? this.earlyAccessHours,
      earlyAccessEndsAt: earlyAccessEndsAt ?? this.earlyAccessEndsAt,
    );
  }
}

/// Represents a 24-hour temporary hold created when an artist proposes slots for a custom request.
class CustomHold {
  final String id;
  final String requestId;
  final String clientName;
  final DateTime date;
  final String timeSlot;
  final int durationMinutes;
  final int estimatedPrice;
  final int deposit;
  final DateTime createdAt;
  final DateTime expiresAt;

  const CustomHold({
    required this.id,
    required this.requestId,
    required this.clientName,
    required this.date,
    required this.timeSlot,
    this.durationMinutes = 180,
    required this.estimatedPrice,
    required this.deposit,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get remainingTime =>
      isExpired ? Duration.zero : expiresAt.difference(DateTime.now());

  CustomHold copyWith({
    String? id,
    String? requestId,
    String? clientName,
    DateTime? date,
    String? timeSlot,
    int? durationMinutes,
    int? estimatedPrice,
    int? deposit,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return CustomHold(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      clientName: clientName ?? this.clientName,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      deposit: deposit ?? this.deposit,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
