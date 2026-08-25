//
//  PrivateBadgeView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI

struct PrivateBadgeView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 10, weight: .semibold))

            Text("Private")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.purple.opacity(colorScheme == .dark ? 0.18 : 0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.purple.opacity(0.30), lineWidth: 1)
        )
    }
}
