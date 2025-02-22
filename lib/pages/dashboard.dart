import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vehicle_monitoring/pages/vehicle_list_page.dart';

import '../globals/global_var.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final Completer<GoogleMapController> _googleMapCompletterController =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('vehicles');
  final DatabaseReference _logRef =
      FirebaseDatabase.instance.ref().child('logs');
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchVehicleLocation();
    _logEvent("Usuário logado");
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _logEvent("Usuário deslogado");
    super.dispose();
  }

  void _fetchVehicleLocation() {
    _subscription = _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      Set<Marker> newMarkers = {};
      if (data != null) {
        data.forEach((key, value) {
          if (value['latitude'] != null && value['longitude'] != null) {
            bool emMovimento = value['em_movimento'] ?? false;
            if (emMovimento) {
              _logEvent("Veículo $key em movimento");
            }
            var marker = Marker(
              markerId: MarkerId(key),
              position: LatLng(value['latitude'], value['longitude']),
              icon: emMovimento
                  ? BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed)
                  : BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue),
              infoWindow: InfoWindow(
                title: key,
                snippet:
                    'Velocidade: ${value['velocidade'] ?? "N/A"} km/h\nMovimento: ${emMovimento ? "Sim" : "Não"}',
              ),
            );
            newMarkers.add(marker);
          }
        });
      }
      setState(() {
        _markers = newMarkers;
      });
      _adjustMapView();
    });
  }

  void _logEvent(String message) {
    _logRef
        .push()
        .set({'timestamp': DateTime.now().toIso8601String(), 'event': message});
  }

  void _adjustMapView() {
    if (_markers.isNotEmpty && _mapController != null) {
      LatLngBounds bounds = _getBounds(_markers);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  LatLngBounds _getBounds(Set<Marker> markers) {
    double south = markers.first.position.latitude;
    double north = markers.first.position.latitude;
    double west = markers.first.position.longitude;
    double east = markers.first.position.longitude;

    for (var marker in markers) {
      if (marker.position.latitude < south) south = marker.position.latitude;
      if (marker.position.latitude > north) north = marker.position.latitude;
      if (marker.position.longitude < west) west = marker.position.longitude;
      if (marker.position.longitude > east) east = marker.position.longitude;
    }
    return LatLngBounds(
        southwest: LatLng(south, west), northeast: LatLng(north, east));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _adjustMapView();
            },
          ),
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const VehicleListPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _logEvent("Usuário deslogou");
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        myLocationEnabled: true,
        initialCameraPosition: initialCameraPosition,
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          _googleMapCompletterController.complete(_mapController);
        },
      ),
    );
  }
}
