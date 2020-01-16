//
//  PlaylistStore.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import Foundation
import Deferred
import RealmSwift

protocol PlaylistStoreObserver: NSObject {
    func playlistsDidLoad()
    func playlistsDidFailToLoad(with error: Error)

    func upcomingClassesDidLoad()
    func upcomingClassesDidFailToLoad(with error: Error)

    func playlistWasUpdated(_ playlist: StudioClass)
    func playlistWasAdded()
    func playlistWasDeleted(_ id: String)

    func upcomingClassWasUpdated(_ upcomingClass: StudioClass)
    func upcomingClassWasAdded()
    func upcomingClassWasDeleted(_ id: String)
}

class PlaylistStore {

//    private(set) var playlists: SafeArray<StudioClass> = SafeArray()
//    private var emergencyPlaylist: StudioClass?
//
//    private(set) var upcomingClasses: SafeArray<StudioClass> = SafeArray()
//    var upcomingClassesWithoutSecondaryClasses: [StudioClass] {
//        return upcomingClasses.filter { $0.classType == .primary }
//    }

    private var observers: [PlaylistStoreObserver] = []

    private(set) var signalRConnection: SignalRService

    init() {
        self.signalRConnection = SignalRService(hubType: .playlists)
        self.signalRConnection.delegate = self
    }

    func addObserver(_ observer: PlaylistStoreObserver) {
        observers.append(observer)
    }

    func removeObserver(_ observer: PlaylistStoreObserver) {
        guard let index = observers.firstIndex(where: { $0 == observer }) else { return }
        observers.remove(at: index)
    }

//    fileprivate func playlistUpdated(playlist: StudioClass) {
//        switch playlist.classType {
//        case .playlist, .emergency:
//            guard let updatedIndex = self.playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
//            playlists[updatedIndex] = playlist
//        case .primary, .secondary:
//            guard let updatedIndex = self.upcomingClasses.firstIndex(where: { $0.id == playlist.id }) else { return }
//            upcomingClasses[updatedIndex] = playlist
//        }
//        observers.forEach { $0.playlistWasUpdated(playlist) }
//        Player.shared.playlistWasUpdated(to: playlist.playlist)
//    }

//    func pastClasses(for month: PastClassMonth) -> [StudioClass] {
//        var pastClassesCopy: [StudioClass]!
//        pastClassesQueue.sync {
//          pastClassesCopy = self.pastClasses[month] ?? []
//        }
//        return pastClassesCopy
//    }
//
//    func studioClass(with id: String) -> StudioClass? {
//        if emergencyPlaylist?.id == id {
//            return emergencyPlaylist
//        }
//
//        if let playlist = playlists.first(where: { $0.id == id }) {
//            return playlist
//        }
//
//        if let studioClass = upcomingClasses.first(where: { $0.id == id }) {
//            return studioClass
//        }
//
//        return nil
//    }

}

// MARK: - Upcoming Classes Loading

extension PlaylistStore {

    func fetchUpcomingClasses() {
        ClassService.fetchClassList().upon { result in
            switch result {
            case .success(let classListResponse):
//                self.upcomingClasses = SafeArray(classListResponse.data)
//                classListResponse.data.forEach { upcomingClass in
//                    self.fetchPlaylistDetail(for: upcomingClass)
//                }
                let classes = classListResponse.data
                do {
                    let realm = try Realm()
                    try realm.write {
                        for studioClass in classes {
                            realm.create(StudioClass.self, value: studioClass, update: .modified)
                        }
                    }
                    Logger.log("realm write succeeded", to: .realm)
                } catch {
                    Logger.log("realm write error: \(error.localizedDescription)", to: .realm)
                }
                self.observers.forEach { $0.upcomingClassesDidLoad() }
            case .failure(let error):
                self.observers.forEach { $0.upcomingClassesDidFailToLoad(with: error) }
            }
        }
    }

}

// MARK: - SignalRService Delegate

extension PlaylistStore: SignalRServiceDelegate {

