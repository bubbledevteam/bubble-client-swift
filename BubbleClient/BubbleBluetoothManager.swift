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
    var sensorData: SensorData?
    var patchInfo: String?
    
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
        os_log("Bubblemanager init called ", log: BubbleBluetoothManager.bt_log)
        
        #if DEBUG
        DispatchQueue.global().async {
            sleep(10)
            self.test()
        }
        
        let timer = Timer.init(timeInterval: 60, repeats: true) { (_) in
            self.test()
        }
        RunLoop.current.add(timer, forMode: .common)
        #endif
    }
    
    func test() {
        var data = "1ef660140300000000000000000000000000000000000000e1400101980ac834d900470ac8f89800440ac8d4d8002d0ac894d8002a0ac86058013a0ac8305801400ac8fc17015a0ac8c45701680ac8a81701710ac89817018d0ac88c57019a0ac87817019f0ac8745701a60ac8f457019a0ac86c1801a30ac8f898009e0ac86c18012603c898d7002503c874d700ff02c83cd700b202c8c459008602c8401b809b02c8f41c80b802c8c41c80c202c8941c808703c8d41c804f04c8805a009004c82c1d806904c8501c800005c83c1c806805c84c1d808f05c8941d807805c8341e809e05c8a01c807705c8c81c800105c8141e80b604c8b81d808904c86c1d804004c8cc1d807804c8b05d80f804c8201d802906c8d01a80a806c8bc1b802107c8041c80ae07c8ec1b808808c8b89900ac09c8601801290ac85c5900f24c0000827600087e083351140796805a00eda6106a1ac804cfb96d".hexadecimal ?? Data()
        data = data.subdata(in: 0..<344)
        sensorData = SensorData(uuid: Data(), bytes: [UInt8](data), date: Date())
        sensorData?.patchUid = "1FE0A80400A007E0"
        sensorData?.patchInfo = "DF000008D306"
        // Check if sensor data is valid and, if this is not the case, request data again after thirty second
        if let sensorData = sensorData {
            let bubble = Bubble(hardware: "0", firmware: "0", battery: 20)
            // Inform delegate that new data is available
            delegate?.BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: sensorData, Bubble: bubble)
        }
    }
    
