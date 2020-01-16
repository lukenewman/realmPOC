//
//  ClassService.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import Foundation
import Deferred

struct PagingInfo: Decodable {
    let pageIndex: Int
    let pageSize: Int
    let totalResults: Int
    let totalPages: Int
}

struct ClassListResponse: Decodable {
    let pagingInfo: PagingInfo
    let data: [StudioClass]
}

typealias FetchClassesTask = Task<ClassListResponse>
typealias FetchClassDetailTask = Task<StudioClass>
typealias FetchPlaylistDetailTask = FetchClassDetailTask
typealias FetchPastClassMonthsTask = Task<[PastClassMonth]>
typealias UpdateClassTask = Task<StudioClass>
typealias UpdatePlaylistTask = UpdateClassTask

class ClassService: BaseService {

    // MARK: - Fetching

    static func fetchClassList(for pastClassMonth: PastClassMonth? = nil) -> FetchClassesTask {
        let startDate = pastClassMonth?.startDate ?? Calendar.current.startOfDay(for: Date())
        let endDate = pastClassMonth?.endDate ?? startDate.addingTimeInterval(Double(14 * 24 * 60 * 60))

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.current

        let queries = [
            API.QueryParameters.instructorId: API.shared.instructorID,
            API.QueryParameters.pageSize: "100",
            API.QueryParameters.startDate: dateFormatter.string(from: startDate),
            API.QueryParameters.endDate: dateFormatter.string(from: endDate),
            API.QueryParameters.sortField: "startDate",
            API.QueryParameters.classType: "primary|secondary"
        ]

        return networkTask(endpoint: .classList, parameters: queries)
    }

    static func fetchClassDetail(for id: String) -> FetchClassDetailTask {
        return networkTask(endpoint: .classDetail(id))
    }

    static func fetchPastClassMonths() -> FetchPastClassMonthsTask {
        let queries = [ API.QueryParameters.instructorId: API.shared.instructorID ]
        return networkTask(endpoint: .pastClasses, parameters: queries)
    }

    static func fetchPlaylists(page: Int = 0) -> FetchClassesTask {
        let queries = [
            API.QueryParameters.instructorId: API.shared.instructorID,
            API.QueryParameters.pageIndex: "\(page)",
            API.QueryParameters.classType: "playlist",
            API.QueryParameters.sortField: "creationDate",
            API.QueryParameters.sortAscending: "false"
        ]
        return networkTask(endpoint: .classList, parameters: queries)
    }

    static func fetchEmergencyPlaylist() -> FetchClassesTask {
        let queries = [
            API.QueryParameters.instructorId: API.shared.instructorID,
            API.QueryParameters.classType: "emergency"
        ]
        return networkTask(endpoint: .classList, parameters: queries)
    }

    // MARK: - Updating

    @discardableResult static func updateName(for classID: String, to newName: String) -> UpdateClassTask {
        let body = UpdateNameBody(value: newName)
        return updateNetworkTask(endpoint: .updateName(classID), body: body)
    }

    @discardableResult static func updateCrossfade(for classID: String, to newCrossfade: Int) -> UpdateClassTask {
        let body = UpdateCrossfadeBody(value: newCrossfade)
        return updateNetworkTask(endpoint: .updateCrossfade(classID), body: body)
    }

    @discardableResult static func addPlaylistItems(for classID: String, with items: [Track]) -> UpdateClassTask {
        let body = AddPlaylistItemsBody(items.map { $0.id })
        return updateNetworkTask(endpoint: .addPlaylistItems(classID), body: body)
    }

    @discardableResult static func removePlaylistItems(for classID: String, with items: [PlaylistItem]) -> UpdateClassTask {
        return updateNetworkTask(endpoint: .removePlaylistItems(classID), body: items.map { $0.id })
    }

    @discardableResult static func reorderPlaylistItems(for classID: String, to items: [PlaylistItem]) -> UpdateClassTask {
        return updateNetworkTask(endpoint: .reorderPlaylistItems(classID), body: items.map { $0.id })
    }

    @discardableResult static func updateStartWorkoutIndex(for classID: String, to newIndex: Int?) -> UpdateClassTask {
        let body = UpdateStartWorkoutIndexBody(value: newIndex)
        return updateNetworkTask(endpoint: .updateStartWorkoutIndex(classID), body: body)
    }

    // MARK: - Creating

    @discardableResult static func createPlaylist(with name: String) -> UpdateClassTask {
        let body = CreatePlaylistBody(instructorId: API.shared.instructorID, name: name)
        return updateNetworkTask(endpoint: .createPlaylist, body: body)
    }

    // MARK: - Deleting

    @discardableResult static func deletePlaylist(with classID: String) -> Task<Void> {
        return deleteNetworkTask(endpoint: .deleteClass(classID))
    }

    // MARK: - Refreshing Track URLs

    static func refreshTrackURLs(for trackIDs: [String]) -> Task<[RefreshExpiringURLResponse]> {
        return updateNetworkTask(endpoint: .refreshTrackURLs, body: trackIDs)
    }

}

struct UpdateNameBody: Encodable {
    let value: String
}

struct AddPlaylistItemsBody: Encodable {
    let trackGuids: [String]
    let insertIndex: Int? = nil

    init(_ tracks: [String]) {
        trackGuids = tracks
    }
}

struct UpdateCrossfadeBody: Encodable {
    let value: Int?
}

struct UpdateStartWorkoutIndexBody: Encodable {
    let value: Int?
}

struct CreatePlaylistBody: Encodable {
    let instructorId: String
    let name: String
}

struct RefreshExpiringURLResponse: Decodable {
    let guid: String
    let links: ExpiringURL
}
