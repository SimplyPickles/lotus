//
//  BrowserToolbarButtonStyle.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI

struct BrowserToolbarButtonStyle: ButtonStyle {
    var isLight: Bool = false
    var hasCustomTheme: Bool = false
    @State private var isHovered = false

    private var baseColor: Color {
        if hasCustomTheme {
            return isLight ? Color.black : Color.white
        }
        return Color.primary
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? baseColor.opacity(0.6) : baseColor)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        configuration.isPressed
                        ? baseColor.opacity(0.14)
                        : (isHovered ? baseColor.opacity(0.08) : Color.clear)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .animation(.easeInOut(duration: 0.14), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
