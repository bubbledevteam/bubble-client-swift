//
//  BubbleManager.swift
//  LibreMonitor
//
//  Created by Uwe Petersen on 10.03.18.
//  Copyright © 2018 Uwe Petersen. All rights reserved.
//
//  How does the Bubble work?
//

import Foundation
import UIKit
import CoreBluetooth
import os.log

public enum BubbleManagerState: String {
    case Unassigned = "Unassigned"
    case Scanning = "Scanning"
    case Disconnected = "Disconnected"
    case DisconnectingDueToButtonPress = "Disconnecting due to button press"
    case Connecting = "Connecting"
    case Connected = "Connected"
    case Notifying = "Notifying"
    case powerOff = "powerOff"
}

public enum BubbleResponseState: UInt8 {
    case dataPacketReceived = 0x28
    case newSensor = 0x32
    case noSensor = 0x34
    case frequencyChangedResponse = 0xD1
}
extension BubbleResponseState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacketReceived:
            return "Data packet received"
        case .newSensor:
            return "New sensor detected"
        case .noSensor:
            return "No sensor found"
        case .frequencyChangedResponse:
            return "Reading intervall changed"
        }
    }
}

protocol BubbleBluetoothManagerDelegate {
    func BubbleBluetoothManagerPeripheralStateChanged(_ state: BubbleManagerState)
    func BubbleBluetoothManagerReceivedMessage(_ messageIdentifier:UInt16, txFlags:UInt8, payloadData:Data)
    func BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: SensorData, Bubble: Bubble) -> Void
    func BubbleBluetoothManagerMessageChanged()
}

