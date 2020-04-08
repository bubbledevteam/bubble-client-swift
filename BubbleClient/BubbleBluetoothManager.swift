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
            sleep(3)
            self.test()
        }
        
        let timer = Timer.init(timeInterval: 60 * 5, repeats: true) { (_) in
            self.test()
        }
        RunLoop.current.add(timer, forMode: .commonModes)
        #endif
    }
    
    func test() {
        var data = "7e71401303000000000000000000000000000000000000006bcb04002d07c83459012d07c83059012a07c82459012707c83859016607c82059016e07c82859017007c82859016d07c84059016307c85459015707c84859015607c84859014c07c86459014407c87459013d07c87c59013b07c86459014507c84459011e06c8cc1b013406c8605a013706c8841a017805c8c0dc00b204c84cde001604c84ca000b503c844a1007303c8f062007603c8c861008c03c81ca100ee03c8c0dd00e404c8e05a011e06c8345a013c07880e1b01ce07c8785a019b07c8581a01d107c8f01901f907c8c45901de07c8705901de07c8f49801c507c8185901a807c8105901fb07c8385901f508c81499015c09c86c98015309c86498013809c88c9801e008c8c458015708c8f09801b707c8f498015807c8f898013707c84459014529000044d100015108f550140796805a00eda6187b1ac804c25869".hexadecimal ?? Data()
        data = data.subdata(in: 0..<344)
        sensorData = SensorData(uuid: Data(), bytes: [UInt8](data), date: Date(), derivedAlgorithmParameterSet: nil)
        
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
        if let uuidString = lastConnectedIdentifier,
            let uuid = UUID(uuidString: uuidString),
            let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first
        {
            self.peripheral = peripheral
            centralManager.connect(peripheral, options: [:])
        } else if let peripheral = centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs).first,
            peripheral.name == deviceName
        {
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
                            if let writeCharacteristic = writeCharacteristic {
                                print("-----set: ", writeCharacteristic)
                                peripheral.writeValue(Data([0x02, 0x00, 0x00, 0x00, 0x00, 0x2B]), for: writeCharacteristic, type: .withoutResponse)
                            }
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
                            let firmware = bubble?.firmware
                            // version = 1.34 patchInfo range 3 ..< 9
                            if firmware == "1.34" {
                                if value.count >= 8 {
                                    patchInfo = value.subdata(in: 3 ..< 9).hexEncodedString().uppercased()
                                }
                            } else if (Float(firmware ?? "0") ?? 0) > 1.34 {
                                // version > 1.34 patchInfo range 3 ..< 9
                                if value.count >= 10 {
                                    patchInfo = value.subdata(in: 5 ..< 11).hexEncodedString().uppercased()
                                }
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
        if let writeCharacteristic = writeCharacteristic {
            peripheral?.writeValue(Data.init(bytes: [0x00, 0x00, 0x05]), for: writeCharacteristic, type: .withoutResponse)
        }
    }
    
    
    func resetBuffer() {
        rxBuffer = Data()
    }
    
    func handleCompleteMessage() {
        guard rxBuffer.count >= 352, let bubble = bubble else {
            return
        }
        let data = rxBuffer.subdata(in: 8..<352)
        sensorData = SensorData(uuid: rxBuffer.subdata(in: 0..<8), bytes: [UInt8](data), date: Date(), derivedAlgorithmParameterSet: nil)
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
