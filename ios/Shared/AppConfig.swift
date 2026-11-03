import Foundation

/// The values of apple/App.xcconfig, as the build wrote them into this
/// target's Info.plist. A missing key is a broken build, not a state to
/// recover from, so it stops at once with the key's name.
enum AppConfig {
  static let supabaseURL = url("AppSupabaseURL")
  static let supabaseKey = string("AppSupabaseKey")
  static let webGame = url("AppWebURL")
  static let maxPilots = Int(string("AppMaxPilots")) ?? 4
  static let urlScheme = string("AppURLScheme")
  static let group = string("AppGroup")

  private static func string(_ key: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty
    else { fatalError("\(key) is missing from Info.plist, see apple/App.xcconfig") }
    return value
  }

  private static func url(_ key: String) -> URL {
    guard let url = URL(string: string(key)) else {
      fatalError("\(key) in Info.plist is no address, see apple/App.xcconfig")
    }
    return url
  }
}
