export def main [] {
  lines | where ($it | str starts-with "data: ") | each {|x|
    $x | str substring 6.. | from json
  } | generate {|event state ={ message: null current_block: null }|

     mut state = $state

    $state = match $event.type {
      "message_start" => {
        $state.message = $event.message
        return { next: $state }
      }

      "ping" => { return { next: $state }}

      "content_block_start" => {
        $state.current_block = $event.content_block
        return { next: $state }
      }

      "content_block_delta" => {
        match $event.delta.type {
          "text_delta" => {
            $state.current_block.text = $state.current_block.text | append $event.delta.text
          }

          "input_json_delta" => {
            $state.current_block.partial_json = $state.current_block | get partial_json? | default [] | append $event.delta.partial_json
          }

          _ => { error make { msg: $"TBD: ($event)" }}
        }

        return { next: $state }
      }

      "content_block_stop" => {
        $state.message.content = $state.message.content | append (
          match $state.current_block.type {
            "text" => ($state.current_block | update text {str join})
            "tool_use" => ($state.current_block | update input {|x| $x.partial_json | str join | from json} | reject partial_json?)
            _ => { error make { msg: $"TBD: ($state.current_block)" }}
          }
        )

        return { next: $state }
      }

      "message_delta" => {
        return {
          next: (
            $state | merge deep {
              message: ($event.delta | insert usage $event.usage)
            }
          )
        }
      }

      "message_stop" => {
        return { out: ($state | reject current_block) }
      }

      _ => { error make { msg: $"TBD: ($event)" }}
    }

    error make { msg: $"TBD: ($event)" }
  }
}
