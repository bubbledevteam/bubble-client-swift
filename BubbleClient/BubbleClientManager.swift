//
//  BubbleClient.swift
//  BubbleClient
//
//  Created by Bjørn Inge Berg on 25/02/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI
import UserNotifications
import CoreBluetooth

import os.log
import HealthKit

public final class BubbleClientManager: CGMManager, BubbleBluetoothManagerDelegate {
    public let delegate = WeakSynchronizedDelegate<CGMManagerDelegate>()
    public var cgmManagerDelegate: CGMManagerDelegate? {
        get {
            return delegate.delegate
        }
        set {
            delegate.delegate = newValue
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return delegate.queue
        }
        set {
            delegate.queue = newValue
        }
    }
    
    public var sensorState: SensorDisplayable? {
        return latestBackfill
    }
    
    public var managedDataInterval: TimeInterval?
    
    public var device: HKDevice? {
        return HKDevice(
            name: "BubbleClient",
            manufacturer: "Bubble",
            model: nil, //latestSpikeCollector,
            hardwareVersion: hardwareVersion,
            firmwareVersion: firmwareVersion,
            softwareVersion: nil,
            localIdentifier: nil,
            udiDeviceIdentifier: nil
        )
    }
    
    public var peripheralState: CBPeripheralState {
        return BubbleClientManager.proxy?.peripheral?.state ?? .disconnected
    }
    
