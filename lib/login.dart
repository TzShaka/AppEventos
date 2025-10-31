import 'package:flutter/material.dart';
import 'dart:async';
import '/prefs_helper.dart';
import '/Admin/logica/admin.dart';
import '/usuarios/logica/estudiante.dart';
import '/Asistentes/asistentes.dart';
import '/Jurados/jurados.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _currentBackgroundIndex = 0;
  Timer? _backgroundTimer;
  bool _imageLoaded = false; // ✅ NUEVO

  final List<String> _backgrounds = [
    'assets/images/fondo01.png',
    'assets/images/fondo02.png',
    'assets/images/fondo03.png',
  ];

  @override
  void initState() {
    super.initState();
    _startBackgroundRotation();
    _precacheImages(); // ✅ NUEVO - Precachear imágenes
  }

  // ✅ NUEVO - Método para precachear imágenes
  Future<void> _precacheImages() async {
    try {
      await precacheImage(const AssetImage('assets/images/logo.png'), context);
      for (var bg in _backgrounds) {
        await precacheImage(AssetImage(bg), context);
      }
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    } catch (e) {
      print('Error precaching images: $e');
      // Si falla, igual continuar
      if (mounted) {
        setState(() {
          _imageLoaded = true;
        });
      }
    }
  }

  void _startBackgroundRotation() {
    _backgroundTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentBackgroundIndex =
              (_currentBackgroundIndex + 1) % _backgrounds.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_userController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage('Por favor, completa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool success = false;
    String? loggedInUserType;

    try {
      final username = _userController.text.trim();
      final password = _passwordController.text;

      // Primero intentar login como admin/asistente predefinidos
      if (username == PrefsHelper.adminEmail ||
          username == PrefsHelper.asistenteEmail) {
        success = await PrefsHelper.loginAdmin(username, password);
        if (success) {
          loggedInUserType = await PrefsHelper.getUserType();
        }
      }
      // Si no es admin/asistente, intentar como jurado
      else {
        success = await PrefsHelper.loginJurado(username, password);
        if (success) {
          loggedInUserType = await PrefsHelper.getUserType();
        } else {
          // Si no es jurado, intentar como estudiante
          success = await PrefsHelper.loginStudent(username, password);
          if (success) {
            loggedInUserType = await PrefsHelper.getUserType();
          }
        }
      }

      if (success && loggedInUserType != null) {
        // Navegar según el tipo de usuario
        if (loggedInUserType == PrefsHelper.userTypeAdmin) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AdminScreen()),
            );
          }
        } else if (loggedInUserType == PrefsHelper.userTypeAsistente) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AsistentesScreen()),
            );
          }
        } else if (loggedInUserType == PrefsHelper.userTypeJurado) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const JuradosScreen()),
            );
          }
        } else if (loggedInUserType == PrefsHelper.userTypeStudent) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const EstudianteScreen()),
            );
          }
        }
      } else {
        _showMessage('Usuario o contraseña incorrectos');
      }
    } catch (e) {
      _showMessage('Error al iniciar sesión: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A5490),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Mostrar loading mientras cargan las imágenes
    if (!_imageLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: Container(
              key: ValueKey<int>(_currentBackgroundIndex),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_backgrounds[_currentBackgroundIndex]),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),

          // Contenido
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 80),

                  // Logo UPeU - ✅ Ahora precacheado
                  Image.asset(
                    'assets/images/logo.png',
                    height: 180,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.school,
                        size: 180,
                        color: Colors.white,
                      );
                    },
                  ),

                  const SizedBox(height: 120),

                  // Card de login
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Campo usuario
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _userController,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Usuario',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF1A5490),
                                size: 24,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Campo contraseña
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Contraseña',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF1A5490),
                                size: 24,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF1A5490),
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Botón de login
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A5490),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              disabledBackgroundColor: Colors.grey[400],
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Ingresar',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
