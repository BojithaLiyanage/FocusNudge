// PreferencesView.swift
import SwiftUI
import Charts

struct PreferencesView: View {
    @ObservedObject var settings: ReminderSettings
    @ObservedObject var reminderTimer: ReminderTimer
    @EnvironmentObject var waterManager: WaterIntakeManager
    
    @State private var pickedColor: Color = .black

    var body: some View {
        TabView {
            WaterSettingsView(settings: settings)
                .tabItem {
                    Label("Water", systemImage: "drop.fill")
                }
            
            LookAwaySettingsView(settings: settings)
                .tabItem {
                    Label("Look Away", systemImage: "eye.fill")
                }
                
            HistoryTabView()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
            
            GlobalSettingsView(settings: settings, pickedColor: $pickedColor)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .padding()
        .frame(width: 550, height: 450)
        .onAppear {
            pickedColor = settings.backgroundColor
        }
    }
}

// MARK: - History Tab
struct HistoryTabView: View {
    @EnvironmentObject var waterManager: WaterIntakeManager
    @State private var timeRange: Int = 0 // 0: Daily, 1: Weekly, 2: Monthly
    @State private var anchorDate: Date = Date()
    @State private var hoveredDate: Date? = nil
    @State private var selectedDate: Date? = nil

    var body: some View {
        VStack(spacing: 12) {
            Picker("Time Range", selection: $timeRange) {
                Text("Daily").tag(0)
                Text("Weekly").tag(1)
                Text("Monthly").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)
            .onChange(of: timeRange) { _ in
                selectedDate = nil
            }

            // Back / forth navigation for every range (day / week / month)
            HStack {
                Button(action: { shift(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text(navLabel())
                    .font(.headline)
                    .frame(minWidth: 180)

                Button(action: { shift(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward())
            }
            .padding(.top, 4)

            Chart {
                ForEach(chartData()) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Intake (ml)", dataPoint.amountML)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Intake (ml)", dataPoint.amountML)
                    )
                    .foregroundStyle(Color.blue)
                }
                
                if let hoveredDate = hoveredDate, let data = chartData().first(where: { Calendar.current.isDate($0.date, inSameDayAs: hoveredDate) || $0.date == hoveredDate }) {
                    RuleMark(x: .value("Hover", data.date))
                        .foregroundStyle(.gray.opacity(0.3))
                        .annotation(position: .bottom, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatHoverDate(data.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(data.amountML) ml")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            .padding(8)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                }
            }
            .chartXScale(domain: chartXDomain())
            .chartXAxis {
                AxisMarks(values: .stride(by: timeUnit(), count: timeRange == 0 ? 4 : (timeRange == 2 ? 7 : 1))) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatAxisDate(date))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let xLocation = location.x - geometry[proxy.plotAreaFrame].origin.x
                                if let date: Date = proxy.value(atX: xLocation) {
                                    hoveredDate = findNearestDate(to: date)
                                }
                            case .ended:
                                hoveredDate = nil
                            }
                        }
                        .onTapGesture { location in
                            let xLocation = location.x - geometry[proxy.plotAreaFrame].origin.x
                            if let date: Date = proxy.value(atX: xLocation) {
                                selectedDate = findNearestDate(to: date)
                            }
                        }
                }
            }
            .frame(height: timeRange == 0 ? 180 : 250)
            .padding(.horizontal)
            
            // Daily: editable daily total + per-entry log editing
            if timeRange == 0 {
                VStack(alignment: .leading, spacing: 8) {
                    DailyTotalEditor(date: anchorDate)
                        .padding(.horizontal)

                    Text("Logs")
                        .font(.headline)
                        .padding(.horizontal)

                    List {
                        ForEach(waterManager.recordsForDate(date: anchorDate)) { record in
                            HStack {
                                Text(record.date, format: .dateTime.hour().minute())
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                Stepper(value: Binding(
                                    get: { record.amountML },
                                    set: { newValue in
                                        waterManager.updateRecord(id: record.id, newAmountML: newValue)
                                    }
                                ), in: 0...5000, step: 100) {
                                    Text("\(record.amountML) ml")
                                        .frame(width: 60, alignment: .trailing)
                                }
                                
                                Button(action: {
                                    waterManager.deleteRecord(id: record.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            
            // Weekly / Monthly: edit daily total of selected date
            if (timeRange == 1 || timeRange == 2), let sel = selectedDate {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sel, format: .dateTime.weekday(.wide).month().day())
                                .font(.headline)
                            Text("\(waterManager.intakeForDay(date: sel)) ml total")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Button { selectedDate = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    DailyTotalEditor(date: sel)

                    List {
                        ForEach(waterManager.recordsForDate(date: sel)) { record in
                            HStack {
                                Text(record.date, format: .dateTime.hour().minute())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Stepper(value: Binding(
                                    get: { record.amountML },
                                    set: { newValue in
                                        waterManager.updateRecord(id: record.id, newAmountML: newValue)
                                    }
                                ), in: 0...5000, step: 100) {
                                    Text("\(record.amountML) ml")
                                        .frame(width: 60, alignment: .trailing)
                                }
                                Button(action: {
                                    waterManager.deleteRecord(id: record.id)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.inset)
                    .frame(maxHeight: 140)
                    
                    HStack(spacing: 8) {
                        ForEach([100, 200, 500, 1000], id: \.self) { ml in
                            Button("+ \(ml)") {
                                waterManager.addIntakeOnDate(date: sel, amountML: ml)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Navigation

    private func navComponent() -> Calendar.Component {
        switch timeRange {
        case 0: return .day
        case 1: return .weekOfYear
        default: return .month
        }
    }

    private func shift(by amount: Int) {
        let calendar = Calendar.current
        if let d = calendar.date(byAdding: navComponent(), value: amount, to: anchorDate) {
            anchorDate = d
            selectedDate = nil
        }
    }

    private func canGoForward() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        switch timeRange {
        case 0:
            return calendar.startOfDay(for: anchorDate) < calendar.startOfDay(for: now)
        case 1:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: anchorDate) else { return false }
            return week.end < now
        case 2:
            guard let month = calendar.dateInterval(of: .month, for: anchorDate) else { return false }
            return month.end < now
        default:
            return false
        }
    }

    private func navLabel() -> String {
        let calendar = Calendar.current
        switch timeRange {
        case 0:
            if calendar.isDateInToday(anchorDate) { return "Today" }
            if calendar.isDateInYesterday(anchorDate) { return "Yesterday" }
            let f = DateFormatter(); f.dateFormat = "EEE, MMM d, yyyy"
            return f.string(from: anchorDate)
        case 1:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: anchorDate) else { return "" }
            let start = week.start
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? week.end
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return "\(f.string(from: start)) – \(f.string(from: end))"
        case 2:
            let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
            return f.string(from: anchorDate)
        default:
            return ""
        }
    }

    private func chartXDomain() -> ClosedRange<Date> {
        let calendar = Calendar.current

        switch timeRange {
        case 0:
            let start = calendar.startOfDay(for: anchorDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
            return start...end
        case 1:
            guard let week = calendar.dateInterval(of: .weekOfYear, for: anchorDate) else {
                return anchorDate...anchorDate
            }
            return week.start...week.end.addingTimeInterval(-1)
        case 2:
            guard let monthInterval = calendar.dateInterval(of: .month, for: anchorDate) else {
                return anchorDate...anchorDate
            }
            return monthInterval.start...monthInterval.end.addingTimeInterval(-1)
        default:
            return anchorDate...anchorDate
        }
    }
    
    private func findNearestDate(to targetDate: Date) -> Date? {
        let data = chartData()
        guard !data.isEmpty else { return nil }
        return data.min(by: { abs($0.date.timeIntervalSince(targetDate)) < abs($1.date.timeIntervalSince(targetDate)) })?.date
    }
    
    private func chartData() -> [ChartDataPoint] {
        switch timeRange {
        case 0: return waterManager.exactTimeDataForDay(date: anchorDate)
        case 1: return waterManager.dailyDataForWeek(date: anchorDate)
        case 2: return waterManager.dailyDataForMonth(date: anchorDate)
        default: return []
        }
    }
    
    private func timeUnit() -> Calendar.Component {
        switch timeRange {
        case 0: return .hour
        case 1: return .day
        case 2: return .day
        default: return .day
        }
    }
    
    private func formatAxisDate(_ date: Date) -> String {
        switch timeRange {
        case 0:
            let formatter = DateFormatter()
            formatter.dateFormat = "h a"
            return formatter.string(from: date)
        case 1:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        case 2:
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        default:
            return ""
        }
    }
    
    private func formatHoverDate(_ date: Date) -> String {
        switch timeRange {
        case 0:
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        case 1, 2:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        default:
            return ""
        }
    }
}

// MARK: - Daily Total Editor
struct DailyTotalEditor: View {
    @EnvironmentObject var waterManager: WaterIntakeManager
    let date: Date

    private var totalBinding: Binding<Int> {
        Binding(
            get: { waterManager.intakeForDay(date: date) },
            set: { waterManager.setDailyTotal(date: date, totalML: max(0, $0)) }
        )
    }

    var body: some View {
        HStack {
            Text("Daily total")
                .font(.subheadline)
            Spacer()
            TextField("ml", value: totalBinding, format: .number)
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
            Text("ml")
                .foregroundColor(.secondary)
            Stepper("", value: totalBinding, in: 0...20000, step: 100)
                .labelsHidden()
        }
    }
}

// MARK: - Water Settings
struct WaterSettingsView: View {
    @ObservedObject var settings: ReminderSettings
    @EnvironmentObject var waterManager: WaterIntakeManager
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Water Reminder", isOn: $settings.isWaterEnabled)
                    .font(.headline)
            }
            
            Section("Settings") {
                TextField("Message", text: $settings.waterMessage)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Text("Remind every")
                    Slider(value: $settings.waterIntervalMinutes, in: 10...180, step: 5)
                    Text("\(Int(settings.waterIntervalMinutes)) min")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }
            
            Section("Quick Add") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Today's Total: ")
                            .font(.headline)
                        Text("\(waterManager.intakeForDay()) ml")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Spacer()
                        Stepper("", onIncrement: {
                            waterManager.addIntake(amountML: 100)
                        }, onDecrement: {
                            waterManager.addIntake(amountML: -100)
                        })
                        .labelsHidden()
                    }
                    
                    HStack {
                        Button("+ 100ml") { waterManager.addIntake(amountML: 100) }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("+ 200ml") { waterManager.addIntake(amountML: 200) }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("+ 500ml") { waterManager.addIntake(amountML: 500) }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("+ 1000ml") { waterManager.addIntake(amountML: 1000) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section {
                Button("Preview Water Reminder") {
                    NotificationCenter.default.post(name: .triggerWaterReminder, object: nil)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Look Away Settings
struct LookAwaySettingsView: View {
    @ObservedObject var settings: ReminderSettings
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Look Away Reminder", isOn: $settings.isLookAwayEnabled)
                    .font(.headline)
            }
            
            Section("Settings") {
                TextField("Message", text: $settings.lookAwayMessage)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Text("Remind every")
                    Slider(value: $settings.lookAwayIntervalMinutes, in: 1...120, step: 1)
                    Text("\(Int(settings.lookAwayIntervalMinutes)) min")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }
            
            Section {
                Button("Preview Look Away Reminder") {
                    NotificationCenter.default.post(name: .triggerLookAwayReminder, object: nil)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Global Settings
struct GlobalSettingsView: View {
    @ObservedObject var settings: ReminderSettings
    @Binding var pickedColor: Color
    
    var body: some View {
        Form {
            // ── Active Hours ──────────────────────────────────────────
            Section("Active Hours") {
                HStack {
                    Text("From")
                    Picker("", selection: $settings.activeFromHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                    .frame(width: 100)

                    Text("to")

                    Picker("", selection: $settings.activeToHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                    .frame(width: 100)
                }

                Text("Reminders only fire between these hours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // ── Appearance ────────────────────────────────────────────
            Section("Appearance") {
                ColorPicker("Background color", selection: $pickedColor)
                    .onChange(of: pickedColor) { newColor in
                        if let hex = newColor.toHex() {
                            settings.backgroundColorHex = hex
                        }
                    }

                HStack {
                    Text("Opacity")
                    Slider(value: $settings.backgroundOpacity, in: 0.1...1.0, step: 0.05)
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }

                Picker("Animation", selection: $settings.animationStyle) {
                    Text("Fade").tag("fade")
                    Text("Scale").tag("scale")
                    Text("Slide").tag("slide")
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("Show for")
                    Slider(value: $settings.displayDuration, in: 2...30, step: 1)
                    Text("\(Int(settings.displayDuration)) sec")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }
            
            // ── Sound ─────────────────────────────────────────────────
            Section("Sound") {
                Toggle("Play sound with reminder", isOn: $settings.soundEnabled)

                if settings.soundEnabled {
                    HStack {
                        Picker("Sound", selection: $settings.soundName) {
                            ForEach(SoundPlayer.availableSounds, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }

                        Button("▶") {
                            SoundPlayer.play(settings.soundName)
                        }
                        .buttonStyle(.borderless)
                        .help("Preview sound")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}
