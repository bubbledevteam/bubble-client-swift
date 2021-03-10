import Foundation
import HealthKit
import LoopKit

/// glucose,
public class GlucoseData: Codable {
    
    // TODO: is there ever a difference between raw and filtered ? why not remove one ?
    
    public var timeStamp: Date
    public var glucoseLevelRaw: Double
    public var glucoseLevelFiltered: Double
    public var trend: UInt8
    public var lastValue: Double
    public var lastDate: Date
    
    public var originValue: Double?
    public var rawGlucose: Int?
    /// The raw temperature as read from the sensor
    public var rawTemperature: Int?
    
    public var temperatureAdjustment: Int?
    
    /// The glucose value in mg/dl
    public var glucose: Double?
    
    public var trueValue: Double {
        if let originValue = originValue, originValue > 0 {
            return originValue
        }
        return glucoseLevelRaw
    }
    
    public var histories: [GlucoseData]?
    
    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double, trend: UInt8 = 0) {
        self.lastDate = timeStamp
        self.timeStamp = timeStamp
        self.glucoseLevelRaw = glucoseLevelRaw
        self.lastValue = glucoseLevelRaw
        self.originValue = glucoseLevelRaw
        self.glucoseLevelFiltered = glucoseLevelFiltered
        self.trend = trend
    }

    convenience init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: 0.0, glucoseLevelFiltered: 0.0)
    }
    
    public var description: String {
        return """
        timeStamp = \(timeStamp.description(with: .current))
        glucoseLevelRaw = \(glucoseLevelRaw.description)
        trend = \(trend)
        lastValue = \(lastValue)
        lastDate = \(lastDate.description(with: .current))
        rawGlucose = \(rawGlucose ?? 0)
        rawTemperature = \(rawTemperature ?? 0)
        
        """
    }
}

extension GlucoseData: GlucoseValue {
    public var startDate: Date {
        return timeStamp
    }
    
    public var quantity: HKQuantity {
        return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: glucoseLevelRaw)
    }
}

extension GlucoseData: GlucoseDisplayable {
    /// todo:
    public var glucoseRangeCategory: GlucoseRangeCategory? {
        return nil
    }
    
    public var isStateValid: Bool {
        return glucoseLevelRaw >= 39
    }
    
    public var trendType: GlucoseTrend? {
        return GlucoseTrend(rawValue: Int(trend))
    }
    
    public var isLocal: Bool {
        return true
    }
}


/// extends RawGlucoseData and adds property unsmoothedGlucose, because this is only used for Libre
public class LibreRawGlucoseData: GlucoseData {
    
    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double) {
        super.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelFiltered)
    }
    
    convenience init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date, unsmoothedGlucose: Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: 0.0, glucoseLevelFiltered: 0.0)
    }
    
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
}

public protocol LibreRawGlucoseWeb {
    var isError: Bool { get }
    var sensorTime: Int? { get }
    var canGetParameters: Bool { get }
    var sensorState: String { get }
    var valueError: Bool { get }
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData])
}

class LibreGlucoseData: Codable {
    struct Slope: Codable {
        var slopeSlope: Double?
        var slopeOffset: Double?
        var offsetOffset: Double?
        var offsetSlope: Double?
        
        enum CodingKeys: String, CodingKey {
            case slopeSlope = "slope_slope"
            case slopeOffset = "slope_offset"
            case offsetOffset = "offset_offset"
            case offsetSlope = "offset_slope"
        }
        
        var isErrorParameters: Bool {
            if slopeSlope == 0 &&
                slopeOffset == 0 &&
                offsetOffset == 0 &&
                offsetSlope == 0 {
                return true
            }
            return slopeSlope == nil || slopeOffset == nil || offsetOffset == nil || offsetSlope == nil
        }
    }
    
    private var slope: Slope?
    var data: LibreRawGlucoseOOPData?
    
    var slopeValue: LibreDerivedAlgorithmParameters? {
        if let s = slope, !s.isErrorParameters {
            return LibreDerivedAlgorithmParameters.init(slope_slope: s.slopeSlope!,
                                                        slope_offset: s.slopeOffset!,
                                                        offset_slope: s.offsetSlope!,
                                                        offset_offset: s.offsetOffset!)
        }
        return nil
    }
}

