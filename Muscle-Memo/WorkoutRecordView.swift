//
//  WorkoutRecordView.swift
//  Muscle-Memo
//
//  Created by rsato on 2025/07/16.
//

import SwiftUI
import SwiftData

struct NewWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    
    let initialDate: Date?
    @State private var currentWorkout = WorkoutSession()
    @State private var selectedBodyPart: BodyPart = .chest
    @State private var currentExercise: Exercise?
    @State private var showingExerciseSheet = false
    @State private var showingAddSetSheet = false
    @State private var exerciseForSetInput: Exercise?
    
    init(initialDate: Date? = nil) {
        self.initialDate = initialDate
        _currentWorkout = State(initialValue: WorkoutSession(date: initialDate ?? Date()))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 部位選択（固定）
                BodyPartPicker(selectedBodyPart: $selectedBodyPart)
                
                // スクロール可能なコンテンツ
                ScrollView {
                    VStack(spacing: 0) {
                        // 前回の記録表示
                        PreviousWorkoutDisplay(bodyPart: selectedBodyPart, sessions: allWorkoutSessions)
                        
                        // 現在のワークアウト
                        CurrentWorkoutView(
                            workout: currentWorkout,
                            selectedBodyPart: selectedBodyPart,
                            onAddExercise: {
                                showingExerciseSheet = true
                            },
                            onAddSet: { exercise in
                                exerciseForSetInput = exercise
                            },
                            onDeleteExercise: { exercise in
                                currentWorkout.removeExercise(exercise)
                            },
                            onMoveExercise: { indices, newOffset in
                                moveExercise(from: indices, to: newOffset)
                            }
                        )
                        
                        // 保存ボタンの余白確保
                        Spacer(minLength: 100)
                    }
                }
                
                // 保存ボタン（固定）
                SaveWorkoutButton(workout: currentWorkout) {
                    saveWorkout()
                }
            }
            .navigationTitle("ワークアウト記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExerciseSheet) {
                ExerciseSelectionSheet(
                    bodyPart: selectedBodyPart,
                    onSelect: { exerciseName in
                        addExercise(name: exerciseName)
                    }
                )
            }
            .sheet(item: $exerciseForSetInput) { exercise in
                AddSetSheet(exercise: exercise)
            }
        }
    }
    
    private func addExercise(name: String) {
        let exercise = Exercise(name: name, bodyPart: selectedBodyPart)
        
        // SwiftDataのcontextに明示的に挿入
        modelContext.insert(exercise)
        
        currentWorkout.addExercise(exercise)
        showingExerciseSheet = false
        
        // 種目追加後、直接セット入力画面を表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exerciseForSetInput = exercise
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        let bodyPartExercises = currentWorkout.exercises.filter { $0.bodyPart == selectedBodyPart }
        var allExercises = currentWorkout.exercises
        
        // 選択中の部位の種目のみを移動
        var filteredExercises = bodyPartExercises
        filteredExercises.move(fromOffsets: source, toOffset: destination)
        
        // 他の部位の種目を除外して、移動後の順序で全体を再構築
        let otherExercises = allExercises.filter { $0.bodyPart != selectedBodyPart }
        
        // 選択中の部位の種目を挿入位置を考慮して全体リストに統合
        var newExercises: [Exercise] = []
        var bodyPartInserted = false
        
        for exercise in allExercises {
            if exercise.bodyPart == selectedBodyPart && !bodyPartInserted {
                newExercises.append(contentsOf: filteredExercises)
                bodyPartInserted = true
            } else if exercise.bodyPart != selectedBodyPart {
                newExercises.append(exercise)
            }
        }
        
        if !bodyPartInserted {
            newExercises.append(contentsOf: filteredExercises)
        }
        
        currentWorkout.exercises = newExercises
    }
    
    private func saveWorkout() {
        // セットが空の種目を除外
        currentWorkout.exercises = currentWorkout.exercises.filter { !$0.sets.isEmpty }
        
        guard !currentWorkout.exercises.isEmpty else { return }
        
        // 同じ日付の既存セッションがあるかチェック
        mergeOrCreateWorkout()
        dismiss()
    }
    
    private func mergeOrCreateWorkout() {
        let calendar = Calendar.current
        let existingSession = allWorkoutSessions.first { session in
            calendar.isDate(session.date, inSameDayAs: currentWorkout.date)
        }
        
        if let existingSession = existingSession {
            // 既存セッションに種目を統合
            for exercise in currentWorkout.exercises {
                if let existingExercise = existingSession.exercises.first(where: { 
                    $0.name == exercise.name && $0.bodyPart == exercise.bodyPart 
                }) {
                    // 既存の種目にセットを追加
                    existingExercise.sets.append(contentsOf: exercise.sets)
                } else {
                    // 新しい種目として追加
                    existingSession.exercises.append(exercise)
                }
            }
        } else {
            // 新しいセッションとして保存
            modelContext.insert(currentWorkout)
        }
    }
}

