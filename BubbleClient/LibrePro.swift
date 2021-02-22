//
//  LibrePro.swift
//  DiaBox
//
//  Created by Yan Hu on 2020/6/28.
//  Copyright © 2020 DiaBox. All rights reserved.
//

import Foundation

// this class is for libre pro/h 
open class LibrePro {
    static let max = 24
    
    private(set) var f126c: CLongLong = 0
    private(set) var f125b: CLongLong = 0
    private(set) var f127d = [UInt8]()
    
    init(f127d: [UInt8]) {
        let time = CLongLong(Date().timeIntervalSince1970 * 1000)
        self.f125b = time
        self.f126c = time
        self.f127d = f127d
    }
    
    private func value(_ index: Int) -> Int {
        return Int(f127d[index])
    }

    private func mo221e(_ i: Int) -> Int {
        let a = value(i)
        let a2 = value(i + 1)
        let i2 = (a2 * 256) + a
        return i2
    }

    private func mo209a() -> Int {
        return histroy() - 5
    }

    private func mo212b(_ i: Int) -> Double {
        return mo208a(mo214b(i, 0), mo214b(i, 3))
    }

    func history(_ index: Int) -> Int {
        return Int(historyData[index])
    }
    
    private func historyValue(_ i: Int) -> Double {
        let len = (i * 6) + startLen() + 0
        let a = history(len)
        let a2 = history(len + 1)
        let v = (a2 * 256) + a
        return mo208a(v, v)
    }

    private func histroyTime(_ i: Int) -> CLongLong {
        let m0 = sensorStartTime()
        let m1 = histroy()
        let e = (m0 % 15) + ((m1 - i) * 15)
        let j = f126c
        return j - ((CLongLong(e) * 60) * 1000)
    }

    func histroy() -> Int {
        256 * Int(f127d[79] & 0xFF) +  Int(f127d[78] & 0xFF)
    }
    
    func histroyByteLen() -> Int {
        histroy() * 6 + 176
    }
    
    func startLen() -> Int {
        let his = histroyByteLen() - Self.max * 8
        return his % 8
    }
    
    func startByte() -> Int {
        var start = 22
        if histroyByteLen() > 176 + 24 * 8 {
            start = ((histroyByteLen() - 24 * 8) - proIndex()) / 8
        }
        return start
    }
    
    func proIndex() -> Int {
        var index = 0
        if histroyByteLen() > 176 + 24 * 8 {
            index = (histroyByteLen() - 24 * 8) % 8
        }
        return index
    }

    func trend() -> Int {
        let trend = 256 * Int(f127d[77] & 0xFF) + Int(f127d[76] & 0xFF)
        return trend
    }
    
    func trendTime(_ i: Int) -> CLongLong {
        let d = ((trend() + 16) - i) % 16
        return f126c - ((CLongLong(d) * 60) * 1000)
    }


    func sensorStartTime() -> Int {
        let sensorTime = 256 * Int(f127d[75] & 0xFF) + Int(f127d[74] & 0xFF)
        return sensorTime
    }

    private func historyIndex() -> Int {
        let h = histroy() - (Self.max * 8 / 6)
        return h
    }

    private func historyCount() -> Int {
        return (Self.max * 8 / 6)
    }
    private var historyData = [UInt8]()
    
    /// handle pro 344 data
    /// - Returns: sensor time, current glucose, for history byte code, if not nil, should get history from bubble
    func mo211a() -> (sensorTime: Int, start: Int, proIndex: Int) {
        return (sensorStartTime(), startByte(), proIndex())
    }

    func mathValue(_ trend: [GlucoseData]) -> Int {
        var all = 0
        var count = 0
        for gd in trend {
            if (count >= 5) {
                break
            }
            all = all + Int(gd.glucoseLevelRaw)
            count += 1
        }
        return all / count
    }

    func mo219d() -> Int {
        let i = value(76) + (value(77) * 256)
        let i2 = ((i + 16) - 1) % 16
        if (i2 >= 0 && i2 < 16) {
            return i2
        }
        return 0
    }
    
    func mo217c(_ i: Int) -> CLongLong {
        let d = ((mo219d() + 16) - i) % 16
        return f126c - ((CLongLong(d) * 60) * 1000)
    }

    func mo214b(_ i: Int, _ i2: Int) -> Int {
        return mo221e((i * 6) + startLen() + i2)
    }
    
    func mo218d(_ i: Int) -> Double {
        return mo208a(mo216c(i, 0), mo216c(i, 3))
    }
    
    /* renamed from: c */
    func mo216c(_ i: Int, _ i2: Int) -> Int {
        return mo221e((i * 6) + 80 + i2)
    }

    func mo222f() -> Int {
        return 16
    }
    
    func mo208a(_ i: Int, _ i2: Int) -> Double {
        let d = Double(i & 8191)
        let d2 = d / 8.5
        if (d2 <= 0.0) {
            return -2.147483648E9
        }
        return d2
    }
    
