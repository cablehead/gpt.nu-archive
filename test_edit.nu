use std assert
use edit.nu

# Create a temporary test directory
def setup [] {
  let test_dir = (mktemp -d)

  # Create test files
  "test file content" | save $"($test_dir)/test.txt"
  mkdir $"($test_dir)/subdir"
  "subdir content" | save $"($test_dir)/subdir/file.txt"

  # Return the test directory path for tests to use
  $test_dir
}

def test_view_file [test_dir: string] {
  let input = {
    input: {
      command: "view"
      path: $"($test_dir)/test.txt"
    }
  }

  let result = ($input | edit)

  # Check if output contains line numbers and content
  assert str contains $result "test file content" "Output should contain the file content"
  assert str contains $result "1" "Output should contain line numbers"
}

def test_view_directory [test_dir: string] {
  let input = {
    input: {
      command: "view"
      path: $test_dir
    }
  }

  let result = ($input | edit)

  # Check if output lists both the test file and subdirectory
  assert str contains $result "test.txt" "Should list the test file"
  assert str contains $result "subdir" "Should list the subdirectory"
}

def main [] {
  print "Running view command tests..."

  # Setup test environment
  let test_dir = (setup)
  print $"Created temporary test directory: ($test_dir)"

  # Run tests
  test_view_file $test_dir
  test_view_directory $test_dir

  print "All tests completed successfully!"
}
