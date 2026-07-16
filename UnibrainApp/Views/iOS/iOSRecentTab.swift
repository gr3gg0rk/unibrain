import SwiftUI

#if os(iOS)
import Foundation
import UnibrainCore
import UnibrainProviders

/// Read-only list of notes from the vault per IOS-01 and UI-SPEC Surface 2.
///
/// Per IOS-01: Scans the vault for .md files using .unibrain/courses.json
/// to discover course folders. Displays sorted by date descending.
/// Tap opens read-only Text view (no editing — Obsidian is the editor).
/// Pull-to-refresh rescans.
struct iOSRecentTab: View {

    @State private var notes: [RecentNote] = []
    @State private var selectedNote: RecentNote?

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("Recent")
            .refreshable {
                await loadNotes()
            }
            .task {
                await loadNotes()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No recordings yet")
                .font(.headline)

            Text("Record a lecture and it'll appear here after your Mac processes it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        List(notes) { note in
            Button {
                selectedNote = note
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(note.courseCode) — \(note.type)")
                        .font(.subheadline)

                    Text("\(note.dateString) · \(note.durationString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $selectedNote) { note in
            NoteDetailView(note: note)
        }
    }

    // MARK: - Load

    /// Scans the vault for notes using course folder structure.
    private func loadNotes() async {
        guard let vaultURL = BookmarkStore.resolve() else {
            notes = []
            return
        }
        defer {
            vaultURL.stopAccessingSecurityScopedResource()
        }

        var found: [RecentNote] = []

        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            notes = []
            return
        }

        for entry in entries where entry.hasDirectoryPath {
            // Scan each subdirectory for .md files
            if let mdFiles = try? fm.contentsOfDirectory(
                at: entry,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) {
                for mdFile in mdFiles where mdFile.pathExtension == "md" {
                    let courseCode = entry.lastPathComponent
                    let date = (try? mdFile.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate) ?? Date()

                    found.append(RecentNote(
                        id: mdFile.path,
                        title: mdFile.deletingPathExtension().lastPathComponent,
                        courseCode: courseCode,
                        type: "Lecture",
                        date: date,
                        url: mdFile
                    ))
                }
            }
        }

        // Sort by date descending
        found.sort { $0.date > $1.date }
        notes = found
    }
}

// MARK: - RecentNote

/// A discovered note for the Recent tab.
struct RecentNote: Identifiable {
    let id: String
    let title: String
    let courseCode: String
    let type: String
    let date: Date
    let url: URL

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var durationString: String {
        // Duration unknown without parsing frontmatter — show placeholder
        return "—"
    }
}

// MARK: - NoteDetailView

/// Read-only Text view for displaying note content per IOS-01.
///
/// No editing — Obsidian is the editor per PROJECT.md Out of Scope.
struct NoteDetailView: View {
    let note: RecentNote

    @State private var content: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.body)
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if let data = try? Data(contentsOf: note.url) {
                    content = String(data: data, encoding: .utf8) ?? "Unable to read file."
                }
            }
        }
    }
}

#endif
