// TaskProgressApp.swift
import SwiftUI
import UserNotifications

struct ContentView: View {
    @StateObject private var manager = TaskManager()
    @State private var newTaskTitle = ""
    @State private var dueDate = Date()
    @State private var recurrence: Recurrence = .none
    @State private var showNewTaskForm = false // <-- Added this
    @State private var showDeleteConfirmation = false
    @State private var taskToDelete: Task?
    @State private var animatedTaskId: UUID? = nil
    @State private var taskToEdit: Task? = nil
    @State private var showEditSheet = false
    @Namespace private var animation

    private func backgroundColor(for task: Task) -> Color {
        let now = Date()
        let timeInterval = task.dueDate.timeIntervalSince(now)
        if timeInterval < 0 {
            return Color.red.opacity(0.15) // Overdue
        } else if timeInterval <= 86400 {
            return Color.yellow.opacity(0.15)
        } else {
            return Color.blue.opacity(0.1)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Task Off")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    // ✅ Button shows form using `showNewTaskForm`
                    Button(action: {
                        withAnimation {
                            showNewTaskForm = true
                            newTaskTitle = ""
                        }
                    }) {
                        Label("Add New Task", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.horizontal)

                    // ✅ Show task input UI only when flag is true
                    if showNewTaskForm {
                        TextField("Enter task name", text: $newTaskTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        DatePicker("Due Date & Time", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .padding(.horizontal)

                        Picker("Recurrence", selection: $recurrence) {
                            ForEach(Recurrence.allCases) { option in
                                Text(option.rawValue.capitalized).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)

                        HStack {
                            Button("Cancel") {
                                withAnimation {
                                    showNewTaskForm = false
                                    newTaskTitle = ""
                                    dueDate = Date()
                                    recurrence = .none
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding(.leading)

                            Spacer()

                            Button(action: {
                                guard !newTaskTitle.isEmpty else { return }
                                withAnimation {
                                    manager.addTask(title: newTaskTitle, dueDate: dueDate, recurrence: recurrence)
                                    showNewTaskForm = false
                                    newTaskTitle = ""
                                    dueDate = Date()
                                    recurrence = .none
                                }
                            }) {
                                Label("Add Task", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding(.trailing)
                        }
                    }

                    Text("My Tasks")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    List {
                        ForEach(manager.activeTasks) { task in
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(backgroundColor(for: task))

                                HStack(spacing: 16) {
                                    if animatedTaskId == task.id {
                                        Spacer()
                                        Text("✅ Completed!")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                        Spacer()
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(task.title)
                                                .font(.headline)

                                            Text("Due: \(task.dueDate.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption)
                                                .foregroundColor(task.dueDate < Date() ? .red : .gray)

                                            if task.recurrence != .none {
                                                Text("Repeats: \(task.recurrence.rawValue.capitalized)")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                            }
                                        }

                                        Spacer()

                                        Button("Done") {
                                            withAnimation(.spring()) {
                                                animatedTaskId = task.id
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                    withAnimation {
                                                        manager.toggleTask(task)
                                                        animatedTaskId = nil
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)
                                        .font(.subheadline)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                            }
                            .onTapGesture {
                                taskToEdit = task
                                showEditSheet = true
                            }
                            .frame(height: 80)
                            .cornerRadius(16)
                            .padding(.horizontal, 12)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
                .alert(item: $taskToDelete) { task in
                    Alert(
                        title: Text("Delete '\(task.title)'?"),
                        message: Text("Are you sure you want to delete the task \"\(task.title)\"?"),
                        primaryButton: .destructive(Text("Delete")) {
                            withAnimation {
                                manager.deleteTask(task)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                .sheet(item: $taskToEdit) { task in
                    TaskEditorView(task: task, manager: manager)
                }
            }
        }
    }
}

    struct TaskEditorView: View {
        @Environment(\.dismiss) var dismiss
        @State var task: Task
        @ObservedObject var manager: TaskManager
        @State private var showDeleteConfirmation = false
        
        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Title")) {
                        TextField("Task Title", text: $task.title)
                    }
                    Section(header: Text("Due Date")) {
                        DatePicker("", selection: $task.dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    Section(header: Text("Recurrence")) {
                        Picker("Recurrence", selection: $task.recurrence) {
                            ForEach(Recurrence.allCases) { option in
                                Text(option.rawValue.capitalized).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle("Edit Task")
                .alert("Delete '\(task.title)'?", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        manager.deleteTask(task)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            manager.updateTask(task)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
