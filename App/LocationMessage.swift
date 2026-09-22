import SwiftUI
import MapKit

/// 位置消息卡片：上方地点名称与地址，下方静态地图与绿色定位针
struct LocationBubble: View {
    let message: Message
    static let width: CGFloat = 240
    static let mapHeight: CGFloat = 100

    @State private var snapshot: UIImage?

    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = message.latitude, let lon = message.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textOnOther)
                    .lineLimit(1)
                if let address = message.locationAddress, !address.isEmpty {
                    Text(address)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                if let snapshot {
                    Image(uiImage: snapshot).resizable().scaledToFill()
                } else {
                    Color.dynamic(0xF1F1EE, 0x2A2A2A)
                }
                MapPin().offset(y: -16)
            }
            .frame(width: Self.width, height: Self.mapHeight)
            .clipped()
        }
        .frame(width: Self.width)
        .background(Color.bubbleOther)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 5))
        .task(id: message.id) { await loadSnapshot() }
    }

    private func loadSnapshot() async {
        guard let coordinate else { return }
        if let cached = LocationSnapshotCache.image(for: message.id) {
            snapshot = cached
            return
        }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 600, longitudinalMeters: 600)
        options.size = CGSize(width: Self.width, height: Self.mapHeight)
        options.pointOfInterestFilter = .excludingAll
        guard let result = try? await MKMapSnapshotter(options: options).start() else { return }
        LocationSnapshotCache.store(result.image, for: message.id)
        snapshot = result.image
    }

    /// 在系统地图中打开
    static func open(_ message: Message) {
        guard let lat = message.latitude, let lon = message.longitude else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        item.name = message.text
        item.openInMaps()
    }
}

private struct MapPin: View {
    private let green = Color(UIColor(hex: 0x07C160))
    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(.white)
                .overlay(Circle().stroke(green, lineWidth: 5))
                .frame(width: 20, height: 20)
            Rectangle().fill(green).frame(width: 3, height: 12)
        }
    }
}

@MainActor
enum LocationSnapshotCache {
    private static let cache = NSCache<NSString, UIImage>()
    static func image(for id: UUID) -> UIImage? { cache.object(forKey: id.uuidString as NSString) }
    static func store(_ image: UIImage, for id: UUID) { cache.setObject(image, forKey: id.uuidString as NSString) }
}

/// ＋ 面板 → 位置：输入地点名称与地址，地址经系统地理编码得到坐标
struct LocationComposeSheet: View {
    var onSend: (_ name: String, _ address: String, _ coordinate: CLLocationCoordinate2D?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var locating = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("地点名称", text: $name)
                        .accessibilityIdentifier("location.name")
                    TextField("详细地址", text: $address, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("location.address")
                } footer: {
                    Text("地址将通过系统地图解析为坐标并生成地图预览；无法解析时仍会发送，但不显示地图。")
                }
            }
            .navigationTitle("发送位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if locating {
                        ProgressView()
                    } else {
                        Button("发送") { Task { await send() } }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityIdentifier("location.send")
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func send() async {
        locating = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = trimmedAddress.isEmpty ? trimmedName : trimmedAddress
        let placemark = try? await CLGeocoder().geocodeAddressString(query).first
        locating = false
        onSend(trimmedName, trimmedAddress, placemark?.location?.coordinate)
        dismiss()
    }
}
