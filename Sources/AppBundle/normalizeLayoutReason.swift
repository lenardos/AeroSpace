func normalizeLayoutReason() {
    for workspace in Workspace.all {
        let windows: [Window] = workspace.allLeafWindowsRecursive
        _normalizeLayoutReason(workspace: workspace, windows: windows)
    }
    _normalizeLayoutReason(workspace: Workspace.focused, windows: macosInvisibleWindowsContainer.children.filterIsInstance(of: Window.self))
}

private func _normalizeLayoutReason(workspace: Workspace, windows: [Window]) {
    for window in windows {
        let isMacosFullscreen = window.isMacosFullscreen
        let isMacosInvisible = !isMacosFullscreen && (window.isMacosMinimized || window.macAppUnsafe.nsApp.isHidden)
        switch window.layoutReason {
            case .standard:
                if isMacosFullscreen {
                    window.layoutReason = .macos(prevParentKind: window.parent.kind)
                    window.unbindFromParent()
                    window.bind(to: workspace.macOsNativeFullscreenWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                } else if isMacosInvisible {
                    window.layoutReason = .macos(prevParentKind: window.parent.kind)
                    window.unbindFromParent()
                    window.bind(to: macosInvisibleWindowsContainer, adaptiveWeight: 1, index: INDEX_BIND_LAST)
                }
            case .macos(let prevParentKind):
                if !isMacosFullscreen && !isMacosInvisible {
                    window.unbindFromParent()
                    exitMacOsNativeOrInvisibleState(window: window, prevParentKind: prevParentKind, workspace: workspace)
                }
        }
    }
}

func exitMacOsNativeOrInvisibleState(window: Window, prevParentKind: NonLeafTreeNodeKind, workspace: Workspace) {
    window.layoutReason = .standard
    switch prevParentKind {
        case .workspace:
            window.bindAsFloatingWindow(to: workspace)
        case .tilingContainer:
            let data = getBindingDataForNewTilingWindow(workspace)
            window.bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
        case .macosInvisibleWindowsContainer, .macosFullscreenWindowsContainer: // wtf case, should never be possible. But If encounter it, let's just re-layout window
            window.relayoutWindow(on: workspace)
    }
}

extension Window {
    func relayoutWindow(on workspace: Workspace) {
        let data = getBindingDataForNewWindow(self.asMacWindow().axWindow, workspace, self.macAppUnsafe)
        bind(to: data.parent, adaptiveWeight: data.adaptiveWeight, index: data.index)
    }
}
