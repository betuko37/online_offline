import 'package:flutter/material.dart';
import '../lib/betuko_offline_sync.dart';

/// Ejemplo súper simple de uso de la librería offline-first
/// 
/// La API es muy simple:
/// - `get()` → Siempre devuelve datos locales
/// - `save()` → Guarda datos localmente
/// - `delete()` → Elimina datos
/// - `syncAll()` → Sincroniza todos los managers con el servidor
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
  late OnlineOfflineManager _reportesManager;
  List<Map<String, dynamic>> _datos = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _status = 'Listo';

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  void _initializeManager() async {
    try {
      // ═══════════════════════════════════════════════════════════════════════
      // PASO 1: Configurar API (una sola vez al inicio de la app)
      // ═══════════════════════════════════════════════════════════════════════
      GlobalConfig.init(
        baseUrl: 'https://tu-api.com',
        token: 'tu-token',
      );

      // ═══════════════════════════════════════════════════════════════════════
      // PASO 2: Crear manager (súper simple)
      // ═══════════════════════════════════════════════════════════════════════
      _reportesManager = OnlineOfflineManager(
        boxName: 'reportes',
        endpoint: '/api/reportes',
      );

      // ═══════════════════════════════════════════════════════════════════════
      // PASO 3: Escuchar cambios automáticamente (opcional)
      // ═══════════════════════════════════════════════════════════════════════
      _reportesManager.dataStream.listen((data) {
        setState(() {
          _datos = data;
        });
      });

      // Cargar datos iniciales
      _loadData();
      
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  /// Cargar datos - SIEMPRE devuelve datos locales
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ═══════════════════════════════════════════════════════════════════════
      // get() SIEMPRE retorna datos locales - sin llamar al servidor
      // ═══════════════════════════════════════════════════════════════════════
      final datos = await _reportesManager.get();
      
      setState(() {
        _datos = datos;
        _status = '${datos.length} registros cargados (locales)';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Sincronizar con el servidor - SOLO cuando el usuario quiera
  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
      _status = 'Sincronizando...';
    });

    try {
      // ═══════════════════════════════════════════════════════════════════════
      // syncAll() sincroniza TODOS los managers con el servidor
      // ═══════════════════════════════════════════════════════════════════════
      final results = await OnlineOfflineManager.syncAll();
      
      // Verificar resultados
      final successCount = results.values.where((r) => r.success).length;
      final errorCount = results.values.where((r) => !r.success).length;
      
      setState(() {
        _status = 'Sincronizado: $successCount exitosos, $errorCount errores';
      });
      
      // Recargar datos después de sincronizar
      await _loadData();
      
    } catch (e) {
      setState(() {
        _status = 'Error al sincronizar: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  /// Agregar nuevo dato
  Future<void> _addData() async {
    final newData = {
      'titulo': 'Reporte ${DateTime.now().millisecondsSinceEpoch}',
      'descripcion': 'Descripción del reporte',
      'fecha': DateTime.now().toIso8601String(),
    };
    
    // ═══════════════════════════════════════════════════════════════════════
    // save() guarda datos localmente (se sincronizarán con syncAll())
    // ═══════════════════════════════════════════════════════════════════════
    await _reportesManager.save(newData);
    
    setState(() {
      _status = 'Dato guardado localmente';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _datos.where((d) => d['sync'] != 'true').length;
    final syncedCount = _datos.where((d) => d['sync'] == 'true').length;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Offline-First Simple'),
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
                Text('📊 Estado: $_status', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('📱 Total: ${_datos.length} registros'),
                Text('☁️ Sincronizados: $syncedCount'),
                Text('⏳ Pendientes: $pendingCount'),
              ],
            ),
          ),
          
          // Botones
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón cargar datos (locales)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadData,
                  icon: Icon(Icons.folder),
                  label: Text('Ver Datos'),
                ),
                // Botón agregar
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addData,
                  icon: Icon(Icons.add),
                  label: Text('Agregar'),
                ),
                // Botón sincronizar
                ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _syncData,
                  icon: _isSyncing 
                    ? SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.sync),
                  label: Text('Sincronizar'),
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
            child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _datos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No hay datos'),
                        Text('Usa "Agregar" para crear datos'),
                        Text('Usa "Sincronizar" para descargar del servidor'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _datos.length,
                    itemBuilder: (context, index) {
                      final item = _datos[index];
                      final isSynced = item['sync'] == 'true';
                      
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: Text(item['titulo'] ?? item['title'] ?? 'Sin título'),
                          subtitle: Text(item['descripcion'] ?? item['description'] ?? ''),
                          trailing: Icon(
                            isSynced ? Icons.cloud_done : Icons.cloud_off,
                            color: isSynced ? Colors.green : Colors.orange,
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
    _reportesManager.dispose();
    super.dispose();
  }
}
