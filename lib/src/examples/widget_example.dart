import 'package:flutter/material.dart';
import '../online_offline_manager.dart';

/// Ejemplo de cómo usar la librería en widgets básicos
/// 
/// Este archivo muestra cómo implementar la librería en widgets reales
/// con operaciones CRUD completas y manejo de estado reactivo.
class WidgetExample extends StatefulWidget {
  const WidgetExample({super.key});

  @override
  State<WidgetExample> createState() => _WidgetExampleState();
}

class _WidgetExampleState extends State<WidgetExample> {
  // 🎯 MANAGER PRINCIPAL - Solo necesitas esto
  late OnlineOfflineManager _manager;
  
  // Controladores para el formulario
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Estado de la aplicación
  bool _isLoading = false;
  String _status = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }
  
  /// Inicializa el manager con configuración básica
  void _initializeManager() async {
    try {
      // 🎯 CONFIGURACIÓN SIMPLE - Solo boxName y endpoint
      _manager = OnlineOfflineManager(
        boxName: 'usuarios',    // Nombre del box local
        endpoint: 'users',      // Endpoint del servidor
      );
      
      // Inicializar el manager
      await _manager.initialize();
      
      setState(() {
        _status = 'Manager inicializado correctamente';
      });
    } catch (e) {
      setState(() {
        _status = 'Error inicializando: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ejemplo de Widgets'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: _manualSync,
            tooltip: 'Sincronizar manualmente',
          ),
          IconButton(
            icon: Icon(Icons.info),
            onPressed: _showInfo,
            tooltip: 'Información del manager',
          ),
        ],
      ),
      body: Column(
        children: [
          // Estado del manager
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado del Manager:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text('Status: $_status'),
                Text('Conectado: ${_manager.isConnected ? "Sí" : "No"}'),
                Text('Inicializado: ${_manager.isInitialized ? "Sí" : "No"}'),
              ],
            ),
          ),
          
          // Formulario para agregar usuarios
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Agregar Usuario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addUser,
                    icon: _isLoading 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.add),
                    label: Text(_isLoading ? 'Guardando...' : 'Agregar Usuario'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Lista de usuarios con StreamBuilder
          Expanded(
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.list, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Usuarios',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        StreamBuilder<Map<String, dynamic>>(
                          stream: _manager.data,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Chip(
                                label: Text('${snapshot.data!.length}'),
                                backgroundColor: Colors.blue.shade100,
                              );
                            }
                            return Chip(
                              label: Text('0'),
                              backgroundColor: Colors.grey.shade100,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<Map<String, dynamic>>(
                      stream: _manager.data,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Cargando usuarios...'),
                              ],
                            ),
                          );
                        }
                        
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Error: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _refreshData,
                                  child: Text('Reintentar'),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        final usuarios = snapshot.data ?? {};
                        
                        if (usuarios.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No hay usuarios',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Agrega tu primer usuario usando el formulario',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          itemCount: usuarios.length,
                          itemBuilder: (context, index) {
                            final userId = usuarios.keys.elementAt(index);
                            final usuario = usuarios[userId];
                            
                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    usuario['nombre']?.toString().substring(0, 1).toUpperCase() ?? '?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  usuario['nombre'] ?? 'Sin nombre',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(usuario['email'] ?? 'Sin email'),
                                    if (usuario['telefono'] != null)
                                      Text(usuario['telefono']),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteUser(userId);
                                    } else if (value == 'edit') {
                                      _editUser(userId, usuario);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Editar'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Agrega un nuevo usuario
  Future<void> _addUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      _showSnackBar('Por favor completa todos los campos requeridos', Colors.orange);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userData = {
        'nombre': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'fecha_creacion': DateTime.now().toIso8601String(),
      };
      
      // Generar ID único
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Guardar usuario
      await _manager.save(userId, userData);
      
      // Limpiar formulario
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      
      _showSnackBar('Usuario agregado exitosamente', Colors.green);
      
    } catch (e) {
      _showSnackBar('Error agregando usuario: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Elimina un usuario
  Future<void> _deleteUser(String userId) async {
    final confirmed = await _showConfirmDialog(
      'Eliminar Usuario',
      '¿Estás seguro de que quieres eliminar este usuario?',
    );
    
    if (!confirmed) return;
    
    try {
      await _manager.delete(userId);
      _showSnackBar('Usuario eliminado exitosamente', Colors.green);
    } catch (e) {
      _showSnackBar('Error eliminando usuario: $e', Colors.red);
    }
  }
  
  /// Edita un usuario
  Future<void> _editUser(String userId, Map<String, dynamic> usuario) async {
    _nameController.text = usuario['nombre'] ?? '';
    _emailController.text = usuario['email'] ?? '';
    _phoneController.text = usuario['telefono'] ?? '';
    
    final confirmed = await _showConfirmDialog(
      'Editar Usuario',
      '¿Quieres editar este usuario?',
    );
    
    if (!confirmed) return;
    
    try {
      final updatedData = {
        'nombre': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      };
      
      await _manager.save(userId, updatedData);
      
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      
      _showSnackBar('Usuario actualizado exitosamente', Colors.green);
    } catch (e) {
      _showSnackBar('Error actualizando usuario: $e', Colors.red);
    }
  }
  
  /// Sincronización manual
  Future<void> _manualSync() async {
    try {
      await _manager.sync();
      _showSnackBar('Sincronización completada', Colors.blue);
    } catch (e) {
      _showSnackBar('Error en sincronización: $e', Colors.red);
    }
  }
  
  /// Refresca los datos
  Future<void> _refreshData() async {
    try {
      await _manager.getAll();
      _showSnackBar('Datos actualizados', Colors.blue);
    } catch (e) {
      _showSnackBar('Error actualizando datos: $e', Colors.red);
    }
  }
  
  /// Muestra información del manager
  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Información del Manager'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Box Name: ${_manager.boxName}'),
            Text('Endpoint: ${_manager.endpoint ?? "Solo local"}'),
            Text('Conectado: ${_manager.isConnected ? "Sí" : "No"}'),
            Text('Inicializado: ${_manager.isInitialized ? "Sí" : "No"}'),
            Text('Estado: ${_manager.currentStatus}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  /// Muestra un SnackBar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  /// Muestra un diálogo de confirmación
  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  
  @override
  void dispose() {
    _manager.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
