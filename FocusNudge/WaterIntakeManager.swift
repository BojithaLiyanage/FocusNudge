// WaterIntakeManager.swift
import Foundation
import Combine

struct WaterIntakeRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    var amountML: Int
    
    init(id: UUID = UUID(), date: Date = Date(), amountML: Int) {
        self.id = id
        self.date = date
        self.amountML = amountML
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amountML: Int
}

class WaterIntakeManager: ObservableObject {
    @Published var records: [WaterIntakeRecord] = []
    
    private let fileName = "WaterIntakeHistory.json"
    
    init() {
        loadRecords()
    }
    
    // MARK: - Data Management
    
    func addIntake(amountML: Int) {
        let record = WaterIntakeRecord(amountML: amountML)
        records.append(record)
        saveRecords()
    }
    
    func addIntakeOnDate(date: Date, amountML: Int) {
        // Use noon of that day so it's clearly within the day
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let record = WaterIntakeRecord(date: noon, amountML: amountML)
        records.append(record)
        saveRecords()
    }
    
    func updateRecord(id: UUID, newAmountML: Int) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].amountML = newAmountML
            saveRecords()
        }
    }

    /// Set the total intake for a given day. Non-destructive: keeps existing
    /// time-stamped logs and appends a single adjustment record for the difference.
    func setDailyTotal(date: Date, totalML: Int) {
        let clamped = max(0, totalML)
        let delta = clamped - intakeForDay(date: date)
        if delta == 0 { return }

        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        records.append(WaterIntakeRecord(date: noon, amountML: delta))
        saveRecords()
    }
    
    func deleteRecord(id: UUID) {
        records.removeAll(where: { $0.id == id })
        saveRecords()
    }
    
    private func getFileURL() -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("FocusNudge", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appSupportDir.path) {
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appSupportDir.appendingPathComponent(fileName)
    }
    
    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: getFileURL(), options: [.atomic, .completeFileProtection])
            
            // Force UI update
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            print("Error saving water intake records: \(error)")
        }
    }
    
    private func loadRecords() {
        let fileURL = getFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loadedRecords = try JSONDecoder().decode([WaterIntakeRecord].self, from: data)
            // Optional: filter out records older than 12 months to save space
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            self.records = loadedRecords.filter { $0.date >= oneYearAgo }
        } catch {
            print("Error loading water intake records: \(error)")
        }
    }
    
    // MARK: - Text Statistics
    
    func recordsForDate(date: Date) -> [WaterIntakeRecord] {
        records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted(by: { $0.date < $1.date })
    }
    
    func intakeForDay(date: Date = Date()) -> Int {
        recordsForDate(date: date).reduce(0) { $0 + $1.amountML }
    }
    
    func intakeForWeek(date: Date = Date()) -> Int {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return records.filter { weekInterval.contains($0.date) }
            .reduce(0) { $0 + $1.amountML }
    }
    
    func intakeForMonth(date: Date = Date()) -> Int {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: date) else { return 0 }
        return records.filter { monthInterval.contains($0.date) }
            .reduce(0) { $0 + $1.amountML }
    }
    
    // MARK: - Chart Aggregations
    
    func exactTimeDataForDay(date: Date = Date()) -> [ChartDataPoint] {
        return recordsForDate(date: date).map { ChartDataPoint(date: $0.date, amountML: $0.amountML) }
    }
    
    func dailyDataForLast7Days() -> [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for i in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let amount = intakeForDay(date: date)
            data.append(ChartDataPoint(date: date, amountML: amount))
        }
        return data
    }
    
    /// Seven data points for the calendar week containing `date`.
    func dailyDataForWeek(date: Date) -> [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }

        for i in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: weekInterval.start) else { continue }
            let amount = intakeForDay(date: dayDate)
            data.append(ChartDataPoint(date: calendar.startOfDay(for: dayDate), amountML: amount))
        }
        return data
    }

    func dailyDataForMonth(date: Date) -> [ChartDataPoint] {
        var data: [ChartDataPoint] = []
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        guard let daysInMonth = calendar.range(of: .day, in: .month, for: date) else { return [] }
        
        for day in daysInMonth {
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else { continue }
            let amount = intakeForDay(date: dayDate)
            data.append(ChartDataPoint(date: dayDate, amountML: amount))
        }
        
        return data
    }
}
