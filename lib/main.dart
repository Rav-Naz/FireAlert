import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:latlong2/latlong.dart';
import 'package:nasa_spaceapp_challange_pireus/colors.dart';
import 'package:nasa_spaceapp_challange_pireus/components/animated_switcher.dart';
import 'package:nasa_spaceapp_challange_pireus/components/loading.dart';
import 'package:nasa_spaceapp_challange_pireus/env.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nasa_spaceapp_challange_pireus/models/spot.dart';
import 'package:nasa_spaceapp_challange_pireus/services/push_notification_service.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:slide_action/slide_action.dart';
import 'package:vibration/vibration.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(backgroundHandler);

  runApp(const MyApp());
}

Future<void> backgroundHandler(RemoteMessage message) async {
  print('Handling a background message ${message.messageId}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorSchemeSeed: MyColors.primary,
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
  final PushNotificationService _notificationService =
      PushNotificationService();

  final double _defaultZoom = 12.0;
  final _mapController = MapController();
  LatLng? _mapCenter;
  LatLng? _focusPoint;
  bool isAddingDanger = false;
  bool isSendingReport = false;
  String baseUrl = "http://10.10.10.22:80/api";
  List<Spot>? brightSpots;
  Spot? currentlyViewingSpot;
  double? onePixelIsThisMeters;
  late double lastZoom;
  double radiusOfCircleMarkInMeters = 2500;

  @override
  void initState() {
    lastZoom = _defaultZoom;
    _notificationService.initialize();
    start();

    super.initState();
  }

  void start() {
    _determinePosition().then((currPos) async {
      var data = {
        "device_id": await _notificationService.getToken(),
        "ftm_token": await _notificationService.getToken(),
        "latitude": currPos.latitude.toString(),
        "longitude": currPos.longitude.toString(),
        "country": "greece"
      };
      var response = await Dio().post("$baseUrl/actual-position",
          data: data,
          options: Options(headers: {"Accept": "application/json"}));
      print(response.data);
      setState(() {
        brightSpots = List<Spot>.from((response.data['brightSpots'] as Iterable)
            .map((model) => Spot.fromJson(model)));
      });
    });
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
    // await Future.delayed(const Duration(seconds: 3));
    Geolocator.getPositionStream(locationSettings: const LocationSettings())
        .listen((event) {
      var newLatLong = LatLng(event.latitude, event.longitude);
      if (mounted && _mapCenter.toString() != newLatLong.toString()) {
        var mapCenterBeforeChange = _mapCenter.toString();
        setState(() {
          _mapCenter = newLatLong;
          if (mapCenterBeforeChange == "null") {
            _mapController.move(_mapCenter!, _defaultZoom);
          }
        });
        // print('New position setted to $_mapCenter');
      }
    });
    var currPos = await Geolocator.getCurrentPosition();
    var newLatLong = LatLng(currPos.latitude, currPos.longitude);

    if (mounted && _mapCenter.toString() != newLatLong.toString()) {
      var mapCenterBeforeChange = _mapCenter.toString();
      setState(() {
        _mapCenter = newLatLong;
        if (mapCenterBeforeChange == "null") {
          _mapController.move(_mapCenter!, _defaultZoom);
        }
      });
      // print('New position setted to $_mapCenter');
    }
    return currPos;
  }

  Widget mapButton(IconData icon, void Function()? onPressed) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Container(
        decoration: BoxDecoration(boxShadow: [
          BoxShadow(
              color: MyColors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10)
        ], shape: BoxShape.circle),
        child: IconButton(
          onPressed: onPressed,
          iconSize: 25,
          icon: Icon(icon),
          highlightColor: MyColors.primary.withOpacity(0.4),
          color: onPressed != null ? MyColors.black : MyColors.grey,
          style: const ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(MyColors.white),
              padding: MaterialStatePropertyAll(EdgeInsets.all(15))),
        ),
      ),
    );
  }

  Widget loadingPage() {
    return Container(
      color: MyColors.white,
      child: Center(
        child: MyLoading(),
      ),
    );
  }

  double getDistanceBetweenPoints(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
    String unit,
  ) {
    final double theta = longitude1 - longitude2;
    double distance =
        (sin(degreesToRadians(latitude1)) * sin(degreesToRadians(latitude2))) +
            (cos(degreesToRadians(latitude1)) *
                cos(degreesToRadians(latitude2)) *
                cos(degreesToRadians(theta)));
    distance = acos(distance);
    distance = radiansToDegrees(distance);
    distance = distance * 60 * 1.1515;
    switch (unit) {
      case 'miles':
        break;
      case 'kilometers':
        distance = distance * 1.609344;
        break;
      case 'meters':
        distance = distance * 1.609344 * 1000;
        break;
      default:
        throw ArgumentError('Invalid unit: $unit');
    }
    return double.parse(distance.toStringAsFixed(2));
  }

  double degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  double radiansToDegrees(double radians) {
    return radians * 180.0 / pi;
  }

  double calculatePixelToMeters(CustomPoint point1, CustomPoint point2) {
    var latLng1 = _mapController.pointToLatLng(point1);
    var latLng2 = _mapController.pointToLatLng(point2);
    var distanceInPixels = point2.x;
    var distanceInMeters = getDistanceBetweenPoints(latLng1.latitude,
        latLng1.longitude, latLng2.latitude, latLng2.longitude, "meters");
    var onePixelIsThisMeters = distanceInMeters / distanceInPixels;
    return onePixelIsThisMeters;
  }

  @override
  Widget build(BuildContext context) {
    // return Scaffold();
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          children: [
            /// Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                  onMapReady: () {
                    setState(() {
                      onePixelIsThisMeters = calculatePixelToMeters(
                          const CustomPoint(0, 0),
                          CustomPoint(constraints.maxWidth, 0));
                    });
                  },
                  onMapEvent: (p0) {
                    if (currentlyViewingSpot != null) {
                      setState(() {
                        currentlyViewingSpot = null;
                      });
                    }
                    if (p0 is MapEventMove &&
                        (lastZoom - p0.zoom).abs() > 0.2) {
                      setState(() {
                        lastZoom = p0.zoom;
                        onePixelIsThisMeters = calculatePixelToMeters(
                            const CustomPoint(0, 0),
                            CustomPoint(constraints.maxWidth, 0));
                      });
                    }
                  },
                  center: _mapCenter,
                  zoom: _defaultZoom,
                  interactiveFlags: isSendingReport
                      ? InteractiveFlag.none
                      : InteractiveFlag.all,
                  maxZoom: 17,
                  minZoom: 4),
              children: [
                TileLayer(
                  urlTemplate: MyEnv.MAP_URL,
                  additionalOptions: const {
                    'accessToken': MyEnv.MAP_ACCESS_TOKEN,
                    'id': 'mapbox.satellite',
                  },
                ),

                /// Circles
                if (brightSpots != null) ...[
                  CircleLayer(
                    circles: brightSpots!
                        .map((e) => CircleMarker(
                            point: e.latLng,
                            radius: radiusOfCircleMarkInMeters,
                            useRadiusInMeter: true,
                            color: MyColors.primary.withOpacity(0.3),
                            borderColor: MyColors.primary,
                            borderStrokeWidth: 3))
                        .toList(),
                  ),
                  if (onePixelIsThisMeters != null)
                    MarkerLayer(
                      markers: brightSpots!.map((e) {
                        var size = (radiusOfCircleMarkInMeters /
                                onePixelIsThisMeters!) *
                            2;
                        return Marker(
                          rotate: true,
                          point: e.latLng,
                          height: size,
                          width: size,
                          builder: (context) {
                            return TextButton(
                                onPressed: !isAddingDanger
                                    ? () {
                                        var point1 = const CustomPoint(0, 0);
                                        var point2 = CustomPoint(0, size);
                                        var latlong1 = _mapController
                                            .pointToLatLng(point1);
                                        var latlong2 = _mapController
                                            .pointToLatLng(point2);
                                        var c = sqrt(pow(
                                                latlong1.latitude -
                                                    latlong2.latitude,
                                                2) +
                                            pow(
                                                latlong1.longitude -
                                                    latlong2.longitude,
                                                2));

                                        _mapController.fitBounds(
                                            LatLngBounds(
                                                LatLng(e.latLng.latitude - c,
                                                    e.latLng.longitude - c),
                                                LatLng(e.latLng.latitude + c,
                                                    e.latLng.longitude + c)),
                                            options: const FitBoundsOptions(
                                                maxZoom: 17,
                                                padding: EdgeInsets.all(20)));
                                        _mapController.move(
                                            e.latLng, _mapController.zoom,
                                            offset: Offset(0,
                                                constraints.maxHeight * -0.15));
                                        setState(() {
                                          currentlyViewingSpot = e;
                                          lastZoom = _mapController.zoom;
                                          onePixelIsThisMeters =
                                              calculatePixelToMeters(
                                                  const CustomPoint(0, 0),
                                                  CustomPoint(
                                                      constraints.maxWidth, 0));
                                        });
                                      }
                                    : null,
                                child: Visibility(
                                  visible: _mapController.zoom > 10,
                                  child: Center(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department,
                                          color: MyColors.primary,
                                          size: size / 3,
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Transform.translate(
                                              offset: Offset(0, (size / 100)),
                                              child: Icon(
                                                Icons.thumb_down,
                                                color: MyColors.white,
                                                size: size / 10,
                                              ),
                                            ),
                                            SizedBox(
                                              width: size / 50,
                                            ),
                                            Text(
                                              e.votes.negative.toString(),
                                              style: TextStyle(
                                                  color: MyColors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: size / 10),
                                            ),
                                            SizedBox(
                                              width: size / 10,
                                            ),
                                            Transform.translate(
                                              offset: Offset(0, (size / 100)),
                                              child: Icon(
                                                Icons.thumb_up,
                                                color: MyColors.white,
                                                size: size / 10,
                                              ),
                                            ),
                                            SizedBox(
                                              width: size / 50,
                                            ),
                                            Text(
                                              e.votes.positive.toString(),
                                              style: TextStyle(
                                                  color: MyColors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: size / 10),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ));
                          },
                        );
                      }).toList(),
                    )
                ],

                /// User position
                MarkerLayer(
                  markers: [
                    if (_mapCenter != null)
                      Marker(
                        rotate: true,
                        point: _mapCenter!,
                        height: 30,
                        width: 30,
                        builder: (context) {
                          return Builder(builder: (context) {
                            return Container(
                              decoration: BoxDecoration(
                                  color: MyColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: MyColors.white,
                                      width: 3,
                                      strokeAlign: 1)),
                              child: const Icon(
                                Icons.person,
                                color: MyColors.secondary,
                                size: 23,
                              ),
                            );
                          });
                        },
                      ),
                    if (_focusPoint != null)
                      Marker(
                        point: _focusPoint!,
                        height: 40,
                        width: 40,
                        builder: (context) {
                          return Builder(builder: (context) {
                            return const Icon(
                              Icons.location_searching,
                              color: MyColors.primary,
                              size: 40,
                            );
                          });
                        },
                      ),
                  ],
                )
              ],
            ),

            /// Map buttons
            if (_mapCenter != null)
              AnimatedPositioned(
                curve: Curves.linear,
                duration: const Duration(milliseconds: 300),
                bottom: 15,
                right: currentlyViewingSpot == null ? 15 : -100,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Builder(builder: (context) {
                        var button = const Positioned(
                            top: 15,
                            bottom: 15,
                            right: 15,
                            child: Icon(
                              Icons.local_fire_department,
                              color: MyColors.white,
                              size: 50,
                            ));
                        var maxWidth = constraints.maxWidth - 30;
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                isAddingDanger = true;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.linear,
                              width: isAddingDanger ? maxWidth : 80,
                              height: 80,
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1000),
                                boxShadow: [
                                  BoxShadow(
                                      color: MyColors.black.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 10)
                                ],
                                color: isAddingDanger && !isSendingReport
                                    ? MyColors.white
                                    : MyColors.primary,
                              ),
                              child: isAddingDanger && _mapCenter != null
                                  ? StreamBuilder(
                                      stream: _mapController.mapEventStream,
                                      builder: (context, snap) {
                                        var latlongCenter = _mapController
                                            .pointToLatLng(CustomPoint(
                                                constraints.maxWidth * 0.5,
                                                constraints.maxHeight * 0.5));
                                        var distane = getDistanceBetweenPoints(
                                            latlongCenter.latitude,
                                            latlongCenter.longitude,
                                            _mapCenter!.latitude,
                                            _mapCenter!.longitude,
                                            "kilometers");
                                        return SlideAction(
                                          trackHeight: 80,
                                          stretchThumb: true,
                                          snapAnimationCurve: Curves.linear,
                                          trackBuilder:
                                              (context, currentState) {
                                            return const Stack(
                                              children: [
                                                Center(
                                                  child: Text(
                                                      "Slide to confirm >>"),
                                                ),
                                                Positioned(
                                                    top: 15,
                                                    bottom: 15,
                                                    right: 15,
                                                    child: Icon(
                                                      Icons
                                                          .notifications_active,
                                                      color: MyColors.grey,
                                                      size: 50,
                                                    ))
                                              ],
                                            );
                                          },
                                          thumbBuilder:
                                              (context, currentState) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(1000),
                                                color: MyColors.primary,
                                              ),
                                              child: MyAnimatedSwitcher(
                                                  firstChild: const Center(
                                                    child: SpinKitWave(
                                                      color: MyColors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  secondChild: Stack(
                                                    children: [
                                                      Opacity(
                                                        opacity: currentState
                                                            .thumbFractionalPosition,
                                                        child: const Center(
                                                            child: Text(
                                                          "ALARM!!!",
                                                          style: TextStyle(
                                                              color: MyColors
                                                                  .white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 20),
                                                        )),
                                                      ),
                                                      button
                                                    ],
                                                  ),
                                                  isFirst: currentState
                                                      .isPerformingAction),
                                            );
                                          },
                                          action: distane > 10
                                              ? null
                                              : () async {
                                                  if (await Vibration
                                                          .hasVibrator() ??
                                                      false) {
                                                    Vibration.vibrate();
                                                  }

                                                  var positon = _mapController
                                                      .pointToLatLng(CustomPoint(
                                                          constraints.maxWidth *
                                                              0.5,
                                                          constraints
                                                                  .maxHeight *
                                                              0.5));
                                                  print(
                                                      "Sending report with positon: $positon");
                                                  setState(() {
                                                    isSendingReport = true;
                                                  });
                                                  var data = {
                                                    "ftm_token":
                                                        await _notificationService
                                                            .getToken(),
                                                    "device_id":
                                                        await _notificationService
                                                            .getToken(),
                                                    "latitude": positon.latitude
                                                        .toString(),
                                                    "longitude": positon
                                                        .longitude
                                                        .toString(),
                                                    "country": "greece"
                                                  };
                                                  var response = await Dio().post(
                                                      "$baseUrl/bright-spots",
                                                      data: data,
                                                      options: Options(
                                                          headers: {
                                                            "Accept":
                                                                "application/json"
                                                          }));
                                                  QuickAlert.show(
                                                    context: context,
                                                    type:
                                                        QuickAlertType.success,
                                                    text: 'Fire spot reported',
                                                  );
                                                  setState(() {
                                                    isSendingReport = false;
                                                    isAddingDanger = false;
                                                    Future.delayed(
                                                      const Duration(
                                                          seconds: 1),
                                                      () {
                                                        setState(() {
                                                          brightSpots = List<
                                                              Spot>.from((response
                                                                          .data[
                                                                      'data']
                                                                  as Iterable)
                                                              .map((model) =>
                                                                  Spot.fromJson(
                                                                      model)));
                                                        });
                                                      },
                                                    );
                                                  });
                                                },
                                        );
                                      })
                                  : Stack(
                                      children: [
                                        button,
                                      ],
                                    ),
                            ),
                          ),
                        );
                      }),
                      MyAnimatedSwitcher(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              mapButton(Icons.contact_emergency, () async {
                                const url = "tel:123456789";
                                if (await canLaunch(url)) {
                                  await launch(url);
                                } else {
                                  throw 'Could not launch $url';
                                }
                              }),
                              mapButton(Icons.refresh, start),
                              mapButton(Icons.my_location, () {
                                _mapController.move(_mapCenter!, _defaultZoom);
                                onePixelIsThisMeters = calculatePixelToMeters(
                                    const CustomPoint(0, 0),
                                    CustomPoint(constraints.maxWidth, 0));
                              }),
                              mapButton(
                                  Icons.zoom_in,
                                  _mapController.zoom < 17
                                      ? () {
                                          setState(() {
                                            _mapController.move(
                                                _mapController.center,
                                                _mapController.zoom + 1);
                                            onePixelIsThisMeters =
                                                calculatePixelToMeters(
                                                    const CustomPoint(0, 0),
                                                    CustomPoint(
                                                        constraints.maxWidth,
                                                        0));
                                          });
                                        }
                                      : null),
                              mapButton(
                                  Icons.zoom_out,
                                  _mapController.zoom > 4
                                      ? () {
                                          setState(() {
                                            _mapController.move(
                                                _mapController.center,
                                                _mapController.zoom - 1);
                                            onePixelIsThisMeters =
                                                calculatePixelToMeters(
                                                    const CustomPoint(0, 0),
                                                    CustomPoint(
                                                        constraints.maxWidth,
                                                        0));
                                          });
                                        }
                                      : null),
                            ],
                          ),
                          isFirst: isSendingReport)
                    ].reversed.toList(),
                  ),
                ),
              ),

            MyAnimatedSwitcher(
                firstChild: const Center(
                  child: Icon(
                    Icons.location_searching,
                    color: MyColors.primary,
                    size: 40,
                  ),
                ),
                secondChild: const SizedBox.shrink(),
                isFirst: isAddingDanger),

            /// Top info
            AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                left: 15,
                right: 15,
                top: isAddingDanger && !isSendingReport ? 15 : -150,
                child: StreamBuilder<Object>(
                    stream: _mapController.mapEventStream,
                    builder: (context, snap) {
                      var distane = double.infinity;
                      if (_mapCenter != null) {
                        var latlongCenter = _mapController.pointToLatLng(
                            CustomPoint(constraints.maxWidth * 0.5,
                                constraints.maxHeight * 0.5));
                        distane = getDistanceBetweenPoints(
                            latlongCenter.latitude,
                            latlongCenter.longitude,
                            _mapCenter!.latitude,
                            _mapCenter!.longitude,
                            "kilometers");
                      }
                      return SafeArea(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: MyColors.white,
                              boxShadow: [
                                BoxShadow(
                                    color: MyColors.black.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 10)
                              ]),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const Text(
                                      "Select a point on the map where the fire is occurring"),
                                  if (distane > 10)
                                    const Text(
                                      "You can't report a danger in range more than 10 km",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                ],
                              )),
                              TextButton(
                                  onPressed: () {
                                    setState(() {
                                      isAddingDanger = false;
                                    });
                                  },
                                  child: const Text(
                                    "Exit",
                                    style: TextStyle(color: MyColors.primary),
                                  ))
                            ],
                          ),
                        ),
                      );
                    })),

            /// Confirmation
            StreamBuilder<Object>(
                stream: _mapController.mapEventStream,
                builder: (context, snap) {
                  var distane = double.infinity;
                  if (_mapCenter != null) {
                    var latlongCenter = _mapController.pointToLatLng(
                        CustomPoint(constraints.maxWidth * 0.5,
                            constraints.maxHeight * 0.5));
                    distane = getDistanceBetweenPoints(
                        latlongCenter.latitude,
                        latlongCenter.longitude,
                        _mapCenter!.latitude,
                        _mapCenter!.longitude,
                        "kilometers");
                  }
                  return AnimatedPositioned(
                      left: 15,
                      right: 15,
                      bottom: currentlyViewingSpot == null ? -300 : 15,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: MyColors.white,
                            boxShadow: [
                              BoxShadow(
                                  color: MyColors.black.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 10)
                            ],
                            borderRadius: BorderRadius.circular(15)),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            var space = 15.0;
                            var buttonSide = (constraints.maxWidth - space) / 2;
                            var disabled = distane > 10;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (disabled)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 5.0),
                                    child: Text(
                                      "You can't confirm a danger in range more than 10 km",
                                      style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                Row(
                                  children: [
                                    TextButton(
                                        onPressed: disabled
                                            ? null
                                            : () async {
                                                int ID =
                                                    currentlyViewingSpot!.id;
                                                setState(() {
                                                  currentlyViewingSpot = null;
                                                });
                                                var response = await Dio().post(
                                                    "$baseUrl/bright-spots/$ID/vote?vote=0",
                                                    options: Options(headers: {
                                                      "Accept":
                                                          "application/json"
                                                    }));
                                                setState(() {
                                                  var index = brightSpots!
                                                      .indexWhere((element) =>
                                                          element.id == ID);
                                                  if (index >= 0) {
                                                    brightSpots?[index] =
                                                        Spot.fromJson(response
                                                            .data["data"]);
                                                  }
                                                });
                                              },
                                        style: ButtonStyle(
                                            shape: MaterialStateProperty.all<
                                                    RoundedRectangleBorder>(
                                                RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                            )),
                                            backgroundColor:
                                                MaterialStatePropertyAll(
                                                    MyColors.primary
                                                        .withOpacity(disabled
                                                            ? 0.5
                                                            : 1)),
                                            fixedSize: MaterialStatePropertyAll(
                                                Size(buttonSide, buttonSide))),
                                        child: Icon(
                                          Icons.thumb_down,
                                          color: MyColors.white,
                                          size: buttonSide / 2,
                                        )),
                                    SizedBox(
                                      width: space,
                                    ),
                                    TextButton(
                                        onPressed: disabled
                                            ? null
                                            : () async {
                                                int ID =
                                                    currentlyViewingSpot!.id;
                                                setState(() {
                                                  currentlyViewingSpot = null;
                                                });
                                                var response = await Dio().post(
                                                    "$baseUrl/bright-spots/$ID/vote?vote=1",
                                                    options: Options(headers: {
                                                      "Accept":
                                                          "application/json"
                                                    }));
                                                setState(() {
                                                  var index = brightSpots!
                                                      .indexWhere((element) =>
                                                          element.id == ID);
                                                  if (index >= 0) {
                                                    brightSpots?[index] =
                                                        Spot.fromJson(response
                                                            .data["data"]);
                                                  }
                                                });
                                              },
                                        style: ButtonStyle(
                                            shape: MaterialStateProperty.all<
                                                    RoundedRectangleBorder>(
                                                RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                            )),
                                            backgroundColor:
                                                MaterialStatePropertyAll(
                                                    MyColors.green.withOpacity(
                                                        disabled ? 0.5 : 1)),
                                            fixedSize: MaterialStatePropertyAll(
                                                Size(buttonSide, buttonSide))),
                                        child: Icon(
                                          Icons.thumb_up,
                                          color: MyColors.white,
                                          size: buttonSide / 2,
                                        )),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ));
                }),
            if (_mapCenter == null) Positioned.fill(child: loadingPage())
          ],
        );
      }),
    );
  }
}
