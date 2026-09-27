#!/bin/bash
source "$(dirname "$0")/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')

const backgroundQml = fs.readFileSync(path.join(root, 'shell/plugins/background/Background.qml'), 'utf8')

assert(
  /function openThemeSwitcher\(\) \{[\s\S]*if \(!root\.shell \|\| !root\.shell\.summon\("omarchy\.image-picker", payload\)\)\s*Util\.execArgv\(\["omarchy-shell", "shell", "summon", "omarchy\.image-picker", payload\]\)/.test(backgroundQml) &&
    !backgroundQml.includes('omarchy-theme-switcher'),
  'background opens the in-shell theme picker instead of spawning the switcher script'
)

assert(
  backgroundQml.includes('pendingThemeFallbackTimer.restart()') &&
    backgroundQml.includes('pendingThemeFallbackTimer.stop()') &&
    backgroundQml.includes('id: pendingThemeFallbackTimer') &&
    !backgroundQml.includes('pendingThemeVersion !== backgroundVersion'),
  'background theme transition applies pending colors even if image reveal stalls'
)

const themeSet = fs.readFileSync(path.join(root, 'bin/omarchy-theme-set'), 'utf8')

// The next background decodes while the theme stages, rather than after the
// transition arrives: WebP decodes take as long at screen size as at native.
assert(
  /function prepare\(path: string\): void \{\s*root\.prepareBackground\(path\)/.test(backgroundQml) &&
    backgroundQml.includes('source: root.imageUrl(root.incomingBackground || root.preparedBackground)'),
  'background decodes a prepared theme background in the hidden incoming frame'
)
assert(
  /path === lastTransitionPath/.test(backgroundQml) &&
    /id: preparedBackgroundTimer[\s\S]*?onTriggered: root\.preparedBackground = ""/.test(backgroundQml),
  'background ignores a late prepare and drops an unclaimed one'
)
assert(
  themeSet.indexOf('shell_ipc background prepare') !== -1 &&
    themeSet.indexOf('shell_ipc background prepare') < themeSet.indexOf('\nomarchy-theme-set-templates\n'),
  'theme set hands the shell its next background before rendering templates'
)
assert(
  themeSet.includes('shell_ipc background prepare "$PREPARED_BACKGROUND_SNAPSHOT" 9>&- &'),
  'theme set sends the prepare without holding the theme lock or waiting on it'
)
JS
