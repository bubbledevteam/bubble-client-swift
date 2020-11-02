//
//  LibreDerivedAlgorithmRunner.swift
//  SwitftOOPWeb
//
//  Created by Bjørn Inge Berg on 18.10.2018.
//  Copyright © 2018 Bjørn Inge Berg. All rights reserved.
//
// adapted by Johan Degraeve for xdrip ios
import Foundation

public struct LibreDerivedAlgorithmParameters: Codable, CustomStringConvertible {
    public var slope_slope: Double
    public var slope_offset: Double
    public var offset_slope: Double
    public var offset_offset: Double
    public var serialNumber: String?
    
    // change the parameters when version changed
    public var version: Int? = 4
    
    public var versionChanged: Bool {
        let p = LibreDerivedAlgorithmParameters.init(slope_slope: 0, slope_offset: 0, offset_slope: 0, offset_offset: 0)
        return p.version != version
    }
    
    public var description: String {
        return """
        LibreDerivedAlgorithmParameters::
        slopeslope: \(slope_slope),
        slopeoffset: \(slope_offset),
        offsetoffset: \(offset_offset),
        offsetSlope: \(offset_slope),
        version: \(version ?? -1)
        """
    }
    
    var isErrorParameters: Bool {
        return slope_slope == 0 &&
            slope_offset == 0 &&
            offset_slope == 0 &&
            offset_offset == 0
    }
    
    public init(slope_slope: Double, slope_offset:Double, offset_slope: Double, offset_offset: Double) {
        self.slope_slope = slope_slope
        self.slope_offset = slope_offset
        self.offset_slope = offset_slope
        self.offset_offset = offset_offset
    }
}

