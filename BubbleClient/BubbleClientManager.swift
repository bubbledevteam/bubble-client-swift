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
            "latestBackfill: \(latestBackfill?.description ?? "")",
            //"latestCollector: \(String(describing: latestSpikeCollector))",
            "logs: \(Self.logs.joined(separator: "\n"))",
            ""
            ].joined(separator: "\n")
    }
    
    static private var logs = [String]()
    
    public static func addlog(log: String?) {
        guard let log = log else { return }
        logs.insert(log, at: 0)
    }
    
    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        NSLog("dabear:: fetchNewDataIfNeeded called but we don't continue")

    }
    
    
    
    public private(set) var lastConnected : Date?
    
    public private(set) var latestBackfill: GlucoseData? {
        set {
            if let newValue = newValue {
                NSLog("dabear:: sending glucose notification")
                NotificationHelper.sendGlucoseNotitifcationIfNeeded(glucose: newValue, oldValue: latestBackfill)
                UserDefaultsUnit.latestGlucose = newValue
            }
        }
        get { UserDefaultsUnit.latestGlucose }
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
    
    public static let localizedTitle = LocalizedString("DiaBox", comment: "Title for the CGMManager option")
    
    public let appURL: URL? = URL(string: "diabox://")
    
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
    
    public func retrievePeripherals() {
        BubbleClientManager.proxy?.retrievePeripherals()
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
    
    public func handleGoodReading(data: SensorData?,_ callback: @escaping (LibreError?, [GlucoseData]?) -> Void) {
        //only care about the once per minute readings here, historical data will not be considered
        
        guard let data = data else {
            callback(LibreError.noSensorData, nil)
            return
        }
        
        BubbleClientManager.addlog(log: "patchUid: \(data.patchUid ?? ""), patchInfo: \(data.patchInfo ?? "")\n content: \(Data(data.bytes).hexEncodedString())")
        
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
        NotificationHelper.sendLowBatteryNotificationIfNeeded(device: Bubble)
        //        NotificationHelper.sendInvalidSensorNotificationIfNeeded(sensorData: sensorData)
        NotificationHelper.sendSensorExpireAlertIfNeeded(sensorData: sensorData)
        
        if sensorData.isFirstSensor && sensorData.state != .ready { return }
        
        if sensorData.hasValidCRCs || sensorData.isSecondSensor {
            NSLog("dabear:: got sensordata with valid crcs, sensor was ready")
            self.lastValidSensorData = sensorData
            
            self.handleGoodReading(data: sensorData) { (error, glucose) in
                self.delegateQueue.async {
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
                    
                    if let latest = self.latestBackfill, let current = glucose.first {
                        let arrow = LibreOOPClient.GetGlucoseDirection(current: current, last: latest)
                        glucose.first?.trend = UInt8(arrow.rawValue)
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
            }
            
        } else {
            self.delegateQueue.async {
                self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .error(LibreError.checksumValidationError))
            }
            os_log("dit not get sensordata with valid crcs")
        }
    }
    
    
    func BubbleBluetoothManagerMessageChanged() {
        reloadData?()
    }
    
}