struct NewWorkoutSheetWithBodyPart: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    
    let initialBodyPart: BodyPart
    let initialDate: Date?
    @State private var currentWorkout = WorkoutSession()
    @State private var selectedBodyPart: BodyPart
    @State private var currentExercise: Exercise?
    @State private var showingExerciseSheet = false
    @State private var showingAddSetSheet = false
    @State private var exerciseForSetInput: Exercise?
    
    init(initialBodyPart: BodyPart, initialDate: Date? = nil) {
        self.initialBodyPart = initialBodyPart
        self.initialDate = initialDate
        _selectedBodyPart = State(initialValue: initialBodyPart)
        _currentWorkout = State(initialValue: WorkoutSession(date: initialDate ?? Date()))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 部位選択（固定）
                BodyPartPicker(selectedBodyPart: $selectedBodyPart)
                
                // スクロール可能なコンテンツ
                ScrollView {
                    VStack(spacing: 0) {
                        // 前回の記録表示
                        PreviousWorkoutDisplay(bodyPart: selectedBodyPart, sessions: allWorkoutSessions)
                        
                        // 現在のワークアウト
                        CurrentWorkoutView(
                            workout: currentWorkout,
                            selectedBodyPart: selectedBodyPart,
                            onAddExercise: {
                                showingExerciseSheet = true
                            },
                            onAddSet: { exercise in
                                exerciseForSetInput = exercise
                            },
                            onDeleteExercise: { exercise in
                                currentWorkout.removeExercise(exercise)
                            },
                            onMoveExercise: { indices, newOffset in
                                moveExercise(from: indices, to: newOffset)
                            }
                        )
                        
                        // 保存ボタンの余白確保
                        Spacer(minLength: 100)
                    }
                }
                
                // 保存ボタン（固定）
                SaveWorkoutButton(workout: currentWorkout) {
                    saveWorkout()
                }
            }
            .navigationTitle("ワークアウト記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExerciseSheet) {
                ExerciseSelectionSheet(
                    bodyPart: selectedBodyPart,
                    onSelect: { exerciseName in
                        addExercise(name: exerciseName)
                    }
                )
            }
            .sheet(item: $exerciseForSetInput) { exercise in
                AddSetSheet(exercise: exercise)
            }
        }
    }
    
    private func addExercise(name: String) {
        let exercise = Exercise(name: name, bodyPart: selectedBodyPart)
        
        // SwiftDataのcontextに明示的に挿入
        modelContext.insert(exercise)
        
        currentWorkout.addExercise(exercise)
        showingExerciseSheet = false
        
        // 種目追加後、直接セット入力画面を表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exerciseForSetInput = exercise
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        let bodyPartExercises = currentWorkout.exercises.filter { $0.bodyPart == selectedBodyPart }
        var allExercises = currentWorkout.exercises
        
        // 選択中の部位の種目のみを移動
        var filteredExercises = bodyPartExercises
        filteredExercises.move(fromOffsets: source, toOffset: destination)
        
        // 他の部位の種目を除外して、移動後の順序で全体を再構築
        let otherExercises = allExercises.filter { $0.bodyPart != selectedBodyPart }
        
        // 選択中の部位の種目を挿入位置を考慮して全体リストに統合
        var newExercises: [Exercise] = []
        var bodyPartInserted = false
        
        for exercise in allExercises {
            if exercise.bodyPart == selectedBodyPart && !bodyPartInserted {
                newExercises.append(contentsOf: filteredExercises)
                bodyPartInserted = true
            } else if exercise.bodyPart != selectedBodyPart {
                newExercises.append(exercise)
            }
        }
        
        if !bodyPartInserted {
            newExercises.append(contentsOf: filteredExercises)
        }
        
        currentWorkout.exercises = newExercises
    }
    
    private func saveWorkout() {
        // セットが空の種目を除外
        currentWorkout.exercises = currentWorkout.exercises.filter { !$0.sets.isEmpty }
        
        guard !currentWorkout.exercises.isEmpty else { return }
        
        // 同じ日付の既存セッションがあるかチェック
        mergeOrCreateWorkout()
        dismiss()
    }
    
    private func mergeOrCreateWorkout() {
        let calendar = Calendar.current
        let existingSession = allWorkoutSessions.first { session in
            calendar.isDate(session.date, inSameDayAs: currentWorkout.date)
        }
        
        if let existingSession = existingSession {
            // 既存セッションに種目を統合
            for exercise in currentWorkout.exercises {
                if let existingExercise = existingSession.exercises.first(where: { 
                    $0.name == exercise.name && $0.bodyPart == exercise.bodyPart 
                }) {
                    // 既存の種目にセットを追加
                    existingExercise.sets.append(contentsOf: exercise.sets)
                } else {
                    // 新しい種目として追加
                    existingSession.exercises.append(exercise)
                }
            }
        } else {
            // 新しいセッションとして保存
            modelContext.insert(currentWorkout)
        }
    }
}

