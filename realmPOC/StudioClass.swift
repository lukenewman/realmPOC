//
//  StudioClass.swift
//  realmPOC
//
//  Created by Luke Newman on 1/14/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift

class StudioClass: Object, Decodable {

    enum ClassType: String, CaseIterable, Codable {
        case emergency, playlist, primary, secondary
    }

    override static func primaryKey() -> String? {
        return "id"
    }

    override class func indexedProperties() -> [String] {
        return ["classTypeRawValue", "classDetails.startDate"]
    }

    @objc dynamic var id: String = ""
    @objc dynamic var name: String = ""
    @objc private dynamic var classTypeRawValue: String = "playlist"
    var classType: ClassType {
        get {
            return ClassType(rawValue: classTypeRawValue)!
        }
        set {
            classTypeRawValue = newValue.rawValue
        }
    }

    let crossfade = RealmOptional<Int>()
    @objc dynamic var playlist: Playlist? = nil
    let playlistSongCount = RealmOptional<Int>()
    let playlistDuration = RealmOptional<Int>()
    @objc dynamic var classDetails: ClassDetails?
    @objc dynamic var workoutDetails: WorkoutDetails?

    var isPastClass: Bool {
        guard let startDate = classDetails?.startDate else { return false }
        return startDate < Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case crossfade, playlist, playlistSongCount, playlistDuration, studioClass, workout
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        classTypeRawValue = try values.decode(String.self, forKey: .type)

        let crossfade = try? values.decode(Int.self, forKey: .crossfade)
        self.crossfade.value = crossfade
        let tracks = try? values.decode([PlaylistItem].self, forKey: .playlist)
        playlist = Playlist(name: name, items: tracks)
        let playlistSongCount = try? values.decode(Int.self, forKey: .playlistSongCount)
        self.playlistSongCount.value = playlistSongCount
        let playlistDuration = try? values.decode(Int.self, forKey: .playlistDuration)
        self.playlistDuration.value = playlistDuration
        classDetails = try? values.decode(ClassDetails.self, forKey: .studioClass)
        workoutDetails = try? values.decode(WorkoutDetails.self, forKey: .workout)
    }

    required init() {

    }

    // for offline mode
//    init(with name: String, id: String) {
//        self.id = id
//        self.name = name
//        classType = .playlist
//        crossfade = SettingsManager.shared.crossfade
//        playlist = Playlist(name: name, items: [])
//        playlistSongCount = 0
//        playlistDuration = 0
//        classDetails = nil
//        workoutDetails = nil
//    }

    func updateStartWorkoutIndex(to newIndex: Int?) {
        if let oldIndex = workoutDetails?.startIndex {
            playlist?.items[oldIndex].isStartWorkoutTrack = false
        }
        if let index = newIndex {
            playlist?.items[index].isStartWorkoutTrack = true
            updateWorkoutDetails(with: newIndex)
        } else {
            workoutDetails = nil
        }
    }

    func updateWorkoutDetails(with newIndex: Int? = nil) {
        guard let playlist = playlist else { return }
        if let index = newIndex ?? workoutDetails?.startIndex {
            let preShowSongCount = index
            var preShowDuration = playlist.items[..<index].compactMap({$0.track?.duration}).reduce(0, +)
            let workoutSongCount = playlist.items.count - index
            var workoutDuration = playlist.items[index...].compactMap({$0.track?.duration}).reduce(0, +)
            if let crossfade = crossfade.value {
                preShowDuration -= max(crossfade * preShowSongCount, 0)
                workoutDuration -= max(crossfade * (workoutSongCount - 1), 0)
            }
            workoutDetails = WorkoutDetails(startIndex: index, preshowSongCount: preShowSongCount, preshowDuration: preShowDuration, workoutSongCount: workoutSongCount, workoutDuration: workoutDuration)
        }
    }

}

class ClassDetails: Object, Decodable {

