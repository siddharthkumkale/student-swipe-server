import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/campuses.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import '../services/profile_service.dart';
import '../utils/app_theme.dart';
import '../widgets/profile_avatar_image.dart';

class ProfileSetupScreen extends StatefulWidget {
  /// When set (e.g. from Edit profile), form is pre-filled including photo.
  final UserProfile? initialProfile;

  const ProfileSetupScreen({super.key, this.initialProfile});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  final _courseController = TextEditingController();
  final _yearController = TextEditingController();
  final _bioController = TextEditingController();

  final List<String> _allSkills = [
    // Engineering & development
    'Flutter',
    'Dart',
    'Android (Kotlin / Java)',
    'iOS (Swift)',
    'React',
    'React Native',
    'Web Development',
    'Backend Development',
    'Full‑stack Development',
    'APIs & Integrations',
    'DevOps / Cloud',
    // Data & AI
    'Python',
    'Data Analysis',
    'Data Science',
    'Machine Learning',
    'AI / LLMs',
    'SQL & Databases',
    // Design & product
    'UI/UX Design',
    'Product Design',
    'Graphic Design',
    'Branding',
    'Prototyping (Figma, XD)',
    // Business & content
    'Marketing',
    'Growth & Analytics',
    'Copywriting',
    'Content Creation',
    'Community Building',
    // Project skills
    'Project Management',
    'Leadership',
    'Public Speaking',
    'Workshop Facilitation',
  ];

  final List<String> _selectedSkills = [];

  bool _loading = false;
  String? _photoUrl;
  final List<String> _extraPhotos = [];
  String? _lookingFor;
  bool _uploadingPhoto = false;
  Campus? _selectedCampus;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    if (p != null) {
      _nameController.text = p.name;
      _universityController.text = p.university;
      _selectedCampus = campusMatchingStoredUniversity(p.university);
      _courseController.text = p.course;
      _yearController.text = p.year;
      _bioController.text = p.bio;
      _selectedSkills.addAll(p.skills.where((s) => _allSkills.contains(s)));
      _photoUrl = p.photoUrl;
      _extraPhotos.addAll(p.additionalPhotos);
      _lookingFor = p.lookingFor;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _courseController.dispose();
    _yearController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one skill')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = AuthService.instance.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final profile = UserProfile(
        uid: user.uid,
        name: _nameController.text.trim(),
        email: user.email ?? '',
        university: _selectedCampus?.name ?? _universityController.text.trim(),
        course: _courseController.text.trim(),
        year: _yearController.text.trim(),
        bio: _bioController.text.trim(),
        skills: List.from(_selectedSkills),
        photoUrl: _photoUrl,
        additionalPhotos: List.from(_extraPhotos),
        lookingFor: _lookingFor,
      );

