import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nasa_spaceapp_challange_pireus/env.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final double _defaultZoom = 11.0;
  final _mapController = MapController();
  LatLng? _mapCenter;

  @override
  void initState() {
    Geolocator.getPositionStream(
            locationSettings:
                const LocationSettings(timeLimit: Duration(seconds: 10)))
        .listen((event) {
      setState(() {
        if (_mapCenter == null) {
          _mapCenter = LatLng(event.latitude, event.longitude);
          _mapController.move(_mapCenter!, _defaultZoom);
        }
      });
    });
    super.initState();
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _mapCenter,
              zoom: _defaultZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: MyEnv.MAP_URL,
                additionalOptions: const {
                  'accessToken': MyEnv.MAP_ACCESS_TOKEN,
                  'id': 'mapbox.satellite',
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}
