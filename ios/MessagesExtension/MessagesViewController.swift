import Messages
import SwiftUI
import UIKit

/// Panzergefecht inside a Messages chat. The extension only invites: it
/// posts a bubble with a fresh room, and whoever taps it lands in that room
/// in the app, where the lobby gives everybody their own tank. The game
/// itself never runs in here, Flutter and Flame would not fit the memory of
/// a Messages extension.
final class MessagesViewController: MSMessagesAppViewController {
  private var hosting: UIHostingController<ChatView>?

  override func willBecomeActive(with conversation: MSConversation) {
    super.willBecomeActive(with: conversation)
    show(conversation)
  }

  override func didSelect(_ message: MSMessage, conversation: MSConversation) {
    super.didSelect(message, conversation: conversation)
    show(conversation)
  }

  override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
    super.didTransition(to: presentationStyle)
    if let conversation = activeConversation {
      show(conversation)
    }
  }

  private func show(_ conversation: MSConversation) {
    let view = ChatView(
      // Tapping a bubble opens the extension expanded with that message.
      invite: presentationStyle == .expanded
        ? conversation.selectedMessage.flatMap(Invite.init(message:)) : nil,
      sentByMe: conversation.selectedMessage.flatMap(Invite.init(message:))
        .map { Invite.hosted.contains($0.room) } ?? false,
      others: conversation.remoteParticipantIdentifiers.count,
      send: { [weak self] mode in self?.send(mode, in: conversation) },
      open: { [weak self] invite, host in self?.openGame(invite, host: host) }
    )
    if let hosting {
      hosting.rootView = view
      return
    }
    let controller = UIHostingController(rootView: view)
    controller.view.backgroundColor = .clear
    addChild(controller)
    controller.view.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(controller.view)
    NSLayoutConstraint.activate([
      controller.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      controller.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      controller.view.topAnchor.constraint(equalTo: self.view.topAnchor),
      controller.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
    ])
    controller.didMove(toParent: self)
    hosting = controller
  }

  /// The invitation waiting in the input field until the player sends it.
  private var staged: Invite?

  /// Puts the invitation into the input field, where the player can add a
  /// line and send it. Messages stages it there even when asked to send
  /// right away.
  private func send(_ mode: Invite.Mode, in conversation: MSConversation) {
    let invite = Invite(room: Invite.newRoom(), mode: mode)
    staged = invite
    conversation.insert(invite.message()) { [weak self] error in
      if error != nil {
        DispatchQueue.main.async { self?.staged = nil }
      }
    }
    requestPresentationStyle(.compact)
  }

  /// Once the invitation goes out, the sender follows it into the room, as
  /// its host: the one who invites picks the mode, the others follow.
  override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
    super.didStartSending(message, conversation: conversation)
    guard let invite = staged, Invite(message: message)?.room == invite.room else { return }
    staged = nil
    Invite.rememberHosted(invite.room)
    openGame(invite, host: true)
  }

  override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
    super.didCancelSending(message, conversation: conversation)
    staged = nil
  }

  /// Messages lets an extension open its own app only, and only while the
  /// app sits on the home screen. Otherwise the bubble's link still opens
  /// the browser game.
  private func openGame(_ invite: Invite, host: Bool) {
    extensionContext?.open(invite.appURL(host: host)) { [weak self] opened in
      DispatchQueue.main.async {
        if opened {
          self?.dismiss()
        } else {
          self?.hosting?.rootView.failed = true
        }
      }
    }
  }
}

/// A round offered in a chat: the room everybody meets in and the mode the
/// host starts. It travels in the bubble's link, the same `?room=` link the
/// game shares everywhere else.
struct Invite {
  enum Mode: String, CaseIterable {
    case multi, flag, defense, duel

    var title: String {
      switch self {
      case .multi: "Last Tank Standing"
      case .flag: "Capture the Flag"
      case .defense: tr("Tower Defense zu zweit", "Tower defense together")
      case .duel: tr("Stützpunkt-Duell", "Base duel")
      }
    }

