enum AppointmentStatus {
  confirmed('Confirmed'),
  pending('Deposit Pending'),
  completed('Completed'),
  cancelled('Cancelled');

  final String label;
  const AppointmentStatus(this.label);
}

/// Strongly typed client appointment data model.
class ClientAppointment {
  final String id;
  final String artistName;
  final String artistAvatar;
  final String studioName;
  final String studioAddress;
  final String flashTitle;
  final String flashImageUrl;
  final DateTime dateTime;
  final String timeSlot;
  final String placement;
  final int depositAmount;
  final int totalPrice;
  final AppointmentStatus status;
  final bool isSilentAppointment;
  final String? notes;

  int get balanceDue => totalPrice - depositAmount;

  const ClientAppointment({
    required this.id,
    required this.artistName,
    required this.artistAvatar,
    required this.studioName,
    required this.studioAddress,
    required this.flashTitle,
    required this.flashImageUrl,
    required this.dateTime,
    required this.timeSlot,
    required this.placement,
    required this.depositAmount,
    required this.totalPrice,
    required this.status,
    this.isSilentAppointment = false,
    this.notes,
  });

  static List<ClientAppointment> mockUpcoming = [
    ClientAppointment(
      id: 'APT-84021',
      artistName: 'OddMaree',
      artistAvatar:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      studioName: 'Obsidian Atelier',
      studioAddress: '742 S Santa Fe Ave, Los Angeles, CA',
      flashTitle: 'Sacred Serpent & Peony',
      flashImageUrl:
          'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=500&q=80',
      dateTime: DateTime(2026, 10, 14, 14, 0),
      timeSlot: '2:00 PM (3.0 hrs)',
      placement: 'Right Forearm',
      depositAmount: 75,
      totalPrice: 280,
      status: AppointmentStatus.confirmed,
      isSilentAppointment: true,
      notes: 'Inner forearm placement, black & grey shading preferred.',
    ),
    ClientAppointment(
      id: 'APT-77291',
      artistName: 'Maree Raven',
      artistAvatar:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
      studioName: 'Void & Bloom Tattoo',
      studioAddress: '1280 E 1st St, Los Angeles, CA',
      flashTitle: 'Lunar Moth & Geometry',
      flashImageUrl:
          'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=500&q=80',
      dateTime: DateTime(2026, 11, 2, 11, 30),
      timeSlot: '11:30 AM (2.5 hrs)',
      placement: 'Upper Arm / Bicep',
      depositAmount: 50,
      totalPrice: 200,
      status: AppointmentStatus.confirmed,
      isSilentAppointment: false,
    ),
  ];

  static List<ClientAppointment> mockPast = [
    ClientAppointment(
      id: 'APT-51092',
      artistName: 'Kora Sol',
      artistAvatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      studioName: 'Velvet Needle Parlor',
      studioAddress: '310 Sunset Blvd, Venice, CA',
      flashTitle: 'Chrysanthemum Silhouette',
      flashImageUrl:
          'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=500&q=80',
      dateTime: DateTime(2026, 7, 18, 15, 0),
      timeSlot: '3:00 PM (3.5 hrs)',
      placement: 'Left Thigh',
      depositAmount: 80,
      totalPrice: 320,
      status: AppointmentStatus.completed,
      isSilentAppointment: true,
    ),
  ];
}
