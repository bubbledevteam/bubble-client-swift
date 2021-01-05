//
//  Calibration.swift
//  BubbleClient
//
//  Created by Bjørn Inge Berg on 05/03/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation
import LoopKit

private let LibreCalibrationLabel =  "https://LibreCalibrationLabel.doesnot.exist.com"
private let LibreCalibrationUrl = URL(string: LibreCalibrationLabel)!
private let LibreUsername = "LibreUsername"


extension KeychainManager {
    public func setLibreCalibrationData(_ calibrationData: LibreDerivedAlgorithmParameters) throws {
        let credentials: InternetCredentials?
        credentials = InternetCredentials(username: LibreUsername, password: serializeAlgorithmParameters(calibrationData), url: LibreCalibrationUrl)
        NSLog("dabear: Setting calibrationdata to \(String(describing: calibrationData))")
        try replaceInternetCredentials(credentials, forLabel: LibreCalibrationLabel)
    }
    
    public func getLibreCalibrationData() -> LibreDerivedAlgorithmParameters? {
        do { // Silence all errors and return nil
            let credentials = try getInternetCredentials(label: LibreCalibrationLabel)
            NSLog("dabear:: credentials.password was retrieved: \(credentials.password)")
            return deserializeAlgorithmParameters(text: credentials.password)
        } catch {
            NSLog("dabear:: unable to retrieve calibrationdata:")
            return nil
        }
    }
}

public let keychain = KeychainManager()

private func serializeAlgorithmParameters(_ params: LibreDerivedAlgorithmParameters) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    
    var aString = ""
    do {
        let jsonData = try encoder.encode(params)
        
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            aString = jsonString
        }
    } catch {
        print("Could not serialize parameters: \(error.localizedDescription)")
    }
    return aString
}

private func deserializeAlgorithmParameters(text: String) -> LibreDerivedAlgorithmParameters? {
    
    if let jsonData = text.data(using: .utf8) {
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(LibreDerivedAlgorithmParameters.self, from: jsonData)
            
        } catch {
            print("Could not create instance: \(error.localizedDescription)")
        }
    } else {
        print("Did not create instance")
    }
    return nil
}

extension Collection where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
    var hex: String {
        return map{ String(format: "%02X", $0) }.joined()
    }
}