public class LibreRawGlucoseOOPData: NSObject, Codable, LibreRawGlucoseWeb {
    var alarm : String?
    var esaMinutesToWait : Int?
    var historicGlucose : [HistoricGlucose]?
    var isActionable : Bool?
    var lsaDetected : Bool?
    var realTimeGlucose : HistoricGlucose?
    var trendArrow : String?
    var msg: String?
    var errcode: String?
    var endTime: Int?
    
    enum Error: String {
        typealias RawValue = String
        case RESULT_SENSOR_STORAGE_STATE
        case RESCAN_SENSOR_BAD_CRC
        case TERMINATE_SENSOR_NORMAL_TERMINATED_STATE
        case TERMINATE_SENSOR_ERROR_TERMINATED_STATE
        case TERMINATE_SENSOR_CORRUPT_PAYLOAD
        case FATAL_ERROR_BAD_ARGUMENTS
        case TYPE_SENSOR_NOT_STARTED
        case TYPE_SENSOR_STARTING
        case TYPE_SENSOR_Expired
        case TYPE_SENSOR_END
        case TYPE_SENSOR_ERROR
        case TYPE_SENSOR_OK
        case TYPE_SENSOR_DETERMINED
    }
    
    public var isError: Bool {
        if let msg = msg {
            switch Error(rawValue: msg) {
            case .TERMINATE_SENSOR_CORRUPT_PAYLOAD,
                 .TERMINATE_SENSOR_NORMAL_TERMINATED_STATE,
                 .TERMINATE_SENSOR_ERROR_TERMINATED_STATE:
                return false
            default:
                break
            }
        }
        return historicGlucose?.isEmpty ?? true
    }
    
    public var sensorTime: Int? {
        if let endTime = endTime, endTime < 0 {
            return 24 * 6 * 149
        }
        return realTimeGlucose?.id
    }
    
    public var canGetParameters: Bool {
        if let dataQuality = realTimeGlucose?.dataQuality, let id = realTimeGlucose?.id {
            if dataQuality == 0 && id >= 60 {
                return true
            }
        }
        return false
    }
    
    public var sensorState: String {
        if let dataQuality = realTimeGlucose?.dataQuality, let id = realTimeGlucose?.id {
            if dataQuality != 0 && id < 60 {
                return LibreSensorState.starting.identify
            }
        }
        
        var state = LibreSensorState.ready
        if let msg = msg {
            switch Error(rawValue: msg) {
            case .TYPE_SENSOR_NOT_STARTED:
                state = .notYetStarted
                break;
            case .TYPE_SENSOR_STARTING:
                state = .starting
                break;
            case .TYPE_SENSOR_Expired,
                 .TERMINATE_SENSOR_CORRUPT_PAYLOAD,
                 .TERMINATE_SENSOR_NORMAL_TERMINATED_STATE,
                 .TERMINATE_SENSOR_ERROR_TERMINATED_STATE:
                state = .end
                break;
            case .TYPE_SENSOR_END:
                state = .end
                break;
            case .TYPE_SENSOR_ERROR:
                state = .failure
                break;
            case .TYPE_SENSOR_OK:
                state = .ready
            case .TYPE_SENSOR_DETERMINED:
                state = .unknown
                break
            default:
                break;
            }
        }
        if let endTime = endTime, endTime < 0 {
            state = .end
        }
        return state.identify
    }
    
    public func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData]) {
        if endTime ?? 0 < 0 {
            return (nil, [])
        }
        var current: LibreRawGlucoseData?
        guard let g = realTimeGlucose, g.dataQuality == 0 else { return(nil, []) }
        current = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.value ?? 0)
        var array = [LibreRawGlucoseData]()
        let gap: TimeInterval = 60 * 15
        var date = date
        if var history = historicGlucose {
            if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
                history = history.reversed()
            }
            
            for g in history {
                date = date.addingTimeInterval(-gap)
                if g.dataQuality != 0 { continue }
                let glucose = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.value ?? 0)
                array.insert(glucose, at: 0)
            }
        }
        return (current ,array)
    }
    
    public var valueError: Bool {
        if let id = realTimeGlucose?.id, id < 60 {
            return false
        }
        
        if let g = realTimeGlucose, let value = g.dataQuality {
            return value != 0
        }
        return false
    }
    
    public var currentError: Bool {
        return (realTimeGlucose?.dataQuality ?? -1) != 0
    }
}

