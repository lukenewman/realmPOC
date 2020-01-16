//
//  SignalRService.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import Foundation
import SwiftSignalRClient

extension Notification.Name {
    static let signalRHubDidConnect = Notification.Name(rawValue: "signalRHubDidConnect")
    static let signalRHubDidDisconnect = Notification.Name(rawValue: "signalRHubDidDisconnect")
}

enum HubType: String, CaseIterable {
    case playlists = "classUpdates"
    case library = "mediaLibrary"
    case instructor = "instructorUpdates"
}

protocol SignalRServiceDelegate: class {
    func didReceive(update: SignalRUpdate)
}

class SignalRService: NSObject {

    private(set) var hubConnection: HubConnection
    let hubType: HubType

    weak var delegate: SignalRServiceDelegate?

    let minimumReconnectDuration = 5.0
    lazy var reconnectDelay: TimeInterval = minimumReconnectDuration / 2.0
    var reconnectTimer: Timer?

    init(hubType: HubType) {
        self.hubType = hubType
        let urlString = SettingsManager.shared.environment.signalrURL + hubType.rawValue
        hubConnection = HubConnectionBuilder(url: URL(string: urlString)!).withLogging(minLogLevel: .debug).build()
        super.init()
        hubConnection.delegate = self
        hubConnection.start()
    }

    func reconnectWhenAppropriate() {
        Logger.log(#function, to: .signalr)
        guard !Stores.shared.isOffline else {
            Logger.log("offline - not attempting to reconnect", to: .signalr)
            return
        }

        reconnectDelay = fmin(reconnectDelay * 2.0, 600)
        Logger.log("entering reconnect delay (\(reconnectDelay) seconds)...", to: .signalr)

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay, repeats: false) { _ in
            Logger.log("restarting hub connection", to: .signalr)
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = nil
            self.hubConnection = HubConnectionBuilder(url: URL(string: SettingsManager.shared.environment.signalrURL + self.hubType.rawValue)!).withLogging(minLogLevel: .debug).build()
            self.hubConnection.delegate = self
            self.hubConnection.start()
        }
    }

    func reconnectImmediately() {
        Logger.log(#function, to: .signalr)
        reconnectDelay = minimumReconnectDuration / 2.0
        guard !Stores.shared.isOffline else {
            Logger.log("offline - not attempting to reconnect", to: .signalr)
            return
        }
        if let timer = reconnectTimer {
            Logger.log("firing timer", to: .signalr)
            timer.fire()
            reconnectTimer = nil
        } else {
            reconnectWhenAppropriate()
        }
    }

    @objc private func didGoOffline() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectDelay = minimumReconnectDuration / 2.0
    }

    @objc private func didComeOnline() {
        reconnectImmediately()
    }

}

extension SignalRService: HubConnectionDelegate {

    func connectionDidOpen(hubConnection: HubConnection) {
        Logger.log("\(self.hubType.rawValue) \(#function)", to: .signalr)

        hubConnection.invoke(method: "AddToGroupWithSessionId", arguments: ["InstructorId_\(API.shared.instructorID)", Stores.shared.sessionID]) { error in
            if let error = error {
                Logger.logError("error joining \(self.hubType.rawValue) group: \(error.localizedDescription)", to: .signalr)
            } else {
                Logger.log("successfully joined \(self.hubType.rawValue) group", to: .signalr)
            }
        }

        hubConnection.on(method: "Send") { (rawUpdate: String) in
            do {
                let update = try JSONDecoder().decode(SignalRUpdate.self, from: rawUpdate.data(using: .utf8)!)
                self.delegate?.didReceive(update: update)
                Logger.log("did receive \(self.hubType.rawValue) update \(update.id)", to: .signalr)
                self.hubConnection.invoke(method: "Ack", update.id, invocationDidComplete: { error in
                    if let error = error {
                        Logger.logError("error sending ack for \(self.hubType.rawValue) update \(update.id): \(error.localizedDescription)", to: .signalr)
                    }
                })
            } catch {
                Logger.logError("error receiving \(self.hubType.rawValue) update: \(error.localizedDescription)", to: .signalr)
            }
        }

        NotificationCenter.default.post(name: .signalRHubDidConnect, object: nil, userInfo: ["hubType": hubType])
    }

    func connectionDidFailToOpen(error: Error) {
        Logger.logError("\(self.hubType.rawValue) \(#function) with error \(error.localizedDescription)", to: .signalr)
        NotificationCenter.default.post(name: .signalRHubDidDisconnect, object: nil, userInfo: ["hubType": hubType])
        hubConnection.stop()
        reconnectWhenAppropriate()
    }

    func connectionDidClose(error: Error?) {
        if let error = error {
            Logger.logError("\(self.hubType.rawValue) \(#function) with error \(error.localizedDescription)", to: .signalr)
            NotificationCenter.default.post(name: .signalRHubDidDisconnect, object: nil, userInfo: ["hubType": hubType])
            hubConnection.stop()
            reconnectImmediately()
        } else {
//            Logger.log("\(self.hubType.rawValue) \(#function) without error", to: .signalr)
        }
    }

}

struct SignalRUpdate: Decodable {

    enum ChangeType: String, Decodable {
        case updated = "Updated"
        case deleted = "Deleted"
        case added = "Added"
    }

    var id: String
    var itemID: String
    var changeType: ChangeType

    enum CodingKeys: String, CodingKey {
        case id = "realTimeUpdateId"
        case itemID = "id"
        case changeType = "changeType"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        itemID = try values.decode(String.self, forKey: .itemID)

        let rawChangeType = try values.decode(String.self, forKey: .changeType)
        changeType = ChangeType(rawValue: rawChangeType) ?? .updated
    }

}

