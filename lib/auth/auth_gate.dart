// lib/auth/auth_gate.dart

import 'package:app_restaurante/auth/login_screen.dart';
import 'package:app_restaurante/features/orders/order_management_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Ouve as mudanças de autenticação do Firebase em tempo real
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Se ainda estiver verificando, mostra um carregamento
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Se o snapshot tem dados, o usuário está logado
        if (snapshot.hasData) {
          return const OrderManagementScreen();
        }
        // Caso contrário, o usuário não está logado
        else {
          return const LoginScreen();
        }
      },
    );
  }
}