//    func scanForBubble() {
//        autoScanning = false
//        os_log("Scan for Bubble while state %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state))
//        if centralManager.state == .poweredOn {
//            disconnectManually()
//            os_log("Before scan for Bubble while central manager state %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: centralManager.state.rawValue))
//            centralManager.scanForPeripherals(withServices: nil, options: nil)
//
//            state = .Scanning
//        }
//    }
    
    func connect() {
        os_log("Connect while state %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue))
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
            centralManager.connect(peripheral, options: [:])
        }
    }
    
    func disconnectManually() {
        os_log("Disconnect manually while state %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue))

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
            os_log("Central Manager was either .poweredOff, .resetting, .unauthorized, .unknown, .unsupported: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: central.state))
            state = .Unassigned
        case .poweredOn:
            os_log("state poweredOn", log: BubbleBluetoothManager.bt_log)
            retrievePeripherals()
        @unknown default:
            break
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
//        os_log("Did discover peripheral while state %{public}@ with name: %{public}@, wantstoterminate?:  %d", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue), String(describing: peripheral.name), self.wantsToTerminate)
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Did connect peripheral while state %{public}@ with name: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue), String(describing: peripheral.name))
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
        
        os_log("Did fail to connect peripheral while state: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue))
        if let error = error {
            os_log("Did fail to connect peripheral error: %{public}@", log: BubbleBluetoothManager.bt_log, type: .error ,  "\(error.localizedDescription)")
        }
        state = .Disconnected
        connect()
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        os_log("Did disconnect peripheral while state: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue))
        if let error = error {
            os_log("Did disconnect peripheral error: %{public}@", log: BubbleBluetoothManager.bt_log, type: .error ,  "\(error.localizedDescription)")
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
        
        os_log("Did discover services", log: BubbleBluetoothManager.bt_log, type: .default)
        if let error = error {
            os_log("Did discover services error: %{public}@", log: BubbleBluetoothManager.bt_log, type: .error ,  "\(error.localizedDescription)")
        }
        
        
        if let services = peripheral.services {
            
            for service in services {
                if service.characteristics != nil {
                    self.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: nil)
                } else {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
                
                os_log("Did discover service: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: service.debugDescription))
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        os_log("Did discover characteristics for service %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: peripheral.name))
        
        if let error = error {
            os_log("Did discover characteristics for service error: %{public}@", log: BubbleBluetoothManager.bt_log, type: .error ,  "\(error.localizedDescription)")
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                os_log("Did discover characteristic: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: characteristic.debugDescription))
                if (characteristic.properties.intersection(.notify)) == .notify && characteristic.uuid == CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") {
                    peripheral.setNotifyValue(true, for: characteristic)
                    os_log("Set notify value for this characteristic", log: BubbleBluetoothManager.bt_log, type: .default)
                }
                if (characteristic.uuid == CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")) {
                    writeCharacteristic = characteristic
                }
            }
        } else {
            os_log("Discovered characteristics, but no characteristics listed. There must be some error.", log: BubbleBluetoothManager.bt_log, type: .default)
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        os_log("Did update notification state for characteristic: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: characteristic.debugDescription))
        
        if let error = error {
            os_log("Peripheral did update notification state for characteristic: %{public}@ with error", log: BubbleBluetoothManager.bt_log, type: .error ,  "\(error.localizedDescription)")
        } else {
            resetBuffer()
            requestData()
        }
        state = .Notifying
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        os_log("Did update value for characteristic: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: characteristic.debugDescription))
        
        if let error = error {
            os_log("Characteristic update error: %{public}@", log: BubbleBluetoothManager.bt_log, type: .error ,  "\(error.localizedDescription)")
        } else {
            if characteristic.uuid == CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"), let value = characteristic.value {
                if let firstByte = value.first {
                    if let bubbleResponseState = BubbleResponseType(rawValue: firstByte) {
                        switch bubbleResponseState {
                        case .bubbleInfo:
                            let battery = Int(value[4])
                            bubble = Bubble(hardware: "0", firmware: "0", battery: battery)
                            delegate?.BubbleBluetoothManagerMessageChanged()
//                            if let writeCharacteristic = writeCharacteristic {
//                                print("-----set: ", writeCharacteristic)
//                                peripheral.writeValue(Data([0x02, 0x00, 0x00, 0x00, 0x00, 0x2B]), for: writeCharacteristic, type: .withoutResponse)
//                            }
                        case .dataPacket:
                            guard rxBuffer.count >= 8 else { return }
                            rxBuffer.append(value.suffix(from: 4))
                            if rxBuffer.count >= 352 {
                                os_log("dabear:: receive 352 bytes")
                                handleCompleteMessage()
                                resetBuffer()
                            }
                        case .noSensor:
                            os_log("dabear:: receive noSensor")
                            delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0x34, payloadData: rxBuffer)
                            resetBuffer()
                        case .serialNumber:
                            os_log("dabear:: receive serialNumber")
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
        os_log("Did Write value %{public}@ for characteristic %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(characteristic.value.debugDescription), String(characteristic.debugDescription))
    }
    
    // Bubble specific commands
    func requestData() {
//        if let writeCharacteristic = writeCharacteristic {
//            peripheral?.writeValue(Data.init(bytes: [0x00, 0x00, 0x05]), for: writeCharacteristic, type: .withoutResponse)
//        }
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
        let data = rxBuffer.subdata(in: 8..<352)
        sensorData = SensorData(uuid: rxBuffer.subdata(in: 0..<8), bytes: [UInt8](data), date: Date())
        sensorData?.patchInfo = patchInfo
        
        if bubble.battery < 20 {
            NotificationHelper.sendLowBatteryNotificationIfNeeded(device: bubble)
        }
        
        // Check if sensor data is valid and, if this is not the case, request data again after thirty second
        if let sensorData = sensorData {
            // Inform delegate that new data is available
            delegate?.BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: sensorData, Bubble: bubble)
        }
    }
    
    deinit {
        self.delegate = nil
        os_log("dabear:: Bubblemanager deinit called")
    }
    
}

fileprivate enum BubbleResponseType: UInt8 {
    case dataPacket = 130
    case bubbleInfo = 128
    case noSensor = 191
    case serialNumber = 192
    case patchInfo = 193
}


extension String {
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