    @objc dynamic var startDate: Date = Date()
    @objc private dynamic var fitnessDisciplineRawValue: String = "none"
    var fitnessDiscipline: DisciplineType {
        get {
            return DisciplineType(rawValue: fitnessDisciplineRawValue)
        }
        set {
            fitnessDisciplineRawValue = newValue.rawValue
        }
    }
    @objc private dynamic var difficultyRawValue: String = "beginner"
    var difficulty: ClassDifficulty {
        get {
            return ClassDifficulty(rawValue: difficultyRawValue)!
        }
        set {
            difficultyRawValue = newValue.rawValue
        }
    }

    enum CodingKeys: String, CodingKey {
        case startDate, fitnessDiscipline, difficulty
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let startDateISO = try values.decode(String.self, forKey: .startDate)

        guard let startDate = Formatters.iso8601Formatter.date(from: startDateISO) else {
            preconditionFailure("could not decode ISO date")
        }
        self.startDate = startDate

        self.difficultyRawValue = try values.decode(String.self, forKey: .difficulty)

        guard let discipline = try? values.decode(String.self, forKey: .fitnessDiscipline).lowercased() else {
            self.fitnessDisciplineRawValue = "none"
            return
        }
        self.fitnessDisciplineRawValue = discipline
    }

    required init() {

    }

}

class WorkoutDetails: Object, Decodable {

    @objc dynamic var startIndex: Int = 0
    @objc dynamic var preshowSongCount: Int = 0
    @objc dynamic var preshowDuration: Int = 0
    @objc dynamic var workoutSongCount: Int = 0
    @objc dynamic var workoutDuration: Int = 0

    init(startIndex: Int, preshowSongCount: Int, preshowDuration: Int, workoutSongCount: Int, workoutDuration: Int) {
        self.startIndex = startIndex
        self.preshowSongCount = preshowSongCount
        self.preshowDuration = preshowDuration
        self.workoutSongCount = workoutSongCount
        self.workoutDuration = workoutDuration
    }

    required init() {

    }

}

extension StudioClass {

    var formattedStartDate: String {
        guard let startDate = classDetails?.startDate else {
            return ""
        }
        return Formatters.startDateFormatter.string(from: startDate)
    }

}

extension StudioClass {

    var isEditable: Bool {
        // secondary and past class types are not editable
        if classType == .secondary || isPastClass {
            return false
        }

        // if there is no start time, it should be editable
        guard let startDate = classDetails?.startDate else { return true }

        // classes are editable if they haven't started yet
        return Date() < startDate
    }

}

enum ClassDifficulty: String, Codable {
    case beginner, intermediate, advanced

    var badge: UIImage {
        switch self {
        case .beginner:     return .difficultyBeginner
        case .intermediate: return .difficultyIntermediate
        case .advanced:     return .difficultyAdvanced
        }
    }
}

//
//  Playlist.swift
//  CrescendoMobile
//
//  Created by Luke Newman on 5/21/19.
//  Copyright © 2019 Peloton. All rights reserved.
//

import Foundation

class Playlist: Object {

    @objc dynamic var name: String = ""
    var items: [PlaylistItem] {
        get {
            return isSorted ? sortedItems : unsortedItems.map { $0 }
        }
        set {
            unsortedItems.removeAll()
            unsortedItems.insert(contentsOf: newValue, at: 0)
        }
    }
    var uniqueTracks: [Track] {
        return items.compactMap({ $0.track }).withoutDuplicates
    }
    @objc dynamic var crossfade = 0

    private let unsortedItems = List<PlaylistItem>()
    private var sortedItems: [PlaylistItem] = []
    var sortDescriptor: SortDescriptor? = nil {
        didSet {
            sort()
        }
    }
    var isSorted: Bool {
        return sortDescriptor != nil
    }

    var isEmpty: Bool {
        return unsortedItems.isEmpty
    }

    init(name: String, items: [PlaylistItem]?) {
        self.name = name
        self.unsortedItems.insert(contentsOf: items ?? [], at: 0)
    }

    required init() { }

    subscript(index: Int) -> PlaylistItem {
        get {
            return items[index]
        }
        set (newValue) {
            unsortedItems[index] = newValue
            sort()
        }
    }

    private func sort() {
        guard let sortBlock = sortDescriptor?.sortBlock else { return }
        sortedItems = unsortedItems.sorted(by: sortBlock)
    }

}

extension Playlist {

