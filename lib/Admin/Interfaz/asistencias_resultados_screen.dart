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

  bool _isLoading = true;
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
      duration: const Duration(milliseconds: 800),
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
    _headerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar estudiantes
      final estudiantesSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'student')
          .where('facultad', isEqualTo: widget.facultad)
          .where('carrera', isEqualTo: widget.carrera)
          .get();

      List<Map<String, dynamic>> estudiantesList = [];
      List<String> estudiantesIds = [];
      Set<String> ciclos = {};
      Set<String> grupos = {};

      for (var doc in estudiantesSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        estudiantesList.add(data);
        estudiantesIds.add(doc.id);

        if (data['ciclo'] != null && data['ciclo'].toString().isNotEmpty) {
          ciclos.add(data['ciclo'].toString());
        }
        if (data['grupo'] != null && data['grupo'].toString().isNotEmpty) {
          grupos.add(data['grupo'].toString());
        }
      }

      setState(() {
        _estudiantes = estudiantesList;
        _ciclosDisponibles = ciclos.toList()..sort();
        _gruposDisponibles = grupos.toList()..sort();
      });

      if (estudiantesIds.isNotEmpty) {
        await _cargarAsistenciasEstudiantes(estudiantesIds);
      }

      _aplicarFiltros();
    } catch (e) {
      _showSnackBar('Error cargando datos: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarAsistenciasEstudiantes(
    List<String> estudiantesIds,
  ) async {
    try {
      List<Map<String, dynamic>> todasAsistencias = [];

      for (int i = 0; i < estudiantesIds.length; i += 10) {
        final batch = estudiantesIds.skip(i).take(10).toList();

        final asistenciasSnapshot = await _firestore
            .collection('asistencias')
            .where('studentId', whereIn: batch)
            .orderBy('timestamp', descending: true)
            .get();

        for (var doc in asistenciasSnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          todasAsistencias.add(data);
        }
      }

      Map<String, List<Map<String, dynamic>>> asistenciasPorEstudiante = {};

      for (var asistencia in todasAsistencias) {
        final studentId = asistencia['studentId'];
        if (!asistenciasPorEstudiante.containsKey(studentId)) {
          asistenciasPorEstudiante[studentId] = [];
        }
        asistenciasPorEstudiante[studentId]!.add(asistencia);
      }

      setState(() {
        _asistenciasPorEstudiante = asistenciasPorEstudiante;
      });
    } catch (e) {
      print('Error cargando asistencias: $e');
    }
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_estudiantes);

    if (_cicloSeleccionado != null) {
      resultado = resultado.where((e) {
        return e['ciclo']?.toString() == _cicloSeleccionado;
      }).toList();
    }

    if (_grupoSeleccionado != null) {
      resultado = resultado.where((e) {
        return e['grupo']?.toString() == _grupoSeleccionado;
      }).toList();
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

    setState(() {
      _estudiantesFiltrados = resultado;
    });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF1E3A5F),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      _showSnackBar('Error al generar reporte: $e', isError: true);
    }
  }

  Color _getColorByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return Colors.grey;
    final hash = categoria.hashCode;
    final colors = [
      const Color(0xFF1E3A5F),
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getIniciales(String nombre) {
    if (nombre.isEmpty) return '?';
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre[0].toUpperCase();
  }

  Widget _buildFiltrosSection() {
    final hayFiltrosActivos =
        _cicloSeleccionado != null ||
        _grupoSeleccionado != null ||
        _searchTerm.isNotEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.filter_list,
                      color: Color(0xFF1E3A5F),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const Spacer(),
                  if (hayFiltrosActivos)
                    AnimatedScale(
                      scale: hayFiltrosActivos ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: TextButton.icon(
                        onPressed: _limpiarFiltros,
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Limpiar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          backgroundColor: Colors.red.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Barra de búsqueda
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, DNI o código...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF1E3A5F),
                  ),
                  suffixIcon: _searchTerm.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchTerm = '';
                            });
                            _aplicarFiltros();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchTerm = value;
                  });
                  _aplicarFiltros();
                },
              ),
              const SizedBox(height: 16),

              // Filtros de ciclo y grupo
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _cicloSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Ciclo',
                        labelStyle: const TextStyle(color: Color(0xFF1E3A5F)),
                        prefixIcon: const Icon(
                          Icons.school,
                          color: Color(0xFF1E3A5F),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos los ciclos'),
                        ),
                        ..._ciclosDisponibles.map((ciclo) {
                          return DropdownMenuItem(
                            value: ciclo,
                            child: Text('Ciclo $ciclo'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _cicloSeleccionado = value;
                        });
                        _aplicarFiltros();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _grupoSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Grupo',
                        labelStyle: const TextStyle(color: Color(0xFF1E3A5F)),
                        prefixIcon: const Icon(
                          Icons.group,
                          color: Color(0xFF1E3A5F),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos los grupos'),
                        ),
                        ..._gruposDisponibles.map((grupo) {
                          return DropdownMenuItem(
                            value: grupo,
                            child: Text('Grupo $grupo'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _grupoSeleccionado = value;
                        });
                        _aplicarFiltros();
                      },
                    ),
                  ),
                ],
              ),

              // Chips de filtros activos
              if (hayFiltrosActivos) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_cicloSeleccionado != null)
                      _buildFilterChip(
                        label: 'Ciclo $_cicloSeleccionado',
                        color: const Color(0xFF1E3A5F),
                        onDeleted: () {
                          setState(() {
                            _cicloSeleccionado = null;
                          });
                          _aplicarFiltros();
                        },
                      ),
                    if (_grupoSeleccionado != null)
                      _buildFilterChip(
                        label: 'Grupo $_grupoSeleccionado',
                        color: Colors.green,
                        onDeleted: () {
                          setState(() {
                            _grupoSeleccionado = null;
                          });
                          _aplicarFiltros();
                        },
                      ),
                    if (_searchTerm.isNotEmpty)
                      _buildFilterChip(
                        label: 'Búsqueda: "$_searchTerm"',
                        color: Colors.orange,
                        onDeleted: () {
                          _searchController.clear();
                          setState(() {
                            _searchTerm = '';
                          });
                          _aplicarFiltros();
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color color,
    required VoidCallback onDeleted,
  }) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
        onDeleted: onDeleted,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildEstudianteCard(
    Map<String, dynamic> estudiante,
    List<Map<String, dynamic>> asistencias,
    int index,
  ) {
    final estudianteId = estudiante['id'];
    final isExpanded = _estudiantesExpandidos.contains(estudianteId);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        elevation: 3,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Hero(
                      tag: 'avatar_$estudianteId',
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF1E3A5F),
                        child: Text(
                          _getIniciales(estudiante['name'] ?? ''),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            estudiante['name'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (estudiante['ciclo'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A5F),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'C${estudiante['ciclo']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (estudiante['ciclo'] != null &&
                                  estudiante['grupo'] != null)
                                const SizedBox(width: 6),
                              if (estudiante['grupo'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'G${estudiante['grupo']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (estudiante['username'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Usuario: ${estudiante['username']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: asistencias.isNotEmpty
                              ? [Colors.green, Colors.green.shade700]
                              : [Colors.red, Colors.red.shade700],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (asistencias.isNotEmpty
                                        ? Colors.green
                                        : Colors.red)
                                    .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '${asistencias.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.expand_more,
                        color: const Color(0xFF1E3A5F),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Column(
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: asistencias.isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Asistencias registradas:',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A5F),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ...asistencias.map(
                                      (asistencia) =>
                                          _buildAsistenciaResumen(asistencia),
                                    ),
                                  ],
                                )
                              : Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.red.shade600,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Este estudiante no tiene asistencias registradas',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF1E3A5F),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
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
    final tituloProyecto = asistencia['tituloProyecto'];
    final codigoProyecto = asistencia['codigoProyecto'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _getColorByCategoria(categoria),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asistencia['eventName'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildTag(
                        label: categoria,
                        color: _getColorByCategoria(categoria),
                      ),
                      if (grupo != null &&
                          grupo.toString().trim().isNotEmpty &&
                          grupo.toString().toLowerCase() != 'sin grupo')
                        _buildTag(
                          label: 'Grupo $grupo',
                          color: const Color(0xFF17A5A1),
                          icon: Icons.group,
                        ),
                      if (codigoProyecto != null &&
                          codigoProyecto.toString().isNotEmpty)
                        _buildTag(
                          label: codigoProyecto,
                          color: Colors.purple.shade600,
                          icon: Icons.tag,
                        ),
                      if (timestamp != null)
                        _buildTag(
                          label:
                              '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                          color: const Color(0xFF64748B),
                        ),
                    ],
                  ),
                  if (tituloProyecto != null &&
                      tituloProyecto.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.article,
                            size: 16,
                            color: Colors.indigo.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tituloProyecto,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.indigo.shade900,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            // Header animado
            FadeTransition(
              opacity: _headerAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(_headerAnimation),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school,
                          color: Color(0xFF1E3A5F),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Asistencias de Estudiantes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${widget.facultad} - ${widget.carrera}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: _isLoading ? null : _descargarReporte,
                          tooltip: 'Descargar Reporte Excel',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: _cargarDatos,
                          tooltip: 'Actualizar',
                        ),
                      ),
                    ],
                  ),
                ),
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
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF1E3A5F),
                              ),
                              strokeWidth: 4,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Cargando estudiantes...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF1E3A5F),
                                fontWeight: FontWeight.w600,
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
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: child,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.search_off,
                                  size: 80,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No se encontraron estudiantes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Intenta con otros filtros',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sección de filtros
                            _buildFiltrosSection(),

                            // Contador de resultados
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1E3A5F,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.people,
                                      color: Color(0xFF1E3A5F),
                                      size: 24,
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
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${_estudiantesFiltrados.length}',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E3A5F),
                                              ),
                                            ),
                                            if (_estudiantesFiltrados.length !=
                                                _estudiantes.length)
                                              Text(
                                                ' de ${_estudiantes.length}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Lista de estudiantes
                            _estudiantesFiltrados.isEmpty
                                ? Card(
                                    elevation: 3,
                                    shadowColor: Colors.black26,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(40.0),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF1E3A5F,
                                              ).withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.filter_alt_off,
                                              size: 64,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Text(
                                            'No hay resultados',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A5F),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Intenta ajustar los filtros',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _estudiantesFiltrados.length,
                                    itemBuilder: (context, index) {
                                      final estudiante =
                                          _estudiantesFiltrados[index];
                                      final asistencias =
                                          _asistenciasPorEstudiante[estudiante['id']] ??
                                          [];
                                      return _buildEstudianteCard(
                                        estudiante,
                                        asistencias,
                                        index,
                                      );
                                    },
                                  ),
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
