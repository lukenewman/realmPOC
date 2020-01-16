//
//  SettingsManager.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import Foundation

extension Notification.Name {
    static var BPMVisibilityChanged = Notification.Name(rawValue: "com.crescendo.bpmVisibility.Notification")
    static var crossfadeChanged = Notification.Name(rawValue: "com.crescendo.crossfade.Notification")
    static let classDisplayChanged = Notification.Name(rawValue: "com.crescendo.classDisplay.Notification")
}

final class SettingsManager {

    static let shared = SettingsManager()

    private(set) var signalRConnection: SignalRService!

    private init() { }

    func setUpSignalR() {
        signalRConnection = SignalRService(hubType: .instructor)
        signalRConnection.delegate = self
    }

    var isBPMNeededInPlaylist: Bool {
        get {
            if let preference = UserDefaults.standard.value(forKey: #function) as? Bool {
                return preference
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: #function)
            NotificationCenter.default.post(Notification(name: .BPMVisibilityChanged))
        }
    }

    var crossfade: Int {
        get {
            return UserDefaults.standard.integer(forKey: #function)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: #function)
            NotificationCenter.default.post(Notification(name: .crossfadeChanged))
        }
    }

    var environment: Environment {
        get {
            guard let value = UserDefaults.standard.string(forKey: #function) else {
                UserDefaults.standard.set(Environment.production.rawValue, forKey: #function)
                return .production
            }

            guard let environment = Environment(rawValue: value) else {
                preconditionFailure("Unable to create Environment from raw value \(value)")
            }

            return environment
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: #function)
            API.updateBaseURL()
        }
    }

    var isRemovingPastClassDownloads: Bool {
        get {
            return UserDefaults.standard.bool(forKey: #function)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: #function)
        }
    }

    var isLoggedIn: Bool {
        get {
            return UserDefaults.standard.bool(forKey: #function)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: #function)
        }
    }

}

extension SettingsManager: SignalRServiceDelegate {

    func didReceive(update: SignalRUpdate) {
//        if let email = instructor?.email {
//            InstructorService.getInstructor(with: email).upon { result in
//                switch result {
//                case .success(let instructor):
//                    self.crossfade = instructor.defaultCrossfade
//                    self.classDisplayType = instructor.defaultClassDisplay
//                case .failure(let error):
//                    Logger.log("failed to refresh instructor from signalr update: \(error.localizedDescription)", to: .signalr)
//                }
//            }
//        } else {
//            Logger.log("received instructor update but did not have instructor email to refetch defaults", to: .signalr)
//        }
    }

}


