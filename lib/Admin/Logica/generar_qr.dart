import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class GenerarQRController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ AGREGADA la opción "Universidad Peruana Unión"
  final Map<String, List<String>> facultadesCarreras = {
    'Universidad Peruana Unión': [], // ✅ Nueva opción sin carreras
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

  // ✅ NUEVO MÉTODO: Verifica si se requiere carrera
  bool requiereCarrera(String? facultad) {
    if (facultad == null) return true;
    return facultad != 'Universidad Peruana Unión';
  }

  Future<List<QueryDocumentSnapshot>> buscarEventos({
    required String facultad,
    String? carrera, // ✅ Ahora es opcional
  }) async {
    Query query = _firestore
        .collection('events')
        .where('facultad', isEqualTo: facultad);

    // ✅ Solo agregar filtro de carrera si se proporciona
    if (carrera != null && carrera.isNotEmpty) {
      query = query.where('carrera', isEqualTo: carrera);
    } else if (facultad == 'Universidad Peruana Unión') {
      // Para UPeU, buscar eventos con carrera "General"
      query = query.where('carrera', isEqualTo: 'General');
    }

    final QuerySnapshot snapshot = await query
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

  Future<Map<String, String>> generarQRParaTodasLasCategorias({
    required String eventId,
    required String eventName,
    required String facultad,
    required String carrera,
    required List<String> categorias,
  }) async {
    final Map<String, String> qrData = {};

    for (final categoria in categorias) {
      final proyectos = await _obtenerProyectosPorCategoria(
        eventId: eventId,
        categoria: categoria,
      );

      final primerProyecto = proyectos.isNotEmpty ? proyectos.first : null;

      final qrInfo = _crearQRInfo(
        eventId: eventId,
        eventName: eventName,
        facultad: facultad,
        carrera: carrera,
        categoria: categoria,
        codigoProyecto: primerProyecto?['Código']?.toString(),
        tituloProyecto: primerProyecto?['Título']?.toString(),
        grupo: primerProyecto?['Sala']?.toString(),
      );

      qrData[categoria] = jsonEncode(qrInfo);
    }

    return qrData;
  }

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

    if (grupoValido) {
      qrData['grupo'] = grupo;
      print('✅ Grupo válido incluido en QR: $grupo');
    } else {
      print('⚠️ Grupo no válido, no se incluye en QR: $grupo');
    }

    return qrData;
  }

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

  Future<List<Map<String, dynamic>>> obtenerProyectosDeCategoria({
    required String eventId,
    required String categoria,
  }) async {
    return await _obtenerProyectosPorCategoria(
      eventId: eventId,
      categoria: categoria,
    );
  }

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
      final sala = proyecto['Sala']?.toString();

      final qrData = await generarQRParaProyecto(
        eventId: eventId,
        eventName: eventName,
        facultad: facultad,
        carrera: carrera,
        categoria: categoria,
        codigoProyecto: codigo,
        tituloProyecto: titulo,
        grupo: sala,
      );

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
