import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/bill_model.dart';
import '../models/customer_model.dart';
import '../models/milk_record_model.dart';

class PdfInvoiceService {
  static String _safeFileName(String input) {
    return input
        .replaceAll(RegExp(r'[^\w\s-]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Generate a professional, attractive, and colorful monthly milk bill PDF
  static Future<File> generateMonthlyPdf({
    required Customer customer,
    required DateTime month,
    required List<MilkRecord> records,
    required BillRecord? billRecord,
  }) async {
    final pdf = pw.Document();
    final monthName = DateFormat('MMMM yyyy').format(month);

    final now = DateTime.now();
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final curMonthDate = DateTime(now.year, now.month, 1);

    String monthTag;
    if (month.year == prevMonthDate.year && month.month == prevMonthDate.month) {
      monthTag = "Previous Month (Completed)";
    } else if (month.year == curMonthDate.year && month.month == curMonthDate.month) {
      monthTag = "Present Month (Ongoing)";
    } else {
      monthTag = "Custom Month";
    }

    final double totalCost = billRecord?.totalAmount ??
        records.fold<double>(0.0, (sum, r) {
          if (r.status != 'skipped') {
            return sum + (r.effectiveMilkQuantity + r.extraMilk) * customer.pricePerLiter;
          }
          return sum;
        });

    final double totalMilkLiters = records.fold<double>(
      0.0,
      (sum, r) => sum + (r.status == 'skipped' ? 0.0 : r.effectiveMilkQuantity + r.extraMilk),
    );

    final int normalMilkDays = records.where((r) => r.status != 'skipped').length;
    final int skippedDays = records.where((r) => r.status == 'skipped').length;
    final double extraMilk = records.fold<double>(0.0, (sum, r) => sum + r.extraMilk);

    final bool isPaid = billRecord?.isPaid ?? false;
    final double collected = billRecord?.collectedAmount ?? 0.0;
    final double due = billRecord?.dueAmount ?? (totalCost - collected).clamp(0.0, double.infinity);
    final bool isPartiallyPaid = collected > 0 && !isPaid;

    final primaryBlue = PdfColor.fromHex('#1E40AF'); // Deep Blue
    final darkHeader = PdfColor.fromHex('#1E293B');

    final successGreen = PdfColor.fromHex('#15803D');
    final warningOrange = PdfColor.fromHex('#C2410C');
    final lightBg = PdfColor.fromHex('#F8FAFC');
    final borderGrey = PdfColor.fromHex('#CBD5E1');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: pw.BoxDecoration(
              color: primaryBlue,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "MILKIFY",
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Fresh Dairy Milk Delivery Service",
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        "MONTHLY INVOICE",
                        style: pw.TextStyle(
                          color: primaryBlue,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      monthName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    pw.Text(
                      "Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Customer & Summary Details Cards
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Customer Card
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F0FDF4'), // Light Mint
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColor.fromHex('#BBF7D0'), width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "BILLED TO",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#166534'),
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        customer.name,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: darkHeader,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (customer.phone.isNotEmpty)
                        pw.Text(
                          "Phone: ${customer.phone}",
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                        ),
                      if (customer.address.isNotEmpty)
                        pw.Text(
                          "Address: ${customer.address}",
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                        ),
                      pw.Text(
                        "Preferred Timing: ${customer.time}",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),

              // Billing Details Card
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EFF6FF'), // Light Blue
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE'), width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "BILLING SUMMARY",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryBlue,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Billing Cycle: $monthName",
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkHeader),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Cycle Type: $monthTag",
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Milk Rate: Rs ${customer.pricePerLiter.toStringAsFixed(2)} / L",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                      pw.Text(
                        "Active Milk Days: $normalMilkDays days (Extra: ${extraMilk.toStringAsFixed(1)} L, Skipped: $skippedDays)",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),

                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // 4 Metric Highlight Badges
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EEF2FF'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#C7D2FE')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("TOTAL MILK", style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#4338CA'), fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("${totalMilkLiters.toStringAsFixed(1)} L", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkHeader)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EFF6FF'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("TOTAL BILL", style: pw.TextStyle(fontSize: 8, color: primaryBlue, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("Rs ${totalCost.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkHeader)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F0FDF4'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#BBF7D0')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("COLLECTED", style: pw.TextStyle(fontSize: 8, color: successGreen, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("Rs ${collected.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: successGreen)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FFF7ED'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#FED7AA')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("PENDING DUE", style: pw.TextStyle(fontSize: 8, color: warningOrange, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("Rs ${due.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: warningOrange)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Daily Breakdown Section Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "DAILY CONSUMPTION BREAKDOWN",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: darkHeader,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Text(
                "${records.length} records",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Table
          pw.TableHelper.fromTextArray(
            headers: ["Date", "Regular (L)", "Extra (L)", "Total (L)", "Status", "Amount (Rs)"],
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: pw.BoxDecoration(
              color: primaryBlue,
            ),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
            },
            oddRowDecoration: pw.BoxDecoration(color: lightBg),
            data: records.map((r) {
              final isSkipped = r.status == 'skipped';
              final dayLiters = isSkipped ? 0.0 : (r.effectiveMilkQuantity + r.extraMilk);
              final amount = dayLiters * customer.pricePerLiter;
              final statusText = isSkipped
                  ? 'Skipped'
                  : (r.effectiveMilkQuantity < r.milkQuantity ? 'Less' : 'Normal');

              return [
                DateFormat('dd MMM yyyy (EEE)').format(DateTime.parse(r.date)),
                r.effectiveMilkQuantity.toStringAsFixed(2),
                r.extraMilk.toStringAsFixed(2),
                dayLiters.toStringAsFixed(2),
                statusText,
                amount.toStringAsFixed(2),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),

          // Payment Summary & Status Stamp Box
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Payment Status Stamp Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: isPaid
                      ? PdfColor.fromHex('#F0FDF4')
                      : (isPartiallyPaid ? PdfColor.fromHex('#EFF6FF') : PdfColor.fromHex('#FFF7ED')),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: isPaid
                        ? successGreen
                        : (isPartiallyPaid ? primaryBlue : warningOrange),
                    width: 1.5,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "PAYMENT STATUS",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: isPaid ? successGreen : (isPartiallyPaid ? primaryBlue : warningOrange),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      isPaid ? "FULLY PAID" : (isPartiallyPaid ? "PARTIALLY PAID" : "UNPAID"),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: isPaid ? successGreen : (isPartiallyPaid ? primaryBlue : warningOrange),
                        letterSpacing: 1,
                      ),
                    ),
                    if (billRecord?.paymentDate != null) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "Last Recorded Payment: ${DateFormat('dd MMM yyyy').format(DateTime.parse(billRecord!.paymentDate!))}",
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ],
                ),
              ),

              // Total Calculation Summary Card
              pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderGrey, width: 1),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Total Amount:", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                        pw.Text("Rs ${totalCost.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Amount Collected:", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                        pw.Text("Rs ${collected.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: successGreen)),
                      ],
                    ),
                    pw.Divider(color: borderGrey, height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Remaining Due:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkHeader)),
                        pw.Text("Rs ${due.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: due > 0 ? warningOrange : successGreen)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Footer Notice
          pw.Divider(color: borderGrey),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              "Thank you for choosing Milkify Dairy Service! For inquiries or adjustments, please contact your delivery provider.",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();

    final safeCustomerName = _safeFileName(customer.name);
    final safeMonth = monthName.replaceAll(' ', '_');
    final file = File('${dir.path}/Milk_Bill_${safeCustomerName}_$safeMonth.pdf');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
