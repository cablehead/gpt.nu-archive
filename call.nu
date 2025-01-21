const computer_tools = [
  { type: "text_editor_20241022" name: "str_replace_editor" }
  { type: "bash_20241022" name: "bash" }
]

def str_replace_editor [] {
  let input = $in.input
  match $input.command {
    "view" => (cat -n $input.path)
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

# .get 03d8pn78vfs6du2ae4mxutbjt | .cas | from json | where type == "tool_use" | each {run-tool} | to json -r | .append message --meta {role: "user"}

export def thread [] {
  .cat | where topic == "message" | each {|f|
    {
      role: $f.meta.role
      content: (.cas $f.hash | from json)
    }
  }
}

export def append-assistant-response [] {
  let message = $in
  $message.content | to json -r | .append message --meta {
    role: "assistant"
    message: ($message | reject content)
  }
}
