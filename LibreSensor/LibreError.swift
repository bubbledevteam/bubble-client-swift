//
//  LibreError.swift
//  BubbleClient
//
//  Created by Bjørn Inge Berg on 05/03/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation

public enum LibreError: Error {
    case noSensorData
    case noCalibrationData
    case invalidCalibrationData
    case checksumValidationError
    case expiredSensor
    case invalidAutoCalibrationCredentials
    case encryptedSensor
    
    public var errorDescription: String{
        switch self {
        case .noSensorData:
            return "No sensor data present"
        
        case .noCalibrationData:
            return "No calibration data present"
        case .invalidCalibrationData:
            return "invalid calibration data detected"
        case .checksumValidationError:
            return "Checksum Validation Error "
        case .expiredSensor:
            return "Sensor has expired"
        case .invalidAutoCalibrationCredentials:
            return "Invalid Auto Calibration Credentials"
        case .encryptedSensor:
            return "Encrypted and unsupported libre sensor detected."
        
        }
    }
}
