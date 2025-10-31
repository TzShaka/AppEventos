import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class ProyectosCategoriaScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String facultad;
  final String carrera;
  final String categoria;

  const ProyectosCategoriaScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.facultad,
    required this.carrera,
    required this.categoria,
  });

  @override
  State<ProyectosCategoriaScreen> createState() =>
      _ProyectosCategoriaScreenState();
}

class _ProyectosCategoriaScreenState extends State<ProyectosCategoriaScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _proyectos = [];
  bool _isLoading = true;
  String? _qrDataGenerado;
  Map<String, dynamic>? _proyectoSeleccionado;

  late AnimationController _fadeController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cargarProyectos();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _cargarProyectos() async {
    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('proyectos')
          .where('Clasificación', isEqualTo: widget.categoria)
          .orderBy('Código')
          .get();

      final proyectos = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _proyectos = proyectos;
        _isLoading = false;
      });

      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al cargar proyectos: $e', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTODO CORREGIDO: Nombres de campos correctos
  // ═══════════════════════════════════════════════════════════════
  void _generarQRParaProyecto(Map<String, dynamic> proyecto) {
    print('🎯 GENERANDO QR PARA PROYECTO:');
    print('   Código: ${proyecto['Código']}');
    print('   Título: ${proyecto['Título']}');
    print('   Sala: ${proyecto['Sala']}');

    final qrInfo = {
      'eventId': widget.eventId,
      'eventName': widget.eventName,
      'facultad': widget.facultad,
      'carrera': widget.carrera,
      'categoria': widget.categoria,

      // ⚠️ CRÍTICO: Usar los nombres correctos que espera escanear_qr.dart
      'codigoProyecto': proyecto['Código'] ?? 'Sin código', // ✅ CORREGIDO
      'tituloProyecto': proyecto['Título'] ?? 'Sin título', // ✅ CORREGIDO
      'grupo': proyecto['Sala'], // ✅ CORREGIDO (puede ser null)

      'timestamp': DateTime.now().toIso8601String(),
      'type': 'asistencia_categoria',
    };

    print('📦 QR INFO CREADO:');
    print('   codigoProyecto: ${qrInfo['codigoProyecto']}');
    print('   tituloProyecto: ${qrInfo['tituloProyecto']}');
    print('   grupo: ${qrInfo['grupo']}');

    final qrJson = jsonEncode(qrInfo);
    print('📄 QR JSON: $qrJson');

    setState(() {
      _qrDataGenerado = qrJson;
      _proyectoSeleccionado = proyecto;
    });

    _scaleController.forward(from: 0);
    _showSnackBar('¡Código QR generado para el proyecto!');
  }

  void _limpiarQR() {
    setState(() {
      _qrDataGenerado = null;
      _proyectoSeleccionado = null;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFF5),
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proyectos por Categoría',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(
              widget.categoria,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
              ),
            )
          : _qrDataGenerado != null
          ? _buildQRView()
          : _buildProyectosList(),
    );
  }

  Widget _buildProyectosList() {
    if (_proyectos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay proyectos en esta categoría',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Selecciona un proyecto para generar su código QR',
                    style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _proyectos.length,
              itemBuilder: (context, index) {
                final proyecto = _proyectos[index];
                return TweenAnimationBuilder(
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: _buildProyectoCard(proyecto),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyectoCard(Map<String, dynamic> proyecto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _generarQRParaProyecto(proyecto),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        proyecto['Código'] ?? 'Sin código',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.qr_code_rounded,
                      color: const Color(0xFF1E3A5F).withOpacity(0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  proyecto['Título'] ?? 'Sin título',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                    height: 1.3,
                  ),
                ),
                if (proyecto['Integrantes'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          proyecto['Integrantes'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (proyecto['Sala'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.room_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sala: ${proyecto['Sala']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Toca para generar QR',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRView() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _proyectoSeleccionado!['Código'] ?? 'Sin código',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE0E7ED),
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: _qrDataGenerado!,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Evento:', widget.eventName),
                        _buildInfoRow('Categoría:', widget.categoria),
                        _buildInfoRow(
                          'Código:',
                          _proyectoSeleccionado!['Código'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Título:',
                          _proyectoSeleccionado!['Título'] ?? 'N/A',
                        ),
                        if (_proyectoSeleccionado!['Sala'] != null)
                          _buildInfoRow(
                            'Sala:',
                            _proyectoSeleccionado!['Sala'],
                          ),
                        _buildInfoRow(
                          'Generado:',
                          DateTime.now().toString().split('.')[0],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _limpiarQR,
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          label: const Text('Volver'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: Color(0xFF1E3A5F),
                              width: 1.5,
                            ),
                            foregroundColor: const Color(0xFF1E3A5F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_rounded, size: 20),
                          label: const Text('Finalizar'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
