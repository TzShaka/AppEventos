import 'package:cloud_firestore/cloud_firestore.dart';

class EventosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Estructura de facultades y carreras
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

  // Crear nuevo evento
  Future<void> createEvent({
    required String name,
    required String facultad,
    required String carrera,
  }) async {
    await _firestore.collection('events').add({
      'name': name,
      'facultad': facultad,
      'carrera': carrera,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'fecha': null,
      'hora': null,
      'lugar': '',
      'ponentes': [],
    });
  }

  // Editar evento
  Future<void> updateEvent({
    required String eventId,
    required String name,
    required String facultad,
    required String carrera,
  }) async {
    await _firestore.collection('events').doc(eventId).update({
      'name': name,
      'facultad': facultad,
      'carrera': carrera,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  // Validar carrera
  String? validateCarrera(String? carrera) {
    if (carrera == null) {
      return 'Por favor selecciona una carrera';
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

  // Filtrar eventos por carrera
  List<QueryDocumentSnapshot> filterByCarrera(
    List<QueryDocumentSnapshot> events,
    String? filtroCarrera,
  ) {
    if (filtroCarrera == null) return events;
    return events.where((event) {
      final data = event.data() as Map<String, dynamic>;
      return data['carrera'] == filtroCarrera;
    }).toList();
  }
}