    func didReceive(update: SignalRUpdate) {
//        switch update.changeType {
//        case .added:
//            ClassService.fetchClassDetail(for: update.itemID).upon { result in
//                switch result {
//                case .success(let newPlaylist):
//                    if newPlaylist.classType == .secondary {
//                        Logger.log("received 'added' update for secondary class with id \(newPlaylist.id)", to: .signalr)
//                    }
//                    switch newPlaylist.classType {
//                    case .playlist:
//                        // if this playlist is the api-created playlist of one that was created offline
//                        // (offline-created playlist has id of 'name')
//                        if let indexOfPlaylistCreatedOffline = self.playlists.firstIndex(where: {
//                            $0.name == newPlaylist.name && $0.id == newPlaylist.name.replacingOccurrences(of: " /\\-", with: "")
//                        }) {
//                            self.playlists[indexOfPlaylistCreatedOffline] = newPlaylist
//                        } else {
//                            let insertionIndex = self.emergencyPlaylist == nil ? 0 : 1
//                            self.playlists.insert(newPlaylist, at: insertionIndex)
//                        }
//                    case .primary, .secondary:
//                        self.upcomingClasses.append(newPlaylist)
//                        self.upcomingClasses.sort { (class1, class2) in
//                            guard let date1 = class1.classDetails?.startDate, let date2 = class2.classDetails?.startDate else { return false }
//                            return date1 < date2
//                        }
//                        return
//                    default:
//                        return
//                    }
//                    self.observers.forEach { $0.playlistWasAdded() }
//                case .failure(let error):
//                    Analytics.shared.track(.failedToFetchDetailForNewlyAdded, properties: ["id": update.itemID, "error": error.localizedDescription])
//                }
//            }
//        case .deleted:
//            self.observers.forEach { $0.playlistWasDeleted(update.itemID) }
//            if let playlistIndex = self.playlists.firstIndex(where: { $0.id == update.itemID }) {
//                self.playlists.remove(at: playlistIndex)
//            } else if let classIndex = self.upcomingClasses.firstIndex(where: { $0.id == update.itemID }) {
//                self.upcomingClasses.remove(at: classIndex)
//            } else {
//                Analytics.shared.track(.receivedDeletedUpdateForUnknownPlaylist, properties: ["id": update.itemID])
//            }
//        case .updated:
//            ClassService.fetchClassDetail(for: update.itemID).upon { result in
//                switch result {
//                case .success(let playlist):
//                    // do we already have this secondary class in upcoming classes?
//                    // then we can assume that a studio is making changes to it
//                    if playlist.classType == .secondary && self.upcomingClasses.firstIndex(where: { $0.id == playlist.id }) == nil {
//                        Logger.log("received 'updated' update for secondary class with id \(playlist.id)", to: .signalr)
//                        // otherwise...
//                        // the only update we're notified of in a secondary playlist is the submission of it
//                        // in that case, we remove it from playlists and stick it in the upcoming classes
//                        guard let updatedIndex = self.playlists.firstIndex(where: { $0.id == playlist.id }) else {
//                            Logger.log("secondary class was created but could not find the old playlist index", to: .signalr)
//                            return
//                        }
//                        self.playlists.remove(at: updatedIndex)
//                        self.upcomingClasses.append(playlist)
//                        self.upcomingClasses.sort {
//                            guard let date1 = $0.classDetails?.startDate, let date2 = $1.classDetails?.startDate else {
//                                return false
//                            }
//                            return date1 < date2
//                        }
//                        self.observers.forEach { $0.playlistWasDeleted(playlist.id) }
//                        self.observers.forEach { $0.upcomingClassWasAdded() }
//                    } else {
//                        self.playlistUpdated(playlist: playlist)
//                    }
//                case .failure(let error):
//                    Analytics.shared.track(.couldNotFetchDetailForUpdatedPlaylist, properties: ["id": update.itemID, "error": error.localizedDescription])
//                }
//            }
//        }
    }

}

