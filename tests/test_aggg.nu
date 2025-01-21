use std assert

use ../aggg.nu

def parse-response [name: string] {
  let name = $env.FILE_PWD | path join $name
  let got = cat ($name + ".sse") | aggg
  let want = open ($name + "-expected.json")
  assert ($got == $want)
}

def main [] {
  parse-response "resp-anthropic-tool_use"
  parse-response "resp-anthropic-end_turn"
}
