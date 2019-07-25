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

public class BubblePeripheral: NSObject {
    public var mac: String?
    public var peripheral: CBPeripheral?
}

public enum BubbleManagerState: String {
    case Unassigned = "Unassigned"
    case Scanning = "Scanning"
    case Disconnected = "Disconnected"
    case DisconnectingDueToButtonPress = "Disconnecting due to button press"
    case Connecting = "Connecting"
    case Connected = "Connected"
    case Notifying = "Notifying"
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
    func BubbleBluetoothManagerDidFound(peripheral: BubblePeripheral)
}

final class BubbleBluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var list = [BubblePeripheral]()
    // MARK: - Properties
    private var wantsToTerminate = false
    private var lastConnectedIdentifier : String?
    
    static let bt_log = OSLog(subsystem: "com.LibreMonitor", category: "BubbleManager")
    var bubble: Bubble?
    var BubbleResponseState: BubbleResponseState?
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    //    var slipBuffer = SLIPBuffer()
    var writeCharacteristic: CBCharacteristic?
    
    var rxBuffer = Data()
    var sensorData: SensorData?
    
    //    fileprivate let serviceUUIDs:[CBUUID]? = [CBUUID(string: "6E400001B5A3F393E0A9E50E24DCCA9E")]
    fileprivate let deviceName = "Bubble"
    fileprivate let serviceUUIDs:[CBUUID]? = [CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")]
    
    var BLEScanDuration = 3.0
    weak var timer: Timer?
    
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
        
    }
    
    func scanForBubble() {
        os_log("Scan for Bubble while state %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state))
        //        print(centralManager.debugDescription)
        if centralManager.state == .poweredOn {
            disconnectManually()
            os_log("Before scan for Bubble while central manager state %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: centralManager.state.rawValue))
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            
            state = .Scanning
            
            //            print(centralManager.debugDescription)
        }
        //        // Set timer to check connection and reconnect if necessary
        //        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) {_ in
        //            os_log("********** Reconnection timer fired in background **********", log: BubbleManager.bt_log, type: .default)
        //            if self.state != .Notifying {
        //                self.scanForBubble()
        //                //                NotificationManager.scheduleDebugNotification(message: "Reconnection timer fired in background", wait: 0.5)
        //            }
        //        }
    }
    
    func connect() {
        os_log("Connect while state %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue))
        if let peripheral = peripheral {
            peripheral.delegate = self
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
            state = .Connecting
        }
    }
    
    func disconnectManually() {
        os_log("Disconnect manually while state %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue))
        //        NotificationManager.scheduleDebugNotification(message: "Timer fired in Background", wait: 3)
        //        _ = Timer(timeInterval: 150, repeats: false, block: {timer in NotificationManager.scheduleDebugNotification(message: "Timer fired in Background", wait: 0.5)})
        
        switch state {
        case .Connected, .Connecting, .Notifying:
            self.state = .DisconnectingDueToButtonPress  // to avoid reconnect in didDisconnetPeripheral
            centralManager.cancelPeripheralConnection(peripheral!)
            self.wantsToTerminate = true
        case .Scanning:
            self.state = .DisconnectingDueToButtonPress  // to avoid reconnect in didDisconnetPeripheral
             os_log("stopping scan", log: BubbleBluetoothManager.bt_log, type: .default)
            centralManager.stopScan()
            self.wantsToTerminate = true
            // at this point, the peripherial is not connected and therefore not available either
            //centralManager.cancelPeripheralConnection(peripheral!)
        default:
            break
        }
        //        if state == .Connected || peripheral?.state == .Connecting {
        //            centralManager.cancelPeripheralConnection(peripheral!)
        //        }
    }
    
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        os_log("Central Manager did update state to %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: central.state.rawValue))
        
        
        switch central.state {
        case .poweredOff, .resetting, .unauthorized, .unknown, .unsupported:
            os_log("Central Manager was either .poweredOff, .resetting, .unauthorized, .unknown, .unsupported: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: central.state))
            state = .Unassigned
        case .poweredOn:
            if state == .DisconnectingDueToButtonPress {
                os_log("Central Manager was powered on but sensorstate was DisconnectingDueToButtonPress:  %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: central.state))
            } else {
                os_log("Central Manager was powered on, scanningforBubble: state: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state))
                scanForBubble() // power was switched on, while app is running -> reconnect.
            }
            
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        os_log("Did discover peripheral while state %{public}@ with name: %{public}@, wantstoterminate?:  %d", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue), String(describing: peripheral.name), self.wantsToTerminate)
        if peripheral.name == deviceName {
            if let data = advertisementData["kCBAdvDataManufacturerData"] as? Data {
                var mac = ""
                for i in 0 ..< 6 {
                    mac += data.subdata(in: (7 - i)..<(8 - i)).hexEncodedString().uppercased()
                    if i != 5 {
                        mac += ":"
                    }
                }
                let bubblePeripheral = BubblePeripheral()
                bubblePeripheral.mac = mac
                bubblePeripheral.peripheral = peripheral
                delegate?.BubbleBluetoothManagerDidFound(peripheral: bubblePeripheral)
            }
            
//            self.peripheral = peripheral
//            connect()
            
//            if let data = advertisementData["kCBAdvDataManufacturerData"] as? Data {
//                var mac = ""
//                for i in 0 ..< 6 {
//                    mac += data.subdata(in: (7 - i)..<(8 - i)).hexEncodedString().uppercased()
//                    if i != 5 {
//                        mac += ":"
//                    }
//                }
//
//                if mac == "EB:12:CD:ED:7E:3B" {
//                    print("mac: \(mac)")
//                    self.peripheral = peripheral
//                    connect()
//                }
//            }
            
//            if let lastConnectedIdentifier = self.lastConnectedIdentifier {
//                if peripheral.identifier.uuidString == lastConnectedIdentifier {
//                    os_log("Did connect to previously known Bubble with identifier %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: peripheral.identifier))
//                    if let data = advertisementData["kCBAdvDataManufacturerData"] as? Data {
//                        var mac = ""
//                        for i in 0 ..< 6 {
//                            mac += data.subdata(in: (7 - i)..<(8 - i)).hexEncodedString().uppercased()
//                            if i != 5 {
//                                mac += ":"
//                            }
//                        }
//
//                        if mac == "EB:12:CD:ED:7E:3B" {
//                            self.peripheral = peripheral
//                            connect()
//                        }
//                    }
//                } else {
//                    os_log("Did not connect to miamiao with identifier %{public}@, because it did not match previously connected Bubble with identifer %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: peripheral.identifier.uuidString), lastConnectedIdentifier)
//                }
//
//            } else {
//                os_log("Did connect to Bubble with new identifier %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: peripheral.identifier))
//                self.peripheral = peripheral
//                connect()
//            }
            
        }
        
        /*
        if peripheral.name == deviceName {
            
            self.peripheral = peripheral
            connect()
        }*/
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        os_log("Did connect peripheral while state %{public}@ with name: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue), String(describing: peripheral.name))
        state = .Connected
        self.lastConnectedIdentifier = peripheral.identifier.uuidString
        // Discover all Services. This might be helpful if writing is needed some time
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        os_log("Did fail to connect peripheral while state: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: state.rawValue))
        if let error = error {
            os_log("Did fail to connect peripheral error: %{public}@", log: BubbleBluetoothManager.bt_log, type: .error ,  "\(error.localizedDescription)")
        }
        state = .Disconnected
        // attempt to avoid IOS killing app because of cpu usage.
        // postpone connecting for 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(30)) {
            self.connect()
        }
        
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
            //    scanForBubble()
        }
        // Keep this code in case you want it some later time: it is used for reconnection only in background mode
        //        state = .Disconnected
        //        // Start scanning, if disconnection occurred in background mode
        //        if UIApplication.sharedApplication().applicationState == .Background ||
        //            UIApplication.sharedApplication().applicationState == .Inactive {
        //            scanForBubble()
        //        }
    }
    
    
    // MARK: - CBPeripheralDelegate
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        os_log("Did discover services", log: BubbleBluetoothManager.bt_log, type: .default)
        if let error = error {
            os_log("Did discover services error: %{public}@", log: BubbleBluetoothManager.bt_log, type: .error ,  "\(error.localizedDescription)")
        }
        
        
        if let services = peripheral.services {
            
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
                
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
                //                print("Characteristic: ")
                //                debugPrint(characteristic.debugDescription)
                //                print("... with properties: ")
                //                debugPrint(characteristic.properties)
                //                print("Broadcast:                           ", [characteristic.properties.contains(.broadcast)])
                //                print("Read:                                ", [characteristic.properties.contains(.read)])
                //                print("WriteWithoutResponse:                ", [characteristic.properties.contains(.writeWithoutResponse)])
                //                print("Write:                               ", [characteristic.properties.contains(.write)])
                //                print("Notify:                              ", [characteristic.properties.contains(.notify)])
                //                print("Indicate:                            ", [characteristic.properties.contains(.indicate)])
                //                print("AuthenticatedSignedWrites:           ", [characteristic.properties.contains(.authenticatedSignedWrites )])
                //                print("ExtendedProperties:                  ", [characteristic.properties.contains(.extendedProperties)])
                //                print("NotifyEncryptionRequired:            ", [characteristic.properties.contains(.notifyEncryptionRequired)])
                //                print("BroaIndicateEncryptionRequireddcast: ", [characteristic.properties.contains(.indicateEncryptionRequired)])
                //                print("Serivce for Characteristic:          ", [characteristic.service.debugDescription])
                //
                //                if characteristic.service.uuid == CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E") {
                //                    print("\n B I N G O \n")
                //                }
                
                // Choose the notifiying characteristic and Register to be notified whenever the Bubble transmits
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
                    if firstByte == 128 {
                        let hardware = value[2].description + ".0"
                        let firmware = value[1].description + ".0"
                        let battery = Int(value[4])
                        bubble = Bubble(hardware: hardware,
                                            firmware: firmware,
                                            battery: battery)
                        
                        if let writeCharacteristic = writeCharacteristic {
                            print("-----set: ", writeCharacteristic)
                            peripheral.writeValue(Data([0x02, 0x00, 0x00, 0x00, 0x00, 0x2B]), for: writeCharacteristic, type: .withResponse)
                        }
                    }
                    
                    if firstByte == 191 {
                        delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0x34, payloadData: rxBuffer)
                        resetBuffer()
                    }
                    
                    if firstByte == 192 {
                        rxBuffer.append(value.subdata(in: 2..<10))
                    }
                    
                    if firstByte == 130 {
                        rxBuffer.append(value.suffix(from: 4))
                    }
                    if rxBuffer.count >= 352 {
                        handleCompleteMessage()
                        print("++++++++++first: ", rxBuffer.count)
                        resetBuffer()
                    }
                }
                
                
//                rxBuffer.append(value)
//                os_log("Appended value with length %{public}@, buffer length is: %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(describing: value.count), String(describing: rxBuffer.count))
//
//                if let firstByte = rxBuffer.first {
//                    BubbleResponseState = BubbleResponseState(rawValue: firstByte)
//                    if let BubbleResponseState = BubbleResponseState {
//                        switch BubbleResponseState {
//                        case .dataPacketReceived: // 0x28: // data received, append to buffer and inform delegate if end reached
//
//                            // Set timer to check if data is still uncomplete after a certain time frame
//                            // Any old buffer is invalidated and a new buffer created with every reception of data
//                            timer?.invalidate()
//                            timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { _ in
//                                os_log("********** BubbleManagertimer fired **********", log: BubbleBluetoothManager.bt_log, type: .default)
//                                if self.rxBuffer.count >= 364 {
//                                    // buffer large enough and can be used
//                                    os_log("Buffer incomplete but large enough, inform delegate.", log: BubbleBluetoothManager.bt_log, type: .default)
//                                    self.delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0x29, payloadData: self.rxBuffer)
//                                    self.handleCompleteMessage()
//
//                                    self.rxBuffer = Data()  // reset buffer, once completed and delegate is informed
//                                } else {
//                                    // buffer not large enough and has to be reset
//                                    os_log("Buffer incomplete and not large enough, reset buffer and request new data, again", log: BubbleBluetoothManager.bt_log, type: .default)
//                                    self.requestData()
//                                }
//                            }
//
//                            if rxBuffer.count >= 363 && rxBuffer.last! == 0x29 {
//                                os_log("Buffer complete, inform delegate.", log: BubbleBluetoothManager.bt_log, type: .default)
//                                delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0x28, payloadData: rxBuffer)
//                                handleCompleteMessage()
//                                rxBuffer = Data()  // reset buffer, once completed and delegate is informed
//                                timer?.invalidate()
//                            } else {
//                                // buffer not yet complete, inform delegate with txFlags 0x27 to display intermediate data
//                                //dabear-edit: don't notify on incomplete readouts
//                                //delegate?.BubbleManagerReceivedMessage(0x0000, txFlags: 0x27, payloadData: rxBuffer)
//                            }
//
//                            // if data is not complete after 10 seconds: use anyways, if long enough, do not use if not long enough and reset buffer in both cases.
//
//                        case .newSensor: // 0x32: // A new sensor has been detected -> acknowledge to use sensor and reset buffer
//                            delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0x32, payloadData: rxBuffer)
//                            if let writeCharacteristic = writeCharacteristic {
//                                peripheral.writeValue(Data.init(bytes: [0x00, 0x00, 0x05]), for: writeCharacteristic, type: .withResponse)
//                            }
//                            rxBuffer = Data()
//                        case .noSensor: // 0x34: // No sensor has been detected -> reset buffer (and wait for new data to arrive)
//                            delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0x34, payloadData: rxBuffer)
//                            rxBuffer = Data()
//                        case .frequencyChangedResponse: // 0xD1: // Success of fail for setting time intervall
//                            delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0xD1, payloadData: rxBuffer)
//                            if rxBuffer.count >= 2 {
//                                if rxBuffer[2] == 0x01 {
//                                    os_log("Success setting time interval.", log: BubbleBluetoothManager.bt_log, type: .default)
//                                } else if rxBuffer[2] == 0x00 {
//                                    os_log("Failure setting time interval.", log: BubbleBluetoothManager.bt_log, type: .default)
//                                } else {
//                                    os_log("Unkown response for setting time interval.", log: BubbleBluetoothManager.bt_log, type: .default)
//                                }
//                            }
//                            rxBuffer = Data()
//                            //                    default: // any other data (e.g. partial response ...)
//                            //                        delegate?.BubbleManagerReceivedMessage(0x0000, txFlags: 0x99, payloadData: rxBuffer)
//                            //                        rxBuffer = Data() // reset buffer, since no valid response
//                        }
//                    }
//                } else {
//                    // any other data (e.g. partial response ...)
//                    delegate?.BubbleBluetoothManagerReceivedMessage(0x0000, txFlags: 0x99, payloadData: rxBuffer)
//                    rxBuffer = Data() // reset buffer, since no valid response
//                }
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        os_log("Did Write value %{public}@ for characteristic %{public}@", log: BubbleBluetoothManager.bt_log, type: .default, String(characteristic.value.debugDescription), String(characteristic.debugDescription))
    }
    
    // Bubble specific commands
    
    // Confirm (to replace) the sensor. Iif a new sensor is detected and shall be used, send this command (0xD301)
    func confirmSensor() {
        if let writeCharacteristic = writeCharacteristic {
            peripheral?.writeValue(Data.init(bytes: [0xD3, 0x00]), for: writeCharacteristic, type: .withResponse)
        }
    }
    
    func requestData() {
        if let writeCharacteristic = writeCharacteristic {
//            confirmSensor()
            resetBuffer()
            timer?.invalidate()
            peripheral?.writeValue(Data.init(bytes: [0x00, 0x00, 0x05]), for: writeCharacteristic, type: .withResponse)
        }
    }
    
    
    func resetBuffer() {
        rxBuffer = Data()
    }
    
    func handleCompleteMessage() {
        guard rxBuffer.count >= 352 else {
            return
        }
//        #if DEBUG
//        data = "7e71401303000000000000000000000000000000000000006bcb04002d07c83459012d07c83059012a07c82459012707c83859016607c82059016e07c82859017007c82859016d07c84059016307c85459015707c84859015607c84859014c07c86459014407c87459013d07c87c59013b07c86459014507c84459011e06c8cc1b013406c8605a013706c8841a017805c8c0dc00b204c84cde001604c84ca000b503c844a1007303c8f062007603c8c861008c03c81ca100ee03c8c0dd00e404c8e05a011e06c8345a013c07880e1b01ce07c8785a019b07c8581a01d107c8f01901f907c8c45901de07c8705901de07c8f49801c507c8185901a807c8105901fb07c8385901f508c81499015c09c86c98015309c86498013809c88c9801e008c8c458015708c8f09801b707c8f498015807c8f898013707c84459014529000044d100015108f550140796805a00eda6187b1ac804c25869".hexadecimal ?? Data()
//        data = data.subdata(in: 0..<344)
//        #endif
        let data = rxBuffer.subdata(in: 8..<352)
        sensorData = SensorData(uuid: rxBuffer.subdata(in: 0..<8), bytes: [UInt8](data), date: Date(), derivedAlgorithmParameterSet: nil)
        
        // Set notifications
//        NotificationManager.scheduleApplicationTerminatedNotification(wait: 500)
//        NotificationManager.scheduleDataTransferInterruptedNotification(wait: 400)
//
//        if Bubble.battery < 20 {
//            NotificationManager.setLowBatteryNotification(voltage: Double(Bubble.battery))
//        }
        
        // Check if sensor data is valid and, if this is not the case, request data again after thirty second
        if let sensorData = sensorData {
            if !(sensorData.hasValidHeaderCRC && sensorData.hasValidBodyCRC && sensorData.hasValidFooterCRC) {
                Timer.scheduledTimer(withTimeInterval: 30, repeats: false, block: {_ in
                    self.requestData()
                })
            }
            // Inform delegate that new data is available
            delegate?.BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: sensorData, Bubble: bubble!)
        }
        
        
    }
    
    deinit {
        self.delegate = nil
        os_log("dabear:: Bubblemanager deinit called")
        
        
    }
    
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
