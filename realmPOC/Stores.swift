//
//  Stores.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let didLogIn = Notification.Name(rawValue: "didLogIn")
    static let didLogOut = Notification.Name(rawValue: "didLogOut")
    static let didDownloadDisciplineIcons = Notification.Name(rawValue: "didDownloadDisciplineIcons")

    static let didGoOffline = Notification.Name(rawValue: "didGoOffline")
    static let didComeOnline = Notification.Name(rawValue: "didComeOnline")

    static let signalrDidLoseConnection = Notification.Name(rawValue: "signalrDidLoseConnection")
    static let signalrDidReconnect = Notification.Name(rawValue: "signalrDidReconnect")
}

class Stores {

    static let shared = Stores()

    private(set) var playlistStore: PlaylistStore!

    private(set) var isOffline: Bool = false
    private(set) var sessionID: String = ""

    private var disconnectedHubs: Set<HubType> = []

    func initialize() {
        Logger.log("stores initializing", to: .signalr)
        sessionID = UUID().uuidString

        playlistStore = PlaylistStore()
        playlistStore.fetchUpcomingClasses()

        SettingsManager.shared.setUpSignalR()

        NotificationCenter.default.addObserver(self, selector: #selector(hubDidConnect(_:)), name: .signalRHubDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hubDidDisconnect(_:)), name: .signalRHubDidDisconnect, object: nil)
    }

    func tearDown() {
        Logger.log("stores tearing down", to: .signalr)
        sessionID = ""

        playlistStore?.signalRConnection.hubConnection.stop()
        playlistStore = nil
        SettingsManager.shared.signalRConnection.hubConnection.stop()
    }

    func reconnectSignalRIfNecessary() {
        for disconnectedHub in disconnectedHubs {
            switch disconnectedHub {
            case .playlists:    playlistStore?.signalRConnection.reconnectWhenAppropriate()
            case .library:      break
            case .instructor:   SettingsManager.shared.signalRConnection?.reconnectWhenAppropriate()
            }
        }
    }

    @objc private func hubDidConnect(_ notif: Notification) {
        guard let hubType = notif.userInfo?["hubType"] as? HubType else {
            preconditionFailure("expected to have hubType in signalr notification info")
        }
        disconnectedHubs.remove(hubType)
        if disconnectedHubs.isEmpty {
            NotificationCenter.default.post(name: .signalrDidReconnect, object: nil)
        }
    }

    @objc private func hubDidDisconnect(_ notif: Notification) {
        guard let hubType = notif.userInfo?["hubType"] as? HubType else {
            preconditionFailure("expected to have hubType in signalr notification info")
        }
        disconnectedHubs.insert(hubType)
        NotificationCenter.default.post(name: .signalrDidLoseConnection, object: nil)
    }

}