    public var debugDescription: String {
        
        return [
            "## BubbleClientManager",
            "Testdata: foo",
            "lastConnected: \(String(describing: lastConnected))",
            "Connection state: \(connectionState)",
            "Sensor state: \(sensorStateDescription)",
            "Bridge battery: \(battery)",
            //"Notification glucoseunit: \(glucoseUnit)",
            //"shouldSendGlucoseNotifications: \(shouldSendGlucoseNotifications)",
            //"latestBackfill: \(String(describing: "latestBackfill))",
            //"latestCollector: \(String(describing: latestSpikeCollector))",
            ""
            ].joined(separator: "\n")
    }
    
    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        //        guard BubbleClientManager.proxy != nil else {
        //            completion(.noData)
        //            return
        //        }
        NSLog("dabear:: fetchNewDataIfNeeded called but we don't continue")
        //        self.autoconnect()
        //        completion(.noData)
        /*
         self.getLastSensorValues { (error, glucose) in
         if let error = error {
         NSLog("dabear:: getLastSensorValues returned with error")
         completion(.error(error))
         return
         }
         
         guard let glucose = glucose else {
         NSLog("dabear:: getLastSensorValues returned with no data")
         completion(.noData)
         return
         }
         
         let startDate = self.latestBackfill?.startDate
         let newGlucose = glucose.filterDateRange(startDate, nil).filter({ $0.isStateValid }).map {
         return NewGlucoseSample(date: $0.startDate, quantity: $0.quantity, isDisplayOnly: false, syncIdentifier: "\(Int($0.startDate.timeIntervalSince1970))", device: self.device)
         }
         
         self.latestBackfill = glucose.first
         
         if newGlucose.count > 0 {
         completion(.newData(newGlucose))
         } else {
         completion(.noData)
         }
         
         } */
    }
    
    
    
    public private(set) var lastConnected : Date?
    
    // This tighly tracks latestBackfill,
    // and is defined here so that the ui can have a way to fetch the latest
    // glucose value
    public static var latestGlucose : GlucoseData?
    
    public private(set) var latestBackfill: GlucoseData? {
        didSet(oldValue) {
            NSLog("dabear:: latestBackfill set, newvalue is \(latestBackfill )")
            if let latestBackfill = latestBackfill {
                BubbleClientManager.latestGlucose = latestBackfill
                NSLog("dabear:: sending glucose notification")
                NotificationHelper.sendGlucoseNotitifcationIfNeeded(glucose: latestBackfill, oldValue: oldValue)
            }
            
        }
    }
    public static var managerIdentifier = "DexBubbleClient1"
    
    required convenience public init?(rawState: CGMManager.RawStateValue) {
        os_log("dabear:: BubbleClientManager will init from rawstate")
        self.init()
        
    }
    
    public var rawState: CGMManager.RawStateValue {
        return [:]
    }
    
    public let keychain = KeychainManager()
    
    //public var BubbleService: BubbleService
    
    public static let localizedTitle = LocalizedString("Bubble", comment: "Title for the CGMManager option")
    
    public let appURL: URL? = nil //URL(string: "spikeapp://")
    
    public let providesBLEHeartbeat = true
    
    public let shouldSyncToRemoteService = true
    
    
    private(set) public var lastValidSensorData : SensorData? = nil
    
    
    
    
    public init(){
        lastConnected = nil
        
        os_log("dabear: BubbleClientManager will be created now")
        //proxy = BubbleBluetoothManager()
        BubbleClientManager.proxy?.delegate = self
        //proxy?.connect()
        
        BubbleClientManager.instanceCount += 1   
    }
    
    public var connectionState : String {
        return BubbleClientManager.proxy?.state.rawValue ?? "n/a"
        
    }
    
    public var sensorSerialNumber: String {
        return BubbleClientManager.proxy?.sensorData?.serialNumber ?? "n/a"
    }
    
    public var sensorAge: String {
        guard let data =  BubbleClientManager.proxy?.sensorData else {
            return "n/a"
        }
        
        let sensorStart = Calendar.current.date(byAdding: .minute, value: -data.minutesSinceStart, to: data.date)!
        
        return  sensorStart.timeIntervalSinceNow.stringDaysFromTimeInterval() +  " day(s)"
        
    }
    
    public var sensorFooterChecksums: String {
        if let crc = BubbleClientManager.proxy?.sensorData?.footerCrc.byteSwapped {
            return  "\(crc)"
        }
        return  "n/a"
    }
    
    
    public var sensorStateDescription : String {
        return BubbleClientManager.proxy?.sensorData?.state.description ?? "n/a"
    }
    
    public var firmwareVersion : String {
        return BubbleClientManager.proxy?.bubble?.firmware ?? "n/a"
    }
    
    public var hardwareVersion : String {
        return BubbleClientManager.proxy?.bubble?.hardware ?? "n/a"
    }
    
    public var battery : String {
        if let bat = BubbleClientManager.proxy?.bubble?.battery {
            return "\(bat)%"
        }
        return "n/a"
    }
    
    public var calibrationData : LibreDerivedAlgorithmParameters? {
        return keychain.getLibreCalibrationData()
    }
    
    public func disconnect(){
        NSLog("dabear:: BubbleClientManager disconnect called")
        
        
        BubbleClientManager.proxy?.disconnectManually()
        BubbleClientManager.proxy?.delegate = nil
        //BubbleClientManager.proxy = nil
    }
    
    deinit {
        
        NSLog("dabear:: BubbleClientManager deinit called")
        
        
        //cleanup any references to events to this class
        disconnect()
        BubbleClientManager.instanceCount -= 1
    }
    
    
    private static var instanceCount = 0 {
        didSet {
            
            //this is to workaround a bug where multiple managers might exist
            os_log("dabear:: BubbleClientManager instanceCount changed to %s", type: .default, String(describing: instanceCount))
            if instanceCount < 1 {
                os_log("dabear:: instancecount is 0, deiniting service", type: .default)
                BubbleClientManager.sharedProxy = nil
                //BubbleClientManager.sharedInstance = nil
            }
            //this is another attempt to workaround a bug where multiple managers might exist
            if oldValue > instanceCount {
                os_log("dabear:: BubbleClientManager decremented, stop all Bubble bluetooth services")
                BubbleClientManager.sharedProxy = nil
                //BubbleClientManager.sharedInstance = nil
            }
            
            
        }
    }
    
    
    private static var sharedProxy: BubbleBluetoothManager?
    private class var proxy : BubbleBluetoothManager? {
        guard let sharedProxy = self.sharedProxy else {
            let sharedProxy = BubbleBluetoothManager()
            self.sharedProxy = sharedProxy
            return sharedProxy
        }
        return sharedProxy
    }
    
    
    
    func autoconnect() {
        guard let proxy = BubbleClientManager.proxy else {
            os_log("dabear: could not do autoconnect, proxy was nil")
            return
        }
        
        // force trying to reconnect every time a we detect
        // a disconnected state while fetching
        switch (proxy.state) {
        case .Unassigned, .powerOff:
            break
        //proxy.scanForBubble()
        case .Scanning:
            break
        case .Connected, .Connecting, .Notifying:
            break
        case .Disconnected, .DisconnectingDueToButtonPress:
            proxy.connect()
        }
    }
    
    private func trendToLibreGlucose(_ measurements: [Measurement]) -> [LibreGlucose]?{
        var origarr = [LibreGlucose]()
        
        //whether or not to return all the 16 latest trends or just every fifth element
        let returnAllTrends = true
        
        
        
        for trend in measurements {
            let glucose = LibreGlucose(unsmoothedGlucose: trend.temperatureAlgorithmGlucose, glucoseDouble: 0.0, trend: UInt8(GlucoseTrend.flat.rawValue), timestamp: trend.date, collector: "Bubble")
            origarr.append(glucose)
        }
        //NSLog("dabear:: glucose samples before smoothing: \(String(describing: origarr))")
        var arr : [LibreGlucose]
        arr = CalculateSmothedData5Points(origtrends: origarr)
        
        
        
        for i in 0 ..< arr.count {
            let trend = arr[i]
            //we know that the array "always" (almost) will contain 16 entries
            //the last five entries will get a trend arrow of flat, because it's not computable when we don't have
            //more entries in the array to base it on
            let arrow = TrendArrowCalculation.GetGlucoseDirection(current: trend, last: arr[safe: i+5])
            arr[i].trend = UInt8(arrow.rawValue)
            NSLog("Date: \(trend.timestamp), before: \(trend.unsmoothedGlucose), after: \(trend.glucose), arrow: \(trend.trend)")
        }
        
        
        
        
        if returnAllTrends {
            return arr
        }
        
        //        var filtered = [LibreGlucose]()
        //        for elm in arr.enumerated() where elm.offset % 5 == 0 {
        //            filtered.append(elm.element)
        //        }
        //
        //        //NSLog("dabear:: glucose samples after smoothing: \(String(describing: arr))")
        //        return filtered
    }
    
    public func handleGoodReading(data: SensorData?,_ callback: @escaping (LibreError?, [GlucoseData]?) -> Void) {
        //only care about the once per minute readings here, historical data will not be considered
        
        guard let data = data else {
            callback(LibreError.noSensorData, nil)
            return
        }
        
        LibreOOPClient.handleLibreData(sensorData: data) { result in
            guard let glucose = result?.glucoseData, !glucose.isEmpty else {
                callback(LibreError.noSensorData, nil)
                return
            }
            
            callback(nil, glucose)
        }
    }
    
    public func BubbleBluetoothManagerPeripheralStateChanged(_ state: BubbleManagerState) {
        switch state {
        case .Connected:
            lastConnected = Date()
        case .powerOff:
            NotificationHelper.sendBluetoothPowerOffNotification()
        case .Disconnected:
            NotificationHelper.sendDisconnectNotification()
        default:
            break
        }
        reloadData?()
        return
    }
    
    public func BubbleBluetoothManagerReceivedMessage(_ messageIdentifier: UInt16, txFlags: UInt8, payloadData: Data) {
        guard let packet = BubbleResponseState.init(rawValue: txFlags) else {
            // Incomplete package?
            // this would only happen if delegate is called manually with an unknown txFlags value
            // this was the case for readouts that were not yet complete
            // but that was commented out in BubbleManager.swift, see comment there:
            // "dabear-edit: don't notify on incomplete readouts"
            NSLog("dabear:: incomplete package or unknown response state")
            return
        }
        
        switch packet {
        case .newSensor:
            NSLog("dabear:: new libresensor detected")
            NotificationHelper.sendSensorChangeNotificationIfNeeded(hasChanged: true)
            break
        case .noSensor:
            NSLog("dabear:: no libresensor detected")
            NotificationHelper.sendSensorNotDetectedNotificationIfNeeded(noSensor: true)
            break
        case .frequencyChangedResponse:
            NSLog("dabear:: Bubble readout interval has changed!")
            break
            
        default:
            //we don't care about the rest!
            break
        }
        
        return
        
    }
    
    public var reloadData: (() -> ())?
    public func BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: SensorData, Bubble: Bubble) {
        
        NotificationHelper.sendLowBatteryNotificationIfNeeded(device: Bubble)
        //        NotificationHelper.sendInvalidSensorNotificationIfNeeded(sensorData: sensorData)
        NotificationHelper.sendSensorExpireAlertIfNeeded(sensorData: sensorData)
        
        if sensorData.isFirstSensor && sensorData.state != .ready { return }
        
        if sensorData.hasValidCRCs || sensorData.isSecondSensor {
            NSLog("dabear:: got sensordata with valid crcs, sensor was ready")
            self.lastValidSensorData = sensorData
            
            self.handleGoodReading(data: sensorData) { (error, glucose) in
                if let error = error {
                    NSLog("dabear:: handleGoodReading returned with error: \(error)")
                    
                    self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .error(error))
                    self.reloadData?()
                    return
                }
                
                guard let glucose = glucose else {
                    NSLog("dabear:: handleGoodReading returned with no data")
                    self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .noData)
                    self.reloadData?()
                    return
                }
                
                let startDate = self.latestBackfill?.startDate
                let newGlucose = glucose.filterDateRange(startDate, nil).filter({ $0.isStateValid }).map {
                    return NewGlucoseSample(date: $0.startDate, quantity: $0.quantity, isDisplayOnly: false, syncIdentifier: "\(Int($0.startDate.timeIntervalSince1970))", device: self.device)
                }
                
                self.latestBackfill = glucose.first
                
                if newGlucose.count > 0 {
                    NSLog("dabear:: handleGoodReading returned with \(newGlucose.count) new glucose samples")
                    self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .newData(newGlucose))
                    
                } else {
                    NSLog("dabear:: handleGoodReading returned with no new data")
                    self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .noData)
                    
                }
                
            }
            
        } else {
            self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .error(LibreError.checksumValidationError))
            os_log("dit not get sensordata with valid crcs")
        }
        self.reloadData?()
        return
    }
    
    
    
    
}
