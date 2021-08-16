//
//  LogView.swift
//  Decrypter
//
//  Created by Lakr Aream on 2021/8/16.
//

import SwiftUI
import Dog

struct LogView: View {
    
    let file = Dog.shared.currentLogFileLocation?.path
    @State var text: String = ""
    
    let timer = Timer
        .publish(every: 0.25, on: .main, in: .common)
        .autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(file ?? "broken resources")
                Divider()
                Text(text)
            }
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .padding()
        }
        .onReceive(timer) { _ in
            text = Dog.shared.obtainCurrentLogContent()
        }
    }
    
}
