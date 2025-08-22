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
    
    let pageRect = CGRect(x: 0, y: 0, width: 226, height: 800) // 80mm width
    let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
    
    let data = renderer.pdfData { (context) in
      context.beginPage()
      
      var yPosition: CGFloat = 30
      let margin: CGFloat = 10
      let pageWidth: CGFloat = 226
      
      // Fonts
      let titleFont = UIFont.boldSystemFont(ofSize: 14)
      let headerFont = UIFont.boldSystemFont(ofSize: 12)
      let normalFont = UIFont.systemFont(ofSize: 10)
      let smallFont = UIFont.systemFont(ofSize: 8)
      
      // Header
      if language == "ta" {
        let headerRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 20)
        headerText.draw(in: headerRect, withAttributes: [
          .font: normalFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
          }()
        ])
        yPosition += 20
      }
      
      // Title
      let titleText = language == "ta" ? "மதிப்பீட்டு ரசீது" : "Receipt"
      let titleRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 20)
      titleText.draw(in: titleRect, withAttributes: [
        .font: titleFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 20
      
      // Shop name
      let shopRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 15)
      shopName.draw(in: shopRect, withAttributes: [
        .font: headerFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 15
      
      // Address
      let addressRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 12)
      address.draw(in: addressRect, withAttributes: [
        .font: normalFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 12
      
      // City
      let cityRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 12)
      city.draw(in: cityRect, withAttributes: [
        .font: normalFont,
        .foregroundColor: UIColor.black,
        .paragraphStyle: {
          let style = NSMutableParagraphStyle()
          style.alignment = .center
          return style
        }()
      ])
      yPosition += 12
      
      // Phone
      let phoneRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 12)
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
        .font: normalFont,
        .foregroundColor: UIColor.black
      ])
      
      let dateRect = CGRect(x: pageWidth - margin - 80, y: yPosition, width: 80, height: 12)
      dateString.draw(in: dateRect, withAttributes: [
        .font: normalFont,
        .foregroundColor: UIColor.black
      ])
      yPosition += 20
      
      // Draw line
      let context = UIGraphicsGetCurrentContext()!
      context.setStrokeColor(UIColor.black.cgColor)
      context.setLineWidth(1.0)
      context.move(to: CGPoint(x: margin, y: yPosition))
      context.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
      context.strokePath()
      yPosition += 15
      
      // Table header
      let detailsText = language == "ta" ? "விபரங்கள்" : "Details"
      let qtyText = language == "ta" ? "அளவு" : "Qty"
      let rateText = language == "ta" ? "விலை" : "Rate"
      let amountText = language == "ta" ? "தொகை" : "Amount"
      
      detailsText.draw(at: CGPoint(x: margin + 15, y: yPosition), withAttributes: [.font: normalFont, .foregroundColor: UIColor.black])
      qtyText.draw(at: CGPoint(x: margin + 105, y: yPosition), withAttributes: [.font: normalFont, .foregroundColor: UIColor.black])
      rateText.draw(at: CGPoint(x: margin + 140, y: yPosition), withAttributes: [.font: normalFont, .foregroundColor: UIColor.black])
      amountText.draw(at: CGPoint(x: margin + 180, y: yPosition), withAttributes: [.font: normalFont, .foregroundColor: UIColor.black])
      yPosition += 15
      
      // Draw line
      context.move(to: CGPoint(x: margin, y: yPosition))
      context.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
      context.strokePath()
      yPosition += 10
      
      // Items
      for (index, item) in items.enumerated() {
        let itemName = item["productName"] as? String ?? ""
        let quantity = item["quantity"] as? Double ?? 0
        let price = item["price"] as? Double ?? 0
        let total = item["total"] as? Double ?? 0
        let unit = item["unit"] as? String ?? ""
        
        "\(index + 1)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: [.font: smallFont, .foregroundColor: UIColor.black])
        itemName.draw(at: CGPoint(x: margin + 15, y: yPosition), withAttributes: [.font: smallFont, .foregroundColor: UIColor.black])
        "\(quantity)\(unit)".draw(at: CGPoint(x: margin + 105, y: yPosition), withAttributes: [.font: smallFont, .foregroundColor: UIColor.black])
        String(format: "%.2f", price).draw(at: CGPoint(x: margin + 140, y: yPosition), withAttributes: [.font: smallFont, .foregroundColor: UIColor.black])
        String(format: "%.2f", total).draw(at: CGPoint(x: margin + 180, y: yPosition), withAttributes: [.font: smallFont, .foregroundColor: UIColor.black])
        yPosition += 12
      }
      
      // Draw line
      context.move(to: CGPoint(x: margin, y: yPosition))
      context.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
      context.strokePath()
      yPosition += 15
      
      // Total
      let totalText = language == "ta" ? "மொத்தம்:" : "Total:"
      totalText.draw(at: CGPoint(x: margin + 140, y: yPosition), withAttributes: [.font: headerFont, .foregroundColor: UIColor.black])
      String(format: "%.2f", totalAmount).draw(at: CGPoint(x: margin + 180, y: yPosition), withAttributes: [.font: headerFont, .foregroundColor: UIColor.black])
      yPosition += 25
      
      // Footer
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
      
      if language == "ta" {
        // Draw line
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
        context.strokePath()
        yPosition += 15
        
        let footer1Rect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 12)
        footerText1.draw(in: footer1Rect, withAttributes: [
          .font: smallFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
          }()
        ])
        yPosition += 12
        
        let footer2Rect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 12)
        footerText2.draw(in: footer2Rect, withAttributes: [
          .font: smallFont,
          .foregroundColor: UIColor.black,
          .paragraphStyle: {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            return style
          }()
        ])
        yPosition += 12
        
        let footer3Rect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 12)
        footerText3.draw(in: footer3Rect, withAttributes: [
          .font: smallFont,
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