    var detail: String {
      switch self {
      case .multi: tr("Jeder gegen jeden, der letzte Panzer gewinnt", "Everyone against everyone, the last tank wins")
      case .flag: tr("Rot gegen Blau, CPU-Panzer füllen auf", "Red against blue, CPU tanks fill up")
      case .defense: tr("Gemeinsam gegen die Wellen", "Together against the waves")
      case .duel: tr("Jeder baut seinen Stützpunkt, wer hält länger?", "Each builds a base, who holds out longer?")
      }
    }

    var symbol: String {
      switch self {
      case .multi: "scope"
      case .flag: "flag.2.crossed"
      case .defense: "shield.lefthalf.filled"
      case .duel: "arrow.left.arrow.right"
      }
    }

    /// Picture in the bubble: the battlefield or the road of the waves.
    var picture: String { self == .multi || self == .flag ? "InviteBattle" : "InviteDefense" }

    /// What a chat offers: the defense needs exactly two, a group fights.
    static func offered(others: Int) -> [Mode] {
      others == 1 ? [.defense, .duel, .multi] : [.multi, .flag]
    }
  }

  /// The browser game, which the apps also open by universal link.
  static let webGame = URL(string: "https://www.regetskcob.de/wargame/play/")!

  /// Tanks per room, the default of `MAX_PILOTS` in `lib/src/app/env.dart`.
  static let maxPilots = 4

  let room: String
  let mode: Mode

  init(room: String, mode: Mode) {
    self.room = room
    self.mode = mode
  }

  init?(message: MSMessage) {
    guard let url = message.url,
          let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
          let room = items.first(where: { $0.name == "room" })?.value,
          let mode = items.first(where: { $0.name == "mode" })?.value.flatMap(Mode.init(rawValue:))
    else { return nil }
    self.init(room: room, mode: mode)
  }

  /// Rooms this device sent invitations for, newest last. Tapping one of
  /// them again leads back in as the host. The participant identifiers of
  /// Messages would say the same, but the simulator hands out a different
  /// one for the sender of a message than for the local player.
  static var hosted: [String] {
    UserDefaults.standard.stringArray(forKey: hostedKey) ?? []
  }

  static func rememberHosted(_ room: String) {
    UserDefaults.standard.set(Array((hosted + [room]).suffix(20)), forKey: hostedKey)
  }

  private static let hostedKey = "hostedRooms"

  /// The same alphabet as the game's room codes, without look-alikes.
  static func newRoom() -> String {
    let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    return String((0..<5).map { _ in alphabet.randomElement()! })
  }

  private var query: [URLQueryItem] {
    [URLQueryItem(name: "room", value: room), URLQueryItem(name: "mode", value: mode.rawValue)]
  }

  /// The link in the bubble. Without the app it opens the browser game.
  var webURL: URL {
    var components = URLComponents(url: Invite.webGame, resolvingAgainstBaseURL: false)!
    components.queryItems = query
    return components.url!
  }

  /// The app's own scheme, which an extension may open. [host] marks the
  /// sender, who starts the round in the chosen mode.
  func appURL(host: Bool) -> URL {
    var components = URLComponents()
    components.scheme = "panzergefecht"
    components.host = "play"
    components.queryItems = query + (host ? [URLQueryItem(name: "host", value: "1")] : [])
    return components.url!
  }

  func message() -> MSMessage {
    let layout = MSMessageTemplateLayout()
    layout.image = UIImage(named: mode.picture)
    layout.caption = "Panzergefecht · \(mode.title)"
    layout.subcaption = tr("Tippen und mitspielen", "Tap to join")
    layout.trailingSubcaption = tr("Raum \(room)", "Room \(room)")
    // One session per round, so a later result can replace this bubble.
    let message = MSMessage(session: MSSession())
    message.layout = layout
    message.url = webURL
    message.summaryText = "Panzergefecht: \(mode.title)"
    return message
  }
}

/// German on German devices, English everywhere else, like the game.
func tr(_ german: String, _ english: String) -> String {
  // The extension carries no localizations of its own, so Locale.current
  // would always fall back to English.
  Locale.preferredLanguages.first?.hasPrefix("de") == true ? german : english
}

