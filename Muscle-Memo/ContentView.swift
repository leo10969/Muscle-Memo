//
//  ContentView.swift
//  Muscle-Memo
//
//  Created by rsato on 2025/07/16.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("ホーム")
                }
                .tag(0)
            
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("カレンダー")
                }
                .tag(1)
                .id("CalendarView") // 固有のIDを設定
            
            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("統計")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// ホーム画面
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    @State private var showingNewWorkoutSheet = false
    @State private var showingWorkoutDetail = false
    @State private var selectedWorkoutSession: WorkoutSession?
    @State private var selectedDateForNewWorkout: Date?
    @State private var showingSuggestionSheet = false
    @State private var selectedSuggestionBodyPart: BodyPart?
    @State private var showingQuickWorkoutSheet = false
    @State private var selectedQuickAccessBodyPart: BodyPart?
    @State private var showingWorkoutOptions = false

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 今日の統計情報
                        TodayStatsCard(workoutSessions: workoutSessions)
                        
                        // 週間統計
                        WeeklyStatsCard(workoutSessions: workoutSessions)
                        
                        // 連続日数とストリーク
                        StreakCard(workoutSessions: workoutSessions)
                        
                        // 次のトレーニング提案
                        NextWorkoutSuggestionCard(onSuggestionTap: { suggestedBodyPart in
                            selectedSuggestionBodyPart = suggestedBodyPart
                            showingQuickWorkoutSheet = true
                        })
                        
                        // クイックアクセス（よく使う部位）
                        QuickAccessCard(workoutSessions: workoutSessions, onBodyPartSelected: { bodyPart in
                            selectedQuickAccessBodyPart = bodyPart
                            showingNewWorkoutSheet = true
                        })
                        
                        // 最近のワークアウト（改善版）
                        ImprovedRecentWorkoutsSection(
                            workoutSessions: Array(workoutSessions.prefix(5)),
                            onWorkoutTap: { session in
                                selectedWorkoutSession = session
                                showingWorkoutDetail = true
                            }
                        )
                        
                        // FloatingActionButtonのためのスペース
                        Spacer()
                            .frame(height: 80)
                    }
                    .padding()
                }
                
                // 右下固定のFloating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showingWorkoutOptions = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("ホーム")
            .sheet(isPresented: $showingNewWorkoutSheet, onDismiss: {
                selectedDateForNewWorkout = nil
                selectedSuggestionBodyPart = nil
                selectedQuickAccessBodyPart = nil
            }) {
                if let selectedDate = selectedDateForNewWorkout {
                    NewWorkoutSheet(initialDate: selectedDate)
                } else if let suggestedBodyPart = selectedSuggestionBodyPart {
                    NewWorkoutSheetWithSuggestion(suggestedBodyPart: suggestedBodyPart)
                } else if let quickAccessBodyPart = selectedQuickAccessBodyPart {
                    NewWorkoutSheetWithBodyPart(initialBodyPart: quickAccessBodyPart)
                } else {
                    NewWorkoutSheet()
                }
            }
            .sheet(isPresented: $showingWorkoutDetail) {
                if let selectedSession = selectedWorkoutSession {
                    WorkoutDetailSheet(
                        date: selectedSession.date,
                        sessions: workoutSessions,
                        onAddWorkout: { date in
                            selectedDateForNewWorkout = date
                            showingNewWorkoutSheet = true
                        }
                    )
                }
            }
            .sheet(isPresented: $showingSuggestionSheet) {
                WorkoutSuggestionSheet(
                    onSuggestionSelected: { bodyPart in
                        selectedSuggestionBodyPart = bodyPart
                        showingSuggestionSheet = false
                        showingNewWorkoutSheet = true
                    }
                )
            }
            .sheet(isPresented: $showingQuickWorkoutSheet, onDismiss: {
                selectedSuggestionBodyPart = nil
            }) {
                let bodyPart = selectedSuggestionBodyPart ?? .chest
                QuickWorkoutSheet(
                    suggestedBodyPart: bodyPart,
                    allSessions: Array(workoutSessions)
                )
            }
            .confirmationDialog("ワークアウトを開始", isPresented: $showingWorkoutOptions, titleVisibility: .visible) {
                Button("新しいワークアウト") {
                    showingNewWorkoutSheet = true
                }
                
                Button("提案されたワークアウト") {
                    let suggestion = getNextWorkoutSuggestion()
                    selectedSuggestionBodyPart = suggestion
                    showingQuickWorkoutSheet = true
                }
                
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("どのようにワークアウトを開始しますか？")
            }
        }
    }
    
    private func getNextWorkoutSuggestion() -> BodyPart? {
        guard !workoutSessions.isEmpty else { return .chest }
        
        let recentSessions = workoutSessions.prefix(10)
        let recentBodyParts = recentSessions.flatMap { $0.trainedBodyParts }
        let bodyPartCounts = Dictionary(grouping: recentBodyParts, by: { $0 })
            .mapValues { $0.count }
        
        // メイン部位（必須部位）のみを対象にした提案
        return BodyPart.requiredParts.min { bodyPart1, bodyPart2 in
            bodyPartCounts[bodyPart1, default: 0] < bodyPartCounts[bodyPart2, default: 0]
        }
    }
}

