//
//  NotificationService.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import Foundation
import FirebaseMessaging
import FirebaseFirestore
import UserNotifications

final class NotificationService: NSObject {
    static let shared = NotificationService()
    private let db = Firestore.firestore()

    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }

    func saveToken(_ token: String, for userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "fcmToken": token
        ])
    }
}