//
//  FirebaseService.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

final class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()

    private init() {}

    func createTeam(name: String, season: String, managerId: String) async throws -> Team {
        let inviteCode = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
        let team = Team(
            id: nil,
            name: name,
            managerId: managerId,
            memberIds: [managerId],
            inviteCode: inviteCode,
            createdAt: Date(),
            season: season
        )
        let ref = try db.collection("teams").addDocument(from: team)
        var created = team
        created.id = ref.documentID
        return created
    }

    func joinTeam(inviteCode: String, userId: String) async throws -> Team {
        let snapshot = try await db.collection("teams")
            .whereField("inviteCode", isEqualTo: inviteCode)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw FirebaseServiceError.teamNotFound
        }
        try await doc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
        return try doc.data(as: Team.self)
    }

    func fetchTeam(teamId: String) async throws -> Team {
        try await db.collection("teams").document(teamId).getDocument(as: Team.self)
    }

    func updateUserTeamIds(userId: String, teamIds: [String]) async throws {
        try await db.collection("users").document(userId).updateData([
            "teamIds": teamIds
        ])
    }

    func addMember(_ member: Member) async throws {
        _ = try db.collection("members").addDocument(from: member)
    }

    func fetchMembers(teamId: String) async throws -> [Member] {
        let snapshot = try await db.collection("members")
            .whereField("teamId", isEqualTo: teamId)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: Member.self) }
    }

    func createGameWeek(_ gameWeek: GameWeek) async throws -> GameWeek {
        let ref = try db.collection("gameWeeks").addDocument(from: gameWeek)
        var created = gameWeek
        created.id = ref.documentID
        return created
    }

    func fetchGameWeeks(teamId: String) async throws -> [GameWeek] {
        let snapshot = try await db.collection("gameWeeks")
            .whereField("teamId", isEqualTo: teamId)
            .order(by: "weekNumber")
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: GameWeek.self) }
    }

    func submitLeg(_ leg: AccumulatorLeg) async throws {
        _ = try db.collection("legs").addDocument(from: leg)
    }

    func fetchLegs(teamId: String, gameWeekId: String) async throws -> [AccumulatorLeg] {
        let snapshot = try await db.collection("legs")
            .whereField("teamId", isEqualTo: teamId)
            .whereField("gameWeekId", isEqualTo: gameWeekId)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: AccumulatorLeg.self) }
    }

    func fetchLegs(teamId: String) async throws -> [AccumulatorLeg] {
        let snapshot = try await db.collection("legs")
            .whereField("teamId", isEqualTo: teamId)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: AccumulatorLeg.self) }
    }

    func updateLegOutcome(legId: String, outcome: LegOutcome) async throws {
        try await db.collection("legs").document(legId).updateData([
            "outcome": outcome.rawValue
        ])
    }

    func listenToLegs(teamId: String, onChange: @escaping ([AccumulatorLeg]) -> Void) -> ListenerRegistration {
        db.collection("legs")
            .whereField("teamId", isEqualTo: teamId)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let legs = documents.compactMap { try? $0.data(as: AccumulatorLeg.self) }
                onChange(legs)
            }
    }
    
    func fetchMember(teamId: String, userId: String) async throws -> Member? {
        let snapshot = try await db.collection("members")
            .whereField("teamId", isEqualTo: teamId)
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.map { try $0.data(as: Member.self) }
    }
    
    func setGameWeekBookmaker(gameWeekId: String, bookmaker: String, combinedOdds: Double) async throws {
        try await db.collection("gameWeeks").document(gameWeekId).updateData([
            "selectedBookmaker": bookmaker,
            "combinedOdds": combinedOdds
        ])
    }
    
    func settleGameWeek(gameWeekId: String) async throws {
        try await db.collection("gameWeeks").document(gameWeekId).updateData([
            "isSettled": true
        ])
    }
}

enum FirebaseServiceError: LocalizedError {
    case teamNotFound

    var errorDescription: String? {
        switch self {
        case .teamNotFound: return "No team found with that invite code."
        }
    }
}
