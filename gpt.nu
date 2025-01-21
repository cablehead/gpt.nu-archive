export-env {
  # Coerce the provider to a record if it's a string.
  $env.GPT_PROVIDER = match ($env.GPT_PROVIDER? | describe -d | get type) {
    "string" => ($env.GPT_PROVIDER | from json)
    _ => ($env.GPT_PROVIDER?)
  }

  $env.GPT_PROVIDERS = {
    openai: {
      models: {||
        (
          http get https://api.openai.com/v1/models
          -H { Authorization: $"Bearer ($env.OPENAI_API_KEY)" }
          | get data
          | select id created
          | update created {$in * 1_000_000_000 | into datetime}
          | sort-by -r created
        )
      }

      # todo: help fix tree-sitter:
      # ]: list<record<role: string content: string>> -> string {
      call: {|model: string|
        let data = {
          model: $model
          stream: true
          messages: $in
        }

        (
          http post
          --content-type application/json
          -H { Authorization: $"Bearer ($env.OPENAI_API_KEY)" }
          https://api.openai.com/v1/chat/completions
          $data
          | lines
          | each {|line|
            if $line == "data: [DONE]" { return }
            if ($line | is-empty) { return }
            $line | str substring 6.. | from json | get choices.0.delta | if ($in | is-not-empty) {$in.content}
          }
        )
      }
    }

    anthropic : {
      models: {||
        (
          http get
          -H {
            "x-api-key": $env.ANTHROPIC_API_KEY
            "anthropic-version": "2023-06-01"
            "anthropic-beta": "computer-use-2024-10-22"
          }

          https://api.anthropic.com/v1/models
          | get data
          | select id created_at
          | rename -c { created_at: "created" }
          | update created {into datetime}
          | sort-by -r created
        )
      }

      call: {|model: string, tools?: list|
        let data = {
          model: $model
          max_tokens: 8192
          stream: true
          # TODO: anthropic only supports a single system message as a top level attribute
          messages: ($in | update role {|x| if $x.role == "system" {"user"} else {$x.role}})
          tools: ($tools | default [])
        }

        return (
          http post
          --content-type application/json
          -H {
            "x-api-key": $env.ANTHROPIC_API_KEY
            "anthropic-version": "2023-06-01"
            "anthropic-beta": "computer-use-2024-10-22"
          }
          https://api.anthropic.com/v1/messages
          $data
        )

        (
          http post
          --content-type application/json
          -H {
            "x-api-key": $env.ANTHROPIC_API_KEY
            "anthropic-version": "2023-06-01"
          }
          https://api.anthropic.com/v1/messages
          $data
          | lines
          | each {|line| $line | split row -n 2 "data: " | get 1?}
          | each {|x| $x | from json}
          | where type == "content_block_delta"
          | each {|x| $x | get delta.text}
        )
      }
    }

    cerebras : {
      models: {||
        (
          http get https://api.cerebras.ai/v1/models
          -H { Authorization: $"Bearer ($env.CEREBRAS_API_KEY)" }
          | get data
          | select id created
          | update created {$in * 1_000_000_000 | into datetime}
          | sort-by -r created
        )
      }

      call: {|model: string|
        let data = {
          model: $model
          stream: true
          messages: $in
        }

        (
          http post
          --content-type application/json
          -H { Authorization: $"Bearer ($env.CEREBRAS_API_KEY)" }
          https://api.cerebras.ai/v1/chat/completions
          $data
          | lines | each {|line| $line | split row -n 2 "data: " | get 1?} | | each {|x| $x | from json | get choices.0.delta.content?}
        )
      }
    }
  }
}

def conditional-pipe [
  condition: bool
  action: closure
] {
  if $condition {do $action} else {$in}
}

export def call [ --streamer: closure] {
  let content = $in

  let config = $env.GPT_PROVIDER
  let caller = $env.GPT_PROVIDERS | get $config.name | get call

  (
    $content
    | do $caller $config.model
    | conditional-pipe ($streamer | is-not-empty) {|| tee {each {do $streamer}}}
    | str join
  )
}

export def --env ensure-api-key [name: string] {
  let key_name = $"($name | str upcase)_API_KEY"
  if not ($key_name in $env) {
    let key = input -s $"\nRequired API key: $env.($key_name) = \"...\"\n\nIf you like, I can set it for you. Paste key: "
    set-env $key_name $key
    print "key set 👍\n"
  }
}

export def --env select-provider [] {
  print "Select a provider:"
  let name = $env.GPT_PROVIDERS | columns | input list
  print $"Selected provider: ($name)"

  let provider = $env.GPT_PROVIDERS | get $name
  ensure-api-key $name

  print -n "Select model:"
  let model = do $provider.models | get id | input list --fuzzy
  print $"Selected model: ($model)"
  $env.GPT_PROVIDER = { name: $name model: $model }
}

export def --env ensure-provider [] {
  if $env.GPT_PROVIDER? == null {select-provider}
  ensure-api-key $env.GPT_PROVIDER.name
}
