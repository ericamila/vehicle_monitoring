import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _maintenance = [];


  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Buscar veículos
      final vehiclesSnapshot = await _database.child("vehicles").get();
      final driversSnapshot = await _database.child("drivers").get();
      final routesSnapshot = await _database.child("routes").get();
      final maintenanceSnapshot = await _database.child("maintenance").get();

      if (vehiclesSnapshot.exists) {
        _vehicles = (vehiclesSnapshot.value as Map).entries.map((entry) {
          Map<String, dynamic> data = Map<String, dynamic>.from(entry.value);
          data['id'] = entry.key;
          return data;
        }).toList();
      }

      if (driversSnapshot.exists) {
        _drivers = (driversSnapshot.value as Map).entries.map((entry) {
          Map<String, dynamic> data = Map<String, dynamic>.from(entry.value);
          data['id'] = entry.key;
          return data;
        }).toList();
      }

      if (routesSnapshot.exists) {
        _routes = (routesSnapshot.value as Map).entries.map((entry) {
          Map<String, dynamic> data = Map<String, dynamic>.from(entry.value);
          data['id'] = entry.key;
          return data;
        }).toList();
      }

      if (maintenanceSnapshot.exists) {
        _maintenance = (maintenanceSnapshot.value as Map).entries.map((entry) {
          Map<String, dynamic> data = Map<String, dynamic>.from(entry.value);
          data['id'] = entry.key;
          return data;
        }).toList();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Erro ao buscar dados: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Relatório de Veículos, Rotas e Manutenção',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Seção de veículos
              pw.Text("Veículos", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              ..._vehicles.map((vehicle) => pw.Text(
                "Marca: ${vehicle['marca']} | Modelo: ${vehicle['modelo']} | Ano: ${vehicle['ano']} | Cor: ${vehicle['cor']}",
                style: const pw.TextStyle(fontSize: 14),
              )),
              pw.SizedBox(height: 10),

              // Seção de motoristas
              pw.Text("Motoristas", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              ..._drivers.map((driver) => pw.Text(
                "Nome: ${driver['nome']} | Telefone: ${driver['telefone']} | RFID: ${driver['tag_rfid']} | Sensor Cardíaco: ${driver['sensor_ad8232']} bpm",
                style: const pw.TextStyle(fontSize: 14),
              )),
              pw.SizedBox(height: 10),

              // Seção de rotas
              pw.Text("Rotas", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              ..._routes.map((route) => pw.Text(
                "Origem: (${route['origin_lat']}, ${route['origin_lng']}) → Destino: (${route['destination_lat']}, ${route['destination_lng']}) | Tempo Estimado: ${route['estimated_travel_time']} min | Combustível: ${route['fuel_consumption']}L",
                style: const pw.TextStyle(fontSize: 14),
              )),
              pw.SizedBox(height: 10),

              // Seção de manutenção
              pw.Text("Manutenção", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              ..._maintenance.map((maintenance) => pw.Text(
                "Veículo ID: ${maintenance['vehicle_id']} | Custo: R\$${maintenance['cost']} | Início: ${maintenance['start_date']} | Fim: ${maintenance['end_date']}",
                style: const pw.TextStyle(fontSize: 14),
              )),
              pw.SizedBox(height: 20),

              // Rodapé
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Gerado em: $formattedDate',
                  style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Relatório de veículos e rotas disponível!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generatePdf,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white,),
              label: const Text('Gerar Relatório PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