    func playlistItem(before item: PlaylistItem) -> PlaylistItem? {
        guard let baseIndex = items.firstIndex(of: item), baseIndex > 0 else {
            return nil
        }
        return items[items.index(before: baseIndex)]
    }

    func playlistItem(after item: PlaylistItem) -> PlaylistItem? {
        guard let baseIndex = items.firstIndex(of: item), baseIndex + 1 < items.count else {
            return nil
        }
        return items[items.index(after: baseIndex)]
    }

    // refreshes expired links for specified items or all items (if none specified)
    func refreshExpiredLinksIfNecessary(for items: [PlaylistItem]? = nil) {
        let itemsToRefresh = self.items

        guard !itemsToRefresh.isEmpty else { return }

        if let newURLsResult = ClassService.refreshTrackURLs(for: itemsToRefresh.compactMap { $0.track?.id }).wait(until: .distantFuture) {
            switch newURLsResult {
            case .success(let newURLs):
                for newURL in newURLs {
                    for item in itemsToRefresh {
                        if item.track?.id == newURL.guid {
                            item.track?.expiringURL = newURL.links
                        }
                    }
                }
            case .failure(let error):
                print("failure refreshing urls: \(error)")
            }
        }
    }

}

extension Array where Element: Equatable {

    func indexes(of element: Element) -> [Int] {
        return self.enumerated().filter({ element == $0.element }).map({ $0.offset })
    }

    var withoutDuplicates: [Element] {
        var uniqueValues: [Element] = []
        forEach { item in
            if !uniqueValues.contains(item) {
                uniqueValues += [item]
            }
        }
        return uniqueValues
    }

}

//
//  PlaylistItem.swift
//  CrescendoMobile
//
//  Created by Luke Newman on 2/25/19.
//  Copyright © 2019 Peloton. All rights reserved.
//

import Foundation

class PlaylistItem: Object, Decodable {

    @objc dynamic var id: String = ""
    @objc dynamic var track: Track? = nil
    @objc dynamic var isStartWorkoutTrack: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, track, isStartWorkoutTrack
    }

    init(id: String, track: Track, isStartWorkoutTrack: Bool = false) {
        self.id = id
        self.track = track
        self.isStartWorkoutTrack = isStartWorkoutTrack
    }

    init(track: Track) {
        self.id = track.id
        self.track = track
        self.isStartWorkoutTrack = false
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        id = try values.decode(String.self, forKey: .id)
        track = try values.decode(Track.self, forKey: .track)
        isStartWorkoutTrack = try values.decode(Bool.self, forKey: .isStartWorkoutTrack)
    }

    required init() {

    }

    static func ==(lhs: PlaylistItem, rhs: PlaylistItem) -> Bool {
        return lhs.id == rhs.id
    }

}

//
//  Track.swift
//  CrescendoMobile
//
//  Created by Carlos Vázquez on 4/29/19.
//  Copyright © 2019 Peloton. All rights reserved.
//

import Foundation
import Deferred

class TrackArtist: Object, Decodable {

    @objc dynamic var name: String = ""
    @objc dynamic var id: String = ""

    enum CodingKeys: String, CodingKey {
        case name = "artistName"
        case id = "artistGuid"
    }

}

class Track: Object, Decodable {

    @objc dynamic var id: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var expiringURL: ExpiringURL? = nil
    @objc dynamic var artistName: String = ""
    @objc dynamic var albumName: String = ""
    @objc dynamic var albumArt: AlbumArt? = nil
    @objc dynamic var duration: Int = 0
    @objc dynamic var isExplicit: Bool = false
    var bpm = RealmOptional<Int>()
    let genres = List<String>()
    @objc dynamic var year: Int = 0
    @objc dynamic var albumID: String? = nil
    let artists = List<TrackArtist>()
    @objc dynamic var metadataID: String = ""

