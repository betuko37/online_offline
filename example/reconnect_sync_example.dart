import 'package:flutter/material.dart';
import '../lib/betuko_offline_sync.dart';

/// Ejemplo de sincronización al reconectar
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sincronización al Reconectar',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ReconnectSyncExample(),
    );
  }
}

class ReconnectSyncExample extends StatefulWidget {
  @override
  _ReconnectSyncExampleState createState() => _ReconnectSyncExampleState();
}

class _ReconnectSyncExampleState extends State<ReconnectSyncExample> {
  late OnlineOfflineManager _manager;
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  String _status = 'Inicializando...';
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  /// Inicialización con configuración de reconexión
  void _initializeManager() async {
    try {
      // 1. Configurar API con sincronización al reconectar
      GlobalConfig.init(
        baseUrl: 'https://tu-api.com',
        token: 'tu-token',
        syncMinutes: 5, // Sincronizar cada 5 minutos
        useIncrementalSync: true, // Sincronización incremental
        pageSize: 25, // 25 registros por página
        lastModifiedField: 'lastModifiedAt', // Tu campo de timestamp
        syncOnReconnect: true, // ← ¡NUEVO! Sincronizar al reconectar
      );

      // 2. Crear manager
      _manager = OnlineOfflineManager(
        boxName: 'reports',
        endpoint: 'api/reports',
      );

      // 3. Escuchar cambios automáticamente
      _manager.dataStream.listen((data) {
        setState(() {
          _data = data;
        });
      });

      _manager.statusStream.listen((status) {
        setState(() {
          _status = _getStatusText(status);
        });
      });

      // 4. Escuchar conectividad
      _manager.connectivityStream.listen((isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
        
        if (isOnline) {
          _status = 'Conectado - Sincronizando...';
        } else {
          _status = 'Sin conexión - Modo offline';
        }
      });

      // 5. Cargar datos (sincronización automática incluida)
      _loadData();
      
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  /// Cargar datos - SÚPER SIMPLE: solo getAll()
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _status = 'Cargando datos...';
    });

    try {
      // ¡ESTO ES TODO LO QUE NECESITAS! 
      // Automáticamente sincroniza y retorna todos los datos
      final data = await _manager.getAll();
      
      setState(() {
        _data = data;
        _status = 'Datos cargados: ${data.length} registros';
      });
    } catch (e) {
      setState(() {
        _status = 'Error cargando datos: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Agregar nuevo dato - SÚPER SIMPLE
  Future<void> _addData() async {
    final newData = {
      'title': 'Nuevo Reporte ${DateTime.now().millisecondsSinceEpoch}',
      'description': 'Descripción del reporte',
      'status': 'active',
    };
    
    await _manager.save(newData);
    print('✅ Datos guardados (se sincronizarán automáticamente)');
    
    // Recargar datos para mostrar cambios
    _loadData();
  }

  /// Simular pérdida de conexión (para testing)
  void _simulateOffline() {
    setState(() {
      _isOnline = false;
      _status = 'Simulando pérdida de conexión...';
    });
  }

  /// Simular recuperación de conexión (para testing)
  void _simulateReconnect() {
    setState(() {
      _isOnline = true;
      _status = 'Simulando recuperación de conexión...';
    });
  }

  /// Obtiene texto descriptivo del estado
  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Inactivo';
      case SyncStatus.syncing:
        return 'Sincronizando automáticamente...';
      case SyncStatus.success:
        return 'Sincronización exitosa';
      case SyncStatus.error:
        return 'Error en sincronización';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sincronización al Reconectar'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Panel de estado con indicador de conexión
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: _isOnline ? Colors.green[100] : Colors.red[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isOnline ? Icons.wifi : Icons.wifi_off,
                      color: _isOnline ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _isOnline ? 'Conectado' : 'Sin conexión',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isOnline ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('📊 Estado: $_status'),
                Text('📄 Registros: ${_data.length}'),
                Text('💡 Sincronización al reconectar: ${GlobalConfig.syncOnReconnect ? "Activada" : "Desactivada"}'),
              ],
            ),
          ),
          
          // Botones de control
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadData,
                  icon: Icon(Icons.refresh),
                  label: Text('Cargar Datos'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addData,
                  icon: Icon(Icons.add),
                  label: Text('Agregar'),
                ),
              ],
            ),
          ),
          
          // Botones de simulación (solo para testing)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _simulateOffline,
                  icon: Icon(Icons.wifi_off),
                  label: Text('Simular Offline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _simulateReconnect,
                  icon: Icon(Icons.wifi),
                  label: Text('Simular Reconexión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Lista de datos
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Cargando datos con sincronización automática...'),
                      ],
                    ),
                  )
                : _data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No hay datos'),
                            SizedBox(height: 8),
                            Text('Usa "Agregar" para crear datos'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _data.length,
                        itemBuilder: (context, index) {
                          final item = _data[index];
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              title: Text(item['title'] ?? 'Sin título'),
                              subtitle: Text(item['description'] ?? 'Sin descripción'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  item['sync'] == 'true'
                                      ? Icon(Icons.cloud_done, color: Colors.green, size: 20)
                                      : Icon(Icons.cloud_off, color: Colors.orange, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    item['sync'] == 'true' ? 'Sincronizado' : 'Local',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item['sync'] == 'true' ? Colors.green : Colors.orange,
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
    );
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}
