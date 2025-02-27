import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../methods/common_methods.dart';

class VehicleListPage extends StatefulWidget {
  const VehicleListPage({super.key});

  @override
  State<VehicleListPage> createState() => _VehicleListPageState();
}

class _VehicleListPageState extends State<VehicleListPage> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('vehicles');
  final DatabaseReference _driverRef =
      FirebaseDatabase.instance.ref().child('drivers');
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, String> _drivers = {};

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    _fetchDrivers();
  }

  void _fetchVehicles() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        List<Map<String, dynamic>> tempVehicles = [];
        data.forEach((key, value) {
          tempVehicles.add({
            'id': key,
            'marca': value['marca'] ?? 'Desconhecido',
            'modelo': value['modelo'] ?? 'Desconhecido',
            'cor': value['cor'] ?? 'Desconhecido',
            'ano': value['ano'] ?? 'Desconhecido',
            'em_movimento': value['em_movimento'] ?? false,
            'latitude': value['latitude'],
            'longitude': value['longitude'],
            'motorista_id': value['motorista_id'] ?? '',
          });
        });
        setState(() {
          _vehicles = tempVehicles;
        });
      }
    });
  }

  void _fetchDrivers() {
    _driverRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        Map<String, String> tempDrivers = {};
        data.forEach((key, value) {
          tempDrivers[key] = value['nome'] ?? 'Desconhecido';
        });
        setState(() {
          _drivers = tempDrivers;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veículos'),
        automaticallyImplyLeading: false,
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.handyman),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AddMaintenanceDialog(vehicles: _vehicles);
                },
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = _vehicles[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Card(
              color: Colors.white,
              child: ListTile(
                title: Text(
                  '${vehicle['marca']} ${vehicle['modelo']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cor: ${vehicle['cor']} | Ano: ${vehicle['ano']}'),
                    Text(
                        'Motorista: ${_drivers[vehicle['motorista_id']] ?? 'Não vinculado'}'),
                    Text('Em uso: ${vehicle['em_movimento'] ? 'Sim' : 'Não'}'),
                    vehicle['em_movimento']
                        ? const Icon(Icons.directions_run, color: Colors.red)
                        : const Icon(Icons.directions_car, color: Colors.green),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleMapPage(
                          latitude: vehicle['latitude'],
                          longitude: vehicle['longitude'],
                          title: '${vehicle['marca']} ${vehicle['modelo']}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddVehiclePage(drivers: _drivers)),
          );
        },
      ),
    );
  }
}

class VehicleMapPage extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String title;

  const VehicleMapPage(
      {super.key,
      required this.latitude,
      required this.longitude,
      required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: MarkerId(title),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(title: title),
          ),
        },
      ),
    );
  }
}

class AddVehiclePage extends StatefulWidget {
  final Map<String, String> drivers;

  const AddVehiclePage({super.key, required this.drivers});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('vehicles');
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  CommonMethods commonMethods = CommonMethods();
  String? _selectedDriver;

  bool validateForm() {
    if (_plateController.text.isEmpty) {
      commonMethods.displaySnackBar(context, 'Placa é obrigatória');
      return false;
    }
    if (_modelController.text.isEmpty) {
      commonMethods.displaySnackBar(context, 'Modelo é obrigatório');
      return false;
    }
    if (_brandController.text.isEmpty) {
      commonMethods.displaySnackBar(context, 'Marca é obrigatória');
      return false;
    }
    if (_colorController.text.isEmpty) {
      commonMethods.displaySnackBar(context, 'Cor é obrigatória');
      return false;
    }
    if (_yearController.text.isEmpty) {
      commonMethods.displaySnackBar(context, 'Ano é obrigatório');
      return false;
    }
    if (_selectedDriver == null) {
      commonMethods.displaySnackBar(context, 'Motorista é obrigatório');
      return false;
    }
    return true;
  }

  void _saveVehicle() {
    if (validateForm()) {
      String id = _plateController.text.toUpperCase();
      _dbRef.child(id).set({
        'placa': _plateController.text.toUpperCase(),
        'modelo': _modelController.text,
        'marca': _brandController.text,
        'cor': _colorController.text,
        'ano': _yearController.text,
        'em_movimento': false,
        'motorista_id': _selectedDriver,
        'latitude': 2.833125,
        'longitude': -60.6952925,
        'velocidade': 0.0,
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Veículo'), toolbarHeight: 40),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          spacing: 8,
          children: [
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(labelText: 'Placa'),
              textCapitalization: TextCapitalization.characters,
            ),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: 'Modelo'),
            ),
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Marca'),
            ),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(labelText: 'Cor'),
            ),
            TextField(
              controller: _yearController,
              decoration: const InputDecoration(labelText: 'Ano'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: _selectedDriver,
              items: widget.drivers.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDriver = value;
                });
              },
              decoration:
                  const InputDecoration(labelText: 'Selecionar Motorista'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveVehicle,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddMaintenanceDialog extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles;

  const AddMaintenanceDialog({super.key, required this.vehicles});

  @override
  State<AddMaintenanceDialog> createState() => _AddMaintenanceDialogState();
}

class _AddMaintenanceDialogState extends State<AddMaintenanceDialog> {
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  CommonMethods commonMethods = CommonMethods();
  String? _selectedVehicle;

  void _saveMaintenance() {
    if (_selectedVehicle != null &&
        _startDateController.text.isNotEmpty &&
        _endDateController.text.isNotEmpty &&
        _costController.text.isNotEmpty) {
      DatabaseReference maintenanceRef =
          FirebaseDatabase.instance.ref().child('maintenance');
      String id = maintenanceRef.push().key ?? '';
      maintenanceRef.child(id).set({
        'vehicle_id': _selectedVehicle,
        'start_date': _startDateController.text,
        'end_date': _endDateController.text,
        'cost': double.parse(_costController.text),
      });
      commonMethods.displaySnackBar(context, 'Manutenção cadastrada');
      Navigator.pop(context);
    } else {
      commonMethods.displaySnackBar(
          context, 'Todos os campos são obrigatórios');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Cadastrar Manutenção',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      content: Column(
        spacing: 8,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _startDateController,
            decoration: const InputDecoration(
              labelText: 'Data de Início',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2050),
              );
              if (pickedDate != null) {
                setState(() {
                  _startDateController.text =
                      DateFormat('dd/MM/yyyy').format(pickedDate);
                });
              }
            },
          ),
          TextField(
            controller: _endDateController,
            decoration: const InputDecoration(
              labelText: 'Data de Fim',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2050),
              );
              if (pickedDate != null) {
                setState(() {
                  _endDateController.text =
                      DateFormat('dd/MM/yyyy').format(pickedDate);
                });
              }
            },
          ),
          TextField(
            controller: _costController,
            decoration: const InputDecoration(labelText: 'Valor Cobrado'),
            keyboardType: TextInputType.number,
          ),
          DropdownButtonFormField<String>(
            value: _selectedVehicle,
            items: widget.vehicles.map((vehicle) {
              return DropdownMenuItem<String>(
                value: vehicle['id'],
                child: Text('${vehicle['marca']} ${vehicle['modelo']}'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedVehicle = value;
              });
            },
            decoration: const InputDecoration(labelText: 'Selecionar Veículo'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _saveMaintenance,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
