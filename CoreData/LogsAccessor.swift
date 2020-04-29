//
//  LogsAccessor.swift
//  BubbleClient
//
//  Created by Yan Hu on 2020/4/15.
//  Copyright © 2020 Mark Wilson. All rights reserved.
//

import UIKit
import os
import CoreData

class LogsAccessor: NSObject {
    // MARK: - Properties
    /// CoreDataManager to use
    private let coreDataManager: CoreDataManager
    
    // MARK: - initializer
    init(coreDataManager:CoreDataManager) {
        self.coreDataManager = coreDataManager
        super.init()
    }
    
    func todayLogs() -> [LocalLog] {
        let calendar = Calendar(identifier: Calendar.current.identifier)
        let date = calendar.date(byAdding: .day, value: -1, to: Date())!
        return fetchLogs(fromDate: date)
    }
    
    private func fetchLogs(fromDate: Date, toDate: Date? = nil) -> [LocalLog] {
        let fetchRequest: NSFetchRequest<LocalLog> = LocalLog.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(LocalLog.date), ascending: false)]
        
        var predicate = NSPredicate(format: "date >= %@", NSDate(timeIntervalSince1970: fromDate.timeIntervalSince1970))
        if let toDate = toDate {
            predicate = NSPredicate(format: "date >= %@ && date <= %@", NSDate(timeIntervalSince1970: fromDate.timeIntervalSince1970), NSDate(timeIntervalSince1970: toDate.timeIntervalSince1970))
        }
        fetchRequest.predicate = predicate
        
        var logs = [LocalLog]()
        coreDataManager.mainManagedObjectContext.performAndWait {
            do {
                logs = try fetchRequest.execute()
            } catch { }
        }
        return logs
    }
    
    private static let osLog = OSLog(subsystem: "BubbleClient", category: "Logger")
    
    // MARK: save
    static private func textLog(object: String?) {
        guard let coreDataManager = coreDataManager else { return }
        var text = ""
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd hh:mm:ss"
        let dateString = format.string(from: Date())
        if let object = object {
            text += "\n\n\(dateString)\n\(object)"
        }
        
        let _ = LocalLog.init(date: Date(), text: text, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        coreDataManager.saveChanges()
    }
    
    static func todayLogs() -> String {
        var text = "Code Error: \(UserDefaultsUnit.coreDataError!)"
        guard let logsAccessor = logsAccessor else { return "" }
        let logs = logsAccessor.todayLogs()
        for log in logs {
            text += "\(log.text ?? "")\n"
        }
        return text
    }
    
    static private var coreDataManager: CoreDataManager? = {
        return CoreDataManager(modelName: "BubbleClientModel")
    }()
    
    static  private var logsAccessor: LogsAccessor? = {
        guard let coreDataManager = coreDataManager else { return nil }
        return LogsAccessor.init(coreDataManager: coreDataManager)
    }()
    
    static func log(_ object: String?, _ shouldPrint: Bool = true) {
        DispatchQueue.main.async {
            guard let object = object else { return }
            if shouldPrint {
                os_log("Bubble:: %s", log: osLog, type: .debug, object)
            }
            textLog(object: object)
        }
    }
    
    static func error(_ object: String?, _ shouldPrint: Bool = true) {
        DispatchQueue.main.async {
            guard let object = object else { return }
            if shouldPrint {
                os_log("Bubble:: %s", log: osLog, type: .debug, object)
            }
            let format = DateFormatter()
            format.dateFormat = "yyyy-MM-dd hh:mm:ss"
            let dateString = format.string(from: Date())
            UserDefaultsUnit.coreDataError += "\n\n\(dateString)\n\(object)"
        }
    }
}