class HistoricGlucose: NSObject, Codable {
    let dataQuality : Int?
    let id: Int?
    let value : Double?
}

public class LibreA2GlucoseData: Codable {
    struct Slope: Codable {
        var slopeSlope: Double?
        var slopeOffset: Double?
        var offsetOffset: Double?
        var offsetSlope: Double?
        
        enum CodingKeys: String, CodingKey {
            case slopeSlope = "slope_slope"
            case slopeOffset = "slope_offset"
            case offsetOffset = "offset_offset"
            case offsetSlope = "offset_slope"
        }
        
        var isErrorParameters: Bool {
            if slopeSlope == 0 &&
                slopeOffset == 0 &&
                offsetOffset == 0 &&
                offsetSlope == 0 {
                return true
            }
            return slopeSlope == nil || slopeOffset == nil || offsetOffset == nil || offsetSlope == nil
        }
    }
    
    private var slope: Slope?
    var data: LibreRawGlucoseOOPA2Data?
    
    var slopeValue: LibreDerivedAlgorithmParameters? {
        if let s = slope, !s.isErrorParameters {
            return LibreDerivedAlgorithmParameters.init(slope_slope: s.slopeSlope!,
                                                        slope_offset: s.slopeOffset!,
                                                        offset_slope: s.offsetSlope!,
                                                        offset_offset: s.offsetOffset!)
        }
        return nil
    }
}

public class LibreRawGlucoseOOPA2Data: NSObject, Codable, LibreRawGlucoseWeb {
    var errcode: Int?
    var list: [LibreRawGlucoseOOPA2List]?
    
    var content: LibreRawGlucoseOOPA2Cotent? {
        return list?.first?.content
    }
    
    public var isError: Bool {
        if content?.currentBg ?? 0 <= 10 {
            return true
        }
        return list?.first?.content?.historicBg?.isEmpty ?? true
    }
    
    public var sensorTime: Int? {
        return content?.currentTime
    }
    
    public var canGetParameters: Bool {
        if let id = content?.currentTime {
            if id >= 60 {
                return true
            }
        }
        return false
    }
    
    public var sensorState: String {
        if let id = content?.currentTime {
            if id < 60 {
                return LibreSensorState.starting.identify
            } else if id >= 20880 {
                return LibreSensorState.end.identify
            }
        }
        
        let state = LibreSensorState.ready
        return state.identify
    }
    
    public func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData]) {
        var current: LibreRawGlucoseData?
        guard !isError else { return(nil, []) }
        current = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: content?.currentBg ?? 0)
        var array = [LibreRawGlucoseData]()
        let gap: TimeInterval = 60 * 15
        var date = date
        if var history = content?.historicBg {
            if (history.first?.time ?? 0) < (history.last?.time ?? 0) {
                history = history.reversed()
            }
            
            for g in history {
                date = date.addingTimeInterval(-gap)
                if g.quality != 0 { continue }
                let glucose = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.bg ?? 0)
                array.insert(glucose, at: 0)
            }
        }
        return (current ,array)
    }
    
    public var valueError: Bool {
        if let id = content?.currentTime, id < 60 {
            return false
        }
        
        if content?.currentBg ?? 0 <= 10 {
            return true
        }
        return false
    }
}

class LibreRawGlucoseOOPA2List: NSObject, Codable {
    var content: LibreRawGlucoseOOPA2Cotent?
    var timestamp: Int?
}

class LibreRawGlucoseOOPA2Cotent: NSObject, Codable {
    var currentTime: Int?
    var currenTrend: Int?
    var serialNumber: String?
    var historicBg: [HistoricGlucoseA2]?
    var currentBg: Double?
    var timestamp: Int?
}

class HistoricGlucoseA2: NSObject, Codable {
    let quality : Int?
    let time: Int?
    let bg : Double?
}
