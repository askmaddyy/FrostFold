//
//  DemoContentView.swift
//  FrostFold
//

import SwiftUI

struct DemoContentView: View {
    var body: some View {
        ZStack {
            Color.white
            VStack(spacing: 14) {
                Text("Built by AskMaddyy")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                Text("@askmaddyy on X")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.black.opacity(0.45))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    DemoContentView()
}
