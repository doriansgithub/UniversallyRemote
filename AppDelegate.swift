import UIKit
import MultipeerConnectivity

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        RemotePeerManager.shared.startBrowsing()
        print("✅ UniversallyRemote launched and browsing for peers")
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        RemotePeerManager.shared.stopBrowsing()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
//        RemotePeerManager.shared.stopBrowsing()
        RemotePeerManager.shared.startBrowsing()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController as? UINavigationController,
               let mainVC = rootVC.viewControllers.first as? ViewController {
                mainVC.autoSelectOrPromptServer()
            }
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("⏸️ App moving to background")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("▶️ App became active again")
    }
}

enum BrowseLevel {
    case genres
    case artists(String)  // genre
    case albums(String)   // artist
    case songs(String)    // album
}

var currentLevel: BrowseLevel = .genres


let globalGenres: [String] = [ "Acid Jazz", "Acoustic", "Afrobeat", "Afrobeats", "Alt-Country", "Alt-Jazz", "Alternative", "Ambient", "Americana", "Anime", "Arabesque", "Avant-Garde", "Bachata", "Baila", "Baroque", "Bebop", "Bhangra", "Bluegrass", "Blues", "Bollywood", "Boogie-Woogie", "Bossa Nova", "Breakbeat", "Cajun", "Calypso", "Celtic", "Chamber Music", "Chanson", "Chillwave", "Chiptune", "Christian", "Chutney", "Classic Rock", "Classical", "Classical Music", "Country", "Crunk", "Cumbia", "Dance", "Dancehall", "Darkwave", "Disco", "Dixieland", "Doo-Wop", "Downtempo", "Drone", "Drum & Bass", "Dub", "Dubstep", "EDM", "Easy Listening", "Electro", "Electroacoustic", "Electronic", "Electropop", "Emo", "Experimental", "Flamenco", "Folk", "Funk", "Funk Carioca", "G-Funk", "Garage", "Glam Rock", "Gospel", "Gqom", "Grime", "Grunge", "Hard Rock", "Hardcore", "Hardstyle", "Heavy Metal", "Highlife", "Hip-Hop", "House", "IDM", "Indie", "Industrial", "Instrumental", "Italo Disco", "J-Pop", "Jazz", "Jit", "K-Pop", "Kizomba", "Kwaito", "Lambada", "Latin", "Lounge", "Lovers Rock", "Mambo", "Mariachi", "Merengue", "Metal", "Minimal", "Morna", "Musique Concrète", "Nederpop", "Neo-Soul", "New Age", "No Wave", "Nu Jazz", "Opera", "Polka", "Pop", "Pop Rock", "Progressive", "Psytrance", "Punk", "R&B", "Rap", "Reggae", "Rock", "Salsa", "Samba", "Shoegaze", "Ska", "Soca", "Soft Rock", "Soul", "Soundtrack", "Spoken Word", "Synthwave", "Techno", "Trance", "Trap", "Trip-Hop", "Tropical", "Vaporwave", "World", "Zouk" ]


let genreArtwork: [String: String] = [
    "": "HomeGenreRnB",
    "Alternative": "HomeGenrePopRock",
    "Blues": "HomeGenreBlues",
    "Brass": "HomeGenreBrass",
    "Choral": "HomeGenreReligious",
    "Christian": "HomeGenreReligious",
    "Classical": "HomeGenreClassical",
    "Classic Rock": "HomeGenreRock",
    "Comedy": "HomeGenreComedy",
    "Country": "HomeGenreCountry",
    "EDM": "HomeGenreEDM",
    "Easy Listening": "HomeGenreEasyListening",
    "Electronica": "HomeGenreDance",
    "Folk": "HomeGenreFolk",
    "Fusion": "HomeGenreJazz",
    "Glam Metal": "HomeGenreMetal",
    "Grunge": "HomeGenreHardRock",
    "Hard & Heavy": "HomeGenreMetal",
    "Hard Rock": "HomeGenreHardRock",
    "Heavy": "HomeGenreMetal",
    "Hip-Hop": "HomeGenreHipHop",
    "Holidays": "HomeGenreHolidays",
    "Horns": "HomeGenreHorns",
    "House": "HomeGenreHouse",
    "Indie": "HomeGenreIndie",
    "Instrumental Latin": "HomeGenreLatin",
    "Instrumental Rock": "HomeGenreRock",
    "Jazz": "HomeGenreJazz",
    "Latin": "HomeGenreLatin",
    "Metal": "HomeGenreMetal",
    "New Age": "HomeGenreNewAge",
    "Opera": "HomeGenreOpera",
    "Other": "HomeGenreRnB",
    "Podcast": "HomeGenreRnB",
    "Pop": "HomeGenrePop",
    "Pop Rock": "HomeGenrePopRock",
    "Punk": "HomeGenrePunk",
    "R&B": "HomeGenreRnB",
    "Reggae": "HomeGenreReggae",
    "Religious": "HomeGenreReligious",
    "Rock": "HomeGenreRock",
    "Russian Pop": "HomeGenrePop",
    "Russian Rock": "HomeGenreRock",
    "Singer-Songwriter": "HomeGenreRnB",
    "Soft Rock": "HomeGenrePopRock",
    "Soul": "HomeGenreSoul",
    "Soundtrack": "HomeGenreClassical",
    "Spiritual": "HomeGenreSpiritual",
    "Spoken Audio": "HomeGenreRnB",
    "Strings": "HomeGenreStrings",
    "Traditional": "HomeGenreOpera",
    "Trance": "HomeGenreDance",
    "Unknown": "HomeGenreSpiritual",
    "Various": "HomeGenreSpiritual",
    "World": "HomeGenreNewAge"
]

