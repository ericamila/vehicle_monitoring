import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps_flutter;
import 'package:google_maps_webservice/directions.dart' as maps_webservice;
import 'package:vehicle_monitoring/globals/global_var.dart';

class RouteRegistrationPage extends StatefulWidget {
  const RouteRegistrationPage({super.key});

  @override
  State<RouteRegistrationPage> createState() => _RouteRegistrationPageState();
}

class _RouteRegistrationPageState extends State<RouteRegistrationPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('routes');
  final TextEditingController _fuelConsumptionController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  DateTime? _departureTime;
  DateTime? _arrivalTime;
  String? _selectedVehicle;
  List<String> _vehicles = [];
  maps_flutter.GoogleMapController? _mapController;
  maps_flutter.LatLng? _originLatLng;
  maps_flutter.LatLng? _destinationLatLng;
  final Set<maps_flutter.Polyline> _polylines = {};
  final String _googleApiKey = "SUA_CHAVE_DA_API_AQUI";

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
    if (_departureTime == null || _arrivalTime == null || _selectedVehicle == null || _originLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os campos!')));
      return;
    }

    Duration travelTime = _arrivalTime!.difference(_departureTime!);

    _dbRef.push().set({
      'vehicle': _selectedVehicle,
      'departure_time': _departureTime!.toIso8601String(),
      'arrival_time': _arrivalTime!.toIso8601String(),
      'fuel_consumption': _fuelConsumptionController.text,
      'estimated_travel_time': travelTime.inMinutes,
      'origin_lat': _originLatLng!.latitude,
      'origin_lng': _originLatLng!.longitude,
      'destination_lat': _destinationLatLng!.latitude,
      'destination_lng': _destinationLatLng!.longitude,
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota salva com sucesso!')));
    Navigator.pop(context);
  }

  Future<void> _selectDateTime(BuildContext context, bool isDeparture) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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

  void _setDestination(maps_flutter.LatLng latLng, String address) {
    setState(() {
      _destinationLatLng = latLng;
      _destinationController.text = address;
    });
    _fetchRoute();
  }

  void _fetchRoute() async {
    if (_originLatLng == null || _destinationLatLng == null) return;

    final directions = maps_webservice.GoogleMapsDirections(apiKey: _googleApiKey);
    final result = await directions.directionsWithLocation(
      maps_webservice.Location(lat: _originLatLng!.latitude, lng: _originLatLng!.longitude),
      maps_webservice.Location(lat: _destinationLatLng!.latitude, lng: _destinationLatLng!.longitude),
      travelMode: maps_webservice.TravelMode.driving,
    );

    if (result.isOkay && result.routes.isNotEmpty) {
      final route = result.routes.first;
      final points = route.overviewPolyline.points;
      final decodedPoints = _decodePolyline(points);

      setState(() {
        _polylines.clear();
        _polylines.add(maps_flutter.Polyline(
          polylineId: const maps_flutter.PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: decodedPoints,
        ));
      });
    }
  }

  List<maps_flutter.LatLng> _decodePolyline(String encoded) {
    List<maps_flutter.LatLng> points = [];
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
      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      points.add(maps_flutter.LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Rota')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField(
              value: _selectedVehicle,
              items: _vehicles.map((vehicle) => DropdownMenuItem(value: vehicle, child: Text(vehicle))).toList(),
              onChanged: (value) => setState(() {
                _selectedVehicle = value;
                _originLatLng = const maps_flutter.LatLng(2.8333356,-60.6963642); // Exemplo estático
              }),
              decoration: const InputDecoration(labelText: 'Veículo'),
            ),
            TextField(
              controller: _fuelConsumptionController,
              decoration: const InputDecoration(labelText: 'Consumo Previsto (L)'),
              keyboardType: TextInputType.number,
            ),
            ListTile(
              title: Text(_departureTime == null ? 'Selecionar Hora de Partida' : 'Partida: ${_departureTime.toString()}'),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectDateTime(context, true),
            ),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: 'Destino'),
              readOnly: true,
              onTap: () async {},
            ),
            const SizedBox(height: 10),
            Expanded(
              child: maps_flutter.GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: initialCameraPosition,
                onTap: (maps_flutter.LatLng latLng) {
                  _setDestination(latLng, 'Destino selecionado');
                },
                markers: {
                  if (_destinationLatLng != null) maps_flutter.Marker(markerId: const maps_flutter.MarkerId('destination'), position: _destinationLatLng!),
                },
                polylines: _polylines,
              ),
            ),
            ElevatedButton(onPressed: _saveRoute, child: const Text('Salvar Rota')),
          ],
        ),
      ),
    );
  }
}
