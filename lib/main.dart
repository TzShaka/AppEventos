import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:convert';
import 'firebase_options.dart';
import '/login.dart';
import '/admin/logica/admin.dart';
import '/usuarios/logica/estudiante.dart';
import '/Asistentes/asistentes.dart';
import '/Jurados/jurados.dart'; // ✅ AGREGADO
import '/prefs_helper.dart';

void main() async {
  // Asegurar que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _linkSubscription;
  String? _pendingDeepLink;
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  // Inicializar listener de deep links - USANDO APP_LINKS
  void _initDeepLinkListener() {
    // Manejar deep link cuando la app ya está abierta
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('Deep link recibido: ${uri.toString()}');
        _handleDeepLink(uri.toString());
      },
      onError: (err) {
        print('Error en deep link: $err');
      },
    );

    // Manejar deep link cuando la app se abre por primera vez
    _handleInitialLink();
  }

  // Manejar deep link inicial (cuando la app se abre desde cerrada)
  Future<void> _handleInitialLink() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        print('Deep link inicial: ${initialUri.toString()}');
        _pendingDeepLink = initialUri.toString();
      }
    } catch (e) {
      print('Error obteniendo deep link inicial: $e');
    }
  }

  // Procesar el deep link
  void _handleDeepLink(String link) {
    try {
      final uri = Uri.parse(link);

      if (uri.scheme == 'myapp' && uri.host == 'asistencia') {
        final String? encodedData = uri.queryParameters['data'];

        if (encodedData != null) {
          try {
            // Decodificar los datos
            final String decodedData = Uri.decodeComponent(encodedData);
            final Map<String, dynamic> qrData = jsonDecode(decodedData);

            print('Datos del QR decodificados: $qrData');

            // Navegar a la pantalla de asistencia
            _navigateToAsistencia(qrData);
          } catch (e) {
            print('Error decodificando datos del QR: $e');
            _showErrorDialog('Error', 'Código QR inválido o dañado');
          }
        } else {
          print('No se encontraron datos en el deep link');
          _showErrorDialog('Error', 'Enlace inválido');
        }
      } else {
        print('Deep link no reconocido: $link');
      }
    } catch (e) {
      print('Error procesando deep link: $e');
      _showErrorDialog('Error', 'Error al procesar el enlace');
    }
  }

  // Navegar a la pantalla de asistencia
  void _navigateToAsistencia(Map<String, dynamic> qrData) {
    // Verificar si el usuario está logueado
    PrefsHelper.isLoggedIn().then((isLoggedIn) {
      if (!isLoggedIn) {
        // Si no está logueado, guardar los datos y redirigir al login
        _pendingDeepLink = null; // Limpiar pending link
        _showErrorDialog(
          'Sesión requerida',
          'Necesitas iniciar sesión para registrar tu asistencia',
        );
        return;
      }

      // Verificar tipo de usuario
      PrefsHelper.getUserType().then((userType) {
        if (userType != PrefsHelper.userTypeStudent) {
          _showErrorDialog(
            'Acceso denegado',
            'Solo los estudiantes pueden registrar asistencia',
          );
          return;
        }

        // Navegar a la pantalla de registro de asistencia
        navigatorKey.currentState?.pushNamed(
          '/registro-asistencia',
          arguments: qrData,
        );
      });
    });
  }

  // Mostrar dialog de error
  void _showErrorDialog(String title, String message) {
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Eventos',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Agregar soporte para localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés (fallback)
      ],
      locale: const Locale('es', 'ES'),

      // Rutas de la aplicación - ACTUALIZADAS
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin': (context) => const AdminScreen(),
        '/estudiante': (context) => const EstudianteScreen(),
        '/asistente': (context) => const AsistentesScreen(),
        '/jurado': (context) => const JuradosScreen(), // ✅ AGREGADO
        '/registro-asistencia': (context) => RegistroAsistenciaScreen(
          qrData:
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?,
        ),
      },

      home: AuthWrapper(pendingDeepLink: _pendingDeepLink),
    );
  }
}