    func needData(c2: [UInt8]) -> [UInt8] {
        let data1 = f127d
        let data2 = c2
        
        LogsAccessor.log("c1: \(Data(data1).hexEncodedString())")
        LogsAccessor.log("c2: \(Data(data2).hexEncodedString())")
        
        var bb = [UInt8]()
        var content1 = "482998170300000000000000000000000000000000000000d16900000905c8c81e802c05c8fc1d802d05c8ec1d802c05c8e41d802a05c8d81d802705c8d01d802705c8081e802705c8781e802305c8281e801f05c8045e801c05c8e01d801805c8d81d80150588021e801105c80c5e801105c88c5e801105c8e01e800f05c88c5e803e04c8901c807304c8e85a80e40488ce59802105c81859806305c8a458808205c87c18802d05c8549b80dc04c8001c80d204c8a89b80df04c8d45b80db04c8581c80dc04c89c1c80ed04c8545b802805c8885b804e05c8345b807505c8405b80bb05c8685b80c305c8d45b80db05c8b05b80d805c8bc5b80c505c8545a80ec05c83c59800606c89c18806b06c8c018803806c85819801306c8cc5a80b305c8401c807105c8b05c003805c8c45e802705c85c5e803305c8241e80d2210000c24d000814091851140796805a00eda60c621ac8041cda6e".hexadecimal!.bytes
        bb.append(data1[329])
        bb.append(data1[330])
        bb.append(data1[326])
        bb.append(data1[327])
        content1[2] = data1[26]
        content1[3] = data1[27]
        content1[316] = data1[74]
        content1[317] = data1[75]
        var d = [UInt8](repeating: 0, count: 176 - 80 + 1)
        var d2 =  [UInt8](repeating: 0, count: 194)
        var j = 0;
        let indexHistory = Int(content1[27] & 0xFF) // double check this bitmask? should be lower?
        let indexTrend = Int(content1[26] & 0xFF)
        for i in 80 ... 176 {
            d[j] = data1[i]
            j += 1
        }
        
        j = 0
        var proIndex = startByte()
        if proIndex < 0 {
            proIndex = 0
        }
        for i in proIndex ... 6 * 32 + proIndex {
            if data2.count <= i {
                break
            }
            d2[j] = data2[i]
            j += 1
        }
        
        var x = 0
        let trend = 256 * Int(f127d[77] & 0xFF) + Int(f127d[76] & 0xFF)
        for index in 0 ..< 16 {
            let d1 = ((trend + 16) - index) % 16
            var i = indexTrend - index - 1
            if (i < 0) {
                i += 16
            }
            content1[(i * 6 + 28)] = d[d1 * 6 + 0]
            content1[(i * 6 + 29)] = d[d1 * 6 + 1]
            content1[(i * 6 + 30)] = d[d1 * 6 + 2]
            content1[(i * 6 + 31)] = d[d1 * 6 + 3]
            content1[(i * 6 + 32)] = d[d1 * 6 + 4]
            content1[(i * 6 + 33)] = d[d1 * 6 + 5]
            x += 1
        }
        
        x = 0
        for var index in 0 ... 31 {
            index = 31 - index
            var i = indexHistory - index - 1
            if (i < 0) {
                i += 32
            }
            content1[(i * 6 + 124)] = d2[x * 6 + 0]
            content1[(i * 6 + 125)] = d2[x * 6 + 1]
            content1[(i * 6 + 126)] = d2[x * 6 + 2]
            content1[(i * 6 + 127)] = d2[x * 6 + 3]
            content1[(i * 6 + 128)] = d2[x * 6 + 4]
            content1[(i * 6 + 129)] = d2[x * 6 + 5]
            x += 1
        }
        LogsAccessor.log("xxx c1: \(Data(d).hexEncodedString())")
        LogsAccessor.log("xxx c2: \(Data(d2).hexEncodedString())")
        LogsAccessor.log("newContent: \(Data(content1).hexEncodedString())")
        return content1
    }
    
    /// data 使用未解析的 344 (f127d)
    static func calibrationInfo2(fram: Data) -> CalibrationInfo {
        let b = 14 + 42
        let i1 = Libre2.readBits(fram, 26, 0, 3)
        let i2 = Libre2.readBits(fram, 26, 3, 0xa)
        let i3 = Libre2.readBits(fram, b, 0, 8)
        let i4 = Libre2.readBits(fram, b, 8, 0xe)
        let negativei3 = Libre2.readBits(fram, b, 0x21, 1) != 0
        let i5 = Libre2.readBits(fram, b, 0x28, 0xc) << 2
        let i6 = Libre2.readBits(fram, b, 0x34, 0xc) << 2

        return CalibrationInfo(i1: i1, i2: i2, i3: negativei3 ? -i3 : i3, i4: i4, i5: i5, i6: i6)
    }
}