struct NewWorkoutSheetWithSuggestion: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    
    let suggestedBodyPart: BodyPart
    @State private var currentWorkout = WorkoutSession()
    @State private var selectedBodyPart: BodyPart
    @State private var currentExercise: Exercise?
    @State private var showingExerciseSheet = false
    @State private var showingAddSetSheet = false
    @State private var exerciseForSetInput: Exercise?
    
    init(suggestedBodyPart: BodyPart) {
        self.suggestedBodyPart = suggestedBodyPart
        _selectedBodyPart = State(initialValue: suggestedBodyPart)
        _currentWorkout = State(initialValue: WorkoutSession())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 提案ヘッダー
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("提案されたワークアウト")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    HStack {
                        Text("\(suggestedBodyPart.displayName)のトレーニングを開始します")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                
                // 部位選択（固定）
                BodyPartPicker(selectedBodyPart: $selectedBodyPart)
                
                // スクロール可能なコンテンツ
                ScrollView {
                    VStack(spacing: 0) {
                                                 // 前回の記録表示
                         PreviousWorkoutDisplay(bodyPart: selectedBodyPart, sessions: allWorkoutSessions)
                         
                         // 現在のワークアウト
                         CurrentWorkoutView(
                             workout: currentWorkout,
                             selectedBodyPart: selectedBodyPart,
                             onAddExercise: {
                                 showingExerciseSheet = true
                             },
                             onAddSet: { exercise in
                                 exerciseForSetInput = exercise
                             },
                             onDeleteExercise: { exercise in
                                 currentWorkout.removeExercise(exercise)
                             },
                             onMoveExercise: { indices, newOffset in
                                 moveExercise(from: indices, to: newOffset)
                             }
                         )
                        
                        // 保存ボタンの余白確保
                        Spacer(minLength: 100)
                    }
                }
                
                // 保存ボタン（固定）
                SaveWorkoutButton(workout: currentWorkout) {
                    saveWorkout()
                }
            }
            .navigationTitle("ワークアウト記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExerciseSheet) {
                ExerciseSelectionSheet(
                    bodyPart: selectedBodyPart,
                    onSelect: { exerciseName in
                        addExercise(name: exerciseName)
                    }
                )
            }
            .sheet(item: $exerciseForSetInput) { exercise in
                AddSetSheet(exercise: exercise)
            }
        }
    }
    
    private func addExercise(name: String) {
        let exercise = Exercise(name: name, bodyPart: selectedBodyPart)
        
        // SwiftDataのcontextに明示的に挿入
        modelContext.insert(exercise)
        
        currentWorkout.addExercise(exercise)
        showingExerciseSheet = false
        
        // 種目追加後、直接セット入力画面を表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exerciseForSetInput = exercise
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        let bodyPartExercises = currentWorkout.exercises.filter { $0.bodyPart == selectedBodyPart }
        var allExercises = currentWorkout.exercises
        
        // 選択中の部位の種目のみを移動
        var filteredExercises = bodyPartExercises
        filteredExercises.move(fromOffsets: source, toOffset: destination)
        
        // 他の部位の種目を除外して、移動後の順序で全体を再構築
        let otherExercises = allExercises.filter { $0.bodyPart != selectedBodyPart }
        
        // 選択中の部位の種目を挿入位置を考慮して全体リストに統合
        var newExercises: [Exercise] = []
        var bodyPartInserted = false
        
        for exercise in allExercises {
            if exercise.bodyPart == selectedBodyPart && !bodyPartInserted {
                newExercises.append(contentsOf: filteredExercises)
                bodyPartInserted = true
            } else if exercise.bodyPart != selectedBodyPart {
                newExercises.append(exercise)
            }
        }
        
        if !bodyPartInserted {
            newExercises.append(contentsOf: filteredExercises)
        }
        
        currentWorkout.exercises = newExercises
    }
    
    private func saveWorkout() {
        // セットが空の種目を除外
        currentWorkout.exercises = currentWorkout.exercises.filter { !$0.sets.isEmpty }
        
        guard !currentWorkout.exercises.isEmpty else { return }
        
        // 同じ日付の既存セッションがあるかチェック
        mergeOrCreateWorkout()
        dismiss()
    }
    
    private func mergeOrCreateWorkout() {
        let calendar = Calendar.current
        let existingSession = allWorkoutSessions.first { session in
            calendar.isDate(session.date, inSameDayAs: currentWorkout.date)
        }
        
        if let existingSession = existingSession {
            // 既存セッションに種目を統合
            for exercise in currentWorkout.exercises {
                if let existingExercise = existingSession.exercises.first(where: { 
                    $0.name == exercise.name && $0.bodyPart == exercise.bodyPart 
                }) {
                    // 既存の種目にセットを追加
                    existingExercise.sets.append(contentsOf: exercise.sets)
                } else {
                    // 新しい種目として追加
                    existingSession.exercises.append(exercise)
                }
            }
        } else {
            // 新しいセッションとして保存
            modelContext.insert(currentWorkout)
        }
    }
}

