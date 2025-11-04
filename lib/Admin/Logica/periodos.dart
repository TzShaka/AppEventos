import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'periodos_helper.dart';

class PeriodosScreen extends StatefulWidget {
  const PeriodosScreen({super.key});

  @override
  State<PeriodosScreen> createState() => _PeriodosScreenState();
}

class _PeriodosScreenState extends State<PeriodosScreen> {
  List<Map<String, dynamic>> _periodos = [];
  List<Map<String, dynamic>> _filteredPeriodos = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPeriodos();
  }

  Future<void> _loadPeriodos() async {
    setState(() => _isLoading = true);
    final periodos = await PeriodosHelper.getPeriodos();
    setState(() {
      _periodos = periodos;
      _filteredPeriodos = periodos;
      _isLoading = false;
    });
  }

  void _filterPeriodos(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPeriodos = _periodos;
      } else {
        _filteredPeriodos = _periodos.where((periodo) {
          final nombre = periodo['nombre'].toString().toLowerCase();
          return nombre.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showCreateDialog() {
    final nombreController = TextEditingController();
    DateTime? fechaInicio;
    DateTime? fechaFin;
    bool activo = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear Período'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Período',
                    hintText: 'Ej: 2025-I',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Fecha de Inicio'),
                  subtitle: Text(
                    fechaInicio != null
                        ? DateFormat('dd/MM/yyyy').format(fechaInicio!)
                        : 'Seleccionar fecha',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => fechaInicio = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Fecha de Fin'),
                  subtitle: Text(
                    fechaFin != null
                        ? DateFormat('dd/MM/yyyy').format(fechaFin!)
                        : 'Seleccionar fecha',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fechaInicio ?? DateTime.now(),
                      firstDate: fechaInicio ?? DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => fechaFin = picked);
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Período Activo'),
                  subtitle: const Text('Solo puede haber un período activo'),
                  value: activo,
                  onChanged: (value) {
                    setDialogState(() => activo = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingrese el nombre del período'),
                    ),
                  );
                  return;
                }
                if (fechaInicio == null || fechaFin == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seleccione las fechas')),
                  );
                  return;
                }
                if (fechaFin!.isBefore(fechaInicio!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La fecha de fin debe ser posterior'),
                    ),
                  );
                  return;
                }

                final success = await PeriodosHelper.createPeriodo(
                  nombre: nombreController.text,
                  fechaInicio: fechaInicio!,
                  fechaFin: fechaFin!,
                  activo: activo,
                );

                if (success) {
                  Navigator.pop(context);
                  _loadPeriodos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Período creado exitosamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al crear el período'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> periodo) {
    final nombreController = TextEditingController(text: periodo['nombre']);
    DateTime? fechaInicio = (periodo['fechaInicio'] as Timestamp).toDate();
    DateTime? fechaFin = (periodo['fechaFin'] as Timestamp).toDate();
    bool activo = periodo['activo'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Período'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Período',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Fecha de Inicio'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(fechaInicio!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fechaInicio,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => fechaInicio = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Fecha de Fin'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(fechaFin!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fechaFin,
                      firstDate: fechaInicio ?? DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => fechaFin = picked);
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Período Activo'),
                  subtitle: const Text('Solo puede haber un período activo'),
                  value: activo,
                  onChanged: (value) {
                    setDialogState(() => activo = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingrese el nombre del período'),
                    ),
                  );
                  return;
                }
                if (fechaFin!.isBefore(fechaInicio!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La fecha de fin debe ser posterior'),
                    ),
                  );
                  return;
                }

                final success = await PeriodosHelper.updatePeriodo(
                  periodoId: periodo['id'],
                  nombre: nombreController.text,
                  fechaInicio: fechaInicio,
                  fechaFin: fechaFin,
                  activo: activo,
                );

                if (success) {
                  Navigator.pop(context);
                  _loadPeriodos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Período actualizado exitosamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al actualizar el período'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> periodo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Período'),
        content: Text(
          '¿Está seguro que desea eliminar el período "${periodo['nombre']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await PeriodosHelper.deletePeriodo(periodo['id']);
              if (success) {
                Navigator.pop(context);
                _loadPeriodos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Período eliminado exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al eliminar el período'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gestión de Períodos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE8EDF2),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _filterPeriodos,
                decoration: InputDecoration(
                  hintText: 'Buscar período...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPeriodos('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Lista de períodos
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPeriodos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay períodos registrados',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredPeriodos.length,
                      itemBuilder: (context, index) {
                        final periodo = _filteredPeriodos[index];
                        final fechaInicio =
                            (periodo['fechaInicio'] as Timestamp).toDate();
                        final fechaFin = (periodo['fechaFin'] as Timestamp)
                            .toDate();
                        final activo = periodo['activo'] ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: activo
                                ? const BorderSide(
                                    color: Colors.green,
                                    width: 2,
                                  )
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: activo
                                  ? Colors.green
                                  : const Color(0xFF1E3A5F),
                              child: Icon(
                                activo
                                    ? Icons.check_circle
                                    : Icons.calendar_month,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              periodo['nombre'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Inicio: ${DateFormat('dd/MM/yyyy').format(fechaInicio)}',
                                ),
                                Text(
                                  'Fin: ${DateFormat('dd/MM/yyyy').format(fechaFin)}',
                                ),
                                if (activo)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'PERÍODO ACTIVO',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditDialog(periodo);
                                } else if (value == 'delete') {
                                  _showDeleteDialog(periodo);
                                } else if (value == 'activate') {
                                  PeriodosHelper.activarPeriodo(
                                    periodo['id'],
                                  ).then((success) {
                                    if (success) {
                                      _loadPeriodos();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Período activado exitosamente',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  });
                                } else if (value == 'deactivate') {
                                  PeriodosHelper.desactivarPeriodo(
                                    periodo['id'],
                                  ).then((success) {
                                    if (success) {
                                      _loadPeriodos();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Período desactivado exitosamente',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  });
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Editar'),
                                    ],
                                  ),
                                ),
                                if (!activo)
                                  const PopupMenuItem(
                                    value: 'activate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, size: 20),
                                        SizedBox(width: 8),
                                        Text('Activar'),
                                      ],
                                    ),
                                  ),
                                if (activo)
                                  const PopupMenuItem(
                                    value: 'deactivate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.cancel, size: 20),
                                        SizedBox(width: 8),
                                        Text('Desactivar'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Eliminar',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF1E3A5F),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Período'),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