// カレンダー画面
struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var currentMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedFilterBodyPart: BodyPart? = nil
    @State private var showingWorkoutDetail = false
    @State private var showingNewWorkoutSheet = false
    @State private var selectedDateForNewWorkout: Date?
    @State private var detailDate: Date? // WorkoutDetailSheetに渡す専用の日付
    @State private var isViewAppeared = false // ビューの表示状態を管理
    @State private var refreshID = UUID() // ビューの強制再描画用
    
    // カレンダー用の統一された設定
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()
    
    // フィルタリング後のワークアウトセッション
    private var filteredWorkoutSessions: [WorkoutSession] {
        guard let filterBodyPart = selectedFilterBodyPart else { 
            return Array(workoutSessions) 
        }
        return workoutSessions.filter { session in
            session.trainedBodyParts.contains(filterBodyPart)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // スクロール可能なメインコンテンツ
                ScrollView {
                    VStack(spacing: 16) {
                        // 部位フィルター（カラー統合版）
                        BodyPartFilterWithColorView(selectedBodyPart: $selectedFilterBodyPart)
                        
                        // カスタムカレンダー
                        CustomCalendarView(
                            currentMonth: $currentMonth,
                            selectedDate: $selectedDate,
                            workoutSessions: filteredWorkoutSessions,
                            onDateTap: { date in
                                // タイムゾーンを明示的に設定したカレンダーで正規化
                                var calendarForNormalization = Calendar.current
                                calendarForNormalization.timeZone = TimeZone.current
                                
                                // 日付をJSTの00:00に正規化
                                let normalizedDate = calendarForNormalization.startOfDay(for: date)
                                
                                print("=== Calendar Date Tap Debug ===")
                                print("Original tapped date: \(date)")
                                print("Normalized tapped date: \(normalizedDate)")
                                print("Current selectedDate: \(selectedDate)")
                                print("Current detailDate: \(detailDate?.description ?? "nil")")
                                print("isViewAppeared: \(isViewAppeared)")
                                print("TimeZone: \(calendarForNormalization.timeZone.identifier)")
                                
                                // 確実に状態を更新（正規化された日付を使用）
                                selectedDate = normalizedDate
                                detailDate = normalizedDate
                                
                                print("Updated detailDate: \(detailDate?.description ?? "nil")")
                                print("Updated selectedDate: \(selectedDate)")
                                print("Showing workout detail immediately")
                                showingWorkoutDetail = true
                            }
                        )
                        .id(refreshID) // 強制再描画のためのID
                    }
                    .padding(.bottom, 100) // ボタンとのスペースを確保
                }
                
                // 固定の新しいワークアウト開始ボタン
                VStack {
                    Divider()
                    
                    Button(action: {
                        showingNewWorkoutSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("新しいワークアウトを開始")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("カレンダー")
            .onAppear {
                print("CalendarView appeared") // デバッグ用
                // ビュー表示時の初期化処理
                if !isViewAppeared {
                    isViewAppeared = true
                    // 状態を明示的にリセット
                    detailDate = nil
                    showingWorkoutDetail = false
                    // 現在の日付で月を初期化（startOfDayで正規化）
                    var initCalendar = Calendar.current
                    initCalendar.timeZone = TimeZone.current
                    let today = initCalendar.startOfDay(for: Date())
                    currentMonth = today
                    selectedDate = today
                    // ビューの強制再描画
                    refreshID = UUID()
                    print("CalendarView initialized with date: \(today)")
                    print("Init TimeZone: \(initCalendar.timeZone.identifier)")
                }
            }
            .onDisappear {
                print("CalendarView disappeared") // デバッグ用
                // ビュー非表示時のクリーンアップ
                detailDate = nil
                showingWorkoutDetail = false
            }
            .sheet(isPresented: $showingWorkoutDetail, onDismiss: {
                print("WorkoutDetailSheet dismissed")
                detailDate = nil // シートが閉じられた時にリセット
            }) {
                // 強制的にdetailDateを使用（nilの場合はselectedDate）
                let dateToUse = detailDate ?? selectedDate
                let _ = print("=== WorkoutDetailSheet created with date: \(dateToUse) ===")
                WorkoutDetailSheet(
                    date: dateToUse,
                    sessions: Array(workoutSessions),
                    onAddWorkout: { date in
                        selectedDateForNewWorkout = date
                        showingNewWorkoutSheet = true
                    }
                )
            }
            .sheet(isPresented: $showingNewWorkoutSheet, onDismiss: {
                selectedDateForNewWorkout = nil
            }) {
                if let selectedDate = selectedDateForNewWorkout {
                    NewWorkoutSheet(initialDate: selectedDate)
                } else {
                    NewWorkoutSheet()
                }
            }
        }
    }
}



// 統計画面
struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutSessions: [WorkoutSession]
    @State private var showingExportMenu = false
    @State private var exportDocument: CSVDocument?
    @State private var showingDocumentPicker = false
    @State private var showingImportPicker = false
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?
    @State private var importError: ImportError?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 称号・ランク表示
                    TitleCard(sessions: workoutSessions)
                    
                    // 週間統計（修正版）
                    WeeklyStatsCard(workoutSessions: workoutSessions)
                    
                    // 週ごとのワークアウト推移グラフ
                    WeeklyTrendCard(sessions: workoutSessions)
                    
                    // 面白い統計
                    FunFactsCard(sessions: workoutSessions)
                    
                    // パーソナルレコード
                    PersonalRecordsCard(sessions: workoutSessions)
                    
                    // 月別統計
                    MonthlyStatsCard(sessions: workoutSessions)
                    
                    // 部位別詳細統計（グラフ付き）
                    DetailedBodyPartStatsCard(sessions: workoutSessions)
                    
                    // 継続ランキング
                    ConsistencyCard(sessions: workoutSessions)
                    
                }
                .padding()
            }
            .navigationTitle("統計")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingImportPicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingExportMenu = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(workoutSessions.isEmpty)
                }
            }
            .actionSheet(isPresented: $showingExportMenu) {
                ActionSheet(
                    title: Text("データをエクスポート"),
                    message: Text("エクスポートする形式を選択してください"),
                    buttons: [
                        .default(Text("📊 全ワークアウトデータ")) {
                            exportWorkouts()
                        },
                        .default(Text("📈 日別統計データ")) {
                            exportStats()
                        },
                        .default(Text("💪 部位別統計データ")) {
                            exportBodyPartStats()
                        },
                        .cancel(Text("キャンセル"))
                    ]
                )
            }
            .fileExporter(
                isPresented: $showingDocumentPicker,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: exportDocument?.filename ?? "export"
            ) { result in
                switch result {
                case .success(let url):
                    print("ファイルが保存されました: \(url)")
                case .failure(let error):
                    print("エクスポートエラー: \(error.localizedDescription)")
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("インポート結果", isPresented: $showingImportResult) {
                Button("OK") { }
            } message: {
                if let result = importResult {
                    Text(generateImportResultMessage(result))
                } else if let error = importError {
                    Text("エラー: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func exportWorkouts() {
        let csvContent = DataExporter.exportWorkoutsToCSV(sessions: workoutSessions)
        let filename = DataExporter.generateFileName(prefix: "muscle_memo_workouts")
        exportDocument = CSVDocument(content: csvContent, filename: filename)
        showingDocumentPicker = true
    }
    
    private func exportStats() {
        let csvContent = DataExporter.exportStatsToCSV(sessions: workoutSessions)
        let filename = DataExporter.generateFileName(prefix: "muscle_memo_stats")
        exportDocument = CSVDocument(content: csvContent, filename: filename)
        showingDocumentPicker = true
    }
    
    private func exportBodyPartStats() {
        let csvContent = DataExporter.exportBodyPartStatsToCSV(sessions: workoutSessions)
        let filename = DataExporter.generateFileName(prefix: "muscle_memo_bodypart_stats")
        exportDocument = CSVDocument(content: csvContent, filename: filename)
        showingDocumentPicker = true
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            
            do {
                let csvContent = try String(contentsOf: fileURL, encoding: .utf8)
                let importResult = DataExporter.importWorkoutsFromCSV(csvContent: csvContent)
                
                switch importResult {
                case .success(let result):
                    // データベースに保存
                    saveImportedSessions(result.importedSessions)
                    self.importResult = result
                    self.importError = nil
                    showingImportResult = true
                    
                case .failure(let error):
                    self.importError = error
                    self.importResult = nil
                    showingImportResult = true
                }
                
            } catch {
                self.importError = ImportError.parseError("ファイルの読み込みに失敗しました: \(error.localizedDescription)")
                self.importResult = nil
                showingImportResult = true
            }
            
        case .failure(let error):
            self.importError = ImportError.parseError("ファイル選択エラー: \(error.localizedDescription)")
            self.importResult = nil
            showingImportResult = true
        }
    }
    
    private func saveImportedSessions(_ sessions: [WorkoutSession]) {
        for session in sessions {
            modelContext.insert(session)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("データ保存エラー: \(error.localizedDescription)")
        }
    }
    
    private func generateImportResultMessage(_ result: ImportResult) -> String {
        var message = "インポートが完了しました。\n\n"
        message += "✅ 成功: \(result.successCount)セッション\n"
        message += "📊 処理行数: \(result.processedCount)行\n"
        
        if result.skippedCount > 0 {
            message += "⚠️ スキップ: \(result.skippedCount)行\n"
        }
        
        if result.hasErrors {
            message += "\n⚠️ エラー詳細:\n"
            let errorCount = min(result.errors.count, 5) // 最大5個まで表示
            for i in 0..<errorCount {
                message += "• \(result.errors[i])\n"
            }
            if result.errors.count > 5 {
                message += "...他\(result.errors.count - 5)件\n"
            }
        }
        
        return message
    }
}

// MARK: - サポートビュー

struct NextWorkoutSuggestionCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    let onSuggestionTap: (BodyPart?) -> Void
    
    var body: some View {
        Button(action: {
            onSuggestionTap(getNextWorkoutSuggestion())
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("次のトレーニング提案")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let suggestion = getNextWorkoutSuggestion() {
                    Text("\(suggestion.displayName)のトレーニングがおすすめです")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(suggestion.defaultExercises.prefix(3), id: \.self) { exercise in
                            Text(exercise)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Text("今日から筋トレを始めましょう！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("タップして前回の種目でクイックスタート")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getNextWorkoutSuggestion() -> BodyPart? {
        guard !workoutSessions.isEmpty else { return .chest }
        
        let recentSessions = workoutSessions.prefix(10)
        let recentBodyParts = recentSessions.flatMap { $0.trainedBodyParts }
        let bodyPartCounts = Dictionary(grouping: recentBodyParts, by: { $0 })
            .mapValues { $0.count }
        
        // メイン部位（必須部位）のみを対象にした提案
        return BodyPart.requiredParts.min { bodyPart1, bodyPart2 in
            bodyPartCounts[bodyPart1, default: 0] < bodyPartCounts[bodyPart2, default: 0]
        }
    }
}

struct WorkoutSuggestionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    let onSuggestionSelected: (BodyPart) -> Void
    
    private var suggestions: [BodyPart] {
        guard !workoutSessions.isEmpty else { return [.chest, .legs, .back] }
        
        let recentSessions = workoutSessions.prefix(20)
        let recentBodyParts = recentSessions.flatMap { $0.trainedBodyParts }
        let bodyPartCounts = Dictionary(grouping: recentBodyParts, by: { $0 })
            .mapValues { $0.count }
        
        return BodyPart.requiredParts.sorted { bodyPart1, bodyPart2 in
            bodyPartCounts[bodyPart1, default: 0] < bodyPartCounts[bodyPart2, default: 0]
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("おすすめのワークアウト")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("最近のトレーニング履歴から、今日におすすめの部位を提案します")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(suggestions, id: \.self) { bodyPart in
                            WorkoutSuggestionRow(
                                bodyPart: bodyPart,
                                workoutSessions: workoutSessions,
                                onSelect: {
                                    onSuggestionSelected(bodyPart)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("ワークアウト提案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WorkoutSuggestionRow: View {
    let bodyPart: BodyPart
    let workoutSessions: [WorkoutSession]
    let onSelect: () -> Void
    
    private var lastWorkoutDate: Date? {
        workoutSessions.first { session in
            session.trainedBodyParts.contains(bodyPart)
        }?.date
    }
    
    private var daysSinceLastWorkout: Int? {
        guard let lastDate = lastWorkoutDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(bodyPart.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(.white)
                            .font(.caption)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bodyPart.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let days = daysSinceLastWorkout {
                        Text("\(days)日前")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("未実施")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        ForEach(bodyPart.primaryExercises.prefix(2), id: \.self) { exercise in
                            Text(exercise)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(bodyPart.color.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ホーム画面用の新しいカードコンポーネント

struct TodayStatsCard: View {
    let workoutSessions: [WorkoutSession]
    
    private var todaysSessions: [WorkoutSession] {
        workoutSessions.filter { Calendar.current.isDateInToday($0.date) }
    }
    
    private var todaysVolume: Double {
        todaysSessions.reduce(0) { $0 + $1.totalVolume }
    }
    
    private var todaysExerciseCount: Int {
        todaysSessions.reduce(0) { $0 + $1.exercises.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日の記録")
                .font(.headline)
                .fontWeight(.bold)
            
            if todaysSessions.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("今日はまだワークアウトしていません")
                            .font(.subheadline)
                        Text("右下のボタンから開始しましょう！")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            } else {
                HStack(spacing: 20) {
                    VStack {
                        Text("\(todaysExerciseCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("種目")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text(String(format: "%.0f", todaysVolume))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("総重量(kg)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(todaysSessions.count)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("セッション")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeeklyStatsCard: View {
    let workoutSessions: [WorkoutSession]
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 1 // 日曜日を週の開始日に設定（1=日曜日, 2=月曜日）
        return cal
    }
    
    private var weekInterval: DateInterval? {
        calendar.dateInterval(of: .weekOfYear, for: Date())
    }
    
    private var weekSessions: [WorkoutSession] {
        guard let interval = weekInterval else { return [] }
        return workoutSessions.filter { session in
            let sessionDay = calendar.startOfDay(for: session.date)
            let weekStart = calendar.startOfDay(for: interval.start) // 日曜日 0:00
            let weekEnd = calendar.startOfDay(for: interval.end)     // 次の日曜日 0:00
            
            // 日曜日 0:00 から 土曜日 23:59:59 まで
            // sessionDay >= weekStart: 日曜日 0:00 以降
            // sessionDay < weekEnd: 次の日曜日 0:00 未満（つまり土曜日 23:59:59 まで）
            return sessionDay >= weekStart && sessionDay < weekEnd
        }
    }
    
    private var weeklyVolume: Double {
        weekSessions.reduce(0) { $0 + $1.totalVolume }
    }
    
    private var weeklyBodyPartCounts: [(bodyPart: BodyPart, count: Int)] {
        let allBodyParts = weekSessions.flatMap { $0.trainedBodyParts }
        let bodyPartCounts = Dictionary(grouping: allBodyParts, by: { $0 })
            .mapValues { $0.count }
        
        return bodyPartCounts.map { (bodyPart: $0.key, count: $0.value) }
            .sorted { $0.bodyPart.displayName < $1.bodyPart.displayName }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("今週の統計")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("今日: \(Date().formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    // デバッグ情報（開発中のみ表示）
                    if let interval = weekInterval {
                        let weekEndDisplay = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
                        Text("週の範囲: \(interval.start.formatted(date: .abbreviated, time: .shortened)) 〜 \(weekEndDisplay.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("（日曜日 0:00 〜 土曜日 23:59）")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 詳細デバッグ情報：今週のワークアウト一覧
                if !weekSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今週のワークアウト:")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        ForEach(Array(weekSessions.enumerated()), id: \.offset) { index, session in
                            let dayOfWeek = calendar.component(.weekday, from: session.date)
                            let weekdayNames = ["", "日", "月", "火", "水", "木", "金", "土"]
                            let exerciseCount = session.exercises.count
                            let setCount = session.exercises.reduce(0) { $0 + $1.sets.count }
                            Text("\(index + 1). \(session.date.formatted(date: .abbreviated, time: .shortened)) (\(weekdayNames[dayOfWeek])) - \(exerciseCount)種目, \(setCount)セット")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            if weekSessions.isEmpty {
                Text("今週はまだワークアウトしていません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("ワークアウト回数")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(weekSessions.count)回")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("総重量")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.0fkg", weeklyVolume))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("部位別回数:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                            ForEach(weeklyBodyPartCounts, id: \.bodyPart) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(item.bodyPart.color)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(item.bodyPart.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(item.count)回")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeeklyTrendCard: View {
    let sessions: [WorkoutSession]
    @State private var showingVolume = false
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 1 // 日曜日を週の開始日に設定
        return cal
    }
    
    private var weeklyData: [(weekLabel: String, count: Int, volume: Double)] {
        let now = Date()
        
        // 過去8週間のデータを取得
        var weeklyData: [(weekLabel: String, count: Int, volume: Double)] = []
        
        for weekOffset in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }
            
            let weekSessions = sessions.filter { session in
                let sessionDay = calendar.startOfDay(for: session.date)
                let weekStart = calendar.startOfDay(for: weekInterval.start) // 日曜日 0:00
                let weekEnd = calendar.startOfDay(for: weekInterval.end)     // 次の日曜日 0:00
                
                // 日曜日 0:00 から 土曜日 23:59:59 まで
                // sessionDay >= weekStart: 日曜日 0:00 以降
                // sessionDay < weekEnd: 次の日曜日 0:00 未満（つまり土曜日 23:59:59 まで）
                return sessionDay >= weekStart && sessionDay < weekEnd
            }
            
            let weekVolume = weekSessions.reduce(0.0) { $0 + $1.totalVolume }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            formatter.locale = Locale(identifier: "ja_JP")
            
            let weekLabel = weekOffset == 0 ? "今週" : formatter.string(from: weekInterval.start)
            weeklyData.append((weekLabel: weekLabel, count: weekSessions.count, volume: weekVolume))
        }
        
        return weeklyData
    }
    
    private var maxCount: Int {
        weeklyData.map { $0.count }.max() ?? 1
    }
    
    private var maxVolume: Double {
        weeklyData.map { $0.volume }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("週ごとのワークアウト推移（日曜〜土曜）")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 切り替えボタン
                Button(action: {
                    showingVolume.toggle()
                }) {
                    Text(showingVolume ? "重量" : "回数")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            
            if weeklyData.allSatisfy({ $0.count == 0 && $0.volume == 0 }) {
                Text("まだ記録がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weeklyData, id: \.weekLabel) { data in
                        VStack(spacing: 4) {
                            // バーグラフ
                            Rectangle()
                                .fill(getBarColor(data: data))
                                .frame(width: 30, height: getBarHeight(data: data))
                                .cornerRadius(4)
                            
                            // 値表示
                            Text(getDisplayValue(data: data))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(getValueColor(data: data))
                            
                            // 週ラベル
                            Text(data.weekLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getBarColor(data: (weekLabel: String, count: Int, volume: Double)) -> Color {
        if showingVolume {
            return data.volume > 0 ? Color.green : Color.gray.opacity(0.3)
        } else {
            return data.count > 0 ? Color.blue : Color.gray.opacity(0.3)
        }
    }
    
    private func getBarHeight(data: (weekLabel: String, count: Int, volume: Double)) -> CGFloat {
        if showingVolume {
            return max(CGFloat(data.volume) / CGFloat(maxVolume) * 60, 4)
        } else {
            return max(CGFloat(data.count) / CGFloat(maxCount) * 60, 4)
        }
    }
    
    private func getDisplayValue(data: (weekLabel: String, count: Int, volume: Double)) -> String {
        if showingVolume {
            return String(format: "%.0f", data.volume)
        } else {
            return "\(data.count)"
        }
    }
    
    private func getValueColor(data: (weekLabel: String, count: Int, volume: Double)) -> Color {
        if showingVolume {
            return data.volume > 0 ? .primary : .secondary
        } else {
            return data.count > 0 ? .primary : .secondary
        }
    }
}

struct DetailedBodyPartStatsCard: View {
    let sessions: [WorkoutSession]
    
    private var bodyPartData: [(bodyPart: BodyPart, count: Int, volume: Double)] {
        var bodyPartStats: [BodyPart: (count: Int, volume: Double)] = [:]
        
        for session in sessions {
            for bodyPart in session.trainedBodyParts {
                let currentStats = bodyPartStats[bodyPart] ?? (count: 0, volume: 0.0)
                let bodyPartVolume = session.exercises
                    .filter { $0.bodyPart == bodyPart }
                    .reduce(0.0) { $0 + $1.totalVolume }
                
                bodyPartStats[bodyPart] = (
                    count: currentStats.count + 1,
                    volume: currentStats.volume + bodyPartVolume
                )
            }
        }
        
        return bodyPartStats.map { (bodyPart: $0.key, count: $0.value.count, volume: $0.value.volume) }
            .sorted { $0.count > $1.count }
    }
    
    private var maxCount: Int {
        bodyPartData.map { $0.count }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("部位別詳細統計")
                .font(.headline)
                .fontWeight(.bold)
            
            if bodyPartData.isEmpty {
                Text("まだ記録がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(bodyPartData, id: \.bodyPart) { data in
                        VStack(alignment: .leading, spacing: 6) {
                            // 部位名と統計
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(data.bodyPart.color)
                                        .frame(width: 16, height: 16)
                                    
                                    Text(data.bodyPart.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(data.count)回")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    
                                    Text("\(String(format: "%.0f", data.volume))kg")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 横バーグラフ
                            HStack(spacing: 4) {
                                Rectangle()
                                    .fill(data.bodyPart.color.opacity(0.8))
                                    .frame(height: 8)
                                    .frame(width: CGFloat(data.count) / CGFloat(maxCount) * 200)
                                    .cornerRadius(4)
                                
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StreakCard: View {
    let workoutSessions: [WorkoutSession]
    
    private var workoutStreak: Int {
        // ワークアウトが記録された日付を取得（重複除去）
        let workoutDates = Set(workoutSessions.map { Calendar.current.startOfDay(for: $0.date) })
        let sortedDates = workoutDates.sorted(by: >)
        
        guard !sortedDates.isEmpty else { return 0 }
        
        var streak = 0
        let today = Calendar.current.startOfDay(for: Date())
        
        // 今日または昨日からストリークが始まっているかチェック
        let daysSinceLastWorkout = Calendar.current.dateComponents([.day], from: sortedDates[0], to: today).day ?? 0
        
        if daysSinceLastWorkout > 1 {
            return 0 // 2日以上空いている場合はストリーク切れ
        }
        
        // 連続する日数をカウント
        var previousDate = sortedDates[0]
        streak = 1
        
        for i in 1..<sortedDates.count {
            let currentDate = sortedDates[i]
            let daysBetween = Calendar.current.dateComponents([.day], from: currentDate, to: previousDate).day ?? 0
            
            if daysBetween == 1 {
                streak += 1
                previousDate = currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("連続記録")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.title)
                
                VStack(alignment: .leading) {
                    Text("\(workoutStreak)日連続")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if workoutStreak > 0 {
                        Text("素晴らしい継続力です！")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("今日から新しいストリークを始めましょう")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickAccessCard: View {
    let workoutSessions: [WorkoutSession]
    let onBodyPartSelected: (BodyPart) -> Void
    
    private var frequentBodyParts: [BodyPart] {
        let bodyPartCounts = Dictionary(grouping: workoutSessions.flatMap { $0.trainedBodyParts }) { $0 }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        return Array(bodyPartCounts.prefix(4).map { $0.key })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("よく使う部位")
                .font(.headline)
                .fontWeight(.bold)
            
            if frequentBodyParts.isEmpty {
                Text("ワークアウトを記録すると、よく使う部位が表示されます")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(frequentBodyParts, id: \.self) { bodyPart in
                        Button(action: {
                            onBodyPartSelected(bodyPart)
                        }) {
                            HStack {
                                Circle()
                                    .fill(bodyPart.color)
                                    .frame(width: 20, height: 20)
                                
                                Text(bodyPart.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ImprovedRecentWorkoutsSection: View {
    let workoutSessions: [WorkoutSession]
    let onWorkoutTap: (WorkoutSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近のワークアウト")
                .font(.headline)
                .fontWeight(.bold)
            
            if workoutSessions.isEmpty {
                Text("まだワークアウトが記録されていません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(workoutSessions, id: \.date) { session in
                        ImprovedWorkoutSessionRow(session: session)
                            .onTapGesture {
                                onWorkoutTap(session)
                            }
                    }
                }
            }
        }
    }
}

struct ImprovedWorkoutSessionRow: View {
    let session: WorkoutSession
    
    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d(E) HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 日時と部位
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatter.string(from: session.date))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        ForEach(Array(session.trainedBodyParts), id: \.self) { bodyPart in
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(bodyPart.color)
                                    .frame(width: 8, height: 8)
                                Text(bodyPart.displayName)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(bodyPart.color.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(String(format: "%.1fkg", session.totalVolume))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("総重量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 種目数と詳細情報
            HStack {
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "dumbbell")
                            .foregroundColor(.blue)
                        Text("\(session.exercises.count)種目")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.purple)
                        Text("\(session.totalSets)セット")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - 新しい統計メニュー用カードコンポーネント

struct TitleCard: View {
    let sessions: [WorkoutSession]
    
    private var currentTitle: (title: String, emoji: String, description: String) {
        let totalWorkouts = sessions.count
        let totalVolume = sessions.reduce(0) { $0 + $1.totalVolume }
        let streakDays = calculateStreak()
        
        if totalWorkouts >= 100 {
            return ("筋肉の帝王", "👑", "100回のワークアウトを達成！")
        } else if totalWorkouts >= 50 {
            return ("鉄の戦士", "⚔️", "50回のワークアウトを達成！")
        } else if totalVolume >= 10000 {
            return ("重量マスター", "💪", "総重量10トンを突破！")
        } else if streakDays >= 30 {
            return ("継続王", "🏆", "30日連続でワークアウト！")
        } else if totalWorkouts >= 20 {
            return ("筋トレ中級者", "🔥", "20回のワークアウトを達成！")
        } else if totalWorkouts >= 10 {
            return ("トレーニング愛好家", "💪", "10回のワークアウトを達成！")
        } else if totalWorkouts >= 5 {
            return ("頑張り屋さん", "⭐", "5回のワークアウトを達成！")
        } else {
            return ("筋トレ初心者", "🌱", "まずは継続から始めよう！")
        }
    }
    
    private func calculateStreak() -> Int {
        // ワークアウトが記録された日付を取得（重複除去）
        let workoutDates = Set(sessions.map { Calendar.current.startOfDay(for: $0.date) })
        let sortedDates = workoutDates.sorted(by: >)
        
        guard !sortedDates.isEmpty else { return 0 }
        
        var streak = 0
        let today = Calendar.current.startOfDay(for: Date())
        
        // 今日または昨日からストリークが始まっているかチェック
        let daysSinceLastWorkout = Calendar.current.dateComponents([.day], from: sortedDates[0], to: today).day ?? 0
        
        if daysSinceLastWorkout > 1 {
            return 0 // 2日以上空いている場合はストリーク切れ
        }
        
        // 連続する日数をカウント
        var previousDate = sortedDates[0]
        streak = 1
        
        for i in 1..<sortedDates.count {
            let currentDate = sortedDates[i]
            let daysBetween = Calendar.current.dateComponents([.day], from: currentDate, to: previousDate).day ?? 0
            
            if daysBetween == 1 {
                streak += 1
                previousDate = currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // タイトル部分
            VStack(spacing: 8) {
                Text(currentTitle.emoji)
                    .font(.system(size: 60))
                
                Text(currentTitle.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(currentTitle.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 基本統計
            HStack(spacing: 20) {
                VStack {
                    Text("\(sessions.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("ワークアウト")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(String(format: "%.0f", sessions.reduce(0) { $0 + $1.totalVolume }))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("総重量(kg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(calculateStreak())")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("連続日数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

struct FunFactsCard: View {
    let sessions: [WorkoutSession]
    
    private var funFacts: [String] {
        let totalVolume = sessions.reduce(0) { $0 + $1.totalVolume }
        let totalSets = sessions.reduce(0) { $0 + $1.totalSets }
        let averagePerSession = sessions.isEmpty ? 0 : totalVolume / Double(sessions.count)
        
        var facts: [String] = []
        
        if totalVolume > 0 {
            let elephants = totalVolume / 4000 // 象の体重約4トン
            if elephants >= 1 {
                facts.append("🐘 今までに持ち上げた重量は象約\(String(format: "%.1f", elephants))頭分！")
            }
            
            let cars = totalVolume / 1200 // 小型車約1.2トン
            if cars >= 1 {
                facts.append("🚗 総重量は小型車約\(String(format: "%.1f", cars))台分！")
            }
            
            if totalVolume >= 1000 {
                facts.append("🏗️ 1トン以上持ち上げた重量マスター！")
            }
        }
        
        if totalSets >= 100 {
            facts.append("🔥 \(totalSets)セットも頑張った努力家！")
        }
        
        if sessions.count >= 50 {
            facts.append("⭐ \(sessions.count)回のワークアウト継続は素晴らしい！")
        }
        
        if averagePerSession >= 500 {
            facts.append("💪 1回平均\(String(format: "%.0f", averagePerSession))kgのパワフルトレーニー！")
        }
        
        // デフォルトメッセージ
        if facts.isEmpty {
            facts.append("🌱 これからが楽しみ！どんどん記録を伸ばそう！")
            facts.append("💪 継続は力なり！毎日コツコツ頑張ろう！")
        }
        
        return facts
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("面白いファクト")
                .font(.headline)
                .fontWeight(.bold)
            
            ForEach(funFacts, id: \.self) { fact in
                HStack {
                    Text(fact)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PersonalRecordsCard: View {
    let sessions: [WorkoutSession]
    
    private var personalRecords: [(exercise: String, weight: Double)] {
        var records: [String: Double] = [:]
        
        for session in sessions {
            for exercise in session.exercises {
                let maxWeight = exercise.sets.map { $0.weight }.max() ?? 0
                if maxWeight > (records[exercise.name] ?? 0) {
                    records[exercise.name] = maxWeight
                }
            }
        }
        
        return records.sorted { $0.value > $1.value }.prefix(5).map { (exercise: $0.key, weight: $0.value) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("パーソナルレコード")
                .font(.headline)
                .fontWeight(.bold)
            
            if personalRecords.isEmpty {
                Text("まだ記録がありません。トレーニングを始めましょう！")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(personalRecords.enumerated()), id: \.offset) { index, record in
                    HStack {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        Text(record.exercise)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.0f", record.weight))kg")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MonthlyStatsCard: View {
    let sessions: [WorkoutSession]
    
    private var monthlyData: [(month: String, count: Int)] {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy年M月"
        monthFormatter.locale = Locale(identifier: "ja_JP")
        
        let monthlyGroups = Dictionary(grouping: sessions) { session in
            monthFormatter.string(from: session.date)
        }
        
        return monthlyGroups.map { (month: $0.key, count: $0.value.count) }
            .sorted { $0.month > $1.month }
            .prefix(6)
            .reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月別ワークアウト回数")
                .font(.headline)
                .fontWeight(.bold)
            
            if monthlyData.isEmpty {
                Text("まだ記録がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(monthlyData, id: \.month) { data in
                    HStack {
                        Text(data.month)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        // 簡易グラフ
                        HStack(spacing: 2) {
                            ForEach(0..<min(data.count, 20), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 12)
                            }
                        }
                        
                        Text("\(data.count)回")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}



struct ConsistencyCard: View {
    let sessions: [WorkoutSession]
    
    private var consistencyStats: (weeklyAverage: Double, bestStreak: Int, currentStreak: Int) {
        let totalWeeks = Calendar.current.dateComponents([.weekOfYear], from: sessions.first?.date ?? Date(), to: Date()).weekOfYear ?? 1
        let weeklyAverage = totalWeeks > 0 ? Double(sessions.count) / Double(max(totalWeeks, 1)) : 0
        
        // ワークアウトが記録された日付を取得（重複除去）
        let workoutDates = Set(sessions.map { Calendar.current.startOfDay(for: $0.date) })
        let sortedDates = Array(workoutDates).sorted()
        
        // 最長ストリーク計算
        var bestStreak = 0
        var currentBestStreak = 1
        
        if !sortedDates.isEmpty {
            for i in 1..<sortedDates.count {
                let daysBetween = Calendar.current.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
                if daysBetween == 1 {
                    currentBestStreak += 1
                } else {
                    bestStreak = max(bestStreak, currentBestStreak)
                    currentBestStreak = 1
                }
            }
            bestStreak = max(bestStreak, currentBestStreak)
        }
        
        // 現在のストリーク
        let currentStreak = calculateCurrentStreak()
        
        return (weeklyAverage: weeklyAverage, bestStreak: bestStreak, currentStreak: currentStreak)
    }
    
    private func calculateCurrentStreak() -> Int {
        // ワークアウトが記録された日付を取得（重複除去）
        let workoutDates = Set(sessions.map { Calendar.current.startOfDay(for: $0.date) })
        let sortedDates = workoutDates.sorted(by: >)
        
        guard !sortedDates.isEmpty else { return 0 }
        
        var streak = 0
        let today = Calendar.current.startOfDay(for: Date())
        
        // 今日または昨日からストリークが始まっているかチェック
        let daysSinceLastWorkout = Calendar.current.dateComponents([.day], from: sortedDates[0], to: today).day ?? 0
        
        if daysSinceLastWorkout > 1 {
            return 0 // 2日以上空いている場合はストリーク切れ
        }
        
        // 連続する日数をカウント
        var previousDate = sortedDates[0]
        streak = 1
        
        for i in 1..<sortedDates.count {
            let currentDate = sortedDates[i]
            let daysBetween = Calendar.current.dateComponents([.day], from: currentDate, to: previousDate).day ?? 0
            
            if daysBetween == 1 {
                streak += 1
                previousDate = currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("継続力ランキング")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                HStack {
                    Text("🔥 現在の連続記録")
                        .font(.subheadline)
                    Spacer()
                    Text("\(consistencyStats.currentStreak)日")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                HStack {
                    Text("🏆 最長連続記録")
                        .font(.subheadline)
                    Spacer()
                    Text("\(consistencyStats.bestStreak)日")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                
                HStack {
                    Text("📊 週平均ワークアウト")
                        .font(.subheadline)
                    Spacer()
                    Text("\(String(format: "%.1f", consistencyStats.weeklyAverage))回")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                // モチベーションメッセージ
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    
                    Text(motivationMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var motivationMessage: String {
        let currentStreak = consistencyStats.currentStreak
        
        if currentStreak >= 30 {
            return "神級の継続力！あなたは筋トレの神様です！"
        } else if currentStreak >= 14 {
            return "素晴らしい継続力！習慣化が身についていますね！"
        } else if currentStreak >= 7 {
            return "一週間継続！このペースで頑張りましょう！"
        } else if currentStreak >= 3 {
            return "良いペース！継続は力なりです！"
        } else {
            return "今日から新しいストリークを始めましょう！"
        }
    }
}

// 既存のコンポーネント
struct RecentWorkoutsSection: View {
    let workoutSessions: [WorkoutSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近のワークアウト")
                .font(.headline)
            
            if workoutSessions.isEmpty {
                Text("まだワークアウトが記録されていません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(workoutSessions, id: \.date) { session in
                        WorkoutSessionRow(session: session)
                    }
                }
            }
        }
    }
}

struct WorkoutSessionRow: View {
    let session: WorkoutSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                
                HStack {
                    ForEach(Array(session.trainedBodyParts), id: \.self) { bodyPart in
                        Text(bodyPart.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text("\(session.exercises.count)種目")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(String(format: "%.0fkg", session.totalVolume))
                    .font(.headline)
                Text("総重量")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct WorkoutSessionsForDateView: View {
    let date: Date
    let sessions: [WorkoutSession]
    
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()
    
    private var sessionsForDate: [WorkoutSession] {
        sessions.filter { session in
            let sessionNormalized = calendar.startOfDay(for: session.date)
            let dateNormalized = calendar.startOfDay(for: date)
            return calendar.isDate(sessionNormalized, inSameDayAs: dateNormalized)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(date.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .padding(.horizontal)
            
            if sessionsForDate.isEmpty {
                Text("この日はワークアウトがありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack {
                    ForEach(sessionsForDate, id: \.date) { session in
                        WorkoutSessionRow(session: session)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct OverallStatsSection: View {
    let sessions: [WorkoutSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全体統計")
                .font(.headline)
            
            HStack {
                StatCard(title: "総ワークアウト数", value: "\(sessions.count)")
                StatCard(title: "総重量", value: String(format: "%.0fkg", sessions.reduce(0) { $0 + $1.totalVolume }))
            }
        }
    }
}

struct BodyPartStatsSection: View {
    let sessions: [WorkoutSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("部位別統計")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                    let count = sessions.filter { $0.trainedBodyParts.contains(bodyPart) }.count
                    BodyPartStatRow(bodyPart: bodyPart, count: count)
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct BodyPartStatRow: View {
    let bodyPart: BodyPart
    let count: Int
    
    var body: some View {
        HStack {
            Text(bodyPart.displayName)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)回")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - カレンダー関連のビュー

struct CustomCalendarView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let workoutSessions: [WorkoutSession]
    let onDateTap: (Date) -> Void
    
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current // 明示的に現在のタイムゾーンを設定
        return cal
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        formatter.timeZone = TimeZone.current // タイムゾーンを明示的に設定
        return formatter
    }()
    
    private var monthDays: [Date] {
        // タイムゾーンを明示的に設定したカレンダーを使用
        var monthCalendar = Calendar.current
        monthCalendar.timeZone = TimeZone.current
        
        // 現在の月の開始日を取得し、startOfDayで正規化
        let startOfMonth = monthCalendar.startOfDay(for: monthCalendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth)
        
        // 月の日数を取得
        guard let range = monthCalendar.range(of: .day, in: .month, for: currentMonth) else { return [] }
        
        var days: [Date] = []
        
        // 月の各日を生成（すべてstartOfDayで正規化）
        for day in 1...range.count {
            if let date = monthCalendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let normalizedDate = monthCalendar.startOfDay(for: date)
                days.append(normalizedDate)
            }
        }
        
        return days
    }
    
    private var weeks: [[Date?]] {
        let firstDayOfMonth = monthDays.first ?? Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: firstDayOfMonth)?.start ?? firstDayOfMonth
        
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = []
        
        // 月の最初の週の空白部分を追加
        var date = startOfWeek
        while date < firstDayOfMonth {
            currentWeek.append(nil)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        
        // 月の日付を追加
        for day in monthDays {
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            currentWeek.append(day)
        }
        
        // 最後の週の空白部分を追加
        while currentWeek.count < 7 {
            currentWeek.append(nil)
        }
        weeks.append(currentWeek)
        
        return weeks
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 月ナビゲーション
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: currentMonth))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // 曜日ヘッダー
            HStack {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { dayOfWeek in
                    Text(dayOfWeek)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // カレンダーグリッド
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weeks.flatMap { $0 }, id: \.self) { date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            workoutBodyParts: getWorkoutBodyParts(for: date),
                            onTap: { 
                                // 日付を確実にstartOfDayで正規化してから渡す
                                // タイムゾーンを明示的に設定
                                var tapCalendar = Calendar.current
                                tapCalendar.timeZone = TimeZone.current
                                let normalizedDate = tapCalendar.startOfDay(for: date)
                                print("CustomCalendarView tap - Original: \(date), Normalized: \(normalizedDate)")
                                onDateTap(normalizedDate) 
                            }
                        )
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 40)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private func previousMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) else { return }
        currentMonth = newMonth
    }
    
    private func nextMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return }
        currentMonth = newMonth
    }
    
    private func getWorkoutBodyParts(for date: Date) -> Set<BodyPart> {
        let sessionsForDate = workoutSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return Set(sessionsForDate.flatMap { $0.trainedBodyParts })
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let workoutBodyParts: Set<BodyPart>
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                // ワークアウト部位インジケーター
                if !workoutBodyParts.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(workoutBodyParts).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { bodyPart in
                            Circle()
                                .fill(bodyPart.color)
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(calendar.isDateInToday(date) ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - フィルター関連ビュー

struct BodyPartFilterWithColorView: View {
    @Binding var selectedBodyPart: BodyPart?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("部位別フィルター & カラー")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // 「すべて」ボタン
                    Button(action: {
                        selectedBodyPart = nil
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 20, height: 20)
                                Image(systemName: "list.bullet")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Text("すべて")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(selectedBodyPart == nil ? Color.blue.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedBodyPart == nil ? .blue : .gray)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedBodyPart == nil ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedBodyPart == nil ? 2 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // 各部位のフィルターボタン
                    ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                        Button(action: {
                            selectedBodyPart = selectedBodyPart == bodyPart ? nil : bodyPart
                        }) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(bodyPart.color)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedBodyPart == bodyPart ? 3 : 0)
                                    )
                                
                                Text(bodyPart.displayName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(selectedBodyPart == bodyPart ? bodyPart.color.opacity(0.15) : Color.clear)
                            .foregroundColor(selectedBodyPart == bodyPart ? bodyPart.color : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedBodyPart == bodyPart ? bodyPart.color : Color.clear, lineWidth: selectedBodyPart == bodyPart ? 2 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}



// MARK: - ワークアウト詳細ポップアップ

struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let initialDate: Date
    let sessions: [WorkoutSession]
    let onAddWorkout: (Date) -> Void
    
    @State private var currentDate: Date
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var sessionToEdit: WorkoutSession?
    @State private var sessionToDelete: WorkoutSession?
    
    // WorkoutDetailSheet専用のカレンダー設定（タイムゾーン統一）
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()
    
    init(date: Date, sessions: [WorkoutSession], onAddWorkout: @escaping (Date) -> Void) {
        self.initialDate = date
        self.sessions = sessions
        self.onAddWorkout = onAddWorkout
        // 日付を確実に設定するためにタイムゾーンを明示的に設定したCalendarを使って正規化
        var calendarForInit = Calendar.current
        calendarForInit.timeZone = TimeZone.current
        let normalizedDate = calendarForInit.startOfDay(for: date)
        self._currentDate = State(initialValue: normalizedDate)
        print("WorkoutDetailSheet initialized with date: \(normalizedDate)") // デバッグ用
        print("WorkoutDetailSheet init TimeZone: \(calendarForInit.timeZone.identifier)")
    }
    
    private var sessionsForDate: [WorkoutSession] {
        // タイムゾーンを明示的に設定
        var normalizeCalendar = Calendar.current
        normalizeCalendar.timeZone = TimeZone.current
        
        let filtered = sessions.filter { session in
            let sessionNormalized = normalizeCalendar.startOfDay(for: session.date)
            let currentNormalized = normalizeCalendar.startOfDay(for: currentDate)
            let isMatch = normalizeCalendar.isDate(sessionNormalized, inSameDayAs: currentNormalized)
            
            // デバッグ情報
            if session == sessions.first {
                print("=== WorkoutDetailSheet sessionsForDate Debug ===")
                print("currentDate: \(currentDate)")
                print("currentNormalized: \(currentNormalized)")
                print("TimeZone for filtering: \(normalizeCalendar.timeZone.identifier)")
                print("Total sessions: \(sessions.count)")
                for (index, sess) in sessions.enumerated() {
                    let normalized = normalizeCalendar.startOfDay(for: sess.date)
                    let match = normalizeCalendar.isDate(normalized, inSameDayAs: currentNormalized)
                    print("Session \(index): \(sess.date) -> \(normalized) (match: \(match))")
                }
            }
            
            return isMatch
        }
        
        print("Filtered sessions count for \(currentDate): \(filtered.count)")
        return filtered
    }
    
    private func mergeSessionsForDate() {
        guard sessionsForDate.count > 1 else { return }
        
        // 最初のセッションをメインセッションとして使用
        let mainSession = sessionsForDate[0]
        let otherSessions = Array(sessionsForDate.dropFirst())
        
        // 他のセッションの種目をメインセッションに統合
        for session in otherSessions {
            for exercise in session.exercises {
                // 同じ種目が既にメインセッションにあるかチェック
                if let existingExercise = mainSession.exercises.first(where: { 
                    $0.name == exercise.name && $0.bodyPart == exercise.bodyPart 
                }) {
                    // 既存の種目にセットを追加
                    existingExercise.sets.append(contentsOf: exercise.sets)
                } else {
                    // 新しい種目として追加
                    mainSession.exercises.append(exercise)
                }
            }
            
            // 不要なセッションを削除
            modelContext.delete(session)
        }
        
        // 変更を保存
        do {
            try modelContext.save()
        } catch {
            print("Failed to merge sessions: \(error)")
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 日付ヘッダー（ナビゲーション付き）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if let newDate = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                                        currentDate = calendar.startOfDay(for: newDate)
                                        print("WorkoutDetailSheet date changed to: \(currentDate)")
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text(currentDate.formatted(date: .complete, time: .omitted))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                
                                if Calendar.current.isDateInToday(currentDate) {
                                    Text("今日")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if let newDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                                        currentDate = calendar.startOfDay(for: newDate)
                                        print("WorkoutDetailSheet date changed to: \(currentDate)")
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if !sessionsForDate.isEmpty {
                            let totalVolume = sessionsForDate.reduce(0) { $0 + $1.totalVolume }
                            let totalSets = sessionsForDate.flatMap { $0.exercises }.flatMap { $0.sets }.count
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Label("\(totalSets)セット", systemImage: "repeat")
                                    Spacer()
                                    Label(String(format: "%.1fkg", totalVolume), systemImage: "scalemass")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                
                                // 統合ボタン（複数セッションがある場合のみ表示）
                                if sessionsForDate.count > 1 {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("⚠️ 同じ日に複数のワークアウトが保存されています")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        
                                        Button("1つのワークアウトに統合") {
                                            mergeSessionsForDate()
                                        }
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    if sessionsForDate.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            
                            Text("この日はワークアウトがありません")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("新しいワークアウトを開始してトレーニングを記録しましょう。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(sessionsForDate, id: \.date) { session in
                                WorkoutSessionDetailCard(
                                    session: session,
                                    onEdit: {
                                        sessionToEdit = session
                                    },
                                    onDelete: {
                                        sessionToDelete = session
                                        showingDeleteAlert = true
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width > threshold {
                            // 右スワイプ：前の日
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if let newDate = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                                    currentDate = calendar.startOfDay(for: newDate)
                                    print("WorkoutDetailSheet swiped to: \(currentDate)")
                                }
                            }
                        } else if value.translation.width < -threshold {
                            // 左スワイプ：次の日
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if let newDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                                    currentDate = calendar.startOfDay(for: newDate)
                                    print("WorkoutDetailSheet swiped to: \(currentDate)")
                                }
                            }
                        }
                    }
            )
            .navigationTitle("ワークアウト詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("ワークアウト追加") {
                        onAddWorkout(currentDate)
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
            }
            .sheet(item: $sessionToEdit) { session in
                EditWorkoutSheet(session: session)
            }
            .alert("ワークアウトを削除", isPresented: $showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    if let session = sessionToDelete {
                        deleteWorkout(session)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("このワークアウトを削除してもよろしいですか？この操作は取り消せません。")
            }
        }
    }
    
    private func deleteWorkout(_ session: WorkoutSession) {
        modelContext.delete(session)
        sessionToDelete = nil
    }
}

struct WorkoutSessionDetailCard: View {
    let session: WorkoutSession
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セッション時間とボリューム + 編集・削除ボタン
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.date.formatted(date: .omitted, time: .shortened))
                            .font(.headline)
                        
                        if !session.trainedBodyParts.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(Array(session.trainedBodyParts), id: \.self) { bodyPart in
                                    HStack(spacing: 2) {
                                        Circle()
                                            .fill(bodyPart.color)
                                            .frame(width: 8, height: 8)
                                        Text(bodyPart.displayName)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(String(format: "%.0fkg", session.totalVolume))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("総重量")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 編集・削除ボタン
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            Text("編集")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    
                    Button(action: onDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("削除")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
            }
            
            // エクササイズ一覧
            if !session.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("エクササイズ")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(session.exercises, id: \.name) { exercise in
                        HStack {
                            Circle()
                                .fill(exercise.bodyPart.color)
                                .frame(width: 6, height: 6)
                            
                            Text(exercise.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(exercise.sets.count)セット")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self, ExerciseSet.self], inMemory: true)
}
