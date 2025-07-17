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
    
    private func saveWorkout() {
        guard !currentWorkout.exercises.isEmpty else { return }
        
        modelContext.insert(currentWorkout)
        dismiss()
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
        sessions.first { session in
            session.trainedBodyParts.contains(bodyPart)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                Text("前回の\(bodyPart.displayName)トレーニング")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            if let workout = previousWorkout {
                let bodyPartExercises = workout.exercises.filter { $0.bodyPart == bodyPart }
                
                LazyVStack(spacing: 8) {
                    ForEach(bodyPartExercises, id: \.name) { exercise in
                        PreviousExerciseRow(exercise: exercise)
                    }
                }
                .padding(.horizontal)
            } else {
                Text("まだ\(bodyPart.displayName)のトレーニング記録がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6).opacity(0.3))
    }
}

struct PreviousExerciseRow: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                    Text("\(String(format: "%.0f", set.weight))kg×\(set.reps)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

struct CurrentWorkoutView: View {
    let workout: WorkoutSession
    let selectedBodyPart: BodyPart
    let onAddExercise: () -> Void
    let onAddSet: (Exercise) -> Void
    
    private var bodyPartExercises: [Exercise] {
        workout.exercises.filter { $0.bodyPart == selectedBodyPart }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今回の\(selectedBodyPart.displayName)トレーニング")
                    .font(.headline)
                
                Spacer()
                
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
                LazyVStack(spacing: 12) {
                    ForEach(bodyPartExercises, id: \.name) { exercise in
                        CurrentExerciseRow(exercise: exercise) {
                            onAddSet(exercise)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct CurrentExerciseRow: View {
    let exercise: Exercise
    let onAddSet: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
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
                        Text("Set\(index + 1): \(String(format: "%.0f", set.weight))kg×\(set.reps)")
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
    }
}

struct ExerciseSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bodyPart: BodyPart
    let onSelect: (String) -> Void
    
    @State private var customExerciseName = ""
    @State private var showingCustomInput = false
    @State private var showingAllExercises = false
    
    private var exercisesToShow: [String] {
        showingAllExercises ? bodyPart.defaultExercises : bodyPart.primaryExercises
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("定番種目")) {
                    ForEach(exercisesToShow, id: \.self) { exercise in
                        Button(exercise) {
                            onSelect(exercise)
                            dismiss()
                        }
                        .foregroundColor(.primary)
                    }
                    
                    // もっと見る/閉じるボタン
                    if bodyPart.defaultExercises.count > bodyPart.primaryExercises.count {
                        Button(action: {
                            withAnimation {
                                showingAllExercises.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: showingAllExercises ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                Text(showingAllExercises ? "閉じる" : "もっと見る (\(bodyPart.defaultExercises.count - bodyPart.primaryExercises.count)種目)")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("カスタム種目")) {
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
                                        onSelect(customExerciseName)
                                        dismiss()
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
    let exercise: Exercise
    
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var memo: String = ""
    @FocusState private var isInputFocused: Bool
    
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
                    
                    // 既存セット表示
                    if !exercise.sets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("完了済みセット")
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
                                                Text("\(String(format: "%.0f", set.weight))kg")
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
                                            weight = String(format: "%.0f", set.weight)
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
                                TextField("例: 50", text: $weight)
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
                        Text("総重量: \(String(format: "%.0f", workout.totalVolume))kg")
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
    @State private var selectedBodyPart: BodyPart = .chest
    @State private var showingExerciseSheet = false
    @State private var exerciseForSetInput: Exercise?
    @State private var showingDeleteExerciseAlert = false
    @State private var exerciseToDelete: Exercise?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 日付表示
                VStack(spacing: 8) {
                    Text("ワークアウト編集")
                        .font(.headline)
                    Text(session.date.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // 部位選択
                BodyPartPicker(selectedBodyPart: $selectedBodyPart)
                
                // 前回の記録表示
                PreviousWorkoutDisplay(bodyPart: selectedBodyPart, sessions: allWorkoutSessions)
                
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
                    }
                )
                
                Spacer()
                
                // 保存ボタン
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
    
    private func saveWorkout() {
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
    
    private var bodyPartExercises: [Exercise] {
        session.exercises.filter { $0.bodyPart == selectedBodyPart }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(selectedBodyPart.displayName)の種目")
                    .font(.headline)
                
                Spacer()
                
                Button("種目追加", action: onAddExercise)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            if bodyPartExercises.isEmpty {
                Text("種目を追加してトレーニングを編集しましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(bodyPartExercises, id: \.name) { exercise in
                        EditExerciseRow(
                            exercise: exercise,
                            onAddSet: {
                                onAddSet(exercise)
                            },
                            onDelete: {
                                onDeleteExercise(exercise)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct EditExerciseRow: View {
    let exercise: Exercise
    let onAddSet: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("セット追加", action: onAddSet)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Button("削除", action: onDelete)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if exercise.sets.isEmpty {
                Text("セットを追加してください")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                        Text("Set\(index + 1): \(String(format: "%.0f", set.weight))kg×\(set.reps)")
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
                        Text("総重量: \(String(format: "%.0f", session.totalVolume))kg")
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