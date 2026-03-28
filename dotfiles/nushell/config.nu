# Base config (merge to preserve defaults like history settings)
$env.config = ($env.config | merge {
  show_banner: false
  table: {
    mode: rounded
  }
  history: {
    file_format: "sqlite"
    max_size: 100_000
    sync_on_enter: true
    isolation: false
  }
})

# Editor config
$env.EDITOR = "nano"
$env.VISUAL = "nano"

# Custom functions
source ~/.config/nushell/functions/nix.nu
source ~/.config/nushell/functions/aliases.nu
