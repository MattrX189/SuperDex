//
//  CountryCodePicker.swift
//  SuperDex
//

import SwiftUI

struct CountryCode: Identifiable, Hashable {
    let name: String
    let dial: String
    let iso: String

    var id: String { iso }

    static func flag(for dialCode: String) -> String {
        guard let entry = all.first(where: { $0.dial == dialCode }) else { return "🏳️" }
        return flagEmoji(for: entry.iso)
    }

    private static func flagEmoji(for iso: String) -> String {
        iso.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }.map(String.init).joined()
    }

    /// Valid mobile number lengths (digits after the country code, without a
    /// leading trunk "0") per country. Unknown codes fall back to E.164 bounds.
    static func mobileLengths(for dialCode: String) -> ClosedRange<Int> {
        guard let iso = all.first(where: { $0.dial == dialCode })?.iso else { return 6...15 }
        switch iso {
        case "SG", "QA", "KW", "BH", "OM", "DK", "NO":
            return 8...8
        case "AU", "FR", "ES", "NL", "SE", "CH", "AE", "SA", "ZA", "KE", "IL",
             "TH", "LK", "CL", "PL", "PT", "IE":
            return 9...9
        case "US", "CA", "GB", "IN", "JP", "MX", "TR", "RU", "PH", "PK", "BD",
             "NP", "CO", "EG", "NG":
            return 10...10
        case "CN", "BR":
            return 11...11
        case "DE", "AR":
            return 10...11
        case "IT", "KR", "MY", "VN":
            return 9...10
        case "NZ":
            return 8...10
        case "FI":
            return 7...10
        case "ID":
            return 9...12
        default:
            return 6...15
        }
    }

    /// Digits that count toward the mobile length (drops a leading trunk "0",
    /// e.g. UK "07700…" → "7700…").
    static func nationalDigits(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        return digits.hasPrefix("0") ? String(digits.dropFirst()) : digits
    }

    static func isValidMobile(_ raw: String, dialCode: String) -> Bool {
        mobileLengths(for: dialCode).contains(nationalDigits(raw).count)
    }

    /// e.g. "10 digits" or "9–10 digits", for helper text.
    static func lengthDescription(for dialCode: String) -> String {
        let range = mobileLengths(for: dialCode)
        return range.lowerBound == range.upperBound
            ? "\(range.lowerBound) digits"
            : "\(range.lowerBound)–\(range.upperBound) digits"
    }

    static let all: [CountryCode] = [
        CountryCode(name: "United States", dial: "+1", iso: "US"),
        CountryCode(name: "United Kingdom", dial: "+44", iso: "GB"),
        CountryCode(name: "India", dial: "+91", iso: "IN"),
        CountryCode(name: "Canada", dial: "+1", iso: "CA"),
        CountryCode(name: "Australia", dial: "+61", iso: "AU"),
        CountryCode(name: "Germany", dial: "+49", iso: "DE"),
        CountryCode(name: "France", dial: "+33", iso: "FR"),
        CountryCode(name: "Japan", dial: "+81", iso: "JP"),
        CountryCode(name: "China", dial: "+86", iso: "CN"),
        CountryCode(name: "Brazil", dial: "+55", iso: "BR"),
        CountryCode(name: "Mexico", dial: "+52", iso: "MX"),
        CountryCode(name: "South Korea", dial: "+82", iso: "KR"),
        CountryCode(name: "Italy", dial: "+39", iso: "IT"),
        CountryCode(name: "Spain", dial: "+34", iso: "ES"),
        CountryCode(name: "Netherlands", dial: "+31", iso: "NL"),
        CountryCode(name: "Sweden", dial: "+46", iso: "SE"),
        CountryCode(name: "Switzerland", dial: "+41", iso: "CH"),
        CountryCode(name: "Singapore", dial: "+65", iso: "SG"),
        CountryCode(name: "UAE", dial: "+971", iso: "AE"),
        CountryCode(name: "Saudi Arabia", dial: "+966", iso: "SA"),
        CountryCode(name: "South Africa", dial: "+27", iso: "ZA"),
        CountryCode(name: "Nigeria", dial: "+234", iso: "NG"),
        CountryCode(name: "Kenya", dial: "+254", iso: "KE"),
        CountryCode(name: "Israel", dial: "+972", iso: "IL"),
        CountryCode(name: "Turkey", dial: "+90", iso: "TR"),
        CountryCode(name: "Russia", dial: "+7", iso: "RU"),
        CountryCode(name: "Indonesia", dial: "+62", iso: "ID"),
        CountryCode(name: "Thailand", dial: "+66", iso: "TH"),
        CountryCode(name: "Philippines", dial: "+63", iso: "PH"),
        CountryCode(name: "Malaysia", dial: "+60", iso: "MY"),
        CountryCode(name: "Vietnam", dial: "+84", iso: "VN"),
        CountryCode(name: "Pakistan", dial: "+92", iso: "PK"),
        CountryCode(name: "Bangladesh", dial: "+880", iso: "BD"),
        CountryCode(name: "Sri Lanka", dial: "+94", iso: "LK"),
        CountryCode(name: "Nepal", dial: "+977", iso: "NP"),
        CountryCode(name: "Argentina", dial: "+54", iso: "AR"),
        CountryCode(name: "Colombia", dial: "+57", iso: "CO"),
        CountryCode(name: "Chile", dial: "+56", iso: "CL"),
        CountryCode(name: "Poland", dial: "+48", iso: "PL"),
        CountryCode(name: "Portugal", dial: "+351", iso: "PT"),
        CountryCode(name: "Ireland", dial: "+353", iso: "IE"),
        CountryCode(name: "New Zealand", dial: "+64", iso: "NZ"),
        CountryCode(name: "Egypt", dial: "+20", iso: "EG"),
        CountryCode(name: "Qatar", dial: "+974", iso: "QA"),
        CountryCode(name: "Kuwait", dial: "+965", iso: "KW"),
        CountryCode(name: "Bahrain", dial: "+973", iso: "BH"),
        CountryCode(name: "Oman", dial: "+968", iso: "OM"),
        CountryCode(name: "Denmark", dial: "+45", iso: "DK"),
        CountryCode(name: "Norway", dial: "+47", iso: "NO"),
        CountryCode(name: "Finland", dial: "+358", iso: "FI"),
    ]
}

struct CountryCodePicker: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [CountryCode] {
        if search.isEmpty { return CountryCode.all }
        let q = search.lowercased()
        return CountryCode.all.filter {
            $0.name.lowercased().contains(q) || $0.dial.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { country in
                    HStack(spacing: 12) {
                        Text(CountryCode.flag(for: country.dial))
                            .font(.title2)
                        Text(country.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(country.dial)
                            .foregroundStyle(.secondary)
                        if country.dial == selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selected = country.dial
                        dismiss()
                    }
                }
            }
            .searchable(text: $search, prompt: "Search country or code")
            .navigationTitle("Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
