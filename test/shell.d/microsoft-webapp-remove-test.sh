#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export PATH="$tmp/bin:$ROOT/bin:$PATH"
export OMARCHY_REMOVE_NOTIFY=false
mkdir -p "$HOME/.local/share/applications" "$tmp/bin"
printf '#!/bin/bash\nexit 0\n' >"$tmp/bin/update-desktop-database"
chmod +x "$tmp/bin/update-desktop-database"

native="$HOME/.local/share/applications/Microsoft Teams.desktop"
printf '[Desktop Entry]\nName=Microsoft Teams\nExec=teams-for-linux\nType=Application\n' >"$native"
cp "$native" "$tmp/native-original"

webapp="$HOME/.local/share/applications/Microsoft Outlook.desktop"
printf '[Desktop Entry]\nName=Microsoft Outlook\nExec=omarchy-launch-webapp "https://outlook.example.org/" --user-data-dir=/tmp/work-profile\nType=Application\n' >"$webapp"

omarchy-remove-service-microsoft >/dev/null
cmp -s "$native" "$tmp/native-original" || fail "bundle removal preserves a same-name native launcher"
pass "bundle removal preserves a same-name native launcher"
[[ ! -e $webapp ]] || fail "bundle removal deletes its web apps with customized URLs and profiles"
pass "bundle removal deletes its web apps with customized URLs and profiles"

run_node_test <<'JS'
const fs = require('fs')
const { spawnSync } = require('child_process')
const menu = requireFromRoot('shell/plugins/menu/MenuModel.js')
const items = menu.parseMenuJsonc(fs.readFileSync(path.join(root, 'default/omarchy/omarchy-menu.jsonc'), 'utf8'))
const install = items.find(item => item.id === 'install.service.microsoft')
const remove = items.find(item => item.id === 'remove.service.microsoft')
assert(install && remove, 'Microsoft service menu entries exist')
function guard(expression) {
  return spawnSync('bash', ['-c', expression], { env: process.env }).status
}
assert(guard(remove.when) !== 0, 'removal menu hides when only a native launcher remains')
const applications = path.join(process.env.HOME, '.local/share/applications')
for (const app of ['Microsoft Outlook', 'Microsoft Office', 'Microsoft OneDrive']) {
  fs.writeFileSync(path.join(applications, `${app}.desktop`), '[Desktop Entry]\nExec=omarchy-launch-webapp "https://example.org/"\n')
}
assert(guard(install.disabled) !== 0, 'three web apps plus native Teams do not disable installation')
fs.writeFileSync(path.join(applications, 'Microsoft Teams.desktop'), '[Desktop Entry]\nExec=omarchy-launch-webapp "https://teams.cloud.microsoft/"\n')
assertEqual(guard(install.disabled), 0, 'all four web apps disable installation')
JS
