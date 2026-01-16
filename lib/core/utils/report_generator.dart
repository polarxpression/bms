import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:bms/core/models/battery.dart';
import 'package:intl/intl.dart';

class ReportGenerator {
  static Future<void> generateBuyReport(
    List<Battery> batteries, {
    int? roundToMultiplesOf,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

    // Fetch the logo SVG string
    String? logoSvg;
    try {
      final ByteData data = await NetworkAssetBundle(
        Uri.parse('https://polar.is-a.dev/images/logo-black.svg'),
      ).load("");
      logoSvg = utf8.decode(data.buffer.asUint8List());
    } catch (e) {
      // Fail silently or log if needed, logo will just be omitted
      print('Error loading logo: $e');
    }

    // Calculate totals
    int totalItems = 0;
    int totalQtyToBuy = 0;

    final tableRows = <pw.TableRow>[];

    // Header Row
    tableRows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              'Produto',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              'Qtd',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              'Cód. Barras',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    for (final b in batteries) {
      int needed = (b.minStockThreshold - b.quantity).clamp(0, 9999);

      if (roundToMultiplesOf != null && roundToMultiplesOf > 0 && needed > 0) {
        needed = (needed / roundToMultiplesOf).ceil() * roundToMultiplesOf;
      }

      totalItems++;
      totalQtyToBuy += needed;

      tableRows.add(
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${b.brand} ${b.model}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 12),
                  ),
                  pw.Text(
                    'Tipo: ${b.type} | Pack: ${b.packSize}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                needed.toString(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: b.barcode.isNotEmpty
                  ? pw.Text(
                      b.barcode,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10),
                    )
                  : pw.Text('-', textAlign: pw.TextAlign.center),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          3.0 * PdfPageFormat.cm,
          3.0 * PdfPageFormat.cm,
          2.0 * PdfPageFormat.cm,
          2.0 * PdfPageFormat.cm,
        ),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text(
              'Página ${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.bottomRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'BMS',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (logoSvg != null) ...[
                  pw.SizedBox(width: 8),
                  pw.SvgImage(svg: logoSvg, height: 20),
                ],
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'RELATÓRIO DE COMPRAS - BMS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Data de emissão: $dateStr',
                    style: const pw.TextStyle(fontSize: 12),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              children: tableRows,
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total de Itens: $totalItems',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Text(
                  'Total a Comprar: $totalQtyToBuy',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'relatorio_compras_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }
}