final class BubbleBluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: - Properties
    private var wantsToTerminate = false
    private var lastConnectedIdentifier: String? {
        set {
            UserDefaults.standard.set(newValue, forKey: "lastConnectedIdentifier")
        }
        get {
            return UserDefaults.standard.value(forKey: "lastConnectedIdentifier") as? String
        }
    }
    
    static let bt_log = OSLog(subsystem: "com.LibreMonitor", category: "BubbleManager")
    var bubble: Bubble?
    var BubbleResponseState: BubbleResponseState?
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    //    var slipBuffer = SLIPBuffer()
    var writeCharacteristic: CBCharacteristic?
    
    var rxBuffer = Data()
    private var proRxBuffer = Data()
    var sensorData: SensorData?
    var patchInfo: String?
    var isDecryptedDataPacket = false
    
    //    fileprivate let serviceUUIDs:[CBUUID]? = [CBUUID(string: "6E400001B5A3F393E0A9E50E24DCCA9E")]
    fileprivate let deviceName = "Bubble"
    fileprivate let serviceUUIDs:[CBUUID] = [CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")]

    var delegate: BubbleBluetoothManagerDelegate? {
        didSet {
            // Help delegate initialize by sending current state directly after delegate assignment
            delegate?.BubbleBluetoothManagerPeripheralStateChanged(state)
        }
    }
    
    var state: BubbleManagerState = .Unassigned {
        didSet {
            // Help delegate initialize by sending current state directly after delegate assignment
            delegate?.BubbleBluetoothManagerPeripheralStateChanged(state)
        }
    }
    
    // MARK: - Methods
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        //        slipBuffer.delegate = self
        
        #if DEBUG
        DispatchQueue.global().async {
            sleep(2)
            self.test1()
        }
        #endif
        
        NotificationCenter.default.addObserver(self, selector: #selector(runWhenAppWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func runWhenAppWillEnterForeground(_ : Notification) {
        if peripheral?.state != .connected {
            retrievePeripherals()
        }
    }
    
    func test() {
        var data = "9421901a03000000000000000000000000000000000000009ece040baa0bc8f81a81950bc8fc1a81880bc8fc1a81720bc8f81a81600cc8581b814b0cc8541b81310cc8481b81210cc8481b81120cc840db80fb0bc8381b81e70bc8341b81d70bc8241b81ca0bc8141b81c30bc80c1b81b50bc8081b81b00bc8ec1a818a08c8d41a81520ac8401b81d20bc8541b81990cc8041c81000dc8081d81380ec8341b812e0fc8a019816a0ec85c1a81c50dc8541a81b10dc80c1b815a0cc8581b814d05c8641f811905c8a01e813a05c8701e811b05c81c1e81bc04c8e81c81b504c8501d816904c8141d816804c8c41c815305c8001d819605c8581d812405c8481c81df04c8701a81da03c834d9801503c8f4d7800c02c8fcd6802101c818d680b200c8c4d5809e00c8c018814002c87418813304c83419810207c86c1a8194020000ce9b0001cf09a150140796805a00eda600921ac804bed866".hexadecimal ?? Data()
        data = data.subdata(in: 0..<344)
        sensorData = SensorData(uuid: Data(), bytes: [UInt8](data), date: Date(), patchInfo: "A20000081E00")
        sensorData?.patchUid = "84C6B86000A007E0"
        // Check if sensor data is valid and, if this is not the case, request data again after thirty second
        if let sensorData = sensorData {
            let bubble = Bubble(hardware: "0", firmware: "0", battery: 20)
            // Inform delegate that new data is available
            delegate?.BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: sensorData, Bubble: bubble)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(60 * 4.5))) {
            self.test1()
        }
    }
    
    func test1() {
        var data = "05dad01d0300000000000000000000000000000000000000f22d0b0c600cc8bc5b00500cc8b05b004a0cc8805b00410cc8685b00360cc8485b00370cc8b85b00430cc8705b003e0cc82c5c002f0cc8345c000e0cc8585c00f20bc8845c005d0cc8305c005e0cc8fc5b00570cc8f45b00500cc8c45b00550cc8ac5b00b809c8045c00730ac8785c00500bc8005b00650cc8f89900ff0cc8a85a00a90cc8785b00f90cc8ac9a00640dc81c9a00540dc8d49a00fb0cc8645c008a0cc8605c00410cc8685b007a05c8085e002f05c8a05b005605c8689a008505c8489a004f04c8005c009603c8805d00ba03c8889a007805c8849900c307c8445a001f08c8e01d805708c8fc5b004a08c8cc5c00a508c8b85b001d09c8d89a004509c8f45b00c308c8a85c003608c8f01e806408c8305c00ba08c8745b003709c8285c003b0800007c3500045b0a0e51140796805a00eda612551ac80421ba76".hexadecimal ?? Data()
        data = data.subdata(in: 0..<344)
        sensorData = SensorData(uuid: Data(), bytes: [UInt8](data), date: Date(), patchInfo: "A20800045B37")
        sensorData?.patchUid = "45F4820500A007E0"
        sensorData?.isDecryptedDataPacket = true
        // Check if sensor data is valid and, if this is not the case, request data again after thirty second
        if let sensorData = sensorData {
            let bubble = Bubble(hardware: "0", firmware: "2.6", battery: 20)
            // Inform delegate that new data is available
            delegate?.BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: sensorData, Bubble: bubble)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(60 * 4.5))) {
            self.test()
        }
    }
    
    func connect() {
        if let p = peripheral {
            p.delegate = self
            centralManager.connect(p, options: nil)
            state = .Connecting
        }
    }
    
    func retrievePeripherals() {
        guard peripheral?.state  != .connected else { return }
        if let peripheral = centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs).first,
            peripheral.name == deviceName {
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            centralManager.connect(peripheral, options: [:])
            state = .Connecting
        }
    }
    
    func disconnectManually() {
        if let p = peripheral {
            centralManager.cancelPeripheralConnection(p)
            peripheral = nil
        }
    }
    
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            state = .powerOff
        case  .resetting, .unauthorized, .unknown, .unsupported:
            state = .Unassigned
        case .poweredOn:
            retrievePeripherals()
        @unknown default:
            break
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        state = .Connected
        self.lastConnectedIdentifier = peripheral.identifier.uuidString
        // Discover all Services. This might be helpful if writing is needed some time
        peripheral.delegate = self
        if peripheral.services != nil {
            self.peripheral(peripheral, didDiscoverServices: nil)
        } else {
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            LogsAccessor.log("Did fail to connect peripheral error: \(error.localizedDescription)")
        }
        state = .Disconnected
        connect()
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            LogsAccessor.log("Did disconnect peripheral error: \(error.localizedDescription)")
        }
        
        
        switch state {
        case .DisconnectingDueToButtonPress:
            state = .Disconnected
            self.wantsToTerminate = true
        
        default:
            state = .Disconnected
            connect()
        }
    }
    
    
    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            
            for service in services {
                if service.characteristics != nil {
                    self.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: nil)
                } else {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if (characteristic.properties.intersection(.notify)) == .notify && characteristic.uuid == CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if (characteristic.uuid == CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")) {
                    writeCharacteristic = characteristic
                }
            }
        } else {
            LogsAccessor.log("Discovered characteristics, but no characteristics listed.")
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            LogsAccessor.log("Peripheral did update notification with error: \(error.localizedDescription)")
        } else {
            resetBuffer()
            requestData()
        }
        state = .Notifying
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            LogsAccessor.log("Characteristic update error: \(error.localizedDescription)")
        } else {
            if characteristic.uuid == CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"), let value = characteristic.value {
                if let firstByte = value.first {
                    if let bubbleResponseState = BubbleResponseType(rawValue: firstByte) {
                        switch bubbleResponseState {
                        case .bubbleInfo:
                            let battery = Int(value[4])
                            let firmware = "\(value[2]).\(value[3])"
                            bubble = Bubble(hardware: "0", firmware: firmware, battery: battery)
                            delegate?.BubbleBluetoothManagerMessageChanged()
                            LogsAccessor.log("Battery: \(battery)")
                        case .dataPacket, .decryptedDataPacket:
                            isDecryptedDataPacket = bubbleResponseState == .decryptedDataPacket
                            guard rxBuffer.count >= 8 else { return }
                            rxBuffer.append(value.suffix(from: 4))
                            if rxBuffer.count >= 352 {
                                handleCompleteMessage()
                                resetBuffer()
                            }
                        case .noSensor:
                            delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0x34, payloadData: rxBuffer)
                            resetBuffer()
                        case .serialNumber:
                            rxBuffer.append(value.subdata(in: 2..<10))
                        case .patchInfo:
                            if value.count >= 10 {
                                patchInfo = value.subdata(in: 5 ..< 11).hexEncodedString().uppercased()
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
    }
    
    // Bubble specific commands
    func requestData() {
        
    }
    
    
    func resetBuffer() {
        rxBuffer = Data()
    }
    
    var latestUpdateDate = Date(timeIntervalSince1970: 0)
    func handleCompleteMessage() {
        guard latestUpdateDate.addingTimeInterval(60 * 4) < Date() else { return }
        guard rxBuffer.count >= 352, let bubble = bubble else {
            return
        }
        
        LogsAccessor.log("receive 344")
        let data = rxBuffer.subdata(in: 8 ..< 352)
        sensorData = SensorData(uuid: rxBuffer.subdata(in: 0..<8), bytes: [UInt8](data), date: Date(), patchInfo: patchInfo)
        guard var sensorData = sensorData else { return }
        
        if isDecryptedDataPacket || sensorData.isFirstSensor {
            sensorData.isDecryptedDataPacket = true
            // Inform delegate that new data is available
            delegate?.BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: sensorData, Bubble: bubble)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        self.delegate = nil
    }
}

fileprivate enum BubbleResponseType: UInt8 {
    case dataPacket = 130
    case decryptedDataPacket = 0x88
    case bubbleInfo = 128
    case noSensor = 191
    case serialNumber = 192
    case patchInfo = 193
}


public extension String {
    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        guard data.count > 0 else { return nil }
        return data
    }
}
