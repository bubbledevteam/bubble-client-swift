//
//  NFCManager.swift
//  DiaBox
//
//  Created by Yan Hu on 2020/5/9.
//  Copyright © 2020 DiaBox. All rights reserved.
//

import UIKit
import CoreNFC

public class NFCManager: NSObject, NFCReceive {
    var patchUid: String?
    var patchInfo: String?
    
    var delegate: BubbleBluetoothManagerDelegate?
    
    static var isAvailable: Bool {
        return NFCTagReaderSession.readingAvailable
    }
    
    #if canImport(Combine)
    let manager = BaseNFCManager(unlockCode: 0xA4, password: "c2ad7521".hexadecimal)
    var cancellable: AnyCancellable?
    #endif
    
    public func action(request: ActionRequest) {
        #if canImport(Combine)
        manager.delegate = self
        cancellable = manager.perform(request)
            .receive(on: DispatchQueue.main)
            .sink { (string) in
                print("??????????: \(string)")
        }
        #endif
    }
    
    public func handleLibre2CalibrationInfo(data: Data) {
        LogsAccessor.log("handleLibre2CalibrationInfo receive 344")
        LogsAccessor.log(data.hexEncodedString())
        if let uid = patchUid?.hexadecimal?.bytes,
           let info = patchInfo?.hexadecimal?.bytes {
            let data = Data(PreLibre2.decryptFRAM(uid, info, data.bytes))
            LogsAccessor.log("libre2Data: \(data.hexEncodedString())")
            let calibrationInfo = Libre2.calibrationInfo(fram: data)
            UserDefaultsUnit.calibrationInfo = calibrationInfo
            LogsAccessor.log("calibrationInfo: \(calibrationInfo)")
        }
        handleLibre2Data(data: data)
    }
    
    private func handleLibre2Data(data: Data) {
        UserDefaultsUnit.libre2Nfc344OriginalData = data.hexEncodedString()
        guard let uid = UserDefaultsUnit.patchUid?.hexadecimal,
              let info = UserDefaultsUnit.patchInfo else {
            return
        }
        LogsAccessor.log( "start network")
        
        let sensorData = SensorData(bytes: [UInt8](data), sn: UserDefaultsUnit.sensorSerialNumber ?? "", patchUid: Data(uid.reversed()).hexEncodedString(), patchInfo: info)
        let bubble = Bubble(hardware: "1.0", firmware: "1.0", battery: 100)
        delegate?.BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: sensorData, Bubble: bubble)
        delegate?.BubbleBluetoothManagerLibre2Rescan()
    }
    
    public func set(sn value: Data, patchInfo: String) {
        DispatchQueue.main.async {
            self.patchInfo = patchInfo
            UserDefaultsUnit.patchInfo = patchInfo
            
            let reversed = Data(value.reversed())
            self.patchUid = reversed.hexEncodedString().uppercased()
            UserDefaultsUnit.patchUid = self.patchUid
            
            LogsAccessor.log("patchInfo: \(patchInfo), patchUid: \(self.patchUid ?? "")")
            
            if let sensorSerialNumber = SensorSerialNumber(withUID: reversed, patchInfo: patchInfo) {
                UserDefaultsUnit.sensorSerialNumber = sensorSerialNumber.serialNumber
            }
        }
    }
}

public protocol NFCReceive {
    func handleLibre2CalibrationInfo(data: Data)
    func set(sn value: Data, patchInfo: String)
}

#if canImport(Combine)
import Combine

enum NFCManagerError: Error, LocalizedError {
    case unsupportedSensorType
    case missingUnlockParameters
    case failed
    case canNotRestart

    var errorDescription: String? {
        switch self {
        case .unsupportedSensorType:
            return "Sensor Unsupported"
        case .missingUnlockParameters:
            return "Missing Unlock Parameters"
        case .failed:
            return "Failed"
            
        case .canNotRestart:
            return ""
        }
    }
}


protocol NFCManager1 {
    @available(iOS 13.0, *)
    func perform(_ request: ActionRequest) -> AnyPublisher<String, Never>
    func setCredentials(unlockCode: Int, password: Data)
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
final class BaseNFCManager: NSObject, NFCManager1 {
    enum Config {
//        static let numberOfFRAMBlocks = 0xF4
        static let numberOfFRAMBlocks = 0x2B // 43
    }

