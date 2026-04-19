//
//  TCPServerTestView.swift
//  litu
//
//  Created by ilya on 17/04/2026.
//

import SwiftUI

struct TCPServerTestView: View {
    @StateObject private var server = SimpleTCPServer()
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Start Server") {
                    server.start(port: 8080)
                }

                Button("Stop Server") {
                    server.stop()
                }
            }

            List(server.log, id: \.self) { line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .padding()
    }
}



