-- Disable mouse focus (see https://github.com/basecamp/omarchy/pull/5183#issuecomment-4189299971).
o.window("^(jetbrains-.*)$", { no_follow_mouse = true })

-- Keep XWayland popups from stealing focus on hover (see https://github.com/basecamp/omarchy/issues/5601).
o.window({ class = "^(jetbrains-.*)$", title = "^(win.*)$", xwayland = true, float = true }, { no_initial_focus = true })