    private var session: NFCTagReaderSession?

    private let nfcQueue = DispatchQueue(label: "NFCManager.nfcQueue")
    private let accessQueue = DispatchQueue(label: "NFCManager.accessQueue")

    private var sessionToken: AnyCancellable?

    private var actionRequest: ActionRequest? {
        didSet {
            guard actionRequest != nil else { return }
            startSession()
        }
    }

    @Published private var sessionLog = ""

    private var unlockCode: Int?
    private var password: Data?
    var delegate: NFCReceive?

    func perform(_ request: ActionRequest) -> AnyPublisher<String, Never> {
        sessionLog = ""
        LogsAccessor.log("Start processing...")
        actionRequest = request
        return $sessionLog.eraseToAnyPublisher()
    }

    func setCredentials(unlockCode: Int, password: Data) {
        self.unlockCode = unlockCode
        self.password = password
    }

    init(unlockCode: Int? = nil, password: Data? = nil) {
        self.unlockCode = unlockCode
        self.password = password
    }

    private func startSession() {
        guard NFCReaderSession.readingAvailable, actionRequest != nil else {
            sessionLog = "You phone is not supporting NFC"
            actionRequest = nil
            return
        }

        accessQueue.async {
            self.session = NFCTagReaderSession(pollingOption: .iso15693, delegate: self, queue: self.nfcQueue)
            self.session?.alertMessage = "Hold your iPhone near the item to learn more about it."
            self.session?.begin()
        }
    }

    private func processTag(_ tag: NFCISO15693Tag) {
        dispatchPrecondition(condition: .onQueue(accessQueue))

        guard let actionRequest = actionRequest else {
            session?.invalidate()
            return
        }

        LogsAccessor.log("Tag connected")
        LogsAccessor.log("Sn: \(tag.identifier.hexEncodedString())")
        let snData = tag.identifier
        sessionToken = tag.getPatchInfo()
            .flatMap { data -> AnyPublisher<Data, Error> in
                let patchInfo = data.hexEncodedString().uppercased()
                let sensorType = SensorType(patchInfo: patchInfo)
                let region = SensorRegion(rawValue: [UInt8](data)[3]) ?? .unknown
                LogsAccessor.log("Patch Info: " + patchInfo)
                LogsAccessor.log("Type: " + sensorType.displayType)
                LogsAccessor.log("Region: \(region)")
                DispatchQueue.main.async {
                    self.delegate?.set(sn: snData, patchInfo: patchInfo)
                }
                switch actionRequest {
                case .readLibre2CalibrationInfo:
                    if sensorType != .libre2 {
                        return Fail(error: NFCManagerError.unsupportedSensorType).eraseToAnyPublisher()
                    }
                    return tag.readFRAM(blocksCount: BaseNFCManager.Config.numberOfFRAMBlocks)
//                        .flatMap { data1 -> AnyPublisher<Data, Error> in
//                            if data1.count >= 344 {
//                                DispatchQueue.main.async {
//                                    self.delegate?.handleLibre2CalibrationInfo(data: data1[0..<344])
//                                }
//                            }
//                            return tag.enableStreamingPayload(info: data, uid: Data(snData.reversed()))
//                        }
//                        .eraseToAnyPublisher()
                case .readState:
                    return tag.readFRAM(blocksCount: 1)
                }
            }
            .receive(on: accessQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        LogsAccessor.log("Completed")
                        self.session?.invalidate()
                    case let .failure(error):
                        LogsAccessor.log("Error: \(error.localizedDescription)")
                        self.session?.invalidate(errorMessage: error.localizedDescription)
                    }
                },
                receiveValue: {
                    self.processResult(with: $0)
                }
            )
    }


    private func processResult(with data: Data) {
        dispatchPrecondition(condition: .onQueue(accessQueue))
        
        let bytes = [UInt8](data)
        switch actionRequest {
        case .readLibre2CalibrationInfo:
            if data.count >= 344 {
                DispatchQueue.main.async {
                    self.delegate?.handleLibre2CalibrationInfo(data: data[0..<344])
                }
            }
            break
        case .readState:
            let state = LibreSensorState(stateByte: bytes[4])
            LogsAccessor.log("Sensor state: \(state) (\(state.description))")
        default: break
        }
        actionRequest = nil
    }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension BaseNFCManager: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        LogsAccessor.log("Started scanning for tags")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let error = error as NSError
        if error.code != 200 {
            LogsAccessor.log("Session did invalidate with error: \(error)")
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        if let tag = tags.first {
            switch tag {
            case let .iso15693(libreTag):
                print("Tag found")
                session.connect(to: tag) { _ in
                    self.accessQueue.async {
                        self.processTag(libreTag)
                    }
                }
            default: break
            }
        }
    }
}


