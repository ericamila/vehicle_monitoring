import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DriverListPage extends StatefulWidget {
  const DriverListPage({super.key});

  @override
  State<DriverListPage> createState() => _DriverListPageState();
}

class _DriverListPageState extends State<DriverListPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('drivers');
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  void _fetchDrivers() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        List<Map<String, dynamic>> tempDrivers = [];
        data.forEach((key, value) {
          tempDrivers.add({
            'id': key,
            'nome': value['nome'] ?? 'Desconhecido',
            'telefone': value['telefone'] ?? 'Não informado',
            'foto': value['foto'] ?? '',
            'veiculo': value['veiculo'] ?? 'Nenhum veículo',
          });
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
      body: ListView.builder(
        itemCount: _drivers.length,
        itemBuilder: (context, index) {
          final driver = _drivers[index];
          return ListTile(
            leading: driver['foto'].isNotEmpty
                ? CircleAvatar(backgroundImage: NetworkImage(driver['foto']))
                : const CircleAvatar(child: Icon(Icons.person)),
            title: Text(driver['nome']),
            subtitle: Text('Telefone: ${driver['telefone']}\nVeículo: ${driver['veiculo']}'),
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
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('drivers');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _photoUrl;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _photoUrl = pickedFile.path; // verificar Firebase Storage
      });
    }
  }

  void _saveDriver() {
    String id = _dbRef.push().key ?? '';
    _dbRef.child(id).set({
      'nome': _nameController.text,
      'telefone': _phoneController.text,
      'foto': _photoUrl ?? '',
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Motorista')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                child: _photoUrl == null ? const Icon(Icons.camera_alt) : null,
              ),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
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