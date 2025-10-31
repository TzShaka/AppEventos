import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class GenerarQRController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, List<String>> facultadesCarreras = {
    'Facultad de Ciencias Empresariales': [
      'Administración',
      'Contabilidad',
      'Gestión Tributaria y Aduanera',
    ],
    'Facultad de Ciencias Humanas y Educación': [
      'Educación, Especialidad Inicial y Puericultura',
      'Educación, Especialidad Primaria y Pedagogía Terapéutica',
      'Educación, Especialidad Inglés y Español',
    ],
    'Facultad de Ciencias de la Salud': [
      'Enfermería',
      'Nutrición Humana',
      'Psicología',
    ],
    'Facultad de Ingeniería y Arquitectura': [
      'Ingeniería Civil',
      'Arquitectura y Urbanismo',
      'Ingeniería Ambiental',
      'Ingeniería de Industrias Alimentarias',
      'Ingeniería de Sistemas',
    ],
  };

  Future<List<QueryDocumentSnapshot>> buscarEventos({
    required String facultad,
    required String carrera,
  }) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('events')
        .where('facultad', isEqualTo: facultad)
        .where('carrera', isEqualTo: carrera)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs;
  }

  Future<List<String>> cargarCategorias(String eventId) async {
    final QuerySnapshot proyectosSnapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('proyectos')
        .get();

    final Set<String> categoriasSet = {};
    for (final doc in proyectosSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final clasificacion = data['Clasificación']?.toString().trim();
      if (clasificacion != null && clasificacion.isNotEmpty) {
        categoriasSet.add(clasificacion);
      }
    }

    return categoriasSet.toList()..sort();
  }

  // MÉTODO ACTUALIZADO: Genera QR con datos del proyecto
  Future<Map<String, String>> generarQRParaTodasLasCategorias({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required List<String> categorias,
  }) async {
    final Map<String, String> qrData = {};

    for (final categoria in categorias) {
      // Obtener el primer proyecto de esta categoría para los datos
      final proyectos = await _obtenerProyectosPorCategoria(
        eventId: eventId,
        categoria: categoria,
      );

      // Usar datos del primer proyecto (o valores por defecto)
      final primerProyecto = proyectos.isNotEmpty ? proyectos.first : null;

      final qrInfo = _crearQRInfo(
        eventId: eventId,
        eventName: eventName,
        facultad: facultad,
        carrera: carrera,
        categoria: categoria,
        codigoProyecto: primerProyecto?['Código']?.toString(),
        tituloProyecto: primerProyecto?['Título']?.toString(),
        grupo: primerProyecto?['Sala']?.toString(), // ← USAR SALA COMO GRUPO
      );

      qrData[categoria] = jsonEncode(qrInfo);
    }

    return qrData;
  }

  // MÉTODO ACTUALIZADO: Genera QR específico por proyecto
  Future<String> generarQRParaProyecto({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
    required String codigoProyecto,
    required String tituloProyecto,
    String? grupo,
  }) async {
    final qrInfo = _crearQRInfo(
      eventId: eventId,
      eventName: eventName,
      facultad: facultad,
      carrera: carrera,
      categoria: categoria,
      codigoProyecto: codigoProyecto,
      tituloProyecto: tituloProyecto,
      grupo: grupo,
    );

    print('🔧 QR generado para proyecto:');
    print('   Código: $codigoProyecto');
    print('   Título: $tituloProyecto');
    print('   Categoría: $categoria');
    print('   Grupo: $grupo');

    return jsonEncode(qrInfo);
  }

  // MÉTODO ACTUALIZADO: Genera QR para una categoría completa
  String generarQRParaCategoria({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
    String? codigoProyecto,
    String? tituloProyecto,
    String? grupo,
  }) {
    final qrInfo = _crearQRInfo(
      eventId: eventId,
      eventName: eventName,
      facultad: facultad,
      carrera: carrera,
      categoria: categoria,
      codigoProyecto: codigoProyecto,
      tituloProyecto: tituloProyecto,
      grupo: grupo,
    );
    return jsonEncode(qrInfo);
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTODO CORREGIDO: Crear QR Info - CAMBIO CRÍTICO AQUÍ
  // ═══════════════════════════════════════════════════════════════
  Map<String, dynamic> _crearQRInfo({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
    String? codigoProyecto,
    String? tituloProyecto,
    String? grupo,
  }) {
    // Validar si el grupo es válido antes de agregarlo
    final grupoValido =
        grupo != null &&
        grupo.trim().isNotEmpty &&
        grupo.toLowerCase() != 'sin grupo' &&
        grupo.toLowerCase() != 'null';

    final qrData = {
      'eventId': eventId,
      'eventName': eventName,
      'facultad': facultad,
      'carrera': carrera,
      'categoria': categoria,
      'codigoProyecto': codigoProyecto ?? 'Sin código',
      'tituloProyecto': tituloProyecto ?? 'Sin título',
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'asistencia_categoria',
    };

    // SOLO agregar el grupo si es válido, de lo contrario no incluirlo
    if (grupoValido) {
      qrData['grupo'] = grupo;
      print('✅ Grupo válido incluido en QR: $grupo');
    } else {
      print('⚠️ Grupo no válido, no se incluye en QR: $grupo');
    }

    return qrData;
  }

  // NUEVO MÉTODO: Obtener proyectos por categoría
  Future<List<Map<String, dynamic>>> _obtenerProyectosPorCategoria({
    required String eventId,
    required String categoria,
  }) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .where('Clasificación', isEqualTo: categoria)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo proyectos: $e');
      return [];
    }
  }

  // NUEVO MÉTODO: Obtener todos los proyectos de una categoría con sus datos
  Future<List<Map<String, dynamic>>> obtenerProyectosDeCategoria({
    required String eventId,
    required String categoria,
  }) async {
    return await _obtenerProyectosPorCategoria(
      eventId: eventId,
      categoria: categoria,
    );
  }

  // MÉTODO ACTUALIZADO: Generar múltiples QRs para cada proyecto de una categoría
  Future<Map<String, String>> generarQRsPorProyecto({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required String categoria,
  }) async {
    final Map<String, String> qrsPorProyecto = {};

    final proyectos = await obtenerProyectosDeCategoria(
      eventId: eventId,
      categoria: categoria,
    );

    for (final proyecto in proyectos) {
      final codigo = proyecto['Código']?.toString() ?? 'Sin código';
      final titulo = proyecto['Título']?.toString() ?? 'Sin título';
      final sala = proyecto['Sala']?.toString(); // ← Obtener SALA del proyecto

      final qrData = await generarQRParaProyecto(
        eventId: eventId,
        eventName: eventName,
        facultad: facultad,
        carrera: carrera,
        categoria: categoria,
        codigoProyecto: codigo,
        tituloProyecto: titulo,
        grupo: sala, // ← Usar SALA como grupo
      );

      // Usar código como clave única
      qrsPorProyecto[codigo] = qrData;
    }

    print(
      '✅ Generados ${qrsPorProyecto.length} QRs para categoría: $categoria',
    );
    return qrsPorProyecto;
  }

  List<String> obtenerCarrerasPorFacultad(String facultad) {
    return facultadesCarreras[facultad] ?? [];
  }
}
