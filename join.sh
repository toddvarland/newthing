#!/bin/bash
# Bootstrap a fresh Apple Silicon Mac for development on a private GitHub repository.
#
#   curl -fsSL https://raw.githubusercontent.com/toddvarland/newthing/main/join.sh | bash -s -- <owner/repo>
#
# Or, to read it first:
#   curl -fsSLO https://raw.githubusercontent.com/toddvarland/newthing/main/join.sh
#   less join.sh && bash join.sh <owner/repo>
#
# Steps: Homebrew (official installer), GitHub CLI, browser sign-in to GitHub, access check,
# clone into ~/Documents/GitHub/<repo>, then hand over to the repo's own "./dev join" (or older "./ip join") if present.
# Shows progress as it goes, keeps a log in ~/Library/Logs/newthing/, and notifies when done.
# Contains no secrets; everything project-specific lives in the private repository.
set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ] || [ "${REPO#*/}" = "$REPO" ]; then
  echo "usage: bash join.sh <owner/repo>   (the repository name you were given)" >&2
  exit 2
fi
DIR="$HOME/Documents/GitHub/${REPO#*/}"

# When piped from curl, read prompts (password, sign-in) from the terminal.
if [ ! -t 0 ] && (exec < /dev/tty) 2>/dev/null; then exec < /dev/tty; fi

# Colors only on a terminal; the project's own steps keep theirs through the log (DEV_COLOR).
if [ -t 1 ]; then B=$'\033[1m'; Y=$'\033[33m'; G=$'\033[32m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'; export DEV_COLOR=1
else B=""; Y=""; G=""; R=""; D=""; N=""; fi

# Everything shown here is also written to a log (local only), to follow or share if something fails.
LOG_DIR="$HOME/Library/Logs/newthing"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/join-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

START="$(date +%s)"
TOTAL=5
STEP=0
STEP_NAME="starting"
dur() { local s=$(( $(date +%s) - START )); printf '%dm %02ds' $((s / 60)) $((s % 60)); }
step() { STEP=$((STEP + 1)); STEP_NAME="$1"; printf '\n%s==> [%d/%d] %s%s  %s(%s elapsed)%s\n' "$B" "$STEP" "$TOTAL" "$1" "$N" "$D" "$(dur)" "$N"; }
note() { printf '    %s%s%s\n' "$D" "$*" "$N"; }
yourturn() { printf '\n  %s>>> Your turn:%s %s\n' "$Y$B" "$N" "$*"; }
notify() { osascript -e "display notification \"$1\" with title \"Mac setup\"" >/dev/null 2>&1 || true; }

finish() {
  local rc=$?
  if [ "$rc" = 0 ]; then
    printf '\n%sSetup finished%s in %s. Log: %s\n' "$G$B" "$N" "$(dur)" "$LOG"
    notify "Finished in $(dur)"
  else
    printf '\n%sStopped%s at step %d/%d (%s) after %s.\n' "$R$B" "$N" "$STEP" "$TOTAL" "$STEP_NAME" "$(dur)"
    printf '  Fix the problem shown above, then run the same command again: finished steps are skipped.\n'
    printf '  Full log: %s\n' "$LOG"
    notify "Stopped at step $STEP/$TOTAL ($STEP_NAME)"
  fi
}
trap finish EXIT

[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo "An Apple Silicon Mac is required." >&2; exit 1; }

cat <<EOF
${B}Setting up this Mac for $REPO${N}
  1. Homebrew          (asks for your Mac password once; typing shows nothing)
  2. GitHub sign-in    (opens your browser)
  3. Access check
  4. Clone             -> $DIR
  5. Project setup     (the project's own steps; the longest part, 20-45 min)
  Total: usually 30-60 minutes. Prompts appear here, marked ">>> Your turn".
  Files go to the folder above, not the current folder.
  Follow along from another window:  tail -f "$LOG"
EOF

step "Homebrew"
if command -v brew >/dev/null 2>&1 || [ -x /opt/homebrew/bin/brew ]; then
  note "already installed"
else
  yourturn "enter your Mac password when asked, and press Enter to continue the Homebrew installer."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
for rc in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  # shellcheck disable=SC2016  # written literally into the profile, expanded at login
  grep -qs 'brew shellenv' "$rc" || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$rc"
done
note "brew $(brew --version | head -1 | awk '{print $2}')"

step "GitHub CLI and sign-in"
command -v gh >/dev/null 2>&1 || { note "installing the GitHub CLI (about 1 minute)"; brew install gh; }
if gh auth status >/dev/null 2>&1; then
  note "already signed in"
else
  yourturn "copy the one-time code shown below, press Enter, sign in to GitHub in the browser and paste the code."
  gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git
USER_LOGIN="$(gh api user --jq .login)"
note "signed in as $USER_LOGIN"

step "Access to $REPO"
if ! gh repo view "$REPO" >/dev/null 2>&1; then
  echo "GitHub account '$USER_LOGIN' has no access to $REPO." >&2
  echo "Ask the repository owner to invite '$USER_LOGIN', accept the invitation, then run this again." >&2
  exit 1
fi
note "ok"

step "Clone"
if [ -d "$DIR/.git" ]; then
  note "already cloned: $DIR"
else
  mkdir -p "$(dirname "$DIR")"
  gh repo clone "$REPO" "$DIR"
  note "cloned to $DIR"
fi

cd "$DIR"
if [ -x ./dev ]; then
  step "Project setup (./dev join; it numbers its own steps 1/6 to 6/6)"
  ./dev join
elif [ -x ./ip ]; then
  step "Project setup (./ip join)"
  ./ip join
else
  step "Project setup"
  note "No setup command in the repository. See its README for next steps."
fi
