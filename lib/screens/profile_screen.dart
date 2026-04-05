import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import '../services/profile_service.dart';
import '../utils/app_theme.dart';
import '../widgets/profile_avatar_image.dart';
import 'profile_setup_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Show this URL immediately after upload so the photo appears before the stream updates.
  String? _pendingPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: StreamBuilder(
            stream: ProfileService.instance.profileStream(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Couldn\'t load profile',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final doc = snapshot.data;
              if (doc == null || !doc.exists) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No profile found',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF111827),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _goToSetup(context),
                          child: Text('Set up profile', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final profile = UserProfile.fromFirestore(doc);
              if (_pendingPhotoUrl != null && profile.photoUrl == _pendingPhotoUrl) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _pendingPhotoUrl = null);
                });
              }
              final displayPhotoUrl = _pendingPhotoUrl ?? profile.photoUrl;
              final extraPhotos = profile.additionalPhotos.where((p) => p.isNotEmpty).take(4).toList();
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ProfileTopBar(
                        onSettings: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SettingsScreen(currentProfile: profile),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ProfilePhotoSection(
                        mainPhotoUrl: displayPhotoUrl,
                        extraPhotoUrls: extraPhotos,
                        onChangeMainTap: () => _pickAndUploadPhoto(profile),
                        onAddExtraTap: () => _pickAndUploadGalleryPhoto(profile),
                        onMainMenuTap: () => _showPhotoOptions(
                          context,
                          profile,
                          _orderedPhotoUrls(profile, displayPhotoUrl),
                          0,
                        ),
                        onExtraTap: (extraIndex) => _showPhotoOptions(
                          context,
                          profile,
                          _orderedPhotoUrls(profile, displayPhotoUrl),
                          extraIndex + 1,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileDetailsPanel(
                            profile: profile,
                            displayPhotoUrl: displayPhotoUrl,
                          ),
                          const SizedBox(height: 16),
                          _ProfileActionBar(
                            onEdit: () => _goToSetup(context, profile),
                            onSignOut: () => _signOut(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(UserProfile profile) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final url = await PhotoService.instance.pickAndUploadProfilePhoto(uid);
      if (url == null || !context.mounted) return;
      setState(() => _pendingPhotoUrl = url);
      final updated = UserProfile(
        uid: profile.uid,
        name: profile.name,
        email: profile.email,
        university: profile.university,
        course: profile.course,
        year: profile.year,
        bio: profile.bio,
        skills: profile.skills,
        photoUrl: url,
        additionalPhotos: profile.additionalPhotos,
        lookingFor: profile.lookingFor,
        createdAt: profile.createdAt,
        isAiBot: profile.isAiBot,
        aiPersona: profile.aiPersona,
      );
      await ProfileService.instance.saveProfile(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Main photo updated'), backgroundColor: AppTheme.accent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadGalleryPhoto(UserProfile profile) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    if (profile.additionalPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to 5 photos total')),
      );
      return;
    }
    try {
      final url = await PhotoService.instance.pickAndUploadProfilePhoto(uid);
      if (url == null || !context.mounted) return;
      final updated = UserProfile(
        uid: profile.uid,
        name: profile.name,
        email: profile.email,
        university: profile.university,
        course: profile.course,
        year: profile.year,
        bio: profile.bio,
        skills: profile.skills,
        photoUrl: profile.photoUrl,
        additionalPhotos: [...profile.additionalPhotos, url],
        lookingFor: profile.lookingFor,
        createdAt: profile.createdAt,
        isAiBot: profile.isAiBot,
        aiPersona: profile.aiPersona,
      );
      await ProfileService.instance.saveProfile(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extra photo added — tap it to change or remove'), backgroundColor: AppTheme.accent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  List<String> _orderedPhotoUrls(UserProfile profile, String? displayPhotoUrl) {
    final primaryPhoto = displayPhotoUrl ?? profile.photoUrl;
    return <String>[
      if (primaryPhoto != null && primaryPhoto.isNotEmpty) primaryPhoto,
      ...profile.additionalPhotos.where((p) => p.isNotEmpty),
    ].take(5).toList();
  }

  void _showPhotoOptions(BuildContext context, UserProfile profile, List<String> allPhotos, int index) {
    if (allPhotos.isEmpty || index < 0 || index >= allPhotos.length) return;
    final isMain = index == 0;
    final extraNumber = index; // 1-based label for first extra
    final title = isMain ? 'Main profile photo' : 'Extra photo $extraNumber';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                isMain
                    ? 'Changing or deleting applies to your main picture shown on Discover.'
                    : 'Changing or deleting applies only to this gallery slot.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            ListTile(
              leading: const Icon(Icons.photo_camera_back_outlined, color: Colors.white),
              title: Text(
                isMain ? 'Change main photo' : 'Change extra photo $extraNumber',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _replacePhotoAt(profile, index);
              },
            ),
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.star_outline_rounded, color: Colors.white),
                title: Text(
                  'Set extra photo $extraNumber as main',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _setAsMainPhoto(profile, index, allPhotos);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300),
              title: Text(
                isMain ? 'Delete main photo' : 'Delete extra photo $extraNumber',
                style: TextStyle(color: Colors.red.shade300),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeletePhoto(context, profile, index, title);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePhoto(
    BuildContext context,
    UserProfile profile,
    int index,
    String photoLabel,
  ) async {
    final isMain = index == 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMain ? 'Delete main photo?' : 'Delete $photoLabel?'),
        content: Text(
          isMain
              ? 'Your main profile picture will be removed. If you have extra photos, the next one becomes your main photo.'
              : '$photoLabel will be removed from your gallery. This does not affect your main photo unless you promote another photo first.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _deletePhotoAt(profile, index);
  }

  Future<void> _replacePhotoAt(UserProfile profile, int index) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final url = await PhotoService.instance.pickAndUploadProfilePhoto(uid);
      if (url == null || !context.mounted) return;
      if (index == 0) {
        setState(() => _pendingPhotoUrl = url);
        final updated = UserProfile(
          uid: profile.uid,
          name: profile.name,
          email: profile.email,
          university: profile.university,
          course: profile.course,
          year: profile.year,
          bio: profile.bio,
          skills: profile.skills,
          photoUrl: url,
          additionalPhotos: profile.additionalPhotos,
          lookingFor: profile.lookingFor,
          createdAt: profile.createdAt,
          isAiBot: profile.isAiBot,
          aiPersona: profile.aiPersona,
        );
        await ProfileService.instance.saveProfile(updated);
      } else {
        final extras = List<String>.from(profile.additionalPhotos);
        final i = index - 1;
        if (i >= 0 && i < extras.length) extras[i] = url;
        final updated = UserProfile(
          uid: profile.uid,
          name: profile.name,
          email: profile.email,
          university: profile.university,
          course: profile.course,
          year: profile.year,
          bio: profile.bio,
          skills: profile.skills,
          photoUrl: profile.photoUrl,
          additionalPhotos: extras,
          lookingFor: profile.lookingFor,
          createdAt: profile.createdAt,
          isAiBot: profile.isAiBot,
          aiPersona: profile.aiPersona,
        );
        await ProfileService.instance.saveProfile(updated);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(index == 0 ? 'Main photo updated' : 'Extra photo $index updated'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _deletePhotoAt(UserProfile profile, int index) async {
    try {
      String? newPrimary;
      List<String> newExtras;
      if (index == 0) {
        final extras = List<String>.from(profile.additionalPhotos);
        if (extras.isEmpty) {
          newPrimary = null;
          newExtras = [];
        } else {
          newPrimary = extras.first;
          newExtras = extras.sublist(1);
        }
      } else {
        newPrimary = profile.photoUrl;
        newExtras = List<String>.from(profile.additionalPhotos);
        final i = index - 1;
        if (i >= 0 && i < newExtras.length) newExtras.removeAt(i);
      }
      setState(() {
        if (index == 0) _pendingPhotoUrl = null;
      });
      final updated = UserProfile(
        uid: profile.uid,
        name: profile.name,
        email: profile.email,
        university: profile.university,
        course: profile.course,
        year: profile.year,
        bio: profile.bio,
        skills: profile.skills,
        photoUrl: newPrimary,
        additionalPhotos: newExtras,
        lookingFor: profile.lookingFor,
        createdAt: profile.createdAt,
        isAiBot: profile.isAiBot,
        aiPersona: profile.aiPersona,
      );
      final clearMain = newPrimary == null || newPrimary.isEmpty;
      await ProfileService.instance.saveProfile(updated, deleteMainPhotoIfEmpty: clearMain);
      if (context.mounted) {
        final msg = index == 0 && (newPrimary != null && newPrimary.isNotEmpty)
            ? 'Main photo removed — next photo is now your main picture'
            : index == 0
                ? 'Main photo removed'
                : 'Extra photo $index removed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.accent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _setAsMainPhoto(UserProfile profile, int index, List<String> allPhotos) async {
    if (index <= 0 || index >= allPhotos.length) return;
    final selected = allPhotos[index];
    final old = profile.photoUrl;
    final extras = List<String>.from(profile.additionalPhotos);
    extras.removeWhere((p) => p == selected);
    if (old != null && old.isNotEmpty && old != selected) {
      extras.insert(0, old);
    }
    while (extras.length > 4) {
      extras.removeLast();
    }
    setState(() => _pendingPhotoUrl = selected);
    try {
      final updated = UserProfile(
        uid: profile.uid,
        name: profile.name,
        email: profile.email,
        university: profile.university,
        course: profile.course,
        year: profile.year,
        bio: profile.bio,
        skills: profile.skills,
        photoUrl: selected,
        additionalPhotos: extras,
        lookingFor: profile.lookingFor,
        createdAt: profile.createdAt,
        isAiBot: profile.isAiBot,
        aiPersona: profile.aiPersona,
      );
      await ProfileService.instance.saveProfile(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extra photo $index is now your main photo'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _goToSetup(BuildContext context, [UserProfile? currentProfile]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileSetupScreen(initialProfile: currentProfile),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    // AuthGate listens to auth state and will show LoginScreen
  }
}

// —— Tinder-style profile chrome ——————————————————————————————————

class _ProfileTopBar extends StatelessWidget {
  final VoidCallback onSettings;

  const _ProfileTopBar({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.05,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How you appear on Discover',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSettings,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Icon(Icons.settings_rounded, color: Colors.white.withValues(alpha: 0.95), size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileActionBar extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onSignOut;

  const _ProfileActionBar({required this.onEdit, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 20),
            label: Text('Edit profile', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF111827),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: onSignOut,
          icon: Icon(Icons.logout_rounded, size: 20, color: Colors.white.withValues(alpha: 0.65)),
          label: Text(
            'Sign out',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePhotoSection extends StatelessWidget {
  final String? mainPhotoUrl;
  final List<String> extraPhotoUrls;
  final VoidCallback onChangeMainTap;
  final VoidCallback onAddExtraTap;
  final VoidCallback onMainMenuTap;
  final ValueChanged<int> onExtraTap;

  const _ProfilePhotoSection({
    required this.mainPhotoUrl,
    required this.extraPhotoUrls,
    required this.onChangeMainTap,
    required this.onAddExtraTap,
    required this.onMainMenuTap,
    required this.onExtraTap,
  });

  bool get _hasMain => mainPhotoUrl != null && mainPhotoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final showMoreRow = extraPhotoUrls.isNotEmpty || extraPhotoUrls.length < 4;
    const cardRadius = 20.0;
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Text(
                  'PHOTOS',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const Spacer(),
                Text(
                  '${(_hasMain ? 1 : 0) + extraPhotoUrls.length}/5',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_hasMain)
                      ProfileAvatarImage(
                        photoUrl: mainPhotoUrl!,
                        fit: BoxFit.cover,
                        placeholder: _profileHeroPlaceholder,
                        errorWidget: _profileHeroPlaceholder,
                      )
                    else
                      _profileHeroPlaceholder(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.35, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _PhotoGlassIconButton(
                        icon: Icons.more_horiz_rounded,
                        enabled: _hasMain,
                        onTap: _hasMain ? onMainMenuTap : null,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _PhotoGlassIconButton(
                        icon: Icons.camera_alt_rounded,
                        enabled: true,
                        onTap: onChangeMainTap,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                _hasMain ? 'Main photo · tap ⋯ for options' : 'Tap camera to set your main photo',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: onAddExtraTap,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_a_photo_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Add',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showMoreRow) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'MORE PHOTOS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Text(
                'Tap a thumbnail to change or remove it',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
                children: [
                  for (var i = 0; i < extraPhotoUrls.length; i++)
                    _ExtraPhotoThumbnail(
                      url: extraPhotoUrls[i],
                      indexLabel: '${i + 1}',
                      onTap: () => onExtraTap(i),
                    ),
                  if (extraPhotoUrls.length < 4) _AddExtraPhotoTile(onTap: onAddExtraTap),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoGlassIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PhotoGlassIconButton({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: enabled ? 0.28 : 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: enabled ? 0.45 : 0.2)),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white.withValues(alpha: enabled ? 1 : 0.35),
          ),
        ),
      ),
    );
  }
}

class _ExtraPhotoThumbnail extends StatelessWidget {
  final String url;
  final String indexLabel;
  final VoidCallback onTap;

  const _ExtraPhotoThumbnail({
    required this.url,
    required this.indexLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProfileAvatarImage(
                  photoUrl: url,
                  fit: BoxFit.cover,
                  placeholder: _profileHeroPlaceholder,
                  errorWidget: _profileHeroPlaceholder,
                ),
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      indexLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddExtraPhotoTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddExtraPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5), width: 2),
            color: const Color(0xFFFFF5F5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppTheme.accent, size: 30),
              const SizedBox(height: 2),
              Text(
                'Add',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailsPanel extends StatelessWidget {
  final UserProfile profile;
  final String? displayPhotoUrl;

  const _ProfileDetailsPanel({required this.profile, this.displayPhotoUrl});

  static const _ink = Color(0xFF212121);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFECECEC);

  @override
  Widget build(BuildContext context) {
    final primaryPhoto = displayPhotoUrl ?? profile.photoUrl;
    final hasPrimaryPhoto = primaryPhoto != null && primaryPhoto.isNotEmpty;
    final completeness = _calculateProfileCompleteness(
      hasPrimaryPhoto: hasPrimaryPhoto,
      extraPhotoCount: profile.additionalPhotos.length,
      hasUniversity: profile.university.isNotEmpty,
      hasCourse: profile.course.isNotEmpty,
      hasYear: profile.year.isNotEmpty,
      hasBio: profile.bio.isNotEmpty,
      skillCount: profile.skills.length,
      hasLookingFor: profile.lookingFor != null && profile.lookingFor!.isNotEmpty,
    );
    final missing = _missingProfileSections(
      hasPrimaryPhoto: hasPrimaryPhoto,
      extraPhotoCount: profile.additionalPhotos.length,
      hasUniversity: profile.university.isNotEmpty,
      hasCourse: profile.course.isNotEmpty,
      hasYear: profile.year.isNotEmpty,
      hasBio: profile.bio.isNotEmpty,
      skillCount: profile.skills.length,
      hasLookingFor: profile.lookingFor != null && profile.lookingFor!.isNotEmpty,
    );
    final pct = completeness.clamp(0, 100).toDouble();

    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name.isEmpty ? 'Your name' : profile.name,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.05,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.email,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ProfileStrengthRing(percent: pct),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1, color: _line),
            if (profile.lookingFor != null && profile.lookingFor!.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionLabel(text: 'LOOKING FOR'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.favorite_border_rounded, size: 20, color: AppTheme.accent.withValues(alpha: 0.9)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        profile.lookingFor!,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SectionLabel(text: 'ABOUT ME'),
              const SizedBox(height: 10),
              Text(
                profile.bio,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: const Color(0xFF374151),
                ),
              ),
            ],
            const SizedBox(height: 22),
            _SectionLabel(text: 'STUDY'),
            const SizedBox(height: 6),
            _StudyRow(
              icon: Icons.school_outlined,
              label: 'University',
              value: profile.university.isEmpty ? '—' : profile.university,
            ),
            _StudyRow(
              icon: Icons.menu_book_outlined,
              label: 'Course',
              value: profile.course.isEmpty ? '—' : profile.course,
            ),
            _StudyRow(
              icon: Icons.calendar_today_outlined,
              label: 'Year',
              value: profile.year.isEmpty ? '—' : profile.year,
              showDivider: false,
            ),
            if (profile.skills.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionLabel(text: 'PASSIONS'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.skills
                    .map(
                      (skill) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                        ),
                        child: Text(
                          skill,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Text(
                          'Finish your profile',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: missing
                          .take(4)
                          .map(
                            (item) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFFFCD34D)),
                              ),
                              child: Text(
                                item,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF78350F),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }
}

class _ProfileStrengthRing extends StatelessWidget {
  final double percent;

  const _ProfileStrengthRing({required this.percent});

  @override
  Widget build(BuildContext context) {
    final v = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 4,
              backgroundColor: const Color(0xFFE5E7EB),
              color: AppTheme.accent,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percent.round()}',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: const Color(0xFF111827),
                ),
              ),
              Text(
                '%',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9CA3AF),
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const _StudyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: const Color(0xFF9CA3AF)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: const Color(0xFF212121),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: _ProfileDetailsPanel._line),
      ],
    );
  }
}

double _calculateProfileCompleteness({
    required bool hasPrimaryPhoto,
    required int extraPhotoCount,
    required bool hasUniversity,
    required bool hasCourse,
    required bool hasYear,
    required bool hasBio,
    required int skillCount,
    required bool hasLookingFor,
  }) {
    const sections = 7;
    int filled = 0;

    if (hasPrimaryPhoto) filled++;
    if (extraPhotoCount >= 2) filled++; // at least 2 extra photos
    if (hasUniversity && hasCourse && hasYear) filled++;
    if (hasBio) filled++;
    if (skillCount >= 3) filled++; // at least 3 skills
    if (hasLookingFor) filled++;
    if (filled >= 5) filled++; // small boost when most key fields are done

    final pct = (filled / sections) * 100;
    return pct.clamp(0, 100);
  }

List<String> _missingProfileSections({
    required bool hasPrimaryPhoto,
    required int extraPhotoCount,
    required bool hasUniversity,
    required bool hasCourse,
    required bool hasYear,
    required bool hasBio,
    required int skillCount,
    required bool hasLookingFor,
  }) {
    final List<String> items = [];

    if (!hasPrimaryPhoto) {
      items.add('Add a main photo');
    }
    if (extraPhotoCount < 2) {
      items.add('Add more photos');
    }
    if (!hasUniversity) {
      items.add('Select your university');
    }
    if (!hasCourse) {
      items.add('Add your course');
    }
    if (!hasYear) {
      items.add('Add your study year');
    }
    if (!hasBio) {
      items.add('Write a short bio');
    }
    if (skillCount < 3) {
      items.add('Add more skills');
    }
    if (!hasLookingFor) {
      items.add('Set what you\'re looking for');
    }

    if (items.length > 5) {
      return items.sublist(0, 5);
    }
    return items;
  }

Widget _profileHeroPlaceholder() {
  return Container(
    color: const Color(0xFFE5E7EB),
    child: Center(
      child: Icon(Icons.person_rounded, size: 56, color: const Color(0xFF9CA3AF)),
    ),
  );
}

