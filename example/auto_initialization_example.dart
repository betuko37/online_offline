import 'package:flutter/material.dart';
import 'package:betuko_offline_sync/betuko_offline_sync.dart';

/// Ejemplo completo de inicialización automática
/// TODO se maneja automáticamente - solo crear y usar
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Initialization Demo',
      home: AutoInitScreen(),
    );
  }
}

class AutoInitScreen extends StatefulWidget {
  @override
  _AutoInitScreenState createState() => _AutoInitScreenState();
}

class _AutoInitScreenState extends State<AutoInitScreen> {
  // ✨ SOLO CREAR - TODO SE INICIALIZA AUTOMÁTICAMENTE
  late final OnlineOfflineManager manager;
  
  @override
  void initState() {
    super.initState();
    
    // 🎯 CONFIGURACIÓN GLOBAL (solo una vez en la app)
    GlobalConfig.init(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      token: 'tu-token-aqui', // opcional
    );
    
    // ✨ CREAR MANAGER - SE INICIALIZA AUTOMÁTICAMENTE
    manager = OnlineOfflineManager(
      boxName: 'productos',
      endpoint: 'posts',
    );
    
    // 🚀 TODO FUNCIONA INMEDIATAMENTE - Sin await, sin initialize()
    print('✅ Manager creado - Hive se inicializa automáticamente');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Auto-Initialization Demo'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // 📊 INDICADORES AUTOMÁTICOS
          _buildStatusIndicators(),
          
          // 🔄 DATOS EN TIEMPO REAL
          _buildDataStream(),
          
          // 🎛️ CONTROLES
          _buildControls(),
        ],
      ),
    );
  }

  /// Indicadores de estado automáticos
  Widget _buildStatusIndicators() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          // 🌐 CONECTIVIDAD AUTOMÁTICA
          Expanded(
            child: StreamBuilder<bool>(
              stream: manager.connectivityStream,
              initialData: false,
              builder: (context, snapshot) {
                final isOnline = snapshot.data ?? false;
                return Card(
                  color: isOnline ? Colors.green[100] : Colors.red[100],
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          color: isOnline ? Colors.green : Colors.red,
                        ),
                        Text(
                          isOnline ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            color: isOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          SizedBox(width: 8),
          
          // 🔄 SINCRONIZACIÓN AUTOMÁTICA
          Expanded(
            child: StreamBuilder<SyncStatus>(
              stream: manager.statusStream,
              initialData: SyncStatus.idle,
              builder: (context, snapshot) {
                final status = snapshot.data ?? SyncStatus.idle;
                Color color;
                IconData icon;
                String text;
                
                switch (status) {
                  case SyncStatus.syncing:
                    color = Colors.blue;
                    icon = Icons.sync;
                    text = 'SYNC';
                    break;
                  case SyncStatus.success:
                    color = Colors.green;
                    icon = Icons.check_circle;
                    text = 'OK';
                    break;
                  case SyncStatus.error:
                    color = Colors.orange;
                    icon = Icons.warning;
                    text = 'ERROR';
                    break;
                  default:
                    color = Colors.grey;
                    icon = Icons.pause;
                    text = 'IDLE';
                }
                
                return Card(
                  color: color.withOpacity(0.1),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Icon(icon, color: color),
                        Text(
                          text,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
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

  /// Stream de datos automático
  Widget _buildDataStream() {
    return Expanded(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: manager.dataStream,
        initialData: [],
        builder: (context, snapshot) {
          final data = snapshot.data ?? [];
          
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  Text(
                    'No hay datos aún',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                  Text(
                    'Agrega algunos datos para empezar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final isPending = item['sync'] != 'true' && !item.containsKey('syncDate');
              
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: isPending ? Colors.yellow[50] : Colors.green[50],
                child: ListTile(
                  leading: Icon(
                    isPending ? Icons.upload_outlined : Icons.check_circle,
                    color: isPending ? Colors.orange : Colors.green,
                  ),
                  title: Text(item['title'] ?? 'Sin título'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['body'] ?? 'Sin descripción'),
                      Text(
                        isPending 
                          ? 'Pendiente de subir' 
                          : 'Sincronizado: ${item['syncDate'] ?? 'N/A'}',
                        style: TextStyle(
                          color: isPending ? Colors.orange : Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteItem(index),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Controles de la app
  Widget _buildControls() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // 💾 GUARDAR AUTOMÁTICO
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addRandomData,
                  icon: Icon(Icons.add),
                  label: Text('Agregar Datos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
              SizedBox(width: 8),
              
              // 🔄 SINCRONIZAR MANUAL
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _forceSync,
                  icon: Icon(Icons.sync),
                  label: Text('Sincronizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          Row(
            children: [
              // 🧹 LIMPIAR TODO
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clearAll,
                  icon: Icon(Icons.clear_all),
                  label: Text('Limpiar Todo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              
              SizedBox(width: 8),
              
              // 📊 STATS
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showStats,
                  icon: Icon(Icons.analytics),
                  label: Text('Estadísticas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ✨ AGREGAR DATOS - SE GUARDA Y SINCRONIZA AUTOMÁTICAMENTE
  void _addRandomData() async {
    final data = {
      'title': 'Producto ${DateTime.now().millisecondsSinceEpoch}',
      'body': 'Descripción automática creada a las ${DateTime.now()}',
      'userId': 1,
    };
    
    // 🚀 GUARDAR - Todo automático: Hive se inicializa, se guarda, UI se actualiza, se sincroniza
    await manager.save(data);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Datos guardados y sincronizándose automáticamente'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// 🔄 FORZAR SINCRONIZACIÓN
  void _forceSync() async {
    try {
      await manager.sync();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sincronización completada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error en sincronización: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🗑️ ELIMINAR ITEM
  void _deleteItem(int index) async {
    final data = await manager.getAll();
    if (index < data.length) {
      // Para el ejemplo, eliminamos por posición (en una app real usarías ID único)
      final item = data[index];
      final itemId = item['created_at'] ?? 'unknown';
      
      // Buscar y eliminar por created_at
      final allData = await manager.getAll();
      for (int i = 0; i < allData.length; i++) {
        if (allData[i]['created_at'] == itemId) {
          // En una app real, tendrías un método más directo
          await manager.clear();
          
          // Restaurar todos excepto el eliminado
          for (int j = 0; j < allData.length; j++) {
            if (j != i) {
              await manager.save(allData[j]);
            }
          }
          break;
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Elemento eliminado'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// 🧹 LIMPIAR TODO
  void _clearAll() async {
    await manager.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🧹 Todos los datos eliminados'),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// 📊 MOSTRAR ESTADÍSTICAS
  void _showStats() async {
    final all = await manager.getAll();
    final pending = await manager.getPending();
    final synced = await manager.getSynced();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📊 Estadísticas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📦 Total de registros: ${all.length}'),
            Text('⏳ Pendientes de sincronizar: ${pending.length}'),
            Text('✅ Sincronizados: ${synced.length}'),
            Text('🌐 Estado de conexión: ${manager.isOnline ? "Online" : "Offline"}'),
            Text('🔄 Estado de sync: ${manager.status.toString().split('.').last}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 🧹 LIMPIEZA AUTOMÁTICA
    manager.dispose();
    super.dispose();
  }
}
