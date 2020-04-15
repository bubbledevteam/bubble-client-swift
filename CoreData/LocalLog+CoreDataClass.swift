//
//  LocalLog+CoreDataClass.swift
//  BubbleClient
//
//  Created by Yan Hu on 2020/4/15.
//  Copyright © 2020 Mark Wilson. All rights reserved.
//
//

import Foundation
import CoreData

@objc(LocalLog)
public class LocalLog: NSManagedObject {
    init(date: Date, text: String, nsManagedObjectContext: NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entity(forEntityName: "LocalLog", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.date = date
        self.text = text
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
