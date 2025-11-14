import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'asistencias_excel.dart';

class AsistenciasResultadosScreen extends StatefulWidget {
  final String facultad;
  final String carrera;

  const AsistenciasResultadosScreen({
    super.key,
    required this.facultad,
    required this.carrera,
  });

  @override
  State<AsistenciasResultadosScreen> createState() =>
      _AsistenciasResultadosScreenState();
}

class _AsistenciasResultadosScreenState
    extends State<AsistenciasResultadosScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingAsistencias = false;
  List<Map<String, dynamic>> _estudiantes = [];
  List<Map<String, dynamic>> _estudiantesFiltrados = [];
  Map<String, List<Map<String, dynamic>>> _asistenciasPorEstudiante = {};
  Set<String> _estudiantesExpandidos = {};

  // Filtros
  String? _cicloSeleccionado;
  String? _grupoSeleccionado;
  String _searchTerm = '';

  List<String> _ciclosDisponibles = [];
  List<String> _gruposDisponibles = [];

  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    );
    _headerAnimationController.forward();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // CARGA DE DATOS OPTIMIZADA
  // ═══════════════════════════════════════════════════════════════
  Future<void> _cargarDatos() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isLoadingAsistencias = false;
    });

    try {
      // Cargar estudiantes primero (más rápido)
      await _cargarEstudiantes();

      // Cargar asistencias en segundo plano
      if (_estudiantes.isNotEmpty && mounted) {
        setState(() {
          _isLoadingAsistencias = true;
        });

        final estudiantesIds = _estudiantes
            .map((e) => e['id'] as String)
            .toList();
        await _cargarAsistenciasEstudiantes(estudiantesIds);

        if (mounted) {
          setState(() {
            _isLoadingAsistencias = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error cargando datos: $e');
      if (mounted) {
        _showSnackBar('Error cargando datos', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingAsistencias = false;
        });
      }
    }
  }

  Future<void> _cargarEstudiantes() async {
    try {
      debugPrint(
        '🔍 Cargando estudiantes de ${widget.facultad} - ${widget.carrera}',
      );

      final List<Map<String, dynamic>> estudiantesList = [];
      final Set<String> ciclos = {};
      final Set<String> grupos = {};

      // Obtener carreras
      final carrerasSnapshot = await _firestore.collection('users').get();

      for (var carreraDoc in carrerasSnapshot.docs) {
        final carreraName = carreraDoc.id;

        // Saltar documentos especiales
        if (carreraName == 'admin' ||
            carreraName == 'asistente' ||
            carreraName == 'jurado') {
          continue;
        }

        try {
          // ✅ BÚSQUEDA CON WHERE COMO EN TU VERSIÓN ORIGINAL
          Query query = _firestore
              .collection('users')
              .doc(carreraName)
              .collection('students');

          // Aplicar filtro de carrera
          query = query.where('carrera', isEqualTo: widget.carrera);

          // Aplicar filtro de facultad
          query = query.where('facultad', isEqualTo: widget.facultad);

          final studentsSnapshot = await query.get();

          debugPrint(
            '📂 Carrera $carreraName: ${studentsSnapshot.docs.length} estudiantes encontrados',
          );

          for (var doc in studentsSnapshot.docs) {
            final data = Map<String, dynamic>.from(
              doc.data() as Map<String, dynamic>,
            );
            data['id'] = '$carreraName/${doc.id}';
            data['docId'] = doc.id;
            data['carreraPath'] = carreraName;

            estudiantesList.add(data);  

            // Recopilar ciclos y grupos
            final ciclo = data['ciclo']?.toString();
            final grupo = data['grupo']?.toString();

            if (ciclo != null && ciclo.isNotEmpty) ciclos.add(ciclo);
            if (grupo != null && grupo.isNotEmpty) grupos.add(grupo);

            debugPrint(
              '   ✅ ${data['name']} - C${ciclo ?? '?'} G${grupo ?? '?'}',
            );
          }
        } catch (e) {
          debugPrint('⚠️ Error en $carreraName: $e');
        }
      }

      debugPrint('✅ Total estudiantes cargados: ${estudiantesList.length}');

      if (mounted) {
        setState(() {
          _estudiantes = estudiantesList;
          _ciclosDisponibles = ciclos.toList()..sort();
          _gruposDisponibles = grupos.toList()..sort();
        });
        _aplicarFiltros();
      }
    } catch (e) {
      debugPrint('❌ Error cargando estudiantes: $e');
      rethrow;
    }
  }

  Future<void> _cargarAsistenciasEstudiantes(
    List<String> estudiantesIds,
  ) async {
    try {
      debugPrint(
        '🔍 Cargando asistencias para ${estudiantesIds.length} estudiantes',
      );

      final Map<String, List<Map<String, dynamic>>> asistenciasPorEstudiante =
          {};

      // Obtener todos los eventos
      final eventosSnapshot = await _firestore.collection('events').get();

      // ✅ CARGAR EN PARALELO: Crear lista de futures
      final List<Future<void>> cargaFutures = [];

      for (var eventDoc in eventosSnapshot.docs) {
        for (var estudianteId in estudiantesIds) {
          cargaFutures.add(
            _cargarAsistenciaEstudianteEvento(
              estudianteId,
              eventDoc,
              asistenciasPorEstudiante,
            ),
          );
        }
      }

      // Ejecutar todas las consultas en paralelo
      await Future.wait(cargaFutures);

      debugPrint(
        '✅ Asistencias cargadas: ${asistenciasPorEstudiante.length} estudiantes',
      );

      if (mounted) {
        setState(() {
          _asistenciasPorEstudiante = asistenciasPorEstudiante;
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando asistencias: $e');
    }
  }

  Future<void> _cargarAsistenciaEstudianteEvento(
    String estudianteId,
    DocumentSnapshot eventDoc,
    Map<String, List<Map<String, dynamic>>> asistenciasPorEstudiante,
  ) async {
    try {
      final parts = estudianteId.split('/');
      if (parts.length != 2) return;

      final studentId = parts[1];
      final eventId = eventDoc.id;
      final eventData = eventDoc.data() as Map<String, dynamic>;

      final scansSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('asistencias')
          .doc(studentId)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .get();

      for (var scanDoc in scansSnapshot.docs) {
        final scanData = scanDoc.data();

        if (scanData['timestamp'] == null) continue;

        final asistencia = {
          'id': scanDoc.id,
          'timestamp': scanData['timestamp'],
          'categoria': scanData['categoria'] ?? 'Sin categoría',
          'tipoInvestigacion': scanData['categoria'] ?? 'Sin categoría',
          'codigoProyecto': scanData['codigoProyecto'] ?? 'Sin código',
          'tituloProyecto': scanData['tituloProyecto'] ?? 'Sin título',
          'grupo': scanData['grupo'],
          'qrId': scanData['qrId'],
          'registrationMethod': scanData['registrationMethod'] ?? 'qr_scan',
          'eventId': eventId,
          'eventName': eventData['name'] ?? 'Sin nombre',
          'eventDescription': eventData['description'] ?? '',
          'eventDate': eventData['date'],
          'eventFacultad': eventData['facultad'] ?? '',
          'eventCarrera': eventData['carrera'] ?? '',
        };

        asistenciasPorEstudiante.putIfAbsent(estudianteId, () => []);
        asistenciasPorEstudiante[estudianteId]!.add(asistencia);
      }
    } catch (e) {
      debugPrint(
        '⚠️ Error en evento ${eventDoc.id} para estudiante $estudianteId: $e',
      );
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_estudiantes);

    if (_cicloSeleccionado != null) {
      resultado = resultado
          .where((e) => e['ciclo']?.toString() == _cicloSeleccionado)
          .toList();
    }

    if (_grupoSeleccionado != null) {
      resultado = resultado
          .where((e) => e['grupo']?.toString() == _grupoSeleccionado)
          .toList();
    }

    if (_searchTerm.isNotEmpty) {
      final searchLower = _searchTerm.toLowerCase();
      resultado = resultado.where((e) {
        final nombre = (e['name'] ?? '').toString().toLowerCase();
        final dni = (e['dni'] ?? '').toString().toLowerCase();
        final codigo = (e['codigoUniversitario'] ?? '')
            .toString()
            .toLowerCase();
        final username = (e['username'] ?? '').toString().toLowerCase();

        return nombre.contains(searchLower) ||
            dni.contains(searchLower) ||
            codigo.contains(searchLower) ||
            username.contains(searchLower);
      }).toList();
    }

    // ORDENAR: Primero los que tienen asistencias, luego los que no
    resultado.sort((a, b) {
      final asistenciasA = _asistenciasPorEstudiante[a['id']]?.length ?? 0;
      final asistenciasB = _asistenciasPorEstudiante[b['id']]?.length ?? 0;

      if (asistenciasA == 0 && asistenciasB > 0) return 1;
      if (asistenciasA > 0 && asistenciasB == 0) return -1;

      // Si ambos tienen o no tienen asistencias, ordenar por cantidad descendente
      return asistenciasB.compareTo(asistenciasA);
    });

    if (mounted) {
      setState(() {
        _estudiantesFiltrados = resultado;
      });
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _cicloSeleccionado = null;
      _grupoSeleccionado = null;
      _searchTerm = '';
      _searchController.clear();
    });
    _aplicarFiltros();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade600
            : const Color(0xFF1E3A5F),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _descargarReporte() async {
    try {
      _showSnackBar('Generando reporte...');

      await AsistenciasExcel.generarReporteExcel(
        estudiantes: _estudiantesFiltrados,
        asistenciasPorEstudiante: _asistenciasPorEstudiante,
        facultad: widget.facultad,
        carrera: widget.carrera,
      );

      _showSnackBar('Reporte generado exitosamente');
    } catch (e) {
      _showSnackBar('Error al generar reporte', isError: true);
    }
  }

  Color _getColorByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return Colors.grey.shade400;

    final colors = [
      const Color(0xFF1E3A5F),
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.pink.shade600,
      Colors.amber.shade700,
      Colors.cyan.shade600,
      Colors.lime.shade700,
    ];

    return colors[categoria.hashCode.abs() % colors.length];
  }

  String _getIniciales(String nombre) {
    if (nombre.isEmpty) return '?';
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre[0].toUpperCase();
  }

  // ═══════════════════════════════════════════════════════════════
  // WIDGETS DE UI
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFiltrosSection() {
    final hayFiltrosActivos =
        _cicloSeleccionado != null ||
        _grupoSeleccionado != null ||
        _searchTerm.isNotEmpty;

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Color(0xFF1E3A5F),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                if (hayFiltrosActivos)
                  TextButton.icon(
                    onPressed: _limpiarFiltros,
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text(
                      'Limpiar',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Barra de búsqueda
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, DNI o código...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF1E3A5F),
                  size: 18,
                ),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchTerm = '');
                          _aplicarFiltros();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (value) {
                setState(() => _searchTerm = value);
                _aplicarFiltros();
              },
            ),
            const SizedBox(height: 12),

            // Filtros de ciclo y grupo
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _cicloSeleccionado,
                    decoration: InputDecoration(
                      labelText: 'Ciclo',
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.school,
                        color: Color(0xFF1E3A5F),
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos', style: TextStyle(fontSize: 13)),
                      ),
                      ..._ciclosDisponibles.map((ciclo) {
                        return DropdownMenuItem(
                          value: ciclo,
                          child: Text(
                            'C$ciclo',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _cicloSeleccionado = value);
                      _aplicarFiltros();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _grupoSeleccionado,
                    decoration: InputDecoration(
                      labelText: 'Grupo',
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.group,
                        color: Color(0xFF1E3A5F),
                        size: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos', style: TextStyle(fontSize: 13)),
                      ),
                      ..._gruposDisponibles.map((grupo) {
                        return DropdownMenuItem(
                          value: grupo,
                          child: Text(
                            'G$grupo',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _grupoSeleccionado = value);
                      _aplicarFiltros();
                    },
                  ),
                ),
              ],
            ),

            // Chips de filtros activos
            if (hayFiltrosActivos) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (_cicloSeleccionado != null)
                    _buildFilterChip(
                      label: 'Ciclo $_cicloSeleccionado',
                      color: const Color(0xFF1E3A5F),
                      onDeleted: () {
                        setState(() => _cicloSeleccionado = null);
                        _aplicarFiltros();
                      },
                    ),
                  if (_grupoSeleccionado != null)
                    _buildFilterChip(
                      label: 'Grupo $_grupoSeleccionado',
                      color: Colors.green.shade600,
                      onDeleted: () {
                        setState(() => _grupoSeleccionado = null);
                        _aplicarFiltros();
                      },
                    ),
                  if (_searchTerm.isNotEmpty)
                    _buildFilterChip(
                      label: 'Búsqueda: "$_searchTerm"',
                      color: Colors.orange.shade600,
                      onDeleted: () {
                        _searchController.clear();
                        setState(() => _searchTerm = '');
                        _aplicarFiltros();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color color,
    required VoidCallback onDeleted,
  }) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
      onDeleted: onDeleted,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildEstudianteCard(
    Map<String, dynamic> estudiante,
    List<Map<String, dynamic>> asistencias,
  ) {
    final estudianteId = estudiante['id'] as String;
    final isExpanded = _estudiantesExpandidos.contains(estudianteId);

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _estudiantesExpandidos.remove(estudianteId);
                } else {
                  _estudiantesExpandidos.add(estudianteId);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1E3A5F),
                    child: Text(
                      _getIniciales(estudiante['name'] ?? ''),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          estudiante['name'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 3,
                          runSpacing: 2,
                          children: [
                            if (estudiante['ciclo'] != null)
                              _buildSmallBadge(
                                'C${estudiante['ciclo']}',
                                const Color(0xFF1E3A5F),
                              ),
                            if (estudiante['grupo'] != null)
                              _buildSmallBadge(
                                'G${estudiante['grupo']}',
                                Colors.green.shade600,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      maxWidth: 40,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: asistencias.isNotEmpty
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${asistencias.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF1E3A5F),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: asistencias.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Asistencias registradas:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...asistencias.map((a) => _buildAsistenciaResumen(a)),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Sin asistencias registradas',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 8,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAsistenciaResumen(Map<String, dynamic> asistencia) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
    final categoria =
        asistencia['categoria'] ??
        asistencia['tipoInvestigacion'] ??
        'Sin categoría';
    final grupo = asistencia['grupo'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: _getColorByCategoria(categoria),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      asistencia['eventName'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildTag(categoria, _getColorByCategoria(categoria)),
                        if (grupo != null && grupo.toString().trim().isNotEmpty)
                          _buildTag('G$grupo', Colors.teal.shade600),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
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
            // Header compacto
            FadeTransition(
              opacity: _headerAnimation,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Color(0xFF1E3A5F),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asistencias',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${widget.facultad} - ${widget.carrera}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _isLoading ? null : _descargarReporte,
                      tooltip: 'Descargar Excel',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _isLoading ? null : _cargarDatos,
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1E3A5F),
                              ),
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Cargando estudiantes...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _estudiantes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No se encontraron estudiantes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Intenta con otros filtros',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  // Sección de filtros
                                  _buildFiltrosSection(),

                                  // Contador de resultados
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF1E3A5F,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.people,
                                            color: Color(0xFF1E3A5F),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Total de estudiantes',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    '${_estudiantesFiltrados.length}',
                                                    style: const TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF1E3A5F),
                                                    ),
                                                  ),
                                                  if (_estudiantesFiltrados
                                                          .length !=
                                                      _estudiantes.length)
                                                    Text(
                                                      ' de ${_estudiantes.length}',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_isLoadingAsistencias)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Color(0xFF1E3A5F),
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),

                          // Lista de estudiantes
                          _estudiantesFiltrados.isEmpty
                              ? SliverFillRemaining(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.filter_alt_off,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No hay resultados',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Intenta ajustar los filtros',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      final estudiante =
                                          _estudiantesFiltrados[index];
                                      final asistencias =
                                          _asistenciasPorEstudiante[estudiante['id']] ??
                                          [];
                                      return _buildEstudianteCard(
                                        estudiante,
                                        asistencias,
                                      );
                                    }, childCount: _estudiantesFiltrados.length),
                                  ),
                                ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
