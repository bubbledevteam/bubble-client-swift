//
//  CoreDataManager.swift
//  BubbleClient
//
//  Created by Yan Hu on 2020/4/15.
//  Copyright © 2020 Mark Wilson. All rights reserved.
//

import CoreData
import UIKit
import os

/// development as explained in cocoacasts.com https://cocoacasts.com/bring-your-own
final class CoreDataManager: NSObject {
    // MARK: - Properties
    private let modelName: String
    
    private var log = OSLog(subsystem: "BubbleClient", category: "categoryCoreDataManager")
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillTerminate
    private let applicationManagerKeySaveChanges = "coredatamanagersavechanges"
    
    // MARK: -
    
    private(set) lazy var mainManagedObjectContext: NSManagedObjectContext = {
        // Initialize Managed Object Context
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        // Configure Managed Object Context
        managedObjectContext.parent = self.privateManagedObjectContext
        
        return managedObjectContext
    }()
    
    private lazy var privateManagedObjectContext: NSManagedObjectContext = {
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        
        managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        
        return managedObjectContext
    }()
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        // Fetch Model URL
        guard let modelURL = FrameworkBundle.main.url(forResource: self.modelName, withExtension: "momd") else {
            fatalError("Unable to Find Data Model")
        }
        
        // Initialize Managed Object Model
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to Load Data Model")
        }
        
        return managedObjectModel
    }()
    
    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        return NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
    }()
    
    static func addLog(log: String?) {
        LogsAccessor.log(log)
    }
    
    private func addPersistentStore(to persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        // Helpers
        let fileManager = FileManager.default
        let storeName = "\(self.modelName).sqlite"
        
        let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        // URL Persistent Store
        let persistentStoreURL = url.appendingPathComponent(storeName)
        
        do {
            let options = [
                NSMigratePersistentStoresAutomaticallyOption : true,
                NSInferMappingModelAutomaticallyOption : true
            ]
            
            // Add Persistent Store
            try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                              configurationName: nil,
                                                              at: persistentStoreURL,
                                                              options: options)
            
        } catch {
            fatalError("Unable to Add Persistent Store")
        }
    }
    
    // MARK: - Initialization
    
    init(modelName: String) {
        // Set Properties
        self.modelName = modelName
        super.init()
        // Setup Core Data Stack
        setupCoreDataStack()
    }
    
    // MARK: - Helper Methods
    
    private func setupCoreDataStack() {
        // Fetch Persistent Store Coordinator
        guard let persistentStoreCoordinator = mainManagedObjectContext.persistentStoreCoordinator else {
            fatalError("Unable to Set Up Core Data Stack")
        }
        
        //        DispatchQueue.global().async {
        // Add Persistent Store
        addPersistentStore(to: persistentStoreCoordinator)
        
        NotificationCenter.default.addObserver(self, selector: #selector(runWhenAppWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func runWhenAppWillEnterForeground(_ : Notification) {
        saveChangesAtTermination()
    }
    
    // MARK: -
    
    public func saveChanges() {
        
        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                LogsAccessor.log("in saveChangesAtTermination,  Unable to Save Changes of Main Managed Object Context, \(error.localizedDescription)")
            }
        }
        
        privateManagedObjectContext.perform {
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }
            } catch {
                LogsAccessor.log("in saveChangesAtTermination,  Unable to Save Changes of Private Managed Object Context, \(error.localizedDescription)")
            }
        }
    }
    
    /// to be used when app terminates, difference with savechanges is that it calls privateManagedObjectContext.save synchronously
    private func saveChangesAtTermination() {
        
        mainManagedObjectContext.performAndWait {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                LogsAccessor.log("in saveChangesAtTermination,  Unable to Save Changes of Main Managed Object Context, \(error.localizedDescription)")
            }
        }
        
        privateManagedObjectContext.performAndWait {
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }
            } catch {
                LogsAccessor.log("in saveChangesAtTermination,  Unable to Save Changes of Private Managed Object Context, \(error.localizedDescription)")
            }
        }
    }
    
}
