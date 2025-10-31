import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'evaluaciones.dart';

class EvaluacionItem {
  String descripcion;
  String escala;

  EvaluacionItem({required this.descripcion, required this.escala});
}

class CriteriosScreen extends StatefulWidget {
  final String facultad;
  final String carrera;
  final String categoria;
  final String juradoId;
  final Map<String, dynamic> juradoData;
  final List<String> gruposSeleccionados;
  final List<Map<String, dynamic>> proyectos;

  const CriteriosScreen({
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
  State<CriteriosScreen> createState() => _CriteriosScreenState();
}

class _CriteriosScreenState extends State<CriteriosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<EvaluacionItem> evaluaciones = [];
  bool _isGuardando = false;
  bool _isCargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCriteriosExistentes();
  }

  Future<void> _cargarCriteriosExistentes() async {
    setState(() => _isCargando = true);

    try {
      if (widget.gruposSeleccionados.isNotEmpty) {
        final codigoGrupo = widget.gruposSeleccionados.first;
        final proyecto = widget.proyectos.firstWhere(
          (p) => p['codigo'] == codigoGrupo,
        );

        final eventId = proyecto['eventId'] as String;
        final proyectoId = proyecto['id'] as String;

        final evaluacionDoc = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc(proyectoId)
            .collection('evaluaciones')
            .doc(widget.juradoId)
            .get();

        if (evaluacionDoc.exists) {
          final data = evaluacionDoc.data();
          if (data != null && data.containsKey('criterios')) {
            final criterios = data['criterios'] as List<dynamic>;

            setState(() {
              evaluaciones.clear();
              for (var criterio in criterios) {
                evaluaciones.add(
                  EvaluacionItem(
                    descripcion: criterio['descripcion'] ?? '',
                    escala: criterio['escala'] ?? '0/20',
                  ),
                );
              }
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${criterios.length} criterios cargados'),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error al cargar criterios: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar criterios existentes'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCargando = false);
      }
    }
  }

  void _mostrarDialogoAgregar() {
    final descripcionController = TextEditingController();
    final escalaController = TextEditingController(text: '0/20');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Criterio de Evaluación'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Descripción del Criterio:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Innovación y creatividad',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escala de Nota:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: escalaController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ej: 0/20, 0/5, 0/10',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (descripcionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debe ingresar una descripción'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setState(() {
                evaluaciones.add(
                  EvaluacionItem(
                    descripcion: descripcionController.text,
                    escala: escalaController.text,
                  ),
                );
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Criterio agregado'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditar(int index) {
    final item = evaluaciones[index];
    final descripcionController = TextEditingController(text: item.descripcion);
    final escalaController = TextEditingController(text: item.escala);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Criterio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Descripción:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ingrese la descripción',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Escala de Nota:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: escalaController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ej: 0/20, 0/5, 0/4, etc.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                evaluaciones.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Criterio eliminado'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              if (descripcionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debe ingresar una descripción'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setState(() {
                evaluaciones[index].descripcion = descripcionController.text;
                evaluaciones[index].escala = escalaController.text;
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Criterio actualizado'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarCriterios() async {
    if (evaluaciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos un criterio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _procesarGuardado();
  }

  Future<void> _procesarGuardado() async {
    setState(() => _isGuardando = true);

    try {
      final criterios = evaluaciones.map((e) {
        return {'descripcion': e.descripcion, 'escala': e.escala};
      }).toList();

      for (final codigoGrupo in widget.gruposSeleccionados) {
        final proyecto = widget.proyectos.firstWhere(
          (p) => p['codigo'] == codigoGrupo,
        );

        final eventId = proyecto['eventId'] as String;
        final proyectoId = proyecto['id'] as String;

        final evaluacionRef = _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc(proyectoId)
            .collection('evaluaciones')
            .doc(widget.juradoId);

        await evaluacionRef.set({
          'juradoId': widget.juradoId,
          'juradoNombre': widget.juradoData['nombre'],
          'juradoUsuario': widget.juradoData['usuario'],
          'facultad': widget.facultad,
          'carrera': widget.carrera,
          'categoria': widget.categoria,
          'criterios': criterios,
          'codigoGrupo': codigoGrupo,
          'fechaCreacion': FieldValue.serverTimestamp(),
          'fechaActualizacion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() => _isGuardando = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Criterios guardados para ${widget.gruposSeleccionados.length} grupo(s)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      print('Error al guardar criterios: $e');
      if (mounted) {
        setState(() => _isGuardando = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _navegarAEvaluaciones() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluacionesScreen(
          facultad: widget.facultad,
          carrera: widget.carrera,
          categoria: widget.categoria,
          juradoId: widget.juradoId,
          juradoData: widget.juradoData,
          gruposSeleccionados: widget.gruposSeleccionados,
          proyectos: widget.proyectos,
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
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Regresar',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Gestión de Evaluación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (evaluaciones.isNotEmpty && !_isGuardando)
                    IconButton(
                      icon: const Icon(
                        Icons.save,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _guardarCriterios,
                      tooltip: 'Guardar Criterios',
                    ),
                ],
              ),
            ),

            // Botones de navegación
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E3A5F),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Criterios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _navegarAEvaluaciones,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D4A6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Evaluaciones',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                child: _buildCriteriosContent(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: !_isCargando && !_isGuardando
          ? FloatingActionButton(
              onPressed: _mostrarDialogoAgregar,
              backgroundColor: const Color(0xFF1E3A5F),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCriteriosContent() {
    if (_isCargando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando criterios...',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Info Panel
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF1E3A5F),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Información de la Evaluación',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildInfoRow('Jurado:', widget.juradoData['nombre']),
              _buildInfoRow('Facultad:', widget.facultad),
              _buildInfoRow('Carrera:', widget.carrera),
              _buildInfoRow('Categoría:', widget.categoria),
              _buildInfoRow(
                'Grupos:',
                '${widget.gruposSeleccionados.length} seleccionados',
              ),
            ],
          ),
        ),

        // Lista de Criterios
        Expanded(
          child: evaluaciones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay criterios de evaluación',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toca el botón + para agregar criterios',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: evaluaciones.length,
                  itemBuilder: (context, index) {
                    final item = evaluaciones[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _mostrarDialogoEditar(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.descripcion,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
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
                                  'Escala: ${item.escala}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
