# newthing

Bootstrap a fresh Apple Silicon Mac for development on a private GitHub repository.

```bash
curl -fsSL https://raw.githubusercontent.com/toddvarland/newthing/main/join.sh | bash -s -- <owner/repo>
```

To review the script before running it:

```bash
curl -fsSLO https://raw.githubusercontent.com/toddvarland/newthing/main/join.sh
less join.sh
bash join.sh <owner/repo>
```

**What it does:**
1. Installs Homebrew (official installer) and the GitHub CLI.
2. Signs you in to GitHub in your browser.
3. Checks that you have access to the repository.
4. Clones it to `~/Documents/GitHub/<repo>`.
5. Runs the repository's own setup (`./dev join`) if it has one.

**While it runs:** each stage is numbered with the elapsed time, prompts that need you are marked
`>>> Your turn`, and everything is logged to `~/Library/Logs/newthing/` (local only). Follow along
from another window with the `tail -f` command it prints. If it stops, it names the stage and you
run the same command again: finished stages are skipped. A notification appears when it ends.

It contains no secrets. You need an invitation to the private repository.
