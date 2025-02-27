import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_maps_webservice/places.dart' as gmw;
import 'package:firebase_database/firebase_database.dart';

import '../globals/global_var.dart';
import '../methods/common_methods.dart';

class RouteRegistrationPage extends StatefulWidget {
  const RouteRegistrationPage({super.key});

  @override
  State<RouteRegistrationPage> createState() => _RouteRegistrationPageState();
}

class _RouteRegistrationPageState extends State<RouteRegistrationPage> {
  CommonMethods commonMethods = CommonMethods();
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('routes');
  final TextEditingController _searchController =
      TextEditingController(text: 'Ponte dos Macuxis');
  GoogleMapController? _mapController;
  DateTime? _departureTime;
  DateTime? _arrivalTime;
  final Set<Polyline> _polylines = {};
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  String? _estimedTime;
  List<String> _vehicles = [];
  String? _selectedVehicle;
  String? _distance;
  double? _kmAccumulated;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

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
      'fuel_consumption': 6 / 13 * double.parse(_distance!),
      'estimated_travel_time': travelTime.inMinutes,
      'origin_lat': _originLatLng!.latitude,
      'origin_lng': _originLatLng!.longitude,
      'destination_lat': _destinationLatLng!.latitude,
      'destination_lng': _destinationLatLng!.longitude,
      'estimedTime': _estimedTime,
      'distance': _distance,
      'km_accumulated': _kmAccumulated, //não acumula ainda
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
      commonMethods.displaySnackBar(context, "Erro ao buscar coordenadas: $e");
    }
    return null;
  }

  Future<void> _tracarRota() async {
    if (_destinationLatLng == null) return;

    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_originLatLng!.latitude},${_originLatLng!.longitude}&destination=${_destinationLatLng!.latitude},${_destinationLatLng!.longitude}&key=$googleMapKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'].isNotEmpty) {
        final rota = data['routes'][0]['overview_polyline']['points'];
        final time = data['routes'][0]['legs'][0]['duration']['text'];
        final distance = data['routes'][0]['legs'][0]['distance']['text'];

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId("rota"),
              points: commonMethods.decodePolyline(rota),
              color: Colors.blue,
              width: 5,
            ),
          );
          _estimedTime = time;
          _distance = distance;
        });

        LatLng southwest = LatLng(
          _originLatLng!.latitude < _destinationLatLng!.latitude
              ? _originLatLng!.latitude
              : _destinationLatLng!.latitude,
          _originLatLng!.longitude < _destinationLatLng!.longitude
              ? _originLatLng!.longitude
              : _destinationLatLng!.longitude,
        );

        LatLng northeast = LatLng(
          _originLatLng!.latitude > _destinationLatLng!.latitude
              ? _originLatLng!.latitude
              : _destinationLatLng!.latitude,
          _originLatLng!.longitude > _destinationLatLng!.longitude
              ? _originLatLng!.longitude
              : _destinationLatLng!.longitude,
        );

        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: southwest, northeast: northeast),
            100,
          ),
        );
      }
    } else {
      commonMethods.displaySnackBar(context, "Erro ao buscar rota");
    }
  }

  Future<List<gmw.Prediction>> _buscarSugestoes(String query) async {
    final places = gmw.GoogleMapsPlaces(apiKey: googleMapKey);

    final response = await places.autocomplete(
      query,
      components: [gmw.Component(gmw.Component.country, "BR")],
      types: ['geocode'],
      // Retorna apenas locais físicos (endereços, cidades, etc.)
      language: 'pt',
    );

    if (response.isOkay) {
      return response.predictions.take(5).toList(); // Limita a 5 sugestões
    } else {
      commonMethods.displaySnackBar(
          context, "Erro ao buscar sugestões: ${response.errorMessage}");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa e Rotas'),
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.hourglass_top),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveRoute,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            DropdownButtonFormField(
              value: _selectedVehicle,
              items: _vehicles
                  .map((vehicle) =>
                      DropdownMenuItem(value: vehicle, child: Text(vehicle)))
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedVehicle = value;
                FirebaseDatabase.instance
                    .ref()
                    .child('vehicles/$_selectedVehicle')
                    .once()
                    .then((event) {
                  final vehicleData =
                      event.snapshot.value as Map<dynamic, dynamic>?;
                  if (vehicleData != null) {
                    setState(() {
                      _originLatLng = LatLng(
                        double.parse(vehicleData['latitude'].toString()),
                        double.parse(vehicleData['longitude'].toString()),
                      );
                    });
                    _mapController
                        ?.animateCamera(CameraUpdate.newLatLng(_originLatLng!));
                  }
                });
              }),
              decoration: const InputDecoration(labelText: 'Veículo'),
            ),
            ListTile(
              title: Text(_departureTime == null
                  ? 'Selecionar Hora de Partida'
                  : 'Partida: ${_departureTime.toString()}'),
              trailing: const Icon(Icons.access_time, color: Colors.blueGrey),
              onTap: () => _selectDateTime(context, true),
            ),
            ListTile(
              title: Text(_arrivalTime == null
                  ? 'Selecionar Hora de Chegada'
                  : 'Chegada: ${_arrivalTime.toString()}'),
              trailing: const Icon(Icons.access_time, color: Colors.blueGrey),
              onTap: () => _selectDateTime(context, false),
            ),
            TypeAheadField<gmw.Prediction>(
              builder: (context, searchController, focusNode) => TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Digite um endereço",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.blueGrey),
                    onPressed: () async {
                      LatLng? coordenadas = await _buscarCoordenadas(
                        searchController.text,
                      );
                      print('coordenadas $coordenadas');
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
                  leading: const Icon(Icons.location_on, color: Colors.blue),
                  title: Text(suggestion.description ?? "",
                      style: const TextStyle(fontSize: 16)),
                );
              },
              onSelected: (gmw.Prediction suggestion) async {
                _searchController.text = suggestion.description ?? "";
                LatLng? coordenadas =
                    await _buscarCoordenadas(suggestion.description!);
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
                  target: _originLatLng ?? const LatLng(2.8333356, -60.6963642),
                  zoom: 14,
                ),
                myLocationEnabled: true,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                polylines: _polylines,
                markers: {
                  if (_originLatLng != null)
                    Marker(
                        markerId: const MarkerId('origin'),
                        position: _originLatLng!),
                  if (_destinationLatLng != null)
                    Marker(
                        markerId: const MarkerId('destination'),
                        position: _destinationLatLng!),
                },
              ),
            ),
            if (_estimedTime != null && _distance != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Distância: $_distance Tempo estimado: $_estimedTime",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
