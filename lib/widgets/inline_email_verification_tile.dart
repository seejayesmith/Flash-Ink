import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/auth/auth_exceptions.dart';
import '../theme/app_theme.dart';
import 'flash_snack_bar.dart';
import 'inline_verification_shared.dart';
import 'reauthentication_bottom_sheet.dart';

/// Expandable inline settings tile for viewing, adding, or updating an
/// account email address via passwordless `verifyBeforeUpdateEmail`.
///
/// Mirrors [InlinePhoneVerificationTile] in styling and interaction:
/// - Displays the current email (or `'Not added'`), an optional `'VERIFIED'`
///   badge when verified, or a `'PENDING'` badge when a verification link
///   has been dispatched.
/// - Expands inline to accept an email address, send the verification link
///   (prompting [ReauthenticationBottomSheet] on `requires-recent-login`),
///   and confirm verification once the user clicks the inbox link.
class InlineEmailVerificationTile extends StatefulWidget {
  final String email;
  final String? pendingEmail;
  final bool emailVerified;
  final String title;
  final IconData icon;
  final AuthService? authService;
  final FirebaseFirestore? firestore;
  final bool isArtist;
  final ValueChanged<String> onEmailVerified;
  final ValueChanged<String>? onVerificationLinkSent;

  const InlineEmailVerificationTile({
    super.key,
    required this.email,
    this.pendingEmail,
    required this.emailVerified,
    this.title = 'Email Address',
    this.icon = Icons.email_outlined,
    this.authService,
    this.firestore,
    this.isArtist = false,
    required this.onEmailVerified,
    this.onVerificationLinkSent,
  });

  @override
  State<InlineEmailVerificationTile> createState() =>
      _InlineEmailVerificationTileState();
}

