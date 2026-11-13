import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/mock/mock_data_config.dart';
import '../../core/mock/mock_fixtures.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../models/artist.dart';
import '../../repositories/artist_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/artist_top_bar.dart';
import 'artist_account_screen.dart';
import 'artist_upload_flash_screen.dart';
import '../../features/artist/presentation/widgets/flash_piece_card.dart';

enum CollectionsFilter {
  available('Available'),
  claimed('Claimed'),
  all('All');

  final String label;
  const CollectionsFilter(this.label);
}

/// Screen allowing logged-in artists to view, upload, edit, and organize their
/// flash artwork catalog ("Collections" tab in the bottom navigation bar).
class ArtistCollectionsScreen extends StatefulWidget {
  final Artist? artist;
  final AuthService? authService;
  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;
  final bool isEmbeddedInTab;
  final VoidCallback? onNavigateToAccount;

  const ArtistCollectionsScreen({
    super.key,
    this.artist,
    this.authService,
    this.firestore,
    this.storage,
    this.isEmbeddedInTab = true,
    this.onNavigateToAccount,
  });

  @override
  State<ArtistCollectionsScreen> createState() => _ArtistCollectionsScreenState();
}

class _ArtistCollectionsScreenState extends State<ArtistCollectionsScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  Artist? _liveArtist;
  CollectionsFilter _selectedFilter = CollectionsFilter.available;

  @override
  void initState() {
    super.initState();
    _loadLiveArtistProfile();
  }

  Future<void> _loadLiveArtistProfile() async {
    try {
      final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
      final uid = widget.artist?.id ?? user?.uid;
      if (uid == null || uid.isEmpty) return;

      final db = widget.firestore ?? FirebaseFirestore.instance;
      final doc = await db.collection('artists').doc(uid).get();
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _liveArtist = Artist.fromMap(doc.data()!, doc.id);
        });
      }
    } catch (_) {}
  }

  Artist get _effectiveArtist {
    if (_liveArtist != null) return _liveArtist!;
    if (widget.artist != null) return widget.artist!;
    if (MockDataConfig.isEnabled) {
      return MockFixtures.artists.first;
    }
    return const Artist(
      id: '',
      name: 'Artist',
      username: '',
      studioName: '',
      avatarUrl: '',
      location: '',
      studioType: 'Private Studio',
      rating: 5.0,
      availablePieces: 0,
      minDeposit: 50,
      flashArtworks: [],
    );
  }

  List<FlashArtwork> get _allFlashArtworks {
    return _effectiveArtist.flashArtworks;
  }

  List<FlashArtwork> get _filteredArtworks {
    final list = _allFlashArtworks;
    switch (_selectedFilter) {
      case CollectionsFilter.available:
        return list.where((a) => a.status != FlashStatus.claimed).toList();
      case CollectionsFilter.claimed:
        return list.where((a) => a.status == FlashStatus.claimed).toList();
      case CollectionsFilter.all:
        return list;
    }
  }

  int get _availableCount =>
      _allFlashArtworks.where((a) => a.status != FlashStatus.claimed).length;

  int get _claimedCount =>
      _allFlashArtworks.where((a) => a.status == FlashStatus.claimed).length;

  Future<void> _navigateToAccount() async {
    if (widget.onNavigateToAccount != null) {
      widget.onNavigateToAccount!();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistAccountScreen(
          artist: _effectiveArtist,
          authService: _authService,
          firestore: widget.firestore,
        ),
      ),
    );
    _loadLiveArtistProfile();
  }

  Future<void> _navigateToMessages() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MessagesScreen(),
      ),
    );
  }

  Future<void> _openUploadScreen({FlashArtwork? existingArtwork}) async {
    final result = await Navigator.push<FlashArtwork?>(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistUploadFlashScreen(
          artist: _effectiveArtist,
          existingArtwork: existingArtwork,
          authService: _authService,
          firestore: widget.firestore,
          storage: widget.storage,
        ),
      ),
    );

    if (result != null && mounted) {
      // Local optimistic update
      final currentList = List<FlashArtwork>.from(_effectiveArtist.flashArtworks);
      if (existingArtwork != null) {
        final index = currentList.indexWhere((a) => a.id == result.id);
        if (index != -1) {
          currentList[index] = result;
        } else {
          currentList.insert(0, result);
        }
      } else {
        currentList.removeWhere((a) => a.id == result.id);
        currentList.insert(0, result);
      }

      setState(() {
        _liveArtist = _effectiveArtist.copyWith(
          flashArtworks: currentList,
          availablePieces: currentList.where((a) => !a.isClaimed).length,
        );
      });
      _loadLiveArtistProfile();
    }
  }

  Future<void> _toggleArtworkStatus(FlashArtwork artwork) async {
    final isCurrentlyClaimed = artwork.status == FlashStatus.claimed;
    final newStatus = isCurrentlyClaimed
        ? (artwork.isExclusive ? FlashStatus.available : FlashStatus.repeatable)
        : FlashStatus.claimed;

    final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
    final uid = _effectiveArtist.id.isNotEmpty ? _effectiveArtist.id : (user?.uid ?? '');

    // Optimistic local update
    final currentList = _effectiveArtist.flashArtworks.map((item) {
      if (item.id == artwork.id) {
        return item.copyWith(status: newStatus);
      }
      return item;
    }).toList();

    setState(() {
      _liveArtist = _effectiveArtist.copyWith(
        flashArtworks: currentList,
        availablePieces: currentList.where((a) => !a.isClaimed).length,
      );
    });

    final isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (uid.isNotEmpty && (!isWidgetTest || widget.firestore != null)) {
      await ArtistRepository.toggleFlashArtworkStatus(
        uid: uid,
        artworkId: artwork.id,
        newStatus: newStatus,
        firestore: widget.firestore,
      );
    }

    if (mounted) {
      FlashSnackBar.showSuccess(
        context,
        newStatus == FlashStatus.claimed
            ? 'Flash piece marked as Claimed'
            : 'Flash piece marked as Available',
      );
    }
  }

  Future<void> _deleteArtwork(FlashArtwork artwork) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2121),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          side: const BorderSide(color: Color(0xFF333737)),
        ),
        title: Text(
          'Delete Flash Artwork?',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${artwork.title}"? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_flash_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.favoriteActive,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
    final uid = _effectiveArtist.id.isNotEmpty ? _effectiveArtist.id : (user?.uid ?? '');

    // Optimistic local update
    final currentList = _effectiveArtist.flashArtworks
        .where((item) => item.id != artwork.id)
        .toList();

    setState(() {
      _liveArtist = _effectiveArtist.copyWith(
        flashArtworks: currentList,
        availablePieces: currentList.where((a) => !a.isClaimed).length,
      );
    });

    final isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (uid.isNotEmpty && (!isWidgetTest || widget.firestore != null)) {
      await ArtistRepository.deleteFlashArtwork(
        uid: uid,
        artworkId: artwork.id,
        firestore: widget.firestore,
      );
    }

    if (mounted) {
      FlashSnackBar.showSuccess(
        context,
        '"${artwork.title}" deleted from Collections',
      );
    }
  }

  void _showArtworkDetailModal(FlashArtwork artwork) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isClaimed = artwork.status == FlashStatus.claimed;

        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: const Color(0xFF1E2121),
          topRadius: AppRadius.radiusSheet,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Center grab handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF333737),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: FlashImage(
                        urlOrPath: artwork.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title and status badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          artwork.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isClaimed
                              ? const Color(0xFF333737)
                              : const Color(0xFFEEC200).withAlpha(40),
                          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                          border: Border.all(
                            color: isClaimed
                                ? const Color(0xFF555B5B)
                                : const Color(0xFFEEC200),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          artwork.status.label.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: isClaimed
                                ? const Color(0xFF8C9191)
                                : const Color(0xFFEEC200),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Metadata chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDetailBadge('Price: \$${artwork.price}'),
                      _buildDetailBadge('Deposit: \$${artwork.deposit}'),
                      _buildDetailBadge('Size: ${artwork.size}'),
                      _buildDetailBadge('Style: ${artwork.category}'),
                      _buildDetailBadge(artwork.isExclusive ? 'One-off Exclusive' : 'Repeatable'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  ElevatedButton.icon(
                    key: const Key('modal_edit_flash_button'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Artwork Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openUploadScreen(existingArtwork: artwork);
                    },
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    key: const Key('modal_toggle_status_button'),
                    icon: Icon(
                      isClaimed ? Icons.check_circle_outline : Icons.block_outlined,
                      size: 18,
                    ),
                    label: Text(isClaimed ? 'Mark as Available' : 'Mark as Claimed'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF333737)),
                      minimumSize: const Size.fromHeight(48),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _toggleArtworkStatus(artwork);
                    },
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    key: const Key('modal_delete_flash_button'),
                    icon: const Icon(Icons.delete_outline, color: AppTheme.favoriteActive, size: 18),
                    label: Text(
                      'Delete Flash Piece',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.favoriteActive,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.favoriteActive.withAlpha(120)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _deleteArtwork(artwork);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF262929),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(color: const Color(0xFF333737)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFFDCDFE0),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTopActionBar() {
    String? authPhoto;
    try {
      authPhoto = _authService.currentUser?.photoURL;
    } catch (_) {}
    final avatarUrl = _effectiveArtist.avatarUrl.isNotEmpty
        ? _effectiveArtist.avatarUrl
        : (authPhoto ?? '');

    final avatarChild = CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF262929),
      child: ClipOval(
        child: FlashImage(
          urlOrPath: avatarUrl,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorWidget: Container(
            color: const Color(0xFF262929),
            alignment: Alignment.center,
            child: Text(
              _effectiveArtist.name.isNotEmpty
                  ? _effectiveArtist.name[0]
                  : 'A',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEEC200),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );

    return ArtistTopBar(
      logoKey: const Key('collections_tattoo_machine_logo'),
      messagesKey: const Key('top_action_messages_button'),
      avatarKey: const Key('collections_artist_avatar_button'),
      onMessagesTap: _navigateToMessages,
      onAvatarTap: _navigateToAccount,
      avatarChild: avatarChild,
      artistId: _effectiveArtist.id.isNotEmpty ? _effectiveArtist.id : _authService.currentUser?.uid,
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E1E),
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
        border: Border.all(color: const Color(0xFF333737)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: CollectionsFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          String countLabel = '';
          if (filter == CollectionsFilter.available) {
            countLabel = ' ($_availableCount)';
          } else if (filter == CollectionsFilter.claimed) {
            countLabel = ' ($_claimedCount)';
          } else {
            countLabel = ' (${_allFlashArtworks.length})';
          }

          return Expanded(
            child: GestureDetector(
              key: Key('filter_tab_${filter.name}'),
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEEC200) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${filter.label}$countLabel',
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? const Color(0xFF121414) : const Color(0xFF8C9191),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2121),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF333737)),
            ),
            child: const Icon(
              Icons.collections_outlined,
              color: Color(0xFFEEC200),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == CollectionsFilter.claimed
                ? 'No Claimed Flash Yet'
                : 'No Flash Works in this Filter',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == CollectionsFilter.claimed
                ? 'When clients book exclusive flash pieces, they will appear here.'
                : 'Upload flash designs to showcase on your profile and start taking bookings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            key: const Key('empty_state_upload_flash_button'),
            onPressed: () => _openUploadScreen(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Upload Flash Work'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEEC200),
              foregroundColor: const Color(0xFF121414),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredArtworks;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          12,
          AppSpacing.screenGutter,
          MediaQuery.paddingOf(context).bottom + 90,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopActionBar(),
            const SizedBox(height: 20),

            // Header row with Title and + NEW FLASH button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flash Collections',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_availableCount available • ${_allFlashArtworks.length} total pieces',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  key: const Key('add_new_flash_button'),
                  onPressed: () => _openUploadScreen(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Flash'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _buildFilterToggle(),
            const SizedBox(height: 20),

            if (filtered.isEmpty)
              _buildEmptyState()
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.spaceSm + 2,
                  mainAxisSpacing: AppSpacing.spaceMd,
                  childAspectRatio: 0.58,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final piece = filtered[index];
                  return FlashPieceCard(
                    piece: piece,
                    onTap: () => _showArtworkDetailModal(piece),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