    enum CodingKeys: String, CodingKey {
        case sourceURL = "streamingUrl"
        case id = "guid"
        case albumArt = "albumArtUrlMeta"
        case year = "releaseYear"
        case name, duration, albumName, artistName, isExplicit, bpm, genres, artists
        case expiringURL = "links"
        case albumID = "albumGuid"
        case metadataID = "metadataId"
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        expiringURL = try values.decode(ExpiringURL.self, forKey: .expiringURL)
        artistName = try values.decode(String.self, forKey: .artistName)
        albumName = try values.decode(String.self, forKey: .albumName)
        albumArt = try values.decode(AlbumArt.self, forKey: .albumArt)
        duration = try values.decode(Int.self, forKey: .duration)
        isExplicit = try values.decode(Bool.self, forKey: .isExplicit)
        let bpm = try values.decode(Int?.self, forKey: .bpm)
        self.bpm.value = bpm
        year = try values.decode(Int.self, forKey: .year)
        let genreObjects = try values.decode([Genre].self, forKey: .genres)
        genres.insert(contentsOf: genreObjects.map { $0.name }, at: 0)
        albumID = try values.decode(String?.self, forKey: .albumID)
        let artists = try values.decode([TrackArtist]?.self, forKey: .artists) ?? [] 
        self.artists.insert(contentsOf: artists, at: 0)
        metadataID = try values.decode(String.self, forKey: .metadataID)
    }

    required init() {

    }

    static func ==(lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Track {

    var bpmString: String {
        return "\(bpm.value ?? 0) BPM"
    }

    var durationString: String {
        return duration.durationString
    }

}

private class Genre: Decodable {
    var name: String
}

class ExpiringURL: Object, Decodable {

    @objc dynamic var urlString: String = ""
    var url: URL {
        get {
            return URL(string: urlString)!
        }
        set {
            urlString = newValue.absoluteString
        }
    }
    @objc dynamic var expirationDate: Date = Date()
    var value: URL? {
        get {
            return hasExpired ? nil : url
        }
    }

    var hasExpired: Bool {
        return expirationDate < Date()
    }

    enum CodingKeys: String, CodingKey {
        case expiration, m4a_256
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        urlString = try values.decode(String.self, forKey: .m4a_256)

        let expiration = try values.decode(String.self, forKey: .expiration)
        guard let expirationDate = Formatters.iso8601Formatter.date(from: expiration) else {
            preconditionFailure("could not decode ISO date")
        }
        self.expirationDate = expirationDate
    }

    required init() {

    }

}

class AlbumArt: Object, Codable {
    /**
     available sizes for images from the api
     - mini: 52x52
     - mid: 80x80
     - medium: 150x150
     - normal: 350x350
     - large: 700x700
     - big: 1400x1400
     - orig: Not normalized like the assets above
     - header: this is specifically for the header on browse. it does not have a size built into it.

     Source: https://pelotoncycle.slack.com/archives/GDB2K9JNS/p1547580553094100
     */
    enum Size: String, CaseIterable {
        case mid, mini, medium, normal, large, big, orig, header
    }

    @objc dynamic var urlString: String = ""
    var url: URL {
        get {
            return URL(string: urlString)!
        }
        set {
            urlString = newValue.absoluteString
        }
    }
    @objc dynamic var name: String? = nil

    enum CodingKeys: String, CodingKey {
        case urlString = "baseUrl",  name = "imageName"
    }

    func url(_ imageSize: Size) -> URL {
        // the header does not have sizing information and the url is complete and thus returned
        if imageSize == .header {
            return url
        }
        return url.appendingPathComponent(imageSize.rawValue + (name ?? ""))
    }

}

struct Formatters {

    static var durationFormatter: DateComponentsFormatter = {
        let df = DateComponentsFormatter()
        df.unitsStyle = .positional
        df.zeroFormattingBehavior = [.pad]
        df.allowedUnits = [.minute, .second]
        return df
    }()

    static var durationFormatterWithHours: DateComponentsFormatter = {
        let df = DateComponentsFormatter()
        df.unitsStyle = .positional
        df.zeroFormattingBehavior = [.pad]
        df.allowedUnits = [.hour, .minute, .second]
        return df
    }()

    static var iso8601Formatter: ISO8601DateFormatter = {
        return ISO8601DateFormatter()
    }()

    static var startDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d, h:mm a"
        return dateFormatter
    }()

    static var queryDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a MMM dd, yyyy"
        return dateFormatter
    }()

