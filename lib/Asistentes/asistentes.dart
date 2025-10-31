import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import '/login.dart';
import '/admin/interfaz/generar_qr_screen.dart';

class AsistentesScreen extends StatefulWidget {
  const AsistentesScreen({super.key});

  @override
  State<AsistentesScreen> createState() => _AsistentesScreenState();
}

class _AsistentesScreenState extends State<AsistentesScreen> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userName = await PrefsHelper.getUserName();
    setState(() {
      _userName = userName ?? 'Asistente';
    });
  }

  Future<void> _logout() async {
    // Eliminamos el diálogo de aquí porque ya existe uno en GenerarQRScreen
    await PrefsHelper.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mostrar directamente la pantalla de generar QR con el botón de logout
      body: GenerarQRScreen(logoutCallback: _logout),
    );
  }
}
