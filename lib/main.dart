import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:latlong2/latlong.dart';
import 'package:nasa_spaceapp_challange_pireus/colors.dart';
import 'package:nasa_spaceapp_challange_pireus/components/animated_switcher.dart';
import 'package:nasa_spaceapp_challange_pireus/components/loading.dart';
import 'package:nasa_spaceapp_challange_pireus/env.dart';
import 'package:geolocator/geolocator.dart';
import 'package:slide_action/slide_action.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
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
  final double _defaultZoom = 12.0;
  final _mapController = MapController();
  LatLng? _mapCenter;
  LatLng? _focusPoint;
  bool isAddingDanger = false;
  bool isSendingReport = false;

  @override
  void initState() {
    Future.delayed(
      const Duration(seconds: 2),
      () {
        _determinePosition();
      },
    );
    super.initState();
  }

  void _determinePosition() async {
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
        print('New position setted to $_mapCenter');
      }
    });
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
                  center: _mapCenter,
                  zoom: _defaultZoom,
                  maxZoom: 18,
                  minZoom: 3),
              children: [
                TileLayer(
                  urlTemplate: MyEnv.MAP_URL,
                  additionalOptions: const {
                    'accessToken': MyEnv.MAP_ACCESS_TOKEN,
                    'id': 'mapbox.satellite',
                  },
                ),
                MarkerLayer(
                  markers: [
                    /// User position
                    if (_mapCenter != null)
                      Marker(
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
              Positioned(
                bottom: 15,
                right: 15,
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
                            child: isAddingDanger
                                ? SlideAction(
                                    trackHeight: 80,
                                    stretchThumb: true,
                                    snapAnimationCurve: Curves.linear,
                                    trackBuilder: (context, currentState) {
                                      return const Center(
                                        child: Text("Slide to confirm >>"),
                                      );
                                    },
                                    thumbBuilder: (context, currentState) {
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
                                                        color: MyColors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                    action: () async {
                                      if (await Vibration.hasVibrator() ??
                                          false) {
                                        Vibration.vibrate();
                                      }

                                      var positon = _mapController
                                          .pointToLatLng(CustomPoint(
                                              constraints.maxWidth * 0.5,
                                              constraints.maxHeight * 0.5));
                                      print(
                                          "Sending report with positon: $positon");
                                      setState(() {
                                        isSendingReport = true;
                                      });
                                      await Future.delayed(
                                        const Duration(seconds: 2),
                                        () {
                                          setState(() {
                                            isSendingReport = false;
                                            isAddingDanger = false;
                                          });
                                        },
                                      );
                                    },
                                  )
                                : Stack(
                                    children: [
                                      button,
                                    ],
                                  ),
                          ),
                        ),
                      );
                    }),
                    mapButton(Icons.my_location, () {
                      _mapController.move(_mapCenter!, _defaultZoom);
                    }),
                    mapButton(
                        Icons.zoom_in,
                        _mapController.zoom < 17
                            ? () {
                                setState(() {
                                  _mapController.move(_mapController.center,
                                      _mapController.zoom + 1);
                                });
                              }
                            : null),
                    mapButton(
                        Icons.zoom_out,
                        _mapController.zoom > 4
                            ? () {
                                setState(() {
                                  _mapController.move(_mapController.center,
                                      _mapController.zoom - 1);
                                });
                              }
                            : null),
                  ].reversed.toList(),
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
                top: isAddingDanger && !isSendingReport ? 15 : -100,
                child: SafeArea(
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
                        const Expanded(
                            child: Text(
                                "Select a point on the map where the fire is occurring")),
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
                )),
            if (_mapCenter == null) Positioned.fill(child: loadingPage())
          ],
        );
      }),
    );
  }
}
