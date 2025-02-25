import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_maps_webservice/places.dart' as gmw;
import 'package:firebase_database/firebase_database.dart';

import '../globals/global_var.dart';
import '../methods/common_methods.dart';

/// IMPRIMIR A COORDENADA DE ORIGEM NO CONSOLE

class RouteRegistrationPage extends StatefulWidget {
  const RouteRegistrationPage({super.key});

  @override
  State<RouteRegistrationPage> createState() => _RouteRegistrationPageState();
}

class _RouteRegistrationPageState extends State<RouteRegistrationPage> {
  CommonMethods commonMethods = CommonMethods();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('routes');
  final TextEditingController _searchController = TextEditingController(text: 'Ponte dos Macuxis');
  GoogleMapController? _mapController;
  DateTime? _departureTime;
  DateTime? _arrivalTime;
  final Set<Polyline> _polylines = {};
  LatLng _userLocation = const LatLng(2.8333356, -60.6963642);///todo trocar
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  String? _tempoEstimado;
  List<String> _vehicles = [];
  String? _selectedVehicle;
  double _fuelConsumption = 0;


  @override
  void initState() {
    super.initState();
    ///trocar
    //_getUserLocation();
    _loadVehicles();
  }

  Future<void> _getUserLocation() async {///trocar
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(_userLocation));
  }///trocar

  void _loadVehicles() {
    FirebaseDatabase.instance.ref().child('vehicles').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _vehicles = data.keys.cast<String>().toList();
        });
      }
    });
  }

  void _saveRoute() {
    if (_departureTime == null ||
        _arrivalTime == null ||
        _selectedVehicle == null ||
        _originLatLng == null ||
        _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }

    Duration travelTime = _arrivalTime!.difference(_departureTime!);

    _dbRef.push().set({
      'vehicle': _selectedVehicle,
      'departure_time': _departureTime!.toIso8601String(),
      'arrival_time': _arrivalTime!.toIso8601String(),
      'fuel_consumption': _fuelConsumption,///todo
      'estimated_travel_time': travelTime.inMinutes,
      'estimated_travel_time2': _tempoEstimado,
      'origin_lat': _originLatLng!.latitude,
      'origin_lng': _originLatLng!.longitude,
      'destination_lat': _destinationLatLng!.latitude,
      'destination_lng': _destinationLatLng!.longitude,
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Rota salva com sucesso!')));
    Navigator.pop(context);
  }

  Future<void> _selectDateTime(BuildContext context, bool isDeparture) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2050),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    setState(() {
      final selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (isDeparture) {
        _departureTime = selectedDateTime;
      } else {
        _arrivalTime = selectedDateTime;
      }
    });
  }

  Future<LatLng?> _buscarCoordenadas(String endereco) async {
    try {
      List<Location> locations = await locationFromAddress(endereco);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      commonMethods.displaySnackBar(context,"Erro ao buscar coordenadas: $e");
    }
    return null;
  }

  Future<void> _tracarRota() async {
    if (_destinationLatLng == null) return;

    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_userLocation.latitude},${_userLocation.longitude}&destination=${_destinationLatLng!.latitude},${_destinationLatLng!.longitude}&key=$googleMapKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'].isNotEmpty) {
        final rota = data['routes'][0]['overview_polyline']['points'];
        final tempo = data['routes'][0]['legs'][0]['duration']['text'];

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId("rota"),
              points: _decodePolyline(rota),
              color: Colors.blue,
              width: 5,
            ),
          );
          _tempoEstimado = tempo;
        });

        LatLng southwest = LatLng(
          _userLocation.latitude < _destinationLatLng!.latitude ? _userLocation.latitude : _destinationLatLng!.latitude,
          _userLocation.longitude < _destinationLatLng!.longitude ? _userLocation.longitude : _destinationLatLng!.longitude,
        );

        LatLng northeast = LatLng(
          _userLocation.latitude > _destinationLatLng!.latitude ? _userLocation.latitude : _destinationLatLng!.latitude,
          _userLocation.longitude > _destinationLatLng!.longitude ? _userLocation.longitude : _destinationLatLng!.longitude,
        );

        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: southwest, northeast: northeast),
            100,
          ),
        );
      }
    } else {
      commonMethods.displaySnackBar(context,"Erro ao buscar rota");
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }


  Future<List<gmw.Prediction>> _buscarSugestoes(String query) async {
    final places = gmw.GoogleMapsPlaces(apiKey: googleMapKey);
    final response = await places.autocomplete(query);

    if (response.isOkay) {
      return response.predictions;
    } else {
      commonMethods.displaySnackBar(context,"Erro ao buscar sugestões: ${response.errorMessage}");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa e Rotas 2 - Google Maps')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            DropdownButtonFormField(
              value: _selectedVehicle,
              items: _vehicles
                  .map((vehicle) =>
                  DropdownMenuItem(value: vehicle, child: Text(vehicle)))
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedVehicle = value;
                FirebaseDatabase.instance.ref().child('vehicles/$_selectedVehicle').once().then((event) {
                  final vehicleData = event.snapshot.value as Map<dynamic, dynamic>?;
                  if (vehicleData != null) {
                    print("foi \n");
                    print(vehicleData['latitude'].toString());
                    print(vehicleData['longitude'].toString());
                    setState(() {
                      _originLatLng = LatLng(
                        double.parse(vehicleData['latitude'].toString()),
                        double.parse(vehicleData['longitude'].toString()),
                      );
                    });
                  }
                });
              }),
              decoration: const InputDecoration(labelText: 'Veículo'),
            ),
            TypeAheadField<gmw.Prediction>(
              builder: (context, searchController, focusNode) => TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Digite um endereço",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      LatLng? coordenadas = await _buscarCoordenadas(
                        searchController.text,
                      );
                      if (coordenadas != null) {
                        setState(() {
                          _destinationLatLng = coordenadas;
                        });
                        _tracarRota();
                      }
                    },
                  ),
                ),
              ),
              suggestionsCallback: _buscarSugestoes,
              itemBuilder: (context, gmw.Prediction suggestion) {
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(suggestion.description ?? ""),
                );
              },
              onSelected: (gmw.Prediction suggestion) async {
                _searchController.text = suggestion.description ?? "";
                LatLng? coordenadas = await _buscarCoordenadas(
                  suggestion.description!,
                );
                if (coordenadas != null) {
                  setState(() {
                    _destinationLatLng = coordenadas;
                  });
                  _tracarRota();
                }
              },
            ),

            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _userLocation,
                  zoom: 14,
                ),
                myLocationEnabled: true,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                polylines: _polylines,
              ),
            ),
            if (_tempoEstimado != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Tempo estimado: $_tempoEstimado",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
