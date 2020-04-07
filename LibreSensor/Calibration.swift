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

func post(bytes: [UInt8],_ completion:@escaping (( _ data_: Data, _ response: String, _ success: Bool ) -> Void)) {
    let date = Int(Date().timeIntervalSince1970 * 1000)
    let json: [String: String] = [
        "token": "bubble-201907",
        "content": "\(bytes.hex)",
        "timestamp": "\(date)"]
    if let uploadURL = URL.init(string: "http://www.glucose.space/calibrateSensor") {
        let request = NSMutableURLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        request.setBodyContent(contentMap: json)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, _ in
            
            guard let data = data else {
                completion("network error".data(using: .utf8)!, "network error", false)
                return
            }
            
            if let response = String(data: data, encoding: String.Encoding.utf8) {
                completion(data, response, true)
            }
            
        }
        task.resume()
    }
}

public let keychain = KeychainManager()
public func calibrateSensor(sensordata: SensorData,  callback: @escaping (LibreDerivedAlgorithmParameters?) -> Void) {
    if let response = keychain.getLibreCalibrationData(), response.serialNumber == sensordata.serialNumber {
        callback(response)
        return
    }
    
    post(bytes: sensordata.bytes, { (data, str, can) in
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(GetCalibrationStatus.self, from: data)
            print(response)
            if let slope = response.slope {
                var para = LibreDerivedAlgorithmParameters.init(slope_slope: slope.slopeSlope ?? 0, slope_offset: slope.slopeOffset ?? 0, offset_slope: slope.offsetSlope ?? 0, offset_offset: slope.offsetOffset ?? 0, isValidForFooterWithReverseCRCs: Int(slope.isValidForFooterWithReverseCRCs ?? 1), extraSlope: 1.0, extraOffset: 0.0)
                para.serialNumber = sensordata.serialNumber
                do {
                    try keychain.setLibreCalibrationData(para)
                } catch {
                    NSLog("dabear:: could not save calibrationdata")
                }
                callback(para)
            } else {
                callback(nil)
            }
        } catch {
            print("got error trying to decode GetCalibrationStatus")
            callback(nil)
        }
    })
}

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
