// PreferencesView.swift
import SwiftUI
import Charts

struct PreferencesView: View {
    @ObservedObject var settings: ReminderSettings
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
                
            HistoryTabView(settings: settings)
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
            
            GlobalSettingsView(settings: settings, pickedColor: $pickedColor)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            pickedColor = settings.backgroundColor
        }
    }
}

// MARK: - History Tab
struct HistoryTabView: View {
    @ObservedObject var settings: ReminderSettings
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
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.quaternary.opacity(0.5)))
                }
                .buttonStyle(.plain)

                Text(navLabel())
                    .font(.headline)
                    .frame(minWidth: 180)

                Button(action: { shift(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.quaternary.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward())
                .opacity(canGoForward() ? 1 : 0.35)
            }
            .padding(.top, 4)

            Group {
                if chartData().allSatisfy({ $0.amountML == 0 }) {
                    emptyChartState()
                } else {
                    Chart {
                        ForEach(chartData()) { dataPoint in
                            AreaMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Intake (ml)", dataPoint.amountML)
                            )
                            .interpolationMethod(timeRange == 0 ? .stepEnd : .catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.35), Color.blue.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Intake (ml)", dataPoint.amountML)
                            )
                            .interpolationMethod(timeRange == 0 ? .stepEnd : .catmullRom)
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                            PointMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Intake (ml)", dataPoint.amountML)
                            )
                            .symbolSize(dataPoint.date == hoveredDate ? 90 : 35)
                            .foregroundStyle(Color.blue)
                        }

                        RuleMark(y: .value("Goal", settings.dailyGoalML))
                            .foregroundStyle(.orange.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal \(settings.dailyGoalML) ml")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }

                        if let hoveredDate = hoveredDate, let data = chartData().first(where: { $0.date == hoveredDate }) {
                            RuleMark(x: .value("Hover", data.date))
                                .foregroundStyle(.secondary.opacity(0.25))
                                .lineStyle(StrokeStyle(lineWidth: 1))
                                .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(formatHoverDate(data.date))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(data.amountML) ml")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.blue)
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(.regularMaterial)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.08))
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                                }
                        }
                    }
                    .chartXScale(domain: chartXDomain())
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                            AxisValueLabel {
                                if let ml = value.as(Int.self) {
                                    Text("\(ml)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: timeUnit(), count: timeRange == 0 ? 4 : (timeRange == 2 ? 7 : 1))) { value in
                            AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                            AxisTick().foregroundStyle(.secondary.opacity(0.3))
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(formatAxisDate(date))
                                        .font(.caption2)
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
                                            let nearest = findNearestDate(to: date)
                                            if nearest != hoveredDate {
                                                var transaction = Transaction()
                                                transaction.disablesAnimations = true
                                                withTransaction(transaction) {
                                                    hoveredDate = nearest
                                                }
                                            }
                                        }
                                    case .ended:
                                        var transaction = Transaction()
                                        transaction.disablesAnimations = true
                                        withTransaction(transaction) {
                                            hoveredDate = nil
                                        }
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
                }
            }
            .frame(height: timeRange == 0 ? 180 : 250)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .cardStyle()
            .padding(.horizontal)
            
            // Daily: editable daily total + per-entry log editing
            if timeRange == 0 {
                VStack(alignment: .leading, spacing: 10) {
                    DailyTotalEditor(date: anchorDate)
                        .cardStyle()
                        .padding(.horizontal)

                    SectionHeader(title: "Logs", icon: "list.bullet")
                        .padding(.horizontal)

                    List {
                        ForEach(waterManager.recordsForDate(date: anchorDate)) { record in
                            HStack {
                                Text(record.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
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
                                Text(record.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
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
                            Button("+\(ml)") {
                                waterManager.addIntakeOnDate(date: sel, amountML: ml)
                            }
                            .buttonStyle(PillButtonStyle(tint: .blue, prominent: ml == 1000))
                        }
                    }
                }
                .cardStyle()
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

    @ViewBuilder
    private func emptyChartState() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "drop")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No water logged yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case 0: return waterManager.cumulativeDataForDay(date: anchorDate)
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
            formatter.locale = .appTime
            formatter.dateFormat = "HH:00"
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
            formatter.locale = .appTime
            formatter.dateFormat = "HH:mm"
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

    private var todayML: Int { waterManager.intakeForDay() }
    private var progress: Double { Double(todayML) / Double(max(settings.dailyGoalML, 1)) }

    private var goalBinding: Binding<Int> {
        Binding(
            get: { settings.dailyGoalML },
            set: { settings.dailyGoalML = max(500, $0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Water Reminder", isOn: $settings.isWaterEnabled)
                    .font(.headline)
            }

            Section("Message") {
                TextField("Message", text: $settings.waterMessage)
                    .textFieldStyle(.roundedBorder)
            }

            ReminderScheduleSection(settings: settings, type: .water, defaultQuickFillMinutes: 45)

            Section("Daily Goal") {
                HStack {
                    Text("Target")
                    Slider(value: Binding(
                        get: { Double(settings.dailyGoalML) },
                        set: { settings.dailyGoalML = max(500, Int($0)) }
                    ), in: 500...5000, step: 50)
                    TextField("ml", value: goalBinding, format: .number)
                        .frame(width: 64)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                    Text("ml")
                        .foregroundColor(.secondary)
                }
            }

            Section("Quick Add") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        WaterWaveView(progress: progress, size: 48, showsPercentLabel: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(todayML) ml")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.aquaDeep)
                        }
                        Spacer()
                        Stepper("", onIncrement: {
                            waterManager.addIntake(amountML: 100)
                        }, onDecrement: {
                            waterManager.addIntake(amountML: -100)
                        })
                        .labelsHidden()
                    }

                    WrapGrid(items: settings.drinkContainers, columns: 4) { container in
                        Button {
                            waterManager.addIntake(amountML: container.amountML)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: container.icon)
                                Text("+\(container.amountML) ml")
                            }
                        }
                        .buttonStyle(PillButtonStyle(tint: Theme.aquaDeep, prominent: container.amountML >= 1000))
                    }
                }
                .padding(.vertical, 6)
            }

            DrinkContainersSection(settings: settings)

            Section {
                Button {
                    NotificationCenter.default.post(name: .triggerWaterReminder, object: nil)
                } label: {
                    Label("Preview Water Reminder", systemImage: "eye")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Drink Containers management
struct DrinkContainersSection: View {
    @ObservedObject var settings: ReminderSettings
    @State private var editingContainer: DrinkContainer?
    @State private var isAddingContainer = false

    var body: some View {
        Section("Drink Containers") {
            ForEach(settings.drinkContainers) { container in
                HStack {
                    Image(systemName: container.icon)
                        .foregroundColor(Theme.aquaDeep)
                        .frame(width: 22)
                    Text(container.name)
                    Spacer()
                    Text("\(container.amountML) ml")
                        .foregroundColor(.secondary)
                    Button {
                        editingContainer = container
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    Button {
                        settings.deleteContainer(container.id)
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .onMove { settings.moveContainer(fromOffsets: $0, toOffset: $1) }

            Button {
                isAddingContainer = true
            } label: {
                Label("Add Container", systemImage: "plus.circle.fill")
            }
        }
        .sheet(item: $editingContainer) { container in
            DrinkContainerEditor(container: container) { updated in
                settings.updateContainer(updated)
            }
        }
        .sheet(isPresented: $isAddingContainer) {
            DrinkContainerEditor(container: DrinkContainer(name: "", amountML: 250, icon: "cup.and.saucer.fill")) { newContainer in
                settings.addContainer(name: newContainer.name, amountML: newContainer.amountML, icon: newContainer.icon)
            }
        }
    }
}

struct DrinkContainerEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var container: DrinkContainer
    let onSave: (DrinkContainer) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(container.name.isEmpty ? "New Container" : "Edit Container")
                .font(.headline)

            TextField("Name", text: $container.name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Amount")
                Slider(value: Binding(
                    get: { Double(container.amountML) },
                    set: { container.amountML = Int($0) }
                ), in: 50...2000, step: 50)
                TextField("ml", value: $container.amountML, format: .number)
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                Text("ml").foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(DrinkContainer.iconChoices, id: \.self) { icon in
                    Button {
                        container.icon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .frame(width: 34, height: 34)
                            .foregroundColor(container.icon == icon ? .white : Theme.aquaDeep)
                            .background(
                                Circle().fill(container.icon == icon ? Theme.aquaDeep : Theme.aquaDeep.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    onSave(container)
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(tint: Theme.aquaDeep, prominent: true))
                .disabled(container.name.trimmingCharacters(in: .whitespaces).isEmpty || container.amountML <= 0)
            }
        }
        .padding(20)
        .frame(width: 320)
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
            
            Section("Message") {
                TextField("Message", text: $settings.lookAwayMessage)
                    .textFieldStyle(.roundedBorder)
            }

            ReminderScheduleSection(settings: settings, type: .lookAway, defaultQuickFillMinutes: 20)

            Section {
                Button {
                    NotificationCenter.default.post(name: .triggerLookAwayReminder, object: nil)
                } label: {
                    Label("Preview Look Away Reminder", systemImage: "eye")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
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

                        Button {
                            SoundPlayer.play(settings.soundName)
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.borderless)
                        .help("Preview sound")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Reminder Schedule Section (Active Hours + Scheduled Times + Quick Fill)
struct ReminderScheduleSection: View {
    @ObservedObject var settings: ReminderSettings
    let type: ReminderType
    let defaultQuickFillMinutes: Int

    @State private var quickFillMinutes: Int = 30
    @State private var isAddingTime = false
    @State private var newTimeMinutes: Int = 9 * 60

    private var scheduledMinutes: [Int] {
        type == .water ? settings.waterScheduledMinutes : settings.lookAwayScheduledMinutes
    }

    private var activeFromBinding: Binding<Int> {
        type == .water ? $settings.waterActiveFromMinutes : $settings.lookAwayActiveFromMinutes
    }

    private var activeToBinding: Binding<Int> {
        type == .water ? $settings.waterActiveToMinutes : $settings.lookAwayActiveToMinutes
    }

    var body: some View {
        Section("Active Hours") {
            HStack {
                Text("From")
                TimeOfDayPicker(minutes: activeFromBinding)
                Text("to")
                TimeOfDayPicker(minutes: activeToBinding)
                Spacer()
            }

            Text("Reminders only fire between these hours")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Scheduled Times") {
            if scheduledMinutes.isEmpty {
                Text("No times scheduled yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                WrapGrid(items: scheduledMinutes, columns: 7) { minutes in
                    TimeChip(minutes: minutes) {
                        settings.removeScheduledTime(minutes, for: type)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Button {
                    newTimeMinutes = defaultNewTimeMinutes()
                    isAddingTime = true
                } label: {
                    Label("Add Time", systemImage: "plus.circle.fill")
                }
                .popover(isPresented: $isAddingTime) {
                    VStack(spacing: 12) {
                        TimeOfDayPicker(minutes: $newTimeMinutes)
                        Button("Add") {
                            settings.addScheduledTime(newTimeMinutes, for: type)
                            isAddingTime = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }

                Spacer()

                Stepper("Every \(quickFillMinutes) min", value: $quickFillMinutes, in: 1...180, step: 5)
                    .frame(width: 160)

                Button("Fill Schedule") {
                    settings.quickFill(everyMinutes: quickFillMinutes, for: type)
                }
                .buttonStyle(.bordered)
                .help("Replaces the times above with an even spread across your active hours")
            }
        }
        .onAppear {
            quickFillMinutes = defaultQuickFillMinutes
        }
    }

    private func defaultNewTimeMinutes() -> Int {
        scheduledMinutes.max().map { min($0 + 60, 1439) } ?? activeFromBinding.wrappedValue
    }
}

// MARK: - Time-of-day picker (24h, hour + minute adjustable)
struct TimeOfDayPicker: View {
    @Binding var minutes: Int // 0...1439

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = minutes / 60
                comps.minute = minutes % 60
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }

    var body: some View {
        DatePicker("", selection: dateBinding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.stepperField)
            .environment(\.locale, .appTime)
            .labelsHidden()
            .frame(width: 90)
    }
}

// MARK: - Scheduled time chip
struct TimeChip: View {
    let minutes: Int
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(TimeFormat.hhmm(fromMinutes: minutes))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(Color.blue.opacity(0.14)))
        .foregroundColor(.blue)
    }
}
