import ActivityKit
import SwiftUI
import WidgetKit

/// The running round on the lock screen and in the Dynamic Island.
struct MatchLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MatchActivityAttributes.self) { context in
      LockScreenView(attributes: context.attributes, state: context.state)
        .activityBackgroundTint(WidgetPalette.background)
        .activitySystemActionForegroundColor(WidgetPalette.amber)
    } dynamicIsland: { context in
      let state = context.state
      let attributes = context.attributes
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading, priority: 1) {
          Stat(value: "\(state.alive)", label: state.defending(attributes) ? tr("Verteidiger", "Defenders") : tr("übrig", "left"))
            .padding(.leading, 6)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        DynamicIslandExpandedRegion(.trailing, priority: 1) {
          Stat(value: "\(state.kills)", label: tr("Abschüsse", "Kills"), alignment: .trailing)
            .padding(.trailing, 6)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(state.headline(attributes))
              .font(.system(size: 14, weight: .heavy))
              .foregroundStyle(state.headlineColor)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
            // A timer text claims all the width it gets; pin it.
            RoundClock(state: state)
              .font(.system(size: 20, weight: .bold).monospacedDigit())
              .foregroundStyle(WidgetPalette.amber)
              .multilineTextAlignment(.center)
              .frame(width: 80)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          Bars(attributes: attributes, state: state)
            .padding(.horizontal, 6)
            .padding(.top, 4)
        }
      } compactLeading: {
        HStack(spacing: 3) {
          Image(systemName: state.defending(attributes) ? "shield.fill" : "scope")
            .foregroundStyle(WidgetPalette.amber)
          Text("\(state.alive)")
            .fontWeight(.heavy)
            .foregroundStyle(WidgetPalette.text)
        }
      } compactTrailing: {
        if state.phase == "roundOver" {
          Text(state.outcome == "won" ? tr("SIEG", "WIN") : tr("AUS", "OUT"))
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(state.headlineColor)
        } else {
          RoundClock(state: state)
            .font(.system(size: 14, weight: .semibold).monospacedDigit())
            .foregroundStyle(WidgetPalette.amber)
            .multilineTextAlignment(.trailing)
            .frame(width: 44)
        }
      } minimal: {
        Text("\(state.alive)")
          .fontWeight(.heavy)
          .foregroundStyle(WidgetPalette.amber)
      }
      .keylineTint(WidgetPalette.amber)
    }
  }
}

private struct LockScreenView: View {
  let attributes: MatchActivityAttributes
  let state: MatchActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text("PANZERGEFECHT")
          .font(.system(size: 11, weight: .black))
          .tracking(1.5)
          .foregroundStyle(WidgetPalette.sand)
        Text(attributes.map.uppercased())
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(WidgetPalette.textDim.opacity(0.7))
          .lineLimit(1)
        Spacer()
        RoundClock(state: state)
          .font(.system(size: 15, weight: .bold).monospacedDigit())
          .foregroundStyle(WidgetPalette.amber)
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 80, alignment: .trailing)
      }
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 0) {
          Text(state.headline(attributes))
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(state.headlineColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          Text(state.subline(attributes))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(WidgetPalette.textDim)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        Stat(value: "\(state.alive)/\(max(state.total, state.alive))", label: tr("übrig", "left"), alignment: .trailing)
        Stat(value: "\(state.kills)", label: tr("Abschüsse", "Kills"), alignment: .trailing)
      }
      Bars(attributes: attributes, state: state)
    }
    .padding(16)
  }
}

private struct Stat: View {
  let value: String
  let label: String
  var alignment: HorizontalAlignment = .leading

  var body: some View {
    VStack(alignment: alignment, spacing: -2) {
      Text(value)
        .font(.system(size: 24, weight: .heavy, design: .rounded))
        .foregroundStyle(WidgetPalette.text)
        .contentTransition(.numericText())
      Text(label)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(WidgetPalette.textDim)
    }
  }
}

/// Armour, and in a defense round the base below it.
private struct Bars: View {
  let attributes: MatchActivityAttributes
  let state: MatchActivityAttributes.ContentState

  var body: some View {
    VStack(spacing: 6) {
      if state.phase != "spectating" {
        Bar(label: tr("Panzerung", "Armour"), value: state.hp, color: state.hp > 0.3 ? WidgetPalette.olive : WidgetPalette.danger)
      }
      if state.defending(attributes) {
        Bar(label: tr("Basis", "Base"), value: state.baseHp, color: state.baseHp > 0.3 ? WidgetPalette.sand : WidgetPalette.danger)
      }
    }
  }
}

