package com.example.billreciptapp

import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Environment
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "pdf_generator"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generatePdf" -> {
                    try {
                        val arguments = call.arguments as Map<String, Any>
                        val pdfBytes = generatePdf(arguments)
                        result.success(pdfBytes)
                    } catch (e: Exception) {
                        result.error("PDF_GENERATION_ERROR", e.message, null)
                    }
                }
                "savePdf" -> {
                    try {
                        val arguments = call.arguments as Map<String, Any>
                        val pdfBytes = arguments["pdfBytes"] as ByteArray
                        val fileName = arguments["fileName"] as String
                        val success = savePdf(pdfBytes, fileName)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("PDF_SAVE_ERROR", e.message, null)
                    }
                }
                "sharePdf" -> {
                    try {
                        val arguments = call.arguments as Map<String, Any>
                        val pdfBytes = arguments["pdfBytes"] as ByteArray
                        val fileName = arguments["fileName"] as String
                        val shareText = arguments["shareText"] as String
                        val success = sharePdf(pdfBytes, fileName, shareText)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("PDF_SHARE_ERROR", e.message, null)
                    }
                }
                "printPdf" -> {
                    try {
                        val arguments = call.arguments as Map<String, Any>
                        val pdfBytes = arguments["pdfBytes"] as ByteArray
                        val jobName = arguments["jobName"] as String
                        val success = printPdf(pdfBytes, jobName)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("PDF_PRINT_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun generatePdf(arguments: Map<String, Any>): ByteArray {
        val shopName = arguments["shopName"] as String
        val address = arguments["address"] as String
        val city = arguments["city"] as String
        val phone = arguments["phone"] as String
        val headerText = arguments["headerText"] as String
        val footerText1 = arguments["footerText1"] as String
        val footerText2 = arguments["footerText2"] as String
        val footerText3 = arguments["footerText3"] as String
        val receiptNumber = arguments["receiptNumber"] as Int
        val items = arguments["items"] as List<Map<String, Any>>
        val totalAmount = arguments["totalAmount"] as Double
        val language = arguments["language"] as String
        val timestamp = arguments["timestamp"] as Long

        // Create PDF document
        val pdfDocument = PdfDocument()
        val pageInfo = PdfDocument.PageInfo.Builder(226, 800, 1).create() // 80mm width
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas

        // Paint objects for different text styles
        val titlePaint = Paint().apply {
            color = Color.BLACK
            textSize = 14f
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }

        val headerPaint = Paint().apply {
            color = Color.BLACK
            textSize = 12f
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
        }

        val normalPaint = Paint().apply {
            color = Color.BLACK
            textSize = 10f
            textAlign = Paint.Align.LEFT
        }

        val smallPaint = Paint().apply {
            color = Color.BLACK
            textSize = 8f
            textAlign = Paint.Align.LEFT
        }

        val centerPaint = Paint().apply {
            color = Color.BLACK
            textSize = 10f
            textAlign = Paint.Align.CENTER
        }

        var yPosition = 30f
        val pageWidth = 226f
        val margin = 10f

        // Header
        if (language == "ta") {
            canvas.drawText(headerText, pageWidth / 2, yPosition, centerPaint)
            yPosition += 20f
        }

        canvas.drawText(if (language == "ta") "மதிப்பீட்டு ரசீது" else "Receipt", pageWidth / 2, yPosition, titlePaint)
        yPosition += 20f

        canvas.drawText(shopName, pageWidth / 2, yPosition, headerPaint)
        yPosition += 15f

        canvas.drawText(address, pageWidth / 2, yPosition, normalPaint)
        yPosition += 12f

        canvas.drawText(city, pageWidth / 2, yPosition, normalPaint)
        yPosition += 12f

        canvas.drawText("Phone: $phone", pageWidth / 2, yPosition, normalPaint)
        yPosition += 20f

        // Receipt number and date
        val dateFormat = SimpleDateFormat("hh:mm:ss a dd/MM/yyyy", Locale.getDefault())
        val dateString = dateFormat.format(Date(timestamp))
        
        canvas.drawText("No: $receiptNumber", margin, yPosition, normalPaint)
        canvas.drawText(dateString, pageWidth - margin - 80f, yPosition, normalPaint)
        yPosition += 20f

        // Draw line
        canvas.drawLine(margin, yPosition, pageWidth - margin, yPosition, normalPaint)
        yPosition += 15f

        // Table header
        canvas.drawText("", margin, yPosition, normalPaint)
        canvas.drawText(if (language == "ta") "விபரங்கள்" else "Details", margin + 15f, yPosition, normalPaint)
        canvas.drawText(if (language == "ta") "அளவு" else "Qty", margin + 105f, yPosition, normalPaint)
        canvas.drawText(if (language == "ta") "விலை" else "Rate", margin + 140f, yPosition, normalPaint)
        canvas.drawText(if (language == "ta") "தொகை" else "Amount", margin + 180f, yPosition, normalPaint)
        yPosition += 15f

        // Draw line
        canvas.drawLine(margin, yPosition, pageWidth - margin, yPosition, normalPaint)
        yPosition += 10f

        // Items
        items.forEachIndexed { index, item ->
            val itemName = item["productName"] as String
            val quantity = item["quantity"] as Double
            val price = item["price"] as Double
            val total = item["total"] as Double
            val unit = item["unit"] as? String ?: ""

            canvas.drawText("${index + 1}", margin, yPosition, smallPaint)
            canvas.drawText(itemName, margin + 15f, yPosition, smallPaint)
            canvas.drawText("$quantity$unit", margin + 105f, yPosition, smallPaint)
            canvas.drawText(String.format("%.2f", price), margin + 140f, yPosition, smallPaint)
            canvas.drawText(String.format("%.2f", total), margin + 180f, yPosition, smallPaint)
            yPosition += 12f
        }

        // Draw line
        canvas.drawLine(margin, yPosition, pageWidth - margin, yPosition, normalPaint)
        yPosition += 15f

        // Total
        canvas.drawText(if (language == "ta") "மொத்தம்:" else "Total:", margin + 140f, yPosition, headerPaint)
        canvas.drawText(String.format("%.2f", totalAmount), margin + 180f, yPosition, headerPaint)
        yPosition += 25f

        // Footer
        canvas.drawText(if (language == "ta") "நன்றி" else "Thank You", pageWidth / 2, yPosition, centerPaint)
        yPosition += 15f
        canvas.drawText(if (language == "ta") "மீண்டும் வாருங்கள்" else "Visit Again", pageWidth / 2, yPosition, centerPaint)
        yPosition += 20f

        if (language == "ta") {
            canvas.drawLine(margin, yPosition, pageWidth - margin, yPosition, normalPaint)
            yPosition += 15f
            canvas.drawText(footerText1, pageWidth / 2, yPosition, smallPaint)
            yPosition += 12f
            canvas.drawText(footerText2, pageWidth / 2, yPosition, smallPaint)
            yPosition += 12f
            canvas.drawText(footerText3, pageWidth / 2, yPosition, smallPaint)
        }

        pdfDocument.finishPage(page)

        // Convert to byte array
        val outputStream = java.io.ByteArrayOutputStream()
        pdfDocument.writeTo(outputStream)
        pdfDocument.close()

        return outputStream.toByteArray()
    }

    private fun savePdf(pdfBytes: ByteArray, fileName: String): Boolean {
        return try {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val file = File(downloadsDir, fileName)
            val fos = FileOutputStream(file)
            fos.write(pdfBytes)
            fos.close()
            true
        } catch (e: IOException) {
            false
        }
    }

    private fun sharePdf(pdfBytes: ByteArray, fileName: String, shareText: String): Boolean {
        return try {
            val cacheDir = File(cacheDir, "pdfs")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            
            val file = File(cacheDir, fileName)
            val fos = FileOutputStream(file)
            fos.write(pdfBytes)
            fos.close()

            val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
            
            val shareIntent = Intent().apply {
                action = Intent.ACTION_SEND
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, shareText)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            
            startActivity(Intent.createChooser(shareIntent, "Share PDF"))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun printPdf(pdfBytes: ByteArray, jobName: String): Boolean {
        return try {
            val cacheDir = File(cacheDir, "pdfs")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            
            val file = File(cacheDir, "$jobName.pdf")
            val fos = FileOutputStream(file)
            fos.write(pdfBytes)
            fos.close()

            val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
            
            val printIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/pdf")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            startActivity(printIntent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
