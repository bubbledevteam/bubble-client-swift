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
    
    @UserDefaultWrapper("patchInfo", "")
    public static var patchInfo: String!
    
    @UserDefaultWrapper("patchUid", "")
    public static var patchUid: String!
    
    @UserDefaultWrapper("patchUid", "")
    public static var sensorSerialNumber: String!
    
    @UserDefaultWrapper("unlockCount", 1)
    static var unlockCount: UInt16!
    
    /// libre2 344 original data
    @UserDefaultWrapper("libre2Nfc344OriginalData")
    static var libre2Nfc344OriginalData: String?
    
    /// libre2 decryptFRAM 344 Libre2.calibrationInfo
    @UserDefaultJsonWrapper("calibrationInfo")
    static var calibrationInfo: CalibrationInfo?
}

