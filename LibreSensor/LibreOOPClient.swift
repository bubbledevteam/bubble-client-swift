////
////  RemoteBG.swift
////  SwitftOOPWeb
////
////  Created by Bjørn Inge Berg on 08.04.2018.
////  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
////
//
//
//  LibreOOPClient.swift
//  SwitftOOPWeb
//
//  Created by Bjørn Inge Berg on 08.04.2018.
//  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
//
import Foundation
import os
import SpriteKit
import UserNotifications
import LoopKit

let baseUrl = "http://www.glucose.space"
let token = "bubble-201907"

class LibreOOPClient {
    // MARK: - public functions
    static func webOOP(uploadURL: URL, callback: ((LibreRawGlucoseOOPData?) -> ())?) {
        let request = NSMutableURLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, error in
            DispatchQueue.main.async {
                guard let data = data else {
                    callback?(nil)
                    return
                }
                
                let decoder = JSONDecoder.init()
                if let oopValue = try? decoder.decode(LibreRawGlucoseOOPData.self, from: data) {
                    callback?(oopValue)
                    return
                }
                callback?(nil)
            }
        }
        task.resume()
    }
    
    public static func handleLibreData(sensorData: SensorData, callback: @escaping ((glucoseData: [GlucoseData], sensorState: LibreSensorState?, sensorTimeInMinutes: Int?)?) -> Void) {
        //only care about the once per minute readings here, historical data will not be considered
        let sensorState = sensorData.state
        
        // web oop for newwork bad and version < 1.22
        func oop() {
            LibreOOPClient.calibrateSensor(sensorData: sensorData, serialNumber: sensorData.serialNumber) {
                (calibrationparams)  in
                var params = LibreDerivedAlgorithmParameters.init(slope_slope: 0.13,
                                                                  slope_offset: 0,
                                                                  offset_slope: 0,
                                                                  offset_offset: -20,
                                                                  isValidForFooterWithReverseCRCs: 1,
                                                                  extraSlope: 1.0,
                                                                  extraOffset: 0.0)
                if let p = calibrationparams {
                    params = p
                    guard !p.isErrorParameters else {
                        callback(([], sensorState, nil))
                        return
                    }
                }
                
                let last16 = trendMeasurements(bytes: sensorData.bytes, date: Date(), LibreDerivedAlgorithmParameterSet: params)
                if var glucoseData = trendToLibreGlucose(last16), let first = glucoseData.first {
                    let last32 = historyMeasurements(bytes: sensorData.bytes, date: first.timeStamp, LibreDerivedAlgorithmParameterSet: params)
                    let glucose32 = trendToLibreGlucose(last32) ?? []
                    let last96 = split(current: first, glucoseData: glucose32.reversed())
                    glucoseData = last96
                    callback((glucoseData, sensorState, nil))
                } else {
                    callback(([], sensorState, nil))
                }
            }
        }
        
        let patchUid = sensorData.patchUid
        guard let patchInfo = sensorData.patchInfo else {
            oop()
            return
        }
        
        let bytesAsData = Data(bytes: sensorData.bytes, count: sensorData.bytes.count)
        let item = URLQueryItem(name: "accesstoken", value: token)
        let item1 = URLQueryItem(name: "patchUid", value: patchUid)
        let item2 = URLQueryItem(name: "patchInfo", value: patchInfo)
        let item3 = URLQueryItem(name: "content", value: bytesAsData.hexEncodedString())
        var urlComponents = URLComponents(string: "\(baseUrl)/libreoop2")!
        urlComponents.queryItems = [item, item1, item2, item3]
        var retryCount = 1
        if let uploadURL = URL.init(string: urlComponents.url?.absoluteString.removingPercentEncoding ?? "") {
            func retry() {
                retryCount += 1
                webOOP(uploadURL: uploadURL) { oopValue in
                    if let oopValue = oopValue, !oopValue.isError {
                        if oopValue.valueError {
                            if sensorData.isSecondSensor && oopValue.sensorState.sensorState == .notYetStarted {
                                callback(([], .notYetStarted, nil))
                            } else {
                                callback(([], .failure, nil))
                            }
                            return
                        } else {
                            if let time = oopValue.sensorTime {
                                var last96 = [LibreRawGlucoseData]()
                                if !(oopValue.historicGlucose?.isEmpty ?? true) {
                                    let value = oopValue.glucoseData(date: Date())
                                    last96 = split(current: value.0, glucoseData: value.1)
                                }
                                
                                if time < 20880 {
                                    callback((last96, oopValue.sensorState.sensorState, time))
                                } else {
                                    callback(([], .expired, time))
                                }
                            } else {
                                callback(([], oopValue.sensorState.sensorState, nil))
                            }
                        }
                    } else {
                        if retryCount < 4 {
                            retry()
                        } else {
                            if sensorData.isFirstSensor {
                                oop()
                            } else {
                                callback(([], nil, nil))
                            }
                        }
                    }
                }
            }
            retry()
        }
    }
    
    private static func split(current: LibreRawGlucoseData?, glucoseData: [LibreRawGlucoseData]) -> [LibreRawGlucoseData] {
        var x = [Double]()
        var y = [Double]()
        
        if let current = current {
            let timeInterval = current.timeStamp.timeIntervalSince1970 * 1000
            x.append(timeInterval)
            y.append(current.glucoseLevelRaw)
        }
        
        for glucose in glucoseData.reversed() {
            let time = glucose.timeStamp.timeIntervalSince1970 * 1000
            x.insert(time, at: 0)
            y.insert(glucose.glucoseLevelRaw, at: 0)
        }
        
        let startTime = x.first ?? 0
        let endTime = x.last ?? 0
        
        let frameS = SKKeyframeSequence.init(keyframeValues: y, times: x as [NSNumber])
        frameS.interpolationMode = .spline
        var items = [LibreRawGlucoseData]()
        var ptime = endTime
        while ptime >= startTime {
            let value = (frameS.sample(atTime: CGFloat(ptime)) as? Double) ?? 0
            let item = LibreRawGlucoseData.init(timeStamp: Date.init(timeIntervalSince1970: ptime / 1000), glucoseLevelRaw: value, unsmoothedGlucose: value)
            items.append(item)
            ptime -= 300000
        }
        
        for i in 0 ..< items.count {
            let trend = items[i]
            //we know that the array "always" (almost) will contain 16 entries
            //the last five entries will get a trend arrow of flat, because it's not computable when we don't have
            //more entries in the array to base it on
            let arrow = GetGlucoseDirection(current: trend, last: items[safe: i+1])
            items[i].trend = UInt8(arrow.rawValue)
            NSLog("Date: \(trend.timeStamp), before: \(trend.unsmoothedGlucose), after: \(trend.glucoseLevelRaw), arrow: \(trend.trend)")
        }
        
        return items
    }
    
    private static func calibrateSensor(sensorData: SensorData, serialNumber: String,  callback: @escaping (LibreDerivedAlgorithmParameters?) -> Void) {
        if let response = keychain.getLibreCalibrationData(), response.serialNumber == sensorData.serialNumber {
            callback(response)
            return
        }
        
        post(bytes: sensorData.bytes, { (data, str, can) in
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(GetCalibrationStatus.self, from: data)
                if let slope = response.slope {
                    var p = LibreDerivedAlgorithmParameters.init(slope_slope: slope.slopeSlope ?? 0, slope_offset: slope.slopeOffset ?? 0, offset_slope: slope.offsetSlope ?? 0, offset_offset: slope.offsetOffset ?? 0, isValidForFooterWithReverseCRCs: Int(slope.isValidForFooterWithReverseCRCs ?? 1), extraSlope: 1.0, extraOffset: 0.0)
                    p.serialNumber = serialNumber
                    if p.slope_slope != 0 ||
                        p.slope_offset != 0 ||
                        p.offset_slope != 0 ||
                        p.offset_offset != 0 {
                        
                        try? keychain.setLibreCalibrationData(p)
                        callback(p)
                    } else {
                        callback(nil)
                    }
                } else {
                    callback(nil)
                }
            } catch {
                callback(nil)
            }
        })
    }
    
    // MARK: - private functions
    
    private static func post(bytes: [UInt8],_ completion:@escaping (( _ data_: Data, _ response: String, _ success: Bool ) -> Void)) {
        let date = Date().toMillisecondsAsInt64()
        let bytesAsData = Data(bytes: bytes, count: bytes.count)
        let json: [String: String] = [
            "token": token,
            "content": "\(bytesAsData.hexEncodedString())",
            "timestamp": "\(date)",
            "appName": "diabox"
        ]
        
        if let uploadURL = URL.init(string: "\(baseUrl)/calibrateSensor") {
            let request = NSMutableURLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.setBodyContent(contentMap: json)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) {
                data, response, error in
                
                guard let data = data else {
                    DispatchQueue.main.sync {
                        completion("network error".data(using: .utf8)!, "network error", false)
                    }
                    return
                    
                }
                
                if let response = String(data: data, encoding: String.Encoding.utf8) {
                    DispatchQueue.main.sync {
                        completion(data, response, true)
                    }
                    return
                }
                
                DispatchQueue.main.sync {
                    completion("response error".data(using: .utf8)!, "response error", false)
                }
                
            }
            task.resume()
        }
    }
    
    private static func trendMeasurements(bytes: [UInt8], date: Date, _ offset: Double = 0.0, slope: Double = 0.1, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameters?) -> [LibreMeasurement] {
        guard bytes.count >= 320 else { return [] }
        //    let headerRange =   0..<24   //  24 bytes, i.e.  3 blocks a 8 bytes
        let bodyRange   =  24 ..< 320  // 296 bytes, i.e. 37 blocks a 8 bytes
        //    let footerRange = 320..<344  //  24 bytes, i.e.  3 blocks a 8 bytes
        
        let body   = Array(bytes[bodyRange])
        let nextTrendBlock = Int(body[2])
        
        var measurements = [LibreMeasurement]()
        // Trend data is stored in body from byte 4 to byte 4+96=100 in units of 6 bytes. Index on data such that most recent block is first.
        for blockIndex in 0 ... 15 {
            var index = 4 + (nextTrendBlock - 1 - blockIndex) * 6 // runs backwards
            if index < 4 {
                index = index + 96 // if end of ring buffer is reached shift to beginning of ring buffer
            }
            guard index + 6 < body.count else { return [] }
            let range = index ..< index + 6
            let measurementBytes = Array(body[range])
            let measurementDate = date.addingTimeInterval(Double(-60 * blockIndex))
            
            let measurement = LibreMeasurement(bytes: measurementBytes, slope: slope, offset: offset, date: measurementDate, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameterSet)
            measurements.append(measurement)
        }
        return measurements
    }
    
    private static func historyMeasurements(bytes: [UInt8], date: Date, _ offset: Double = 0.0, slope: Double = 0.1, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameters?) -> [LibreMeasurement] {
        guard bytes.count >= 320 else { return [] }
        let bodyRange   =  24..<320  // 296 bytes, i.e. 37 blocks a 8 bytes
        let body   = Array(bytes[bodyRange])
        let nextHistoryBlock = Int(body[3])
        let minutesSinceStart = Int(body[293]) << 8 + Int(body[292])
        var measurements = [LibreMeasurement]()
        // History data is stored in body from byte 100 to byte 100+192-1=291 in units of 6 bytes. Index on data such that most recent block is first.
        for blockIndex in 0..<32 {
            
            var index = 100 + (nextHistoryBlock - 1 - blockIndex) * 6 // runs backwards
            if index < 100 {
                index = index + 192 // if end of ring buffer is reached shift to beginning of ring buffer
            }
            
            let range = index..<index+6
            let measurementBytes = Array(body[range])
            let (date, counter) = dateOfMostRecentHistoryValue(minutesSinceStart: minutesSinceStart, nextHistoryBlock: nextHistoryBlock, date: date)
            let final = date.addingTimeInterval(Double(-900 * blockIndex))
            let measurement = LibreMeasurement(bytes: measurementBytes, slope: slope, offset: offset, counter: counter - blockIndex * 15, date: final, LibreDerivedAlgorithmParameterSet: LibreDerivedAlgorithmParameterSet)
            measurements.append(measurement)
        }
        return measurements
    }
    
    private static func dateOfMostRecentHistoryValue(minutesSinceStart: Int, nextHistoryBlock: Int, date: Date) -> (date: Date, counter: Int) {
        let nextHistoryIndexCalculatedFromMinutesCounter = ( (minutesSinceStart - 3) / 15 ) % 32
        let delay = (minutesSinceStart - 3) % 15 + 3 // in minutes
        if nextHistoryIndexCalculatedFromMinutesCounter == nextHistoryBlock {
            return (date: date.addingTimeInterval( 60.0 * -Double(delay) ), counter: minutesSinceStart - delay)
        } else {
            return (date: date.addingTimeInterval( 60.0 * -Double(delay - 15)), counter: minutesSinceStart - delay)
        }
    }
    
    
    private static func trendToLibreGlucose(_ measurements: [LibreMeasurement]) -> [LibreRawGlucoseData]?{
        
        var origarr = [LibreRawGlucoseData]()
        for trend in measurements {
            let glucose = LibreRawGlucoseData(timeStamp: trend.date,
                                              glucoseLevelRaw: trend.temperatureAlgorithmGlucose,
                                              unsmoothedGlucose: trend.temperatureAlgorithmGlucose)
            origarr.append(glucose)
        }
        
        var arr : [LibreRawGlucoseData]
        arr = LibreGlucoseSmoothing.CalculateSmothedData5Points(origtrends: origarr)
        for i in 0 ..< arr.count {
            let trend = arr[i]
            //we know that the array "always" (almost) will contain 16 entries
            //the last five entries will get a trend arrow of flat, because it's not computable when we don't have
            //more entries in the array to base it on
            let arrow = GetGlucoseDirection(current: trend, last: arr[safe: i+5])
            arr[i].trend = UInt8(arrow.rawValue)
            NSLog("Date: \(trend.timeStamp), before: \(trend.unsmoothedGlucose), after: \(trend.glucoseLevelRaw), arrow: \(trend.trend)")
        }
        return arr
    }
    
    static func calculateSlope(current: LibreRawGlucoseData, last: LibreRawGlucoseData) -> Double
    {
        if current.timeStamp == last.timeStamp {
            return 0.0
        }
        
        let _curr = Double(current.timeStamp.timeIntervalSince1970 * 1000)
        let _last = Double(last.timeStamp.timeIntervalSince1970 * 1000)
        
        
        
        return (Double(last.unsmoothedGlucose) - Double(current.unsmoothedGlucose)) / (_last - _curr)
    }
    
    static func calculateSlopeByMinute(current: LibreRawGlucoseData, last: LibreRawGlucoseData) -> Double
    {
        return calculateSlope(current: current, last: last) * 60000;
    }
    
    static func GetGlucoseDirection(current: LibreRawGlucoseData?, last: LibreRawGlucoseData?) -> GlucoseTrend {
        NSLog("GetGlucoseDirection:: current:\(current), last: \(last)")
        guard let current = current, let last = last else {
            return GlucoseTrend.flat
        }
        
        
        let  s = calculateSlopeByMinute(current: current, last: last)
        NSLog("Got trendarrow value of \(s))")
        
        switch s {
        case _ where s <= (-3.5):
            return GlucoseTrend.downDownDown
        case _ where s <= (-2):
            return GlucoseTrend.downDown
        case _ where s <= (-1):
            return GlucoseTrend.down
        case _ where s <= (1):
            return GlucoseTrend.flat
        case _ where s <= (2):
            return GlucoseTrend.up
        case _ where s <= (3.5):
            return GlucoseTrend.upUp
        case _ where s <= (40):
            return GlucoseTrend.flat //flat is the new (tm) "unknown"!
            
        default:
            NSLog("Got unknown trendarrow value of \(s))")
            return GlucoseTrend.flat
        }
        
    }
}
