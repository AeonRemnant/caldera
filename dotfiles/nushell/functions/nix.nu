# Rebuild NixOS
def --env rebuild [--unclean] {
  # Authenticate early so sudo session persists through the whole rebuild
  sudo true

  echo "Changing directory to ~/.config/caldera"
  cd ~/.config/caldera

  if $unclean {
    echo "Rebuilding without safety checks (unclean mode)..."
  } else {
    echo "Pulling git updates..."
    git pull

    echo "Running safety checks..."
    just check
  }

  echo "> Building NixOS configuration"
  sudo nixos-rebuild switch --flake . o+e>| nom
}

# Update flake
def --env upgrade [] {
  echo "Switching to ~/.config/caldera"
  cd ~/.config/caldera

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
  sudo nix-collect-garbage --delete-older-than "${keep}d"
  sudo nixos-rebuild boot --flake .
}
