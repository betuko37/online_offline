import 'package:flutter/material.dart';
import '../lib/betuko_offline_sync.dart';

/// Ejemplo de API súper limpia sin SyncConfig
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Súper Limpia',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CleanApiExample(),
    );
  }
}

class CleanApiExample extends StatefulWidget {
  @override
  _CleanApiExampleState createState() => _CleanApiExampleState();
}

class _CleanApiExampleState extends State<CleanApiExample> {
  late OnlineOfflineManager _reportsManager; // ← CON limpieza automática
  late OnlineOfflineManager _selectsManager; // ← SIN limpieza automática
  
  List<Map<String, dynamic>> _reportsData = [];
  List<Map<String, dynamic>> _selectsData = [];
  bool _isLoading = false;
  String _status = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _initializeManagers();
  }

  /// Inicialización súper limpia
  void _initializeManagers() async {
    try {
      // 1. Configurar API global (súper simple)
      GlobalConfig.init(
        baseUrl: 'https://tu-api.com',
        token: 'tu-token',
        syncMinutes: 5, // ← Sincronizar cada 5 minutos automáticamente
        // useIncrementalSync: true (por defecto)
        // pageSize: 25 (por defecto)
        // lastModifiedField: 'lastModifiedAt' (por defecto)
        // syncOnReconnect: true (por defecto)
        // NO configurar limpieza global - solo por manager individual
      );

      // 2. Manager CON limpieza automática (súper simple)
      _reportsManager = OnlineOfflineManager(
        boxName: 'reports',
        endpoint: 'api/reports',
        enableAutoCleanup: true, // ← ¡HABILITAR limpieza automática!
      );

      // 3. Manager SIN limpieza automática (súper simple)
      _selectsManager = OnlineOfflineManager(
        boxName: 'selects',
        endpoint: 'api/selects',
        enableAutoCleanup: false, // ← ¡DESHABILITAR limpieza automática!
      );

      // 4. Cargar datos
      _loadData();
      
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  /// Cargar datos súper simple
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _status = 'Cargando datos...';
    });

    try {
      // ¡ESTO ES TODO! Sincronización automática incluida
      final reportsData = await _reportsManager.getAll();
      final selectsData = await _selectsManager.getAll();
      
      setState(() {
        _reportsData = reportsData;
        _selectsData = selectsData;
        _status = 'Datos cargados: ${reportsData.length} reports, ${selectsData.length} selects';
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

  /// Agregar dato súper simple
  Future<void> _addReport() async {
    final newData = {
      'title': 'Reporte ${DateTime.now().millisecondsSinceEpoch}',
      'description': 'Este reporte se limpiará automáticamente',
      'status': 'active',
    };
    
    await _reportsManager.save(newData);
    print('✅ Reporte guardado (se limpiará automáticamente)');
    _loadData();
  }

  /// Agregar dato súper simple
  Future<void> _addSelect() async {
    final newData = {
      'name': 'Select ${DateTime.now().millisecondsSinceEpoch}',
      'description': 'Este select NO se limpiará automáticamente',
      'type': 'master',
    };
    
    await _selectsManager.save(newData);
    print('✅ Select guardado (NO se limpiará automáticamente)');
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Súper Limpia'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Panel de estado
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 Estado: $_status', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('📄 Reports: ${_reportsData.length} registros (CON limpieza automática)'),
                Text('📄 Selects: ${_selectsData.length} registros (SIN limpieza automática)'),
                SizedBox(height: 8),
                Text('🔄 Sincronización: Cada ${GlobalConfig.syncMinutes} minutos automáticamente'),
                Text('🗑️ Limpieza: Solo en reports, NO en selects'),
                Text('✅ API súper limpia - sin SyncConfig redundante'),
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
                  onPressed: _isLoading ? null : _addReport,
                  icon: Icon(Icons.add),
                  label: Text('Agregar Reporte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addSelect,
                  icon: Icon(Icons.add),
                  label: Text('Agregar Select'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de datos
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Reports (${_reportsData.length}) - CON limpieza'),
                      Tab(text: 'Selects (${_selectsData.length}) - SIN limpieza'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Reports (CON limpieza)
                        _buildDataList(_reportsData, 'Reports', true),
                        // Tab 2: Selects (SIN limpieza)
                        _buildDataList(_selectsData, 'Selects', false),
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

  Widget _buildDataList(List<Map<String, dynamic>> data, String title, bool hasCleanup) {
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
            title: Text(item['title'] ?? item['name'] ?? 'Sin título'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['description'] ?? 'Sin descripción'),
                if (hasCleanup) 
                  Text('⚠️ Este registro se limpiará automáticamente', 
                       style: TextStyle(color: Colors.orange, fontSize: 12)),
                if (!hasCleanup) 
                  Text('✅ Este registro NO se limpiará automáticamente', 
                       style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
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
    _reportsManager.dispose();
    _selectsManager.dispose();
    super.dispose();
  }
}
