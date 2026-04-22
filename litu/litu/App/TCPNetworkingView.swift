//
//  TCPClientTestView.swift
//  litu
//
//  Created by ilya on 17/04/2026.
//

import SwiftUI

struct JoystickPayload {
    var x: Float
    var y: Float
    var timestamp: UInt32
}

struct StartManualPayload {
    var timestamp: UInt32
}

struct TCPClientTestView: View {
    @StateObject private var client = SimpleTCPClient()
    @State private var stick = CGSize.zero

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Connect") {
                    client.connect(host: "172.20.10.13", port: 8080)
                }

                Button("Start Manual Nav") {
                    client.sendMessage(msgId: 0x1002, payload: serializeManual(StartManualPayload(timestamp: 123)))
                }
                
                Button("Halt Manual") {
                    client.sendMessage(msgId: 0x1003, payload: serializeManual(StartManualPayload(timestamp: 123)))
                }

                Button("Disconnect") {
                    client.disconnect()
                }
            }

            List(client.log, id: \.self) { line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
            }
            
            HStack(alignment: .bottom) {
                // Camera joystick (bottom-left)
                cameraJoystick

                Spacer()
            }
            .padding(20)
        }
        .padding()
    }
    
    // MARK: - Camera joystick

    private var cameraJoystick: some View {
        let size: CGFloat = 110
        let knob: CGFloat = 40
        let limit = (size - knob) / 2

        return ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: size, height: size)

            Circle()
                .fill(.ultraThickMaterial)
                .frame(width: knob, height: knob)
                .offset(stick)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    var x = value.translation.width
                    var y = value.translation.height
                    let len = hypot(x, y)
                    if len > limit, len > 0 {
                        x = x / len * limit
                        y = y / len * limit
                    }
                    
                    let nx = Float(x / limit)
                    let ny = Float(-y / limit)
                    stick = CGSize(width: x, height: y)

                    let payload = JoystickPayload(x: nx, y: ny, timestamp: 123)
                    
                    client.sendMessage(msgId: 0x1001, payload: serializeJoystick(payload))
                }
                .onEnded { _ in
                    stick = .zero
                }
        )
    }
    
    func serializeJoystick(_ js: JoystickPayload) -> Data {
        var data = Data()

        var x = js.x.bitPattern.littleEndian
        var y = js.y.bitPattern.littleEndian
        var t = js.timestamp.littleEndian

        withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &y) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &t) { data.append(contentsOf: $0) }

        return data
    }
    
    func serializeManual(_ js: StartManualPayload) -> Data {
        var data = Data()
        
        var t = js.timestamp.littleEndian
        withUnsafeBytes(of: &t) { data.append(contentsOf: $0) }

        return data
    }
}
