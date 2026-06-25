// Color+Hex.swift
import SwiftUI

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    // Convert Color back to hex for storage
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(components.redComponent   * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent  * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
