import AppKit

extension NSWindow {
    /// Met la fenêtre au premier plan même si l'appli (accessoire, sans Dock) n'est pas encore active : depuis un menu ou un
    /// panneau, l'activation est asynchrone et `makeKeyAndOrderFront` seul laisse la première fenêtre invisible.
    @MainActor func present() {
        NSApp.activate()
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in // activation pas encore effective : on la redemande au tour suivant
            guard let self, self.isVisible, !self.isKeyWindow else { return }
            NSApp.activate()
            self.makeKeyAndOrderFront(nil)
        }
    }
}
