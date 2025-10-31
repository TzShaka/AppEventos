import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'crear_jurados.dart';
import 'criterios.dart';
import 'jurados_criterios.dart';

class EditarNotasScreen extends StatefulWidget {
  const EditarNotasScreen({super.key});

  @override
  State<EditarNotasScreen> createState() => _EditarNotasScreenState();
}

class _EditarNotasScreenState extends State<EditarNotasScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selección de filtros
  String? _facultadSeleccionada;
  String? _carreraSeleccionada;
  String? _categoriaSeleccionada;

  // Listas dinámicas
  List<String> _facultades = [];
  List<String> _carrerasDisponibles = [];
  List<String> _categoriasDisponibles = [];
  String? _juradoSeleccionado;
  Map<String, dynamic>? _juradoData;
  List<Map<String, dynamic>> _juradosDisponibles = [];

  List<Map<String, dynamic>> _proyectosDisponibles = [];
  Set<String> _gruposSeleccionados = {};

  bool _isLoadingJurados = false;
  bool _isLoadingProyectos = false;
  bool _isLoadingCategorias = false;
  bool _gruposExpandido = false;

  // Cache de datos
  Map<String, Set<String>> _carrerasPorFacultad = {};

  @override
  void initState() {
    super.initState();
    _cargarFacultades();
  }

  Future<void> _cargarFacultades() async {
    try {
      final eventsSnapshot = await _firestore.collection('events').get();

      final Set<String> facultadesSet = {};
      final Map<String, Set<String>> carrerasMap = {};

      for (var doc in eventsSnapshot.docs) {
        final data = doc.data();
        final facultad = data['facultad'] as String?;
        final carrera = data['carrera'] as String?;

        if (facultad != null && facultad.isNotEmpty) {
          facultadesSet.add(facultad);

          if (carrera != null && carrera.isNotEmpty) {
            if (!carrerasMap.containsKey(facultad)) {
              carrerasMap[facultad] = {};
            }
            carrerasMap[facultad]!.add(carrera);
          }
        }
      }

      if (mounted) {
        setState(() {
          _facultades = facultadesSet.toList()..sort();
          _carrerasPorFacultad = carrerasMap;
        });
      }
    } catch (e) {
      print('Error al cargar facultades: $e');
    }
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _facultadSeleccionada = facultad;
      _carreraSeleccionada = null;
      _categoriaSeleccionada = null;
      _categoriasDisponibles = [];
      _juradoSeleccionado = null;
      _juradoData = null;
      _gruposSeleccionados.clear();
      _proyectosDisponibles.clear();

      if (facultad != null && _carrerasPorFacultad.containsKey(facultad)) {
        _carrerasDisponibles = _carrerasPorFacultad[facultad]!.toList()..sort();
      } else {
        _carrerasDisponibles = [];
      }
    });
  }

  Future<void> _onCarreraChanged(String? carrera) async {
    setState(() {
      _carreraSeleccionada = carrera;
      _categoriaSeleccionada = null;
      _categoriasDisponibles = [];
      _juradoSeleccionado = null;
      _juradoData = null;
      _gruposSeleccionados.clear();
      _proyectosDisponibles.clear();
      _isLoadingCategorias = true;
    });

    if (carrera == null || _facultadSeleccionada == null) {
      setState(() => _isLoadingCategorias = false);
      return;
    }

    try {
      final eventsSnapshot = await _firestore
          .collection('events')
          .where('facultad', isEqualTo: _facultadSeleccionada)
          .where('carrera', isEqualTo: carrera)
          .get();

      final Set<String> categoriasSet = {};

      for (var eventDoc in eventsSnapshot.docs) {
        final proyectosSnapshot = await _firestore
            .collection('events')
            .doc(eventDoc.id)
            .collection('proyectos')
            .get();

        for (var proyectoDoc in proyectosSnapshot.docs) {
          final data = proyectoDoc.data();
          final clasificacion = data['Clasificación'] as String?;

          if (clasificacion != null && clasificacion.isNotEmpty) {
            categoriasSet.add(clasificacion);
          }
        }
      }

      if (mounted) {
        setState(() {
          _categoriasDisponibles = categoriasSet.toList()..sort();
          _isLoadingCategorias = false;
        });

        if (categoriasSet.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay proyectos registrados para esta carrera'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error al cargar categorías: $e');
      if (mounted) {
        setState(() => _isLoadingCategorias = false);
      }
    }
  }

  void _onCategoriaChanged(String? categoria) {
    setState(() {
      _categoriaSeleccionada = categoria;
      _juradoSeleccionado = null;
      _juradoData = null;
      _gruposSeleccionados.clear();
      _proyectosDisponibles.clear();
    });

    if (categoria != null) {
      _cargarJurados();
      _cargarProyectosCategoria();
    }
  }

  Future<void> _cargarProyectosCategoria() async {
    if (_facultadSeleccionada == null ||
        _carreraSeleccionada == null ||
        _categoriaSeleccionada == null) {
      return;
    }

    setState(() {
      _gruposSeleccionados.clear();
      _proyectosDisponibles.clear();
      _isLoadingProyectos = true;
    });

    try {
      final eventsSnapshot = await _firestore
          .collection('events')
          .where('facultad', isEqualTo: _facultadSeleccionada)
          .where('carrera', isEqualTo: _carreraSeleccionada)
          .get();

      // Usamos un Map para evitar duplicados por código
      final Map<String, Map<String, dynamic>> proyectosMap = {};

      for (var eventDoc in eventsSnapshot.docs) {
        final proyectosSnapshot = await _firestore
            .collection('events')
            .doc(eventDoc.id)
            .collection('proyectos')
            .where('Clasificación', isEqualTo: _categoriaSeleccionada)
            .get();

        for (var proyectoDoc in proyectosSnapshot.docs) {
          final data = proyectoDoc.data();
          final codigo = data['Código'] ?? '';

          // Solo agregamos si el código no está vacío y no existe ya
          if (codigo.isNotEmpty && !proyectosMap.containsKey(codigo)) {
            proyectosMap[codigo] = {
              'id': proyectoDoc.id,
              'eventId': eventDoc.id,
              'codigo': codigo,
              'titulo': data['Título'] ?? '',
              'integrantes': data['Integrantes'] ?? '',
              'sala': data['Sala'] ?? '',
            };
          }
        }
      }

      if (mounted) {
        setState(() {
          // Convertimos el Map a List y ordenamos por código
          _proyectosDisponibles = proyectosMap.values.toList()
            ..sort(
              (a, b) =>
                  (a['codigo'] as String).compareTo(b['codigo'] as String),
            );
          _isLoadingProyectos = false;
        });
      }
    } catch (e) {
      print('Error al cargar proyectos: $e');
      if (mounted) {
        setState(() => _isLoadingProyectos = false);
      }
    }
  }

  Future<void> _cargarJurados() async {
    if (_facultadSeleccionada == null ||
        _carreraSeleccionada == null ||
        _categoriaSeleccionada == null) {
      return;
    }

    setState(() {
      _isLoadingJurados = true;
      _juradosDisponibles = [];
      _juradoSeleccionado = null;
      _juradoData = null;
    });

    try {
      final juradosSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'jurado')
          .where('facultad', isEqualTo: _facultadSeleccionada)
          .where('carrera', isEqualTo: _carreraSeleccionada)
          .where('categoria', isEqualTo: _categoriaSeleccionada)
          .get();

      final List<Map<String, dynamic>> jurados = [];

      for (var doc in juradosSnapshot.docs) {
        final data = doc.data();
        jurados.add({
          'id': doc.id,
          'nombre': data['name'] ?? '',
          'usuario': data['usuario'] ?? '',
          'categoria': data['categoria'] ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _juradosDisponibles = jurados;
          _isLoadingJurados = false;
        });

        if (jurados.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay jurados disponibles para esta categoría'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error al cargar jurados: $e');
      if (mounted) {
        setState(() => _isLoadingJurados = false);
      }
    }
  }

  bool get _puedeCrearCriterios {
    return _facultadSeleccionada != null &&
        _carreraSeleccionada != null &&
        _categoriaSeleccionada != null &&
        _juradoSeleccionado != null &&
        _gruposSeleccionados.isNotEmpty;
  }

  void _irACrearCriterios() {
    if (!_puedeCrearCriterios) {
      String mensaje = 'Complete todos los filtros:';
      List<String> faltantes = [];

      if (_facultadSeleccionada == null) faltantes.add('Facultad');
      if (_carreraSeleccionada == null) faltantes.add('Carrera');
      if (_categoriaSeleccionada == null) faltantes.add('Categoría');
      if (_juradoSeleccionado == null) faltantes.add('Jurado');
      if (_gruposSeleccionados.isEmpty) faltantes.add('Grupos a evaluar');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$mensaje\n${faltantes.join(', ')}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Navegar a la pantalla de criterios
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CriteriosScreen(
          facultad: _facultadSeleccionada!,
          carrera: _carreraSeleccionada!,
          categoria: _categoriaSeleccionada!,
          juradoId: _juradoSeleccionado!,
          juradoData: _juradoData!,
          gruposSeleccionados: _gruposSeleccionados.toList(),
          proyectos: _proyectosDisponibles,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Regresar',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Configurar Evaluación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CrearJuradosScreen(),
                        ),
                      );
                    },
                    tooltip: 'Crear Jurados',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.assignment_ind,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const JuradosCriteriosScreen(),
                        ),
                      );
                    },
                    tooltip: 'Ver Jurados con Grupos',
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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card de Filtros Principales
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ámbito de Evaluación',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Facultad
                                DropdownButtonFormField<String>(
                                  value: _facultadSeleccionada,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Facultad',
                                    prefixIcon: const Icon(Icons.school),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: _facultades.map((facultad) {
                                    return DropdownMenuItem(
                                      value: facultad,
                                      child: Text(facultad),
                                    );
                                  }).toList(),
                                  onChanged: _onFacultadChanged,
                                ),
                                const SizedBox(height: 16),

                                // Carrera
                                DropdownButtonFormField<String>(
                                  value: _carreraSeleccionada,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Carrera',
                                    prefixIcon: const Icon(Icons.book),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: _carrerasDisponibles.map((carrera) {
                                    return DropdownMenuItem(
                                      value: carrera,
                                      child: Text(carrera),
                                    );
                                  }).toList(),
                                  onChanged: _facultadSeleccionada == null
                                      ? null
                                      : _onCarreraChanged,
                                ),
                                const SizedBox(height: 16),

                                // Categoría
                                DropdownButtonFormField<String>(
                                  value: _categoriaSeleccionada,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Categoría / Proyecto',
                                    prefixIcon: const Icon(Icons.category),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: _categoriasDisponibles.map((
                                    categoria,
                                  ) {
                                    return DropdownMenuItem(
                                      value: categoria,
                                      child: Text(categoria),
                                    );
                                  }).toList(),
                                  onChanged: _categoriasDisponibles.isEmpty
                                      ? null
                                      : _onCategoriaChanged,
                                ),

                                if (_isLoadingCategorias)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Cargando categorías...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Card de Jurado
                        if (_categoriaSeleccionada != null) ...[
                          const SizedBox(height: 16),
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Jurado Evaluador',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  DropdownButtonFormField<String>(
                                    value: _juradoSeleccionado,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Seleccione un jurado',
                                      prefixIcon: const Icon(Icons.person),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: _juradosDisponibles.map((jurado) {
                                      return DropdownMenuItem<String>(
                                        value: jurado['id'] as String,
                                        child: Text(jurado['nombre'] as String),
                                      );
                                    }).toList(),
                                    onChanged: _juradosDisponibles.isEmpty
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _juradoSeleccionado = value;
                                              _juradoData = _juradosDisponibles
                                                  .firstWhere(
                                                    (j) => j['id'] == value,
                                                  );
                                            });
                                          },
                                  ),

                                  if (_isLoadingJurados)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Cargando jurados...',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (_juradoData != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF4CAF50),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF4CAF50),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _juradoData!['nombre'],
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Usuario: ${_juradoData!['usuario']}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Card de Grupos a Evaluar
                        if (_juradoSeleccionado != null) ...[
                          const SizedBox(height: 16),
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header clickeable
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _gruposExpandido = !_gruposExpandido;
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          _gruposExpandido
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: const Color(0xFF1E3A5F),
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Grupos a Evaluar',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A5F),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${_gruposSeleccionados.length} seleccionados',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Contenido expandible
                                  if (_gruposExpandido) ...[
                                    const SizedBox(height: 16),
                                    if (_isLoadingProyectos)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else if (_proyectosDisponibles.isEmpty)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: Text(
                                            'No hay proyectos disponibles',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _proyectosDisponibles.length,
                                        itemBuilder: (context, index) {
                                          final proyecto =
                                              _proyectosDisponibles[index];
                                          final codigo =
                                              proyecto['codigo'] as String;
                                          final isSelected =
                                              _gruposSeleccionados.contains(
                                                codigo,
                                              );

                                          return CheckboxListTile(
                                            value: isSelected,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  _gruposSeleccionados.add(
                                                    codigo,
                                                  );
                                                } else {
                                                  _gruposSeleccionados.remove(
                                                    codigo,
                                                  );
                                                }
                                              });
                                            },
                                            title: Text(
                                              proyecto['titulo'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Código: $codigo',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                if ((proyecto['integrantes']
                                                        as String)
                                                    .isNotEmpty)
                                                  Text(
                                                    'Integrantes: ${proyecto['integrantes']}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            activeColor: const Color(
                                              0xFF1E3A5F,
                                            ),
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                          );
                                        },
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Botón Crear Criterios
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _puedeCrearCriterios
                                ? _irACrearCriterios
                                : null,
                            icon: const Icon(Icons.add_task, size: 24),
                            label: const Text(
                              'Crear Criterios de Evaluación',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[500],
                              elevation: _puedeCrearCriterios ? 4 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
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
}
