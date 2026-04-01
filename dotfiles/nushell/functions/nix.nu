# Rebuild NixOS
def --env rebuild [--unclean] {
  echo "Changing directory to /config"
  cd /config

  if $unclean {
    echo "Rebuilding without safety checks (unclean mode)..."
  } else {
    echo "Pulling git updates..."
    try { git pull } catch {
      # First pull has unrelated histories — force sync to remote
      print "Syncing with remote..."
      try {
        git fetch origin
        git reset --hard origin/main
      } catch {
        print "WARNING: git sync failed, rebuilding with local state"
      }
    }

    echo "Running safety checks..."
    just check
  }

  echo "> Building NixOS configuration"
  nh os switch /config
}

# Update flake
def --env upgrade [] {
  echo "Switching to /config"
  cd /config

  echo "Upgrading flake..."
  nix flake update
}

export def --env clean [arg?: string] {
  let help = [
    "Usage:"
    "  clean           # show help"
    "  clean +N        # Keep last N generations"
    ""
    "Example:"
    "  clean +10       # This keeps the last 10 generations"
  ]

  if ($arg | is-empty) or (not ($arg | str starts-with "+")) {
    $help | str join (char nl) | print
    return
  }

  let keep = (try {
    $arg | str trim | str replace '^\+' '' | into int
  } catch {
    -1
  })

  if $keep <= 0 {
    print $"Error: expected +N where N is a positive integer, got '($arg)'."
    print ""
    $help | str join (char nl) | print
    return (1)
  }

  print $"Cleaning all profiles, keeping last ($keep) generations..."
  sudo nix-collect-garbage --delete-older-than $"($keep)d"
  nh os boot /config
}