struct QuickWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let suggestedBodyPart: BodyPart
    let allSessions: [WorkoutSession]
    @State private var currentWorkout = WorkoutSession()
    @State private var selectedBodyPart: BodyPart
    @State private var showingExerciseSheet = false
    @State private var exerciseForSetInput: Exercise?
    @State private var isLoaded = false
    
    init(suggestedBodyPart: BodyPart, allSessions: [WorkoutSession]) {
        self.suggestedBodyPart = suggestedBodyPart
        self.allSessions = allSessions
        _selectedBodyPart = State(initialValue: suggestedBodyPart)
        _currentWorkout = State(initialValue: WorkoutSession())
    }
    
    private var previousWorkout: WorkoutSession? {
        let calendar = Calendar.current
        let today = Date()
        
        return allSessions.first { session in
            // 当日以前のセッションで、指定の部位を含むもの
            !calendar.isDate(session.date, inSameDayAs: today) &&
            session.date < today &&
            session.trainedBodyParts.contains(suggestedBodyPart)
        }
    }
    
    private var hasCompletedSets: Bool {
        !currentWorkout.exercises.isEmpty && 
        currentWorkout.exercises.allSatisfy { exercise in
            !exercise.sets.isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 提案ヘッダー
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.orange)
                        Text("前回の種目を再利用")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    HStack {
                        if let previousWorkout = previousWorkout {
                            Text("\(suggestedBodyPart.displayName)の前回の種目でトレーニングを開始します")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(suggestedBodyPart.displayName)の新しいトレーニングを開始します")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                
                // 部位選択（固定）
                BodyPartPicker(selectedBodyPart: $selectedBodyPart)
                
                // スクロール可能なコンテンツ
                ScrollView {
                    VStack(spacing: 0) {
                        // 前回の記録表示
                        PreviousWorkoutDisplay(bodyPart: selectedBodyPart, sessions: allSessions)
                        
                        // 現在のワークアウト
                        CurrentWorkoutView(
                            workout: currentWorkout,
                            selectedBodyPart: selectedBodyPart,
                            onAddExercise: {
                                showingExerciseSheet = true
                            },
                            onAddSet: { exercise in
                                exerciseForSetInput = exercise
                            },
                            onDeleteExercise: { exercise in
                                currentWorkout.removeExercise(exercise)
                            },
                            onMoveExercise: { indices, newOffset in
                                moveExercise(from: indices, to: newOffset)
                            }
                        )
                        
                        // 保存ボタンの余白確保
                        Spacer(minLength: 100)
                    }
                }
                
                // 保存ボタン（固定）
                VStack(spacing: 8) {
                    if hasCompletedSets {
                        Button("ワークアウトを保存") {
                            saveWorkout()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("種目にセットを追加してワークアウトを完了させてください")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("クイックワークアウト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExerciseSheet) {
                ExerciseSelectionSheet(
                    bodyPart: selectedBodyPart,
                    onSelect: { exerciseName in
                        addExercise(name: exerciseName)
                    }
                )
            }
            .sheet(item: $exerciseForSetInput) { exercise in
                AddSetSheet(exercise: exercise)
            }
            .onAppear {
                if !isLoaded {
                    loadPreviousWorkout()
                    isLoaded = true
                }
            }
        }
    }
    
    private func loadPreviousWorkout() {
        guard let previousWorkout = previousWorkout else { return }
        
        let bodyPartExercises = previousWorkout.exercises.filter { $0.bodyPart == suggestedBodyPart }
        
        for previousExercise in bodyPartExercises {
            let newExercise = Exercise(name: previousExercise.name, bodyPart: previousExercise.bodyPart)
            
            // 種目のみ追加（セット情報は空のまま）
            modelContext.insert(newExercise)
            currentWorkout.addExercise(newExercise)
        }
        
        // 最初の種目のセット入力画面を自動で開く
        if let firstExercise = currentWorkout.exercises.first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exerciseForSetInput = firstExercise
            }
        }
    }
    
    private func addExercise(name: String) {
        let exercise = Exercise(name: name, bodyPart: selectedBodyPart)
        modelContext.insert(exercise)
        currentWorkout.addExercise(exercise)
        showingExerciseSheet = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exerciseForSetInput = exercise
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        let bodyPartExercises = currentWorkout.exercises.filter { $0.bodyPart == selectedBodyPart }
        var allExercises = currentWorkout.exercises
        
        // 選択中の部位の種目のみを移動
        var filteredExercises = bodyPartExercises
        filteredExercises.move(fromOffsets: source, toOffset: destination)
        
        // 他の部位の種目を除外して、移動後の順序で全体を再構築
        let otherExercises = allExercises.filter { $0.bodyPart != selectedBodyPart }
        
        // 選択中の部位の種目を挿入位置を考慮して全体リストに統合
        var newExercises: [Exercise] = []
        var bodyPartInserted = false
        
        for exercise in allExercises {
            if exercise.bodyPart == selectedBodyPart && !bodyPartInserted {
                newExercises.append(contentsOf: filteredExercises)
                bodyPartInserted = true
            } else if exercise.bodyPart != selectedBodyPart {
                newExercises.append(exercise)
            }
        }
        
        if !bodyPartInserted {
            newExercises.append(contentsOf: filteredExercises)
        }
        
        currentWorkout.exercises = newExercises
    }
    
    private func saveWorkout() {
        guard hasCompletedSets else { return }
        
        // セットが空の種目を除外
        currentWorkout.exercises = currentWorkout.exercises.filter { !$0.sets.isEmpty }
        
        // 同じ日付の既存セッションがあるかチェック
        mergeOrCreateWorkout()
        dismiss()
    }
    
    private func mergeOrCreateWorkout() {
        let calendar = Calendar.current
        let existingSession = allSessions.first { session in
            calendar.isDate(session.date, inSameDayAs: currentWorkout.date)
        }
        
        if let existingSession = existingSession {
            // 既存セッションに種目を統合
            for exercise in currentWorkout.exercises {
                if let existingExercise = existingSession.exercises.first(where: { 
                    $0.name == exercise.name && $0.bodyPart == exercise.bodyPart 
                }) {
                    // 既存の種目にセットを追加
                    existingExercise.sets.append(contentsOf: exercise.sets)
                } else {
                    // 新しい種目として追加
                    existingSession.exercises.append(exercise)
                }
            }
        } else {
            // 新しいセッションとして保存
            modelContext.insert(currentWorkout)
        }
    }
}

struct BodyPartPicker: View {
    @Binding var selectedBodyPart: BodyPart
    @State private var showOptionalParts = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 必須部位
            VStack(alignment: .leading, spacing: 8) {
                Text("メイン部位")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BodyPart.requiredParts, id: \.self) { bodyPart in
                            BodyPartButton(bodyPart: bodyPart, selectedBodyPart: $selectedBodyPart)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // オプション部位の展開ボタン
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showOptionalParts.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("オプション部位")
                            .font(.headline)
                        Image(systemName: showOptionalParts ? "chevron.up" : "chevron.down")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
                .padding(.horizontal)
                
                Spacer()
            }
            
            // オプション部位（条件付き表示）
            if showOptionalParts {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BodyPart.optionalParts, id: \.self) { bodyPart in
                            BodyPartButton(bodyPart: bodyPart, selectedBodyPart: $selectedBodyPart)
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6).opacity(0.5))
    }
}

struct BodyPartButton: View {
    let bodyPart: BodyPart
    @Binding var selectedBodyPart: BodyPart
    
