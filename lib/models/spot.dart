import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Class that describes model of contractor
class Spot {
  Spot({
    required this.id,
    required this.countryId,
    required this.latLng,
    required this.confidence,
    required this.fromNasa,
    required this.votes,
  });

  int id;
  String countryId;
  LatLng latLng;
  String confidence;
  bool fromNasa;
  Votes votes;

  /// Constructor that create [Spot] from JSON object
  factory Spot.fromJson(Map<String, dynamic> json) {
    return Spot(
      id: json['id'],
      countryId: json['country_id'],
      latLng: LatLng(
          double.parse(json['latitude']), double.parse(json['longitude'])),
      confidence: json['confidence'],
      fromNasa: json['from_nasa'],
      votes: Votes(
          positive: json['votes']['positive'],
          negative: json['votes']['negative']),
    );
  }

  /// Function that converts object to JSON object
  Map<String, dynamic> toJson() => {
        "id": id,
        "country_id": countryId,
        "latitude": latLng.latitude.toString(),
        "longitude": latLng.longitude.toString(),
        "confidence": confidence,
        "from_nasa": fromNasa,
        "votes": {"positive": votes.positive, "negative": votes.negative}
      };

  static String encodeList(List<Spot>? contractors) => contractors != null
      ? json.encode(
          contractors
              .map<Map<String, dynamic>>((contractor) => contractor.toJson())
              .toList(),
        )
      : '[]';

  static List<Spot> decodeList(String? contractors) {
    if (contractors == null) return List<Spot>.empty();
    try {
      return (json.decode(contractors) as List<dynamic>)
          .map<Spot>((item) => Spot.fromJson(item))
          .toList();
    } catch (e) {
      return List<Spot>.empty();
    }
  }
}

class Votes {
  int positive;
  int negative;

  Votes({
    required this.positive,
    required this.negative,
  });
}