    static var lastPlayedDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yy"
        return dateFormatter
    }()

}

extension Int {

    var durationString: String {
        let interval = TimeInterval(self)
        guard !(interval.isNaN || interval.isInfinite),
            var timeString = TimeFormatter.durationFormatter.string(from: interval) else { return "0:00" }
        // pad with zero minutes if we only got a string with seconds
        if timeString.count == 2 {
            timeString.insert(contentsOf: "0:", at: timeString.startIndex)
        } else if timeString.count == 3 {
            // same story but with the minus sign
            timeString.insert(contentsOf: "0:", at: timeString.index(after: timeString.startIndex))
        }
        return timeString
    }

    var monthString: String {
        guard (1...12).contains(self) else { return "" }
        return DateFormatter().monthSymbols[self - 1]
    }

}

struct TimeFormatter {

    static var durationFormatter: DateComponentsFormatter = {
        let df = DateComponentsFormatter()
        df.zeroFormattingBehavior = [.dropLeading]
        df.allowedUnits = [.hour, .minute, .second]
        return df
    }()

}

struct PastClassMonth: Codable, Hashable {

    var month: Int
    var year: Int
    var count: Int

    private var monthInterval: DateInterval {
        let dateComponents = DateComponents(year: year, month: month)
        let monthDate = Calendar.current.date(from: dateComponents)!
        guard let interval = Calendar.current.dateInterval(of: .month, for: monthDate) else {
            preconditionFailure("could not get interval for past class month (\(year), month \(month))")
        }
        return interval
    }

}

extension PastClassMonth {

    var displayString: String {
        return "\(month.monthString) \(year)"
    }

    var startDate: Date {
        return monthInterval.start
    }

    var endDate: Date {
        return min(Calendar.current.startOfDay(for: Date()), monthInterval.end)
    }

}

enum DisciplineType: String, Decodable {

    case outdoor
    case running
    case strength
    case meditation
    case yoga
    case stretching
    case bootcamp
    case walking
    case cardio
    case cycling
    case none

    init(rawValue: String) {
        if rawValue.contains("cycling") {
            self = .cycling
        } else if rawValue.contains("running") {
            self = .running
        } else if rawValue.contains("meditation") {
            self = .meditation
        } else if rawValue.contains("yoga") {
            self = .yoga
        } else if rawValue.contains("walking") {
            self = .walking
        } else if rawValue.contains("cardio") {
            self = .cardio
        } else if rawValue.contains("stretching") {
            self = .stretching
        } else if rawValue.contains("strength") {
            self = .strength
        } else if rawValue.contains("bootcamp") || rawValue.contains("circuit") {
            self = .bootcamp
        } else if rawValue.contains("outdoor") {
            self = .outdoor
        } else {
            self = .none
        }
    }

    var image: UIImage {
        switch self {
        case .outdoor:       return .outdoor
        case .running:       return .running
        case .strength:      return .strength
        case .meditation:    return .meditation
        case .yoga:          return .yoga
        case .stretching:    return .stretching
        case .bootcamp:      return .bootcamp
        case .walking:       return .walking
        case .cardio:        return .cardio
        case .cycling:       return .cycling
        case .none:          return .disciplineIconPlaceholder
        }
    }

}

extension UIImage {
    static let browse = UIImage(named: "browse")!
    static let library = UIImage(named: "library")!
    static let classes = UIImage(named: "classes")!
    static let playlists = UIImage(named: "playlists")!
    static let search = UIImage(named: "search")!
    static let more = UIImage(named: "more")!
    static let playlistLarge = UIImage(named: "playlistLarge")!
    static let star = UIImage(named: "star")!
    static let close = UIImage(named: "close")!
    static let nowPlaying = UIImage(named: "nowPlaying")!
    static let check = UIImage(named: "check")!
    static let add = UIImage(named: "add")!
    static let back = UIImage(named: "back")!
    static let settings = UIImage(named: "settings")!
    static let playlistToolPlaceholder = UIImage(named: "playlistToolPlaceholder")!
    static let offline = UIImage(named: "offline")!
    static let online = UIImage(named: "online")!
    static let signalrOffline = UIImage(named: "signalr-offline")!
    static let signalrOnline = UIImage(named: "signalr-online")!
    static let tabBarGradient = UIImage(named: "tabBarGradient")!

