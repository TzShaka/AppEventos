import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EvaluacionesExcelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Genera y descarga un reporte de evaluaciones en formato Excel
  Future<String> generarReporteEvaluaciones({
    required String juradoId,
    required String juradoNombre,
    required String facultad,
    required String carrera,
    required String categoria,
    required List<String> gruposSeleccionados,
    required List<Map<String, dynamic>> proyectos,
  }) async {
    // Obtener todas las evaluaciones
    final List<Map<String, dynamic>> todasLasEvaluaciones = [];

    for (final codigoGrupo in gruposSeleccionados) {
      try {
        final proyecto = proyectos.firstWhere(
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
            .doc(juradoId)
            .get();

        if (snapshot.exists) {
          final data = snapshot.data()!;
          todasLasEvaluaciones.add({
            ...data,
            'eventId': eventId,
            'proyectoId': proyectoId,
            'codigoGrupo': codigoGrupo,
            'tituloProyecto': proyecto['titulo'] ?? 'Sin título',
            'integrantes': proyecto['integrantes'] ?? '',
            'sala': proyecto['sala'] ?? '',
          });
        }
      } catch (e) {
        print('Error al cargar evaluación de $codigoGrupo: $e');
      }
    }

    if (todasLasEvaluaciones.isEmpty) {
      throw Exception(
        'No hay evaluaciones disponibles para generar el reporte',
      );
    }

    // Crear el libro de Excel
    final excel = Excel.createExcel();

    // Eliminar la hoja por defecto
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Crear la única hoja con toda la información
    _construirHojaCompleta(
      excel,
      todasLasEvaluaciones,
      juradoNombre,
      facultad,
      carrera,
      categoria,
    );

    // Guardar el archivo
    final filePath = await _guardarArchivo(
      excel,
      juradoNombre,
      carrera,
      categoria,
    );

    return filePath;
  }

  void _construirHojaCompleta(
    Excel excel,
    List<Map<String, dynamic>> evaluaciones,
    String juradoNombre,
    String facultad,
    String carrera,
    String categoria,
  ) {
    final sheet = excel['Reporte de Evaluaciones'];

    // Título principal
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('J1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
      'REPORTE DE EVALUACIONES - $facultad - $carrera',
    );
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
    );

    // Información del jurado y fecha
    var row = 2;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(
      'Jurado Evaluador: $juradoNombre',
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
    );

    row++;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(
      'Categoría: $categoria',
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = CellStyle(
      fontSize: 11,
    );

    row++;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(
      'Fecha de generación: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = CellStyle(
      fontSize: 11,
      italic: true,
    );

    // Obtener criterios de la primera evaluación
    List<dynamic> criterios = [];
    if (evaluaciones.isNotEmpty) {
      criterios = evaluaciones[0]['criterios'] as List<dynamic>? ?? [];
    }

    // Construir headers dinámicamente
    row += 2;
    final baseHeaders = [
      'N°',
      'Código Proyecto',
      'Categoría',
      'Título del Proyecto',
      'Integrantes',
      'Sala',
      'Jurado',
      'Estado',
    ];

    final headers = [...baseHeaders];

    // Agregar headers de criterios
    for (var i = 0; i < criterios.length; i++) {
      final criterio = criterios[i];
      headers.add('${criterio['descripcion']}\n(${criterio['escala']})');
    }

    headers.add('Nota Total');
    headers.add('Fecha Evaluación');

    // Escribir headers
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );
    }

    // Datos de las evaluaciones
    row++;
    var contador = 1;

    for (final eval in evaluaciones) {
      final evaluada = eval['evaluada'] ?? false;
      final bloqueada = eval['bloqueada'] ?? false;
      final notas = eval['notas'] as Map<String, dynamic>? ?? {};
      final notaTotal = eval['notaTotal'] ?? 0;
      final fecha = eval['fechaEvaluacion'] as Timestamp?;

      var col = 0;

      // Color de fondo según estado
      final bgColor = evaluada
          ? ExcelColor.fromHexString('#D4EDDA')
          : ExcelColor.fromHexString('#FFF3CD');

      // N°
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = IntCellValue(contador);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Código Proyecto
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['codigoGrupo']);
      cell.cellStyle = CellStyle(backgroundColorHex: bgColor, bold: true);

      // Categoría
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(categoria);
      cell.cellStyle = CellStyle(backgroundColorHex: bgColor);

      // Título del Proyecto
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['tituloProyecto']);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        textWrapping: TextWrapping.WrapText,
      );

      // Integrantes
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['integrantes']);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        textWrapping: TextWrapping.WrapText,
      );

      // Sala
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(eval['sala']);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Jurado
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      cell.value = TextCellValue(juradoNombre);
      cell.cellStyle = CellStyle(backgroundColorHex: bgColor, bold: true);

      // Estado
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      String estadoTexto = evaluada ? 'Evaluada' : 'Pendiente';
      if (bloqueada) estadoTexto += ' (Bloqueada)';
      cell.value = TextCellValue(estadoTexto);
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Notas por criterio
      if (evaluada) {
        for (var i = 0; i < criterios.length; i++) {
          final nota = notas[i.toString()] ?? 0;
          cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
          );
          cell.value = TextCellValue(nota.toString());
          cell.cellStyle = CellStyle(
            backgroundColorHex: bgColor,
            horizontalAlign: HorizontalAlign.Center,
          );
        }

        // Nota Total
        cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
        );
        cell.value = TextCellValue(notaTotal.toStringAsFixed(2));
        cell.cellStyle = CellStyle(
          backgroundColorHex: bgColor,
          horizontalAlign: HorizontalAlign.Center,
          bold: true,
        );
      } else {
        // Si no está evaluada, llenar con guiones
        for (var i = 0; i < criterios.length + 1; i++) {
          cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
          );
          cell.value = TextCellValue('-');
          cell.cellStyle = CellStyle(
            backgroundColorHex: bgColor,
            horizontalAlign: HorizontalAlign.Center,
            italic: true,
          );
        }
      }

      // Fecha de Evaluación
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row),
      );
      if (fecha != null && evaluada) {
        final fechaFormat = fecha.toDate();
        cell.value = TextCellValue(
          DateFormat('dd/MM/yyyy HH:mm').format(fechaFormat),
        );
      } else {
        cell.value = TextCellValue('-');
      }
      cell.cellStyle = CellStyle(
        backgroundColorHex: bgColor,
        horizontalAlign: HorizontalAlign.Center,
      );

      row++;
      contador++;
    }

    // Agregar fila de resumen al final
    row++;

    // Calcular estadísticas
    final totalEvaluaciones = evaluaciones.length;
    final evaluacionesCompletas = evaluaciones
        .where((e) => e['evaluada'] == true)
        .length;
    final evaluacionesPendientes = totalEvaluaciones - evaluacionesCompletas;

    final notasEvaluadas = evaluaciones
        .where((e) => e['evaluada'] == true)
        .map((e) => (e['notaTotal'] as num).toDouble())
        .toList();

    final promedioNotas = notasEvaluadas.isNotEmpty
        ? notasEvaluadas.reduce((a, b) => a + b) / notasEvaluadas.length
        : 0.0;

    // Fusionar celdas para "RESUMEN:"
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
    );

    var resumenCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
    );
    resumenCell.value = TextCellValue('RESUMEN:');
    resumenCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFC107'),
      horizontalAlign: HorizontalAlign.Center,
      fontSize: 12,
    );

    // Total Proyectos
    var startCol = 3;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row),
    );
    var totalCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
    );
    totalCell.value = TextCellValue('Total: $totalEvaluaciones');
    totalCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Evaluadas
    startCol += 2;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row),
    );
    var evaluadasCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
    );
    evaluadasCell.value = TextCellValue('Evaluadas: $evaluacionesCompletas');
    evaluadasCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Pendientes
    startCol += 2;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row),
    );
    var pendientesCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
    );
    pendientesCell.value = TextCellValue('Pendientes: $evaluacionesPendientes');
    pendientesCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Promedio
    startCol += 2;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row),
    );
    var promedioCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row),
    );
    promedioCell.value = TextCellValue(
      'Promedio: ${promedioNotas.toStringAsFixed(2)}',
    );
    promedioCell.cellStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFF9C4'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Ajustar ancho de columnas
    sheet.setColumnWidth(0, 8); // N°
    sheet.setColumnWidth(1, 15); // Código
    sheet.setColumnWidth(2, 20); // Categoría
    sheet.setColumnWidth(3, 50); // Título
    sheet.setColumnWidth(4, 40); // Integrantes
    sheet.setColumnWidth(5, 10); // Sala
    sheet.setColumnWidth(6, 25); // Jurado
    sheet.setColumnWidth(7, 15); // Estado

    // Columnas de criterios
    for (var i = 0; i < criterios.length; i++) {
      sheet.setColumnWidth(8 + i, 12);
    }

    // Nota Total y Fecha
    sheet.setColumnWidth(8 + criterios.length, 12);
    sheet.setColumnWidth(9 + criterios.length, 18);
  }

  /// Guarda el archivo Excel en el dispositivo
  Future<String> _guardarArchivo(
    Excel excel,
    String juradoNombre,
    String carrera,
    String categoria,
  ) async {
    try {
      // Solicitar permisos según la versión de Android
      if (Platform.isAndroid) {
        if (await Permission.photos.isPermanentlyDenied ||
            await Permission.videos.isPermanentlyDenied) {
          await openAppSettings();
          throw Exception('Por favor, habilita los permisos en configuración');
        }

        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();

        if (!statuses.values.every((status) => status.isGranted)) {
          var storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            var manageStatus = await Permission.manageExternalStorage.request();
            if (!manageStatus.isGranted) {
              throw Exception('Permisos de almacenamiento denegados');
            }
          }
        }
      }

      // Generar nombre de archivo
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final nombreCarrera = carrera.replaceAll(' ', '_');
      final nombreJurado = juradoNombre.replaceAll(' ', '_');
      final nombreCategoria = categoria.replaceAll(' ', '_');

      final fileName =
          'Evaluaciones_${nombreCarrera}_${nombreCategoria}_${nombreJurado}_$timestamp.xlsx';

      // Obtener directorio
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Documents');
        if (!await directory.exists()) {
          try {
            await directory.create(recursive: true);
          } catch (e) {
            directory = Directory('/storage/emulated/0/Download');
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('No se pudo acceder al directorio de descargas');
      }

      // Guardar archivo
      final filePath = '${directory.path}/$fileName';
      final fileBytes = excel.save();

      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        print('✅ Archivo guardado exitosamente en: $filePath');
        print('📁 Ubicación: Documentos del dispositivo');
        return filePath;
      } else {
        throw Exception('Error al generar el archivo Excel');
      }
    } catch (e) {
      print('Error al guardar archivo: $e');
      rethrow;
    }
  }
}
