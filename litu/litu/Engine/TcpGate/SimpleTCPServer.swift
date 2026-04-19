//
//  Untitled.swift
//  litu
//
//  Created by ilya on 17/04/2026.
//

import Foundation
import Network
import Combine

@MainActor
final class SimpleTCPServer: ObservableObject {
    @Published var log: [String] = []

    private var listener: NWListener?
    private var connections: [NWConnection] = []

    func start(port: UInt16 = 8080) {
        do {
            let params = NWParameters.tcp
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.log.append("listener state: \(state)")
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handle(connection: connection)
                }
            }

            self.listener = listener
            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            Task { @MainActor in
                self.log.append("listener failed: \(error)")
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }

    private func handle(connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.log.append("connection state: \(state)")
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data, !data.isEmpty {
                let text = String(decoding: data, as: UTF8.self)
                Task { @MainActor in
                    self?.log.append("received: \(text)")
                }

                let reply = Data("hello from iphone\n".utf8)
                connection.send(content: reply, completion: .contentProcessed { sendError in
                    if let sendError {
                        Task { @MainActor in
                            self?.log.append("send error: \(sendError)")
                        }
                    }
                })
            }

            if let error {
                Task { @MainActor in
                    self?.log.append("receive error: \(error)")
                }
                return
            }

            if isComplete {
                Task { @MainActor in
                    self?.log.append("connection complete")
                }
                return
            }

            Task { @MainActor in
                self?.receive(on: connection)
            }
        }
    }
}
