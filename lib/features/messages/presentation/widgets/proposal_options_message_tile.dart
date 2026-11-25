import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/mock/mock_data_config.dart';
import '../../../../models/artist_dashboard/artist_books_schedule.dart';
import '../../../../repositories/artist_dashboard_repository.dart';
import '../../../../services/booking_sync_service.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../../domain/models/message_thread.dart';

/// Interactive chat card displaying 1–3 artist-proposed dates & times.
///
/// When a client selects one of the proposed times and taps Confirm, this card
/// re-checks the artist's live schedule (cloud + local) to prevent double-booking
/// if another client claimed that slot after the proposal was sent.
class ProposalOptionsMessageTile extends StatefulWidget {
  final ChatMessage message;
  final MessageThread? thread;
  final bool isArtistView;
  final FirebaseFirestore? firestore;
  final ValueChanged<({ChatMessage updatedProposal, ChatMessage receiptMessage})>?
      onProposalConfirmed;

  const ProposalOptionsMessageTile({
    super.key,
    required this.message,
    this.thread,
    this.isArtistView = false,
    this.firestore,
    this.onProposalConfirmed,
  });

  @override
  State<ProposalOptionsMessageTile> createState() =>
      _ProposalOptionsMessageTileState();
}

class _ProposalOptionsMessageTileState
    extends State<ProposalOptionsMessageTile> {
  static const Color _confirmedGreen = Color(0xFF4ADE80);

  ArtistBooksSchedule? _remoteSchedule;
  final Set<String> _unavailableKeys = {};
  int? _selectedIndex;
  int? _confirmedIndex;
  bool _isConfirming = false;

  String get _effectiveArtistId {
    final fromThread = widget.thread?.artistId.trim() ?? '';
    if (fromThread.isNotEmpty) return fromThread;
    return widget.message.senderId.trim();
  }

  @override
  void initState() {
    super.initState();
    _confirmedIndex = widget.message.selectedProposalIndex;
    _loadLatestArtistSchedule();
  }

  @override
  void didUpdateWidget(covariant ProposalOptionsMessageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.selectedProposalIndex !=
        widget.message.selectedProposalIndex) {
      _confirmedIndex = widget.message.selectedProposalIndex;
    }
  }

  Future<void> _loadLatestArtistSchedule() async {
    final artistId = _effectiveArtistId;
    if (artistId.isEmpty) return;
    if (MockDataConfig.isEnabled && widget.firestore == null) return;

    final fetched = await BookingSyncService.fetchArtistScheduleFromCloud(
      artistId,
      firestore: widget.firestore,
    );
    if (!mounted || fetched == null) return;
    setState(() {
      _remoteSchedule = fetched;
    });
  }

  bool _isOptionAvailable(ProposedTimeOption opt) {
    if (_unavailableKeys.contains(opt.uniqueKey)) return false;
    final artistId = _effectiveArtistId.isNotEmpty ? _effectiveArtistId : null;
    final effectiveSchedule =
        _remoteSchedule ?? ArtistDashboardRepository.booksSchedule;
    final durationMins = opt.durationMinutes > 0
        ? opt.durationMinutes
        : (widget.message.appointmentDurationMinutes ??
            effectiveSchedule.slotDurationMinutes);
    return ArtistDashboardRepository.isSlotBookable(
      date: opt.date,
      timeSlot: opt.timeSlot,
      schedule: _remoteSchedule,
      artistId: artistId,
      startMinutes: opt.startMinutes,
      durationMinutes: durationMins,
      bufferMinutes: effectiveSchedule.bufferDurationMinutes,
    );
  }

  String _formatOptionDate(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }

  String _formatDuration(int? mins) {
    if (mins == null || mins <= 0) return '';
    final hrs = mins / 60.0;
    return hrs == hrs.roundToDouble()
        ? '${hrs.toInt()} ${hrs.toInt() == 1 ? 'hr' : 'hrs'}'
        : '${hrs.toStringAsFixed(1)} hrs';
  }

  Future<void> _handleConfirmSelection() async {
    final idx = _selectedIndex;
    if (idx == null || _isConfirming || _confirmedIndex != null) return;

    setState(() => _isConfirming = true);

    final result = await ArtistDashboardRepository.confirmProposedTimeSlot(
      proposalMessage: widget.message,
      optionIndex: idx,
      thread: widget.thread,
      artistId: _effectiveArtistId,
      firestore: widget.firestore,
    );

    if (!mounted) return;

    if (!result.confirmed) {
      final takenOption = widget.message.proposedSlots[idx];
      setState(() {
        _isConfirming = false;
        _unavailableKeys.add(takenOption.uniqueKey);
        if (result.schedule != null) {
          _remoteSchedule = result.schedule;
        }
        _selectedIndex = null;
      });
      FlashSnackBar.showError(
        context,
        result.errorMessage ??
            'That time slot is no longer available. Please pick another option.',
      );
      return;
    }

    setState(() {
      _isConfirming = false;
      _confirmedIndex = idx;
      if (result.schedule != null) {
        _remoteSchedule = result.schedule;
      }
    });

    if (result.updatedProposal != null && result.receiptMessage != null) {
      widget.onProposalConfirmed?.call((
        updatedProposal: result.updatedProposal!,
        receiptMessage: result.receiptMessage!,
      ));
    }

    final chosen = widget.message.proposedSlots[idx];
    FlashSnackBar.showSuccess(
      context,
      'Confirmed for ${_formatOptionDate(chosen.date)} at ${chosen.timeSlot}!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.message.proposedSlots;
    final isConfirmed = _confirmedIndex != null;
    final durationLabel =
        _formatDuration(widget.message.appointmentDurationMinutes);
    final anyOptionAvailable = options.any(_isOptionAvailable);

    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        width: MediaQuery.of(context).size.width * 0.88,
        decoration: BoxDecoration(
          color: AppTheme.onyxContainer,
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(
            color: isConfirmed ? _confirmedGreen : AppTheme.goldBorder,
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Row(
                children: [
                  Icon(
                    isConfirmed
                        ? Icons.check_circle_rounded
                        : Icons.event_available_rounded,
                    color: isConfirmed ? _confirmedGreen : AppTheme.gold,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isConfirmed
                          ? 'SESSION TIME CONFIRMED'
                          : 'PROPOSED SESSION TIMES',
                      style: GoogleFonts.plusJakartaSans(
                        color: isConfirmed ? _confirmedGreen : AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  if (durationLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2222),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Text(
                        durationLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quote recap
                  if (widget.message.estimatedTotalPrice != null ||
                      widget.message.receiptAmount != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.message.estimatedTotalPrice != null)
                          Text(
                            'Est. Total: \$${widget.message.estimatedTotalPrice}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (widget.message.receiptAmount != null)
                          Text(
                            'Deposit: \$${widget.message.receiptAmount!.round()}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    isConfirmed
                        ? 'Your selected appointment time is locked in.'
                        : (widget.isArtistView
                            ? 'Sent to client. Live availability is checked when they pick a time.'
                            : 'Choose one of the open times below. We will verify it is still open before confirming.'),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Proposed options list
                  ...options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final opt = entry.value;
                    final isChosenConfirmed = _confirmedIndex == idx;
                    final isAvailable =
                        isConfirmed ? isChosenConfirmed : _isOptionAvailable(opt);
                    final isSelected =
                        !isConfirmed && isAvailable && _selectedIndex == idx;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: idx == options.length - 1 ? 0 : 8,
                      ),
                      child: InkWell(
                        key: Key('proposal_option_$idx'),
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                        onTap: (widget.isArtistView ||
                                isConfirmed ||
                                !isAvailable ||
                                _isConfirming)
                            ? null
                            : () => setState(() => _selectedIndex = idx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: isChosenConfirmed
                                ? const Color(0x1F4ADE80)
                                : (isSelected
                                    ? const Color(0x24EEC200)
                                    : const Color(0xFF171A1A)),
                            borderRadius:
                                BorderRadius.circular(AppRadius.radiusMd),
                            border: Border.all(
                              color: isChosenConfirmed
                                  ? _confirmedGreen
                                  : (isSelected
                                      ? AppTheme.gold
                                      : const Color(0xFF2C2F30)),
                              width: isSelected || isChosenConfirmed ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isChosenConfirmed
                                    ? Icons.check_circle_rounded
                                    : (!isAvailable && !isConfirmed
                                        ? Icons.block_rounded
                                        : (isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded)),
                                size: 18,
                                color: isChosenConfirmed
                                    ? _confirmedGreen
                                    : (!isAvailable && !isConfirmed
                                        ? const Color(0xFF6B7272)
                                        : (isSelected
                                            ? AppTheme.gold
                                            : AppTheme.navInactive)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${_formatOptionDate(opt.date)} • ${opt.timeSlot}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isChosenConfirmed
                                        ? _confirmedGreen
                                        : (!isAvailable && !isConfirmed
                                            ? const Color(0xFF6B7272)
                                            : AppTheme.textPrimary),
                                    fontSize: 13,
                                    fontWeight: isSelected || isChosenConfirmed
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    decoration: !isAvailable && !isConfirmed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (isChosenConfirmed)
                                Text(
                                  'Confirmed',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _confirmedGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else if (!isAvailable && !isConfirmed)
                                Text(
                                  'Taken',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFF87171),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  if (!widget.isArtistView && !isConfirmed) ...[
                    const SizedBox(height: 14),
                    AppButtons.primaryCTA(
                      key: const Key('confirm_proposed_slot_button'),
                      onPressed: (!anyOptionAvailable ||
                              _selectedIndex == null ||
                              _isConfirming)
                          ? null
                          : _handleConfirmSelection,
                      isLoading: _isConfirming,
                      text: !anyOptionAvailable
                          ? 'All Proposed Times Taken'
                          : (_selectedIndex == null
                              ? 'Select a Time to Confirm'
                              : 'Confirm Selected Time'),
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.onyxBackground,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