// Widget que verifica si hay sesión activa - ACTUALIZADO ✅
class AuthWrapper extends StatefulWidget {
  final String? pendingDeepLink;

  const AuthWrapper({super.key, this.pendingDeepLink});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Procesar deep link pendiente después de que se complete la autenticación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingDeepLink();
    });
  }

  void _processPendingDeepLink() {
    if (widget.pendingDeepLink != null) {
      // Usar el contexto de MyApp para procesar el deep link
      final myAppState = context.findAncestorStateOfType<_MyAppState>();
      myAppState?._handleDeepLink(widget.pendingDeepLink!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuthStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Inicializando...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          // Hay sesión activa, verificar tipo de usuario
          return FutureBuilder<String?>(
            future: PrefsHelper.getUserType(),
            builder: (context, userTypeSnapshot) {
              if (userTypeSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Verificando usuario...'),
                      ],
                    ),
                  ),
                );
              }

              final userType = userTypeSnapshot.data;
              print('🔍 UserType detectado en AuthWrapper: $userType'); // ✅ LOG

              if (userType == PrefsHelper.userTypeAdmin) {
                return const AdminScreen();
              } else if (userType == PrefsHelper.userTypeAsistente) {
                return const AsistentesScreen();
              } else if (userType == PrefsHelper.userTypeJurado) {
                // ✅ AGREGADO SOPORTE PARA JURADO
                print('✅ Navegando a JuradosScreen');
                return const JuradosScreen();
              } else if (userType == PrefsHelper.userTypeStudent) {
                return const EstudianteScreen();
              } else {
                // Tipo de usuario desconocido, cerrar sesión
                print('❌ Tipo de usuario desconocido: $userType');
                PrefsHelper.logout();
                return const LoginScreen();
              }
            },
          );
        }

        // No hay sesión activa
        return const LoginScreen();
      },
    );
  }

  Future<bool> _checkAuthStatus() async {
    try {
      final isLoggedIn = await PrefsHelper.isLoggedIn();
      print('🔍 Estado de sesión: $isLoggedIn');
      return isLoggedIn;
    } catch (e) {
      print('Error verificando estado de autenticación: $e');
      return false;
    }
  }
}

// Pantalla para registrar asistencia (placeholder - debes implementarla)
class RegistroAsistenciaScreen extends StatefulWidget {
  final Map<String, dynamic>? qrData;

  const RegistroAsistenciaScreen({super.key, this.qrData});

  @override
  State<RegistroAsistenciaScreen> createState() =>
      _RegistroAsistenciaScreenState();
}

class _RegistroAsistenciaScreenState extends State<RegistroAsistenciaScreen> {
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    if (widget.qrData != null) {
      _processAsistencia();
    }
  }

  void _processAsistencia() async {
    setState(() {
      _isRegistering = true;
    });

    try {
      // Aquí implementa la lógica para registrar la asistencia
      // Usar widget.qrData para obtener la información del evento

      await Future.delayed(const Duration(seconds: 2)); // Simulación

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Asistencia registrada exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );

        // Regresar a la pantalla anterior después de un breve delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error registrando asistencia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.qrData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No se recibieron datos del QR')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Asistencia'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRegistering) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Registrando asistencia...'),
            ] else ...[
              const Icon(Icons.event_available, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              Text(
                'Evento: ${widget.qrData!['eventName'] ?? 'Sin nombre'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text('Facultad: ${widget.qrData!['facultad'] ?? 'N/A'}'),
              Text('Carrera: ${widget.qrData!['carrera'] ?? 'N/A'}'),
              Text('Tipo: ${widget.qrData!['tipoInvestigacion'] ?? 'N/A'}'),
            ],
          ],
        ),
      ),
    );
  }
}
