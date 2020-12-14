//
//  NFCManager.swift
//  DiaBox
//
//  Created by Yan Hu on 2020/5/9.
//  Copyright © 2020 DiaBox. All rights reserved.
//

import UIKit
import CoreNFC

class NFCManager: NSObject, NFCReceive {
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
    
//    init() {
//        super.init()
//    }
    
    func action(request: ActionRequest) {
        #if canImport(Combine)
        manager.delegate = self
        cancellable = manager.perform(request)
            .receive(on: DispatchQueue.main)
            .sink { (string) in
                print("??????????: \(string)")
        }
        #endif
    }
    
    func handleLibre2CalibrationInfo(data: Data) {
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
        guard patchUid != nil, patchInfo != nil else { return }
        UserDefaultsUnit.libre2Nfc344OriginalData = data.hexEncodedString()
        LogsAccessor.log( "start network")
        
        if var sensorData = SensorData(uuid: data.subdata(in: 0..<8), bytes: [UInt8](data), date: Date(), patchInfo: UserDefaultsUnit.patchInfo) {
            let bubble = Bubble(hardware: "1.0", firmware: "1.0", battery: 100)
            sensorData.isDecryptedDataPacket = true
            delegate?.BubbleBluetoothManagerDidUpdateSensorAndBubble(sensorData: sensorData, Bubble: bubble)
            delegate?.BubbleBluetoothManagerLibre2Rescan()
        }
    }
    