private struct Bar: View {
  let label: String
  let value: Double
  let color: Color

  var body: some View {
    HStack(spacing: 8) {
      Text(label)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(WidgetPalette.textDim)
        .frame(width: 66, alignment: .leading)
      ProgressView(value: min(max(value, 0), 1))
        .tint(color)
        .background(WidgetPalette.surface)
      Text("\(Int((value * 100).rounded())) %")
        .font(.system(size: 11, weight: .bold).monospacedDigit())
        .foregroundStyle(WidgetPalette.text)
        .frame(width: 40, alignment: .trailing)
    }
  }
}

/// Counts down to the start or to the next wave, otherwise up from the
/// start of the round. Runs on its own between updates.
private struct RoundClock: View {
  let state: MatchActivityAttributes.ContentState

  var body: some View {
    if state.phase == "roundOver" {
      Text(tr("Ende", "End"))
    } else if let target = state.countdownTarget, target > .now {
      Text(timerInterval: Date.now...target, countsDown: true)
    } else {
      Text(state.startsAt, style: .timer)
    }
  }
}

extension MatchActivityAttributes.ContentState {
  func defending(_ attributes: MatchActivityAttributes) -> Bool {
    attributes.mode == "defense"
  }

  var countdownTarget: Date? {
    phase == "countdown" ? startsAt : nextWaveAt
  }

  func headline(_ attributes: MatchActivityAttributes) -> String {
    switch phase {
    case "countdown":
      return tr("Gleich geht's los", "Starting soon")
    case "roundOver":
      return outcome == "won" ? tr("Sieg!", "Victory!") : (defending(attributes) ? tr("Basis gefallen", "Base fell") : tr("Vernichtet", "Destroyed"))
    case "spectating":
      return tr("Abgeschossen", "Knocked out")
    default:
      if defending(attributes) {
        return wave == 0 ? tr("Stellung beziehen", "Take position") : tr("Welle \(wave)/\(waves)", "Wave \(wave)/\(waves)")
      }
      return tr("Im Gefecht", "In battle")
    }
  }

  func subline(_ attributes: MatchActivityAttributes) -> String {
    switch phase {
    case "roundOver":
      if let winner, outcome != "won" { return tr("Sieger: \(winner)", "Winner: \(winner)") }
      return tr("\(kills) Abschüsse in dieser Runde", "\(kills) kills this round")
    case "spectating":
      return spectating.map { tr("Du schaust \($0) zu", "You are watching \($0)") } ?? tr("Du schaust zu", "You are watching")
    default:
      switch attributes.mode {
      case "solo": return tr("\(attributes.pilot) gegen CPU-Panzer", "\(attributes.pilot) against CPU tanks")
      case "defense": return nextWaveAt != nil ? tr("Nächste Welle rollt an", "Next wave incoming") : tr("Haltet die Basis", "Hold the base")
      default: return "\(attributes.pilot) · \(tr("Raum", "Room")) \(attributes.room)"
      }
    }
  }

  var headlineColor: Color {
    switch (phase, outcome) {
    case ("roundOver", "won"): return WidgetPalette.amber
    case ("roundOver", _), ("spectating", _): return WidgetPalette.danger
    default: return WidgetPalette.text
    }
  }
}

#Preview("Sperrbildschirm", as: .content, using: MatchActivityAttributes.preview) {
  MatchLiveActivity()
} contentStates: {
  MatchActivityAttributes.ContentState.playingPreview
  MatchActivityAttributes.ContentState.defensePreview
}

extension MatchActivityAttributes {
  static let preview = MatchActivityAttributes(
    room: "K7QX", pilot: "Panzer-4711", mode: "multi", map: "Wald")
}

extension MatchActivityAttributes.ContentState {
  static let playingPreview = Self(
    phase: "playing", startsAt: .now.addingTimeInterval(-74), alive: 3, total: 6,
    hp: 0.62, kills: 2, spectating: nil, wave: 0, waves: 8, baseHp: 0,
    nextWaveAt: nil, outcome: "none", winner: nil)
  static let defensePreview = Self(
    phase: "playing", startsAt: .now.addingTimeInterval(-300), alive: 2, total: 2,
    hp: 0.9, kills: 11, spectating: nil, wave: 3, waves: 8, baseHp: 0.71,
    nextWaveAt: .now.addingTimeInterval(12), outcome: "none", winner: nil)
}
