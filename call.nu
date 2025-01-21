def iff [
  action: closure
  --else: closure
]: any -> any {
  if ($in | is-not-empty) {do $action} else {
    if ($else | is-not-empty) {do $else}
  }
}

def or-else [or_else: closure] {
  if ($in | is-not-empty) {$in} else {do $or_else}
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition {do $action} else {$in}
}

def role-color [role] {
  match $role {
    "assistant" => "green"
    "user" => "blue"
    _ => "purple"
  }
}

def dash-sk [] {
  let size = term size

  $in | reverse | sk --format {
    $"..($in.id | str substring 20..) (ansi (role-color $in.role))($in.role | fill -w 9 -a r)(ansi reset) ($in.content | lines | str join)"
  } --preview {
    $in.content | bat -l md --force-colorization -p
  } --preview-window (if $size.columns >= 120 {"right:wrap"} else {"up:wrap"})
}

const computer_tools = [
  { type: "text_editor_20241022" name: "str_replace_editor" }
  { type: "bash_20241022" name: "bash" }
]

def "str_replace_editor view" [path: string] {
  match ($path | path type) {
    "file" => (cat -n $path)
    "dir" => (^find $path -maxdepth 2 -not -path '*/\.*')
    _ => { error make { msg: $"TBD: ($path)" }}
  }
}

def str_replace_editor [] {
  let input = $in.input
  match $input.command {
    "view" => (str_replace_editor view $input.path)
    _ => { error make { msg: $"TBD: ($input)" }}
  }
}

export def .call [] {
  do $env.GPT_PROVIDERS.anthropic.call "claude-3-5-sonnet-20241022" $computer_tools
}

export def run-tool [] {
  let tool = $in
  {
    type: "tool_result"
    tool_use_id: $tool.id
    content: (
      match $tool.name {
        "str_replace_editor" => ($tool | str_replace_editor)
        "bash" => (bash -c ($tool.input.command))
      }
    )
  }
}

export def handlers [] {

  {
    tool_use: {|frame|
      if $frame.topic != "message" { return }
      if $frame.meta.role != "assistant" { return }
      if $frame.meta.message.stop_reason != "tool_use" { return }
      let content = .cas $frame.hash | from json
      $content | where type == "tool_use" | each {run-tool}
    }
  }
}

export def handle-tool-use-request [frame] {
  do (handlers).tool_use $frame | to json -r | .append message --meta {
    mime_type: "application/json"
    role: "user"
    continues: $frame.id
  }
}

export def thread_bak [] {
  .cat | where topic == "message" | each {|f|
    {
      role: $f.meta.role
      content: (.cas $f.hash | from json)
    }
  }
}

export def id-to-messages [id: string] {
  let frame = .get $id
  let meta = $frame | get meta? | default {}
  let role = $meta | default "user" role | get role
  let content = .cas $frame.hash | conditional-pipe (($meta | get mime_type?) == "application/json") {from json}
  let message = {
    id: $id
    role: $role
    content: $content
  }

  let next_id = $frame | get meta?.continues?

  match ($next_id | describe -d | get type) {
    "string" => (id-to-messages $next_id | append $message)
    "list" => ($next_id | each {|id| id-to-messages $id} | flatten | append $message)
    "nothing" => [$message]
    _ => ( error make { msg: "TBD" })
  }
}

export def thread [id?: string --sk] {
  id-to-messages (
    $id | or-else {||
      .cat | where topic == "message" | last | get id
    }
  ) | conditional-pipe $sk {|| dash-sk}
}

export def run-thread [id?: string] {
  let messages = thread $id
  let continues = $messages | last | get id

  print ($messages | table -e)
  $messages | reject id | .call | aggg | last | get message | append-assistant-response $continues
}

export def append-assistant-response [continues: string] {
  let message = $in
  $message.content | to json -r | .append message --meta {
    mime_type: "application/json"
    role: "assistant"
    continues: $continues
    message: ($message | reject content)
  }
}

export def prep [path: string] {
  return [
    $"($path):"
    "```"
    (cat -n $path)
    "```"
  ] | each {str trim} | str join "\n"
}
