//
//  Logger.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import os.log
import Foundation

class Logger {

    enum Category: String {
        case general, signalr, downloads, player, offline, auth, playlists, realm

        var log: OSLog {
            return OSLog(subsystem: "com.peloton.crescendo", category: self.rawValue)
        }
    }

    static func log(_ message: String, to category: Logger.Category = .general) {
        os_log("%{public}@", log: category.log, type: .info, message)
    }

    static func logError(_ message: String, to category: Logger.Category = .general) {
        os_log("%{public}@", log: category.log, type: .error, message)
    }

}

