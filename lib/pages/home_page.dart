import 'package:flutter/material.dart';
import 'package:vehicle_monitoring/pages/route_registration_page.dart';
import 'package:vehicle_monitoring/pages/vehicle_list_page.dart';

import '../components/custom_drawer.dart';
import 'dashboard.dart';
import 'driver_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      //initialIndex: 2, /// APAGAR ESSA LINHA
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Monitoramento de Veículos'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Dashboard"),
              Tab(icon: Icon(Icons.person), text: "Motoristas"),
              Tab(icon: Icon(Icons.directions_car), text: "Veículos"),
              Tab(icon: Icon(Icons.route), text: "Viagens"),
            ],
          ),
        ),
        drawer: customDrawer(context),
        body: const TabBarView(
          children: [
            Dashboard(),
            DriverListPage(),
            VehicleListPage(),
            RouteRegistrationPage(),
          ],
        ),
      ),
    );
  }
}
