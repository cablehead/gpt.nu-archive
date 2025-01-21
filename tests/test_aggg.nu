use std assert

use ../aggg.nu

def parse-response [name: string $dry: bool] {
  let name = $env.FILE_PWD | path join $name
  let got = cat ($name + ".sse") | aggg
  let want = open ($name + "-expected.json")
  if $dry { return [ $got $want ] }
  assert ($got == $want)
}

def main [--dry] {
  parse-response "resp-anthropic-tool_use" $dry
  parse-response "resp-anthropic-end_turn" $dry
}
