import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrefsHelper {
  static const String _keyUserType = 'user_type';
  static const String _keyUserName = 'user_name';
  static const String _keyUserId = 'user_id';
  static const String _keyIsLoggedIn = 'is_logged_in';

  // Tipos de usuario
  static const String userTypeAdmin = 'admin';
  static const String userTypeStudent = 'student';
  static const String userTypeAsistente = 'asistente';
  static const String userTypeJurado = 'jurado';

  // Credenciales por defecto del admin
  static const String adminEmail = 'admin';
  static const String adminPassword = 'admin123';

  // Credenciales por defecto del asistente
  static const String asistenteEmail = 'asistente';
  static const String asistentePassword = 'asistente123';

  // Credenciales por defecto del jurado
  static const String juradoEmail = 'jurado';
  static const String juradoPassword = 'jurado123';

  // Instancia de Firestore
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Guardar datos de usuario en SharedPreferences
  static Future<void> saveUserData({
    required String userType,
    required String userName,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserType, userType);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyUserId, userId);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  // Verificar si hay un usuario logueado
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Obtener ID de usuario actual
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  // Obtener tipo de usuario desde SharedPreferences
  static Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserType);
  }

  // Obtener nombre de usuario desde SharedPreferences
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<bool> loginAdmin(String email, String password) async {
    try {
      // Verificar si son credenciales de admin
      if (email.trim() == adminEmail && password == adminPassword) {
        final adminQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: adminEmail)
            .where('userType', isEqualTo: userTypeAdmin)
            .get();

        String adminId;
        if (adminQuery.docs.isEmpty) {
          final adminDoc = await _firestore.collection('users').add({
            'email': adminEmail,
            'password': adminPassword,
            'userType': userTypeAdmin,
            'name': 'Administrador',
            'createdAt': FieldValue.serverTimestamp(),
          });
          adminId = adminDoc.id;
          print('Admin creado exitosamente');
        } else {
          adminId = adminQuery.docs.first.id;
        }

        await saveUserData(
          userType: userTypeAdmin,
          userName: 'Administrador',
          userId: adminId,
        );
        return true;
      }
      // Verificar si son credenciales de asistente
      else if (email.trim() == asistenteEmail &&
          password == asistentePassword) {
        final asistenteQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: asistenteEmail)
            .where('userType', isEqualTo: userTypeAsistente)
            .get();

        String asistenteId;
        if (asistenteQuery.docs.isEmpty) {
          final asistenteDoc = await _firestore.collection('users').add({
            'email': asistenteEmail,
            'password': asistentePassword,
            'userType': userTypeAsistente,
            'name': 'Asistente',
            'createdAt': FieldValue.serverTimestamp(),
          });
          asistenteId = asistenteDoc.id;
          print('Asistente creado exitosamente');
        } else {
          asistenteId = asistenteQuery.docs.first.id;
        }

        await saveUserData(
          userType: userTypeAsistente,
          userName: 'Asistente',
          userId: asistenteId,
        );
        return true;
      } else {
        print('Credenciales de admin/asistente incorrectas');
        return false;
      }
    } catch (e) {
      print('Error en login admin/asistente: $e');
      return false;
    }
  }

  // Generar nombre de usuario basado en el nombre completo
  static String generateUsername(String fullName) {
    final nameParts = fullName.trim().toLowerCase().split(' ');

    if (nameParts.length >= 3) {
      return '${nameParts[0]}.${nameParts[2]}';
    } else if (nameParts.length == 2) {
      return '${nameParts[0]}.${nameParts[1]}';
    } else if (nameParts.length == 1) {
      return nameParts[0];
    }

    return fullName.toLowerCase().replaceAll(' ', '.');
  }

  // Login de estudiante - usar username y DNI como contraseña
  static Future<bool> loginStudent(String username, String password) async {
    try {
      final studentQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim().toLowerCase())
          .where('userType', isEqualTo: userTypeStudent)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        final studentDoc = studentQuery.docs.first;
        final studentData = studentDoc.data();

        // Verificar contraseña (debe ser el DNI/Documento)
        final storedPassword = studentData['dni'] ?? studentData['documento'];

        if (storedPassword == password) {
          await saveUserData(
            userType: userTypeStudent,
            userName: studentData['name'] ?? 'Estudiante',
            userId: studentDoc.id,
          );
          return true;
        }
      }

      print('Credenciales de estudiante incorrectas');
      return false;
    } catch (e) {
      print('Error en login estudiante: $e');
      return false;
    }
  }

  // Crear cuenta de estudiante con todos los campos del Excel
  static Future<bool> createStudentAccountWithUsername({
    required String email,
    required String name,
    required String username,
    required String codigoUniversitario,
    required String dni,
    required String facultad,
    required String carrera,
    // Nuevos campos opcionales del Excel
    String? modoContrato,
    String? modalidadEstudio,
    String? sede,
    String? ciclo,
    String? grupo,
    String? correoInstitucional,
    String? celular,
  }) async {
    try {
      // Verificar si ya existe un usuario con ese email
      final existingEmailUser = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .get();

      if (existingEmailUser.docs.isNotEmpty) {
        print('Ya existe un usuario con ese email');
        return false;
      }

      // Verificar si ya existe un usuario con ese código universitario
      final existingCodeUser = await _firestore
          .collection('users')
          .where('codigoUniversitario', isEqualTo: codigoUniversitario.trim())
          .get();

      if (existingCodeUser.docs.isNotEmpty) {
        print('Ya existe un usuario con ese código universitario');
        return false;
      }

      // Verificar si ya existe un usuario con ese DNI
      final existingDniUser = await _firestore
          .collection('users')
          .where('dni', isEqualTo: dni.trim())
          .get();

      if (existingDniUser.docs.isNotEmpty) {
        print('Ya existe un usuario con ese DNI');
        return false;
      }

      // Verificar si ya existe un usuario con ese username
      final existingUsernameUser = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase().trim())
          .get();

      if (existingUsernameUser.docs.isNotEmpty) {
        print('Ya existe un usuario con ese nombre de usuario: $username');
        return false;
      }

      // Preparar datos del estudiante
      final studentData = {
        'email': email.trim(),
        'name': name.trim(),
        'username': username.toLowerCase().trim(),
        'codigoUniversitario': codigoUniversitario.trim(),
        'dni': dni.trim(),
        'documento': dni.trim(), // Alias para compatibilidad
        'facultad': facultad,
        'carrera': carrera,
        'userType': userTypeStudent,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Agregar campos opcionales si están presentes
      if (modoContrato != null && modoContrato.isNotEmpty) {
        studentData['modoContrato'] = modoContrato;
      }
      if (modalidadEstudio != null && modalidadEstudio.isNotEmpty) {
        studentData['modalidadEstudio'] = modalidadEstudio;
      }
      if (sede != null && sede.isNotEmpty) {
        studentData['sede'] = sede;
      }
      if (ciclo != null && ciclo.isNotEmpty) {
        studentData['ciclo'] = ciclo;
      }
      if (grupo != null && grupo.isNotEmpty) {
        studentData['grupo'] = grupo;
      }
      if (correoInstitucional != null && correoInstitucional.isNotEmpty) {
        studentData['correoInstitucional'] = correoInstitucional.trim();
      }
      if (celular != null && celular.isNotEmpty) {
        studentData['celular'] = celular.trim();
      }

      // Crear estudiante en Firestore
      await _firestore.collection('users').add(studentData);

      print('Estudiante creado exitosamente: $username');
      return true;
    } catch (e) {
      print('Error creando cuenta de estudiante: $e');
      return false;
    }
  }

  // Obtener todos los estudiantes (para el admin) - incluyendo nuevos campos
  static Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      final studentsQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: userTypeStudent)
          .orderBy('createdAt', descending: true)
          .get();

      return studentsQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error obteniendo estudiantes: $e');
      return [];
    }
  }

  // Eliminar estudiante (solo admin)
  static Future<bool> deleteStudent(String studentId) async {
    try {
      await _firestore.collection('users').doc(studentId).delete();
      print('Estudiante eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error eliminando estudiante: $e');
      return false;
    }
  }

  // Eliminar múltiples estudiantes (eliminación masiva)
  static Future<Map<String, int>> deleteMultipleStudents(
    List<String> studentIds,
  ) async {
    int successCount = 0;
    int errorCount = 0;

    for (String studentId in studentIds) {
      try {
        await _firestore.collection('users').doc(studentId).delete();
        successCount++;
      } catch (e) {
        print('Error eliminando estudiante $studentId: $e');
        errorCount++;
      }
    }

    return {'success': successCount, 'errors': errorCount};
  }

  // Actualizar estudiante (para ediciones futuras)
  static Future<bool> updateStudent({
    required String studentId,
    String? name,
    String? email,
    String? codigoUniversitario,
    String? dni,
    String? facultad,
    String? carrera,
    String? modoContrato,
    String? modalidadEstudio,
    String? sede,
    String? ciclo,
    String? grupo,
    String? correoInstitucional,
    String? celular,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name.trim();
      if (email != null) updateData['email'] = email.trim();
      if (codigoUniversitario != null) {
        updateData['codigoUniversitario'] = codigoUniversitario.trim();
      }
      if (dni != null) {
        updateData['dni'] = dni.trim();
        updateData['documento'] = dni.trim();
      }
      if (facultad != null) updateData['facultad'] = facultad;
      if (carrera != null) updateData['carrera'] = carrera;
      if (modoContrato != null) updateData['modoContrato'] = modoContrato;
      if (modalidadEstudio != null) {
        updateData['modalidadEstudio'] = modalidadEstudio;
      }
      if (sede != null) updateData['sede'] = sede;
      if (ciclo != null) updateData['ciclo'] = ciclo;
      if (grupo != null) updateData['grupo'] = grupo;
      if (correoInstitucional != null) {
        updateData['correoInstitucional'] = correoInstitucional.trim();
      }
      if (celular != null) updateData['celular'] = celular.trim();

      await _firestore.collection('users').doc(studentId).update(updateData);

      print('Estudiante actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error actualizando estudiante: $e');
      return false;
    }
  }

  // Cambiar contraseña de estudiante
  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return false;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final storedPassword = userData['dni'] ?? userData['documento'];

      if (storedPassword != currentPassword) {
        print('Contraseña actual incorrecta');
        return false;
      }

      // Actualizar DNI (que funciona como contraseña)
      await _firestore.collection('users').doc(userId).update({
        'dni': newPassword,
        'documento': newPassword,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Contraseña actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error cambiando contraseña: $e');
      return false;
    }
  }

  // Obtener datos completos del usuario actual
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      userData['id'] = userDoc.id;
      return userData;
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
  }

  // Buscar estudiantes por filtros
  static Future<List<Map<String, dynamic>>> searchStudents({
    String? facultad,
    String? carrera,
    String? ciclo,
    String? grupo,
    String? sede,
    String? searchTerm,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('userType', isEqualTo: userTypeStudent);

      if (facultad != null && facultad.isNotEmpty) {
        query = query.where('facultad', isEqualTo: facultad);
      }
      if (carrera != null && carrera.isNotEmpty) {
        query = query.where('carrera', isEqualTo: carrera);
      }
      if (ciclo != null && ciclo.isNotEmpty) {
        query = query.where('ciclo', isEqualTo: ciclo);
      }
      if (grupo != null && grupo.isNotEmpty) {
        query = query.where('grupo', isEqualTo: grupo);
      }
      if (sede != null && sede.isNotEmpty) {
        query = query.where('sede', isEqualTo: sede);
      }

      final results = await query.get();
      List<Map<String, dynamic>> students = results.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Filtrar por término de búsqueda si existe
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        students = students.where((student) {
          final name = (student['name'] ?? '').toString().toLowerCase();
          final username = (student['username'] ?? '').toString().toLowerCase();
          final codigo = (student['codigoUniversitario'] ?? '')
              .toString()
              .toLowerCase();
          final dni = (student['dni'] ?? '').toString().toLowerCase();

          return name.contains(searchLower) ||
              username.contains(searchLower) ||
              codigo.contains(searchLower) ||
              dni.contains(searchLower);
        }).toList();
      }

      return students;
    } catch (e) {
      print('Error buscando estudiantes: $e');
      return [];
    }
  }

  // CREAR CUENTA DE JURADO - ACTUALIZADO CON USUARIO
  static Future<bool> createJuradoAccount({
    required String nombre,
    required String usuario,
    required String password,
    required String facultad,
    required String carrera,
    required String categoria,
  }) async {
    try {
      // Verificar si ya existe un jurado con ese usuario
      final existingJurado = await _firestore
          .collection('users')
          .where('usuario', isEqualTo: usuario.trim().toLowerCase())
          .where('userType', isEqualTo: userTypeJurado)
          .get();

      if (existingJurado.docs.isNotEmpty) {
        print('Ya existe un jurado con ese nombre de usuario');
        return false;
      }

      // Crear jurado en Firestore con los nuevos campos
      await _firestore.collection('users').add({
        'usuario': usuario.trim().toLowerCase(),
        'password': password,
        'userType': userTypeJurado,
        'name': nombre.trim(),
        'facultad': facultad,
        'carrera': carrera,
        'categoria': categoria,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Jurado creado exitosamente: $nombre');
      return true;
    } catch (e) {
      print('Error creando cuenta de jurado: $e');
      return false;
    }
  }

  // LOGIN DE JURADO - ACTUALIZADO CON LOGS DE DEPURACIÓN
  static Future<bool> loginJurado(String usuario, String password) async {
    try {
      print('🔍 Intentando login jurado con usuario: $usuario');

      // Verificar si es el jurado por defecto
      if (usuario.trim().toLowerCase() == juradoEmail &&
          password == juradoPassword) {
        print('✅ Credenciales de jurado por defecto detectadas');

        final juradoQuery = await _firestore
            .collection('users')
            .where('usuario', isEqualTo: juradoEmail)
            .where('userType', isEqualTo: userTypeJurado)
            .get();

        String juradoId;
        if (juradoQuery.docs.isEmpty) {
          final juradoDoc = await _firestore.collection('users').add({
            'usuario': juradoEmail,
            'password': juradoPassword,
            'userType': userTypeJurado,
            'name': 'Jurado',
            'createdAt': FieldValue.serverTimestamp(),
          });
          juradoId = juradoDoc.id;
          print('✅ Jurado por defecto creado exitosamente con ID: $juradoId');
        } else {
          juradoId = juradoQuery.docs.first.id;
          print('✅ Jurado por defecto encontrado con ID: $juradoId');
        }

        await saveUserData(
          userType: userTypeJurado,
          userName: 'Jurado',
          userId: juradoId,
        );

        // Verificar que se guardó correctamente
        final savedUserType = await getUserType();
        print('✅ UserType guardado: $savedUserType');
        print('✅ Login de jurado por defecto completado');

        return true;
      }

      // Buscar jurado personalizado por usuario
      print(
        '🔍 Buscando jurado personalizado con usuario: ${usuario.trim().toLowerCase()}',
      );
      final juradoQuery = await _firestore
          .collection('users')
          .where('usuario', isEqualTo: usuario.trim().toLowerCase())
          .where('userType', isEqualTo: userTypeJurado)
          .get();

      if (juradoQuery.docs.isNotEmpty) {
        final juradoDoc = juradoQuery.docs.first;
        final juradoData = juradoDoc.data();

        print('✅ Jurado encontrado: ${juradoData['name']}');

        // Verificar contraseña
        if (juradoData['password'] == password) {
          await saveUserData(
            userType: userTypeJurado,
            userName: juradoData['name'] ?? 'Jurado',
            userId: juradoDoc.id,
          );

          // Verificar que se guardó correctamente
          final savedUserType = await getUserType();
          print('✅ UserType guardado: $savedUserType');
          print('✅ Login de jurado personalizado completado');

          return true;
        } else {
          print('❌ Contraseña incorrecta para el jurado');
        }
      } else {
        print('❌ Jurado no encontrado con usuario: $usuario');
      }

      return false;
    } catch (e) {
      print('❌ Error en login de jurado: $e');
      return false;
    }
  }

  // Obtener todos los jurados
  static Future<List<Map<String, dynamic>>> getJurados() async {
    try {
      final juradosQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: userTypeJurado)
          .orderBy('createdAt', descending: true)
          .get();

      return juradosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error obteniendo jurados: $e');
      return [];
    }
  }

  // Eliminar jurado
  static Future<bool> deleteJurado(String juradoId) async {
    try {
      await _firestore.collection('users').doc(juradoId).delete();
      print('Jurado eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error eliminando jurado: $e');
      return false;
    }
  }

  static Future<bool> updateJurado({
    required String juradoId,
    String? nombre,
    String? usuario,
    String? password,
    String? facultad,
    String? carrera,
    String? categoria,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nombre != null && nombre.isNotEmpty) {
        updateData['name'] = nombre.trim();
      }
      if (usuario != null && usuario.isNotEmpty) {
        updateData['usuario'] = usuario.trim().toLowerCase();
      }
      if (password != null && password.isNotEmpty) {
        updateData['password'] = password;
      }
      if (facultad != null && facultad.isNotEmpty) {
        updateData['facultad'] = facultad;
      }
      if (carrera != null && carrera.isNotEmpty) {
        updateData['carrera'] = carrera;
      }
      if (categoria != null && categoria.isNotEmpty) {
        updateData['categoria'] = categoria;
      }

      await _firestore.collection('users').doc(juradoId).update(updateData);
      print('Jurado actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error actualizando jurado: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> searchJurados({
    String? facultad,
    String? carrera,
    String? categoria,
    String? searchTerm,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('userType', isEqualTo: userTypeJurado);

      if (facultad != null && facultad.isNotEmpty) {
        query = query.where('facultad', isEqualTo: facultad);
      }
      if (carrera != null && carrera.isNotEmpty) {
        query = query.where('carrera', isEqualTo: carrera);
      }
      if (categoria != null && categoria.isNotEmpty) {
        query = query.where('categoria', isEqualTo: categoria);
      }

      final results = await query.get();
      List<Map<String, dynamic>> jurados = results.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Filtrar por término de búsqueda si existe
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        jurados = jurados.where((jurado) {
          final name = (jurado['name'] ?? '').toString().toLowerCase();
          final usuario = (jurado['usuario'] ?? '').toString().toLowerCase();

          return name.contains(searchLower) || usuario.contains(searchLower);
        }).toList();
      }

      return jurados;
    } catch (e) {
      print('Error buscando jurados: $e');
      return [];
    }
  }

  static Future<Map<String, int>> deleteAllStudents() async {
    try {
      final studentsQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: userTypeStudent)
          .get();

      int successCount = 0;
      int errorCount = 0;

      for (var doc in studentsQuery.docs) {
        try {
          await doc.reference.delete();
          successCount++;
        } catch (e) {
          print('Error eliminando estudiante ${doc.id}: $e');
          errorCount++;
        }
      }

      return {'success': successCount, 'errors': errorCount};
    } catch (e) {
      print('Error eliminando todos los estudiantes: $e');
      return {'success': 0, 'errors': -1};
    }
  }

  // Cerrar sesión
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserType);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserId);
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}
