//
//  API.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import Foundation

enum HTTPMethod: String {
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case get = "GET"
    case delete = "DELETE"
}

enum Environment: String, CaseIterable {

    case qa, staging, production

    var displayValue: String {
        switch self {
        case .qa:           return "QA"
        case .staging:      return "Staging"
        case .production:   return "Production"
        }
    }

    var url: String {
        switch self {
        case .qa:           return "https://api-qa.pelomusic.io/api"
        case .staging:      return "https://api-staging.pelomusic.io/api"
        case .production:   return "https://api.pelomusic.io/api"
        }
    }

    var signalrURL: String {
        switch self {
        case .qa:           return "https://rtu-qa.pelomusic.io/"
        case .staging:      return "https://rtu-staging.pelomusic.io/"
        case .production:   return "https://rtu.pelomusic.io/"
        }
    }

}

class API {

    static private(set) var shared = API()

    private init() {
        baseURL = SettingsManager.shared.environment.url
//        instructorID = SettingsManager.shared.instructor?.id ?? ""
    }

    static func updateBaseURL() {
        API.shared.baseURL = SettingsManager.shared.environment.url
    }

    private var baseURL: String!
    private let apiKey = "63219d6c-da7d-4d22-98f6-df1c1804090b"

    private(set) var instructorID = ""

//    func update(for instructor: Instructor) {
//        instructorID = instructor.id
//    }

    var defaultHeader: [String: String] {
        let build = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        return [
            "api-key": API.shared.apiKey,
            "MUSIC_APP_VERSION": build ?? "unknown build",
            "X-UID": instructorID,
//            "X-Session-Id": Stores.shared.sessionID
        ]
    }

    enum SearchType {
        case artists, albums, songs, all, genre
    }

    enum ArtistMediaType {
        case albums(id: String)
        case tracks(id: String)
    }

    enum Endpoint {
        case classList
        case classDetail(_ id: String)
        case updateName(_ id: String)
        case updateCrossfade(_ id: String)
        case addPlaylistItems(_ id: String)
        case removePlaylistItems(_ id: String)
        case reorderPlaylistItems(_ id: String)
        case updateStartWorkoutIndex(_ id: String)
        case updateClassPlan(_ id: String)
        case createPlaylist
        case deleteClass(_ id: String)
        case pastClasses
        case library
        case addToLibrary
        case removeFromLibrary
        case search(_ type: SearchType)
        case artist(mediaType: ArtistMediaType)
        case album(id: String)
        case playlistTools
        case playlistToolsTracks(id: String)
        case featured
        case refreshTrackURLs
        case instructor(email: String)
        case albumDetails(_ id: String)
        case updateInstructorPreferences
        case songMetadata

        var urlString: String {
            switch self {
            case .classList:                        return API.shared.baseURL + "/v2/classes"
            case .classDetail(let id):              return API.shared.baseURL + "/v2/classes/\(id)"
            case .updateName(let id):               return API.shared.baseURL + "/v2/classes/\(id)/name"
            case .updateCrossfade(let id):          return API.shared.baseURL + "/v2/classes/\(id)/crossfade"
            case .addPlaylistItems(let id):         return API.shared.baseURL + "/v2/classes/\(id)/addPlaylistItems"
            case .removePlaylistItems(let id):      return API.shared.baseURL + "/v2/classes/\(id)/removePlaylistItems"
            case .reorderPlaylistItems(let id):     return API.shared.baseURL + "/v2/classes/\(id)/reorderPlaylistItems"
            case .updateStartWorkoutIndex(let id):  return API.shared.baseURL + "/v2/classes/\(id)/startWorkoutIndex"
            case .updateClassPlan(let id):          return API.shared.baseURL + "/v2/classes/\(id)/classPlan"
            case .createPlaylist:                   return API.shared.baseURL + "/v2/classes"
            case .deleteClass(let id):              return API.shared.baseURL + "/v2/classes/\(id)"
            case .pastClasses:                      return API.shared.baseURL + "/v2/classes/MonthsWithClasses"
            case .library, .removeFromLibrary:      return API.shared.baseURL + "/MediaLibraries"
            case .addToLibrary:                     return API.shared.baseURL + "/MediaLibraries/Bulk"
            case .search(let type):                 return API.shared.baseURL + searchPath(for: type)
            case .artist(let mediaType):            return API.shared.baseURL + artistMediaPath(forType: mediaType)
            case .album(let albumId):               return API.shared.baseURL + "/Products/GetAlbum/\(albumId)"
            case .playlistTools:                    return API.shared.baseURL + "/CuratedContent/GetPlaylists"
            case .playlistToolsTracks(let id):      return API.shared.baseURL + "/CuratedContent/GetPlaylistTracks/\(id)"
            case .featured:                         return API.shared.baseURL + "/CuratedContent"
            case .refreshTrackURLs:                 return API.shared.baseURL + "/Products/file_links"
            case .instructor(let email):            return API.shared.baseURL + "/instructors/GetByEmail/\(email)"
            case .albumDetails(let albumID):        return API.shared.baseURL + "/Products/GetAlbum/\(albumID)"
            case .updateInstructorPreferences:      return API.shared.baseURL + "/instructors/\(API.shared.instructorID)/preferences"
            case .songMetadata:                     return API.shared.baseURL + "/instructors/\(API.shared.instructorID)/songmetadata"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .classList:                        return .get
            case .classDetail:                      return .get
            case .updateName:                       return .patch
            case .updateCrossfade:                  return .patch
            case .addPlaylistItems:                 return .patch
            case .removePlaylistItems:              return .patch
            case .reorderPlaylistItems:             return .patch
            case .updateStartWorkoutIndex:          return .patch
            case .updateClassPlan:                  return .patch
            case .createPlaylist:                   return .post
            case .deleteClass:                      return .delete
            case .pastClasses:                      return .get
            case .library:                          return .get
            case .addToLibrary:                     return .post
            case .removeFromLibrary:                return .delete
            case .search:                           return .get
            case .artist, .album:                   return .get
            case .playlistTools:                    return .get
            case .featured:                         return .get
            case .playlistToolsTracks:              return .get
            case .refreshTrackURLs:                 return .post
            case .instructor:                       return .get
            case .albumDetails:                     return .get
            case .updateInstructorPreferences:      return .patch
            case .songMetadata:                     return .get
            }
        }

        var shouldCache: Bool {
            switch self {
            case .updateInstructorPreferences, .removeFromLibrary, .updateName, .updateCrossfade, .addPlaylistItems, .removePlaylistItems, .reorderPlaylistItems, .updateStartWorkoutIndex, .updateClassPlan, .createPlaylist, .deleteClass:
                return true
            default: return false
            }
        }

        private func searchPath(for type: SearchType) -> String {
            switch type {
            case .artists:                          return "/Search/Artists"
            case .albums:                           return "/Search/Albums"
            case .songs:                            return "/Search/Tracks"
            case .all:                              return "/Search/All"
            case .genre:                            return "/Search/Genres"
            }
        }

        private func artistMediaPath(forType type: ArtistMediaType) -> String {
            switch type {
            case .albums(let id):                   return "/artists/Albums/\(id)"
            case .tracks(let id):                   return "/artists/Tracks/\(id)"
            }
        }
    }

    enum QueryParameters: String {
        case startDate, endDate, instructorId, classType
        case pageSize, pageIndex, query, numberOfItems, lastId, updatedPartialFitnessClass
        case upToSecondsFromEpoch
        case sortField, sortAscending
        case minBPM, maxBPM, minDuration, maxDuration, minYear, maxYear, genre
        case sortDirection
        case requests
    }
}

