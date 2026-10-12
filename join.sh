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
# Contains no secrets; everything project-specific lives in the private repository.
set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ] || [ "${REPO#*/}" = "$REPO" ]; then
  echo "usage: bash join.sh <owner/repo>   (the repository name you were given)" >&2
  exit 2
fi

# When piped from curl, read prompts (password, sign-in) from the terminal.
if [ ! -t 0 ] && (exec < /dev/tty) 2>/dev/null; then exec < /dev/tty; fi

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || { echo "An Apple Silicon Mac is required." >&2; exit 1; }

say "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
for rc in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  grep -qs 'brew shellenv' "$rc" || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$rc"
done
echo "brew $(brew --version | head -1 | awk '{print $2}')"

say "GitHub CLI and sign-in"
command -v gh >/dev/null 2>&1 || brew install gh
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
USER_LOGIN="$(gh api user --jq .login)"
echo "signed in as $USER_LOGIN"

say "Access to $REPO"
if ! gh repo view "$REPO" >/dev/null 2>&1; then
  echo "GitHub account '$USER_LOGIN' has no access to $REPO." >&2
  echo "Ask the repository owner to invite '$USER_LOGIN', accept the invitation, then run this again." >&2
  exit 1
fi
echo "ok"

say "Clone"
DIR="$HOME/Documents/GitHub/${REPO#*/}"
if [ -d "$DIR/.git" ]; then
  echo "already cloned: $DIR"
else
  mkdir -p "$(dirname "$DIR")"
  gh repo clone "$REPO" "$DIR"
fi

cd "$DIR"
if [ -x ./dev ]; then
  say "Project setup (./dev join)"
  exec ./dev join
elif [ -x ./ip ]; then
  say "Project setup (./ip join)"
  exec ./ip join
fi
echo "Cloned to $DIR. See its README for next steps."
