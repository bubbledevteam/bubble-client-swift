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
    
    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double, trend: UInt8 = 0) {
        self.timeStamp = timeStamp
        self.glucoseLevelRaw = glucoseLevelRaw
        self.lastValue = glucoseLevelRaw
        self.glucoseLevelFiltered = glucoseLevelFiltered
        self.trend = trend
    }

    convenience init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: 0.0, glucoseLevelFiltered: 0.0)
    }
    
    var description: String {
        return "timeStamp = \(timeStamp.description(with: .current)) glucoseLevelRaw = \(glucoseLevelRaw.description) trend = \(trend)"
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

extension GlucoseData: SensorDisplayable {
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
class LibreRawGlucoseData: GlucoseData {
    
    var unsmoothedGlucose: Double

    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double, unsmoothedGlucose: Double = 0.0) {
        self.unsmoothedGlucose = unsmoothedGlucose

        super.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelFiltered)
    }
    
    convenience init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date, glucoseLevelRaw:Double, unsmoothedGlucose: Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: 0.0, unsmoothedGlucose: unsmoothedGlucose)
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
}

class LibreRawGlucoseOOPData: NSObject, Codable {
    var alarm : String?
    var esaMinutesToWait : Int?
    var historicGlucose : [HistoricGlucose]?
    var isActionable : Bool?
    var lsaDetected : Bool?
    var realTimeGlucose : HistoricGlucose?
    var trendArrow : String?
    var msg: String?
    var errcode: String?
    
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
    
    var isError: Bool {
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
    
    var sensorTime: Int? {
        if let msg = msg {
            switch Error(rawValue: msg) {
            case .TERMINATE_SENSOR_CORRUPT_PAYLOAD,
                 .TERMINATE_SENSOR_NORMAL_TERMINATED_STATE,
                 .TERMINATE_SENSOR_ERROR_TERMINATED_STATE,
                 .TYPE_SENSOR_Expired:
                return 24 * 6 * 149
            default:
                break
            }
        }
        return realTimeGlucose?.id
    }
    
    var sensorState: String {
        if let sensorTime = sensorTime, sensorTime < 62 {
            return LibreSensorState.notYetStarted.identify
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
                break;
            case .TYPE_SENSOR_END:
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
        return state.identify
    }
    
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData]) {
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
    
    var valueError: Bool {
        if let g = realTimeGlucose, let value = g.dataQuality {
            return value != 0
        }
        return false
    }
}

class HistoricGlucose: NSObject, Codable {
    let dataQuality : Int?
    let id: Int?
    let value : Double?
}
