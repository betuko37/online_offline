import 'package:flutter/material.dart';
import '../lib/betuko_offline_sync.dart';

/// Ejemplo súper simple de uso de la librería offline-first
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline-First Súper Simple',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SimpleExample(),
    );
  }
}

class SimpleExample extends StatefulWidget {
  @override
  _SimpleExampleState createState() => _SimpleExampleState();
}

class _SimpleExampleState extends State<SimpleExample> {
  late OnlineOfflineManager _manager;
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _syncData = [];
  List<Map<String, dynamic>> _localData = [];
  bool _isLoading = false;
  String _status = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  /// Inicialización súper simple
  void _initializeManager() async {
    try {
      // 1. Configurar API con configuración de sincronización
      GlobalConfig.init(
        baseUrl: 'https://tu-api.com',
        token: 'tu-token',
        syncMinutes: 5, // Sincronizar cada 5 minutos
        useIncrementalSync: true, // Usar sincronización incremental
        pageSize: 25, // 25 registros por página
        lastModifiedField: 'updated_at', // Campo de timestamp
      );

      // 2. Crear manager (súper simple)
      _manager = OnlineOfflineManager(
        boxName: 'reports',
        endpoint: 'api/reports',
      );

      // 3. Escuchar cambios automáticamente
      _manager.dataStream.listen((data) {
        setState(() {
          _allData = data;
        });
      });

      _manager.statusStream.listen((status) {
        setState(() {
          _status = _getStatusText(status);
        });
      });

      // 4. Cargar datos (sincronización automática incluida)
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
      final allData = await _manager.getAll();
      final syncData = await _manager.getSync();
      final localData = await _manager.getLocal();
      
      setState(() {
        _allData = allData;
        _syncData = syncData;
        _localData = localData;
        _status = 'Datos cargados: ${allData.length} total, ${syncData.length} sincronizados, ${localData.length} locales';
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
        title: Text('Offline-First Súper Simple'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Panel de estado súper simple
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 Estado: $_status', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('📄 Total: ${_allData.length} registros'),
                Text('☁️ Sincronizados: ${_syncData.length} registros'),
                Text('📱 Locales: ${_localData.length} registros'),
                Text('💡 Solo necesitas getAll(), getSync(), getLocal()'),
              ],
            ),
          ),
          
          // Botones súper simples
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
          
          // Tabs para mostrar diferentes tipos de datos
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Todos (${_allData.length})'),
                      Tab(text: 'Sincronizados (${_syncData.length})'),
                      Tab(text: 'Locales (${_localData.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Todos los datos
                        _buildDataList(_allData, 'Todos los datos'),
                        // Tab 2: Solo sincronizados
                        _buildDataList(_syncData, 'Datos sincronizados'),
                        // Tab 3: Solo locales
                        _buildDataList(_localData, 'Datos locales'),
                      ],
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

  Widget _buildDataList(List<Map<String, dynamic>> data, String title) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando datos con sincronización automática...'),
          ],
        ),
      );
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay $title'),
            SizedBox(height: 8),
            Text('Usa "Agregar" para crear datos'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
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
    );
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}
