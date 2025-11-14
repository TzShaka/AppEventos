import 'package:cloud_firestore/cloud_firestore.dart';

class EventosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Estructura de facultades y carreras
  final Map<String, List<String>> facultadesCarreras = {
    'Universidad Peruana Unión': [],
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

  bool requiereCarrera(String? facultad) {
    if (facultad == null) return true;
    return facultad != 'Universidad Peruana Unión';
  }

  // Crear nuevo evento con período
  Future<void> createEvent({
    required String name,
    required String facultad,
    String? carrera,
    required String periodoId,
    required String periodoNombre,
  }) async {
    final eventData = {
      'name': name,
      'facultad': facultad,
      'periodoId': periodoId,
      'periodoNombre': periodoNombre,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'fecha': null,
      'hora': null,
      'lugar': '',
      'ponentes': [],
    };

    // Solo agregar carrera si se proporciona
    if (carrera != null && carrera.isNotEmpty) {
      eventData['carrera'] = carrera;
    } else {
      eventData['carrera'] = 'General'; // Valor por defecto para UPeU
    }

    await _firestore.collection('events').add(eventData);
  }

  // Editar evento CON PERÍODO
  Future<void> updateEvent({
    required String eventId,
    required String name,
    required String facultad,
    String? carrera,
    String? periodoId,
    String? periodoNombre,
  }) async {
    final updateData = {
      'name': name,
      'facultad': facultad,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Solo agregar carrera si se proporciona o si no es UPeU
    if (carrera != null && carrera.isNotEmpty) {
      updateData['carrera'] = carrera;
    } else if (facultad == 'Universidad Peruana Unión') {
      updateData['carrera'] = 'General';
    }

    // Solo agregar período si se proporciona
    if (periodoId != null) {
      updateData['periodoId'] = periodoId;
    }
    if (periodoNombre != null) {
      updateData['periodoNombre'] = periodoNombre;
    }

    await _firestore.collection('events').doc(eventId).update(updateData);
  }

  // Eliminar evento
  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection('events').doc(eventId).delete();
  }

  // Obtener stream de eventos
  Stream<QuerySnapshot> getEventsStream() {
    return _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Obtener conteo de eventos
  Stream<QuerySnapshot> getEventsCountStream() {
    return _firestore.collection('events').snapshots();
  }

  // Validar nombre del evento
  String? validateEventName(String name) {
    if (name.trim().isEmpty) {
      return 'Por favor ingresa el nombre del evento';
    }
    return null;
  }

  // Validar facultad
  String? validateFacultad(String? facultad) {
    if (facultad == null) {
      return 'Por favor selecciona una facultad';
    }
    return null;
  }

  // ✅ Validar carrera (con 2 parámetros)
  String? validateCarrera(String? carrera, String? facultad) {
    if (facultad == 'Universidad Peruana Unión') {
      return null;
    }
    if (carrera == null) {
      return 'Por favor selecciona una carrera';
    }
    return null;
  }

  // Validar período
  String? validatePeriodo(String? periodoId) {
    if (periodoId == null) {
      return 'Por favor selecciona un período';
    }
    return null;
  }

  // Formatear fecha
  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Filtrar eventos por facultad
  List<QueryDocumentSnapshot> filterByFacultad(
    List<QueryDocumentSnapshot> events,
    String? filtroFacultad,
  ) {
    if (filtroFacultad == null) return events;
    return events.where((event) {
      final data = event.data() as Map<String, dynamic>;
      return data['facultad'] == filtroFacultad;
    }).toList();
  }

  // ✅ MEJORADO: Filtrar eventos por carrera
  // Ahora maneja correctamente el caso de "General" para UPeU
  List<QueryDocumentSnapshot> filterByCarrera(
    List<QueryDocumentSnapshot> events,
    String? filtroCarrera,
  ) {
    if (filtroCarrera == null) return events;

    return events.where((event) {
      final data = event.data() as Map<String, dynamic>;
      final eventCarrera = data['carrera'];

      // Si el filtro es "General", solo mostrar eventos de UPeU
      if (filtroCarrera == 'General') {
        return eventCarrera == 'General' &&
            data['facultad'] == 'Universidad Peruana Unión';
      }

      // Para otras carreras, comparación normal
      return eventCarrera == filtroCarrera;
    }).toList();
  }

  // Filtrar eventos por período
  List<QueryDocumentSnapshot> filterByPeriodo(
    List<QueryDocumentSnapshot> events,
    String? filtroPeriodo,
  ) {
    if (filtroPeriodo == null) return events;
    return events.where((event) {
      final data = event.data() as Map<String, dynamic>;
      return data['periodoId'] == filtroPeriodo;
    }).toList();
  }
}
