import 'package:flutter/material.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔧 Configuración inicial - ¡Solo una línea!
  GlobalConfig.init(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    token: 'tu-token-aqui', // Opcional para APIs públicas
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Betuko Offline Sync Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PostListScreen(),
    );
  }
}

class PostListScreen extends StatefulWidget {
  @override
  _PostListScreenState createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  // 🚀 Manager auto-inicializado - ¡Sin configuración!
  final manager = OnlineOfflineManager(
    boxName: 'posts',
    endpoint: 'posts',
  );
  
  List<Map<String, dynamic>> posts = [];
  bool isLoading = false;
  String statusMessage = '';
  
  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _escucharCambios();
  }
  
  @override
  void dispose() {
    manager.dispose(); // 🧹 Liberar recursos
    super.dispose();
  }
  
  /// 📱 Carga inicial rápida + sync en background
  Future<void> _cargarDatosIniciales() async {
    setState(() { 
      isLoading = true;
      statusMessage = 'Cargando datos locales...';
    });
    
    try {
      // 1. Cargar datos locales primero (súper rápido)
      final datosLocales = await manager.getAll();
      setState(() {
        posts = datosLocales;
        statusMessage = 'Datos locales cargados (${datosLocales.length})';
        isLoading = false;
      });
      
      // 2. Sincronizar en background si hay conexión
      if (manager.isOnline) {
        setState(() { statusMessage = 'Sincronizando con servidor...'; });
        
        final datosActualizados = await manager.getAllWithSync();
        setState(() {
          posts = datosActualizados;
          statusMessage = 'Sincronizado (${datosActualizados.length} posts)';
        });
      } else {
        setState(() { statusMessage = 'Sin conexión - usando datos locales'; });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = 'Error: $e';
      });
    }
  }
  
  /// 🌊 Escuchar cambios en tiempo real
  void _escucharCambios() {
    // Stream de datos
    manager.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          posts = data;
        });
      }
    });
    
    // Stream de estado de sincronización
    manager.statusStream.listen((status) {
      if (mounted) {
        String mensaje = '';
        switch (status) {
          case SyncStatus.idle:
            mensaje = 'Listo';
            break;
          case SyncStatus.syncing:
            mensaje = 'Sincronizando...';
            break;
          case SyncStatus.success:
            mensaje = 'Sincronización exitosa';
            break;
          case SyncStatus.error:
            mensaje = 'Error en sincronización';
            break;
        }
        setState(() { statusMessage = mensaje; });
      }
    });
  }
  
  /// 🔄 Pull to refresh con datos frescos del servidor
  Future<void> _onRefresh() async {
    try {
      setState(() { statusMessage = 'Obteniendo datos frescos...'; });
      
      // 🌐 Obtener datos directamente del servidor
      final datosFrescos = await manager.getFromServer();
      
      setState(() {
        posts = datosFrescos;
        statusMessage = 'Datos actualizados desde servidor (${datosFrescos.length})';
      });
    } catch (e) {
      setState(() { statusMessage = 'Error actualizando: $e'; });
      
      // Mostrar SnackBar con error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sin conexión. Mostrando datos locales.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  /// ➕ Agregar nuevo post
  Future<void> _agregarPost() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => NuevoPostDialog(),
    );
    
    if (result != null) {
      await manager.save({
        'title': result['title']!,
        'body': result['body']!,
        'userId': 1,
      });
      
      setState(() {
        statusMessage = 'Post guardado localmente';
      });
    }
  }
  
  /// 🗑️ Eliminar post
  Future<void> _eliminarPost(Map<String, dynamic> post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar'),
        content: Text('¿Eliminar este post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // Simplemente usar el ID si existe, o buscar por contenido
      if (post['id'] != null) {
        await manager.delete(post['id'].toString());
      } else {
        // Para posts locales, buscar por created_at
        final allData = await manager.getAll();
        for (var item in allData) {
          if (item['title'] == post['title'] && 
              item['body'] == post['body'] &&
              item['created_at'] == post['created_at']) {
            // Crear un ID temporal para eliminar
            final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
            await manager.delete(tempId);
            break;
          }
        }
      }
      
      setState(() {
        statusMessage = 'Post eliminado';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Posts Demo'),
        backgroundColor: Colors.blue,
        actions: [
          // 🌐 Indicador de conectividad
          StreamBuilder<bool>(
            stream: manager.connectivityStream,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Container(
                margin: EdgeInsets.only(right: 16),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 📊 Barra de estado
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Row(
              children: [
                // Estado de sincronización
                StreamBuilder<SyncStatus>(
                  stream: manager.statusStream,
                  builder: (context, snapshot) {
                    final status = snapshot.data ?? SyncStatus.idle;
                    IconData icon;
                    Color color;
                    
                    switch (status) {
                      case SyncStatus.idle:
                        icon = Icons.sync;
                        color = Colors.grey;
                        break;
                      case SyncStatus.syncing:
                        icon = Icons.sync;
                        color = Colors.blue;
                        break;
                      case SyncStatus.success:
                        icon = Icons.check_circle;
                        color = Colors.green;
                        break;
                      case SyncStatus.error:
                        icon = Icons.error;
                        color = Colors.red;
                        break;
                    }
                    
                    return status == SyncStatus.syncing 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(icon, color: color, size: 16);
                  },
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // 📱 Lista de posts
          Expanded(
            child: isLoading 
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No hay posts',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Desliza hacia abajo para actualizar',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final isLocal = post['sync'] != 'true';
                          
                          return Card(
                            margin: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              title: Text(
                                post['title'] ?? 'Sin título',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Text(
                                    post['body'] ?? 'Sin contenido',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'ID: ${post['id'] ?? 'local'} • Usuario: ${post['userId'] ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Indicador de estado
                                  Icon(
                                    isLocal ? Icons.cloud_upload : Icons.cloud_done,
                                    color: isLocal ? Colors.orange : Colors.green,
                                    size: 20,
                                  ),
                                  // Botón eliminar (solo para posts locales)
                                  if (isLocal) ...[
                                    SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _eliminarPost(post),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarPost,
        child: Icon(Icons.add),
        tooltip: 'Agregar post',
      ),
    );
  }
}

class NuevoPostDialog extends StatefulWidget {
  @override
  _NuevoPostDialogState createState() => _NuevoPostDialogState();
}

class _NuevoPostDialogState extends State<NuevoPostDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nuevo Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            decoration: InputDecoration(
              labelText: 'Contenido',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty && 
                _bodyController.text.isNotEmpty) {
              Navigator.of(context).pop({
                'title': _titleController.text,
                'body': _bodyController.text,
              });
            }
          },
          child: Text('Guardar'),
        ),
      ],
    );
  }
}