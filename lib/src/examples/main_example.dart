import 'package:flutter/material.dart';
import '../config/global_config.dart';

/// Ejemplo de cómo configurar la librería en main()
/// 
/// Este archivo muestra cómo inicializar la configuración global
/// que será usada automáticamente por todos los managers.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🎯 CONFIGURACIÓN GLOBAL - Solo se hace una vez aquí
  GlobalConfig.init(
    baseUrl: 'https://tu-api.com/api',  // URL de tu servidor
    token: 'tu_token_de_autenticacion', // Token JWT o API key
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ejemplo de Configuración',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración Global'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de configuración
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración Global Activa:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildConfigRow('Base URL:', GlobalConfig.baseUrl ?? 'No configurado'),
                    _buildConfigRow('Token:', GlobalConfig.token?.substring(0, 20) ?? 'No configurado'),
                    _buildConfigRow('Inicializado:', GlobalConfig.isInitialized ? 'Sí' : 'No'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Información de uso
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cómo usar la librería:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('1. La configuración se establece aquí en main()'),
                    Text('2. Los managers usan automáticamente esta configuración'),
                    Text('3. Solo necesitas especificar boxName y endpoint'),
                    Text('4. La sincronización es automática'),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Botón para ir al ejemplo de widgets
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WidgetExampleScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.widgets),
                label: Text('Ver Ejemplo de Widgets'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                backgroundColor: Colors.grey.shade100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WidgetExampleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ejemplo de Widgets'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.widgets,
                size: 64,
                color: Colors.green,
              ),
              SizedBox(height: 16),
              Text(
                'Ejemplo de Widgets',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Ve al archivo widget_example.dart para ver cómo usar la librería en widgets reales.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
