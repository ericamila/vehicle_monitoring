import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class CommonMethods {
  checkConnection(BuildContext context) async {
    var connectivityResult = await (Connectivity().checkConnectivity());

    if (connectivityResult != ConnectivityResult.mobile &&
        connectivityResult != ConnectivityResult.wifi) {
      if (!context.mounted) return;
      displaySnackBar(context, 'Sem conexão com a internet');
    }
  }

  displaySnackBar(BuildContext context, String s) {
    var snackbar = SnackBar(content: Text(s));
    ScaffoldMessenger.of(context).showSnackBar(snackbar);
  }
}
