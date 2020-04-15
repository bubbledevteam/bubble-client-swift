//
//  LocalLog+CoreDataProperties.swift
//  BubbleClient
//
//  Created by Yan Hu on 2020/4/15.
//  Copyright © 2020 Mark Wilson. All rights reserved.
//
//

import Foundation
import CoreData


extension LocalLog {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocalLog> {
        return NSFetchRequest<LocalLog>(entityName: "LocalLog")
    }

    @NSManaged public var date: Date?
    @NSManaged public var text: String?

}