@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
private extension NFCISO15693Tag {
    func runCommand(_ cmd: CustomCommand, parameters: Data = Data()) -> AnyPublisher<Data, Error> {
        Future { [weak self] promise in
            self?.customCommand(requestFlags: .highDataRate, customCommandCode: cmd.code, customRequestParameters: parameters) { [weak self] data, error in
                if self != nil {
                    guard error == nil else {
                        promise(.failure(error!))
                        return
                    }
                    promise(.success(data))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func enableStreamingPayload(info: Data, uid: Data) -> AnyPublisher<Data, Error> {
        let payload = Data(Libre2.getEnableStreamingPayload(id: uid, info: info))
        LogsAccessor.log("uid:\(uid.hexEncodedString()), info: \(info.hexEncodedString()), payload: \(payload.hexEncodedString())")
        return runCommand(.getPatchInfo, parameters: payload)
    }

    func readBlock(number: UInt8) -> AnyPublisher<Data, Error> {
        Future { promise in
            self.readSingleBlock(requestFlags: .highDataRate, blockNumber: number) { data, error in
                guard error == nil else {
                    promise(.failure(error!))
                    return
                }
                promise(.success(data))
            }
        }.eraseToAnyPublisher()
    }

    func readFRAM(blocksCount: Int) -> AnyPublisher<Data, Error> {
        LogsAccessor.log("readFRAM")
        return Publishers.Sequence(sequence: (UInt8(0) ..< UInt8(blocksCount))
                                .map { self.readBlock(number: $0) })
            .flatMap { $0 }
            .collect()
            .map { $0.reduce(Data(), +) }
            .eraseToAnyPublisher()
    }

    func getPatchInfo() -> AnyPublisher<Data, Error> {
        runCommand(.getPatchInfo)
    }

    func writeBlock(number: UInt8, data: Data) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            self.writeSingleBlock(
                requestFlags: .highDataRate,
                blockNumber: number,
                dataBlock: data
            ) { promise( $0.map { Result.failure($0) } ?? .success(())) }
        }.eraseToAnyPublisher()
    }

    func unlock(_ code: Int, password: Data) -> AnyPublisher<Void, Error> {
        LogsAccessor.log("unlock")
        return runCommand(.init(code: code), parameters: password).asEmpty()
    }

    func lock(password: Data) -> AnyPublisher<Void, Error> {
        LogsAccessor.log("lock")
        return runCommand(.lock, parameters: password).asEmpty()
    }
}

struct CustomCommand {
    let code: Int

    static let activate = CustomCommand(code: 0xA0)
    static let getPatchInfo = CustomCommand(code: 0xA1)
    static let lock = CustomCommand(code: 0xA2)
    static let rawRead = CustomCommand(code: 0xA3)
    static let libre2Universal = CustomCommand(code: 0xA1)
    static let libreProHistory = CustomCommand(code: 0xB3)
}

extension Data {
    var dumpString: String {
        var result = ""

        let bytes = [UInt8](self)

        for number in 0 ..< bytes.count / 8 {
            guard number * 8 < bytes.count else { break }

            let data = Data(bytes[number * 8 ..< number * 8 + 8])

            result += "\(String(format: "%02X", 0xF860 + number * 8)) \(String(format: "%02X", number)): \(data.hexEncodedString())\n"
        }

        return result
    }
}


protocol OptionalType {
    associatedtype Wrapped

    var optional: Wrapped? { get }
}

extension Optional: OptionalType {
    public var optional: Wrapped? { self }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension Publisher where Output: OptionalType {
    func ignoreNil() -> AnyPublisher<Output.Wrapped, Failure> {
        flatMap { output -> AnyPublisher<Output.Wrapped, Failure> in
            guard let output = output.optional else {
                return Empty<Output.Wrapped, Failure>(completeImmediately: false).eraseToAnyPublisher()
            }
            return Just(output).setFailureType(to: Failure.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension Publisher {
    func asEmpty() -> AnyPublisher<Void, Failure> {
        map { _ in () }.eraseToAnyPublisher()
    }

    func get(_ output: @escaping (Output) -> Void) -> AnyPublisher<Output, Failure> {
        map { value -> Output in
            output(value)
            return value
        }.eraseToAnyPublisher()
    }
}

#endif

public enum ActionRequest {
    case readState
    case readLibre2CalibrationInfo
}

enum SensorRegion: UInt8 {
    case europe = 0x01
    case usa = 0x02
    case newZeland = 0x04
    case asia = 0x08
    case unknown = 0x00
}

extension SensorRegion {
    static let selectCases: [SensorRegion] = [.europe, .usa, .newZeland, .asia]
}

extension SensorRegion: CustomStringConvertible {
    var description: String {
        switch self {
        case .europe:
            return "01 - Europe"
        case .usa:
            return "02 - US"
        case .newZeland:
            return "04 - New Zeland"
        case .asia:
            return "08 - Asia and world wide"
        case .unknown:
            return "Unknown"
        }
    }
}

extension SensorRegion: Identifiable {
    var id: UInt8 { rawValue }
}

enum SensorType: String, Codable {
    case libre1
    case libre1new
    case libreUS14day
    case libre2
    case libreProH
    case unknown

    init(patchInfo: String) {
        switch patchInfo.prefix(6) {
        case "DF0000": self = .libre1
        case "A20800": self = .libre1new
        case "E50003": self = .libreUS14day
        case "9D0830": self = .libre2
        case "700010": self = .libreProH
        default: self = .unknown
        }
    }

    var displayType: String {
        switch self {
        case .libre1: return "Libre 1"
        case .libre1new: return "Libre 1"
        case .libreUS14day: return "Libre US 14 Days"
        case .libre2: return "Libre 2"
        case .libreProH: return "Libre Pro/H"
        default: return "unknown"
        }
    }

    var isWritable: Bool {
        switch self {
        case .libre1, .libre1new: return true
        default: return false
        }
    }
    
    var isFirstSensor: Bool {
        switch self {
        case .libre1, .libre1new: return true
        default: return false
        }
    }
    
    var isSecondSensor: Bool {
        switch self {
        case .libre2, .libreUS14day: return true
        default: return false
        }
    }
    
    var isProSensor: Bool {
        switch self {
        case .libreProH: return true
        default: return false
        }
    }

    var crcBlockModified: Data {
        switch self {
        case .libre1: return Data([UInt8]([0x01, 0x6E, 0x21, 0x83, 0xF2, 0x90, 0x07, 0x00]))
        case .libre1new: return Data([UInt8]([0x31, 0xD5, 0x21, 0x83, 0xF2, 0x90, 0x07, 0x00]))
        default: fatalError("Unsuppotred sensor type")
        }
    }

    var crcBlockOriginal: Data {
        switch self {
        case .libre1: return Data([UInt8]([0x9E, 0x42, 0x21, 0x83, 0xF2, 0x90, 0x07, 0x00]))
        case .libre1new: return Data([UInt8]([0xAE, 0xF9 , 0x21, 0x83, 0xF2, 0x90, 0x07, 0x00]))
        default: fatalError("Unsuppotred sensor type")
        }
    }

    var commandBlockModified: Data {
        Data([UInt8]([0xA3, 0x00, 0x56, 0x5A, 0xA2, 0x00, 0xAE, 0xFB]))
    }

    var commandBlockOriginal: Data {
        Data([UInt8]([0xA3, 0x00, 0x56, 0x5A, 0xA2, 0x00, 0xBA, 0xF9]))
    }

    var crcBlockNumber: UInt8 { 0x2B }

    var commandBlockNumber: UInt8 { 0xEC }
}
