import Foundation
import os.log

enum Logger {
    private static let subsystem = "com.kiroku.app"
    
    enum Category: String {
        case recording = "Recording"
        case buffer = "Buffer"
        case export = "Export"
        case fileSystem = "FileSystem"
        case ui = "UI"
        case permissions = "Permissions"
        case process = "Process"
        case video = "Video"
    }
    
    static func log(_ message: String, category: Category, type: OSLogType = .default) {
        let logger = os.Logger(subsystem: subsystem, category: category.rawValue)
        
        switch type {
        case .default:
            logger.log("\(message)")
        case .info:
            logger.info("\(message)")
        case .debug:
            logger.debug("\(message)")
        case .error:
            logger.error("\(message)")
        case .fault:
            logger.fault("\(message)")
        default:
            logger.log("\(message)")
        }
    }
    
    static func debug(_ message: String, category: Category) {
        log(message, category: category, type: .debug)
    }
    
    static func info(_ message: String, category: Category) {
        log(message, category: category, type: .info)
    }
    
    static func error(_ message: String, category: Category) {
        log(message, category: category, type: .error)
    }
    
    static func fault(_ message: String, category: Category) {
        log(message, category: category, type: .fault)
    }
}