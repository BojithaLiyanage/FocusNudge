// DrinkContainer.swift
import Foundation

/// A user-defined drink container (cup, bottle, etc.) used for quick-add water logging.
struct DrinkContainer: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amountML: Int
    var icon: String = "cup.and.saucer.fill"

    static let defaults: [DrinkContainer] = [
        DrinkContainer(name: "Small Cup", amountML: 100, icon: "cup.and.saucer.fill"),
        DrinkContainer(name: "Cup", amountML: 200, icon: "cup.and.saucer.fill"),
        DrinkContainer(name: "Glass", amountML: 300, icon: "waterbottle.fill"),
        DrinkContainer(name: "Bottle", amountML: 500, icon: "waterbottle.fill"),
        DrinkContainer(name: "Large Bottle", amountML: 1000, icon: "waterbottle.fill")
    ]

    static let iconChoices = [
        "cup.and.saucer.fill", "waterbottle.fill", "mug.fill",
        "takeoutbag.and.cup.and.straw.fill", "wineglass.fill", "drop.fill"
    ]
}