    func set(sn value: Data, patchInfo: String) {
        self.patchInfo = patchInfo
        UserDefaultsUnit.patchInfo = patchInfo
        
        let uid = value.hexEncodedString().uppercased()
        UserDefaultsUnit.patchUid = uid
        UserDefaultsUnit.unlockCount = 1
        
        LogsAccessor.log( "patchInfo: \(patchInfo), patchUid: \(uid)")
        
        let reversed = Data(value.reversed())
        patchUid = reversed.hexEncodedString().uppercased()
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
                        .flatMap { data1 -> AnyPublisher<Data, Error> in
                            if data1.count >= 344 {
                                DispatchQueue.main.async {
                                    self.delegate?.handleLibre2CalibrationInfo(data: data1[0..<344])
                                }
                            }
                            return tag.enableStreamingPayload(info: data, uid: Data(snData.reversed()))
                        }
                        .eraseToAnyPublisher()
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

enum ActionRequest {
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


open class Libre2 {
    
    public static func op(_ value: UInt16, _ l1: UInt16, _ l2: UInt16) -> UInt16 {
        var res = value >> 2 // Result does not include these last 2 bits
        if ((value & 1) == 1) {
            res ^= l2
        }
        
        if ((value & 2) == 2) {// If second last bit is 1
            res ^= l1
        }
        return res
    }
    
    static var l1: UInt16 = 0xa0c5
    static var l2: UInt16 = 0x6860
    static var l3: UInt16 = 0x0000
    static var l4: UInt16 = 0x14c6
    
    public static func processCrypto(_ s1: UInt16, _ s2: UInt16, _ s3: UInt16, _ s4: UInt16) -> [UInt16] {
        let r0 = op(s1, l1, l2) ^ s4
        let r1 = op(r0, l1, l2) ^ s3
        let r2 = op(r1, l1, l2) ^ s2
        let r3 = op(r2, l1, l2) ^ s1
        let r4 = op(r3, l1, l2)
        let r5 = op(r4 ^ r0, l1, l2)
        let r6 = op(r5 ^ r1, l1, l2)
        let r7 = op(r6 ^ r2, l1, l2)
        let f1 = ((r0 ^ r4))
        let f2 = ((r1 ^ r5))
        let f3 = ((r2 ^ r6))
        let f4 = ((r3 ^ r7))
        
        return [f4, f3, f2, f1]
    }
    
    static func Word(_ high: UInt8, _ low: UInt8) -> UInt16 {
        return UInt16(high) << 8 + UInt16(low)
    }

    static func prepareVariables2(id: Data, i1: UInt16, i2: UInt16, i3: UInt16, i4: UInt16)  -> [UInt16] {
        let s1 = UInt16((UInt32(Word(id[5], id[4])) + UInt32(i1)) & 0xffff)
        let s2 = UInt16((UInt32(Word(id[3], id[2])) + UInt32(i2)) & 0xffff)
        let s3 = UInt16((UInt32(Word(id[1], id[0])) + UInt32(i3) + UInt32(l3)) & 0xffff)
        let s4 = UInt16((UInt32(i4) + UInt32(l4)) & 0xffff)
        return [s1, s2, s3, s4]
    }
    
    public static func usefulFunction(_ SensorId: Data, _ x: UInt16, _ y: UInt16) -> [UInt8] {
        let skey = prepareVariables(SensorId, x, y)
        let value = processCrypto(skey[0], skey[1], skey[2], skey[3])
        let low = value[0]
        let high = value[1]
        
        var res = (UInt32(high & 0xffff) << 16) + UInt32(low & 0xffff) // combine two words
        res ^= 0x43444163 // xor result at the end

        return [UInt8(res & 0xff),
                UInt8((res >> 8) & 0xff),
                UInt8((res >> 16) & 0xff),
                UInt8((res >> 24) & 0xff)]
    }
    
//    public static int[] prepareVariables(byte[] sensorId, int x, int y) {
//        int s1 = ((Word(sensorId[5], sensorId[4]) + x + y) & 0xffff);
//        int s2 = ((Word(sensorId[3], sensorId[2]) + l3) & 0xffff);
//        int s3 = ((Word(sensorId[1], sensorId[0]) + x * 2) & 0xffff);
//        int s4 = ((0x241a ^ l4) & 0xffff);
//
//        return new int[]{
//                s1, s2, s3, s4
//        };
//    }
    
    public static func prepareVariables(_ sensorId: Data, _ x: UInt16, _ y: UInt16) -> [UInt16] {
        let s1 = ((UInt32(Word(sensorId[5], sensorId[4])) + UInt32(x) + UInt32(y)) & 0xffff)
        let s2 = ((UInt32(Word(sensorId[3], sensorId[2])) + UInt32(l3)) & 0xffff)
        let s3 = ((UInt32(Word(sensorId[1], sensorId[0])) + UInt32(x) * 2) & 0xffff)
        let s4 = ((0x241a ^ UInt32(l4)) & 0xffff)

        return [UInt16(s1), UInt16(s2), UInt16(s3), UInt16(s4)]
    }
    
    static func getEnableStreamingPayload(id: Data, info: Data, unlockCode: UInt32 = 42) -> [UInt8] {
        let b: [UInt8] = [
            UInt8(unlockCode & 0xFF),
            UInt8((unlockCode >> 8) & 0xFF),
            UInt8((unlockCode >> 16) & 0xFF),
            UInt8((unlockCode >> 24) & 0xFF)
        ]

        let d = usefulFunction(id, 0x1e, Word(info[5], info[4]) ^ Word(b[1], b[0]))
        return [0x1e, b[0], b[1], b[2], b[3], d[0], d[1], d[2], d[3]]
    }

    static func streamingUnlockPayload(id: Data, info: Data, enableTime: UInt32, unlockCount: UInt16) -> [UInt8] {

        // First 4 bytes are just int32 of timestamp + unlockCount
        let time = enableTime + UInt32(unlockCount)
        let b: [UInt8] = [
            UInt8(time & 0xFF),
            UInt8((time >> 8) & 0xFF),
            UInt8((time >> 16) & 0xFF),
            UInt8((time >> 24) & 0xFF)
        ]

        // Then we need data of activation command and enable command that were send to sensor
        let ad = usefulFunction(id, 0x1b, 0x1b6a)
        let ed = usefulFunction(id, 0x1e, UInt16(enableTime & 0xffff) ^ Word(info[5], info[4]))

        let t11 = (Word(ed[1], ed[0]) ^ Word(b[3], b[2]))
        let t12 = Word(ad[1], ad[0])
        let t13 = (Word(ed[3], ed[2]) ^ Word(b[1], b[0]))
        let t14 = Word(ad[3], ad[2])

        var key1 = prepareVariables2(id: id, i1: t11, i2: t12, i3: t13, i4: t14)
        var initialKey = processCrypto(key1[0], key1[1], key1[2], key1[3])

        let t21 = initialKey[0];
        let t22 = initialKey[1];
        let t23 = initialKey[2];
        let t24 = initialKey[3];
        // TODO extract if secret
        let d1 = [0xc1, 0xc4, 0xc3, 0xc0, 0xd4, 0xe1, 0xe7, 0xba, WordByte(t21, 0), WordByte(t21, 1)]
        let d2 = [WordByte(t22, 0), WordByte(t22, 1), WordByte(t23, 0), WordByte(t23, 1), WordByte(t24, 0), WordByte(t24, 1)]
        let d3 = [ad[0], ad[1], ad[2], ad[3], ed[0], ed[1]]
        let d4 = [ed[2], ed[3], b[0], b[1], b[2], b[3]]
        let t31 = crc16(Data(d1))
        let t32 = crc16(Data(d2))
        let t33 = crc16(Data(d3))
        let t34 = crc16(Data(d4))
        key1 = prepareVariables2(id: id, i1: t31, i2: t32, i3: t33, i4: t34)
        initialKey = processCrypto(key1[0], key1[1], key1[2], key1[3])

        let res = [
            UInt8(initialKey[0] & 0xFF),
            UInt8((initialKey[0] >> 8) & 0xFF),
            UInt8(initialKey[1] & 0xFF),
            UInt8((initialKey[1] >> 8) & 0xFF),
            UInt8(initialKey[2] & 0xFF),
            UInt8((initialKey[2] >> 8) & 0xFF),
            UInt8(initialKey[3] & 0xFF),
            UInt8((initialKey[3] >> 8) & 0xFF)
        ]

        return [b[0], b[1], b[2], b[3], res[0], res[1], res[2], res[3], res[4], res[5], res[6], res[7]]
    }
    
    public static func WordByte(_ d: UInt16, _ index: UInt16) -> UInt8 {
        return UInt8((d >> (8 * index)) & 0xff)
    }
    
    static func crc16(_ data: Data) -> UInt16 {
        var crc: UInt64 = 0xffff
        let polynomial: UInt64 = 0x1021

        for b in [UInt8](data) {
            for bitNum: UInt64 in 0 ... 7 {
                let bit = (UInt64(b) >> bitNum & 1)
                let c15 = (crc >> 15 & 1)
                crc <<= 1
                if ((c15 ^ bit) != 0) {
                    crc ^= polynomial
                }
            }
        }
        return UInt16((crc & 0xffff))
    }
    
//    public static int readBits(byte[] buffer, int byteOffset,
//                               int bitOffset, int bitCount) {
//        if (bitCount == 0) {
//            return 0;
//        }
//        int res = 0;
////        System.out.println("byteOffset==" + byteOffset + "===" + bitOffset + "===" + bitCount);
//        for (int i = 0; i < bitCount; i++) {
//            int totalBitOffset = byteOffset * 8 + bitOffset + i;
//
//            double byte1 = Math.floor(totalBitOffset / 8);
//            int bit = totalBitOffset % 8;
//            if (totalBitOffset >= 0 && ((buffer[(int) byte1] >> bit) & 0x1) == 1) {
//                res = res | (1 << i);
//            }
//        }
//        return res;
//    }
    
    static func readBits(_ buffer: Data, _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int) -> Int {
        guard bitCount != 0 else {
            return 0
        }
        var res = 0
        for i in 0 ..< bitCount {
            let totalBitOffset = byteOffset * 8 + bitOffset + i
            let byte = Int(floor(Float(totalBitOffset) / 8))
            let bit = totalBitOffset % 8
            if totalBitOffset >= 0 && ((Int(buffer[byte]) >> bit) & 0x1) == 1 {
                res = res | (1 << i)
            }
        }
        return res
    }

    static func writeBits(_ buffer: Data, _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int, _ value: Int) -> Data {
        var res = buffer
        for i in 0 ..< bitCount {
            let totalBitOffset = byteOffset * 8 + bitOffset + i
            let byte = Int(floor(Double(totalBitOffset) / 8))
            let bit = totalBitOffset % 8
            let bitValue = (value >> i) & 0x1
            res[byte] = (res[byte] & ~(1 << bit) | (UInt8(bitValue) << bit))
        }
        return res
    }
    
    static func calibrationInfo(fram: Data) -> CalibrationInfo {
        let i1 = readBits(fram, 2, 0, 3)
        let i2 = readBits(fram, 2, 3, 0xa)
        let i3 = readBits(fram, 0x150, 0, 8)
        let i4 = readBits(fram, 0x150, 8, 0xe)
        let negativei3 = readBits(fram, 0x150, 0x21, 1) != 0
        let i5 = readBits(fram, 0x150, 0x28, 0xc) << 2
        let i6 = readBits(fram, 0x150, 0x34, 0xc) << 2

        return CalibrationInfo(i1: i1, i2: i2, i3: negativei3 ? -i3 : i3, i4: i4, i5: i5, i6: i6)
    }
    
    /// Decrypts Libre 2 BLE payload
    /// - Parameters:
    ///   - id: ID/Serial of the sensor. Could be retrieved from NFC as uid.
    ///   - data: Encrypted BLE data
    /// - Returns: Decrypted BLE data
    static func decryptBLE(id: Data, data: Data) throws -> [UInt8] {
        let d = usefulFunction(id, 0x1b, 0x1b6a)
        let x = ((Word(d[1], d[0]) ^ Word(d[3], d[2])) | 0x63)
        let y = Word(data[1], data[0]) ^ 0x63

        var key = [UInt8]()
        
        let key2 = prepareVariables(id, x, y)
        var initialKey = processCrypto(key2[0], key2[1], key2[2], key2[3])

        for _ in 0 ..< 8 {
            key.append(UInt8(initialKey[0] & 0xff))
            key.append(UInt8(initialKey[0] >> 8) & 0xff)
            key.append(UInt8(initialKey[1] & 0xff))
            key.append(UInt8(initialKey[1] >> 8) & 0xff)
            key.append(UInt8(initialKey[2] & 0xff))
            key.append(UInt8(initialKey[2] >> 8) & 0xff)
            key.append(UInt8(initialKey[3] & 0xff))
            key.append(UInt8(initialKey[3] >> 8) & 0xff)
            initialKey = processCrypto(initialKey[0], initialKey[1], initialKey[2], initialKey[3])
        }

        let result = data[2...].enumerated().map { i, value in
            value ^ key[i]
        }

        guard crc16(Data(result.prefix(42))) == Word(result[43], result[42]) else {
            struct DecryptBLEError: Error, LocalizedError {
                let errorDescription: String
            }
            
            throw DecryptBLEError(errorDescription: "BLE data decrytion failed: crc: \(crc16(Data(result.prefix(42)))), word: \(Word(result[43], result[42]))")
        }

        return result
    }
    
    static func glucoseValueFromRaw(raw: GlucoseData, calibrationInfo: CalibrationInfo) -> GlucoseData {
        let x: Double = 1000 + 71500
        let y: Double = 1000

        let ca = 0.0009180023
        let cb = 0.0001964561
        let cc = 0.0000007061775
        let cd = 0.00000005283566

        var R = Double(raw.rawTemperature ?? 0) * x
        R /= Double(raw.temperatureAdjustment ?? 0) + Double(calibrationInfo.i6)
        R -= y
        let logR = log(R)
        let d = pow(logR, 3) * cd + pow(logR, 2) * cc + logR * cb + ca
        let temperature = 1 / d - 273.15

        let g1 = 65 * Double(raw.rawGlucose! - calibrationInfo.i3) / Double(calibrationInfo.i4 - calibrationInfo.i3)
        let g2 = pow(1.045, 32.5 - temperature)
        let g3 = g1 * g2

        let v1 = t1[calibrationInfo.i2 - 1]
        let v2 = t2[calibrationInfo.i2 - 1]
        let value = round((g3 - v1) / v2)
        
        raw.glucoseLevelRaw = value
        raw.originValue = value
        return raw
    }
    
    static func parseBLEData( _ data: Data, info: CalibrationInfo) -> [GlucoseData] {
        
        var bleGlucose: [GlucoseData] = []
        let wearTimeMinutes = Int(UInt16(data[40...41].first!))
        let crc = Word(data[43], data[42])
        LogsAccessor.log("wearTimeMinutes: \(wearTimeMinutes), crc: \(crc)")
        let delay = 2
        let ints = [0, 2, 4, 6, 7, 12, 15]
        var historyCount = 0
        for i in 0 ..< 10 {
            var temperatureAdjustment = readBits(data, i * 4, 0x1a, 0x5) << 2
            let negativeAdjustment = readBits(data, i * 4, 0x1f, 0x1)
            
            let value = Double(readBits(data, i * 4, 0, 0xe))
            let temperature = readBits(data, i * 4, 0xe, 0xc) << 2
            if negativeAdjustment != 0 {
                temperatureAdjustment = -temperatureAdjustment
            }
            
            if value == 0 {
                continue
            }
            
            var idValue = wearTimeMinutes
            
            if i < 7 {
                idValue -= ints[i]
            } else {
                historyCount += 1
                idValue = ((idValue - delay) / 15) * 15 - 15 * (i - 7)
            }

            let date = Date().addingTimeInterval(TimeInterval(-60 * (wearTimeMinutes - idValue)))
            let glucose = GlucoseData(timeStamp: date, glucoseLevelRaw: 0)
            glucose.rawGlucose = Int(value)
            glucose.rawTemperature = temperature
            glucose.temperatureAdjustment = temperatureAdjustment
            
            _ = glucoseValueFromRaw(raw: glucose, calibrationInfo: info)
            LogsAccessor.log("i:\(i) id:\(idValue) raw: \(glucose.glucoseLevelRaw), rawGlucose: \(glucose.rawGlucose ?? 0), rawTemperature: \(temperature)")
            bleGlucose.append(glucose)
        }
        
        if let current = bleGlucose.first {
            let count = bleGlucose.count
            var histories = [GlucoseData]()
            for i in (count - historyCount) ..< count {
                histories.append(bleGlucose[i])
            }
            bleGlucose = LibreOOPClient.split(current: current, glucoseData: histories.reversed())
            bleGlucose.first?.histories = histories
        }
        
        return bleGlucose
    }
    
    static let t1 = [
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
        1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3,
    ]

    static let t2 = [
        0.037744199999999999, 0.037744199999999999, 0.037744199999999999, 0.037744199999999999, 0.037744199999999999, 0.037744199999999999, 0.037744199999999999, 0.037744199999999999,
        0.038121700000000001, 0.038121700000000001, 0.038121700000000001, 0.038121700000000001, 0.038121700000000001, 0.038121700000000001, 0.038121700000000001, 0.038121700000000001,
        0.0385029, 0.0385029, 0.0385029, 0.0385029, 0.0385029, 0.0385029, 0.0385029, 0.0385029,
        0.038887900000000003, 0.038887900000000003, 0.038887900000000003, 0.038887900000000003, 0.038887900000000003, 0.038887900000000003, 0.038887900000000003, 0.038887900000000003,
        0.039276800000000001, 0.039276800000000001, 0.039276800000000001, 0.039276800000000001, 0.039276800000000001, 0.039276800000000001, 0.039276800000000001, 0.039276800000000001,
        0.039669599999999999, 0.039669599999999999, 0.039669599999999999, 0.039669599999999999, 0.039669599999999999, 0.039669599999999999, 0.039669599999999999, 0.039669599999999999,
        0.040066299999999999, 0.040066299999999999, 0.040066299999999999, 0.040066299999999999, 0.040066299999999999, 0.040066299999999999, 0.040066299999999999, 0.040066299999999999,
        0.0404669, 0.0404669, 0.0404669, 0.0404669, 0.0404669, 0.0404669, 0.0404669, 0.0404669,
        0.040871600000000001, 0.040871600000000001, 0.040871600000000001, 0.040871600000000001, 0.040871600000000001, 0.040871600000000001, 0.040871600000000001, 0.040871600000000001,
        0.041280299999999999, 0.041280299999999999, 0.041280299999999999, 0.041280299999999999, 0.041280299999999999, 0.041280299999999999, 0.041280299999999999, 0.041280299999999999,
        0.041693099999999997, 0.041693099999999997, 0.041693099999999997, 0.041693099999999997, 0.041693099999999997, 0.041693099999999997, 0.041693099999999997, 0.041693099999999997,
        0.042110000000000002, 0.042110000000000002, 0.042110000000000002, 0.042110000000000002, 0.042110000000000002, 0.042110000000000002, 0.042110000000000002, 0.042110000000000002,
        0.042531100000000002, 0.042531100000000002, 0.042531100000000002, 0.042531100000000002, 0.042531100000000002, 0.042531100000000002, 0.042531100000000002, 0.042531100000000002,
        0.042956500000000002, 0.042956500000000002, 0.042956500000000002, 0.042956500000000002, 0.042956500000000002, 0.042956500000000002, 0.042956500000000002, 0.042956500000000002,
        0.043386000000000001, 0.043386000000000001, 0.043386000000000001, 0.043386000000000001, 0.043386000000000001, 0.043386000000000001, 0.043386000000000001, 0.043386000000000001,
        0.043819900000000002, 0.043819900000000002, 0.043819900000000002, 0.043819900000000002, 0.043819900000000002, 0.043819900000000002, 0.043819900000000002, 0.043819900000000002,
        0.044258100000000002, 0.044258100000000002, 0.044258100000000002, 0.044258100000000002, 0.044258100000000002, 0.044258100000000002, 0.044258100000000002, 0.044258100000000002,
        0.044700700000000003, 0.044700700000000003, 0.044700700000000003, 0.044700700000000003, 0.044700700000000003, 0.044700700000000003, 0.044700700000000003, 0.044700700000000003,
        0.045147699999999999, 0.045147699999999999, 0.045147699999999999, 0.045147699999999999, 0.045147699999999999, 0.045147699999999999, 0.045147699999999999, 0.045147699999999999,
        0.045599099999999997, 0.045599099999999997, 0.045599099999999997, 0.045599099999999997, 0.045599099999999997, 0.045599099999999997, 0.045599099999999997, 0.045599099999999997,
        0.046055100000000002, 0.046055100000000002, 0.046055100000000002, 0.046055100000000002, 0.046055100000000002, 0.046055100000000002, 0.046055100000000002, 0.046055100000000002,
        0.0465157, 0.0465157, 0.0465157, 0.0465157, 0.0465157, 0.0465157, 0.0465157, 0.0465157,
        0.046980800000000003, 0.046980800000000003, 0.046980800000000003, 0.046980800000000003, 0.046980800000000003, 0.046980800000000003, 0.046980800000000003, 0.046980800000000003,
        0.047450600000000002, 0.047450600000000002, 0.047450600000000002, 0.047450600000000002, 0.047450600000000002, 0.047450600000000002, 0.047450600000000002, 0.047450600000000002,
        0.047925200000000001, 0.047925200000000001, 0.047925200000000001, 0.047925200000000001, 0.047925200000000001, 0.047925200000000001, 0.047925200000000001, 0.047925200000000001,
        0.0484044, 0.0484044, 0.0484044, 0.0484044, 0.0484044, 0.0484044, 0.0484044, 0.0484044,
        0.048888399999999999, 0.048888399999999999, 0.048888399999999999, 0.048888399999999999, 0.048888399999999999, 0.048888399999999999, 0.048888399999999999, 0.048888399999999999,
        0.049377299999999999, 0.049377299999999999, 0.049377299999999999, 0.049377299999999999, 0.049377299999999999, 0.049377299999999999, 0.049377299999999999, 0.049377299999999999,
        0.049871100000000002, 0.049871100000000002, 0.049871100000000002, 0.049871100000000002, 0.049871100000000002, 0.049871100000000002, 0.049871100000000002, 0.049871100000000002,
        0.050369799999999999, 0.050369799999999999, 0.050369799999999999, 0.050369799999999999, 0.050369799999999999, 0.050369799999999999, 0.050369799999999999, 0.050369799999999999,
        0.050873500000000002, 0.050873500000000002, 0.050873500000000002, 0.050873500000000002, 0.050873500000000002, 0.050873500000000002, 0.050873500000000002, 0.050873500000000002,
        0.051382299999999999, 0.051382299999999999, 0.051382299999999999, 0.051382299999999999, 0.051382299999999999, 0.051382299999999999, 0.051382299999999999, 0.051382299999999999,
        0.051896100000000001, 0.051896100000000001, 0.051896100000000001, 0.051896100000000001, 0.051896100000000001, 0.051896100000000001, 0.051896100000000001, 0.051896100000000001,
        0.052415000000000003, 0.052415000000000003, 0.052415000000000003, 0.052415000000000003, 0.052415000000000003, 0.052415000000000003, 0.052415000000000003, 0.052415000000000003,
        0.052939199999999999, 0.052939199999999999, 0.052939199999999999, 0.052939199999999999, 0.052939199999999999, 0.052939199999999999, 0.052939199999999999, 0.052939199999999999,
        0.053468599999999998, 0.053468599999999998, 0.053468599999999998, 0.053468599999999998, 0.053468599999999998, 0.053468599999999998, 0.053468599999999998, 0.053468599999999998,
        0.054003299999999997, 0.054003299999999997, 0.054003299999999997, 0.054003299999999997, 0.054003299999999997, 0.054003299999999997, 0.054003299999999997, 0.054003299999999997,
        0.054543300000000003, 0.054543300000000003, 0.054543300000000003, 0.054543300000000003, 0.054543300000000003, 0.054543300000000003, 0.054543300000000003, 0.054543300000000003,
        0.055088699999999997, 0.055088699999999997, 0.055088699999999997, 0.055088699999999997, 0.055088699999999997, 0.055088699999999997, 0.055088699999999997, 0.055088699999999997,
        0.055639599999999997, 0.055639599999999997, 0.055639599999999997, 0.055639599999999997, 0.055639599999999997, 0.055639599999999997, 0.055639599999999997, 0.055639599999999997,
        0.056196000000000003, 0.056196000000000003, 0.056196000000000003, 0.056196000000000003, 0.056196000000000003, 0.056196000000000003, 0.056196000000000003, 0.056196000000000003,
        0.056758000000000003, 0.056758000000000003, 0.056758000000000003, 0.056758000000000003, 0.056758000000000003, 0.056758000000000003, 0.056758000000000003, 0.056758000000000003,
        0.057325599999999997, 0.057325599999999997, 0.057325599999999997, 0.057325599999999997, 0.057325599999999997, 0.057325599999999997, 0.057325599999999997, 0.057325599999999997,
        0.0578988, 0.0578988, 0.0578988, 0.0578988, 0.0578988, 0.0578988, 0.0578988, 0.0578988,
        0.058477800000000003, 0.058477800000000003, 0.058477800000000003, 0.058477800000000003, 0.058477800000000003, 0.058477800000000003, 0.058477800000000003, 0.058477800000000003,
        0.0590626, 0.0590626, 0.0590626, 0.0590626, 0.0590626, 0.0590626, 0.0590626, 0.0590626,
        0.059653200000000003, 0.059653200000000003, 0.059653200000000003, 0.059653200000000003, 0.059653200000000003, 0.059653200000000003, 0.059653200000000003, 0.059653200000000003,
        0.060249700000000003, 0.060249700000000003, 0.060249700000000003, 0.060249700000000003, 0.060249700000000003, 0.060249700000000003, 0.060249700000000003, 0.060249700000000003,
        0.060852200000000002, 0.060852200000000002, 0.060852200000000002, 0.060852200000000002, 0.060852200000000002, 0.060852200000000002, 0.060852200000000002, 0.060852200000000002,
        0.0614607, 0.0614607, 0.0614607, 0.0614607, 0.0614607, 0.0614607, 0.0614607, 0.0614607,
        0.062075400000000003, 0.062075400000000003, 0.062075400000000003, 0.062075400000000003, 0.062075400000000003, 0.062075400000000003, 0.062075400000000003, 0.062075400000000003,
        0.062696100000000005, 0.062696100000000005, 0.062696100000000005, 0.062696100000000005, 0.062696100000000005, 0.062696100000000005, 0.062696100000000005, 0.062696100000000005,
        0.063323099999999993, 0.063323099999999993, 0.063323099999999993, 0.063323099999999993, 0.063323099999999993, 0.063323099999999993, 0.063323099999999993, 0.063323099999999993,
        0.063956299999999994, 0.063956299999999994, 0.063956299999999994, 0.063956299999999994, 0.063956299999999994, 0.063956299999999994, 0.063956299999999994, 0.063956299999999994,
        0.064595899999999998, 0.064595899999999998, 0.064595899999999998, 0.064595899999999998, 0.064595899999999998, 0.064595899999999998, 0.064595899999999998, 0.064595899999999998,
        0.065241800000000003, 0.065241800000000003, 0.065241800000000003, 0.065241800000000003, 0.065241800000000003, 0.065241800000000003, 0.065241800000000003, 0.065241800000000003,
        0.0658942, 0.0658942, 0.0658942, 0.0658942, 0.0658942, 0.0658942, 0.0658942, 0.0658942,
        0.066553200000000007, 0.066553200000000007, 0.066553200000000007, 0.066553200000000007, 0.066553200000000007, 0.066553200000000007, 0.066553200000000007, 0.066553200000000007,
        0.067218700000000006, 0.067218700000000006, 0.067218700000000006, 0.067218700000000006, 0.067218700000000006, 0.067218700000000006, 0.067218700000000006, 0.067218700000000006,
        0.067890900000000004, 0.067890900000000004, 0.067890900000000004, 0.067890900000000004, 0.067890900000000004, 0.067890900000000004, 0.067890900000000004, 0.067890900000000004,
        0.0685698, 0.0685698, 0.0685698, 0.0685698, 0.0685698, 0.0685698, 0.0685698, 0.0685698,
        0.069255499999999998, 0.069255499999999998, 0.069255499999999998, 0.069255499999999998, 0.069255499999999998, 0.069255499999999998, 0.069255499999999998, 0.069255499999999998,
        0.069948099999999999, 0.069948099999999999, 0.069948099999999999, 0.069948099999999999, 0.069948099999999999, 0.069948099999999999, 0.069948099999999999, 0.069948099999999999,
        0.070647500000000002, 0.070647500000000002, 0.070647500000000002, 0.070647500000000002, 0.070647500000000002, 0.070647500000000002, 0.070647500000000002, 0.070647500000000002,
        0.071354000000000001, 0.071354000000000001, 0.071354000000000001, 0.071354000000000001, 0.071354000000000001, 0.071354000000000001, 0.071354000000000001, 0.071354000000000001, 0.071354000000000001,
        0.072067599999999996, 0.072067599999999996, 0.072067599999999996, 0.072067599999999996, 0.072067599999999996, 0.072067599999999996, 0.072067599999999996, 0.072067599999999996, 0.072067599999999996,
        0.072788199999999997, 0.072788199999999997, 0.072788199999999997, 0.072788199999999997, 0.072788199999999997, 0.072788199999999997, 0.072788199999999997, 0.072788199999999997, 0.072788199999999997,
        0.073516100000000001, 0.073516100000000001, 0.073516100000000001, 0.073516100000000001, 0.073516100000000001, 0.073516100000000001, 0.073516100000000001, 0.073516100000000001, 0.073516100000000001,
        0.074251300000000006, 0.074251300000000006, 0.074251300000000006, 0.074251300000000006, 0.074251300000000006, 0.074251300000000006, 0.074251300000000006, 0.074251300000000006, 0.074251300000000006,
        0.074993799999999999, 0.074993799999999999, 0.074993799999999999, 0.074993799999999999, 0.074993799999999999, 0.074993799999999999, 0.074993799999999999, 0.074993799999999999, 0.074993799999999999,
        0.075743699999999997, 0.075743699999999997, 0.075743699999999997, 0.075743699999999997, 0.075743699999999997, 0.075743699999999997, 0.075743699999999997, 0.075743699999999997, 0.075743699999999997,
        0.076501200000000005, 0.076501200000000005, 0.076501200000000005, 0.076501200000000005, 0.076501200000000005, 0.076501200000000005, 0.076501200000000005, 0.076501200000000005, 0.076501200000000005,
        0.077266199999999993, 0.077266199999999993, 0.077266199999999993, 0.077266199999999993, 0.077266199999999993, 0.077266199999999993, 0.077266199999999993, 0.077266199999999993, 0.077266199999999993,
        0.078038800000000005, 0.078038800000000005, 0.078038800000000005, 0.078038800000000005, 0.078038800000000005, 0.078038800000000005, 0.078038800000000005, 0.078038800000000005, 0.078038800000000005,
        0.078819200000000006, 0.078819200000000006, 0.078819200000000006, 0.078819200000000006, 0.078819200000000006, 0.078819200000000006, 0.078819200000000006, 0.078819200000000006, 0.078819200000000006,
        0.079607399999999995, 0.079607399999999995, 0.079607399999999995, 0.079607399999999995, 0.079607399999999995, 0.079607399999999995, 0.079607399999999995, 0.079607399999999995, 0.079607399999999995,
        0.080403500000000003, 0.080403500000000003, 0.080403500000000003, 0.080403500000000003, 0.080403500000000003, 0.080403500000000003, 0.080403500000000003, 0.080403500000000003, 0.080403500000000003,
        0.081207500000000002, 0.081207500000000002, 0.081207500000000002, 0.081207500000000002, 0.081207500000000002, 0.081207500000000002, 0.081207500000000002, 0.081207500000000002, 0.081207500000000002,
        0.082019599999999998, 0.082019599999999998, 0.082019599999999998, 0.082019599999999998, 0.082019599999999998, 0.082019599999999998, 0.082019599999999998, 0.082019599999999998, 0.082019599999999998,
        0.082839800000000005, 0.082839800000000005, 0.082839800000000005, 0.082839800000000005, 0.082839800000000005, 0.082839800000000005, 0.082839800000000005, 0.082839800000000005, 0.082839800000000005,
        0.083668199999999998, 0.083668199999999998, 0.083668199999999998, 0.083668199999999998, 0.083668199999999998, 0.083668199999999998, 0.083668199999999998, 0.083668199999999998, 0.083668199999999998,
        0.084504899999999994, 0.084504899999999994, 0.084504899999999994, 0.084504899999999994, 0.084504899999999994, 0.084504899999999994, 0.084504899999999994, 0.084504899999999994, 0.084504899999999994,
        0.085349900000000006, 0.085349900000000006, 0.085349900000000006, 0.085349900000000006, 0.085349900000000006, 0.085349900000000006, 0.085349900000000006, 0.085349900000000006, 0.085349900000000006,
        0.086203399999999999, 0.086203399999999999, 0.086203399999999999, 0.086203399999999999, 0.086203399999999999, 0.086203399999999999, 0.086203399999999999, 0.086203399999999999, 0.086203399999999999,
        0.087065500000000004, 0.087065500000000004, 0.087065500000000004, 0.087065500000000004, 0.087065500000000004, 0.087065500000000004, 0.087065500000000004, 0.087065500000000004, 0.087065500000000004,
        0.087936100000000003, 0.087936100000000003, 0.087936100000000003, 0.087936100000000003, 0.087936100000000003, 0.087936100000000003, 0.087936100000000003, 0.087936100000000003, 0.087936100000000003,
        0.088815500000000006, 0.088815500000000006, 0.088815500000000006, 0.088815500000000006, 0.088815500000000006, 0.088815500000000006, 0.088815500000000006, 0.088815500000000006, 0.088815500000000006,
        0.089703599999999994, 0.089703599999999994, 0.089703599999999994, 0.089703599999999994, 0.089703599999999994, 0.089703599999999994, 0.089703599999999994, 0.089703599999999994,
        0.090600700000000006, 0.090600700000000006, 0.090600700000000006, 0.090600700000000006, 0.090600700000000006, 0.090600700000000006, 0.090600700000000006, 0.090600700000000006,
        0.091506699999999996, 0.091506699999999996, 0.091506699999999996, 0.091506699999999996, 0.091506699999999996, 0.091506699999999996, 0.091506699999999996, 0.091506699999999996,
        0.092421699999999996, 0.092421699999999996, 0.092421699999999996, 0.092421699999999996, 0.092421699999999996, 0.092421699999999996, 0.092421699999999996, 0.092421699999999996,
        0.093345999999999998, 0.093345999999999998, 0.093345999999999998, 0.093345999999999998, 0.093345999999999998, 0.093345999999999998, 0.093345999999999998, 0.093345999999999998,
        0.094279399999999999, 0.094279399999999999, 0.094279399999999999, 0.094279399999999999, 0.094279399999999999, 0.094279399999999999, 0.094279399999999999, 0.094279399999999999,
        0.095222200000000007, 0.095222200000000007, 0.095222200000000007, 0.095222200000000007, 0.095222200000000007, 0.095222200000000007, 0.095222200000000007, 0.095222200000000007,
        0.096174399999999993, 0.096174399999999993, 0.096174399999999993, 0.096174399999999993, 0.096174399999999993, 0.096174399999999993, 0.096174399999999993, 0.096174399999999993,
        0.097136200000000006, 0.097136200000000006, 0.097136200000000006, 0.097136200000000006, 0.097136200000000006, 0.097136200000000006, 0.097136200000000006, 0.097136200000000006,
        0.0981075, 0.0981075, 0.0981075, 0.0981075, 0.0981075, 0.0981075, 0.0981075, 0.0981075,
        0.099088599999999999, 0.099088599999999999, 0.099088599999999999, 0.099088599999999999, 0.099088599999999999, 0.099088599999999999, 0.099088599999999999, 0.099088599999999999,
        0.1000795, 0.1000795, 0.1000795, 0.1000795, 0.1000795, 0.1000795, 0.1000795, 0.1000795,
        0.1010803, 0.1010803, 0.1010803, 0.1010803, 0.1010803, 0.1010803, 0.1010803, 0.1010803,
        0.1020911, 0.1020911, 0.1020911, 0.1020911, 0.1020911, 0.1020911, 0.1020911, 0.1020911,
        0.103112, 0.103112, 0.103112, 0.103112, 0.103112, 0.103112, 0.103112, 0.103112,
        0.1041431, 0.1041431, 0.1041431, 0.1041431, 0.1041431, 0.1041431, 0.1041431, 0.1041431,
        0.1051846, 0.1051846, 0.1051846, 0.1051846, 0.1051846, 0.1051846, 0.1051846, 0.1051846,
        0.10623639999999999, 0.10623639999999999, 0.10623639999999999, 0.10623639999999999, 0.10623639999999999, 0.10623639999999999, 0.10623639999999999, 0.10623639999999999,
        0.1072988, 0.1072988, 0.1072988, 0.1072988, 0.1072988, 0.1072988, 0.1072988, 0.1072988,
        0.1083718, 0.1083718, 0.1083718, 0.1083718, 0.1083718, 0.1083718, 0.1083718, 0.1083718,
        0.1094555, 0.1094555, 0.1094555, 0.1094555, 0.1094555, 0.1094555, 0.1094555, 0.1094555,
        0.11055, 0.11055, 0.11055, 0.11055, 0.11055, 0.11055, 0.11055, 0.11055,
        0.1116555, 0.1116555, 0.1116555, 0.1116555, 0.1116555, 0.1116555, 0.1116555, 0.1116555,
        0.1127721, 0.1127721, 0.1127721, 0.1127721, 0.1127721, 0.1127721, 0.1127721, 0.1127721,
        0.1138998, 0.1138998, 0.1138998, 0.1138998, 0.1138998, 0.1138998, 0.1138998, 0.1138998,
        0.1150388, 0.1150388, 0.1150388, 0.1150388, 0.1150388, 0.1150388, 0.1150388, 0.1150388,
        0.11618920000000001, 0.11618920000000001, 0.11618920000000001, 0.11618920000000001, 0.11618920000000001, 0.11618920000000001, 0.11618920000000001, 0.11618920000000001,
        0.1173511, 0.1173511, 0.1173511, 0.1173511, 0.1173511, 0.1173511, 0.1173511, 0.1173511,
        0.11852459999999999, 0.11852459999999999, 0.11852459999999999, 0.11852459999999999, 0.11852459999999999, 0.11852459999999999, 0.11852459999999999, 0.11852459999999999,
        0.11970989999999999, 0.11970989999999999, 0.11970989999999999, 0.11970989999999999, 0.11970989999999999, 0.11970989999999999, 0.11970989999999999, 0.11970989999999999, 0.11970989999999999,
        0.120907, 0.120907, 0.120907, 0.120907, 0.120907, 0.120907, 0.120907, 0.120907, 0.120907,
        0.122116, 0.122116, 0.122116, 0.122116, 0.122116, 0.122116, 0.122116, 0.122116, 0.122116,
        0.12333719999999999, 0.12333719999999999, 0.12333719999999999, 0.12333719999999999, 0.12333719999999999, 0.12333719999999999, 0.12333719999999999, 0.12333719999999999, 0.12333719999999999,
        0.1245706, 0.1245706, 0.1245706, 0.1245706, 0.1245706, 0.1245706, 0.1245706, 0.1245706, 0.1245706,
        0.12581629999999999, 0.12581629999999999, 0.12581629999999999, 0.12581629999999999, 0.12581629999999999, 0.12581629999999999, 0.12581629999999999, 0.12581629999999999, 0.12581629999999999,
        0.1270744, 0.1270744, 0.1270744, 0.1270744, 0.1270744, 0.1270744, 0.1270744, 0.1270744, 0.1270744,
        0.12834519999999999, 0.12834519999999999, 0.12834519999999999, 0.12834519999999999, 0.12834519999999999, 0.12834519999999999, 0.12834519999999999, 0.12834519999999999, 0.12834519999999999,
    ]
}

struct CalibrationInfo: Equatable, Codable {
   var i1: Int
   var i2: Int
   var i3: Int
   var i4: Int
   var i5: Int
   var i6: Int
 }


open class PreLibre2 {
    
    public static func op(_ value: UInt16, _ l1: UInt16, _ l2: UInt16) -> UInt16 {
        var res = value >> 2 // Result does not include these last 2 bits
        if ((value & 1) == 1) {
            res ^= l2
        }
        
        if ((value & 2) == 2) {// If second last bit is 1
            res ^= l1
        }
        return res
    }
    
    public static func processCrypto(_ s1: UInt16, _ s2: UInt16, _ s3: UInt16, _ s4: UInt16, _ l1: UInt16, _ l2: UInt16) -> [UInt16] {
        let r0 = op(s1, l1, l2) ^ s4
        let r1 = op(r0, l1, l2) ^ s3
        let r2 = op(r1, l1, l2) ^ s2
        let r3 = op(r2, l1, l2) ^ s1
        let r4 = op(r3, l1, l2)
        let r5 = op(r4 ^ r0, l1, l2)
        let r6 = op(r5 ^ r1, l1, l2)
        let r7 = op(r6 ^ r2, l1, l2)
        let f1 = ((r0 ^ r4))
        let f2 = ((r1 ^ r5))
        let f3 = ((r2 ^ r6))
        let f4 = ((r3 ^ r7))
        
        return [f1, f2, f3, f4]
    }
    
    public static func word(_ high: UInt8, _ low: UInt8) -> UInt64 {
        return (UInt64(high) << 8) + UInt64(low & 0xff)
    }
    
    public static func decryptFRAM(_ sensorId: [UInt8], _ sensorInfo: [UInt8], _ FRAMData: [UInt8]) -> [UInt8] {
        let l1: UInt16 = 0xa0c5
        let l2: UInt16 = 0x6860
        let l3: UInt16 = 0x14c6
        let l4: UInt16 = 0x0000
    
        var result = [UInt8]()
        for i in 0 ..< 43 {
            let i64 = UInt64(i)
            var y = word(sensorInfo[5], sensorInfo[4])
            if (i < 3 || i >= 40) {
                y = 0xcadc
            }
            var s1: UInt16 = 0
            if (sensorInfo[0] == 0xE5) {
                let ss1 = (word(sensorId[5], sensorId[4]) + y + i64)
                s1 = UInt16(ss1 & 0xffff)
            } else {
                let ss1 = ((word(sensorId[5], sensorId[4]) + (word(sensorInfo[5], sensorInfo[4]) ^ 0x44)) + i64)
                s1 = UInt16(ss1 & 0xffff)
            }
            
            let s2 = UInt16((word(sensorId[3], sensorId[2]) + UInt64(l4)) & 0xffff)
            let s3 = UInt16((word(sensorId[1], sensorId[0]) + (i64 << 1)) & 0xffff)
            let s4 = ((0x241a ^ l3))
            let key = processCrypto(s1, s2, s3, s4, l1, l2)
            result.append((FRAMData[i * 8 + 0] ^ UInt8(key[3] & 0xff)))
            result.append((FRAMData[i * 8 + 1] ^ UInt8((key[3] >> 8) & 0xff)))
            result.append((FRAMData[i * 8 + 2] ^ UInt8(key[2] & 0xff)))
            result.append((FRAMData[i * 8 + 3] ^ UInt8((key[2] >> 8) & 0xff)))
            result.append((FRAMData[i * 8 + 4] ^ UInt8(key[1] & 0xff)))
            result.append((FRAMData[i * 8 + 5] ^ UInt8((key[1] >> 8) & 0xff)))
            result.append((FRAMData[i * 8 + 6] ^ UInt8(key[0] & 0xff)))
            result.append((FRAMData[i * 8 + 7] ^ UInt8((key[0] >> 8) & 0xff)))
        }
        
        return result[0..<344].map{ $0 }
    }
    
}
