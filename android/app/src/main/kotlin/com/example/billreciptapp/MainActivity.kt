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

        // Create PDF document with proper thermal receipt dimensions
        val pdfDocument = PdfDocument()
        // 80mm width = 226 points, dynamic height based on content
        val estimatedHeight = 200 + (items.size * 15) + if (language == "ta") 100 else 50
        val pageInfo = PdfDocument.PageInfo.Builder(226, estimatedHeight, 1).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas

        // Paint objects for different text styles with proper spacing
        val titlePaint = Paint().apply {
            color = Color.BLACK
            textSize = 16f
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
            letterSpacing = 0.1f
        }

        val headerPaint = Paint().apply {
            color = Color.BLACK
            textSize = 14f
            isFakeBoldText = true
            textAlign = Paint.Align.CENTER
            letterSpacing = 0.1f
        }

        val normalPaint = Paint().apply {
            color = Color.BLACK
            textSize = 12f  // Increased from 11f to prevent shrinking
            textAlign = Paint.Align.CENTER
            letterSpacing = 0.05f
        }

        val smallPaint = Paint().apply {
            color = Color.BLACK
            textSize = 9f
            textAlign = Paint.Align.LEFT
            letterSpacing = 0.05f
        }

        val centerPaint = Paint().apply {
            color = Color.BLACK
            textSize = 12f  // Increased from 11f to prevent shrinking
            textAlign = Paint.Align.CENTER
            letterSpacing = 0.05f
        }

        val rightAlignPaint = Paint().apply {
            color = Color.BLACK
            textSize = 9f
            textAlign = Paint.Align.RIGHT
            letterSpacing = 0.05f
        }

        val boldSmallPaint = Paint().apply {
            color = Color.BLACK
            textSize = 10f
            isFakeBoldText = true
            textAlign = Paint.Align.LEFT
            letterSpacing = 0.05f
        }

        var yPosition = 25f
        val pageWidth = 226f
        val margin = 8f

        // Header text (Tamil only)
        if (language == "ta") {
            canvas.drawText(headerText, pageWidth / 2, yPosition, centerPaint)
            yPosition += 18f
        }

        // Receipt title
        canvas.drawText(if (language == "ta") "மதிப்பீட்டு ரசீது" else "Receipt", pageWidth / 2, yPosition, titlePaint)
        yPosition += 22f

        // Shop name
        canvas.drawText(shopName, pageWidth / 2, yPosition, headerPaint)
        yPosition += 18f

        // Address
        canvas.drawText(address, pageWidth / 2, yPosition, normalPaint)
        yPosition += 15f

        // City
        canvas.drawText(city, pageWidth / 2, yPosition, normalPaint)
        yPosition += 15f

        // Phone
        canvas.drawText("Phone: $phone", pageWidth / 2, yPosition, normalPaint)
        yPosition += 20f

        // Receipt number and date on same line
        val dateFormat = SimpleDateFormat("hh:mm:ss a dd/MM/yyyy", Locale.getDefault())
        val dateString = dateFormat.format(Date(timestamp))
        
        val receiptNoPaint = Paint().apply {
            color = Color.BLACK
            textSize = 10f
            textAlign = Paint.Align.LEFT
        }
        
        val datePaint = Paint().apply {
            color = Color.BLACK
            textSize = 10f
            textAlign = Paint.Align.RIGHT
        }
        
        canvas.drawText("No: $receiptNumber", margin, yPosition, receiptNoPaint)
        canvas.drawText(dateString, pageWidth - margin, yPosition, datePaint)
        yPosition += 18f

        // Draw separator line
        val linePaint = Paint().apply {
            color = Color.BLACK
            strokeWidth = 1f
        }
        canvas.drawLine(margin, yPosition, pageWidth - margin, yPosition, linePaint)
        yPosition += 12f

        // Table header with fixed positioning to prevent overlap
        val headerBoldPaint = Paint().apply {
            color = Color.BLACK
            textSize = 9f
            isFakeBoldText = true
            textAlign = Paint.Align.LEFT
        }

        // Fixed column positions for 80mm thermal paper (226 points width) - preventing overlap
        val col1 = margin + 2f   // S.No
        val col2 = margin + 25f  // Details - moved right to prevent overlap with S.No
        val col3 = margin + 115f // Qty - slightly adjusted
        val col4 = margin + 145f // Rate - moved left to give more space for amount
        val col5 = margin + 180f // Amount - moved left to ensure visibility

        canvas.drawText("S.No", col1, yPosition, headerBoldPaint)
        canvas.drawText(if (language == "ta") "விபரங்கள்" else "Details", col2, yPosition, headerBoldPaint)
        
        val qtyHeaderPaint = Paint().apply {
            color = Color.BLACK
            textSize = 10f  // Increased from 9f to prevent shrinking
            isFakeBoldText = true
            textAlign = Paint.Align.LEFT
        }
        canvas.drawText(if (language == "ta") "அளவு" else "Qty", col3, yPosition, qtyHeaderPaint)
        
        val rateHeaderPaint = Paint().apply {
            color = Color.BLACK
            textSize = 10f  // Increased from 9f to prevent shrinking
            isFakeBoldText = true
            textAlign = Paint.Align.LEFT
        }
        canvas.drawText(if (language == "ta") "விலை" else "Rate", col4, yPosition, rateHeaderPaint)
        
        val amountHeaderPaint = Paint().apply {
            color = Color.BLACK
            textSize = 10f  // Increased from 9f to prevent shrinking (fixes தொகை shrinking)
            isFakeBoldText = true
            textAlign = Paint.Align.LEFT
        }
        canvas.drawText(if (language == "ta") "தொகை" else "Amount", col5, yPosition, amountHeaderPaint)
        yPosition += 15f

        // Draw separator line
        canvas.drawLine(margin, yPosition, pageWidth - margin, yPosition, linePaint)
        yPosition += 8f

        // Items with precise positioning to avoid overlap
        items.forEachIndexed { index, item ->
            val itemName = item["productName"] as String
            val quantity = item["quantity"] as Double
            val price = item["price"] as Double
            val total = item["total"] as Double
            val unit = item["unit"] as? String ?: ""

            // Truncate item names more aggressively for Tamil text
            val truncatedName = if (itemName.length > 10) {
                itemName.substring(0, 10) + ".."
            } else {
                itemName
            }

            val itemPaint = Paint().apply {
                color = Color.BLACK
                textSize = 8f
                textAlign = Paint.Align.LEFT
            }

            val qtyPaint = Paint().apply {
                color = Color.BLACK
                textSize = 8f
                textAlign = Paint.Align.LEFT
            }

            val pricePaint = Paint().apply {
                color = Color.BLACK
                textSize = 8f
                textAlign = Paint.Align.LEFT
            }

            val totalPaint = Paint().apply {
                color = Color.BLACK
                textSize = 8f
                textAlign = Paint.Align.LEFT
            }

            // Draw items with fixed positions
            canvas.drawText("${index + 1}", col1, yPosition, itemPaint)
            canvas.drawText(truncatedName, col2, yPosition, itemPaint)
            // Show only numbers in quantity column (removed unit)
            canvas.drawText(String.format("%.0f", quantity), col3, yPosition, qtyPaint)
            canvas.drawText(String.format("%.2f", price), col4, yPosition, pricePaint)
            canvas.drawText(String.format("%.2f", total), col5, yPosition, totalPaint)
            yPosition += 13f
        }

        // Draw separator line
        canvas.drawLine(margin, yPosition, pageWidth - margin, yPosition, linePaint)
        yPosition += 12f

        // Total with proper left alignment and better visibility
        val totalLabelPaint = Paint().apply {
            color = Color.BLACK
            textSize = 12f  // Increased size for better visibility
            isFakeBoldText = true
            textAlign = Paint.Align.LEFT
        }

        val totalAmountPaint = Paint().apply {
            color = Color.BLACK
            textSize = 12f  // Increased size for better visibility
            isFakeBoldText = true
            textAlign = Paint.Align.LEFT
        }

        // Left align the total text properly
        canvas.drawText(if (language == "ta") "மொத்தம்:" else "Total:", margin + 120f, yPosition, totalLabelPaint)
        canvas.drawText(String.format("%.2f", totalAmount), col5, yPosition, totalAmountPaint)
        yPosition += 25f

        // Footer messages
        canvas.drawText(if (language == "ta") "நன்றி" else "Thank You", pageWidth / 2, yPosition, centerPaint)
        yPosition += 15f
        canvas.drawText(if (language == "ta") "மீண்டும் வாருங்கள்" else "Visit Again", pageWidth / 2, yPosition, centerPaint)
        yPosition += 20f

        // Tamil footer texts
        if (language == "ta") {
            canvas.drawLine(margin, yPosition, pageWidth - margin, yPosition, linePaint)
            yPosition += 15f
            
            val footerPaint = Paint().apply {
                color = Color.BLACK
                textSize = 9f
                textAlign = Paint.Align.CENTER
            }
            
            canvas.drawText(footerText1, pageWidth / 2, yPosition, footerPaint)
            yPosition += 14f
            canvas.drawText(footerText2, pageWidth / 2, yPosition, footerPaint)
            yPosition += 14f
            canvas.drawText(footerText3, pageWidth / 2, yPosition, footerPaint)
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