    static let pause = UIImage(named: "pause")!
    static let play = UIImage(named: "play")!
    static let previous = UIImage(named: "previous")!
    static let skip = UIImage(named: "skip")!
    static let pauseLarge = UIImage(named: "pauseLarge")!
    static let playLarge = UIImage(named: "playLarge")!
    static let previousLarge = UIImage(named: "previousLarge")!
    static let skipLarge = UIImage(named: "skipLarge")!

    static let disciplineIconPlaceholder = UIImage(named: "disciplineIconPlaceholder")!
    static let outdoor = UIImage(named: "outdoor")!
    static let running = UIImage(named: "running")!
    static let strength = UIImage(named: "strength")!
    static let meditation = UIImage(named: "meditation")!
    static let yoga = UIImage(named: "yoga")!
    static let stretching = UIImage(named: "stretching")!
    static let bootcamp = UIImage(named: "bootcamp")!
    static let walking = UIImage(named: "walking")!
    static let cardio = UIImage(named: "cardio")!
    static let cycling = UIImage(named: "cycling")!

    static let playedRecently1 = UIImage(named: "played_recently_1")!
    static let playedRecently2 = UIImage(named: "played_recently_2")!
    static let playedRecently3 = UIImage(named: "played_recently_3")!

    static let difficultyAdvanced = UIImage(named: "difficulty_adv")!
    static let difficultyIntermediate = UIImage(named: "difficulty_int")!
    static let difficultyBeginner = UIImage(named: "difficulty_beg")!

}

struct SortDescriptor: Equatable {

    let sortType: SortType
    let ascending: Bool

    var title: String {
        switch sortType {
        case .mostRecent:   return "Most Recent (default)"
        case .popularity:   return "Popularity (default)"
        case .songName:     return ascending ? "Song (A to Z)" : "Song (Z to A)"
        case .artistName:   return ascending ? "Artist (A to Z)" : "Artist (Z to A)"
        case .songLength:   return ascending ? "Length (Short to Long)" : "Length (Long to Short)"
        case .bpm:          return ascending ? "BPM (Low to High)" : "BPM (High to Low)"
        case .year:         return ascending ? "Year (Old to New)" : "Year (New to Old)"
        case .none:         return "Default"
        }
    }

    var queryParameters: [API.QueryParameters : String] {
        return [
            .sortDirection : ascending ? "asc" : "desc",
            .sortField: sortType.queryValue
        ]
    }

    var sortBlock: (PlaylistItem, PlaylistItem) -> Bool {
        let baseBlock: (PlaylistItem, PlaylistItem) -> Bool = {
            switch self.sortType {
            case .songName:     return { $0.track?.name.lowercased() ?? "" < $1.track?.name.lowercased() ?? "" }
            case .artistName:   return { $0.track?.artistName.lowercased() ?? "" < $1.track?.artistName.lowercased() ?? "" }
            case .songLength:   return { $0.track?.duration ?? 0 < $1.track?.duration ?? 0 }
            case .bpm:          return { $0.track?.bpm.value ?? 0 < $1.track?.bpm.value ?? 0 }
            case .year:         return { $0.track?.year ?? 0 < $1.track?.year ?? 0 }
            case .mostRecent, .popularity:
                fatalError("these sort types cannot be locally sorted")
            case .none:
                fatalError("sortBlock should not be used for default sort order")
            }
        }()

        if ascending { return baseBlock }
        return { baseBlock($1, $0) }
    }

}

enum SortType: String {
    case mostRecent
    case popularity
    case songName
    case artistName
    case songLength
    case bpm
    case year
    case none

    var queryValue: String {
        switch self {
        case .mostRecent:   return "date-added"
        case .popularity:   return self.rawValue
        case .songName:     return "track-name"
        case .artistName:   return "artist-name"
        case .songLength:   return "duration"
        case .bpm:          return self.rawValue
        case .year:         return self.rawValue
        case .none:         return ""
        }
    }

}
