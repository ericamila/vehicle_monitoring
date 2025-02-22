import 'package:flutter/material.dart';
import 'package:vehicle_monitoring/pages/vehicle_list_page.dart';

import 'dashboard.dart';
import 'driver_list_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Monitoramento de Veículos'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Dashboard"),
              Tab(icon: Icon(Icons.person), text: "Motoristas"),
              Tab(icon: Icon(Icons.directions_car), text: "Veículos"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Dashboard(),
            DriverListPage(),
            VehicleListPage(),
          ],
        ),
      ),
    );
  }
}