class _InlineEmailVerificationTileState
    extends State<InlineEmailVerificationTile> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final TextEditingController _emailController = TextEditingController();
  final InlineResendCooldownController _cooldown =
      InlineResendCooldownController();

  bool _isExpanded = false;
  bool _awaitingLinkConfirmation = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _localPendingEmail;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? get _effectivePendingEmail {
    final candidate = _localPendingEmail ?? widget.pendingEmail;
    if (candidate == null || candidate.trim().isEmpty) return null;
    return candidate.trim();
  }

  @override
  void initState() {
    super.initState();
    _localPendingEmail = widget.pendingEmail;
  }

  @override
  void didUpdateWidget(covariant InlineEmailVerificationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingEmail != oldWidget.pendingEmail) {
      _localPendingEmail = widget.pendingEmail;
    }
    if (widget.emailVerified &&
        _localPendingEmail != null &&
        widget.email.trim().toLowerCase() ==
            _localPendingEmail!.trim().toLowerCase()) {
      _localPendingEmail = null;
      _awaitingLinkConfirmation = false;
    }
  }

  @override
  void dispose() {
    _cooldown.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    if (!mounted) return;
    _cooldown.start(() {
      if (mounted) setState(() {});
    });
  }

  void _toggleExpanded({bool? forceOpen, bool openPendingConfirmation = false}) {
    setState(() {
      _isExpanded = forceOpen ?? !_isExpanded;
      _errorMessage = null;
      if (_isExpanded) {
        final pending = _effectivePendingEmail;
        if (openPendingConfirmation && pending != null) {
          _awaitingLinkConfirmation = true;
        } else if (pending != null && !_awaitingLinkConfirmation) {
          _emailController.text = pending;
        } else if (_emailController.text.isEmpty &&
            widget.email.trim().isNotEmpty) {
          _emailController.text = widget.email.trim();
        }
      }
    });
  }

  bool _isRequiresRecentLogin(Object error) {
    if (error is RequiresRecentLoginException) return true;
    if (error is FirebaseAuthException &&
        error.code == 'requires-recent-login') {
      return true;
    }
    final lower = error.toString().toLowerCase();
    return lower.contains('requires-recent-login') ||
        lower.contains('recent authentication') ||
        lower.contains('re-authenticate');
  }

  Future<void> _sendVerificationLink({
    String? overrideEmail,
    bool isResend = false,
  }) async {
    if (_isLoading) return;
    final email = (overrideEmail ?? _emailController.text).trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendBackupEmailVerification(
        email,
        isArtist: widget.isArtist,
        firestore: widget.firestore,
      );
      if (!mounted) return;
      _applyVerificationLinkSent(email, isResend: isResend);
    } catch (e) {
      if (!mounted) return;
      if (_isRequiresRecentLogin(e)) {
        setState(() => _isLoading = false);
        await ReauthenticationBottomSheet.show(
          context: context,
          authService: _authService,
          onReauthenticated: () async {
            await _authService.sendBackupEmailVerification(
              email,
              isArtist: widget.isArtist,
              firestore: widget.firestore,
            );
            if (!mounted) return;
            _applyVerificationLinkSent(email, isResend: isResend);
          },
        );
        return;
      }

      final message = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      FlashSnackBar.showError(context, message);
    }
  }

  void _applyVerificationLinkSent(String email, {bool isResend = false}) {
    setState(() {
      _localPendingEmail = email;
      _awaitingLinkConfirmation = true;
      _isLoading = false;
      _errorMessage = null;
    });
    _startResendCooldown();
    widget.onVerificationLinkSent?.call(email);
    FlashSnackBar.showSuccess(
      context,
      isResend
          ? 'Verification link resent to $email'
          : 'Verification link sent to $email',
    );
  }

  Future<void> _checkEmailVerified() async {
    if (_isLoading) return;
    final expectedEmail = _effectivePendingEmail ?? widget.email.trim();
    if (expectedEmail.isEmpty) {
      setState(() {
        _awaitingLinkConfirmation = false;
        _errorMessage = 'Please enter an email address first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final verified = await _authService.checkAndSyncBackupEmailVerified(
        expectedEmail: expectedEmail,
        isArtist: widget.isArtist,
        firestore: widget.firestore,
      );
      if (!mounted) return;
      if (verified) {
        _cooldown.cancel();
        final resolvedEmail =
            _authService.currentUser?.email?.trim().isNotEmpty == true
                ? _authService.currentUser!.email!.trim()
                : expectedEmail;
        setState(() {
          _isLoading = false;
          _isExpanded = false;
          _awaitingLinkConfirmation = false;
          _localPendingEmail = null;
          _errorMessage = null;
        });
        widget.onEmailVerified(resolvedEmail);
        FlashSnackBar.showSuccess(context, 'Email address verified!');
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Email not verified yet. Please open the link in your inbox and try again.';
        });
        FlashSnackBar.showError(context, _errorMessage!);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      FlashSnackBar.showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingEmail = _effectivePendingEmail;
    final hasPending = pendingEmail != null;
    final trimmedEmail = widget.email.trim();
    final hasEmail = trimmedEmail.isNotEmpty;

    final String subtitleText = hasPending
        ? 'Pending verification: $pendingEmail'
        : (hasEmail ? trimmedEmail : 'Not added');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const Key('account_email_tile'),
          onTap: () => _toggleExpanded(openPendingConfirmation: hasPending),
          leading: Icon(widget.icon, color: AppTheme.gold, size: 22),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  widget.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasPending) ...[
                const SizedBox(width: 8),
                InlineVerificationStatusBadge(
                  badgeKey: const Key('email_pending_badge'),
                  label: 'PENDING',
                  backgroundColor: AppTheme.gold.withAlpha(25),
                  borderColor: AppTheme.gold.withAlpha(90),
                  textColor: AppTheme.gold,
                ),
              ] else if (hasEmail && widget.emailVerified) ...[
                const SizedBox(width: 8),
                InlineVerificationStatusBadge(
                  badgeKey: const Key('email_verified_badge'),
                  label: 'VERIFIED',
                  backgroundColor: const Color(0xFF10B981).withAlpha(25),
                  borderColor: const Color(0xFF10B981).withAlpha(80),
                  textColor: const Color(0xFF10B981),
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitleText,
            key: const Key('account_email_subtitle'),
            style: GoogleFonts.plusJakartaSans(
              color: hasPending
                  ? AppTheme.gold
                  : (hasEmail ? AppTheme.navInactive : const Color(0xFF6B7280)),
              fontSize: 13,
            ),
          ),
          trailing: hasPending
              ? InlineVerificationActionPill(
                  buttonKey: const Key('check_email_verified_button'),
                  label: _isExpanded ? 'Close' : 'Verify',
                  highlighted: true,
                  onTap: () => _toggleExpanded(
                    forceOpen: !_isExpanded,
                    openPendingConfirmation: true,
                  ),
                )
              : (hasEmail
                  ? InlineVerificationActionPill(
                      buttonKey: const Key('change_email_button'),
                      label: _isExpanded ? 'Close' : 'Change',
                      onTap: () => _toggleExpanded(),
                    )
                  : InlineVerificationActionPill(
                      buttonKey: const Key('add_email_button'),
                      label: _isExpanded ? 'Close' : 'Add',
                      highlighted: true,
                      onTap: () => _toggleExpanded(),
                    )),
        ),
        if (_isExpanded)
          Container(
            key: const Key('inline_email_expansion_container'),
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: _awaitingLinkConfirmation
                ? _buildWaitingForVerificationContent(
                    pendingEmail ?? trimmedEmail,
                  )
                : _buildEmailInputContent(),
          ),
      ],
    );
  }

  Widget _buildEmailInputContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter an email address to receive a one-tap verification link.',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('inline_email_input_field'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: buildInlineVerificationInputDecoration(
            hintText: 'you@example.com',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF6B7280),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: AppTheme.gold,
              size: 18,
            ),
            borderRadius: 12,
            borderColor: Colors.white.withAlpha(25),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onChanged: (_) {
            if (_errorMessage != null) {
              setState(() => _errorMessage = null);
            }
          },
          onSubmitted: (_) => _sendVerificationLink(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          InlineVerificationErrorText(
            errorKey: const Key('inline_email_error_text'),
            message: _errorMessage!,
            color: const Color(0xFFCF6679),
          ),
        ],
        const SizedBox(height: 12),
        InlineVerificationSubmitButton(
          buttonKey: const Key('inline_email_send_link_button'),
          label: 'Send Verification Link',
          isLoading: _isLoading,
          onPressed: () => _sendVerificationLink(),
        ),
      ],
    );
  }

  Widget _buildWaitingForVerificationContent(String targetEmail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Click the verification link sent to $targetEmail, then tap below to confirm.',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFD8DDDD),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          InlineVerificationErrorText(
            errorKey: const Key('inline_email_error_text'),
            message: _errorMessage!,
            color: const Color(0xFFCF6679),
          ),
        ],
        const SizedBox(height: 12),
        InlineVerificationSubmitButton(
          buttonKey: const Key('inline_email_check_verified_button'),
          label: "I've Verified My Email",
          isLoading: _isLoading,
          onPressed: _checkEmailVerified,
        ),
        const SizedBox(height: 8),
        InlineVerificationFooterActions(
          editKey: const Key('inline_email_edit_button'),
          editLabel: 'Change Email',
          editColor: const Color(0xFFD8DDDD),
          editFontWeight: FontWeight.w600,
          onEdit: _isLoading
              ? null
              : () {
                  setState(() {
                    _awaitingLinkConfirmation = false;
                    _errorMessage = null;
                    _emailController.text = _effectivePendingEmail ?? '';
                  });
                },
          resendKey: const Key('inline_email_resend_button'),
          resendLabel: 'Resend Link',
          cooldownSeconds: _cooldown.secondsRemaining,
          disabledCooldownColor: AppTheme.navInactive,
          onResend: (_isLoading || _cooldown.isActive)
              ? null
              : () => _sendVerificationLink(
                    overrideEmail: _effectivePendingEmail,
                    isResend: true,
                  ),
        ),
      ],
    );
  }
}
