//
//  UserDefaults.swift
//  BubbleClient
//
//  Created by Yan Hu on 2020/4/10.
//  Copyright © 2020 Mark Wilson. All rights reserved.
//

import Foundation
import HealthKit

@propertyWrapper
public struct UserDefaultWrapper<T> {
    var key: String
    var defaultT: T!
    public var wrappedValue: T! {
        get { (UserDefaults.standard.object(forKey: key) as? T) ?? defaultT }
        nonmutating set {
            if newValue == nil {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(newValue, forKey: key)
            }
        }
    }
    
    init(_ key: String, _ defaultT: T! = nil) {
        self.key = key
        self.defaultT = defaultT
    }
}

@propertyWrapper
public struct UserDefaultJsonWrapper<T: Codable> {
    var key: String
    var defaultT: T!
    public var wrappedValue: T! {
        get {
            guard let jsonString = UserDefaults.standard.string(forKey: key) else { return defaultT }
            guard let jsonData = jsonString.data(using: .utf8) else { return defaultT }
            guard let value = try? JSONDecoder().decode(T.self, from: jsonData) else { return defaultT }
            return value
        }
        set {
            let encoder = JSONEncoder()
            guard let jsonData = try? encoder.encode(newValue) else { return }
            let jsonString = String(bytes: jsonData, encoding: .utf8)
            UserDefaults.standard.set(jsonString, forKey: key)
        }
    }
    
    init(_ key: String, _ defaultT: T! = nil) {
        self.key = key
        self.defaultT = defaultT
    }
}

public struct UserDefaultsUnit {
    @UserDefaultJsonWrapper("latestGlucose")
    public static var latestGlucose: GlucoseData?
    
    @UserDefaultJsonWrapper("glucoses", [])
    public static var glucoses: [GlucoseData]!
    
    @UserDefaultWrapper("coreDataError", "")
    public static var coreDataError: String!
}
