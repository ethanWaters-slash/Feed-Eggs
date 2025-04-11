// TaskProgressApp.swift
import SwiftUI
import UserNotifications

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly
    var id: String { self.rawValue }
}

struct Task: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date
    var recurrence: Recurrence

    init(id: UUID = UUID(), title: String, isCompleted: Bool, dueDate: Date, recurrence: Recurrence = .none) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.recurrence = recurrence
    }
}

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = [] {
        didSet {
            saveTasks()
        }
    }

    init() {
        loadTasks()
        checkForOverdueTasks()
    }

    var activeTasks: [Task] {
        tasks.filter { !$0.isCompleted || $0.recurrence != .none }
            .sorted(by: { $0.dueDate < $1.dueDate })
    }
    func updateTask(_ updatedTask: Task) {
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            tasks[index] = updatedTask
            scheduleNotification(for: updatedTask)
        }
    }

    func addTask(title: String, dueDate: Date, recurrence: Recurrence) {
        let newTask = Task(title: title, isCompleted: false, dueDate: dueDate, recurrence: recurrence)
        tasks.append(newTask)
        scheduleNotification(for: newTask)
    }

    func toggleTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            if tasks[index].recurrence != .none {
                let nextDate = nextDueDate(from: tasks[index].dueDate, recurrence: tasks[index].recurrence)
                tasks[index].dueDate = nextDate
                scheduleNotification(for: tasks[index])
            } else {
                tasks[index].isCompleted.toggle()
            }
        }
    }

    func deleteTask(_ task: Task) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
        tasks.removeAll { $0.id == task.id }
    }

    private func nextDueDate(from date: Date, recurrence: Recurrence) -> Date {
        var components = DateComponents()
        switch recurrence {
        case .daily: components.day = 1
        case .weekly: components.day = 7
        case .monthly: components.month = 1
        default: return date
        }
        return Calendar.current.date(byAdding: components, to: date) ?? date
    }

    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "tasks")
        }
    }

    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "tasks"),
           let decoded = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = decoded
        }
    }
    private func logoAttachment() -> UNNotificationAttachment? {
        guard let imageURL = Bundle.main.url(forResource: "appstore", withExtension: "png") else {
            print("⚠️ appstore.png not found in bundle.")
            return nil
        }

        let tmpDir = FileManager.default.temporaryDirectory
        let tmpFile = tmpDir.appendingPathComponent("appstore.png")

        do {
            if FileManager.default.fileExists(atPath: tmpFile.path) {
                try FileManager.default.removeItem(at: tmpFile)
            }
            try FileManager.default.copyItem(at: imageURL, to: tmpFile)
            return try UNNotificationAttachment(identifier: "appstoreLogo", url: tmpFile, options: nil)
        } catch {
            print("⚠️ Could not create attachment: \(error)")
            return nil
        }
    }



    private func scheduleNotification(for task: Task) {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "Don't forget: \(task.title)"
        content.sound = .default

        if let attachment = logoAttachment() {
            content.attachments = [attachment]
        }


        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.dueDate)
        let repeats = task.recurrence != .none

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: repeats)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification scheduling error: \(error.localizedDescription)")
            }
        }
    }

    private func checkForOverdueTasks() {
        let now = Date()
        for task in tasks where !task.isCompleted && task.dueDate < now && task.recurrence == .none {
            let content = UNMutableNotificationContent()
            content.title = "Overdue Task"
            content.body = "The task \(task.title) is overdue."
            content.sound = .default

            let request = UNNotificationRequest(identifier: "overdue-\(task.id.uuidString)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
