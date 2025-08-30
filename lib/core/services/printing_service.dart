// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: "DO NOT REMOVE"
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class PrintingService {
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
    // Garante que o código só rode na web.
    if (!kIsWeb) {
      debugPrint("A função de impressão só está disponível na web.");
      return;
    }

    // --- Extração e Formatação dos Dados ---
    final timestamp = orderData['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate = date != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(date)
        : 'Data Indisponível';

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

    // --- Template HTML Completo ---
    final htmlContent =
        '''
    <html>
      <head>
        <title>Pedido</title>
        <style>
          body { font-family: 'Courier New', monospace; margin: 0; padding: 10px; }
          .receipt { width: 280px; /* Ajustado para impressora POS 58mm */ }
          h3 { text-align: center; margin: 5px 0; }
          p { margin: 2px 0; font-size: 12px; }
          hr { border: none; border-top: 1px dashed #000; }
          table { width: 100%; border-collapse: collapse; font-size: 12px; }
          th, td { padding: 2px 0; }
          .total { font-weight: bold; font-size: 1.1em; }
        </style>
      </head>
      <body onafterprint="window.close()"> <!-- Fecha a janela após imprimir -->
        <div class="receipt">
          <h3>** NOVO PEDIDO **</h3>
          <p>Data: ${_escapeHtml(formattedDate)}</p>
          <hr>
          <table>
            <thead>
              <tr>
                <th style="text-align: left;">Qtd</th>
                <th style="text-align: left;">Item</th>
                <th style="text-align: right;">Preço</th>
              </tr>
            </thead>
            <tbody>
              $itemsHtml
            </tbody>
          </table>
          <hr>
          <p class="total">Total: R\$ $totalAmount</p>
          <hr>
          <p><b>Tipo: ${_escapeHtml(orderType.toUpperCase())}</b></p>
          <p>${_escapeHtml(addressInfo)}</p>
        </div>
      </body>
    </html>
    ''';

    try {
      // Abre uma nova janela em branco de forma síncrona.
      final printWindow = html.window.open(
        '',
        '_blank',
        'height=600,width=400',
      );

      if (printWindow == null) {
        debugPrint(
          "IMPRESSÃO BLOQUEADA: Verifique o bloqueador de pop-ups do seu navegador.",
        );
        // Em um app real, você poderia mostrar um diálogo para o usuário aqui.
        return;
      }

      // Escreve o conteúdo HTML na nova janela.
      printWindow.document.write(htmlContent);
      printWindow.document.close(); // Essencial para finalizar a escrita.

      // Foca na janela e chama a impressão.
      printWindow.focus();
      printWindow.print();
    } catch (e) {
      debugPrint("Ocorreu um erro ao tentar imprimir: $e");
    }
  }
}
