import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/crash_event.dart';
import '../services/preferences_service.dart';

class PdfExport {
  static Future<void> generateAndPrintCrashReport(CrashEvent event) async {
    final pdf = pw.Document();

    final riderName = PreferencesService.riderName;
    final bloodType = PreferencesService.bloodType;
    final emergencyContactNumber = PreferencesService.emergencyContactPhone;
    final dateStr = '${event.timestamp.day}/${event.timestamp.month}/${event.timestamp.year} ${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}';
    
    // Convert to Maps URL for easy visualization
    final mapsLink = 'https://maps.google.com/?q=${event.latitude},${event.longitude}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('IMPACT NODE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Text('OFFICIAL INCIDENT REPORT', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ]
                )
              ),
              
              pw.SizedBox(height: 20),
              
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                color: PdfColors.grey200,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RIDER DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Divider(),
                    pw.Text('Name: $riderName'),
                    pw.Text('Blood Type: $bloodType'),
                    pw.Text('Emergency Contact: $emergencyContactNumber'),
                  ]
                )
              ),
              
              pw.SizedBox(height: 20),
              
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red800, width: 2)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INCIDENT FORENSICS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Date & Time:'),
                        pw.Text(dateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Peak Impact G-Force:'),
                        pw.Text('${event.gForcePeak.toStringAsFixed(2)} Gs', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Impact Speed:'),
                        pw.Text('${event.speedKmph.toStringAsFixed(1)} km/h', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Maximum Tilt Angle:'),
                        pw.Text('${event.tiltAngle.toStringAsFixed(1)} degrees', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('GPS Coordinates:'),
                        pw.Text('${event.latitude}, ${event.longitude}'),
                      ]
                    ),
                    pw.SizedBox(height: 5),
                    pw.UrlLink(
                      destination: mapsLink,
                      child: pw.Text('View Location on Google Maps', style: const pw.TextStyle(color: PdfColors.blue, decoration: pw.TextDecoration.underline))
                    )
                  ]
                )
              ),
              
              pw.SizedBox(height: 40),
              
              pw.Text('This automated telemetry report was generated by Impact Node onboard ML sensing.'),
              pw.SizedBox(height: 10),
              pw.Text('Report ID: ${event.id ?? 'Pending'}', style: const pw.TextStyle(color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    // Share or print PDF directly via native Share / Print dialogs
    await Printing.sharePdf(
      bytes: await pdf.save(), 
      filename: 'ImpactNode_Incident_${event.id ?? "Unknown"}.pdf'
    );
  }
}