/// Colours of the training ground, as `GameColors` in `lib/src/theme.dart`.
private enum Palette {
  static let background = Color(red: 0x16 / 255, green: 0x1C / 255, blue: 0x0F / 255)
  static let surface = Color(red: 0x2A / 255, green: 0x35 / 255, blue: 0x20 / 255)
  static let olive = Color(red: 0x8A / 255, green: 0x9A / 255, blue: 0x5B / 255)
  static let amber = Color(red: 1, green: 0xB3 / 255, blue: 0)
  static let text = Color(red: 0xE6 / 255, green: 0xE2 / 255, blue: 0xD3 / 255)
  static let textDim = Color(red: 0xBF / 255, green: 0xC6 / 255, blue: 0xAA / 255)
}

struct ChatView: View {
  /// The invitation the player tapped, nil while choosing a new one.
  let invite: Invite?
  let sentByMe: Bool
  /// Everybody else in the chat. Messages hides who they are.
  let others: Int
  let send: (Invite.Mode) -> Void
  let open: (Invite, Bool) -> Void
  /// The app could not be opened, so it is missing or not on the home screen.
  var failed = false

  var body: some View {
    ZStack {
      Palette.background.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          if let invite {
            join(invite)
          } else {
            choose
          }
          if failed {
            Text(tr(
              "Die App Panzergefecht muss installiert sein und auf dem Home-Bildschirm liegen. Ohne App öffnet die Nachricht das Spiel im Browser.",
              "The Panzergefecht app has to be installed and on the home screen. Without it the message opens the game in the browser."
            ))
            .font(.footnote)
            .foregroundStyle(Palette.amber)
          }
        }
        .padding(16)
      }
    }
  }

  private var choose: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(others == 1
        ? tr("Panzergefecht zu zweit", "Panzergefecht for two")
        : tr("Panzergefecht für den Chat", "Panzergefecht for the chat"))
        .font(.headline)
        .foregroundStyle(Palette.text)
      ForEach(Invite.Mode.offered(others: others), id: \.self) { mode in
        Button { send(mode) } label: { row(mode) }
          .buttonStyle(.plain)
      }
      if others + 1 > Invite.maxPilots {
        Text(tr(
          "Ein Raum fasst \(Invite.maxPilots) Panzer, wer später kommt, schaut zu.",
          "A room holds \(Invite.maxPilots) tanks, whoever comes later watches."
        ))
        .font(.footnote)
        .foregroundStyle(Palette.textDim)
      }
    }
  }

  private func row(_ mode: Invite.Mode) -> some View {
    HStack(spacing: 12) {
      Image(systemName: mode.symbol)
        .font(.title3)
        .foregroundStyle(Palette.amber)
        .frame(width: 32)
      VStack(alignment: .leading, spacing: 2) {
        Text(mode.title).font(.subheadline.bold()).foregroundStyle(Palette.text)
        Text(mode.detail).font(.caption).foregroundStyle(Palette.textDim)
      }
      Spacer(minLength: 0)
      Image(systemName: "paperplane.fill").foregroundStyle(Palette.olive)
    }
    .padding(12)
    .frame(minHeight: 44)
    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
    .contentShape(Rectangle())
  }

  private func join(_ invite: Invite) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(invite.mode.picture)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(maxWidth: .infinity, maxHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
      Text(invite.mode.title).font(.title3.bold()).foregroundStyle(Palette.text)
      Text(tr("Raum \(invite.room)", "Room \(invite.room)"))
        .font(.subheadline.monospaced())
        .foregroundStyle(Palette.textDim)
      Button { open(invite, sentByMe) } label: {
        Label(
          sentByMe ? tr("Zurück in den Raum", "Back to the room") : tr("Einsteigen", "Join"),
          systemImage: "play.fill"
        )
        .font(.headline)
        .frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(.borderedProminent)
      .tint(Palette.olive)
    }
  }
}
