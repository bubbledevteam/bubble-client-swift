//
//  PreLibre2.swift
//  DiaBox
//
//  Created by Yan Hu on 2020/8/17.
//  Copyright © 2020 DiaBox. All rights reserved.
//

import Foundation

/// for libre2 to decrypt 344 data like libre1 data
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

    public static func LibreProDecryptData(proIndex: Int, c1: [UInt8], c2: [UInt8]) -> [UInt8] {
        var content: [UInt8] =
            [72,41,152,23,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,150,116,0,31,110,4,200,164,28,128,106,4,200,148,92,0,101,4,200,152,28,128,89,4,200,148,28,128,81,4,200,84,28,128,80,4,200,116,28,128,77,4,200,128,28,128,79,4,200,148,28,128,77,4,200,144,28,128,63,4,200,164,28,128,59,4,200,164,28,128,57,4,200,192,28,128,53,4,200,12,29,128,48,4,200,20,29,128,44,4,200,4,29,128,37,4,200,204,28,128,183,4,200,116,90,128,180,4,200,144,90,128,179,4,200,132,154,128,170,4,200,240,90,128,172,4,200,244,154,128,151,4,200,12,155,128,126,4,200,32,155,128,114,4,200,52,91,128,128,4,200,48,155,128,124,4,200,64,91,128,83,4,200,92,28,128,37,4,200,128,91,128,40,4,200,228,91,128,25,4,200,184,28,128,247,3,200,44,30,128,202,3,200,104,93,128,215,3,200,80,28,128,229,3,200,192,27,128,236,3,200,212,91,128,120,4,200,200,91,128,57,4,200,156,91,128,202,3,200,44,28,128,143,3,200,164,92,0,119,3,200,60,92,128,118,3,200,100,28,128,197,3,200,32,92,128,109,4,200,220,155,128,172,4,200,220,91,128,149,4,200,196,91,128,156,4,200,240,91,128,110,4,200,164,28,128,181,4,200,180,90,128,224,31,0,0,194,77,0,8,20,9,24,81,20,7,150,128,90,0,237,166,12,98,26,200,4,28,218,110]
        let d: [UInt8] = Array(c1[80 ..< 97 + 80])
        let d2: [UInt8] = Array(c2[proIndex ..< 192 + proIndex])
        var n = 0
        var i = 0
        content[316] = c1[74]
        content[317] = c1[75]
        content[27] = 0
        content[26] = 0
        let indexTrend = Int(content[26])
        let trend = (256 * Int(c1[77]) + Int(c1[76])) & 0xffff
        LogsAccessor.log("indexTrend: \(indexTrend), trend: \(trend)")
        for index in 0 ..< 16 {
            n = ((trend + 16) - index) % 16
            i = indexTrend - index - 1
            if i < 0 {
                i += 16
            }
            LogsAccessor.log("n: \(i), i: \(n)")
            let start = i * 6 + 28
            let start1 = n * 6 + 0
            content.replaceSubrange(start ..< start + 6, with: d[start1 ..< start1 + 6])
        }
        content.replaceSubrange(124 ..< 124 + 192, with: d2[0 ..< 192])
        LogsAccessor.log("before bytesWithCorrectCRC: \(Data(content).hexEncodedString())")
        return Crc.bytesWithCorrectCRC(data: content)
    }
    
    public static func bytesWithCorrectCRC(_ bytes: [UInt8]) -> [UInt8] {
        let calculatedCrc = Crc.crc16(Array(bytes.dropFirst(2)), seed: 0xffff)
        
        var correctedBytes = bytes
        correctedBytes[0] = UInt8(calculatedCrc >> 8)
        correctedBytes[1] = UInt8(calculatedCrc & 0x00FF)
        return correctedBytes
    }
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
    
    /// data 使用未解析的 344
    static func calibrationInfo2(fram: Data) -> CalibrationInfo {
        let b = 14 + 42
        let i1 = readBits(fram, 26, 0, 3)
        let i2 = readBits(fram, 26, 3, 0xa)
        let i3 = readBits(fram, b, 0, 8)
        let i4 = readBits(fram, b, 8, 0xe)
        let negativei3 = readBits(fram, b, 0x21, 1) != 0
        let i5 = readBits(fram, b, 0x28, 0xc) << 2
        let i6 = readBits(fram, b, 0x34, 0xc) << 2

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
    
    public static func readHistoricalValues(data: Data, calibrationInfo: CalibrationInfo) -> [GlucoseData] {
//        let startIndex = readBits(data, 27, 0, 8)
        let indexHistory = Int(data[27])
        var histories = [GlucoseData]()
        let sensorTime = Int(data[317]) << 8 + Int(data[316])
        for index in 0 ..< 32 {
            var i = indexHistory - index - 1
            if (i < 0) { i += 32 }
//            let address = ((i + startIndex + 32) % 32) * 6 + 124
            let address = i * 6 + 124
            let value = readGlucoseValue(data, address, index, calibrationInfo)
            let time = abs((sensorTime - 3) / 15) * 15 - index * 15
            if sensorTime - time >= sensorTime {
                continue
            }
            value.timeStamp = Date().adding(.minute, value: time - sensorTime)
            LogsAccessor.log("hs: raw: \(value.glucoseLevelRaw), ts: \(value.timeStamp.localString())")
            histories.append(value)
        }
        return histories
    }
    
    public static func readTrendValues(data: Data, calibrationInfo: CalibrationInfo) -> GlucoseData {
        let startIndex = readBits(data, 26, 0, 8)
        let indexTrend = Int(data[26])
        let i = indexTrend - 0 - 1
        let address = i * 6 + 28
        let value = readGlucoseValue(data, address, i, calibrationInfo)
        LogsAccessor.log("current: raw: \(value.glucoseLevelRaw), ts: \(value.timeStamp.localString()), address: \(address), startIndex: \(startIndex)")
        return value
    }
    
    public static func readGlucoseValue(_ data: Data, _ offset: Int, _ i: Int, _ calibrationInfo: CalibrationInfo) -> GlucoseData {

        var temperatureAdjustment = (readBits(data, offset, 0x26, 0x9) << 2)
        let negativeAdjustment = readBits(data, offset, 0x2f, 0x1) != 0
        if negativeAdjustment {
            temperatureAdjustment = -temperatureAdjustment
        }
        let value = readBits(data, offset, 0, 0xe)
        let temperature = readBits(data, offset, 0x1a, 0xc) << 2;
        let glucose = GlucoseData(timeStamp: Date(), glucoseLevelRaw: 0)
        glucose.rawGlucose = value
        glucose.rawTemperature = temperature
        glucose.temperatureAdjustment = temperatureAdjustment
        
        _ = glucoseValueFromRaw(raw: glucose, calibrationInfo: calibrationInfo)
        return glucose
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

        let g1 = 65 * Double(raw.rawGlucose ?? 0 - calibrationInfo.i3) / Double(calibrationInfo.i4 - calibrationInfo.i3)
        let g2 = pow(1.045, 32.5 - temperature)
        let g3 = g1 * g2

        let v1 = t1[calibrationInfo.i2 - 1]
        let v2 = t2[calibrationInfo.i2 - 1]
        var value = round((g3 - v1) / v2)
        if value.isNaN {
            value = 0
        }
        
        raw.glucoseLevelRaw = value
        raw.originValue = value
        return raw
    }
    
    static func parseBLEData( _ data: Data, info: CalibrationInfo) -> (glucoses: [GlucoseData], wearTimeMinutes: Int) {
        
        var bleGlucose: [GlucoseData] = []
        let wearTimeMinutes = Int(Word(data[41], data[40]))
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
            LogsAccessor.log("i:\(i) id:\(idValue) raw: \(glucose.glucoseLevelRaw), rawGlucose: \(glucose.rawGlucose ?? 0), rawTemperature: \(temperature), date: \(date)")
            bleGlucose.append(glucose)
        }
        
        if let current = bleGlucose.first {
            let count = bleGlucose.count
            var histories = [GlucoseData]()
            for i in (count - historyCount) ..< count {
                histories.append(bleGlucose[i])
            }
            bleGlucose = LibreOOPClient.split(current: current, glucoseData: histories.reversed())
            bleGlucose.first?.rawGlucose = current.rawGlucose
            bleGlucose.first?.rawTemperature = current.rawTemperature
        }
        
        return (bleGlucose, wearTimeMinutes)
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

public struct CalibrationInfo: Equatable, Codable {
   var i1: Int
   var i2: Int
   var i3: Int
   var i4: Int
   var i5: Int
   var i6: Int
 }
