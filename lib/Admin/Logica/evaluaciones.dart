import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'evaluaciones_excel.dart';

class EvaluacionesScreen extends StatefulWidget {
  final String facultad;
  final String carrera;
  final String categoria;
  final String juradoId;
  final Map<String, dynamic> juradoData;
  final List<String> gruposSeleccionados;
  final List<Map<String, dynamic>> proyectos;

  const EvaluacionesScreen({
    super.key,
    required this.facultad,
    required this.carrera,
    required this.categoria,
    required this.juradoId,
    required this.juradoData,
    required this.gruposSeleccionados,
    required this.proyectos,
  });

  @override
  State<EvaluacionesScreen> createState() => _EvaluacionesScreenState();
}

class _EvaluacionesScreenState extends State<EvaluacionesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EvaluacionesExcelService _excelService = EvaluacionesExcelService();
  bool _generandoReporte = false;

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
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Regresar',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Evaluaciones Realizadas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Botón de descarga de reporte
                  IconButton(
                    icon: _generandoReporte
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 28,
                          ),
                    onPressed: _generandoReporte ? null : _descargarReporte,
                    tooltip: 'Descargar Reporte Excel',
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
                child: _buildEvaluacionesContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _descargarReporte() async {
    setState(() {
      _generandoReporte = true;
    });

    try {
      // Mostrar diálogo de progreso
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Generando reporte Excel...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Procesando evaluaciones',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      }

      // Generar el reporte
      final filePath = await _excelService.generarReporteEvaluaciones(
        juradoId: widget.juradoId,
        juradoNombre: widget.juradoData['nombre'] ?? 'Sin nombre',
        facultad: widget.facultad,
        carrera: widget.carrera,
        categoria: widget.categoria,
        gruposSeleccionados: widget.gruposSeleccionados,
        proyectos: widget.proyectos,
      );

      if (!mounted) return;

      // Cerrar diálogo de progreso
      Navigator.pop(context);

      // Mostrar diálogo de éxito
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Reporte Generado'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El reporte Excel se ha generado y guardado exitosamente.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El archivo incluye:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem('• Resumen de evaluaciones'),
                    _buildInfoItem('• Detalle completo con criterios'),
                    _buildInfoItem('• Estadísticas generales'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ubicación: Documentos del dispositivo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        // Cerrar diálogo de progreso si está abierto
        Navigator.of(context, rootNavigator: true).pop();

        // Mostrar error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No se pudo generar el reporte:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    e.toString(),
                    style: TextStyle(fontSize: 13, color: Colors.red[700]),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _generandoReporte = false;
        });
      }
    }
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
      ),
    );
  }

  Widget _buildEvaluacionesContent() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _cargarEvaluacionesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Cargando evaluaciones...',
                  style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar evaluaciones',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final evaluaciones = snapshot.data ?? [];

        if (evaluaciones.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay evaluaciones realizadas',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las evaluaciones aparecerán aquí cuando\nel jurado las complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: evaluaciones.length,
          itemBuilder: (context, index) {
            final eval = evaluaciones[index];
            return _buildEvaluacionCard(eval);
          },
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _cargarEvaluacionesStream() {
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      final List<Map<String, dynamic>> todasLasEvaluaciones = [];

      for (final codigoGrupo in widget.gruposSeleccionados) {
        try {
          final proyecto = widget.proyectos.firstWhere(
            (p) => p['codigo'] == codigoGrupo,
          );

          final eventId = proyecto['eventId'] as String;
          final proyectoId = proyecto['id'] as String;

          final snapshot = await _firestore
              .collection('events')
              .doc(eventId)
              .collection('proyectos')
              .doc(proyectoId)
              .collection('evaluaciones')
              .doc(widget.juradoId)
              .get();

          if (snapshot.exists) {
            final data = snapshot.data()!;
            todasLasEvaluaciones.add({
              ...data,
              'eventId': eventId,
              'proyectoId': proyectoId,
              'codigoGrupo': codigoGrupo,
              'tituloProyecto': proyecto['titulo'] ?? 'Sin título',
            });
          }
        } catch (e) {
          print('Error al cargar evaluación de $codigoGrupo: $e');
        }
      }

      return todasLasEvaluaciones;
    });
  }

  Widget _buildEvaluacionCard(Map<String, dynamic> eval) {
    final evaluada = eval['evaluada'] ?? false;
    final bloqueada = eval['bloqueada'] ?? false;
    final notaTotal = eval['notaTotal'] ?? 0;
    final criterios = eval['criterios'] as List<dynamic>? ?? [];
    final notas = eval['notas'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con código y estado
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
                    eval['codigoGrupo'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: evaluada
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    evaluada ? 'Evaluada' : 'Pendiente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: evaluada ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Título del proyecto
            Text(
              eval['tituloProyecto'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),

            if (evaluada) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Nota total
              Row(
                children: [
                  const Icon(Icons.grade, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Nota Total:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    notaTotal.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Detalles de calificación
              ...List.generate(criterios.length, (index) {
                final criterio = criterios[index];
                final nota = notas[index.toString()] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              criterio['descripcion'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Escala: ${criterio['escala']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          nota.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editarNotas(eval),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar Notas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: bloqueada
                          ? null
                          : () => _habilitarEvaluacion(eval),
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('Habilitar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              if (bloqueada)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Evaluación bloqueada por el administrador',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _editarNotas(Map<String, dynamic> eval) {
    final criterios = eval['criterios'] as List<dynamic>;
    final notasActuales = eval['notas'] as Map<String, dynamic>? ?? {};
    final Map<int, TextEditingController> controllers = {};

    // Inicializar controllers con las notas actuales
    for (int i = 0; i < criterios.length; i++) {
      controllers[i] = TextEditingController(
        text: notasActuales[i.toString()]?.toString() ?? '',
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF1E3A5F)),
            SizedBox(width: 8),
            Expanded(child: Text('Editar Notas')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Proyecto: ${eval['codigoGrupo']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(criterios.length, (index) {
                  final criterio = criterios[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                        const SizedBox(height: 6),
                        Text(
                          'Escala: ${criterio['escala']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controllers[index],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Nota',
                            hintText: 'Ingrese la calificación',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              for (var controller in controllers.values) {
                controller.dispose();
              }
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validar que todos los campos tengan nota
              for (int i = 0; i < criterios.length; i++) {
                if (controllers[i]?.text.trim().isEmpty ?? true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debes calificar todos los criterios'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
              }

              // Guardar las notas editadas
              final Map<String, dynamic> nuevasNotas = {};
              double sumaTotal = 0;

              for (var entry in controllers.entries) {
                final nota = double.tryParse(entry.value.text.trim()) ?? 0;
                nuevasNotas[entry.key.toString()] = nota;
                sumaTotal += nota;
              }

              try {
                await _firestore
                    .collection('events')
                    .doc(eval['eventId'])
                    .collection('proyectos')
                    .doc(eval['proyectoId'])
                    .collection('evaluaciones')
                    .doc(widget.juradoId)
                    .update({
                      'notas': nuevasNotas,
                      'notaTotal': sumaTotal,
                      'fechaActualizacion': FieldValue.serverTimestamp(),
                    });

                for (var controller in controllers.values) {
                  controller.dispose();
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notas actualizadas exitosamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  Future<void> _habilitarEvaluacion(Map<String, dynamic> eval) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.orange),
            SizedBox(width: 8),
            Text('Habilitar Evaluación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas habilitar la evaluación del proyecto ${eval['codigoGrupo']}?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'El jurado podrá volver a modificar las notas',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Habilitar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _firestore
            .collection('events')
            .doc(eval['eventId'])
            .collection('proyectos')
            .doc(eval['proyectoId'])
            .collection('evaluaciones')
            .doc(widget.juradoId)
            .update({
              'evaluada': false,
              'bloqueada': false,
              'fechaActualizacion': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Evaluación habilitada. El jurado puede editarla'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al habilitar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
