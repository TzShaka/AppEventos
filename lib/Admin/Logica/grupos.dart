import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:typed_data';

class GruposService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cargar proyectos existentes desde Firebase
  Future<List<Map<String, dynamic>>> cargarProyectosExistentes(
    String eventId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .orderBy('importedAt', descending: true)
          .get();

      final proyectos = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      return proyectos;
    } catch (e) {
      print('Error al cargar proyectos existentes: $e');
      rethrow;
    }
  }

  // Importar Excel y retornar los datos procesados
  Future<List<Map<String, dynamic>>?> importarExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        return await procesarArchivoBytesExcel(result.files.single.bytes!);
      } else if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        return await procesarArchivoBytesExcel(bytes);
      }
      return null;
    } catch (e) {
      print('Error al importar archivo: $e');
      rethrow;
    }
  }

  // Procesar archivo Excel desde bytes
  Future<List<Map<String, dynamic>>> procesarArchivoBytesExcel(
    Uint8List bytes,
  ) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> proyectos = [];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows < 2) continue;

        List<String> headers = [];
        final headerRow = sheet.rows.first;
        for (var cell in headerRow) {
          headers.add(cell?.value?.toString().trim() ?? '');
        }

        print('Headers encontrados: $headers');

        for (int i = 1; i < sheet.maxRows; i++) {
          final row = sheet.rows[i];
          Map<String, dynamic> proyecto = {};

          for (int j = 0; j < headers.length && j < row.length; j++) {
            final cellValue = row[j]?.value?.toString().trim();
            if (cellValue != null && cellValue.isNotEmpty) {
              String normalizedKey = normalizarClave(headers[j]);
              proyecto[normalizedKey] = cellValue;
            }
          }

          if (proyecto.containsKey('Código') &&
              proyecto.containsKey('Clasificación')) {
            proyectos.add(proyecto);
          }
        }
      }

      return proyectos;
    } catch (e) {
      print('Error al procesar el archivo Excel: $e');
      rethrow;
    }
  }

  // Normalizar las claves de las columnas del Excel
  String normalizarClave(String clave) {
    final claveNormalizada = clave.toUpperCase().trim();

    switch (claveNormalizada) {
      case 'CÓDIGO':
        return 'Código';
      case 'TÍTULO DE INVESTIGACIÓN/PROYECTO':
        return 'Título';
      case 'INTEGRANTES':
        return 'Integrantes';
      case 'CLASIFICACIÓN':
        return 'Clasificación';
      case 'SALA':
        return 'Sala';
      default:
        return clave;
    }
  }

  // Guardar proyectos en Firebase
  Future<void> guardarProyectosEnEvento(
    String eventId,
    List<Map<String, dynamic>> proyectos,
  ) async {
    if (proyectos.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final proyecto in proyectos) {
        final docRef = _firestore
            .collection('events')
            .doc(eventId)
            .collection('proyectos')
            .doc();

        batch.set(docRef, {
          ...proyecto,
          'importedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _firestore.collection('events').doc(eventId).update({
        'lastImportAt': FieldValue.serverTimestamp(),
        'proyectosCount': FieldValue.increment(proyectos.length),
      });
    } catch (e) {
      print('Error al guardar proyectos: $e');
      rethrow;
    }
  }

  // Actualizar un proyecto en Firebase
  Future<void> actualizarProyecto(
    String eventId,
    String docId,
    Map<String, dynamic> nuevosDatos,
  ) async {
    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(docId)
          .update({...nuevosDatos, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error al actualizar proyecto: $e');
      rethrow;
    }
  }

  // Eliminar un proyecto individual de Firebase
  Future<void> eliminarProyectoIndividual(String eventId, String docId) async {
    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .doc(docId)
          .delete();

      await _firestore.collection('events').doc(eventId).update({
        'proyectosCount': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error al eliminar proyecto: $e');
      rethrow;
    }
  }

  // Eliminar todos los proyectos de Firebase
  Future<void> eliminarTodosLosProyectos(String eventId) async {
    try {
      final batch = _firestore.batch();

      final querySnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      await _firestore.collection('events').doc(eventId).update({
        'proyectosCount': 0,
        'lastImportAt': FieldValue.delete(),
      });
    } catch (e) {
      print('Error al eliminar todos los proyectos: $e');
      rethrow;
    }
  }

  // Agrupar proyectos por categoría
  Map<String, List<Map<String, dynamic>>> agruparPorCategoria(
    List<Map<String, dynamic>> proyectos,
  ) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};

    for (final proyecto in proyectos) {
      final categoria = proyecto['Clasificación'] ?? 'Sin categoría';
      if (!grupos.containsKey(categoria)) {
        grupos[categoria] = [];
      }
      grupos[categoria]!.add(proyecto);
    }

    return grupos;
  }

  // Formatear fecha de timestamp
  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }
}
