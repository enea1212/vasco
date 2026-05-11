import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/core/constants/app_sizes.dart';
import 'package:vasco/providers/friend_location_provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/services/auth_service.dart';
import 'package:vasco/services/location_groups_service.dart';
import 'package:vasco/presentation/screens/profile/edit_profile_screen.dart';
import 'package:vasco/presentation/screens/profile/dating_preferences_screen.dart';
import 'package:vasco/presentation/widgets/app_avatar.dart';
import 'package:vasco/presentation/widgets/section_label.dart';
import 'package:vasco/presentation/widgets/settings_tile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _privacyLoading = false;
  bool? _locationSharing;
  bool _locationLoading = false;
  String? _loadedForUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<UserProvider>().user;
    if (user != null && _loadedForUserId != user.id) {
      _loadedForUserId = user.id;
      _loadVisibility(user.id);
    }
  }

  Future<void> _loadVisibility(String uid) async {
    try {
      final vis = await LocationGroupsService.getVisibility(uid);
      if (mounted) setState(() => _locationSharing = vis != 'none');
    } catch (_) {
      if (mounted) setState(() => _locationSharing = true);
    }
  }

  Future<void> _toggleLocationSharing(String uid) async {
    if (_locationLoading) return;
    final current = _locationSharing ?? true;
    final newVisibility = current ? 'none' : 'all';
    setState(() {
      _locationSharing = !current;
      _locationLoading = true;
    });
    try {
      await LocationGroupsService.setVisibility(uid, newVisibility);
      if (mounted) {
        await context
            .read<FriendLocationProvider>()
            .updateVisibility(uid, newVisibility);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationSharing = current);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eroare: $e')));
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _togglePrivacy(String uid, bool currentValue) async {
    if (_privacyLoading) return;
    setState(() => _privacyLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isPrivate': !currentValue,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eroare: $e')));
    } finally {
      if (mounted) setState(() => _privacyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setări'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          // ── Account card ───────────────────────────────────────────────────
          if (user != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: AppSizes.shadowBlurLg,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  AppAvatar(
                    photoUrl: user.photoUrl,
                    radius: AppSizes.avatarRadiusSm,
                  ),
                  const SizedBox(width: AppSizes.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? 'Utilizator',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spacingXxl),
          ],

          // ── Section: PROFIL ────────────────────────────────────────────────
          const SectionLabel('Profil'),
          const SizedBox(height: AppSizes.spacingSm),
          SettingsTile(
            icon: Icons.edit_rounded,
            iconBackground: AppColors.primaryMid,
            iconColor: AppColors.primary,
            label: 'Editează profilul',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          SettingsTile(
            icon: Icons.favorite_outline_rounded,
            iconBackground: AppColors.roseLi,
            iconColor: AppColors.rose,
            label: 'Interesele Mele',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DatingPreferencesScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacingXxl),

          // ── Section: CONFIDENȚIALITATE ─────────────────────────────────────
          const SectionLabel('Confidențialitate'),
          const SizedBox(height: AppSizes.spacingSm),

          // Location visibility toggle
          if (user != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.tileHPadding,
                vertical: AppSizes.tileVPadding,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusTile),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadowLight,
                    blurRadius: AppSizes.shadowBlur,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.iconBoxSize,
                    height: AppSizes.iconBoxSize,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMid,
                      borderRadius: BorderRadius.circular(AppSizes.radiusIcon),
                    ),
                    child: const Icon(
                      Icons.visibility_rounded,
                      color: AppColors.primary,
                      size: AppSizes.iconSize,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vizibilitate locație',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _locationSharing == true
                              ? 'Locația ta e vizibilă prietenilor'
                              : 'Locația ta e ascunsă',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  _locationLoading || _locationSharing == null
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Switch(
                          value: _locationSharing!,
                          onChanged: _locationLoading
                              ? null
                              : (_) => _toggleLocationSharing(user.id),
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primaryLight,
                        ),
                ],
              ),
            ),

          const SizedBox(height: AppSizes.spacingSm),

          // Private account toggle
          if (user != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.tileHPadding,
                vertical: AppSizes.tileVPadding,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusTile),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadowLight,
                    blurRadius: AppSizes.shadowBlur,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.iconBoxSize,
                    height: AppSizes.iconBoxSize,
                    decoration: BoxDecoration(
                      color: AppColors.purpleLight,
                      borderRadius: BorderRadius.circular(AppSizes.radiusIcon),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: AppColors.purple,
                      size: AppSizes.iconSize,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cont privat',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          user.isPrivate
                              ? 'Doar prietenii îți pot vedea profilul'
                              : 'Oricine îți poate vedea profilul',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  _privacyLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.purple,
                          ),
                        )
                      : Switch(
                          value: user.isPrivate,
                          onChanged: _privacyLoading
                              ? null
                              : (_) => _togglePrivacy(user.id, user.isPrivate),
                          activeThumbColor: AppColors.purple,
                          activeTrackColor: AppColors.primaryLight,
                        ),
                ],
              ),
            ),

          const SizedBox(height: AppSizes.spacingXxl),

          // ── Section: ALTELE ────────────────────────────────────────────────
          const SectionLabel('Altele'),
          const SizedBox(height: AppSizes.spacingSm),
          SettingsTile(
            icon: Icons.logout_rounded,
            iconBackground: AppColors.dangerLight,
            iconColor: AppColors.danger,
            label: 'Deconectare',
            labelColor: AppColors.danger,
            showArrow: false,
            onTap: () => _confirmLogout(context, authService),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService authService) {
    final nav = Navigator.of(context, rootNavigator: true);
    var isSigningOut = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusDialog),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppSizes.iconBoxSizeLg,
                  height: AppSizes.iconBoxSizeLg,
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: AppSizes.iconSizeLg,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingLg),
                const Text(
                  'Deconectare',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingXs),
                const Text(
                  'Ești sigur că vrei să te deconectezi?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingXl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSigningOut
                            ? null
                            : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusButton,
                            ),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text(
                          'Anulează',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSigningOut
                            ? null
                            : () async {
                                setDialogState(() => isSigningOut = true);
                                try {
                                  await authService.signOut();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (nav.mounted) {
                                    nav.popUntil((route) => route.isFirst);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Eroare: $e')),
                                    );
                                    setDialogState(
                                      () => isSigningOut = false,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: AppColors.surface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusButton,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: isSigningOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: AppColors.surface,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Deconectează'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
