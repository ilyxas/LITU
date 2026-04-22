//
//  SimpleTCPClient.swift
//  litu
//
//  Created by ilya on 17/04/2026.
//

import Foundation
import Network
import Combine

@MainActor
final class SimpleTCPClient: ObservableObject  {
    @Published var log: [String] = []

    private var connection: NWConnection?

    func connect(host: String = "172.20.10.13", port: UInt16 = 8080) {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.log.append("state: \(state)")
                switch state {
                case .ready:
                    //self?.send("hello from iphone client\n")
                    self?.receive()
                default:
                    break
                }
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    func send(_ text: String) {
        guard let connection else { return }

        let data = Data(text.utf8)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.log.append("send error: \(error)")
                } else {
                    //save only 50 last lines
                    if self?.log.count ?? 0 > 50 {
                        self?.log.removeFirst()
                    }
                    self?.log.append("sent: \(text.trimmingCharacters(in: .newlines))")
                }
            }
        })
    }
    
    func sendMessage(msgId: UInt16, payload: Data) {
            guard let connection else { return }

            var data = Data()

            // Header
            var msgIdLE = msgId.littleEndian
            var sizeLE = UInt32(payload.count).littleEndian

            withUnsafeBytes(of: &msgIdLE) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &sizeLE) { data.append(contentsOf: $0) }

            // Payload
            data.append(payload)

            connection.send(content: data, completion: .contentProcessed {  [weak self]  error in
                Task { @MainActor in
                    if let error {
                        self?.log.append("send error: \(error)")
                    } else {
                        //save only 50 last lines
                        if self?.log.count ?? 0 > 50 {
                            self?.log.removeFirst()
                        }
                        //payload size sent
                        self?.log.append("payload size: \(payload.count) bytes")
                    }
                }
            })
    }
    

    func receive() {
        guard let connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data, !data.isEmpty {
                let text = String(decoding: data, as: UTF8.self)
                Task { @MainActor in
                    self?.log.append("received: \(text)")
                }
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
                self?.receive()
            }
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        Task { @MainActor in
            self.log.append("disconnected")
        }
    }
}
