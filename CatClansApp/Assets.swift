import Foundation
import SwiftUI
import UIKit

// MARK: - Имена ассетов

/// Сопоставление моделей игры именам картинок в Assets.xcassets.
/// Если картинки нет — представления показывают эмодзи-фолбэк,
/// поэтому игра остаётся цельной даже при частично готовом наборе артов.
enum GameArt {
    static func buildingAsset(_ type: BuildingType, level: Int) -> String? {
        switch type {
        case .home:
            switch level {
            case ...2: return "b_home1"
            case 3:    return "b_home2"
            default:   return "b_home3"
            }
        case .workshop:    return "b_workshop"
        case .fishTrap:    return "b_fishtrap"
        case .creamBarrel: return "b_creambarrel"
        case .toyShelf:    return "b_toyshelf"
        case .academy:     return "b_academy"
        case .wall:        return "b_wall"
        case .cannon:      return "b_cannon"
        case .sniper:      return "b_sniper"
        case .trap:        return "b_trap"
        }
    }

    static func unitAsset(_ id: UnitID) -> String? {
        switch id {
        case .kitten:    return "u_kitten"
        case .warrior:   return "u_warrior"
        case .mouser:    return "u_mouser"
        case .wizard:    return "u_wizard"
        case .tiger:     return "u_tiger"
        case .hamster:   return "u_hamster"
        case .raccoon:   return "u_raccoon"
        case .banditCat: return "u_banditcat"
        case .dog:       return "u_dog"
        case .wolf:      return "u_wolf"
        case .alphaWolf: return "u_alphawolf"
        }
    }

    static func resourceAsset(_ r: Resource) -> String? {
        switch r {
        case .fish:  return "r_fish"
        case .cream: return "r_cream"
        case .yarn:  return "r_yarn"
        case .mouse: return "r_mouse"
        }
    }
}

// MARK: - Спрайт с фолбэком на эмодзи

/// Показывает картинку из ассетов, а при её отсутствии — эмодзи.
struct SpriteView: View {
    let asset: String?
    let fallbackEmoji: String
    var size: CGFloat
    var shadow: Bool = true

    var body: some View {
        if let asset = asset, let ui = UIImage(named: asset) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: shadow ? Color.black.opacity(0.35) : .clear, radius: 3, x: 0, y: 2)
        } else {
            Text(fallbackEmoji)
                .font(.system(size: size * 0.62))
                .frame(width: size, height: size)
                .shadow(color: shadow ? Color.black.opacity(0.35) : .clear, radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Именованные обёртки (по ТЗ)

/// Спрайт здания.
struct BuildingSpriteView: View {
    let type: BuildingType
    var level: Int = 1
    var size: CGFloat

    var body: some View {
        SpriteView(
            asset: GameArt.buildingAsset(type, level: level),
            fallbackEmoji: type.emoji,
            size: size
        )
    }
}

/// Спрайт юнита.
struct UnitSpriteView: View {
    let unit: UnitID
    var size: CGFloat
    var team: Team = .player

    var body: some View {
        SpriteView(
            asset: GameArt.unitAsset(unit),
            fallbackEmoji: unit.emoji,
            size: size
        )
        .saturation(team == .enemy ? 0.9 : 1.0)
        .overlay(
            // Лёгкая красная подсветка врагов в бою.
            Circle()
                .stroke(team == .enemy ? Color.ccBad.opacity(0.0) : .clear, lineWidth: 0)
        )
    }
}

/// Иконка ресурса (картинка или эмодзи).
struct ResourceIcon: View {
    let resource: Resource
    var size: CGFloat = 18

    var body: some View {
        SpriteView(
            asset: GameArt.resourceAsset(resource),
            fallbackEmoji: resource.emoji,
            size: size,
            shadow: false
        )
    }
}