let genreVCMappings: [String: [String]] = [
    "Alternative": ["Alternative", "alternative", "Indie Rock", "indie rock"],
    "Blues": ["Blues", "blues"],
    "Brass": ["Saxophone", "saxophone", "Trumpet", "trumpet", "Trombone", "trombone", "Cornet", "cornet", "Alto Horn", "alto horn", "Baritone Horn", "baritone horn", "Flugelhorn", "flugelhorn", "Mellophone", "mellophone", "Euphonium", "euphonium", "Tuba", "tuba", "French Horn", "french horn"],
    "Choral": ["Chorus", "chorus", "Choral", "choral", "Choir", "choir"],
    "Christian": ["Christian & Gospel", "christian & gospel", "Christian Gospel", "christian gospel", "Gospel", "gospel", "Christian", "christian"],
    "Classical": ["Classical", "classical", "Classical Music", "classical music", "Orchestral", "orchestral", "Symphony", "symphony", "Symphonic", "symphonic"],
    "Comedy": ["Comedy", "comedy"],
    "Country": ["Country", "country", "Country & Folk", "country & folk", "Country Folk", "country folk"],
    "EDM": ["EDM/Dance", "edm/dance", "EDM", "edm", "Dance", "dance", "Disco", "disco"],
    "Easy Listening": ["Easy Listening", "easy listening", "Lounge", "lounge"],
    "Electronica": ["Electronica", "electronica", "Electronic", "electronic", "IDM", "idm"],
    "Folk": ["Folk", "folk"],
    "Fusion": ["Fusion", "fusion"],
    "Glam Metal": ["Glam Metal", "glam metal"],
    "Hard & Heavy": ["Hard & Heavy", "hard & heavy", "Hard Heavy", "hard heavy"],
    "Hard Rock": ["Hard Rock", "hard rock", "Rock", "rock", "Rock & Roll", "rock & roll", "Rock & roll", "rock & Roll"],
    "Heavy": ["Heavy", "heavy", "Death Metal", "death metal", "Speed Metal", "speed metal"],
    "Hip-Hop": [
        "Hip Hop", "hip hop", "HipHop", "hiphop", "Hip", "hip",
        "Hip Hop Rap", "hip hop rap", "Hip HopRap", "hip hoprap", "HipHopRap", "hiphoprap",
        "Rap", "rap",
        "Hip Hop / Rap", "hip hop / rap", "Hip Hop/Rap", "hip hop/rap", "Hip-Hop/Rap", "hip-hop/rap"
    ],
    "Holidays": ["Holidays", "holidays", "Holiday", "holiday", "Christmas", "christmas", "Christmas Carol", "christmas carol"],
    "House": ["House", "house", "Trance", "trance", "Liquid", "liquid"],
    "Indie": ["Indie", "indie"],
    "Instrumental Latin": ["Instrumental Latin", "instrumental latin"],
    "Instrumental Rock": ["Instrumental Rock", "instrumental rock"],
    "Jazz": ["Jazz", "jazz", "Jazz Rock", "jazz rock"],
    "Latin": ["Salsa", "salsa", "Merengue", "merengue", "Bachata", "bachata", "Calipso", "calipso", "Bolero", "bolero", "Rumba", "rumba", "Mambo", "mambo", "Cha Cha Cha", "cha cha cha", "ChaChaCha", "chachacha", "Danzon", "danzon", "Bossa Nova", "bossa nova", "Tango", "tango", "Mariachi", "mariachi", "Ranchera", "ranchera", "Cumbia", "cumbia", "Norteño", "norteño", "Norteno", "norteno", "Banda", "banda", "Tejano", "tejano", "Reggaeton", "reggaeton", "Latin", "latin", "Pop Latino", "pop latino"],
    "Metal": ["Metal", "metal", "Heavy Metal", "heavy metal"],
    "New Age": ["New Age", "new age"],
    "Opera": ["Opera", "opera", "Chamber", "chamber", "Choral", "choral", "Chant", "chant"],
    "Other": ["Other", "other"],
    "Podcast": ["Podcast", "podcast"],
    "Pop": ["Pop", "pop"],
    "Pop Rock": ["Pop Rock", "pop rock", "Rock/Pop", "rock/pop", "pop Rock", "Pop rock", "RockPop", "rockpop"],
    "Punk": ["Punk", "punk"],
    "R&B": [
        "R&B", "r&b", "RnB", "rnb", "RNB", "rnb", "R B", "r b", "RB", "rb",
        "R & B", "r & b", "Rhythm & Blues"
    ],
    "Reggae": ["Reggae", "reggae"],
    "Religious": ["Religious", "religious", "Christian", "christian", "Catholic", "catholic", "Islam", "islam", "Muslim", "muslim", "Hindu", "hindu", "Buddhist", "buddhist", "Spiritual", "spiritual"],
    "Russian Pop": ["Russian Pop", "russian pop", "Russian Rock", "russian rock"],
    "Singer-Songwriter": ["Singer-Songwriter", "singer-songwriter", "SingerSongwriter", "singersongwriter", "Singer/Songwriter"],
    "Soft Rock": [
        "Soft Rock", "soft rock", "Classic Rock", "classic rock", "Grunge", "grunge"],
    "Soul": ["Soul", "soul", "Funk", "funk"],
    "Soundtrack": ["Soundtrack", "soundtrack"],
    "Spiritual": ["Spiritual", "spiritual"],
    "Spoken Audio": ["Spoken Audio", "spoken audio", "Spoken & Audio"],
    "Strings": ["Violin", "violin", "Cello", "cello"],
    "Traditional": ["Traditional", "traditional"],
    "Trance": ["Trance", "trance", "Psytrance", "psytrance", "Tech Trance", "tech trance"],
    "Unknown": ["Unknown", "unknown"],
    "Various": ["Various", "various"],
    "World": ["World", "world"]
]

