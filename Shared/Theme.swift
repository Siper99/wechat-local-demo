import SwiftUI
import UIKit
import ImageIO

// MARK: - 颜色

extension Color {
    static let brand = Color(UIColor(hex: 0x07C160))
    static let bubbleMe = dynamic(0x95EC69, 0x3EB575)
    static let bubbleOther = dynamic(0xFFFFFF, 0x2C2C2C)
    static let textOnMe = Color(UIColor(hex: 0x111111))
    static let textOnOther = dynamic(0x111111, 0xE5E5E5)
    static let chatBackground = dynamic(0xEDEDED, 0x111111)
    static let inputBar = dynamic(0xF7F7F7, 0x1E1E1E)
    static let inputField = dynamic(0xFFFFFF, 0x2C2C2C)
    static let pinnedRow = dynamic(0xEFEFEF, 0x252525)
    /// WeUI BG-2：单元格白底，深色 #191919
    static let cellBackground = dynamic(0xFFFFFF, 0x191919)
    /// WeUI FG-1：次要文字 55% 黑 / 50% 白
    static let wcSecondary = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.5) : UIColor(white: 0, alpha: 0.55) })
    /// 会话摘要：实机截图实测约 #A0A0A0
    static let wcPreview = dynamic(0xA0A0A0, 0x7A7A7A)
    /// WeUI FG-2：时间戳、箭头 30%
    static let wcTips = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.3) : UIColor(white: 0, alpha: 0.3) })

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - 头像

struct AvatarView: View {
    var name: String
    var data: Data?
    var size: CGFloat = 40
    var isSystem = false

    init(name: String, data: Data?, size: CGFloat = 40, isSystem: Bool = false) {
        self.name = name
        self.data = data
        self.size = size
        self.isSystem = isSystem
    }

    init(contact: Contact?, size: CGFloat = 40) {
        self.init(name: contact?.name ?? "?", data: contact?.avatarData, size: size, isSystem: contact?.isSystem ?? false)
    }

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if isSystem {
                // 文件传输助手：绿底白色文件夹 + 箭头
                ZStack {
                    Color(UIColor(hex: 0x07C160))
                    Image(systemName: "folder.fill")
                        .font(.system(size: size * 0.48))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.right")
                        .font(.system(size: size * 0.2, weight: .heavy))
                        .foregroundStyle(Color(UIColor(hex: 0x07C160)))
                        .offset(y: size * 0.03)
                }
            } else {
                ZStack {
                    Self.color(for: name)
                    Text(String(name.prefix(1)))
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
    }

    private static let palette: [Color] = [
        Color(UIColor(hex: 0x5B8FF9)), Color(UIColor(hex: 0x61DDAA)), Color(UIColor(hex: 0xF6BD16)),
        Color(UIColor(hex: 0xE8684A)), Color(UIColor(hex: 0x6DC8EC)), Color(UIColor(hex: 0x9270CA)),
        Color(UIColor(hex: 0xFF9D4D)), Color(UIColor(hex: 0x269A99)),
    ]

    static func color(for name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}

// MARK: - 时间格式

enum ChatTime {
    private static let calendar = Calendar.current

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = format
        return f
    }

    private static let hm = formatter("HH:mm")
    private static let weekday = formatter("EEEE")
    private static let monthDay = formatter("M月d日")
    private static let full = formatter("yyyy年M月d日")
    private static let short = formatter("yy/M/d")

    private static func daysAgo(_ date: Date, now: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
    }

    /// 会话列表右上角的时间
    static func listLabel(_ date: Date, now: Date = .now) -> String {
        if calendar.isDateInToday(date) { return hm.string(from: date) }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let days = daysAgo(date, now: now)
        if days > 1 && days < 7 { return weekday.string(from: date) }
        return short.string(from: date)
    }

    /// 聊天里居中的时间分隔
    static func chatLabel(_ date: Date, now: Date = .now) -> String {
        let t = hm.string(from: date)
        if calendar.isDateInToday(date) { return t }
        if calendar.isDateInYesterday(date) { return "昨天 \(t)" }
        let days = daysAgo(date, now: now)
        if days > 1 && days < 7 { return "\(weekday.string(from: date)) \(t)" }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) { return "\(monthDay.string(from: date)) \(t)" }
        return "\(full.string(from: date)) \(t)"
    }
}

// MARK: - 拼音首字母（通讯录分组）

enum PinyinIndex {
    static func latin(_ name: String) -> String {
        let latin = name.applyingTransform(.toLatin, reverse: false) ?? name
        return (latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin).lowercased()
    }

    static func letter(for name: String) -> String {
        guard let first = latin(name).first else { return "#" }
        let letter = String(first).uppercased()
        return letter.range(of: "^[A-Z]$", options: .regularExpression) != nil ? letter : "#"
    }
}

// MARK: - 图片

enum ImageUtil {
    /// 用 ImageIO 缩图，内存占用小（分享扩展有 ~120MB 内存上限）
    static func downsampledJPEG(_ data: Data, maxPixel: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else { return nil }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
    }
}

enum ImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for id: UUID, data: Data?) -> UIImage? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data, let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
