import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/admin/interfaz/asistencias_resultados_screen.dart';

class AsistenciasEstudiantesScreen extends StatefulWidget {
  const AsistenciasEstudiantesScreen({super.key});

  @override
  State<AsistenciasEstudiantesScreen> createState() =>
      _AsistenciasEstudiantesScreenState();
}

class _AsistenciasEstudiantesScreenState
    extends State<AsistenciasEstudiantesScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variables de control
  bool _isLoadingFiltros = true;
  String? _currentUserType;

  // Variables para filtros
  List<String> _facultades = [];
  List<String> _carreras = [];
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;

  // Controladores de animación
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _inicializarAnimaciones();
    _inicializar();
  }

  void _inicializarAnimaciones() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _getCurrentUserType();
    if (_currentUserType == PrefsHelper.userTypeAdmin ||
        _currentUserType == PrefsHelper.userTypeAsistente) {
      await _cargarFiltros();
    }
  }

  Future<void> _getCurrentUserType() async {
    try {
      final userType = await PrefsHelper.getUserType();
      setState(() {
        _currentUserType = userType;
      });
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
  }

  Future<void> _cargarFiltros() async {
    setState(() {
      _isLoadingFiltros = true;
    });

    try {
      print('🔍 Cargando filtros desde nueva estructura...');

      Set<String> facultadesSet = {};
      Set<String> carrerasSet = {};

      // Obtener todas las carreras (documentos en 'users')
      final carrerasSnapshot = await _firestore.collection('users').get();

      print('📂 Total documentos en users: ${carrerasSnapshot.docs.length}');

      for (var carreraDoc in carrerasSnapshot.docs) {
        final carreraName = carreraDoc.id;

        // Saltar documentos que no son carreras
        if (carreraName == 'admin' ||
            carreraName == 'asistente' ||
            carreraName == 'jurado') {
          continue;
        }

        print('🔍 Procesando carrera: $carreraName');

        try {
          // Obtener estudiantes de esta carrera
          final studentsSnapshot = await _firestore
              .collection('users')
              .doc(carreraName)
              .collection('students')
              .get();

          print(
            '   📊 Estudiantes encontrados: ${studentsSnapshot.docs.length}',
          );

          for (var doc in studentsSnapshot.docs) {
            final data = doc.data();

            // ✅ Agregar facultad (normalizada)
            if (data['facultad'] != null &&
                data['facultad'].toString().isNotEmpty) {
              final facultad = data['facultad'].toString().trim();
              facultadesSet.add(facultad);
              print('   ✅ Facultad: $facultad');
            }

            // ✅ Agregar carrera
            if (data['carrera'] != null &&
                data['carrera'].toString().isNotEmpty) {
              final carrera = data['carrera'].toString().trim();
              carrerasSet.add(carrera);
              print('   ✅ Carrera: $carrera');
            }
          }
        } catch (e) {
          print('   ⚠️ Error procesando $carreraName: $e');
        }
      }

      setState(() {
        _facultades = facultadesSet.toList()..sort();
        _carreras = carrerasSet.toList()..sort();
      });

      print('✅ Filtros cargados:');
      print('   Facultades: ${_facultades.join(", ")}');
      print('   Carreras: ${_carreras.join(", ")}');

      _showSnackBar(
        'Filtros cargados: ${_facultades.length} facultades, ${_carreras.length} carreras',
      );
    } catch (e) {
      _showSnackBar('Error cargando filtros: $e', isError: true);
      print('❌ Error detallado: $e');
    } finally {
      setState(() {
        _isLoadingFiltros = false;
      });
    }
  }

  Future<void> _verAsistencias() async {
    if (_facultadSeleccionada == null || _carreraSeleccionada == null) {
      _showSnackBar('Debes seleccionar facultad y carrera', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AsistenciasResultadosScreen(
          facultad: _facultadSeleccionada!,
          carrera: _carreraSeleccionada!,
        ),
      ),
    );
  }

  Future<void> _actualizarCarreras(String? facultad) async {
    if (facultad == null) {
      setState(() {
        _carreras.clear();
        _carreraSeleccionada = null;
      });
      return;
    }

    try {
      print('🔍 Buscando carreras para facultad: $facultad');

      Set<String> carrerasSet = {};

      // Obtener todas las carreras (documentos en 'users')
      final carrerasSnapshot = await _firestore.collection('users').get();

      for (var carreraDoc in carrerasSnapshot.docs) {
        final carreraName = carreraDoc.id;

        // Saltar documentos que no son carreras
        if (carreraName == 'admin' ||
            carreraName == 'asistente' ||
            carreraName == 'jurado') {
          continue;
        }

        try {
          // Obtener estudiantes de esta carrera que pertenezcan a la facultad
          final studentsSnapshot = await _firestore
              .collection('users')
              .doc(carreraName)
              .collection('students')
              .get();

          for (var doc in studentsSnapshot.docs) {
            final data = doc.data();
            final facultadEstudiante =
                data['facultad']?.toString().trim() ?? '';

            // ✅ Comparación más flexible para UPeU
            bool perteneceFacultad = false;

            if (facultadEstudiante == facultad) {
              perteneceFacultad = true;
            }

            // Caso especial para UPeU
            if (facultad == 'Universidad Peruana Unión' &&
                (facultadEstudiante == 'Universidad Peruana Unión' ||
                    facultadEstudiante.contains('UPeU'))) {
              perteneceFacultad = true;
            }

            if (perteneceFacultad) {
              final carrera = data['carrera']?.toString().trim();
              if (carrera != null && carrera.isNotEmpty) {
                carrerasSet.add(carrera);
                print(
                  '   ✅ Carrera encontrada: $carrera (Estudiante: ${data['name']})',
                );
              }
            }
          }
        } catch (e) {
          print('   ⚠️ Error en $carreraName: $e');
        }
      }

      setState(() {
        _carreras = carrerasSet.toList()..sort();
        _carreraSeleccionada = null;
      });

      print('✅ Carreras actualizadas: ${_carreras.join(", ")}');
    } catch (e) {
      print('❌ Error actualizando carreras: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF1E3A5F),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildAnimatedInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutBack,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Opacity(opacity: animValue, child: child),
        );
      },
      child: Card(
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  color: Color(0xFF1E3A5F),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltrosCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Card(
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.filter_list,
                          color: Color(0xFF1E3A5F),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Filtros de Búsqueda',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildAnimatedDropdown(
                    value: _facultadSeleccionada,
                    label: 'Facultad',
                    icon: Icons.account_balance,
                    items: _facultades,
                    onChanged: (value) {
                      setState(() {
                        _facultadSeleccionada = value;
                      });
                      _actualizarCarreras(value);
                    },
                    delay: 200,
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedDropdown(
                    value: _carreraSeleccionada,
                    label: 'Carrera',
                    icon: Icons.school,
                    items: _carreras,
                    onChanged: (value) {
                      setState(() {
                        _carreraSeleccionada = value;
                      });
                    },
                    delay: 400,
                  ),
                  const SizedBox(height: 24),
                  _buildAnimatedButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F), size: 22),
            hintText: 'Selecciona $label',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFF1E3A5F),
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutBack,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.scale(scale: animValue, child: child),
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _verAsistencias,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A5F),
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.visibility, size: 22),
              SizedBox(width: 10),
              Text(
                'Ver Asistencias',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserType != PrefsHelper.userTypeAdmin &&
        _currentUserType != PrefsHelper.userTypeAsistente) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E3A5F),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Color(0xFF1E3A5F),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Asistencias',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EDF2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock,
                                size: 50,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Acceso Denegado',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Solo administradores y asistentes\npueden acceder a los reportes',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.school,
                          color: Color(0xFF1E3A5F),
                          size: 30,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Asistencias de Estudiantes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _cargarFiltros,
                    tooltip: 'Actualizar filtros',
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _isLoadingFiltros
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E3A5F),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Info cards animadas
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnimatedInfoCard(
                                    icon: Icons.account_balance,
                                    title: 'Facultades',
                                    value: '${_facultades.length}',
                                    color: const Color(0xFF1E3A5F),
                                    delay: 0,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnimatedInfoCard(
                                    icon: Icons.school,
                                    title: 'Carreras',
                                    value: '${_carreras.length}',
                                    color: const Color(0xFF1E3A5F),
                                    delay: 200,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildFiltrosCard(),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
