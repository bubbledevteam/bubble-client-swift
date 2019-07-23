//
//  ShareService.swift
//  Loop
//
//  Created by Nate Racklyeft on 7/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit
import os.log

// Encapsulates the Dexcom Share client service and its authentication
public class BubbleService: ServiceAuthentication {
    public var credentialValues: [String?]

    public let title: String = LocalizedString("BubbleService", comment: "The title of the BubbleService")
    
   

    public init( accessToken: String?, url: URL?) {
        os_log("dabear: BubbleService init here")
        credentialValues = [
            accessToken,
            url?.absoluteString
        ]
        
        
        if let accessToken = accessToken, let url = url {
            isAuthorized = true
        }
        
       
        
    }
    
    public var accessToken: String? {
        return credentialValues[0]
    }
    
    public var url: URL? {
        guard let urlString = credentialValues[1] else {
            return nil
        }
        
        return URL(string: urlString)
    }

    public var isAuthorized: Bool = false

    public func verify(_ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        
        guard let accessToken = accessToken, let url = url else {
            completion(false, nil)
            return
        }
        
        let client = LibreOOPClient(accessToken: accessToken, site: url.absoluteString)
        
        client.verifyToken { (success) in
            var error : Error? = nil
            if !success {
                error = LibreError.invalidAutoCalibrationCredentials
            }
            completion(success, error)
        }
        
    }

    public func reset() {
        os_log("dabear:: Bubbleservice reset called")
        isAuthorized = false
        //client = nil
    }
    
    deinit {
        os_log("dabear:: Bubbleservice deinit called")
        //client?.disconnect()
        //client = nil
    }
}
let AutoCalibrateWebServiceLabel = "LibreOOPWebClient1"

extension KeychainManager {
    public func setAutoCalibrateWebAccessToken(accessToken: String?, url: URL?) throws {
        let credentials: InternetCredentials?
        
        if let accessToken = accessToken, let url = url {
            credentials = InternetCredentials(username: "whatever", password: accessToken, url: url)
        } else {
            credentials = nil
        }
    
        try replaceInternetCredentials(credentials, forLabel: AutoCalibrateWebServiceLabel)
    }
    
    public func getAutoCalibrateWebCredentials() -> (accessToken: String, url: URL)? {
        do { // Silence all errors and return nil
            do {
                let credentials = try getInternetCredentials(label: AutoCalibrateWebServiceLabel)
                
                return (accessToken: credentials.password, url: credentials.url)
            }
        } catch {
            return nil
        }
    }
}



extension BubbleService {
    public convenience init(keychainManager: KeychainManager = KeychainManager()) {
        if let (accessToken, url) = keychainManager.getAutoCalibrateWebCredentials() {
            self.init(accessToken: accessToken, url: url)
        } else {
            self.init(accessToken: nil, url: nil)
        }
    }
}

