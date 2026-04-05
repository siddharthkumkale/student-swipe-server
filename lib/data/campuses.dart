import 'package:latlong2/latlong.dart';

class Campus {
  final String id;
  final String name;
  final String city;
  final LatLng location;

  const Campus({
    required this.id,
    required this.name,
    required this.city,
    required this.location,
  });
}

/// New Zealand universities and institutes.
const List<Campus> nzCampuses = [
  // =========================
  // UNIVERSITIES
  // =========================
  Campus(
    id: 'uoa',
    name: 'University of Auckland',
    city: 'Auckland',
    location: LatLng(-36.8506, 174.7680),
  ),
  Campus(
    id: 'aut',
    name: 'Auckland University of Technology',
    city: 'Auckland',
    location: LatLng(-36.8531, 174.7653),
  ),
  Campus(
    id: 'waikato',
    name: 'University of Waikato',
    city: 'Hamilton',
    location: LatLng(-37.7870, 175.3150),
  ),
  Campus(
    id: 'massey_akl',
    name: 'Massey University',
    city: 'Auckland',
    location: LatLng(-36.7228, 174.6962),
  ),
  Campus(
    id: 'massey_palmerston',
    name: 'Massey University',
    city: 'Palmerston North',
    location: LatLng(-40.3568, 175.6122),
  ),
  Campus(
    id: 'vuw',
    name: 'Victoria University of Wellington',
    city: 'Wellington',
    location: LatLng(-41.2902, 174.7680),
  ),
  Campus(
    id: 'canterbury',
    name: 'University of Canterbury',
    city: 'Christchurch',
    location: LatLng(-43.5230, 172.5839),
  ),
  Campus(
    id: 'lincoln',
    name: 'Lincoln University',
    city: 'Lincoln',
    location: LatLng(-43.6405, 172.4679),
  ),
  Campus(
    id: 'otago',
    name: 'University of Otago',
    city: 'Dunedin',
    location: LatLng(-45.8650, 170.5140),
  ),

  // =========================
  // PUBLIC COLLEGES / POLYTECHNICS / INSTITUTES
  // =========================
  Campus(
    id: 'unitec',
    name: 'Unitec Institute of Technology',
    city: 'Auckland',
    location: LatLng(-36.8792, 174.7076),
  ),
  Campus(
    id: 'mit',
    name: 'Manukau Institute of Technology',
    city: 'Auckland',
    location: LatLng(-36.9939, 174.8794),
  ),
  Campus(
    id: 'northtec',
    name: 'NorthTec',
    city: 'Whangārei',
    location: LatLng(-35.7098, 174.3237),
  ),
  Campus(
    id: 'wintec',
    name: 'Wintec',
    city: 'Hamilton',
    location: LatLng(-37.7905, 175.2828),
  ),
  Campus(
    id: 'toi_ohomai_tga',
    name: 'Toi Ohomai Institute of Technology',
    city: 'Tauranga',
    location: LatLng(-37.6860, 176.1665),
  ),
  Campus(
    id: 'toi_ohomai_rotorua',
    name: 'Toi Ohomai Institute of Technology',
    city: 'Rotorua',
    location: LatLng(-38.1368, 176.2497),
  ),
  Campus(
    id: 'eit',
    name: 'Eastern Institute of Technology',
    city: 'Napier',
    location: LatLng(-39.6011, 176.8522),
  ),
  Campus(
    id: 'ucol_palmerston',
    name: 'UCOL',
    city: 'Palmerston North',
    location: LatLng(-40.3563, 175.6082),
  ),
  Campus(
    id: 'ucol_whanganui',
    name: 'UCOL',
    city: 'Whanganui',
    location: LatLng(-39.9336, 175.0530),
  ),
  Campus(
    id: 'ucol_masterton',
    name: 'UCOL',
    city: 'Masterton',
    location: LatLng(-40.9465, 175.6678),
  ),
  Campus(
    id: 'whitireia',
    name: 'Whitireia',
    city: 'Porirua',
    location: LatLng(-41.1309, 174.8390),
  ),
  Campus(
    id: 'weltec',
    name: 'Wellington Institute of Technology',
    city: 'Lower Hutt',
    location: LatLng(-41.2117, 174.9059),
  ),
  Campus(
    id: 'open_polytechnic',
    name: 'The Open Polytechnic of New Zealand',
    city: 'Lower Hutt',
    location: LatLng(-41.2140, 174.9035),
  ),
  Campus(
    id: 'nmit_nelson',
    name: 'Nelson Marlborough Institute of Technology',
    city: 'Nelson',
    location: LatLng(-41.2687, 173.2833),
  ),
  Campus(
    id: 'nmit_blenheim',
    name: 'Nelson Marlborough Institute of Technology',
    city: 'Blenheim',
    location: LatLng(-41.5139, 173.9546),
  ),
  Campus(
    id: 'ara_christchurch',
    name: 'Ara Institute of Canterbury',
    city: 'Christchurch',
    location: LatLng(-43.5372, 172.6362),
  ),
  Campus(
    id: 'ara_timaru',
    name: 'Ara Institute of Canterbury',
    city: 'Timaru',
    location: LatLng(-44.3954, 171.2475),
  ),
  Campus(
    id: 'witt',
    name: 'Western Institute of Technology at Taranaki',
    city: 'New Plymouth',
    location: LatLng(-39.0809, 174.0532),
  ),
  Campus(
    id: 'tai_poutini',
    name: 'Tai Poutini Polytechnic',
    city: 'Greymouth',
    location: LatLng(-42.4505, 171.2103),
  ),
  Campus(
    id: 'otago_polytechnic',
    name: 'Otago Polytechnic',
    city: 'Dunedin',
    location: LatLng(-45.8746, 170.5036),
  ),
  Campus(
    id: 'sit_invercargill',
    name: 'Southern Institute of Technology',
    city: 'Invercargill',
    location: LatLng(-46.4137, 168.3538),
  ),
  Campus(
    id: 'sit_queenstown',
    name: 'Southern Institute of Technology',
    city: 'Queenstown',
    location: LatLng(-45.0302, 168.6616),
  ),
];

