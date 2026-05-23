import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/user_model.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ProfileScreen
/// Displays account info, navigation shortcuts, and logout.
/// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      authNotifierProvider
          .select((s) => s is AuthAuthenticated ? s.user : null),
    );

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, ref),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── Avatar + identity ─────────────────────────────────────
            _ProfileHeader(user: user)
                .animate()
                .fadeIn(duration: 360.ms)
                .slideY(begin: 0.08),

            const SizedBox(height: 28),

            // ── Account info ──────────────────────────────────────────
            const _SectionHeader(label: 'Account')
                .animate()
                .fadeIn(delay: 100.ms),
            const SizedBox(height: 10),
            _AccountInfoCard(user: user).animate().fadeIn(delay: 120.ms),

            const SizedBox(height: 24),

            // ── Navigation ────────────────────────────────────────────
            const _SectionHeader(label: 'Navigation')
                .animate()
                .fadeIn(delay: 160.ms),
            const SizedBox(height: 10),
            _NavCard(
              items: [
                _NavItem(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Browse Menu',
                  onTap: () => context.goNamed(RouteNames.menu),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'My Orders',
                  onTap: () => context.goNamed(RouteNames.orders),
                ),
                _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Waiter',
                  onTap: () => context.goNamed(RouteNames.aiChat),
                ),
              ],
            ).animate().fadeIn(delay: 180.ms),

            const SizedBox(height: 24),

            // ── Help & Support ────────────────────────────────────────
            const _SectionHeader(label: 'Help & Support')
                .animate()
                .fadeIn(delay: 210.ms),
            const SizedBox(height: 10),
            _NavCard(
              items: [
                _NavItem(
                  icon: Icons.support_agent_rounded,
                  label: 'Contact Support',
                  // Push so back button returns to profile
                  onTap: () => context.pushNamed(RouteNames.support),
                  iconColor: AppColors.primary,
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Report an Issue',
                  onTap: () => context.pushNamed(RouteNames.support),
                  iconColor: AppColors.warning,
                ),
              ],
            ).animate().fadeIn(delay: 230.ms),

            const SizedBox(height: 24),

            // ── App info ──────────────────────────────────────────────
            const _SectionHeader(label: 'About')
                .animate()
                .fadeIn(delay: 260.ms),
            const SizedBox(height: 10),
            _NavCard(
              items: [
                _NavItem(
                  icon: Icons.info_outline_rounded,
                  label: 'App Version',
                  trailing: Text(
                    'v1.0.0',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.textDisabled),
                  ),
                  onTap: () {},
                ),
                _NavItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () {},
                ),
              ],
            ).animate().fadeIn(delay: 280.ms),

            const SizedBox(height: 32),

            // ── Logout ────────────────────────────────────────────────
            _LogoutButton(ref: ref, context: context)
                .animate()
                .fadeIn(delay: 320.ms),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) =>
      AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Text(
          'Profile',
          style: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      );
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final UserModel user;

  String get _initials => user.name
      .split(' ')
      .take(2)
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase())
      .join();

  Color get _roleColor => switch (user.role) {
        'admin' => AppColors.error,
        'staff' => AppColors.warning,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: GoogleFonts.syne(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Role badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _roleColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _roleColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textDisabled,
            letterSpacing: 2,
          ),
        ),
      );
}

// ── Account info card ─────────────────────────────────────────────────────────

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'User ID',
              value: user.id.substring(0, 8).toUpperCase(),
              isFirst: true,
              monospace: true,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: user.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User ID copied',
                        style: GoogleFonts.dmSans(fontSize: 13)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: AppColors.border, indent: 16),
            _InfoRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: user.email,
            ),
            if (user.phone.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.border, indent: 16),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: user.phone,
                isLast: true,
              ),
            ] else
              const SizedBox.shrink(),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
    this.monospace = false,
    this.onCopy,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;
  final bool monospace;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.textDisabled,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onCopy != null)
              GestureDetector(
                onTap: onCopy,
                child: const Icon(Icons.copy_rounded,
                    size: 15, color: AppColors.textDisabled),
              ),
          ],
        ),
      );
}

// ── Nav card ──────────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  const _NavCard({required this.items});
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: items.asMap().entries.map((e) {
            final item = e.value;
            final isLast = e.key == items.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: e.key == 0 ? const Radius.circular(16) : Radius.zero,
                    bottom: isLast ? const Radius.circular(16) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(item.icon,
                            size: 18,
                            color: item.iconColor ?? AppColors.textMuted),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (item.trailing != null) ...[
                          item.trailing!,
                          const SizedBox(width: 4),
                        ],
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.textDisabled),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, color: AppColors.border, indent: 16),
              ],
            );
          }).toList(),
        ),
      );
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
}

// ── Logout button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.ref, required this.context});
  final WidgetRef ref;
  final BuildContext context;

  void _confirmLogout() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 36),
            const SizedBox(height: 14),
            Text(
              'Sign Out',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will be returned to the login screen.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.mediumImpact();
                  ref.read(authNotifierProvider.notifier).logout();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Sign Out',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: _confirmLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.error.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
