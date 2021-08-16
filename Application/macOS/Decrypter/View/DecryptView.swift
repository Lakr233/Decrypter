//
//  DecryptView.swift
//  Decrypter
//
//  Created by Lakr Aream on 2021/8/16.
//

import SwiftUI

struct DecryptView: View {
    let targetUrl: URL

    @State var result: URL? = nil

    @State var hint: String = ""
    @State var progress: Progress = Progress(totalUnitCount: 100)

    var body: some View {
        GeometryReader { val in
            ZStack {
                VStack {
                    if result == nil {
                        ProgressView()
                    }
                    Text(hint)
                        .bold()
                    ProgressView(progress)
                    Divider()
                    Text(targetUrl.path)
                    if result != nil {
                        VStack {
                            Button(action: {
                                NSWorkspace.shared.open(result!.deletingLastPathComponent())
                            }, label: {
                                Text("Open")
                            })
                        }
                    }
                }
                .animation(.interactiveSpring(), value: progress)
                .animation(.interactiveSpring(), value: hint)
                .animation(.interactiveSpring(), value: result)
            }
            .frame(width: val.size.width, height: val.size.height)
        }
        .padding()
        .onAppear {
            DispatchQueue.global().async {
                decrypt()
            }
        }
    }

    func decrypt() {
        try! FileManager.default.createDirectory(at: userLocation,
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
        let result = dumpApplicationAt(location: targetUrl,
                                       saveTo: userLocation) { val in
            DispatchQueue.main.async {
                progress.completedUnitCount = Int64(val)
            }
        }
        DispatchQueue.main.async {
            self.result = result
        }
    }
}
