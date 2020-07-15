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
    
    private enum Config {
        static let useFilterKey = "BubbleClientManager.useFilter"
        static let filterNoise = 2.5
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
            name: "DiaBoxClient",
            manufacturer: "DiaBox",
            model: nil, //latestSpikeCollector,
            hardwareVersion: hardwareVersion,
            firmwareVersion: firmwareVersion,
            softwareVersion: nil,
            localIdentifier: nil,
            udiDeviceIdentifier: nil
        )
    }
    
    public var todayLogs: String {
        return LogsAccessor.todayLogs()
    }
    
    public var peripheralState: CBPeripheralState {
        return BubbleClientManager.proxy?.peripheral?.state ?? .disconnected
    }
    
    public var debugDescription: String {
        
        return [
            "## BubbleClientManager",
            "lastConnected: \(String(describing: lastConnected))",
            "Connection state: \(connectionState)",
            "Sensor state: \(sensorStateDescription)",
            "Bridge battery: \(battery)",
            "Code Error: \(UserDefaultsUnit.coreDataError!)",
            "latestBackfill: \(latestBackfill?.description ?? "")"
            ].joined(separator: "\n")
    }
    
    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        LogsAccessor.log("fetchNewDataIfNeeded")
        completion(.noData)
    }
    
    
    public private(set) var lastConnected : Date?
    
    public private(set) var latestBackfill: GlucoseData? {
        set {
            UserDefaultsUnit.latestGlucose = newValue
        }
        get { UserDefaultsUnit.latestGlucose }
    }
    
    public static var managerIdentifier = "DexBubbleClient1"
    
    required convenience public init?(rawState: CGMManager.RawStateValue) {
        self.init()
        useFilter = rawState[Config.useFilterKey] as? Bool ?? false
    }
    
    public var rawState: CGMManager.RawStateValue {
        [
            Config.useFilterKey: useFilter
        ]
    }
    
    public let keychain = KeychainManager()
    
    //public var BubbleService: BubbleService
    
    public static let localizedTitle = LocalizedString("DiaBox", comment: "Title for the CGMManager option")
    
    public let appURL: URL? = URL(string: "diabox://")
    
    public let providesBLEHeartbeat = true
    
    public let shouldSyncToRemoteService = true
    
    public var useFilter = false
    
    
    private(set) public var lastValidSensorData : SensorData? = nil
    
    public init(){
        lastConnected = nil
        
        LogsAccessor.log("BubbleClientManager will be created now")
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
        LogsAccessor.log("BubbleClientManager disconnect called")
        BubbleClientManager.proxy?.disconnectManually()
        BubbleClientManager.proxy?.delegate = nil
    }
    
    public func retrievePeripherals() {
        BubbleClientManager.proxy?.retrievePeripherals()
    }
    
    deinit {
        LogsAccessor.log("BubbleClientManager deinit called")
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
    
    public func handleGoodReading(data: SensorData?,_ callback: @escaping (LibreError?, [GlucoseData]?) -> Void) {
        //only care about the once per minute readings here, historical data will not be considered
        guard let data = data else {
            LogsAccessor.log("sensor data nil")
            return
        }
        
        LibreOOPClient.handleLibreData(sensorData: data) { result in
            guard let glucose = result?.glucoseData, !glucose.isEmpty else { return }
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
        reloadData?()
        LogsAccessor.log("name: \(sensorData.sensorName), patchInfo: \(sensorData.patchInfo ?? ""), patchUid: \(sensorData.patchUid ?? ""), \ncontent: \(Data(sensorData.bytes).hexEncodedString()), state: \(sensorData.state.description)")
        if sensorData.isFirstSensor {
            if sensorData.state != .ready { return }
            guard sensorData.hasValidCRCs else {
                LogsAccessor.log("crc failed")
                return
            }
        }
        
        self.lastValidSensorData = sensorData
        self.handleGoodReading(data: sensorData) { [weak self]  (_, glucose) in
            guard let self = self else { return }
            LogsAccessor.log("got glucose")
            
            guard let glucose = glucose, !glucose.isEmpty else { return }
            var filteredGlucose = glucose
            if self.useFilter {
                var filter = KalmanFilter(stateEstimatePrior: glucose.last!.glucoseLevelRaw, errorCovariancePrior: Config.filterNoise)
                filteredGlucose.removeAll()
                for item in glucose.reversed() {
                    let prediction = filter.predict(stateTransitionModel: 1, controlInputModel: 0, controlVector: 0, covarianceOfProcessNoise: Config.filterNoise)
                    let update = prediction.update(measurement: item.glucoseLevelRaw, observationModel: 1, covarienceOfObservationNoise: Config.filterNoise)
                    filter = update
                    item.glucoseLevelRaw = filter.stateEstimatePrior.rounded()
                    filteredGlucose.append(item)
                }
                filteredGlucose = filteredGlucose.reversed()
            }
            
            let startDate = self.latestBackfill?.startDate.addingTimeInterval(4 * 60)
            
            let filterred = filteredGlucose.filterDateRange(startDate, nil).filter({ $0.isStateValid }).sorted { (data1, data2) -> Bool in
                return data1.timeStamp > data2.timeStamp
            }
            
            let newGlucose = filterred.map {
                return NewGlucoseSample(date: $0.startDate, quantity: $0.quantity, isDisplayOnly: false, syncIdentifier: "\(Int($0.startDate.timeIntervalSince1970))", device: self.device)
            }
            
            // update current glucose value every time.
            if let last = self.latestBackfill, let current = filterred.first {
                last.glucoseLevelRaw = current.glucoseLevelRaw
                last.timeStamp = current.timeStamp
                self.latestBackfill = last
            }
            
            if newGlucose.count > 0 {
                var latest = self.latestBackfill
                if filterred.count > 1 {
                    latest = filterred[1]
                }
                // update glucoseLevelRaw and timeStamp for calculate arrow.
                if let last = latest {
                    latest?.glucoseLevelRaw = last.lastValue
                    latest?.timeStamp = last.lastDate
                }
                
                if let newValue = filterred.first {
                    let arrow = LibreOOPClient.GetGlucoseDirection(current: newValue, last: latest)
                    newValue.trend = UInt8(arrow.rawValue)
                    self.latestBackfill = newValue
                    var params = "current glucose: \(newValue.description)\n["
                    for g in newGlucose {
                        params +=
                        """
                        {"date": \(g.date), "glucose": \(g.quantity.doubleValue(for: .milligramsPerDeciliter))},\n
                        """
                    }
                    params += "]"
                    LogsAccessor.log(params)
                }
                
                self.delegate.notify { (delegate) in
                    delegate?.cgmManager(self, didUpdateWith: .newData(newGlucose))
                    LogsAccessor.log("update glucose success")
                }
            }
        }
    }
    
    
    func BubbleBluetoothManagerMessageChanged() {
        reloadData?()
    }
}
