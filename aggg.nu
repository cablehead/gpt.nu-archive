export def main [] {
  lines | where ($it | str starts-with "data: ") | each {|x|
    $x | str substring 6.. | from json
  } | generate {|event state ={ message: null current_block: null blocks: [] }|

     mut state = $state

    $state = match $event.type {
      "message_start" => {
        $state.message = $event.message
        return { next: $state }
      }

      "ping" => { return { next: $state }}

      "content_block_start" => {
        $state.current_block = $event.content_block | insert content [] | reject text?
        return { next: $state }
      }

      "content_block_delta" => {
        match $event.delta.type {
          "text_delta" => {
            $state.current_block.content = $state.current_block.content | append $event.delta.text
          }

          "input_json_delta" => {
            $state.current_block.content = $state.current_block.content | append $event.delta.partial_json
          }

          _ => { error make { msg: $"TBD: ($event)" }}
        }

        return { next: $state }
      }

      "content_block_stop" => {
        $state.blocks = $state.blocks | append ($state.current_block | update content {str join})
        $state.current_block = null
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
