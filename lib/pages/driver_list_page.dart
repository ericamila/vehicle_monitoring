import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DriverListPage extends StatefulWidget {
  const DriverListPage({super.key});

  @override
  State<DriverListPage> createState() => _DriverListPageState();
}

class _DriverListPageState extends State<DriverListPage> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('drivers');
  final DatabaseReference _dbRefVeicle =
      FirebaseDatabase.instance.ref().child('vehicles');
  List<Map<dynamic, dynamic>> _drivers = [];
  //List<Map<dynamic, dynamic>> _movingVehicles = [];
  //int sensorValue = 0;
  List<int> _sensorValues = [];
  StreamSubscription? _sensorSubscription;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
    //_fetchMovingVehicles();
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    super.dispose();
  }

  void _fetchDrivers() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _drivers =
              data.entries.map((e) => {"key": e.key, ...e.value}).toList();
          _extractSensorValue();
        });
      }
    });
  }

/*  void _extractSensorValue() {
    for (var driver in _drivers) {
      if (driver['key'] == '-OJf_KbUSZCRGYoeZEMO') {
        final driverData = driver['8b89ae2'];
        if (driverData != null && driverData['sensor_ad8232'] != null) {
          sensorValue = driverData['sensor_ad8232'] as int;
          return; // Encontrou o valor, pode sair do loop
        }
      }
    }
  }*/

  void _extractSensorValue() {
    for (var driver in _drivers) {
      if (driver['key'] == '-OJf_KbUSZCRGYoeZEMO') {
        final driverData = driver['8b89ae2'];
        if (driverData != null && driverData['sensor_ad8232'] != null) {
          int newValue = driverData['sensor_ad8232'] as int;
          if (_sensorValues.length >= 3) {
            _sensorValues.removeAt(0);
          }
          _sensorValues.add(newValue);
          return;
        }
      }
    }
  }
/*
  void _fetchMovingVehicles() {
    _dbRefVeicle.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _movingVehicles = data.entries
              .where((e) => e.value['em_movimento'] == true)
              .map((e) => {"key": e.key, ...e.value})
              .toList();
        });
      }
    });
  }*/

  void _showSensorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            _sensorSubscription = _dbRef.onValue.listen((event) {
              final data = event.snapshot.value as Map<dynamic, dynamic>?;
              if (data != null) {
                _extractSensorValue();
                setState(() {});
              }
            });

            return AlertDialog(
              title: const Text('Valor Atual do Sensor'),
              content: Text(
                _sensorValues.isNotEmpty ? '${_sensorValues.last} bpm' : 'N/A',
                style: const TextStyle(fontSize: 24),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _sensorSubscription?.cancel();
                    Navigator.pop(context);
                  },
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteDriver(String key) {
    _dbRef.child(key).remove();
  }

  void _editDriver(Map driver) {
    TextEditingController nameController =
        TextEditingController(text: driver['name']);
    TextEditingController phoneController =
        TextEditingController(text: driver['phone']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Motorista'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Telefone'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                _dbRef.child(driver['key']).update({
                  'name': nameController.text,
                  'phone': phoneController.text,
                });
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Motoristas'), toolbarHeight: 40, automaticallyImplyLeading: false),
      body: ListView.builder(
        itemCount: _drivers.length,
        itemBuilder: (context, index) {
          final driver = _drivers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Card(
              color: Colors.white,
              child: ListTile(
                leading: driver['foto'] != null && driver['foto'] != ''
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(driver['foto']),
                        backgroundColor: Colors.blueGrey,
                        radius: 30,
                      )
                    : const CircleAvatar(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.person),
                      ),
                title: Text(
                  driver['nome'] ?? 'Sem nome',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: GestureDetector(
                  onTap: _showSensorDialog,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Telefone: ${driver['telefone'] ?? 'Sem telefone'}\nVeículo: ${driver['veiculo'] ?? '🚘'}'),
                      Text('Tag RFID: ${driver['tag_rfid']}\nBatimentos Cardíacos: ${_sensorValues.isNotEmpty ? _sensorValues.last : 'N/A'} bpm'),
                      Text('Bloqueado: ${(driver['blocked'] == true) ? 'Verdadeiro' : 'Falso'}'),
                    ],
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  color: Colors.white70,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editDriver(driver);
                    } else if (value == 'delete') {
                      _deleteDriver(driver['key']);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Editar'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Excluir'),
                      ),
                    ),
                  ],
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
            MaterialPageRoute(builder: (context) => const AddDriverPage()),
          );
        },
      ),
    );
  }
}

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('drivers');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  String? _photoUrl;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _photoUrl = pickedFile.path;
      });
    }
  }

  void _saveDriver() {
    String id = _dbRef.push().key ?? '';
    _dbRef.child(id).set({
      'nome': _nameController.text,
      'telefone': _phoneController.text,
      'foto': _photoUrl ?? '',
      'tag_rfid': _tagController.text,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Adicionar Motorista'), toolbarHeight: 40),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          spacing: 8,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                child: _photoUrl == null ? const Icon(Icons.camera_alt) : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _tagController,
              decoration: const InputDecoration(labelText: 'Tag RFID'),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveDriver,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
