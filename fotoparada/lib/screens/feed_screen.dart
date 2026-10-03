import 'package:flutter/material.dart';
import '../models/foto_model.dart';
import '../services/api_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Instancia de nuestro servicio para peticiones HTTP
  final ApiService _apiService = ApiService();
  
  // Lista que almacenará los datos obtenidos
  List<Foto> _fotos = [];
  
  // Variable booleana para manejar el estado de carga
  bool _isLoading = true;
  
  // Variable para guardar un mensaje de error si ocurre alguno
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Llamamos a la API justo cuando el widget se inicializa
    _cargarFotos();
  }

  // Método privado para obtener las fotos de forma asíncrona
  Future<void> _cargarFotos() async {
    try {
      // Obtenemos los datos desde el servicio
      final fotosObtenidas = await _apiService.obtenerFotos();
      
      // Actualizamos la pantalla usando setState de forma básica
      setState(() {
        _fotos = fotosObtenidas;
        _isLoading = false; // Finalizamos el indicador de carga
      });
    } catch (e) {
      // En caso de error, mostramos el mensaje y detenemos la carga
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FotoParada Feed'),
        centerTitle: true,
      ),
      // Construimos el cuerpo de la vista en base al estado actual
      body: _construirCuerpo(),
    );
  }

  Widget _construirCuerpo() {
    // 1. Mostrar un indicador de carga mientras esperamos la respuesta
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 2. Mostrar un mensaje si hubo error
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 3. Mostrar mensaje si la lista de fotos está vacía
    if (_fotos.isEmpty) {
      return const Center(
        child: Text('No hay fotos disponibles.'),
      );
    }

    // 4. Mostrar la lista de fotos
    return ListView.builder(
      itemCount: _fotos.length,
      itemBuilder: (context, index) {
        final foto = _fotos[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Imagen de la foto
              Image.network(
                foto.urlImagen,
                height: 200,
                fit: BoxFit.cover,
                // Manejador en caso de que falle la carga de la imagen
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.broken_image, size: 100),
              ),
              // Detalles de la foto
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foto.titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ubicación: ${foto.latitud}, ${foto.longitud}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
