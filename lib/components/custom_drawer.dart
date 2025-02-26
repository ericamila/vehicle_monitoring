import 'package:flutter/material.dart';

import '../pages/about.dart';
import '../pages/report_page.dart';

Drawer customDrawer(BuildContext context) => Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF138275),
            ),
            child:
            Image.asset('assets/images/final.png'),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_outlined),
            title: const Text('Relatório'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Sobre'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const About()));
            },
          ),

        ],
      ),
    );