      await ProfileService.instance.saveProfile(profile).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out. Check your connection.'),
      );

      if (!mounted) return;
      setState(() => _loading = false);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $message'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _pickForMain() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await PhotoService.instance.pickAndUploadProfilePhoto(uid);
      if (!mounted || url == null) return;
      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickForExtra() async {
    if (_photoUrl == null || _photoUrl!.isEmpty) {
      await _pickForMain();
      return;
    }
    if (_extraPhotos.length >= 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Up to 5 photos total (1 main + 4 extra)')),
      );
      return;
    }
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await PhotoService.instance.pickAndUploadProfilePhoto(uid);
      if (!mounted || url == null) return;
      setState(() => _extraPhotos.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _removeExtraAt(int index) {
    if (index < 0 || index >= _extraPhotos.length) return;
    setState(() => _extraPhotos.removeAt(index));
  }

  static const _fieldFill = Color(0xFFF9FAFB);
  static const _fieldBorder = Color(0xFFE5E7EB);
  static const _ink = Color(0xFF111827);

  InputDecoration _lightInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 22, color: const Color(0xFF9CA3AF)),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.75),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade600, width: 1.75),
      ),
      labelStyle: GoogleFonts.outfit(
        color: const Color(0xFF6B7280),
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      floatingLabelStyle: GoogleFonts.outfit(
        color: AppTheme.accent,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      errorStyle: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.red.shade700,
      ),
    );
  }

  TextStyle get _fieldTextStyle => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: _ink,
      );

  Widget _sectionLabel(String text) {
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

  Widget _whiteCard({required List<Widget> children}) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildPhotosCard() {
    final hasMain = _photoUrl != null && _photoUrl!.isNotEmpty;
    final count = (hasMain ? 1 : 0) + _extraPhotos.length;

    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _sectionLabel('PHOTOS'),
                const Spacer(),
                Text(
                  '$count/5',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 260,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasMain)
                      ProfileAvatarImage(
                        photoUrl: _photoUrl,
                        fit: BoxFit.cover,
                        placeholder: () => _photoPlaceholder(),
                        errorWidget: () => _photoPlaceholder(),
                      )
                    else
                      _photoPlaceholder(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.4, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                    if (_uploadingPhoto)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _glassCircleButton(
                        icon: Icons.camera_alt_rounded,
                        onTap: _uploadingPhoto ? null : _pickForMain,
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
                                hasMain ? 'Main photo · camera to replace' : 'Add your main photo first',
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
                              onTap: _uploadingPhoto ? null : _pickForExtra,
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
            const SizedBox(height: 14),
            _sectionLabel('MORE PHOTOS'),
            const SizedBox(height: 6),
            Text(
              'Tap × on a tile to remove it',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
              children: [
                for (var i = 0; i < _extraPhotos.length; i++)
                  _setupExtraThumb(
                    url: _extraPhotos[i],
                    label: '${i + 1}',
                    onRemove: () => _removeExtraAt(i),
                  ),
                if (_extraPhotos.length < 4)
                  _setupAddTile(
                    onTap: _uploadingPhoto ? null : _pickForExtra,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: Icon(Icons.person_rounded, size: 56, color: const Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _glassCircleButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: onTap != null ? 0.28 : 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: onTap != null ? 0.45 : 0.2)),
          ),
          child: Icon(icon, size: 20, color: Colors.white.withValues(alpha: onTap != null ? 1 : 0.4)),
        ),
      ),
    );
  }

  Widget _setupExtraThumb({
    required String url,
    required String label,
    required VoidCallback onRemove,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProfileAvatarImage(
            photoUrl: url,
            fit: BoxFit.cover,
            placeholder: _photoPlaceholder,
            errorWidget: _photoPlaceholder,
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupAddTile({VoidCallback? onTap}) {
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
              Icon(Icons.add_rounded, color: AppTheme.accent, size: 28),
              const SizedBox(height: 2),
              Text(
                'Add',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCampusPicker() async {
    final result = await showModalBottomSheet<Campus>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = nzCampuses
                .where((c) =>
                    c.name.toLowerCase().contains(query.toLowerCase()) ||
                    c.city.toLowerCase().contains(query.toLowerCase()))
                .toList();
            final viewInsets = MediaQuery.of(context).viewInsets;
            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select university',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by name or city',
                        hintStyle: GoogleFonts.outfit(color: const Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.accent, width: 1.75),
                        ),
                      ),
                      style: GoogleFonts.outfit(color: const Color(0xFF111827)),
                      onChanged: (value) =>
                          setModalState(() => query = value.trim()),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFECECEC)),
                        itemBuilder: (context, index) {
                          final campus = filtered[index];
                          final selected = _selectedCampus?.id == campus.id;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            title: Text(
                              campus.name,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF111827),
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              campus.city,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: selected
                                ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                                : null,
                            onTap: () => Navigator.of(context).pop(campus),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _selectedCampus = result;
      _universityController.text = result.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialProfile != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).maybePop(),
                              borderRadius: BorderRadius.circular(14),
                              child: Ink(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Colors.white.withValues(alpha: 0.12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Edit profile' : 'Complete your profile',
                                  style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    height: 1.05,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isEditing
                                      ? 'Update how you show up on Discover'
                                      : 'Step 2 of 2 · Tell people who you are',
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
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        _buildPhotosCard(),
                        const SizedBox(height: 14),
                        _whiteCard(
                          children: [
                            _sectionLabel('PROFILE'),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              decoration: _lightInputDecoration('Full name', Icons.person_outline_rounded),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Enter your name' : null,
                              style: _fieldTextStyle,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _universityController,
                              readOnly: true,
                              decoration: _lightInputDecoration('University', Icons.school_outlined).copyWith(
                                suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9CA3AF)),
                              ),
                              onTap: _openCampusPicker,
                              validator: (_) {
                                if (_selectedCampus != null) return null;
                                if (_universityController.text.trim().isNotEmpty) {
                                  return null;
                                }
                                return 'Select your university';
                              },
                              style: _fieldTextStyle,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _courseController,
                              decoration: _lightInputDecoration('Course', Icons.menu_book_outlined),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Enter your course' : null,
                              style: _fieldTextStyle,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _yearController,
                              decoration: _lightInputDecoration('Year (e.g. 2nd year)', Icons.calendar_today_outlined),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Enter your year' : null,
                              style: _fieldTextStyle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _whiteCard(
                          children: [
                            _sectionLabel('ABOUT ME'),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _bioController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: _lightInputDecoration('Short bio', Icons.edit_note_rounded),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Write a short bio' : null,
                              style: _fieldTextStyle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _whiteCard(
                          children: [
                            _sectionLabel('PASSIONS'),
                            const SizedBox(height: 6),
                            Text(
                              'Choose up to 3',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey('skills_dropdown_${_selectedSkills.length}'),
                              value: null,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              decoration: _lightInputDecoration('Add from list', Icons.bolt_rounded),
                              iconEnabledColor: const Color(0xFF6B7280),
                              style: _fieldTextStyle,
                              items: _allSkills
                                  .where((s) => !_selectedSkills.contains(s))
                                  .map(
                                    (skill) => DropdownMenuItem(
                                      value: skill,
                                      child: Text(skill, style: GoogleFonts.outfit(fontSize: 15, color: _ink)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                if (_selectedSkills.length >= 3) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'You can select up to 3 skills',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  if (!_selectedSkills.contains(value)) {
                                    _selectedSkills.add(value);
                                  }
                                });
                              },
                            ),
                            if (_selectedSkills.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedSkills.map((skill) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      padding: const EdgeInsets.only(left: 14, right: 6, top: 8, bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              skill,
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => setState(() => _selectedSkills.remove(skill)),
                                            borderRadius: BorderRadius.circular(999),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        _whiteCard(
                          children: [
                            _sectionLabel('LOOKING FOR'),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _lookingFor,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              decoration: _lightInputDecoration('What are you mainly looking for?', Icons.favorite_border_rounded),
                              iconEnabledColor: const Color(0xFF6B7280),
                              style: _fieldTextStyle,
                              items: const [
                                'Project teammates',
                                'Hackathon team',
                                'Study partner',
                                'Startup co‑founder',
                                'Mentor',
                                'Mentee',
                                'Club / society collab',
                                'Casual networking',
                                'Any opportunities',
                              ]
                                  .map(
                                    (label) => DropdownMenuItem(
                                      value: label,
                                      child: Text(label, style: GoogleFonts.outfit(fontSize: 15, color: _ink)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _lookingFor = value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 54,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _saveProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _ink,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _loading
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _ink,
                                    ),
                                  )
                                : Text(
                                    isEditing ? 'Save changes' : 'Save & continue',
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
