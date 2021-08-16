//
//  ContentView.swift
//  Decrypter
//
//  Created by Lakr Aream on 2021/8/16.
//

import SwiftUI
import Dog

struct AppInfo: Identifiable {
    var id: URL { url }
    let url: URL
    let name: String
    let iconData: Data?
    let version: String

    init?(from: URL) {
        url = from
        let info = url
            .appendingPathComponent("Info")
            .appendingPathExtension("plist")
        guard let infoData = try? Data(contentsOf: info),
              let result = try? PropertyListSerialization
              .propertyList(from: infoData,
                            options: .mutableContainersAndLeaves,
                            format: .none),
              let decode = result as? [String: Any]
        else {
            return nil
        }

        let icon = url
            .appendingPathComponent("AppIcon60x60@2x")
            .appendingPathExtension("png")
        
        if let data = try? Data(contentsOf: icon) {
            iconData = data
        } else {
            iconData = nil
        }
        
        name = (decode["CFBundleDisplayName"] as? String) ?? "Unknown Name"
        version = (decode["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}

struct ContentView: View {
    @State var loading: Bool = false
    @State var apps: [AppInfo] = []

    var body: some View {
        GeometryReader { val in
            if loading {
                ZStack {
                    ProgressView()
                }
                .frame(width: val.size.width,
                       height: val.size.height)
            } else {
                ScrollView {
                    VStack {
                        ForEach(apps) { item in
                            HStack {
                                Image(nsImage: .init(data: item.iconData ?? Data()) ?? NSImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 45, height: 45)
                                    .cornerRadius(12)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .bottom) {
                                        Text(item.name)
                                            .font(.system(size: 16, weight: .semibold, design: .default))
                                        Text(item.version)
                                            .font(.system(size: 12, weight: .thin, design: .monospaced))
                                    }
                                    Text(item.url.path)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                }
                                Spacer()
                                Button(action: {
                                    DecryptView(targetUrl: item.url)
                                        .frame(width: 600, height: 200)
                                        .openInWindow(title: "", sender: nil)
                                }, label: {
                                    Text("Decrypt")
                                })
                            }
                            .frame(height: 60)
                            Divider()
                        }
                        if apps.count < 1 {
                            Text("Nothing Available")
                                .bold()
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loading = true
            DispatchQueue.global().async {
                loadApps()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init(rawValue: "reload"))) { _ in
            loading = true
            DispatchQueue.global().async {
                usleep(500000) // 喵
                loadApps()
            }
        }
    }

    func loadApps() {
        let base = URL(fileURLWithPath: "/Applications")
        let lookup = (
            (
                try? FileManager
                    .default
                    .contentsOfDirectory(atPath: base.path)
            ) ?? []
        )
        .filter { $0.hasSuffix(".app") }
        .map { base.appendingPathComponent($0) }
        .map { isUIKitApp(url: $0) }
        .compactMap { $0 }
        lookup.forEach { Dog.shared.join("App", "[i] \($0.path)") }
        setApps(lookup)
    }

    func isUIKitApp(url: URL) -> URL? {
        let wrapper = url.appendingPathComponent("Wrapper")
        guard let content = try? FileManager
            .default
            .contentsOfDirectory(atPath: wrapper.path)
        else {
            return nil
        }
        for item in content where item.hasSuffix(".app") {
            return wrapper.appendingPathComponent(item)
        }
        return nil
    }

    func setApps(_ urls: [URL]) {
        DispatchQueue.main.async {
            apps = urls
                .sorted { $0.path < $1.path }
                .map { AppInfo(from: $0) }
                .compactMap { $0 }
            loading = false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
