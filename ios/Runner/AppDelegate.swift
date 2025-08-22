import UIKit
import Flutter
import PDFKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let pdfChannel = FlutterMethodChannel(name: "pdf_generator",
                                          binaryMessenger: controller.binaryMessenger)
    
    pdfChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "generatePdf":
        if let args = call.arguments as? [String: Any] {
          self.generatePdf(arguments: args, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        }
      case "savePdf":
        if let args = call.arguments as? [String: Any] {
          self.savePdf(arguments: args, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        }
      case "sharePdf":
        if let args = call.arguments as? [String: Any] {
          self.sharePdf(arguments: args, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        }
      case "printPdf":
        if let args = call.arguments as? [String: Any] {
          self.printPdf(arguments: args, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func generatePdf(arguments: [String: Any], result: @escaping FlutterResult) {
    guard let shopName = arguments["shopName"] as? String,
          let address = arguments["address"] as? String,
          let city = arguments["city"] as? String,
          let phone = arguments["phone"] as? String,
          let headerText = arguments["headerText"] as? String,
          let footerText1 = arguments["footerText1"] as? String,
          let footerText2 = arguments["footerText2"] as? String,
          let footerText3 = arguments["footerText3"] as? String,
          let receiptNumber = arguments["receiptNumber"] as? Int,
          let items = arguments["items"] as? [[String: Any]],
          let totalAmount = arguments["totalAmount"] as? Double,
          let language = arguments["language"] as? String,
          let timestamp = arguments["timestamp"] as? Int64 else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }
    
    let pdfData = createPDF(
      shopName: shopName,
      address: address,
      city: city,
      phone: phone,
      headerText: headerText,
      footerText1: footerText1,
      footerText2: footerText2,
      footerText3: footerText3,
      receiptNumber: receiptNumber,
      items: items,
      totalAmount: totalAmount,
      language: language,
      timestamp: timestamp
    )
    
    result(FlutterStandardTypedData(bytes: pdfData))
  }
  
  private func savePdf(arguments: [String: Any], result: @escaping FlutterResult) {
    guard let pdfData = arguments["pdfBytes"] as? FlutterStandardTypedData,
          let fileName = arguments["fileName"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }
    
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let pdfPath = documentsPath.appendingPathComponent(fileName)
    
    do {
      try pdfData.data.write(to: pdfPath)
      result(true)
    } catch {
      result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
    }
  }
  
  private func sharePdf(arguments: [String: Any], result: @escaping FlutterResult) {
    guard let pdfData = arguments["pdfBytes"] as? FlutterStandardTypedData,
          let fileName = arguments["fileName"] as? String,
          let shareText = arguments["shareText"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }
    
    let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    
    do {
      try pdfData.data.write(to: tempPath)
      
      DispatchQueue.main.async {
        let activityViewController = UIActivityViewController(activityItems: [shareText, tempPath], applicationActivities: nil)
        
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
          if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
          }
          rootViewController.present(activityViewController, animated: true, completion: nil)
        }
      }
      
      result(true)
    } catch {
      result(FlutterError(code: "SHARE_ERROR", message: error.localizedDescription, details: nil))
    }
  }
  
  private func printPdf(arguments: [String: Any], result: @escaping FlutterResult) {
    guard let pdfData = arguments["pdfBytes"] as? FlutterStandardTypedData,
          let jobName = arguments["jobName"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
      return
    }
    
    DispatchQueue.main.async {
      let printController = UIPrintInteractionController.shared
      let printInfo = UIPrintInfo(dictionary: nil)
      printInfo.outputType = .general
      printInfo.jobName = jobName
      printController.printInfo = printInfo
      printController.printingItem = pdfData.data
      
      printController.present(animated: true) { (controller, completed, error) in
        if let error = error {
          result(FlutterError(code: "PRINT_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(completed)
        }
      }
    }
  }
  
  private func createPDF(
    shopName: String,
    address: String,
    city: String,
    phone: String,
    headerText: String,
    footerText1: String,
    footerText2: String,
    footerText3: String,
    receiptNumber: Int,
    items: [[String: Any]],
    totalAmount: Double,
    language: String,
    timestamp: Int64
  ) -> Data {
    
    // Dynamic height calculation based on content
    let estimatedHeight = 200 + (items.count * 15) + (language == "ta" ? 100 : 50)
    let pageRect = CGRect(x: 0, y: 0, width: 226, height: estimatedHeight) // 80mm width
    let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
    
    let data = renderer.pdfData { (context) in
      context.beginPage()
      
      var yPosition: CGFloat = 25
      let margin: CGFloat = 8
      let pageWidth: CGFloat = 226
      
      // Improved fonts with better spacing
      let titleFont = UIFont.boldSystemFont(ofSize: 16)
      let headerFont = UIFont.boldSystemFont(ofSize: 14)
      let normalFont = UIFont.systemFont(ofSize: 11)
      let smallFont = UIFont.systemFont(ofSize: 9)
      let boldSmallFont = UIFont.boldSystemFont(ofSize: 10)
      
      // Header text (Tamil only)
      if language == "ta" {
        let headerRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 18)
        headerText.draw(in: headerRect, withAttributes: [
          .font: normalFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
          }()
        ])
        yPosition += 18
      }
      
      // Receipt title
      let titleText = language == "ta" ? "மதிப்பீட்டு ரசீது" : "Receipt"
      let titleRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 22)
      titleText.draw(in: titleRect, withAttributes: [
        .font: titleFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 22
      
      // Shop name
      let shopRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 18)
      shopName.draw(in: shopRect, withAttributes: [
        .font: headerFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 18
      
      // Address
      let addressRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 15)
      address.draw(in: addressRect, withAttributes: [
        .font: normalFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 15
      
      // City
      let cityRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 15)
      city.draw(in: cityRect, withAttributes: [
        .font: normalFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 15
      
      // Phone
      let phoneRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 15)
      "Phone: \(phone)".draw(in: phoneRect, withAttributes: [
        .font: normalFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 20
      
      // Receipt number and date
      let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "hh:mm:ss a dd/MM/yyyy"
      let dateString = dateFormatter.string(from: date)
      
      let receiptNoRect = CGRect(x: margin, y: yPosition, width: 100, height: 12)
      "No: \(receiptNumber)".draw(in: receiptNoRect, withAttributes: [
        .font: smallFont,
        .foregroundColor: UIColor.black
      ])
      
      let dateRect = CGRect(x: pageWidth - margin - 80, y: yPosition, width: 80, height: 12)
      dateString.draw(in: dateRect, withAttributes: [
        .font: smallFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .right
          return style
        }()
      ])
      yPosition += 18
      
      // Draw separator line
      let context = UIGraphicsGetCurrentContext()!
      context.setStrokeColor(UIColor.black.cgColor)
      context.setLineWidth(1.0)
      context.move(to: CGPoint(x: margin, y: yPosition))
      context.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
      context.strokePath()
      yPosition += 12
      
      // Table header with proper column alignment
      let col1: CGFloat = margin + 2  // S.No
      let col2: CGFloat = margin + 18 // Details
      let col3: CGFloat = margin + 120 // Qty
      let col4: CGFloat = margin + 155 // Rate
      let col5: CGFloat = margin + 190 // Amount
      
      "S.No".draw(at: CGPoint(x: col1, y: yPosition), withAttributes: [.font: boldSmallFont, .foregroundColor: UIColor.black])
      
      let detailsText = language == "ta" ? "விபரங்கள்" : "Details"
      detailsText.draw(at: CGPoint(x: col2, y: yPosition), withAttributes: [.font: boldSmallFont, .foregroundColor: UIColor.black])
      
      let qtyText = language == "ta" ? "அளவு" : "Qty"
      let qtyRect = CGRect(x: col3 - 15, y: yPosition, width: 30, height: 12)
      qtyText.draw(in: qtyRect, withAttributes: [
        .font: boldSmallFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      
      let rateText = language == "ta" ? "விலை" : "Rate"
      let rateRect = CGRect(x: col4 - 20, y: yPosition, width: 40, height: 12)
      rateText.draw(in: rateRect, withAttributes: [
        .font: boldSmallFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .right
          return style
        }()
      ])
      
      let amountText = language == "ta" ? "தொகை" : "Amount"
      let amountRect = CGRect(x: col5 - 25, y: yPosition, width: 35, height: 12)
      amountText.draw(in: amountRect, withAttributes: [
        .font: boldSmallFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .right
          return style
        }()
      ])
      yPosition += 15
      
      // Draw separator line
      context.move(to: CGPoint(x: margin, y: yPosition))
      context.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
      context.strokePath()
      yPosition += 8
      
      // Items with proper alignment and spacing
      for (index, item) in items.enumerated() {
        let itemName = item["productName"] as? String ?? ""
        let quantity = item["quantity"] as? Double ?? 0
        let price = item["price"] as? Double ?? 0
        let total = item["total"] as? Double ?? 0
        let unit = item["unit"] as? String ?? ""
        
        // Truncate long item names to prevent overlap
        let truncatedName = itemName.count > 15 ? String(itemName.prefix(15)) + "..." : itemName
        
        "\(index + 1)".draw(at: CGPoint(x: col1, y: yPosition), withAttributes: [.font: smallFont, .foregroundColor: UIColor.black])
        truncatedName.draw(at: CGPoint(x: col2, y: yPosition), withAttributes: [.font: smallFont, .foregroundColor: UIColor.black])
        
        let qtyItemRect = CGRect(x: col3 - 15, y: yPosition, width: 30, height: 12)
        "\(quantity)\(unit)".draw(in: qtyItemRect, withAttributes: [
          .font: smallFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
          }()
        ])
        
        let priceRect = CGRect(x: col4 - 20, y: yPosition, width: 40, height: 12)
        String(format: "%.2f", price).draw(in: priceRect, withAttributes: [
          .font: smallFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            return style
          }()
        ])
        
        let totalRect = CGRect(x: col5 - 25, y: yPosition, width: 35, height: 12)
        String(format: "%.2f", total).draw(in: totalRect, withAttributes: [
          .font: smallFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            return style
          }()
        ])
        yPosition += 14
      }
      
      // Draw separator line
      context.move(to: CGPoint(x: margin, y: yPosition))
      context.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
      context.strokePath()
      yPosition += 12
      
      // Total with proper alignment
      let totalText = language == "ta" ? "மொத்தம்:" : "Total:"
      let totalLabelRect = CGRect(x: col4 - 20, y: yPosition, width: 40, height: 15)
      totalText.draw(in: totalLabelRect, withAttributes: [
        .font: headerFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .right
          return style
        }()
      ])
      
      let totalAmountRect = CGRect(x: col5 - 25, y: yPosition, width: 35, height: 15)
      String(format: "%.2f", totalAmount).draw(in: totalAmountRect, withAttributes: [
        .font: headerFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .right
          return style
        }()
      ])
      yPosition += 25
      
      // Footer messages
      let thankYouText = language == "ta" ? "நன்றி" : "Thank You"
      let visitAgainText = language == "ta" ? "மீண்டும் வாருங்கள்" : "Visit Again"
      
      let thankYouRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 15)
      thankYouText.draw(in: thankYouRect, withAttributes: [
        .font: normalFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 15
      
      let visitAgainRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 15)
      visitAgainText.draw(in: visitAgainRect, withAttributes: [
        .font: normalFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 20
      
      // Tamil footer texts
      if language == "ta" {
        // Draw separator line
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
        context.strokePath()
        yPosition += 15
        
        let footerFont = UIFont.systemFont(ofSize: 9)
        
        let footer1Rect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 14)
        footerText1.draw(in: footer1Rect, withAttributes: [
          .font: footerFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
          }()
        ])
        yPosition += 14
        
        let footer2Rect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 14)
        footerText2.draw(in: footer2Rect, withAttributes: [
          .font: footerFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
          }()
        ])
        yPosition += 14
        
        let footer3Rect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 14)
        footerText3.draw(in: footer3Rect, withAttributes: [
          .font: footerFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
          }()
        ])
      }
    }
    
    return data
  }
}
