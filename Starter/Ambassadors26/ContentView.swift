import SwiftUI
import AppKit

@main
struct Ambassadors26App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color(red: 0.42, green: 0.22, blue: 0.62))
                .frame(minWidth: 1120, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1240, height: 720)
    }
}

/// The workshop starter: a three-pane shell with no intelligence in it yet.
///
/// The left pane works — you can type notes or load the sample. The middle and
/// right panes are empty placeholders, and "Build initiative" does nothing.
/// Filling those in is what the three workshop prompts do.
struct ContentView: View {
    @State private var transcript = ""

    /// A realistic conversation to demo with, so nobody has to invent one.
    private static let sample = """
    25 Windows PCs on the bench. The ELN is in a US cloud and QA is unhappy.
    Scientists photograph gel trays on personal phones.
    Anything with patient-derived samples has to stay on-prem.
    """

    var body: some View {
        HSplitView {
            inputPane
                .frame(minWidth: 360)

            outputPane
                .frame(minWidth: 360)

            emailPane
                .frame(minWidth: 360)
        }
        .navigationTitle("Lab Brief")
    }

    // MARK: - Input

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            PaneHeader(
                title: "Conversation notes",
                subtitle: "Notes from a conversation with a biotech lab manager."
            )

            notesEditor

            controls

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notesEditor: some View {
        TextEditor(text: $transcript)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.separator)
            }
            .overlay(alignment: .topLeading) {
                if transcript.isEmpty {
                    Text("e.g. 25 bench PCs, ELN in the cloud, GxP…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 160)
            .accessibilityLabel("Conversation notes")
            .accessibilityHint("Enter the notes to analyze.")
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button("Use sample") {
                transcript = Self.sample
            }
            .help("Fill the notes with an example conversation")

            Spacer()

            Button("Build initiative") {
                // Nothing yet — the first workshop prompt wires this up.
            }
            .buttonStyle(.borderedProminent)
            .disabled(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Analyze the notes and draft a proposal")
        }
        .controlSize(.large)
    }

    // MARK: - Output

    private var outputPane: some View {
        ContentUnavailableView(
            "No initiative yet",
            systemImage: "atom",
            description: Text("Build an initiative to see a structured recommendation here.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.secondary)
    }

    // MARK: - Follow-up email

    private var emailPane: some View {
        ContentUnavailableView(
            "No draft yet",
            systemImage: "envelope",
            description: Text("A proposal email is drafted automatically once an initiative is built.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.secondary)
    }
}

// MARK: - Reusable pieces

/// A consistent section header with an optional subtitle, exposed to VoiceOver
/// as a heading.
private struct PaneHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
