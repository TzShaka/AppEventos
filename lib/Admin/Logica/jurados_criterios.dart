import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'criterios.dart';

class JuradosCriteriosScreen extends StatefulWidget {
  const JuradosCriteriosScreen({super.key});

  @override
  State<JuradosCriteriosScreen> createState() => _JuradosCriteriosScreenState();
}

class _JuradosCriteriosScreenState extends State<JuradosCriteriosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _juradosConGrupos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarJuradosConGrupos();
  }

  Future<void> _cargarJuradosConGrupos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Map para almacenar jurados únicos con sus datos
      final Map<String, Map<String, dynamic>> juradosMap = {};

      // Consulta optimizada: Usar collectionGroup para obtener TODAS las evaluaciones
      // de todos los proyectos en una sola consulta
      final evaluacionesSnapshot = await _firestore
          .collectionGroup('evaluaciones')
          .get();

      print(
        'Total evaluaciones encontradas: ${evaluacionesSnapshot.docs.length}',
      );

      // Procesar todas las evaluaciones
      for (var evaluacionDoc in evaluacionesSnapshot.docs) {
        final evaluacionData = evaluacionDoc.data();
        final juradoId = evaluacionData['juradoId'] as String?;
        final codigoGrupo = evaluacionData['codigoGrupo'] as String?;

        if (juradoId != null && codigoGrupo != null) {
          // Si el jurado no existe, agregarlo con su información
          if (!juradosMap.containsKey(juradoId)) {
            // Obtener el path del documento para extraer eventId y proyectoId
            final pathSegments = evaluacionDoc.reference.path.split('/');
            final eventId = pathSegments[1]; // events/{eventId}
            final proyectoId = pathSegments[3]; // proyectos/{proyectoId}

            juradosMap[juradoId] = {
              'juradoId': juradoId,
              'juradoNombre': evaluacionData['juradoNombre'] ?? 'Sin nombre',
              'juradoUsuario': evaluacionData['juradoUsuario'] ?? '',
              'facultad': evaluacionData['facultad'] ?? '',
              'carrera': evaluacionData['carrera'] ?? '',
              'categoria': evaluacionData['categoria'] ?? '',
              'grupos': <String>{}, // Set para evitar duplicados
              'criterios': evaluacionData['criterios'] ?? [],
              'eventId': eventId,
              'proyectoId': proyectoId,
            };
          }

          // Agregar el grupo al set del jurado
          (juradosMap[juradoId]!['grupos'] as Set<String>).add(codigoGrupo);
        }
      }

      // Convertir el Map a List y los Sets a Lists
      final juradosList = juradosMap.values.map((jurado) {
        return {
          ...jurado,
          'grupos': (jurado['grupos'] as Set<String>).toList()..sort(),
        };
      }).toList();

      // Ordenar por nombre de jurado
      juradosList.sort(
        (a, b) => (a['juradoNombre'] as String).compareTo(
          b['juradoNombre'] as String,
        ),
      );

      print('Total jurados con grupos: ${juradosList.length}');

      if (mounted) {
        setState(() {
          _juradosConGrupos = juradosList;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar jurados con grupos: $e');
      if (mounted) {
        setState(() {
          _error = 'Error al cargar los datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerProyectosPorGrupos(
    String eventId,
    List<String> grupos,
  ) async {
    final List<Map<String, dynamic>> proyectos = [];

    try {
      // Obtener todos los proyectos del evento
      final proyectosSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('proyectos')
          .get();

      for (var proyectoDoc in proyectosSnapshot.docs) {
        final data = proyectoDoc.data();
        final codigo = data['Código'] ?? '';

        if (grupos.contains(codigo)) {
          proyectos.add({
            'id': proyectoDoc.id,
            'eventId': eventId,
            'codigo': codigo,
            'titulo': data['Título'] ?? '',
            'integrantes': data['Integrantes'] ?? '',
            'sala': data['Sala'] ?? '',
          });
        }
      }
    } catch (e) {
      print('Error al obtener proyectos: $e');
    }

    return proyectos;
  }

  void _navegarACriterios(Map<String, dynamic> jurado) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      // Obtener los proyectos completos de los grupos asignados
      final proyectos = await _obtenerProyectosPorGrupos(
        jurado['eventId'],
        List<String>.from(jurado['grupos']),
      );

      if (!mounted) return;

      // Cerrar loading
      Navigator.pop(context);

      // Navegar a CriteriosScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CriteriosScreen(
            facultad: jurado['facultad'],
            carrera: jurado['carrera'],
            categoria: jurado['categoria'],
            juradoId: jurado['juradoId'],
            juradoData: {
              'nombre': jurado['juradoNombre'],
              'usuario': jurado['juradoUsuario'],
              'categoria': jurado['categoria'],
            },
            gruposSeleccionados: List<String>.from(jurado['grupos']),
            proyectos: proyectos,
          ),
        ),
      ).then((_) {
        // Recargar la lista cuando regrese
        _cargarJuradosConGrupos();
      });
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context); // Cerrar loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
                      'Jurados con Grupos Asignados',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _isLoading ? null : _cargarJuradosConGrupos,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),

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
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Cargando jurados...',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Error al cargar datos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _cargarJuradosConGrupos,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_juradosConGrupos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay jurados con grupos asignados',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Asigna grupos a los jurados desde\nConfigurar Evaluación',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _juradosConGrupos.length,
      itemBuilder: (context, index) {
        final jurado = _juradosConGrupos[index];
        final grupos = jurado['grupos'] as List<String>;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _navegarACriterios(jurado),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header del jurado
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF1E3A5F),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jurado['juradoNombre'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${jurado['juradoUsuario']}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Información adicional
                  _buildInfoChip(Icons.school, jurado['facultad']),
                  const SizedBox(height: 8),
                  _buildInfoChip(Icons.book, jurado['carrera']),
                  const SizedBox(height: 8),
                  _buildInfoChip(Icons.category, jurado['categoria']),

                  const SizedBox(height: 16),

                  // Grupos asignados
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4CAF50),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.groups,
                              color: Color(0xFF2E7D32),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${grupos.length} Grupo${grupos.length != 1 ? 's' : ''} Asignado${grupos.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: grupos.take(5).map((grupo) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF4CAF50),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                grupo,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (grupos.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '+ ${grupos.length - 5} más',
                              style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}
