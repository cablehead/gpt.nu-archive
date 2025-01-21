# edit.nu - Text editor tool implementation

# View command implementation
def "str_replace_editor view" [path: string] {
  match ($path | path type) {
    "file" => (cat -n $path)
    "dir" => (^find $path -maxdepth 2 -not -path '*/\.*')
    _ => { error make { msg: $"Invalid path type: ($path)" }}
  }
}

# String replace command implementation
def "str_replace_editor str_replace" [
  path: string # Path to the file
  old_str: string # String to replace
  new_str: string # String to replace with
] {
  # Read the file content
  let file_content = (open $path | into string)

  # Count occurrences of old_str
  let occurrences = ($file_content | split row $old_str | length | $in - 1)

  if $occurrences == 0 {
    error make {
      msg: $"No replacement was performed, old_str `($old_str)` did not appear verbatim in ($path)."
    }
  }

  # Check for multiple occurrences by examining each line
  let lines_with_matches = (
    $file_content
    | lines
    | enumerate # Add line numbers
    | where {|line| $line.item | str contains $old_str}
  )

  if ($lines_with_matches | length) > 1 {
    let line_numbers = (
      $lines_with_matches
      | each {|line| $line.index + 1}
      | str join ", "
    )
    error make {
      msg: $"No replacement was performed. Multiple occurrences of old_str `($old_str)` in lines ($line_numbers). Please ensure it is unique"
    }
  }

  # Perform the replacement
  let new_content = ($file_content | str replace $old_str $new_str)

  # Write the new content back to the file
  $new_content | save -f $path

  # Create a snippet around the edited section
  let replacement_line = (
    $file_content
    | split row $old_str
    | first
    | lines
    | length
  )

  let start_line = (max 0 ($replacement_line - 4)) # Show 4 lines before
  let new_str_lines = ($new_str | lines | length)
  let end_line = ($replacement_line + 4 + $new_str_lines) # Show 4 lines after + new content

  let snippet = (
    $new_content
    | lines
    | range ($start_line)..($end_line)
    | enumerate
    | each {|line| $"($line.index + $start_line + 1)\t($line.item)"}
    | str join "\n"
  )

  # Return success message with snippet
  $"The file ($path) has been edited.\nHere's the result of running `cat -n` on a snippet of ($path):\n($snippet)\n\nReview the changes and make sure they are as expected. Edit the file again if necessary."
}

# Main editor command that dispatches to specific implementations
def str_replace_editor [] {
  let input = $in.input
  match $input.command {
    "view" => (str_replace_editor view $input.path)
    "str_replace" => (str_replace_editor str_replace $input.path $input.old_str $input.new_str)
    _ => { error make { msg: $"Unsupported command: ($input.command)" }}
  }
}

# Export the main command
export def main [] {str_replace_editor}
