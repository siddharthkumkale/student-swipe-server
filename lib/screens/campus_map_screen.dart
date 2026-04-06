import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../data/campuses.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../utils/app_theme.dart';
import '../widgets/profile_avatar_image.dart';

/// Campus map: NZ institutes plus live markers showing students grouped by university.
class CampusMapScreen extends StatefulWidget {
  final String? currentSelection;

  const CampusMapScreen({super.key, this.currentSelection});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  Campus? _selectedCampus;
  LatLng? _currentLocation;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _selectedCampus = nzCampuses.firstWhere(
      (c) => c.name == widget.currentSelection,
      orElse: () => nzCampuses.first,
    );
  }

  /// Groups profiles onto known campuses using the same matching as profile setup.
  static Map<String, List<UserProfile>> _groupProfilesByCampus(List<UserProfile> profiles) {
    final map = <String, List<UserProfile>>{};
    for (final p in profiles) {
      final campus = campusMatchingStoredUniversity(p.university);
      if (campus == null) continue;
      map.putIfAbsent(campus.id, () => []).add(p);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final initial = _selectedCampus ?? nzCampuses.first;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Campus map',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Pins show students by university',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<UserProfile>>(
                  stream: ProfileService.instance.allProfilesStream(),
                  builder: (context, profileSnap) {
                    final byCampus = _groupProfilesByCampus(profileSnap.data ?? []);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: initial.location,
                                    initialZoom: 5.5,
                                    onTap: (_, __) {},
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      subdomains: const ['a', 'b', 'c'],
                                      userAgentPackageName: 'com.studentswipe.app',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        ...nzCampuses.map((c) {
                                          final usersHere = byCampus[c.id] ?? [];
                                          final hasStudents = usersHere.isNotEmpty;
                                          return Marker(
                                            point: c.location,
                                            width: hasStudents ? 72 : 44,
                                            height: hasStudents ? 72 : 44,
                                            alignment: Alignment.bottomCenter,
                                            child: hasStudents
                                                ? _CampusAvatarCluster(
                                                    campus: c,
                                                    users: usersHere,
                                                    selected: _selectedCampus?.id == c.id,
                                                    onTap: () => setState(() => _selectedCampus = c),
                                                  )
                                                : GestureDetector(
                                                    onTap: () => setState(() => _selectedCampus = c),
                                                    child: AnimatedScale(
                                                      scale: _selectedCampus?.id == c.id ? 1.08 : 1.0,
                                                      duration: const Duration(milliseconds: 150),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.accent.withValues(alpha: 0.9),
                                                          shape: BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withValues(alpha: 0.35),
                                                              blurRadius: 12,
                                                              offset: const Offset(0, 6),
                                                            ),
                                                          ],
                                                        ),
                                                        child: const Icon(
                                                          Icons.school_rounded,
                                                          color: Colors.white,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                          );
                                        }),
                                        if (_currentLocation != null)
                                          Marker(
                                            point: _currentLocation!,
                                            width: 28,
                                            height: 28,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.35),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Container(
                                                margin: const EdgeInsets.all(5),
                                                decoration: const BoxDecoration(
                                                  color: AppTheme.accent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: FloatingActionButton.small(
                                  heroTag: 'locate_me',
                                  backgroundColor: AppTheme.card.withValues(alpha: 0.9),
                                  foregroundColor: Colors.white,
                                  onPressed: _locating ? null : _locateMe,
                                  child: _locating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.accent,
                                          ),
                                        )
                                      : const Icon(Icons.my_location_rounded, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBottomCard(context, byCampus),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Map data © OpenStreetMap contributors',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCard(
    BuildContext context,
    Map<String, List<UserProfile>> byCampus,
  ) {
    final campus = _selectedCampus ?? nzCampuses.first;
    final studentsHere = byCampus[campus.id] ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campus.name,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            campus.city,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (studentsHere.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${studentsHere.length} student${studentsHere.length == 1 ? '' : 's'} here',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.accent.withValues(alpha: 0.95),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: studentsHere.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = studentsHere[i];
                  return Tooltip(
                    message: p.name,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ProfileAvatarImage(
                        photoUrl: p.photoUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'No students mapped to this campus yet — pick it to filter Discover.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop<String>(campus.name);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'See students here',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get location: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }
}

/// Stacked profile photos for a campus marker (max 3 faces + overflow count).
class _CampusAvatarCluster extends StatelessWidget {
  final Campus campus;
  final List<UserProfile> users;
  final bool selected;
  final VoidCallback onTap;

  const _CampusAvatarCluster({
    required this.campus,
    required this.users,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double d = 30;
    const overlap = 14.0;
    final show = users.take(3).toList();
    final extra = users.length - show.length;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: d + (show.length - 1) * overlap + (extra > 0 ? 18 : 0),
              height: d + 4,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < show.length; i++)
                    Positioned(
                      left: i * overlap,
                      top: 0,
                      child: Container(
                        width: d,
                        height: d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ProfileAvatarImage(
                          photoUrl: show[i].photoUrl,
                          width: d,
                          height: d,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (extra > 0)
                    Positioned(
                      left: show.length * overlap,
                      top: 2,
                      child: Container(
                        width: d - 4,
                        height: d - 4,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          '+$extra',
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
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                campus.name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
