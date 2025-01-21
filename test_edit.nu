use std assert
use edit.nu

# Create a temporary test directory
def setup [] {
  let test_dir = (mktemp -d)

  # Create test files with multiple lines for range testing
  "Line 1\nLine 2\nLine 3\nLine 4" | save $"($test_dir)/test.txt"
  mkdir $"($test_dir)/subdir"
  "subdir content" | save $"($test_dir)/subdir/file.txt"

  # Return the test directory path for tests to use
  $test_dir
}

# Test viewing a file that exists
def test_view_file [test_dir: string] {
  let input = {
    input: {
      command: "view"
      path: $"($test_dir)/test.txt"
    }
  }

  let result = ($input | edit)

  assert (($result | str contains "Line 1")) "Output should contain file content"
  assert (($result | str contains "1")) "Output should contain line numbers"
}

# Test viewing a directory
def test_view_directory [test_dir: string] {
  let input = {
    input: {
      command: "view"
      path: $test_dir
    }
  }

  let result = ($input | edit)

  assert (($result | str contains "test.txt")) "Should list the test file"
  assert (($result | str contains "subdir")) "Should list the subdirectory"
}

# Test viewing a file with a specific range
def test_view_file_with_range [test_dir: string] {
  let input = {
    input: {
      command: "view"
      path: $"($test_dir)/test.txt"
      view_range: [2 3]
    }
  }

  let result = ($input | edit)

  assert (($result | str contains "Line 2")) "Should contain content from line 2"
  assert (($result | str contains "Line 3")) "Should contain content from line 3"
  assert (not ($result | str contains "Line 1")) "Should not contain content from line 1"
  assert (not ($result | str contains "Line 4")) "Should not contain content from line 4"
}

# Test viewing a file with an invalid range
def test_view_file_invalid_range [test_dir: string] {
  let input = {
    input: {
      command: "view"
      path: $"($test_dir)/test.txt"
      view_range: [3 2] # end before start
    }
  }

  let error = (do {$input | edit} | complete)

  assert ($error.exit_code != 0) "Should fail with invalid range"
  assert (($error.stderr | str contains "Invalid `view_range`")) "Should indicate invalid range in error"
}

# Test viewing a non-existent file
def test_view_nonexistent_file [test_dir: string] {
  let input = {
    input: {
      command: "view"
      path: $"($test_dir)/nonexistent.txt"
    }
  }

  let error = (do {$input | edit} | complete)

  assert ($error.exit_code != 0) "Should fail with nonexistent file"
  assert (($error.stderr | str contains "does not exist")) "Should indicate file does not exist"
}

# Test viewing a directory with view_range (should error)
def test_view_directory_with_range [test_dir: string] {
  let input = {
    input: {
      command: "view"
      path: $test_dir
      view_range: [1 2]
    }
  }

  let error = (do {$input | edit} | complete)

  assert ($error.exit_code != 0) "Should fail when viewing directory with range"
  assert (($error.stderr | str contains "view_range` parameter is not allowed")) "Should indicate view_range not allowed for directories"
}

def main [] {
  print "Running view command tests..."

  # Setup test environment
  let test_dir = (setup)
  print $"Created temporary test directory: ($test_dir)"

  # Run tests
  test_view_file $test_dir
  test_view_directory $test_dir
  test_view_file_with_range $test_dir
  test_view_file_invalid_range $test_dir
  test_view_nonexistent_file $test_dir
  test_view_directory_with_range $test_dir

  print "All tests completed successfully!"
}
