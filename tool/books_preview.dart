import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/artist_dashboard/artist_books_schedule.dart';
import 'package:flash_ink/models/artist_dashboard/booking_request.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_books_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/booking_request_detail_screen.dart';
import 'package:flash_ink/screens/booking/flash_booking_screen.dart';
import 'package:flash_ink/services/booking_sync_service.dart';
import 'package:flash_ink/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MockDataConfig.debugOverride = true;
  BookingSyncService.enableCloudWrites = false;

  final now = DateTime.now();
  final demoDay = DateTime(now.year, now.month, now.day + 2);
  final demoDateKey = ArtistBooksSchedule.dateKey(demoDay);

  ArtistDashboardRepository.calendarAppointments.clear();
  ArtistDashboardRepository.customHolds = [];
  ArtistDashboardRepository.booksSchedule = ArtistBooksSchedule(
    isBooksOpen: true,
    bookingWindowStart: DateTime(now.year, now.month, 1),
    bookingWindowEnd: DateTime(now.year, now.month + 3, 1),
    hasBookingWindow: false,
    workingDays: const {1, 2, 3, 4, 5, 6, 7},
    startTime: const TimeOfDay(hour: 10, minute: 0),
    endTime: const TimeOfDay(hour: 19, minute: 0),
    slotDurationMinutes: 120,
    bufferDurationMinutes: 60,
    preventDeadGaps: true,
    minBookableSessionMinutes: 60,
    bookedSlots: [
      // Existing 11:00 AM – 1:00 PM (+ 1 hr cleanup until 2:00 PM) on demoDay
      ScheduleSlotEntry(
        dateKey: demoDateKey,
        timeSlot: '11:00 AM',
        startMinutes: 11 * 60,
        durationMinutes: 120,
        bufferMinutes: 60,
      ),
    ],
    locationNote: 'Obsidian Atelier • Portland, OR',
  );

  runApp(const ProviderScope(child: BooksInteractivePreviewApp()));
}

class BooksInteractivePreviewApp extends StatefulWidget {
  const BooksInteractivePreviewApp({super.key});

  @override
  State<BooksInteractivePreviewApp> createState() =>
      _BooksInteractivePreviewAppState();
}

class _BooksInteractivePreviewAppState
    extends State<BooksInteractivePreviewApp> {
  int _activeTab = 0;

  static const _demoArtist = Artist(
    id: 'artist_preview_1',
    name: 'OddMaree',
    avatarUrl: '',
    location: 'Portland, OR',
    studioName: 'Obsidian Atelier',
    studioType: 'Private Studio',
    rating: 4.9,
    minDeposit: 80,
    availablePieces: 6,
    images: [],
  );

  static const _demoFlash = FlashArtwork(
    id: 'flash_preview_1',
    artistId: 'artist_preview_1',
    artistName: 'OddMaree',
    title: 'Obsidian Serpent & Peony',
    imageUrl: 'assets/images/flash_traditional_panther.jpg',
    price: 320,
    deposit: 80,
    estimatedTime: '2.0 hrs',
    location: 'Forearm / Calf',
    status: FlashStatus.available,
  );

  static const _demoRequest = BookingRequest(
    id: 'req_preview_1',
    artistId: 'artist_preview_1',
    artistName: 'OddMaree',
    clientId: 'client_preview_1',
    clientName: 'Jordan K.',
    timeAgo: 'Just now',
    conceptDescription:
        'Neo-traditional serpent wrapping around forearm with botanical detail.',
    placement: 'Forearm',
    category: 'Neo-Traditional',
    sketchImageUrl: 'assets/images/flash_traditional_panther.jpg',
    estimatedPrice: 450,
    deposit: 100,
    size: 'Medium (4"-7")',
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash.Ink — Books & Scheduling Preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0C0C),
        body: SafeArea(
          child: Column(
            children: [
              // Switcher bar to jump directly between Artist Books, Client Flash Booking, and Custom Proposal
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF141717),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF282C2C)),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _tabButton(0, '1. Artist Books Settings'),
                    _tabButton(1, '2. Client Flash Booking'),
                    _tabButton(2, '3. Custom Time Proposals'),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.onyxBackground,
                        border: Border.symmetric(
                          vertical: BorderSide(
                            color: AppTheme.darkBorder.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      child: _buildActiveScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final isSelected = _activeTab == index;
    return ChoiceChip(
      key: Key('preview_tab_$index'),
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppTheme.gold,
      backgroundColor: const Color(0xFF1E2121),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.onyxBackground : AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      onSelected: (_) => setState(() => _activeTab = index),
    );
  }

  Widget _buildActiveScreen() {
    switch (_activeTab) {
      case 0:
        return const ArtistBooksScreen(
          key: ValueKey('preview_books'),
          artist: _demoArtist,
          isEmbeddedInTab: true,
        );
      case 1:
        return const FlashBookingScreen(
          key: ValueKey('preview_flash'),
          flash: _demoFlash,
          artist: _demoArtist,
        );
      case 2:
      default:
        return const BookingRequestDetailScreen(
          key: ValueKey('preview_custom'),
          request: _demoRequest,
        );
    }
  }
}
