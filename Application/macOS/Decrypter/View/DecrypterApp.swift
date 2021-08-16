//
//  DecrypterApp.swift
//  Decrypter
//
//  Created by Lakr Aream on 2021/8/16.
//

import SwiftUI
import Dog

let userLocation = FileManager
    .default
    .urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("DecryptedApp")

@main
struct DecrypterApp: App {
    
    init() {
        try? Dog.shared.initialization()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toolbar(content: {
                    ToolbarItem {
                        Button {
                            LogView()
                                .frame(width: 600, height: 400)
                                .openInWindow(title: "", sender: nil)
                        } label: {
                            Image(systemName: "doc.text.below.ecg.fill")
                        }
                    }
                    ToolbarItem {
                        Button(action: {
                            NSWorkspace.shared.open(userLocation)
                        }, label: {
                            Image(systemName: "doc.text.fill")
                        })
                    }
                    ToolbarItem {
                        Button {
                            NotificationCenter.default.post(name: .init(rawValue: "reload"), object: nil)
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                        }
                    }
                })
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

extension View {
    @discardableResult
    func openInWindow(title: String, sender: Any?) -> NSWindow {
        let controller = NSHostingController(rootView: self)
        let win = NSWindow(contentViewController: controller)
        win.contentViewController = controller
        win.title = title
        win.makeKeyAndOrderFront(sender)
        return win
    }
}
