//
//  Muscle_MemoApp.swift
//  Muscle-Memo
//
//  Created by rsato on 2025/07/16.
//

import SwiftUI
import SwiftData

@main
struct Muscle_MemoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            Exercise.self,
            ExerciseSet.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
