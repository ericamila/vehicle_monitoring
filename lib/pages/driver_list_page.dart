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
  List<Map<dynamic, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  void _fetchDrivers() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _drivers =
              data.entries.map((e) => {"key": e.key, ...e.value}).toList();
        });
      }
    });
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
      body: ListView.builder(
        itemCount: _drivers.length,
        itemBuilder: (context, index) {
          final driver = _drivers[index];
          return ListTile(
            leading: driver['foto'] != null && driver['foto'] != ''
                ? CircleAvatar(backgroundImage: NetworkImage(driver['foto']))
                : CircleAvatar(
                    foregroundColor: Colors.green[100],
                    backgroundColor: Colors.green[800],
                    child: const Icon(Icons.person),
                  ),
            title: Text(driver['nome'] ?? 'Sem nome'),
            subtitle: Text(
                'Telefone: ${driver['telefone'] ?? 'Sem telefone'}\nVeículo: ${driver['veiculo']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editDriver(driver)),
                IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteDriver(driver['key'])),
              ],
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
                backgroundImage:
                    _photoUrl != null ? NetworkImage(_photoUrl!) : null,
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
