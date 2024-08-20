export def run-command-at [command: string, path: string] {
  let abs_path = ($path | path expand)

  if ($abs_path | path type) == 'dir'  {
    cd ($abs_path | path expand)
    nu -c $command
  }
}

export def open-editor [path: string] {
  run-command-at $env.EDITOR $path
}
