import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/prefs_helper.dart';
import '/login.dart';

class JuradosScreen extends StatefulWidget {
  const JuradosScreen({super.key});

  @override
  State<JuradosScreen> createState() => _JuradosScreenState();
}

class _JuradosScreenState extends State<JuradosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _userName = '';
  String _userId = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _proyectosAsignados = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userName = await PrefsHelper.getUserName();
    final userId = await PrefsHelper.getCurrentUserId();

    setState(() {
      _userName = userName ?? 'Jurado';
      _userId = userId ?? '';
    });

    if (_userId.isNotEmpty) {
      await _cargarProyectosAsignados();
    }
  }

  Future<void> _cargarProyectosAsignados() async {
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> proyectos = [];

      final evaluacionesSnapshot = await _firestore
          .collectionGroup('evaluaciones')
          .where('juradoId', isEqualTo: _userId)
          .get();

      print('Evaluaciones encontradas: ${evaluacionesSnapshot.docs.length}');

      for (var evaluacionDoc in evaluacionesSnapshot.docs) {
        final evaluacionData = evaluacionDoc.data();

        final pathSegments = evaluacionDoc.reference.path.split('/');
        final eventId = pathSegments[1];
        final proyectoId = pathSegments[3];

        final proyectoDoc = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc(proyectoId)
            .get();

        if (proyectoDoc.exists) {
          final proyectoData = proyectoDoc.data()!;

          proyectos.add({
            'eventId': eventId,
            'proyectoId': proyectoId,
            'codigo': proyectoData['Código'] ?? '',
            'titulo': proyectoData['Título'] ?? 'Sin título',
            'integrantes': proyectoData['Integrantes'] ?? '',
            'sala': proyectoData['Sala'] ?? '',
            'criterios': evaluacionData['criterios'] ?? [],
            'facultad': evaluacionData['facultad'] ?? '',
            'carrera': evaluacionData['carrera'] ?? '',
            'categoria': evaluacionData['categoria'] ?? '',
            'evaluacionId': evaluacionDoc.id,
            'evaluada': evaluacionData['evaluada'] ?? false,
            'bloqueada': evaluacionData['bloqueada'] ?? false,
            'notaTotal': evaluacionData['notaTotal'] ?? 0,
          });
        }
      }

      proyectos.sort((a, b) => a['codigo'].compareTo(b['codigo']));

      if (mounted) {
        setState(() {
          _proyectosAsignados = proyectos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar proyectos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar proyectos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await PrefsHelper.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _navegarAEvaluacion(Map<String, dynamic> proyecto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluacionProyectoScreen(
          proyecto: proyecto,
          juradoId: _userId,
          juradoNombre: _userName,
        ),
      ),
    ).then((_) => _cargarProyectosAsignados());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.gavel,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Panel de Jurado',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _userName,
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
                    onPressed: _isLoading ? null : _cargarProyectosAsignados,
                    tooltip: 'Actualizar',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _logout,
                    tooltip: 'Cerrar Sesión',
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
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando proyectos asignados...',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_proyectosAsignados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
              Text(
                'No tienes proyectos asignados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Los proyectos aparecerán aquí cuando un administrador te los asigne',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Proyectos para Evaluar (${_proyectosAsignados.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: _proyectosAsignados.length,
            itemBuilder: (context, index) {
              final proyecto = _proyectosAsignados[index];
              final criterios = proyecto['criterios'] as List<dynamic>;
              final evaluada = proyecto['evaluada'] as bool;
              final bloqueada = proyecto['bloqueada'] as bool;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () => _navegarAEvaluacion(proyecto),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                proyecto['codigo'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (evaluada || bloqueada)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: bloqueada
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      bloqueada
                                          ? Icons.lock
                                          : Icons.check_circle,
                                      size: 16,
                                      color: bloqueada
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      bloqueada ? 'Bloqueada' : 'Evaluada',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: bloqueada
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          proyecto['titulo'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (proyecto['integrantes'].toString().isNotEmpty)
                          _buildInfoRow(Icons.people, proyecto['integrantes']),
                        if (proyecto['sala'].toString().isNotEmpty)
                          _buildInfoRow(Icons.room, proyecto['sala']),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF1E3A5F,
                                    ).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.assignment,
                                      color: Color(0xFF1E3A5F),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${criterios.length} criterio${criterios.length != 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E3A5F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (evaluada) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.grade,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${proyecto['notaTotal']}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Pantalla de evaluación del proyecto
class EvaluacionProyectoScreen extends StatefulWidget {
  final Map<String, dynamic> proyecto;
  final String juradoId;
  final String juradoNombre;

  const EvaluacionProyectoScreen({
    super.key,
    required this.proyecto,
    required this.juradoId,
    required this.juradoNombre,
  });

  @override
  State<EvaluacionProyectoScreen> createState() =>
      _EvaluacionProyectoScreenState();
}

class _EvaluacionProyectoScreenState extends State<EvaluacionProyectoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<int, double?> _notasSeleccionadas = {};
  bool _isGuardando = false;
  bool _isCargando = true;
  bool _yaEvaluado = false;
  bool _estaBloqueado = false;

  @override
  void initState() {
    super.initState();
    _cargarNotas();
  }

  Future<void> _cargarNotas() async {
    setState(() => _isCargando = true);

    try {
      final evaluacionDoc = await _firestore
          .collection('events')
          .doc(widget.proyecto['eventId'])
          .collection('proyectos')
          .doc(widget.proyecto['proyectoId'])
          .collection('evaluaciones')
          .doc(widget.juradoId)
          .get();

      if (evaluacionDoc.exists && mounted) {
        final data = evaluacionDoc.data();
        if (data != null) {
          _yaEvaluado = data['evaluada'] ?? false;
          _estaBloqueado = data['bloqueada'] ?? false;

          if (data.containsKey('notas')) {
            final notas = data['notas'] as Map<String, dynamic>;

            for (var entry in notas.entries) {
              final index = int.tryParse(entry.key);
              if (index != null) {
                _notasSeleccionadas[index] = (entry.value as num).toDouble();
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error al cargar notas: $e');
    } finally {
      if (mounted) {
        setState(() => _isCargando = false);
      }
    }
  }

  // Parsear la escala del formato "0/10" o "0/20"
  int _parseMaxEscala(String escala) {
    final parts = escala.split('/');
    if (parts.length == 2) {
      return int.tryParse(parts[1].trim()) ?? 10;
    }
    return 10;
  }

  Future<void> _guardarEvaluacion() async {
    // Validar que todos los criterios tengan nota
    final criterios = widget.proyecto['criterios'] as List<dynamic>;
    for (int i = 0; i < criterios.length; i++) {
      if (_notasSeleccionadas[i] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes calificar todos los criterios'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Confirmar guardado
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Evaluación'),
        content: const Text(
          'Una vez guardada, no podrás modificar las notas. ¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isGuardando = true);

    try {
      // Preparar las notas
      final Map<String, dynamic> notas = {};
      double sumaTotal = 0;

      for (var entry in _notasSeleccionadas.entries) {
        notas[entry.key.toString()] = entry.value!;
        sumaTotal += entry.value!;
      }

      // Guardar en Firestore
      await _firestore
          .collection('events')
          .doc(widget.proyecto['eventId'])
          .collection('proyectos')
          .doc(widget.proyecto['proyectoId'])
          .collection('evaluaciones')
          .doc(widget.juradoId)
          .update({
            'notas': notas,
            'notaTotal': sumaTotal,
            'evaluada': true,
            'bloqueada': false,
            'fechaEvaluacion': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evaluación guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGuardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final criterios = widget.proyecto['criterios'] as List<dynamic>;
    final soloLectura = _yaEvaluado || _estaBloqueado;

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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Evaluar ${widget.proyecto['codigo']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!soloLectura && !_isGuardando && !_isCargando)
                    IconButton(
                      icon: const Icon(
                        Icons.save,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _guardarEvaluacion,
                      tooltip: 'Guardar Evaluación',
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
                child: _isCargando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Mensaje de estado
                          if (soloLectura)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _estaBloqueado
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _estaBloqueado
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _estaBloqueado
                                        ? Icons.lock
                                        : Icons.check_circle,
                                    color: _estaBloqueado
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _estaBloqueado
                                          ? 'Evaluación bloqueada por el administrador'
                                          : 'Evaluación completada. Solo lectura.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _estaBloqueado
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Info del proyecto
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.proyecto['titulo'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                  ),
                                  if (widget.proyecto['integrantes']
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.proyecto['integrantes'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Criterios de evaluación
                          const Text(
                            'Criterios de Evaluación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 16),

                          ...List.generate(criterios.length, (index) {
                            final criterio = criterios[index];
                            final maxNota = _parseMaxEscala(criterio['escala']);
                            final notaSeleccionada = _notasSeleccionadas[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      criterio['descripcion'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF1E3A5F,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Escala: ${criterio['escala']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E3A5F),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Selector de notas con chips
                                    _buildNotaSelector(
                                      index,
                                      maxNota,
                                      notaSeleccionada,
                                      soloLectura,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (_isCargando || _isGuardando || soloLectura)
          ? null
          : FloatingActionButton.extended(
              onPressed: _guardarEvaluacion,
              backgroundColor: const Color(0xFF1E3A5F),
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Guardar Evaluación',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  Widget _buildNotaSelector(
    int criterioIndex,
    int maxNota,
    double? notaSeleccionada,
    bool soloLectura,
  ) {
    // Definir umbral para mostrar dropdown en lugar de chips
    const umbralChips = 10; // Si maxNota > 10, usar dropdown

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.stars, size: 18, color: Color(0xFF1E3A5F)),
            const SizedBox(width: 8),
            Text(
              notaSeleccionada != null
                  ? 'Nota seleccionada: ${notaSeleccionada.toStringAsFixed(notaSeleccionada.truncateToDouble() == notaSeleccionada ? 0 : 1)}'
                  : 'Selecciona una calificación',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: notaSeleccionada != null
                    ? const Color(0xFF1E3A5F)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Si la escala es grande (>10), usar dropdown
        if (maxNota > umbralChips)
          _buildDropdownSelector(
            criterioIndex,
            maxNota,
            notaSeleccionada,
            soloLectura,
          )
        else
          // Si la escala es pequeña (<=10), usar chips
          _buildChipsSelector(
            criterioIndex,
            maxNota,
            notaSeleccionada,
            soloLectura,
          ),
      ],
    );
  }

  Widget _buildChipsSelector(
    int criterioIndex,
    int maxNota,
    double? notaSeleccionada,
    bool soloLectura,
  ) {
    final opciones = List.generate(maxNota + 1, (i) => i.toDouble());

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((nota) {
        final isSelected = notaSeleccionada == nota;

        return InkWell(
          onTap: soloLectura
              ? null
              : () {
                  setState(() {
                    _notasSeleccionadas[criterioIndex] = nota;
                  });
                },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1E3A5F)
                  : soloLectura
                  ? Colors.grey[200]
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E3A5F)
                    : soloLectura
                    ? Colors.grey[300]!
                    : const Color(0xFF1E3A5F).withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1E3A5F).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                Text(
                  nota.toStringAsFixed(nota.truncateToDouble() == nota ? 0 : 1),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : soloLectura
                        ? Colors.grey[600]
                        : const Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownSelector(
    int criterioIndex,
    int maxNota,
    double? notaSeleccionada,
    bool soloLectura,
  ) {
    final opciones = List.generate(maxNota + 1, (i) => i.toDouble());

    return Container(
      decoration: BoxDecoration(
        color: soloLectura ? Colors.grey[200] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notaSeleccionada != null
              ? const Color(0xFF1E3A5F)
              : const Color(0xFF1E3A5F).withOpacity(0.3),
          width: notaSeleccionada != null ? 2 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: notaSeleccionada,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_drop_down_circle,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Toca para elegir la calificación',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F)),
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          elevation: 8,
          menuMaxHeight: 400,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A5F),
          ),
          items: opciones.map((nota) {
            return DropdownMenuItem<double>(
              value: nota,
              enabled: !soloLectura,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: notaSeleccionada == nota
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFF1E3A5F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          nota.toStringAsFixed(
                            nota.truncateToDouble() == nota ? 0 : 1,
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: notaSeleccionada == nota
                                ? Colors.white
                                : const Color(0xFF1E3A5F),
                          ),
                        ),
                      ),
                    ),
                    if (notaSeleccionada == nota) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF1E3A5F),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Seleccionada',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: soloLectura
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _notasSeleccionadas[criterioIndex] = value;
                    });
                  }
                },
          selectedItemBuilder: (context) {
            return opciones.map((nota) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      nota.toStringAsFixed(
                        nota.truncateToDouble() == nota ? 0 : 1,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'puntos',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
