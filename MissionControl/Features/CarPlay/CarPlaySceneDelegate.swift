import CarPlay
import Combine
import UIKit

/// The car's companion to the phone assistant. CarPlay reserves the screen for system templates, so this carries the
/// Mission Control mark, the voice state, the last exchange and what is on today — voice is the primary input.
///
/// Template depth is capped at three for the voice-based conversation category: the assistant screen is the root, the
/// full day is one push, and a task, event or goal is the last. Anything deeper is a conversation, not a screen.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let voice = AssistantVoiceCoordinator(playsStartupCue: false)
    private let workspace = CarPlayWorkspace()
    private var root: CarPlayRootScreen?
    private var observers = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var voiceTemplate: CPVoiceControlTemplate?
    private var voicePresented = false
    private var previousState: AssistantVoiceCoordinator.State = .idle

    // MARK: Scene

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let root = CarPlayRootScreen(voice: voice, workspace: workspace)
        root.talk = { [weak self] in self?.toggleVoice() }
        root.openToday = { [weak self] in self?.pushToday() }
        root.openItem = { [weak self] entry in self?.pushItem(entry) }
        root.openGoal = { [weak self] goal in self?.pushGoal(goal) }
        root.retry = { [weak self] in self?.refreshWorkspace() }
        self.root = root
        interfaceController.setRootTemplate(root.template, animated: false, completion: nil)
        voice.updateGatewayAppActivity(true)
        observe()
        refreshWorkspace()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await self?.workspace.refresh()
                self?.root?.refresh()
            }
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        observers.removeAll()
        refreshTask?.cancel(); refreshTask = nil
        voice.cancel()
        if voicePresented {
            interfaceController.dismissTemplate(animated: false, completion: nil)
            voicePresented = false
        }
        voiceTemplate = nil
        root = nil
        self.interfaceController = nil
    }

    // MARK: Voice

    private func observe() {
        voice.$state.sink { [weak self] state in
            // @Published publishes before the property is assigned; refresh after the current turn of the run loop so
            // the screen reads the state that produced the event.
            DispatchQueue.main.async { self?.stateChanged(state) }
        }.store(in: &observers)
        voice.$conversationText.sink { [weak self] _ in
            DispatchQueue.main.async { self?.root?.refresh() }
        }.store(in: &observers)
        voice.$message.sink { [weak self] _ in
            DispatchQueue.main.async { self?.root?.refresh() }
        }.store(in: &observers)
    }

    private func stateChanged(_ state: AssistantVoiceCoordinator.State) {
        root?.refresh()
        updateVoiceTemplate(state)
        let turnFinished = (previousState == .processing || previousState == .speaking) && state == .listening
        previousState = state
        if turnFinished { refreshWorkspace() }
    }

    private func toggleVoice() {
        switch voice.state {
        case .idle, .unavailable: voice.toggle()
        case .preparing, .listening, .processing, .speaking: voice.cancel()
        }
    }

    private func updateVoiceTemplate(_ state: AssistantVoiceCoordinator.State) {
        guard let interfaceController else { return }
        switch state {
        case .idle, .unavailable:
            guard voicePresented else { return }
            voicePresented = false
            voiceTemplate = nil
            interfaceController.dismissTemplate(animated: true, completion: nil)
        case .preparing, .listening, .processing, .speaking:
            let template: CPVoiceControlTemplate
            if let existing = voiceTemplate {
                template = existing
            } else {
                template = makeVoiceTemplate()
                voiceTemplate = template
            }
            if !voicePresented {
                voicePresented = true
                interfaceController.presentTemplate(template, animated: true, completion: nil)
            }
            template.activateVoiceControlState(withIdentifier: identifier(for: state))
        }
    }

    private func makeVoiceTemplate() -> CPVoiceControlTemplate {
        let states = [
            CPVoiceControlState(identifier: "preparing",
                                titleVariants: ["Getting ready", "One moment"],
                                image: AgentMarkArtwork.animatedImage(state: .preparing),
                                repeats: true),
            CPVoiceControlState(identifier: "listening",
                                titleVariants: ["Listening…", "I’m listening"],
                                image: AgentMarkArtwork.animatedImage(state: .listening),
                                repeats: true),
            CPVoiceControlState(identifier: "thinking",
                                titleVariants: ["Thinking…", "Working on it"],
                                image: AgentMarkArtwork.animatedImage(state: .processing),
                                repeats: true),
            CPVoiceControlState(identifier: "speaking",
                                titleVariants: ["Speaking…", "Mission Control is replying"],
                                image: AgentMarkArtwork.animatedImage(state: .speaking),
                                repeats: true),
        ]
        let template = CPVoiceControlTemplate(voiceControlStates: states)
        if #available(iOS 26.4, *) {
            template.trailingNavigationBarButtons = [
                CPBarButton(title: "End") { [weak self] _ in self?.voice.cancel() },
            ]
        }
        return template
    }

    private func identifier(for state: AssistantVoiceCoordinator.State) -> String {
        switch state {
        case .preparing: return "preparing"
        case .listening: return "listening"
        case .processing: return "thinking"
        case .speaking: return "speaking"
        case .idle, .unavailable: return "listening"
        }
    }

    // MARK: Navigation

    private func pushToday() {
        guard let interfaceController else { return }
        let today = CarPlayScreens.today(workspace,
                                         retry: { [weak self] in self?.refreshWorkspace() }) { [weak self] entry, completion in
            self?.pushItem(entry, completion: completion)
        }
        interfaceController.pushTemplate(today, animated: true, completion: nil)
    }

    private func pushItem(_ entry: Wire.DayEntry, completion: (() -> Void)? = nil) {
        guard let interfaceController else { completion?(); return }
        let goalTitle = workspace.openGoals.first { $0.id == entry.item.goalId }?.title
        let template = CarPlayScreens.item(
            entry,
            goalTitle: goalTitle,
            complete: { [weak self] done in
                guard let self else { return false }
                let accepted = await workspace.setDone(entry, done: done)
                if accepted {
                    root?.refresh()
                    interfaceController.popToRootTemplate(animated: true, completion: nil)
                }
                return accepted
            },
            snooze: { [weak self] in
                guard let self else { return false }
                let accepted = await workspace.snooze(entry, minutes: 60)
                if accepted {
                    root?.refresh()
                    interfaceController.popToRootTemplate(animated: true, completion: nil)
                }
                return accepted
            }
        )
        interfaceController.pushTemplate(template, animated: true, completion: nil)
        completion?()
    }

    private func pushGoal(_ goal: Wire.Goal) {
        guard let interfaceController else { return }
        interfaceController.pushTemplate(CarPlayScreens.goal(goal), animated: true, completion: nil)
    }

    // MARK: Workspace

    private func refreshWorkspace() {
        Task { [weak self] in
            guard let self else { return }
            await workspace.refresh()
            root?.refresh()
        }
    }
}