// Flattened list to ensure all possible genres are included
let allGenres = Set(globalGenres + genreVCMappings.values.flatMap { $0 })

let genreEQMap: [String: Int] = [
    "Acoustic": 0,
    "Alternative": 1,
    "Adult Alternative": 1,
    "Blues": 2,
    "Classical": 3,
    "Classical Music": 3,
    "Country": 4,
    "Country & Folk": 4,
    "Dance": 5,
    "Func": 5,
    "Easy Listening": 6,
    "Electronic": 7,
    "Electronica": 7,
    "Trance": 7,
    "HipHop": 8,
    "Hip Hop / Rap": 8,
    "Hip Hop/Rap": 8,
    "Hip-Hop/Rap": 8,
    "Rap": 8,
    "Reggaeton": 8,
    "R&B" : 8,
    "R & B" : 8,
    "R&B/Soul" : 8,
    "Rhythm & Blues": 8,
    "Industrial": 9,
    "Jazz": 10,
    "Jazz Rock": 10,
    "Jazz Traditional": 10,
    "Saxophone": 10,
    "Fusion": 10,
    "Christian": 10,
    "Christmas": 10,
    "Holiday": 10,
    "Latin": 11,
    "Instrument Latin": 11,
    "Metal": 12,
    "Heavy Metal": 13,
    "Heavy": 13,
    "Speed Metal": 13,
    "Death Metal": 13,
    "Glam Metal": 13,
    "New Age": 14,
    "Singer/Songwriter": 14,
    "Opera": 15,
    "Chorus": 15,
    "Pop": 16,
    "Various": 16,
    "Soundtrack": 16,
    "Pop Latino": 16,
    "Other": 16,
    "Reggae": 17,
    "Rock Classic": 18,
    "Classic Rock": 18,
    "Indie Rock": 18,
    "Hard Rock": 19,
    "Rock": 19,
    "rock": 19,
    "Rock & Roll": 19,
    "Grunge": 19,
    "Instrumental Rock": 19,
    "Pop Rock": 20,
    "Rock Pop": 20,
    "Rock/Pop": 20,
    "Pop/Rock": 20,
    "Soft Rock": 21,
    "Russian Rock": 21,
    "Rock Soft": 21,
    "Russian Pop": 20,
    "Spoken Word": 22,
    "Spoken & Audio": 22,
    "Podcast": 22,
    "World": 23,
    "Worldwide": 23,
]
