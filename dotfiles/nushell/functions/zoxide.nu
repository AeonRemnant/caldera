def --env z [path?: string] {
  if ($path | is-empty) {
    zoxide query --list
  } else {
    let target = (zoxide query $path)
    cd $target
  }
}

def --env zi [] {
  let target = (zoxide query --interactive)
  cd $target
}

def --env zcd [path: string] {
  cd $path
  zoxide add $path
}

$env.config.hooks.pre_prompt = ($env.config.hooks.pre_prompt | append {
  condition: {|| true }
  code: {|| zoxide add (pwd) }
})
