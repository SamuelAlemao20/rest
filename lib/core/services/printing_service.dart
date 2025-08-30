// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
// Nova importação necessária para a conversão de tipos
import 'dart:js_interop';
// A nova biblioteca moderna para interagir com o navegador
import 'package:web/web.dart' as web;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class PrintingService {
  // Função para escapar caracteres HTML e evitar quebras no layout
  String _escapeHtml(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  void printOrder(Map<String, dynamic> orderData) {
    if (!kIsWeb) {
      debugPrint("A função de impressão só está disponível na web.");
      return;
    }

    // --- Extração e Formatação dos Dados (continua igual) ---
    final timestamp = orderData['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate = date != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(date)
        : 'Data Indisponível';

    final clientName =
        orderData['userName'] as String? ?? 'Cliente não informado';
    final clientPhone =
        orderData['userPhone'] as String? ?? 'Telefone não informado';
    final paymentMethod =
        orderData['paymentMethod'] as String? ?? 'Não informado';

    final items = (orderData['items'] as List).cast<Map<String, dynamic>>();
    final totalAmount =
        (orderData['totalAmount'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final orderType = orderData['orderType'] as String? ?? 'Não especificado';

    String addressInfo = 'Retirada no Balcão';
    if (orderType == 'entrega' && orderData['deliveryAddress'] != null) {
      final address = orderData['deliveryAddress'] as Map<String, dynamic>;
      final street = address['street'] ?? '';
      final number = address['number'] ?? '';
      addressInfo = 'Endereço: $street, $number';
    }

    final itemsHtml = items
        .map((item) {
          final name = _escapeHtml(item['name'] as String?);
          final quantity = item['quantity'] ?? 0;
          final price = (item['price'] as num?)?.toStringAsFixed(2) ?? '0.00';
          return '''
        <tr>
          <td>${quantity}x</td>
          <td>$name</td>
          <td style="text-align: right;">R\$ $price</td>
        </tr>
      ''';
        })
        .join('');

    // --- Template HTML Completo (continua igual) ---
    final htmlContent =
        '''
    <html>
      <head>
        <title>Pedido</title>
        <style>
          body { font-family: 'Courier New', monospace; margin: 0; padding: 10px; }
          .receipt { width: 280px; /* Ajustado para impressora POS 58mm */ }
          h3, h4 { text-align: center; margin: 5px 0; }
          p { margin: 2px 0; font-size: 12px; }
          hr { border: none; border-top: 1px dashed #000; }
          table { width: 100%; border-collapse: collapse; font-size: 12px; }
          th, td { padding: 2px 0; }
          .total { font-weight: bold; font-size: 1.1em; }
          .client-info { margin-top: 10px; }
        </style>
      </head>
      <body>
        <div class="receipt">
          <h3>** NOVO PEDIDO **</h3>
          <p>Data: ${_escapeHtml(formattedDate)}</p>
          <hr>
          
          <div class="client-info">
            <h4>DADOS DO CLIENTE</h4>
            <p><b>Nome:</b> ${_escapeHtml(clientName)}</p>
            <p><b>Telefone:</b> ${_escapeHtml(clientPhone)}</p>
            <p>${_escapeHtml(addressInfo)}</p>
          </div>
          <hr>

          <h4>ITENS DO PEDIDO</h4>
          <table>
            <thead>
              <tr>
                <th style="text-align: left;">Qtd</th>
                <th style-align: left;">Item</th>
                <th style="text-align: right;">Preço</th>
              </tr>
            </thead>
            <tbody>
              $itemsHtml
            </tbody>
          </table>
          <hr>

          <p><b>Forma de Pagamento:</b> ${_escapeHtml(paymentMethod)}</p>
          <p class="total">TOTAL: R\$ $totalAmount</p>
          <hr>
          <p><b>Tipo de Pedido: ${_escapeHtml(orderType.toUpperCase())}</b></p>
        </div>
      </body>
    </html>
    ''';

    // --- LÓGICA DE IMPRESSÃO CORRIGIDA USANDO BLOB ---
    try {
      final blob = web.Blob(
        [htmlContent.toJS].toJS,
        // CORREÇÃO 1: Passar a String do Dart diretamente.
        web.BlobPropertyBag(type: 'text/html'),
      );
      final url = web.URL.createObjectURL(blob);

      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.style.display = 'none';

      // CORREÇÃO 2: A URL já é uma String do Dart, não precisa de conversão.
      iframe.src = url;

      iframe.onload = (web.Event event) {
        Future.delayed(const Duration(milliseconds: 250), () {
          iframe.contentWindow?.print();
          web.URL.revokeObjectURL(url);
          iframe.remove();
        });
      }.toJS;

      web.document.body?.append(iframe);
    } catch (e) {
      debugPrint("Ocorreu um erro ao tentar imprimir via iframe: $e");
    }
  }
}
