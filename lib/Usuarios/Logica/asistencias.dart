import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import 'dart:math' as math;

class AsistenciasScreen extends StatefulWidget {
  const AsistenciasScreen({super.key});

  @override
  State<AsistenciasScreen> createState() => _AsistenciasScreenState();
}

class _AsistenciasScreenState extends State<AsistenciasScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;
  String? _currentUserName;
  bool _isLoadingAsistencias = false;
  List<Map<String, dynamic>> _misAsistencias = [];
  List<Map<String, dynamic>> _asistenciasFiltradas = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Variables para el filtro de periodo
  String? _periodoSeleccionado;
  List<String> _periodosDisponibles = [];
  bool _mostrarPeriodos = false;
  String? _eventoSeleccionado;
  List<Map<String, dynamic>> _eventosDisponibles = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _getCurrentUserId();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calcularEventosDisponibles() {
    final Map<String, Map<String, dynamic>> eventosMap = {};

    for (var asistencia in _misAsistencias) {
      final eventId = asistencia['eventId'];
      final eventName = asistencia['eventName'];

      if (eventId != null &&
          eventName != null &&
          eventName != 'Sin nombre' &&
          eventName != 'Evento eliminado') {
        if (!eventosMap.containsKey(eventId)) {
          eventosMap[eventId] = {'id': eventId, 'name': eventName};
        }
      }
    }

    setState(() {
      _eventosDisponibles = eventosMap.values.toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // Si no hay evento seleccionado y hay eventos disponibles, no seleccionar ninguno por defecto
      if (_eventoSeleccionado == null && _eventosDisponibles.isNotEmpty) {
        _eventoSeleccionado = null; // El usuario debe seleccionar manualmente
      }
    });
  }

  // Determinar el periodo académico basado en una fecha
  String _getPeriodoFromDate(DateTime date) {
    final year = date.year;
    final month = date.month;

    // 2025-I: Marzo (3) a Julio (7)
    // 2025-II: Agosto (8) a Diciembre (12)

    if (month >= 3 && month <= 7) {
      return '$year-I';
    } else if (month >= 8 && month <= 12) {
      return '$year-II';
    } else {
      // Para otros meses (enero, febrero), asignar al periodo anterior
      return '${year - 1}-II';
    }
  }

  // Calcular periodos disponibles de las asistencias
  void _calcularPeriodosDisponibles() {
    final Set<String> periodos = {};

    for (var asistencia in _misAsistencias) {
      final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
      if (timestamp != null) {
        periodos.add(_getPeriodoFromDate(timestamp));
      }
    }

    setState(() {
      _periodosDisponibles = periodos.toList()..sort((a, b) => b.compareTo(a));
      // Si no hay periodo seleccionado, seleccionar el más reciente
      if (_periodoSeleccionado == null && _periodosDisponibles.isNotEmpty) {
        _periodoSeleccionado = _periodosDisponibles.first;
      }
    });
  }

  void _filtrarAsistenciasPorPeriodo() {
    setState(() {
      _asistenciasFiltradas = _misAsistencias.where((asistencia) {
        // Filtro por periodo
        bool cumplePeriodo = true;
        if (_periodoSeleccionado != null) {
          final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
          if (timestamp == null) return false;
          cumplePeriodo =
              _getPeriodoFromDate(timestamp) == _periodoSeleccionado;
        }

        // Filtro por evento
        bool cumpleEvento = true;
        if (_eventoSeleccionado != null) {
          cumpleEvento = asistencia['eventId'] == _eventoSeleccionado;
        }

        return cumplePeriodo && cumpleEvento;
      }).toList();
    });
  }

  Future<void> _getCurrentUserId() async {
    try {
      final userId = await PrefsHelper.getCurrentUserId();
      final userName = await PrefsHelper.getUserName();
      if (userId != null) {
        setState(() {
          _currentUserId = userId;
          _currentUserName = userName;
        });
        _cargarMisAsistencias();
      } else {
        _showSnackBar('No se pudo obtener el usuario actual', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error al obtener usuario: $e', isError: true);
    }
  }

  Future<void> _cargarMisAsistencias() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoadingAsistencias = true;
      _misAsistencias.clear();
    });

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('asistencias')
          .where('studentId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> asistenciasList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        if (data['eventName'] != null && data['eventDescription'] != null) {
          asistenciasList.add(data);
        } else if (data['eventId'] != null) {
          try {
            final eventDoc = await _firestore
                .collection('events')
                .doc(data['eventId'])
                .get();

            if (eventDoc.exists) {
              final eventData = eventDoc.data() as Map<String, dynamic>;
              data['eventName'] =
                  data['eventName'] ?? eventData['name'] ?? 'Sin nombre';
              data['eventDescription'] =
                  data['eventDescription'] ?? eventData['description'] ?? '';
              data['eventDate'] = data['eventDate'] ?? eventData['date'];
              data['eventFacultad'] =
                  data['eventFacultad'] ?? eventData['facultad'] ?? '';
              data['eventCarrera'] =
                  data['eventCarrera'] ?? eventData['carrera'] ?? '';
            } else {
              data['eventName'] = 'Evento eliminado';
              data['eventDescription'] = '';
              data['eventDate'] = null;
              data['eventLocation'] = '';
              data['eventFacultad'] = '';
              data['eventCarrera'] = '';
            }
            asistenciasList.add(data);
          } catch (e) {
            print('Error obteniendo datos del evento: $e');
            data['eventName'] = 'Error cargando evento';
            data['eventDescription'] = '';
            asistenciasList.add(data);
          }
        } else {
          data['eventName'] = 'Sin evento';
          data['eventDescription'] = '';
          asistenciasList.add(data);
        }
      }

      setState(() {
        _misAsistencias = asistenciasList;
      });

      _calcularPeriodosDisponibles();
      _calcularEventosDisponibles();
      _filtrarAsistenciasPorPeriodo();

      _showSnackBar('Se cargaron ${_misAsistencias.length} asistencia(s)');
    } catch (e) {
      _showSnackBar('Error al cargar asistencias: $e', isError: true);
      print('Error detallado: $e');
    } finally {
      setState(() {
        _isLoadingAsistencias = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getColorByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return const Color(0xFF5A6C7D);

    final hash = categoria.hashCode;
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFF0891B2),
      const Color(0xFF4F46E5),
      const Color(0xFF6366F1),
      const Color(0xFF0D9488),
      const Color(0xFF1E40AF),
      const Color(0xFF15803D),
    ];
    return colors[hash.abs() % colors.length];
  }

  IconData _getIconByCategoria(String? categoria) {
    if (categoria == null || categoria.isEmpty) return Icons.help;

    final categoriaLower = categoria.toLowerCase();

    if (categoriaLower.contains('revisión') ||
        categoriaLower.contains('revision')) {
      return Icons.library_books;
    } else if (categoriaLower.contains('empírico') ||
        categoriaLower.contains('empirico')) {
      return Icons.science;
    } else if (categoriaLower.contains('innovación') ||
        categoriaLower.contains('innovacion') ||
        categoriaLower.contains('tecnológica') ||
        categoriaLower.contains('tecnologica')) {
      return Icons.lightbulb;
    } else if (categoriaLower.contains('narrativa')) {
      return Icons.auto_stories;
    } else if (categoriaLower.contains('descriptiv')) {
      return Icons.description;
    } else if (categoriaLower.contains('experimental')) {
      return Icons.biotech;
    } else if (categoriaLower.contains('teóric') ||
        categoriaLower.contains('teorico')) {
      return Icons.psychology;
    } else if (categoriaLower.contains('cualitativ')) {
      return Icons.forum;
    } else if (categoriaLower.contains('cuantitativ')) {
      return Icons.analytics;
    } else {
      return Icons.assignment;
    }
  }

  Widget _buildSelloAsistencia(Map<String, dynamic> asistencia) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
    final categoria =
        asistencia['categoria'] ??
        asistencia['tipoInvestigacion'] ??
        'Sin categoría';
    final color = _getColorByCategoria(categoria);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
            color.withOpacity(0.4),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.8), width: 3),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SelloPainter(color: color.withOpacity(0.2)),
            ),
          ),
          Center(
            child: Icon(
              _getIconByCategoria(categoria),
              color: Colors.white,
              size: 22, // Reducido de 24 a 22
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          if (timestamp != null)
            Positioned(
              bottom: 6, // Reducido de 8 a 6
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${timestamp.day}/${timestamp.month}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9, // Reducido de 10 a 9
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0.5, 0.5),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned.fill(child: CustomPaint(painter: TextoCurvadoPainter())),
        ],
      ),
    );
  }

  Widget _buildSelloVacio(int index) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade100,
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: SelloPainter(
                color: Colors.grey.shade300.withOpacity(0.3),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.lock_outline,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroPeriodo() {
    if (_periodosDisponibles.isEmpty && _eventosDisponibles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtro de Periodo
          if (_periodosDisponibles.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Color(0xFF1E3A5F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Filtrar por periodo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _periodosDisponibles
                  .map((periodo) => _buildPeriodoChip(periodo, periodo))
                  .toList(),
            ),
          ],

          // Separador
          if (_periodosDisponibles.isNotEmpty &&
              _eventosDisponibles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 20),
          ],

          // Filtro de Eventos
          if (_eventosDisponibles.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Filtrar por evento',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildEventoDropdown(),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodoChip(String label, String? valor) {
    final isSelected = _periodoSeleccionado == valor;

    return InkWell(
      onTap: () {
        setState(() {
          _periodoSeleccionado = valor;
        });
        _filtrarAsistenciasPorPeriodo();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildEventoDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _eventoSeleccionado != null
              ? const Color(0xFF2563EB)
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _eventoSeleccionado,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Seleccionar evento',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
          ),
          items: _eventosDisponibles.map((evento) {
            return DropdownMenuItem<String>(
              value: evento['id'],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 18, color: const Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        evento['name'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E3A5F),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _eventoSeleccionado = value;
            });
            _filtrarAsistenciasPorPeriodo();
          },
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildColeccionSellos() {
    const int totalSellos = 10; // Total de espacios para sellos

    return AnimatedOpacity(
      opacity: _isLoadingAsistencias ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    color: Colors.amber.shade600,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mis Sellos de Asistencia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      if (_periodoSeleccionado != null)
                        Text(
                          _periodoSeleccionado!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_asistenciasFiltradas.length}/$totalSellos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: totalSellos,
              itemBuilder: (context, index) {
                // Si hay asistencia en esta posición, mostrar sello con color
                if (index < _asistenciasFiltradas.length) {
                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    curve: Curves.elasticOut,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Hero(
                          tag: 'sello_${_asistenciasFiltradas[index]['id']}',
                          child: _buildSelloAsistencia(
                            _asistenciasFiltradas[index],
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  // Mostrar espacio vacío en gris
                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    curve: Curves.easeOut,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: _buildSelloVacio(index),
                      );
                    },
                  );
                }
              },
            ),
            if (_asistenciasFiltradas.length > totalSellos) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.celebration,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '¡Felicitaciones! Tienes ${_asistenciasFiltradas.length} asistencias',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _mostrarTodosLosSellos,
                  icon: const Icon(Icons.grid_view),
                  label: const Text('Ver todos los sellos'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A5F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarTodosLosSellos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.workspace_premium,
                            color: const Color(0xFFD97706),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _periodoSeleccionado ?? 'Todos los Sellos',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                              Text(
                                '${_asistenciasFiltradas.length} sellos de asistencia',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemCount: _asistenciasFiltradas.length,
                      itemBuilder: (context, index) {
                        return TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 200 + (index * 30)),
                          curve: Curves.easeOutCubic,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Hero(
                                tag:
                                    'sello_modal_${_asistenciasFiltradas[index]['id']}',
                                child: _buildSelloAsistencia(
                                  _asistenciasFiltradas[index],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _esValorValido(dynamic valor) {
    if (valor == null) return false;
    final valorStr = valor.toString().trim().toLowerCase();
    return valorStr.isNotEmpty &&
        valorStr != 'sin código' &&
        valorStr != 'sin codigo' &&
        valorStr != 'sin título' &&
        valorStr != 'sin titulo' &&
        valorStr != 'sin grupo' &&
        valorStr != 'null';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
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
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user,
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
                          'Mis Asistencias',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_currentUserName != null)
                          Text(
                            _currentUserName!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _cargarMisAsistencias,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EDF2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _currentUserId == null
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _cargarMisAsistencias,
                        color: const Color(0xFF1E3A5F),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20.0),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildFiltroPeriodo(),
                                _buildColeccionSellos(),
                                _buildAsistenciasCard(),
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

  Widget _buildAsistenciasCard() {
    return AnimatedOpacity(
      opacity: _isLoadingAsistencias ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Color(0xFF1E3A5F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Historial Detallado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                if (_asistenciasFiltradas.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_asistenciasFiltradas.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoadingAsistencias)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF1E3A5F)),
                      SizedBox(height: 16),
                      Text(
                        'Cargando asistencias...',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_asistenciasFiltradas.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _periodoSeleccionado != null
                            ? 'No hay asistencias en $_periodoSeleccionado'
                            : 'No tienes asistencias registradas',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1E3A5F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _periodoSeleccionado != null
                            ? 'Selecciona otro periodo o registra nuevas asistencias'
                            : 'Escanea un código QR para registrar tu primera asistencia',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _asistenciasFiltradas.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    curve: Curves.easeOut,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: _buildAsistenciaCard(
                            _asistenciasFiltradas[index],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAsistenciaCard(Map<String, dynamic> asistencia) {
    final timestamp = (asistencia['timestamp'] as Timestamp?)?.toDate();
    final eventDate = (asistencia['eventDate'] as Timestamp?)?.toDate();
    final categoria =
        asistencia['categoria'] ??
        asistencia['tipoInvestigacion'] ??
        'Sin categoría';
    final codigoProyecto = asistencia['codigoProyecto'];
    final tituloProyecto = asistencia['tituloProyecto'];
    final grupo = asistencia['grupo'];

    final hasValidCode = _esValorValido(codigoProyecto);
    final hasValidGroup = _esValorValido(grupo);
    final hasValidTitle = _esValorValido(tituloProyecto);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _getColorByCategoria(categoria).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getColorByCategoria(categoria).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getColorByCategoria(categoria).withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getColorByCategoria(categoria).withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getColorByCategoria(categoria),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _getColorByCategoria(categoria).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconByCategoria(categoria),
                    color: Colors.white,
                    size: 22,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasValidCode) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.qr_code_2,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                codigoProyecto.toString().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF059669),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorByCategoria(
                          categoria,
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getColorByCategoria(
                            categoria,
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconByCategoria(categoria),
                            size: 14,
                            color: _getColorByCategoria(categoria),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            categoria,
                            style: TextStyle(
                              color: _getColorByCategoria(categoria),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasValidGroup)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.group,
                              size: 14,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              grupo.toString().toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (hasValidTitle) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.article_outlined,
                            size: 18,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Proyecto Presentado',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4F46E5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tituloProyecto.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF312E81),
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (asistencia['eventDescription']?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    asistencia['eventDescription'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if ((asistencia['eventFacultad']?.isNotEmpty == true ||
                        asistencia['facultad']?.isNotEmpty == true) &&
                    (asistencia['eventCarrera']?.isNotEmpty == true ||
                        asistencia['carrera']?.isNotEmpty == true)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${asistencia['eventFacultad'] ?? asistencia['facultad'] ?? ''} • ${asistencia['eventCarrera'] ?? asistencia['carrera'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (eventDate != null) ...[
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.event_outlined,
                          label: 'Evento',
                          value:
                              '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                          color: const Color(0xFF0891B2),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (timestamp != null)
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.check_circle_outline,
                          label: 'Registrado',
                          value:
                              '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                          color: const Color(0xFF059669),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SelloPainter extends CustomPainter {
  final Color color;

  SelloPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * (3.14159 / 180);
      final startRadius = radius * 0.6;
      final endRadius = radius * 0.9;

      final start = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );

      canvas.drawLine(start, end, paint..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TextoCurvadoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 8,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
