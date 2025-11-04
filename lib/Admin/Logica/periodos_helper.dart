import 'package:cloud_firestore/cloud_firestore.dart';

class PeriodosHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Crear un nuevo período
  static Future<bool> createPeriodo({
    required String nombre,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    bool activo = false,
  }) async {
    try {
      // Verificar si ya existe un período con ese nombre
      final existingPeriodo = await _firestore
          .collection('periodos')
          .where('nombre', isEqualTo: nombre.trim())
          .get();

      if (existingPeriodo.docs.isNotEmpty) {
        print('Ya existe un período con ese nombre');
        return false;
      }

      // Si se marca como activo, desactivar todos los demás períodos
      if (activo) {
        await _desactivarTodosPeriodos();
      }

      // Crear el período
      await _firestore.collection('periodos').add({
        'nombre': nombre.trim(),
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        'fechaFin': Timestamp.fromDate(fechaFin),
        'activo': activo,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Período creado exitosamente: $nombre');
      return true;
    } catch (e) {
      print('Error creando período: $e');
      return false;
    }
  }

  // Obtener todos los períodos
  static Future<List<Map<String, dynamic>>> getPeriodos() async {
    try {
      final periodosQuery = await _firestore
          .collection('periodos')
          .orderBy('createdAt', descending: true)
          .get();

      return periodosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error obteniendo períodos: $e');
      return [];
    }
  }

  // Obtener el período activo
  static Future<Map<String, dynamic>?> getPeriodoActivo() async {
    try {
      final periodoQuery = await _firestore
          .collection('periodos')
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();

      if (periodoQuery.docs.isNotEmpty) {
        final doc = periodoQuery.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error obteniendo período activo: $e');
      return null;
    }
  }

  // Actualizar un período
  static Future<bool> updatePeriodo({
    required String periodoId,
    String? nombre,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? activo,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nombre != null && nombre.isNotEmpty) {
        // Verificar si ya existe otro período con ese nombre
        final existingPeriodo = await _firestore
            .collection('periodos')
            .where('nombre', isEqualTo: nombre.trim())
            .get();

        if (existingPeriodo.docs.isNotEmpty &&
            existingPeriodo.docs.first.id != periodoId) {
          print('Ya existe otro período con ese nombre');
          return false;
        }
        updateData['nombre'] = nombre.trim();
      }

      if (fechaInicio != null) {
        updateData['fechaInicio'] = Timestamp.fromDate(fechaInicio);
      }

      if (fechaFin != null) {
        updateData['fechaFin'] = Timestamp.fromDate(fechaFin);
      }

      if (activo != null) {
        // Si se activa este período, desactivar todos los demás
        if (activo) {
          await _desactivarTodosPeriodos();
        }
        updateData['activo'] = activo;
      }

      await _firestore.collection('periodos').doc(periodoId).update(updateData);
      print('Período actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error actualizando período: $e');
      return false;
    }
  }

  // Activar un período (desactiva todos los demás)
  static Future<bool> activarPeriodo(String periodoId) async {
    try {
      await _desactivarTodosPeriodos();
      await _firestore.collection('periodos').doc(periodoId).update({
        'activo': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Período activado exitosamente');
      return true;
    } catch (e) {
      print('Error activando período: $e');
      return false;
    }
  }

  // Desactivar un período
  static Future<bool> desactivarPeriodo(String periodoId) async {
    try {
      await _firestore.collection('periodos').doc(periodoId).update({
        'activo': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Período desactivado exitosamente');
      return true;
    } catch (e) {
      print('Error desactivando período: $e');
      return false;
    }
  }

  // Eliminar un período
  static Future<bool> deletePeriodo(String periodoId) async {
    try {
      await _firestore.collection('periodos').doc(periodoId).delete();
      print('Período eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error eliminando período: $e');
      return false;
    }
  }

  // Desactivar todos los períodos (función auxiliar privada)
  static Future<void> _desactivarTodosPeriodos() async {
    try {
      final periodosActivos = await _firestore
          .collection('periodos')
          .where('activo', isEqualTo: true)
          .get();

      for (var doc in periodosActivos.docs) {
        await doc.reference.update({'activo': false});
      }
    } catch (e) {
      print('Error desactivando períodos: $e');
    }
  }

  // Buscar períodos por nombre o año
  static Future<List<Map<String, dynamic>>> searchPeriodos(
    String searchTerm,
  ) async {
    try {
      final periodosQuery = await _firestore
          .collection('periodos')
          .orderBy('createdAt', descending: true)
          .get();

      final periodos = periodosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (searchTerm.isEmpty) return periodos;

      final searchLower = searchTerm.toLowerCase();
      return periodos.where((periodo) {
        final nombre = (periodo['nombre'] ?? '').toString().toLowerCase();
        return nombre.contains(searchLower);
      }).toList();
    } catch (e) {
      print('Error buscando períodos: $e');
      return [];
    }
  }

  // Verificar si hay un período activo
  static Future<bool> hayPeriodoActivo() async {
    try {
      final periodoQuery = await _firestore
          .collection('periodos')
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();

      return periodoQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error verificando período activo: $e');
      return false;
    }
  }
}
