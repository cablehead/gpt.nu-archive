# edit.nu - Text editor tool implementation

# Path validation helper
def validate_path [path: string, command: string] {
  let path_type = ($path | path type)
  let exists = ($path | path exists)

  if $path_type == "dir" and $command != "view" {
    error make {
      msg: $"The path ($path) is a directory and only the `view` command can be used on directories"
    }
  }

  if not $exists {
    error make {
      msg: $"The path ($path) does not exist. Please provide a valid path."
    }
  }
}

# View command implementation
def "str_replace_editor view" [
  path: string
  --view_range: list<int> # Optional range parameter
] {
  validate_path $path "view"
  let path_type = ($path | path type)

  if $path_type == "dir" and $view_range != null {
    error make {
      msg: "The `view_range` parameter is not allowed when `path` points to a directory."
    }
  }

  if $path_type == "file" {
    let content = (open $path | lines)
    let total_lines = ($content | length)

    if $view_range != null {
      if ($view_range | length) != 2 {
        error make { msg: "Invalid `view_range`. It should be a list of two integers." }
      }

      let start_line = ($view_range | get 0)
      let end_line = ($view_range | get 1)

      if $start_line < 1 {
        error make {
          msg: $"Invalid `view_range`: ($view_range). Its first element `($start_line)` should be within the range of lines of the file: [1, ($total_lines)]"
        }
      }

      if $end_line > $total_lines {
        error make {
          msg: $"Invalid `view_range`: ($view_range). Its second element `($end_line)` should be smaller than the number of lines in the file: `($total_lines)`"
        }
      }

      if $end_line < $start_line {
        error make {
          msg: $"Invalid `view_range`: ($view_range). Its second element `($end_line)` should be larger or equal than its first `($start_line)`"
        }
      }

      let ranged_content = (
        $content
        | range ($start_line - 1)..($end_line)
        | enumerate
        | each {|line| $"($line.index + $start_line)\t($line.item)"}
        | str join "\n"
      )
      $"Here's the result of running `cat -n` on ($path):\n($ranged_content)"
    } else {
      cat -n $path
    }
  } else {
    ^find $path -maxdepth 2 -not -path '*/\.*'
  }
}

# String replace command implementation
def "str_replace_editor str_replace" [
  path: string # Path to the file
  old_str: string # String to replace
  new_str: string # String to replace with
] {
  validate_path $path "str_replace"

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
    "view" => (str_replace_editor view $input.path --view_range $input.view_range)
    "str_replace" => (str_replace_editor str_replace $input.path $input.old_str $input.new_str)
    _ => { error make { msg: $"Unsupported command: ($input.command)" }}
  }
}

# Export the main command
export def main [] {str_replace_editor}
