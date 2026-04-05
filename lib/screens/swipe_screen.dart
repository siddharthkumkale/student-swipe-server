import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/ai_bot_bridge.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../utils/app_theme.dart';
import '../utils/tinder_style.dart';
import '../widgets/profile_avatar_image.dart';
import 'profile_setup_screen.dart';
import 'profile_screen.dart';
import 'campus_map_screen.dart';
import 'chats_list_screen.dart';
import 'chat_screen.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  final List<UserProfile> _allProfiles = [];
  UserProfile? _currentUserProfile;
  List<UserProfile> _profiles = [];
  bool _loading = true;
  String? _error;
  bool _filterSameUniversity = false;
  bool _filterSameCourse = false;
  bool _filterSharedSkills = false;
  String? _selectedCampusName;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    _loadProfiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AiBotBridge.instance.seedDemoAiProfiles();
    });
  }

  Future<void> _loadCurrentUserProfile() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final profile = await ProfileService.instance.getProfile(uid);
      if (mounted) {
        setState(() {
          _currentUserProfile = profile;
        });
        _applyFilters();
      }
    } catch (e) {
      // Non-fatal: filters depending on current user will just be ignored
      debugPrint('Failed to load current user profile: $e');
    }
  }

  void _loadProfiles() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    ProfileService.instance.getSwipeableProfiles(uid).listen((profiles) {
      if (mounted) {
        setState(() {
          _allProfiles
            ..clear()
            ..addAll(profiles);
          _loading = false;
          _error = null;
        });
        _applyFilters();
      }
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    });
  }

  void _applyFilters() {
    if (!mounted) return;
    if (_allProfiles.isEmpty) {
      setState(() => _profiles = []);
      return;
    }
    final me = _currentUserProfile;
    final filtered = _allProfiles.where((p) {
      if (me != null) {
        if (_filterSameUniversity && p.university != me.university) {
          return false;
        }
        if (_filterSameCourse && p.course != me.course) {
          return false;
        }
        if (_filterSharedSkills) {
          final mySkills = me.skills.map((s) => s.toLowerCase()).toSet();
          final otherSkills = p.skills.map((s) => s.toLowerCase());
          if (!otherSkills.any(mySkills.contains)) {
            return false;
          }
        }
      }
      if (_selectedCampusName != null &&
          _selectedCampusName!.isNotEmpty &&
          p.university != _selectedCampusName) {
        return false;
      }
      return true;
    }).toList();
    setState(() => _profiles = filtered);
  }

  Future<bool> _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    if (previousIndex >= _profiles.length) return true;

    final profile = _profiles[previousIndex];
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return true;

    final isLike = direction == CardSwiperDirection.right;

    await ProfileService.instance.recordSwipe(
      fromUid: uid,
      toUid: profile.uid,
      isLike: isLike,
    );

    if (isLike) {
      try {
        if (profile.isAiBot) {
          await AiBotBridge.instance.ensureMatchAfterLike(botUid: profile.uid);
        }
        var isMatch = await ProfileService.instance.isMatch(uid, profile.uid);
        // Render cold start / network: short poll if still unmatched.
        if (!isMatch && profile.isAiBot) {
          for (var i = 0; i < 10; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            if (!mounted) return true;
            isMatch = await ProfileService.instance.isMatch(uid, profile.uid);
            if (isMatch) break;
          }
        }
        if (isMatch && mounted) {
          await ProfileService.instance.recordMatch(uid, profile);
          if (mounted) {
            _showMatchOverlay(currentUid: uid, other: profile);
          }
        }
      } catch (e, st) {
        if (mounted) {
          debugPrint('Match check/record failed: $e\n$st');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not update match: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }

    return true;
  }

  void _showMatchOverlay({required String currentUid, required UserProfile other}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MatchSheet(
        profile: other,
        onKeepSwiping: () {
          Navigator.pop(context);
        },
        onMessage: () async {
          Navigator.pop(context);
          await ChatService.instance.getOrCreateChat(currentUid, other.uid);
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                otherUid: other.uid,
                otherName: other.name,
              ),
            ),
          );
        },
      ),
    );
  }

  void _onSwipeLeft() => _swiperController.swipeLeft();
  void _onSwipeRight() => _swiperController.swipeRight();

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileTooIncomplete = _currentUserProfile != null &&
        _profileCompleteness(_currentUserProfile!) < 50;
    final showSwipeActions = !_loading && _profiles.isNotEmpty && !profileTooIncomplete;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildBody()),
              if (showSwipeActions) _buildActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final uid = AuthService.instance.currentUser?.uid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiscoverMeAvatar(
                photoUrl: _currentUserProfile?.photoUrl,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Discover',
                      style: TinderStyle.screenTitle().copyWith(fontSize: 26),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_selectedCampusName != null &&
                        _selectedCampusName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedCampusName!,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedCampusName = null);
                                _applyFilters();
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Swipe people you\'d like to meet',
                          style: TinderStyle.screenSubtitle(
                            Colors.white.withValues(alpha: 0.62),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (uid != null)
                StreamBuilder(
                  stream: ChatService.instance.myChatsStream(uid),
                  builder: (context, chatSnap) {
                    final list = chatSnap.data ?? [];
                    final unreadCount = list.where((p) => p.isUnread(uid)).length;
                    return _DiscoverToolbarIcon(
                      icon: Icons.forum_rounded,
                      tooltip: 'Messages',
                      iconColor: const Color(0xFFBFDBFE),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ChatsListScreen(),
                          ),
                        );
                      },
                      badgeCount: unreadCount > 0 ? unreadCount : null,
                    );
                  },
                ),
              if (uid != null) const SizedBox(width: 4),
              _DiscoverToolbarIcon(
                icon: Icons.explore_rounded,
                tooltip: 'Campus map',
                iconColor: const Color(0xFF86EFAC),
                onTap: _openCampusMap,
              ),
              const SizedBox(width: 4),
              _DiscoverToolbarIcon(
                icon: Icons.filter_list_rounded,
                tooltip: 'Filters',
                iconColor: const Color(0xFFFDE68A),
                onTap: _openFilters,
              ),
              const SizedBox(width: 4),
              _DiscoverToolbarIcon(
                icon: Icons.power_settings_new_rounded,
                tooltip: 'Sign out',
                iconColor: const Color(0xFFFECACA),
                onTap: () async => AuthService.instance.signOut(),
              ),
            ],
          ),
          if (!_loading && _profiles.isNotEmpty)
            const SizedBox(height: 8),
          if (!_loading && _profiles.isNotEmpty)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.07),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.groups_2_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_profiles.length} nearby',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    if (_currentUserProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish your profile first to use filters'),
        ),
      );
      return;
    }

    bool sameUni = _filterSameUniversity;
    bool sameCourse = _filterSameCourse;
    bool sharedSkills = _filterSharedSkills;

    final result = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            final bottomPadding =
                MediaQuery.of(context).padding.bottom + viewInsets.bottom + 20;

            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: bottomPadding,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: TinderStyle.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Filters', style: TinderStyle.cardTitle()),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                sameUni = false;
                                sameCourse = false;
                                sharedSkills = false;
                              });
                            },
                            child: Text(
                              'Clear',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tune who you see in Discover',
                        style: TinderStyle.cardSubtitle(),
                      ),
                      const SizedBox(height: 20),
                      _FilterToggleTile(
                        title: 'Same university',
                        subtitle: 'Only show students from your university',
                        value: sameUni,
                        onChanged: (v) => setModalState(() => sameUni = v),
                      ),
                      const SizedBox(height: 12),
                      _FilterToggleTile(
                        title: 'Same course',
                        subtitle: 'Only show students in your course',
                        value: sameCourse,
                        onChanged: (v) => setModalState(() => sameCourse = v),
                      ),
                      const SizedBox(height: 12),
                      _FilterToggleTile(
                        title: 'Shared skills',
                        subtitle: 'Must share at least one of your skills',
                        value: sharedSkills,
                        onChanged: (v) => setModalState(() => sharedSkills = v),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop({
                              'sameUni': sameUni,
                              'sameCourse': sameCourse,
                              'sharedSkills': sharedSkills,
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Apply filters',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _filterSameUniversity = result['sameUni'] ?? false;
      _filterSameCourse = result['sameCourse'] ?? false;
      _filterSharedSkills = result['sharedSkills'] ?? false;
    });
    _applyFilters();
  }

  Future<void> _openCampusMap() async {
    final selectedName = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CampusMapScreen(currentSelection: _selectedCampusName),
      ),
    );
    if (!mounted || selectedName == null) return;
    setState(() => _selectedCampusName = selectedName);
    _applyFilters();
  }

  Widget _buildBody() {
    // Guardrail: if the current user's profile is very incomplete, nudge them to finish
    // before showing Discover cards.
    if (_currentUserProfile != null &&
        _profileCompleteness(_currentUserProfile!) < 50) {
      return _buildProfileIncompleteState(_currentUserProfile!);
    }

    if (_loading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_profiles.isEmpty) return _buildEmptyState();
    return _buildCardStack();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [TinderStyle.cardShadow()],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Finding students for you...',
                style: TinderStyle.cardSubtitle(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [TinderStyle.cardShadow()],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.wifi_off_rounded, size: 44, color: Colors.red.shade400),
              ),
              const SizedBox(height: 20),
              Text(
                'Couldn\'t load profiles',
                style: TinderStyle.cardTitle(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TinderStyle.cardSubtitle(),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadProfiles();
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  'Retry',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: TinderStyle.border),
            boxShadow: [TinderStyle.cardShadow()],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'DISCOVER',
                style: TinderStyle.sectionCaps(color: TinderStyle.subtle),
              ),
              const SizedBox(height: 20),
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.22),
                      AppTheme.accent.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 48,
                  color: AppTheme.accent.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'You\'re all caught up!',
                style: GoogleFonts.outfit(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.15,
                  color: TinderStyle.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'No more students to swipe right now.\nCheck back later for new connections.',
                textAlign: TextAlign.center,
                style: TinderStyle.bodyCard(color: TinderStyle.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIncompleteState(UserProfile me) {
    final percent = _profileCompleteness(me).toStringAsFixed(0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [TinderStyle.cardShadow()],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline_rounded, size: 48, color: TinderStyle.muted),
              const SizedBox(height: 16),
              Text(
                'Add a bit more about you',
                textAlign: TextAlign.center,
                style: TinderStyle.cardTitle(),
              ),
              const SizedBox(height: 8),
              Text(
                'Your profile is only $percent% complete.\nFinish your details so we can find better matches.',
                textAlign: TextAlign.center,
                style: TinderStyle.bodyCard(color: TinderStyle.muted),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfileSetupScreen(
                          initialProfile: me,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Finish profile',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
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

  double _profileCompleteness(UserProfile profile) {
    final hasPrimaryPhoto =
        (profile.photoUrl != null && profile.photoUrl!.isNotEmpty);
    final extraPhotoCount = profile.additionalPhotos.length;
    final hasUniversity = profile.university.isNotEmpty;
    final hasCourse = profile.course.isNotEmpty;
    final hasYear = profile.year.isNotEmpty;
    final hasBio = profile.bio.isNotEmpty;
    final skillCount = profile.skills.length;
    final hasLookingFor =
        profile.lookingFor != null && profile.lookingFor!.isNotEmpty;

    const sections = 7;
    int filled = 0;

    if (hasPrimaryPhoto) filled++;
    if (extraPhotoCount >= 2) filled++;
    if (hasUniversity && hasCourse && hasYear) filled++;
    if (hasBio) filled++;
    if (skillCount >= 3) filled++;
    if (hasLookingFor) filled++;
    if (filled >= 5) filled++; // small boost when most key fields are done

    final pct = (filled / sections) * 100;
    return pct.clamp(0, 100);
  }

  Widget _buildCardStack() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Expanded(
            child: CardSwiper(
              controller: _swiperController,
              cardsCount: _profiles.length,
              numberOfCardsDisplayed: _profiles.length.clamp(1, 2),
              backCardOffset: const Offset(0, 36),
              padding: EdgeInsets.zero,
              scale: 0.94,
              maxAngle: 10,
              isLoop: false,
              duration: const Duration(milliseconds: 280),
              allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true),
              onSwipe: _onSwipe,
              onEnd: () {},
              cardBuilder: (context, index, px, py) {
                if (index >= _profiles.length) return const SizedBox();
                return _StudentCard(profile: _profiles[index]);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe or tap the buttons below',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SwipeButton(
            icon: Icons.close_rounded,
            label: 'Pass',
            color: const Color(0xFFFB7185),
            filledCenter: const Color(0xFFF43F5E),
            onTap: _onSwipeLeft,
          ),
          const SizedBox(width: 32),
          _SwipeButton(
            icon: Icons.favorite_rounded,
            label: 'Like',
            color: const Color(0xFF6EE7B7),
            filledCenter: const Color(0xFF10B981),
            onTap: _onSwipeRight,
          ),
        ],
      ),
    );
  }
}

// --- Discover chrome (avatar + toolbar) ---

class _DiscoverMeAvatar extends StatelessWidget {
  final String? photoUrl;
  final VoidCallback onTap;

  const _DiscoverMeAvatar({required this.photoUrl, required this.onTap});

  static Widget _placeholder() => Container(
        color: const Color(0xFF1E293B),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, color: Colors.white.withValues(alpha: 0.55), size: 26),
      );

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Your profile',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: ProfileAvatarImage(
                photoUrl: photoUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: _placeholder,
                errorWidget: _placeholder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverToolbarIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color iconColor;
  final VoidCallback onTap;
  final int? badgeCount;

  const _DiscoverToolbarIcon({
    required this.icon,
    required this.tooltip,
    required this.iconColor,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.07),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                ),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount! > 99 ? '99+' : '$badgeCount',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Student card ---

class _StudentCard extends StatelessWidget {
  final UserProfile profile;

  const _StudentCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            _buildGradient(),
            if (profile.isAiBot)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_rounded, size: 14, color: Colors.white.withValues(alpha: 0.95)),
                      const SizedBox(width: 5),
                      Text(
                        'AI',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final photos = [
      if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty) profile.photoUrl!,
      ...profile.additionalPhotos,
    ];
    if (photos.isEmpty) {
      return _placeholder();
    }
    return _PhotoGalleryBackground(photos: photos);
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 100,
          color: Colors.black.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _buildGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.88),
          ],
          stops: const [0.35, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profile.name,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.6,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.school_rounded, size: 18, color: Colors.white.withValues(alpha: 0.92)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${profile.course} • ${profile.university}',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (profile.year.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                profile.year,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                profile.bio,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (profile.skills.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.skills.take(5).map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
                    ),
                    child: Text(
                      skill,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoGalleryBackground extends StatefulWidget {
  final List<String> photos;

  const _PhotoGalleryBackground({required this.photos});

  @override
  State<_PhotoGalleryBackground> createState() => _PhotoGalleryBackgroundState();
}

class _PhotoGalleryBackgroundState extends State<_PhotoGalleryBackground> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, idx) {
            final url = widget.photos[idx];
            return ProfileAvatarImage(
              photoUrl: url,
              fit: BoxFit.cover,
              placeholder: () => Container(color: const Color(0xFFE5E7EB)),
              errorWidget: () => Container(
                color: const Color(0xFFE5E7EB),
                child: Icon(Icons.broken_image_rounded, color: Colors.black.withValues(alpha: 0.25), size: 40),
              ),
            );
          },
        ),
        if (widget.photos.length > 1)
          Positioned(
            right: 12,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(widget.photos.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: active ? 18 : 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// --- Action button ---

class _SwipeButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color filledCenter;
  final VoidCallback onTap;

  const _SwipeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filledCenter,
    required this.onTap,
  });

  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: widget.color.withValues(alpha: 0.85), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.filledCenter,
                    boxShadow: [
                      BoxShadow(
                        color: widget.filledCenter.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, size: 34, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TinderStyle.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TinderStyle.cardTitle()),
                const SizedBox(height: 4),
                Text(subtitle, style: TinderStyle.cardSubtitle()),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

// --- Match bottom sheet ---

class _MatchSheet extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onKeepSwiping;
  final VoidCallback onMessage;

  const _MatchSheet({
    required this.profile,
    required this.onKeepSwiping,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: TinderStyle.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: TinderStyle.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_rounded, color: AppTheme.accent, size: 30),
              const SizedBox(width: 10),
              Text(
                'It\'s a match!',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: TinderStyle.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You and ${profile.name} have liked each other.',
            textAlign: TextAlign.center,
            style: TinderStyle.bodyCard(color: TinderStyle.muted),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: onMessage,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Send first message',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onKeepSwiping,
            child: Text(
              'Keep swiping',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: TinderStyle.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