    var body: some View {
        Button(action: {
            selectedBodyPart = bodyPart
        }) {
            Text(bodyPart.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedBodyPart == bodyPart ? bodyPart.color : Color(.systemGray5))
                .foregroundColor(selectedBodyPart == bodyPart ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct PreviousWorkoutDisplay: View {
    let bodyPart: BodyPart
    let sessions: [WorkoutSession]
    
    private var previousWorkout: WorkoutSession? {
        let calendar = Calendar.current
        let today = Date()
        
        return sessions.first { session in
            // 当日以前のセッションで、指定の部位を含むもの
            !calendar.isDate(session.date, inSameDayAs: today) &&
            session.date < today &&
            session.trainedBodyParts.contains(bodyPart)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                    .font(.subheadline)
                Text("前回の\(bodyPart.displayName)トレーニング")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
            
            if let workout = previousWorkout {
                let bodyPartExercises = workout.exercises.filter { $0.bodyPart == bodyPart }
                
                LazyVStack(spacing: 4) {
                    ForEach(bodyPartExercises, id: \.name) { exercise in
                        PreviousExerciseRow(exercise: exercise)
                    }
                }
                .padding(.horizontal)
            } else {
                Text("まだ\(bodyPart.displayName)のトレーニング記録がありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.3))
    }
}

struct PreviousWorkoutDisplayForEdit: View {
    let bodyPart: BodyPart
    let sessions: [WorkoutSession]
    let editingSessionDate: Date
    
    private var previousWorkout: WorkoutSession? {
        let calendar = Calendar.current
        
        return sessions.first { session in
            // 編集中のセッションより前のセッションで、指定の部位を含むもの
            !calendar.isDate(session.date, inSameDayAs: editingSessionDate) &&
            session.date < editingSessionDate &&
            session.trainedBodyParts.contains(bodyPart)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                    .font(.subheadline)
                Text("前回の\(bodyPart.displayName)トレーニング")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
            
            if let workout = previousWorkout {
                let bodyPartExercises = workout.exercises.filter { $0.bodyPart == bodyPart }
                
                LazyVStack(spacing: 4) {
                    ForEach(bodyPartExercises, id: \.name) { exercise in
                        PreviousExerciseRow(exercise: exercise)
                    }
                }
                .padding(.horizontal)
            } else {
                Text("まだ\(bodyPart.displayName)のトレーニング記録がありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.3))
    }
}

struct PreviousExerciseRow: View {
    let exercise: Exercise
    
    var body: some View {
        HStack(spacing: 8) {
            Text(exercise.name)
                .font(.caption)
                .fontWeight(.medium)
                .frame(minWidth: 80, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                        Text("\(String(format: "%.1f", set.weight))×\(set.reps)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
    }
}

struct CurrentWorkoutView: View {
    let workout: WorkoutSession
    let selectedBodyPart: BodyPart
    let onAddExercise: () -> Void
    let onAddSet: (Exercise) -> Void
    let onDeleteExercise: (Exercise) -> Void
    let onMoveExercise: (IndexSet, Int) -> Void
    
    @State private var editMode: EditMode = .inactive
    
    private var bodyPartExercises: [Exercise] {
        workout.exercises.filter { $0.bodyPart == selectedBodyPart }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今回の\(selectedBodyPart.displayName)トレーニング")
                    .font(.headline)
                
                Spacer()
                
                if !bodyPartExercises.isEmpty {
                    Button(editMode == .active ? "完了" : "編集") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                
                Button("種目追加", action: onAddExercise)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            if bodyPartExercises.isEmpty {
                Text("種目を追加してトレーニングを開始しましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(bodyPartExercises, id: \.name) { exercise in
                        CurrentExerciseRow(
                            exercise: exercise,
                            onAddSet: {
                                onAddSet(exercise)
                            },
                            onDeleteExercise: {
                                onDeleteExercise(exercise)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onMove(perform: editMode == .active ? { indices, newOffset in
                        onMoveExercise(indices, newOffset)
                    } : nil)
                    .onDelete(perform: editMode == .active ? { indexSet in
                        for index in indexSet {
                            onDeleteExercise(bodyPartExercises[index])
                        }
                    } : nil)
                }
                .listStyle(PlainListStyle())
                .environment(\.editMode, $editMode)
                .frame(minHeight: CGFloat(bodyPartExercises.count * 120))
            }
        }
        .padding(.vertical)
    }
}

struct CurrentExerciseRow: View {
    let exercise: Exercise
    let onAddSet: () -> Void
    let onDeleteExercise: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onAddSet) {
                    Text(exercise.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button("セット追加", action: onAddSet)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if exercise.sets.isEmpty {
                Text("セットを追加してください")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                        Text("Set\(index + 1): \(String(format: "%.1f", set.weight))kg×\(set.reps)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("削除", role: .destructive) {
                onDeleteExercise()
            }
        }
    }
}

struct ExerciseSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExercise]
    
    let bodyPart: BodyPart
    let onSelect: (String) -> Void
    
    @State private var customExerciseName = ""
    @State private var showingCustomInput = false
    @State private var showingAllExercises = false
    
    private var topExercises: [String] {
        bodyPart.getTopExercises(customExercises: customExercises)
    }
    
    private var allExercises: [String] {
        bodyPart.getSortedExercises(customExercises: customExercises)
    }
    
    private var exercisesToShow: [String] {
        showingAllExercises ? allExercises : topExercises
    }
    
    private func selectExercise(_ exerciseName: String) {
        // 種目使用回数を記録
        recordExerciseUsage(exerciseName)
        onSelect(exerciseName)
        dismiss()
    }
    
    private func recordExerciseUsage(_ exerciseName: String) {
        // 既存の記録を探す
        if let existingExercise = customExercises.first(where: { $0.name == exerciseName && $0.bodyPart == bodyPart }) {
            existingExercise.recordUsage()
        } else {
            // 新しい記録を作成
            let newExercise = CustomExercise(name: exerciseName, bodyPart: bodyPart, isCustom: false)
            newExercise.recordUsage()
            modelContext.insert(newExercise)
        }
        
        // 保存
        try? modelContext.save()
    }
    
    private func getUsageInfo(for exerciseName: String) -> (count: Int, isCustom: Bool) {
        if let exercise = customExercises.first(where: { $0.name == exerciseName && $0.bodyPart == bodyPart }) {
            return (exercise.usageCount, exercise.isCustom)
        }
        return (0, false)
    }
    
    private func addCustomExercise(_ exerciseName: String) {
        // 重複チェック
        let existingExercise = customExercises.first { $0.name == exerciseName && $0.bodyPart == bodyPart }
        
        if existingExercise == nil {
            // 新しいカスタム種目を作成
            let newCustomExercise = CustomExercise(name: exerciseName, bodyPart: bodyPart, isCustom: true)
            newCustomExercise.recordUsage() // 作成時に1回使用として記録
            modelContext.insert(newCustomExercise)
            try? modelContext.save()
        }
        
        // 種目を選択して画面を閉じる
        selectExercise(exerciseName)
        
        // 入力状態をリセット
        showingCustomInput = false
        customExerciseName = ""
    }
    
    private func deleteCustomExercise(_ exercise: CustomExercise) {
        modelContext.delete(exercise)
        try? modelContext.save()
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: HStack {
                    Text(showingAllExercises ? "全種目（使用頻度順）" : "よく使う種目 TOP5")
                    Spacer()
                    if !showingAllExercises && !topExercises.isEmpty {
                        Text("🔥 人気")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }) {
                    ForEach(exercisesToShow, id: \.self) { exercise in
                        let usageInfo = getUsageInfo(for: exercise)
                        
                        Button(action: {
                            selectExercise(exercise)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise)
                                        .foregroundColor(.primary)
                                        .font(.subheadline)
                                    
                                    if usageInfo.count > 0 {
                                        HStack(spacing: 8) {
                                            Text("使用回数: \(usageInfo.count)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            if usageInfo.isCustom {
                                                Text("🔧 カスタム")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if usageInfo.count > 0 {
                                    HStack(spacing: 2) {
                                        ForEach(0..<min(usageInfo.count, 5), id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                        
                                        if usageInfo.count > 5 {
                                            Text("+\(usageInfo.count - 5)")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // もっと見る/閉じるボタン
                    if allExercises.count > topExercises.count {
                        Button(action: {
                            withAnimation {
                                showingAllExercises.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: showingAllExercises ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                Text(showingAllExercises ? "上位5種目のみ表示" : "全種目を表示 (\(allExercises.count)種目)")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // 既存のカスタム種目を表示
                let existingCustomExercises = customExercises.filter { $0.bodyPart == bodyPart && $0.isCustom }
                if !existingCustomExercises.isEmpty {
                    Section(header: Text("登録済みカスタム種目")) {
                        ForEach(existingCustomExercises, id: \.name) { exercise in
                            HStack {
                                Button(action: {
                                    selectExercise(exercise.name)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(exercise.name)
                                                .foregroundColor(.primary)
                                                .font(.subheadline)
                                            
                                            HStack(spacing: 8) {
                                                Text("使用回数: \(exercise.usageCount)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                Text("🔧 カスタム")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 2) {
                                            ForEach(0..<min(exercise.usageCount, 5), id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            }
                                            
                                            if exercise.usageCount > 5 {
                                                Text("+\(exercise.usageCount - 5)")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    deleteCustomExercise(exercise)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                Section(header: Text("カスタム種目を追加")) {
                    if showingCustomInput {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("新しい種目名を入力")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("種目名を入力", text: $customExerciseName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button("追加") {
                                    if !customExerciseName.isEmpty {
                                        addCustomExercise(customExerciseName)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(customExerciseName.isEmpty)
                            }
                            
                            Button("キャンセル") {
                                showingCustomInput = false
                                customExerciseName = ""
                            }
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color(.systemGray6))
                    } else {
                        Button("+ カスタム種目を追加") {
                            showingCustomInput = true
                        }
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("\(bodyPart.displayName)の種目選択")
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

struct AddSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    let exercise: Exercise
    
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var memo: String = ""
    @FocusState private var isInputFocused: Bool
    
    // 前回の同じ種目を取得
    private var previousSameExercise: Exercise? {
        let calendar = Calendar.current
        let today = Date()
        
        for session in allWorkoutSessions {
            // 当日以前のセッションのみ対象
            if !calendar.isDate(session.date, inSameDayAs: today) && session.date < today {
                if let foundExercise = session.exercises.first(where: { $0.name == exercise.name && $0.bodyPart == exercise.bodyPart }) {
                    return foundExercise
                }
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("セット入力")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !exercise.sets.isEmpty {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                } else {
                    Text("完了")
                        .foregroundColor(.clear)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            ScrollView {
                VStack(spacing: 20) {
                    // 種目名ヘッダー
                    VStack(spacing: 8) {
                        Text(exercise.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if !exercise.sets.isEmpty {
                            Text("\(exercise.sets.count)セット完了")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top)
                    
                    // 前回の同じ種目セット表示
                    if let previousExercise = previousSameExercise, !previousExercise.sets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.orange)
                                    .font(.subheadline)
                                Text("前回の\(exercise.name)")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(previousExercise.sets.enumerated()), id: \.offset) { index, set in
                                        VStack(spacing: 6) {
                                            Text("Set \(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                            
                                            VStack(spacing: 2) {
                                                Text("\(String(format: "%.1f", set.weight))kg")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                Text("\(set.reps)回")
                                                    .font(.subheadline)
                                                
                                                if !set.memo.isEmpty {
                                                    Text(set.memo)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(2)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(12)
                                        .onTapGesture {
                                            // 前回値を入力欄に設定
                                            weight = set.weight.truncatingRemainder(dividingBy: 1) == 0 ? 
                                                String(format: "%.0f", set.weight) : 
                                                String(format: "%.1f", set.weight)
                                            reps = String(set.reps)
                                            memo = set.memo
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            Text("セットをタップすると同じ値を入力できます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // 既存セット表示
                    if !exercise.sets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("今回の完了済みセット")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                                        VStack(spacing: 6) {
                                            Text("Set \(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                            
                                            VStack(spacing: 2) {
                                                Text("\(String(format: "%.1f", set.weight))kg")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                Text("\(set.reps)回")
                                                    .font(.subheadline)
                                                
                                                if !set.memo.isEmpty {
                                                    Text(set.memo)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(2)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(12)
                                        .onTapGesture {
                                            // 前回値を入力欄に設定
                                            weight = set.weight.truncatingRemainder(dividingBy: 1) == 0 ? 
                                                String(format: "%.0f", set.weight) : 
                                                String(format: "%.1f", set.weight)
                                            reps = String(set.reps)
                                            memo = set.memo
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            Text("セットをタップすると同じ値を入力できます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // 新しいセット入力
                    VStack(alignment: .leading, spacing: 16) {
                        Text("新しいセット")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // 重量入力
                            VStack(alignment: .leading, spacing: 4) {
                                Text("重量 (kg)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("例: 50.0", text: $weight)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($isInputFocused)
                            }
                            
                            // 回数入力
                            VStack(alignment: .leading, spacing: 4) {
                                Text("回数")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("例: 10", text: $reps)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            // メモ入力
                            VStack(alignment: .leading, spacing: 4) {
                                Text("メモ（任意）")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("フォームの感想、体調など", text: $memo)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // ボタン
                    VStack(spacing: 12) {
                        // 前回の同じ種目の次のセットを自動入力するボタン
                        if let previousExercise = previousSameExercise {
                            let nextSetIndex = exercise.sets.count
                            if nextSetIndex < previousExercise.sets.count {
                                let nextSet = previousExercise.sets[nextSetIndex]
                                Button(action: {
                                    weight = nextSet.weight.truncatingRemainder(dividingBy: 1) == 0 ? 
                                        String(format: "%.0f", nextSet.weight) : 
                                        String(format: "%.1f", nextSet.weight)
                                    reps = String(nextSet.reps)
                                    memo = nextSet.memo
                                }) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                        Text("前回Set\(nextSetIndex + 1)の値を使用 (\(String(format: "%.1f", nextSet.weight))kg×\(nextSet.reps))")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        Button(action: addSet) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("セットを追加")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(weight.isEmpty || reps.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(weight.isEmpty || reps.isEmpty)
                        
                        if !exercise.sets.isEmpty {
                            Button(action: {
                                addSet()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("セットを追加して完了")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .disabled(weight.isEmpty || reps.isEmpty)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
            
            // キーボードツールバー
            if isInputFocused {
                HStack {
                    Spacer()
                    Button("完了") {
                        isInputFocused = false
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
            }
        }
        .onAppear {
            // 前回の同じ種目の最初のセットを自動入力（今回のセットがまだない場合のみ）
            if exercise.sets.isEmpty, let previousExercise = previousSameExercise, let firstSet = previousExercise.sets.first {
                weight = firstSet.weight.truncatingRemainder(dividingBy: 1) == 0 ? 
                    String(format: "%.0f", firstSet.weight) : 
                    String(format: "%.1f", firstSet.weight)
                reps = String(firstSet.reps)
                memo = firstSet.memo
            }
            
            // 初回表示時にフォーカスを設定
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
    
    private func addSet() {
        guard let weightValue = Double(weight),
              let repsValue = Int(reps) else { return }
        
        exercise.addSet(weight: weightValue, reps: repsValue, memo: memo)
        
        // 入力欄をクリアして次のセットの準備
        weight = ""
        reps = ""
        memo = ""
        
        // フォーカスを重量欄に戻す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }
}

struct SaveWorkoutButton: View {
    let workout: WorkoutSession
    let onSave: () -> Void
    
    var body: some View {
        VStack {
            if !workout.exercises.isEmpty {
                HStack {
                    VStack(alignment: .leading) {
                        Text("総重量: \(String(format: "%.1f", workout.totalVolume))kg")
                            .font(.subheadline)
                        Text("種目数: \(workout.exercises.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Button("ワークアウトを保存") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(workout.exercises.isEmpty)
            .padding()
        }
        .background(Color(.systemGray6))
    }
}

// MARK: - ワークアウト編集シート

struct EditWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkoutSessions: [WorkoutSession]
    
    let session: WorkoutSession
    @State private var selectedBodyPart: BodyPart
    @State private var showingExerciseSheet = false
    @State private var exerciseForSetInput: Exercise?
    @State private var showingDeleteExerciseAlert = false
    @State private var exerciseToDelete: Exercise?
    
    init(session: WorkoutSession) {
        self.session = session
        // セッションの最初の種目の部位を自動選択
        let initialBodyPart = session.exercises.first?.bodyPart ?? .chest
        _selectedBodyPart = State(initialValue: initialBodyPart)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 日付表示（コンパクト）
                HStack {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // 部位選択（固定）
                BodyPartPicker(selectedBodyPart: $selectedBodyPart)
                
                // スクロール可能なコンテンツ
                ScrollView {
                    VStack(spacing: 0) {
                        // 前回の記録表示
                        PreviousWorkoutDisplayForEdit(bodyPart: selectedBodyPart, sessions: allWorkoutSessions, editingSessionDate: session.date)
                        
                        // 現在のワークアウト編集
                        EditCurrentWorkoutView(
                            session: session,
                            selectedBodyPart: selectedBodyPart,
                            onAddExercise: {
                                showingExerciseSheet = true
                            },
                            onAddSet: { exercise in
                                exerciseForSetInput = exercise
                            },
                            onDeleteExercise: { exercise in
                                exerciseToDelete = exercise
                                showingDeleteExerciseAlert = true
                            },
                            onMoveExercise: { indices, newOffset in
                                moveExercise(from: indices, to: newOffset)
                            }
                        )
                        
                        // 保存ボタンの余白確保
                        Spacer(minLength: 100)
                    }
                }
                
                // 保存ボタン（固定）
                EditSaveWorkoutButton(session: session) {
                    saveWorkout()
                }
            }
            .navigationTitle("ワークアウト編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExerciseSheet) {
                ExerciseSelectionSheet(
                    bodyPart: selectedBodyPart,
                    onSelect: { exerciseName in
                        addExercise(name: exerciseName)
                    }
                )
            }
            .sheet(item: $exerciseForSetInput) { exercise in
                AddSetSheet(exercise: exercise)
            }
            .alert("種目を削除", isPresented: $showingDeleteExerciseAlert) {
                Button("削除", role: .destructive) {
                    if let exercise = exerciseToDelete {
                        deleteExercise(exercise)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この種目を削除してもよろしいですか？")
            }
        }
    }
    
    private func addExercise(name: String) {
        let exercise = Exercise(name: name, bodyPart: selectedBodyPart)
        modelContext.insert(exercise)
        session.addExercise(exercise)
        showingExerciseSheet = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exerciseForSetInput = exercise
        }
    }
    
    private func deleteExercise(_ exercise: Exercise) {
        session.removeExercise(exercise)
        modelContext.delete(exercise)
        exerciseToDelete = nil
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        let bodyPartExercises = session.exercises.filter { $0.bodyPart == selectedBodyPart }
        var allExercises = session.exercises
        
        // 選択中の部位の種目のみを移動
        var filteredExercises = bodyPartExercises
        filteredExercises.move(fromOffsets: source, toOffset: destination)
        
        // 他の部位の種目を除外して、移動後の順序で全体を再構築
        let otherExercises = allExercises.filter { $0.bodyPart != selectedBodyPart }
        
        // 選択中の部位の種目を挿入位置を考慮して全体リストに統合
        var newExercises: [Exercise] = []
        var bodyPartInserted = false
        
        for exercise in allExercises {
            if exercise.bodyPart == selectedBodyPart && !bodyPartInserted {
                newExercises.append(contentsOf: filteredExercises)
                bodyPartInserted = true
            } else if exercise.bodyPart != selectedBodyPart {
                newExercises.append(exercise)
            }
        }
        
        if !bodyPartInserted {
            newExercises.append(contentsOf: filteredExercises)
        }
        
        session.exercises = newExercises
    }
    
    private func saveWorkout() {
        // セットが空の種目を除外
        session.exercises = session.exercises.filter { !$0.sets.isEmpty }
        
        guard !session.exercises.isEmpty else { 
            dismiss()
            return 
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save workout: \(error)")
        }
        dismiss()
    }
}

struct EditCurrentWorkoutView: View {
    let session: WorkoutSession
    let selectedBodyPart: BodyPart
    let onAddExercise: () -> Void
    let onAddSet: (Exercise) -> Void
    let onDeleteExercise: (Exercise) -> Void
    let onMoveExercise: (IndexSet, Int) -> Void
    
    @State private var editMode: EditMode = .inactive
    
    private var bodyPartExercises: [Exercise] {
        session.exercises.filter { $0.bodyPart == selectedBodyPart }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(selectedBodyPart.displayName)の種目")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !bodyPartExercises.isEmpty {
                    Button(editMode == .active ? "完了" : "編集") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Button("種目追加", action: onAddExercise)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            if bodyPartExercises.isEmpty {
                Text("種目を追加してトレーニングを編集しましょう")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(bodyPartExercises, id: \.name) { exercise in
                        EditExerciseRow(
                            exercise: exercise,
                            onAddSet: {
                                onAddSet(exercise)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    }
                    .onMove(perform: editMode == .active ? { indices, newOffset in
                        onMoveExercise(indices, newOffset)
                    } : nil)
                    .onDelete(perform: editMode == .active ? { indexSet in
                        for index in indexSet {
                            onDeleteExercise(bodyPartExercises[index])
                        }
                    } : nil)
                }
                .listStyle(PlainListStyle())
                .environment(\.editMode, $editMode)
                .frame(minHeight: CGFloat(bodyPartExercises.count * 80))
            }
        }
        .padding(.vertical, 8)
    }
}

struct EditExerciseRow: View {
    let exercise: Exercise
    let onAddSet: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: onAddSet) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                        Text("セット追加")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            if exercise.sets.isEmpty {
                Text("セットを追加してください")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                            Text("S\(index + 1): \(String(format: "%.1f", set.weight))×\(set.reps)")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct EditSaveWorkoutButton: View {
    let session: WorkoutSession
    let onSave: () -> Void
    
    var body: some View {
        VStack {
            if !session.exercises.isEmpty {
                HStack {
                    VStack(alignment: .leading) {
                        Text("総重量: \(String(format: "%.1f", session.totalVolume))kg")
                            .font(.subheadline)
                        Text("種目数: \(session.exercises.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Button("変更を保存") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(session.exercises.isEmpty)
            .padding()
        }
        .background(Color(.systemGray6))
    }
} 