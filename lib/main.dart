// lib/main.dart

import 'package:app_restaurante/auth/auth_gate.dart';
import 'package:app_restaurante/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart'; // IMPORTAÇÃO CORRIGIDA

void main() async {
  // Usamos um try-catch para capturar qualquer erro durante a inicialização.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    // Se ocorrer um erro, exibimos um aplicativo simples com a mensagem de erro.
    runApp(ErrorApp(errorMessage: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerenciador de Pedidos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      // O AuthGate continua sendo a tela inicial.
      home: const AuthGate(),
    );
  }
}

// Um widget simples para exibir erros de inicialização.
class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Ocorreu um erro crítico ao iniciar o aplicativo:\n\n$errorMessage",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
