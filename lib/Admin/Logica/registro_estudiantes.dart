import 'package:flutter/material.dart';
import '/prefs_helper.dart';
import 'estudiantes_registrados.dart';
import 'datos_excel.dart';

class RegistroEstudiantesScreen extends StatefulWidget {
  const RegistroEstudiantesScreen({super.key});

  @override
  State<RegistroEstudiantesScreen> createState() =>
      _RegistroEstudiantesScreenState();
}

class _RegistroEstudiantesScreenState extends State<RegistroEstudiantesScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _codigoEstudianteController = TextEditingController();
  final _documentoController = TextEditingController();
  final _correoController = TextEditingController();
  final _celularController = TextEditingController();
  final _usernameController = TextEditingController();

  late AnimationController _headerAnimationController;
  late AnimationController _formAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _formFadeAnimation;

  bool _isLoading = false;
  String? _selectedModoContrato;
  String? _selectedModalidadEstudio;
  String? _selectedFacultad;
  String? _selectedCarrera;
  String? _selectedCiclo;
  String? _selectedGrupo;

  final List<String> _modosContrato = ['Regular', 'Convenio', 'Especial'];
  final List<String> _modalidadesEstudio = [
    'Presencial',
    'Semipresencial',
    'Virtual',
  ];
  final List<String> _ciclos = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
  ];
  final List<String> _grupos = ['Único', '1', '2', '3', '4'];

  final Map<String, List<String>> _facultadesCarreras = {
    'Facultad de Ciencias Empresariales': [
      'EP Administración',
      'EP Contabilidad',
      'EP Gestión Tributaria y Aduanera',
    ],
    'Facultad de Ciencias Humanas y Educación': [
      'EP Educación, Especialidad Inicial y Puericultura',
      'EP Educación, Especialidad Primaria y Pedagogía Terapéutica',
      'EP Educación, Especialidad Inglés y Español',
    ],
    'Facultad de Ciencias de la Salud': [
      'EP Enfermería',
      'EP Nutrición Humana',
      'EP Psicología',
    ],
    'Facultad de Ingeniería y Arquitectura': [
      'EP Ingeniería Civil',
      'EP Arquitectura y Urbanismo',
      'EP Ingeniería Ambiental',
      'EP Ingeniería de Industrias Alimentarias',
      'EP Ingeniería de Sistemas',
    ],
  };

  @override
  void initState() {
    super.initState();

    // Inicializar animaciones
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formAnimationController, curve: Curves.easeIn),
    );

    // Iniciar animaciones
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _formAnimationController.forward();
    });

    _nombresController.addListener(_generateUsernameSuggestion);
    _apellidosController.addListener(_generateUsernameSuggestion);
    _correoController.addListener(_extractUsernameFromEmail);
  }

  void _extractUsernameFromEmail() {
    final correo = _correoController.text.trim();
    if (correo.contains('@upeu.edu.pe') && _usernameController.text.isEmpty) {
      final username = correo.split('@')[0];
      if (username.isNotEmpty) {
        _usernameController.text = username;
      }
    }
  }

  void _generateUsernameSuggestion() {
    if (_usernameController.text.isEmpty) {
      final nombres = _nombresController.text.trim();
      final apellidos = _apellidosController.text.trim();
      final suggestion = _generateUsernameFromNamesAndSurnames(
        nombres,
        apellidos,
      );
      if (suggestion.isNotEmpty) {
        _usernameController.text = suggestion;
      }
    }
  }

  String _generateUsernameFromNamesAndSurnames(
    String nombres,
    String apellidos,
  ) {
    if (nombres.isEmpty && apellidos.isEmpty) return '';

    final nombresList = nombres
        .toLowerCase()
        .split(' ')
        .where((name) => name.isNotEmpty)
        .toList();
    final apellidosList = apellidos
        .toLowerCase()
        .split(' ')
        .where((surname) => surname.isNotEmpty)
        .toList();

    String username = '';
    if (nombresList.isNotEmpty) {
      username = nombresList[0];
    }
    if (apellidosList.isNotEmpty) {
      if (username.isNotEmpty) {
        username += '.${apellidosList[0]}';
      } else {
        username = apellidosList[0];
      }
    }
    return _cleanUsername(username);
  }

  String _cleanUsername(String input) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };

    String cleaned = input.toLowerCase();
    accents.forEach((accent, replacement) {
      cleaned = cleaned.replaceAll(accent, replacement);
    });
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9.]'), '');
    return cleaned;
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _formAnimationController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _codigoEstudianteController.dispose();
    _documentoController.dispose();
    _correoController.dispose();
    _celularController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _createStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedModoContrato == null) {
      _showMessage('Por favor selecciona el modo de contrato');
      return;
    }
    if (_selectedModalidadEstudio == null) {
      _showMessage('Por favor selecciona la modalidad de estudio');
      return;
    }
    if (_selectedFacultad == null) {
      _showMessage('Por favor selecciona una facultad');
      return;
    }
    if (_selectedCarrera == null) {
      _showMessage('Por favor selecciona una carrera');
      return;
    }
    if (_selectedCiclo == null) {
      _showMessage('Por favor selecciona el ciclo');
      return;
    }
    if (_selectedGrupo == null) {
      _showMessage('Por favor selecciona el grupo');
      return;
    }

    final fullName =
        '${_nombresController.text.trim()} ${_apellidosController.text.trim()}';
    final username = _usernameController.text.trim().toLowerCase();

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await PrefsHelper.createStudentAccountWithUsername(
        email: _correoController.text.trim(),
        name: fullName,
        username: username,
        codigoUniversitario: _codigoEstudianteController.text.trim(),
        dni: _documentoController.text.trim(),
        facultad: _selectedFacultad!,
        carrera: _selectedCarrera!,
        modoContrato: _selectedModoContrato,
        modalidadEstudio: _selectedModalidadEstudio,
        ciclo: _selectedCiclo,
        grupo: _selectedGrupo,
        celular: _celularController.text.trim(),
      );

      if (success) {
        _showSuccessDialog(
          username,
          _documentoController.text.trim(),
          fullName,
        );
        _clearForm();
      } else {
        _showMessage('Error: Ya existe un usuario con esos datos');
      }
    } catch (e) {
      _showMessage('Error creando estudiante: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showSuccessDialog(
    String username,
    String password,
    String studentName,
  ) async {
    return await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text(
              'Estudiante Creado',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El estudiante $studentName ha sido registrado exitosamente.',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1E3A5F).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key, color: Color(0xFF1E3A5F), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Credenciales de Acceso',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCredentialRow('Usuario:', username),
                    const SizedBox(height: 8),
                    _buildCredentialRow('Contraseña:', password),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Guarda estas credenciales. El estudiante las necesitará para acceder al sistema.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _clearForm() {
    _nombresController.clear();
    _apellidosController.clear();
    _codigoEstudianteController.clear();
    _documentoController.clear();
    _correoController.clear();
    _celularController.clear();
    _usernameController.clear();
    setState(() {
      _selectedModoContrato = null;
      _selectedModalidadEstudio = null;
      _selectedFacultad = null;
      _selectedCarrera = null;
      _selectedCiclo = null;
      _selectedGrupo = null;
    });
  }

  void _onFacultadChanged(String? facultad) {
    setState(() {
      _selectedFacultad = facultad;
      _selectedCarrera = null;
    });
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1E3A5F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helperText,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: items,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      menuMaxHeight: 300,
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E3A5F)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header animado
            SlideTransition(
              position: _headerSlideAnimation,
              child: FadeTransition(
                opacity: _headerFadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'logo',
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person_add,
                                color: Color(0xFF1E3A5F),
                                size: 30,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registro de Estudiantes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Crear nuevas cuentas',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.file_upload,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DatosExcelScreen(),
                            ),
                          );
                        },
                        tooltip: 'Importar Excel',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.list,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EstudiantesRegistradosScreen(),
                            ),
                          );
                        },
                        tooltip: 'Ver registrados',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content Area con animación
            Expanded(
              child: FadeTransition(
                opacity: _formFadeAnimation,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EDF2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1E3A5F),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Información personal
                                _buildSectionCard(
                                  title: 'Información Personal',
                                  icon: Icons.person,
                                  children: [
                                    _buildTextField(
                                      controller: _nombresController,
                                      label: 'Nombres',
                                      icon: Icons.person,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Los nombres son requeridos';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _apellidosController,
                                      label: 'Apellidos',
                                      icon: Icons.person_outline,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Los apellidos son requeridos';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _usernameController,
                                      label: 'Usuario',
                                      icon: Icons.account_circle,
                                      helperText:
                                          'Nombre de usuario para iniciar sesión',
                                      hintText: 'Ej: juan.perez',
                                      onChanged: (value) {
                                        final cleaned = _cleanUsername(value);
                                        if (cleaned != value) {
                                          _usernameController
                                              .value = TextEditingValue(
                                            text: cleaned,
                                            selection: TextSelection.collapsed(
                                              offset: cleaned.length,
                                            ),
                                          );
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'El usuario es requerido';
                                        }
                                        if (value.trim().length < 3) {
                                          return 'El usuario debe tener al menos 3 caracteres';
                                        }
                                        if (!RegExp(
                                          r'^[a-z0-9.]+$',
                                        ).hasMatch(value.trim())) {
                                          return 'Solo letras minúsculas, números y puntos';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _documentoController,
                                      label: 'Documento (DNI)',
                                      icon: Icons.credit_card,
                                      keyboardType: TextInputType.number,
                                      helperText:
                                          'La contraseña inicial será el DNI',
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'El documento es requerido';
                                        }
                                        if (value.trim().length != 8) {
                                          return 'El DNI debe tener 8 dígitos';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Información de contacto
                                _buildSectionCard(
                                  title: 'Información de Contacto',
                                  icon: Icons.contact_phone,
                                  children: [
                                    _buildTextField(
                                      controller: _correoController,
                                      label: 'Correo electrónico',
                                      icon: Icons.email,
                                      keyboardType: TextInputType.emailAddress,
                                      helperText:
                                          'Personal o institucional (@upeu.edu.pe)',
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'El correo es requerido';
                                        }
                                        if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                        ).hasMatch(value)) {
                                          return 'Ingresa un correo válido';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: _celularController,
                                      label: 'Celular',
                                      icon: Icons.phone,
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'El celular es requerido';
                                        }
                                        if (value.trim().length != 9) {
                                          return 'El celular debe tener 9 dígitos';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Información académica
                                _buildSectionCard(
                                  title: 'Información Académica',
                                  icon: Icons.school,
                                  children: [
                                    _buildTextField(
                                      controller: _codigoEstudianteController,
                                      label: 'Código estudiante',
                                      icon: Icons.badge,
                                      helperText: 'Ej: 202320800',
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'El código es requerido';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Modo contrato',
                                      icon: Icons.description,
                                      value: _selectedModoContrato,
                                      items: _modosContrato.map((modo) {
                                        return DropdownMenuItem<String>(
                                          value: modo,
                                          child: Text(modo),
                                        );
                                      }).toList(),
                                      onChanged: (value) => setState(
                                        () => _selectedModoContrato = value,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Modalidad estudio',
                                      icon: Icons.book,
                                      value: _selectedModalidadEstudio,
                                      items: _modalidadesEstudio.map((
                                        modalidad,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: modalidad,
                                          child: Text(modalidad),
                                        );
                                      }).toList(),
                                      onChanged: (value) => setState(
                                        () => _selectedModalidadEstudio = value,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Unidad académica (Facultad)',
                                      icon: Icons.account_balance,
                                      value: _selectedFacultad,
                                      items: _facultadesCarreras.keys.map((
                                        facultad,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: facultad,
                                          child: Text(
                                            facultad,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _onFacultadChanged,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown<String>(
                                      label: 'Programa estudio (Carrera)',
                                      icon: Icons.menu_book,
                                      value: _selectedCarrera,
                                      items: _selectedFacultad != null
                                          ? _facultadesCarreras[_selectedFacultad]!
                                                .map((carrera) {
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: carrera,
                                                    child: Text(
                                                      carrera,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                })
                                                .toList()
                                          : [],
                                      onChanged: (value) => setState(
                                        () => _selectedCarrera = value,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDropdown<String>(
                                            label: 'Ciclo',
                                            icon: Icons.layers,
                                            value: _selectedCiclo,
                                            items: _ciclos.map((ciclo) {
                                              return DropdownMenuItem<String>(
                                                value: ciclo,
                                                child: Text('Ciclo $ciclo'),
                                              );
                                            }).toList(),
                                            onChanged: (value) => setState(
                                              () => _selectedCiclo = value,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildDropdown<String>(
                                            label: 'Grupo',
                                            icon: Icons.groups,
                                            value: _selectedGrupo,
                                            items: _grupos.map((grupo) {
                                              return DropdownMenuItem<String>(
                                                value: grupo,
                                                child: Text('Grupo $grupo'),
                                              );
                                            }).toList(),
                                            onChanged: (value) => setState(
                                              () => _selectedGrupo = value,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Botones de acción
                                _buildActionButton(
                                  label: 'Crear Estudiante',
                                  icon: Icons.person_add,
                                  onPressed: _createStudent,
                                  isPrimary: true,
                                ),
                                const SizedBox(height: 12),
                                _buildActionButton(
                                  label: 'Importar desde Excel',
                                  icon: Icons.file_upload,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DatosExcelScreen(),
                                      ),
                                    );
                                  },
                                  isPrimary: false,
                                ),
                                const SizedBox(height: 12),
                                _buildActionButton(
                                  label: 'Ver Estudiantes Registrados',
                                  icon: Icons.list,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EstudiantesRegistradosScreen(),
                                      ),
                                    );
                                  },
                                  isPrimary: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF1E3A5F), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: const Color(0xFF1E3A5F).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 22),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A5F),
                side: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
  }
}
