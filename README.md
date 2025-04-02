# gpt.nu

Integrate LLM providers into Nushell pipelines

```nu
# Define a system prompt and ask a question
[{
  role: "system"
  content: "You are a direct assistant. Provide concise answers without elaboration or follow-up questions."
},
{
  role: "user"
  content: "What's 4 + 4?"
}] | gpt call
```

## Practical Examples

```nu
# Process a file through an LLM
open README.md | str join | wrap content | wrap {role: "user"} | gpt call | save summary.txt

# Stream responses in real-time
[{role: "user", content: "Write a short poem about coding"}] | gpt call --streamer {|| print -n $in}

# Chain with other Nushell commands
[{role: "user", content: "List 5 popular Linux distros"}] | gpt call | lines | where {|line| $line =~ "Ubuntu"}
```

## Features

- Unified interface for multiple LLM providers
- Current providers: OpenAI, Anthropic, Cerebras, Gemini (@eggcaker 🙏)
- Streaming responses support
- Easy provider configuration and switching
- [Easy to add new providers](#adding-a-new-provider)

## Installation

```nu
"https://raw.githubusercontent.com/cablehead/gpt.nu/refs/heads/main/gpt.nu"
| each {|url|
  http get $url
  | save ($url | path basename)
}
use gpt.nu
```

## Getting Started

Before using gpt.nu, you need to select a provider and model:

```nu
gpt select-provider
```

This interactive command will:
1. Let you choose from available providers
2. Prompt for the required API key if not already set
3. Show available models for your chosen provider

After selecting a provider, you can start using the examples shown above.

## Programmatic Provider Configuration

Instead of using the interactive selector, you can configure your provider
directly:

```nu
# As a record
$env.GPT_PROVIDER = {
    name: openai
    model: "gpt-4"
}

# Or as a JSON string
$env.GPT_PROVIDER = '{"name": "openai", "model": "gpt-4"}'
```

You can also set API keys directly:

```nu
$env.OPENAI_API_KEY = "sk-..."
$env.ANTHROPIC_API_KEY = "sk-ant-..."
$env.CEREBRAS_API_KEY = "sk-..."
$env.GEMINI_API_KEY = "..."
```

## Message Format

The `gpt call` command expects a list of message records, where each message has
a `role` and `content` field. There are three possible roles:

- `system`: Sets behavior and constraints for the LLM
- `user`: Contains the user's input
- `assistant`: Contains previous responses from the LLM

You can build message lists using Nushell's append command, which is
particularly useful for loading stored system prompts:

```nu
# You can combine messages from different sources
# First create a system prompt
let system_prompt = {
    role: "system"
    content: "You are a coding assistant specialized in writing clear, efficient code."
}

# Then add a user message and make the call
$system_prompt | append {
    role: "user"
    content: "Write a function that calculates the Fibonacci sequence"
} | gpt call
```

## Response Streaming

The `--streamer` flag lets you process response chunks in real-time while still capturing the complete output:

```nu
[{role: "user", content: "Write a story"}] | gpt call --streamer {|| print -n $in} | save story.txt
```

- Without `--streamer`: Silent operation, output only goes through the pipeline
- With `--streamer`: See the response as it's generated AND capture the full text
- The streamer closure receives text fragments as they arrive from the API

## Command Reference

### `gpt call`

Make a call to the configured LLM provider.

```nu
# Input: list of message records
[{role: "user", content: "Hello"}] | gpt call

# Options:
#   --streamer <closure>: Process chunks in real-time while maintaining pipeline output
```

### `gpt select-provider`

Interactively select a provider and model.

```nu
# No input required
gpt select-provider

# What it does:
# 1. Shows available providers (OpenAI, Anthropic, Cerebras, Gemini)
# 2. Prompts for API key if not already set in environment
# 3. Lists available models for selected provider
# 4. Sets $env.GPT_PROVIDER with your choices
```

### `gpt models`

List available models for the current provider.

```nu
# No input required
gpt models

# Output: Table with model IDs and creation dates
# [
#   {id: "gpt-4", created: 2023-03-14T00:00:00Z},
#   {id: "gpt-3.5-turbo", created: 2022-11-28T00:00:00Z},
#   ...
# ]
```

## Adding a New Provider

To add support for a new LLM provider, implement two functions in the
`GPT_PROVIDERS` environment record:

```nu
$env.GPT_PROVIDERS = {
    example_provider: {
        # List available models
        # Must return table with 'id' and 'created' columns
        models: {||
            [[
                [id, created];
                ["gpt-x", ("2024-01-01" | into datetime)]
                ["gpt-y", ("2023-12-01" | into datetime)]
            ]]
        }

        # Handle LLM calls
        # Input: list<record<role: string, content: string>>
        # Output: streamed response chunks
        call: {|model: string|
            let data = {
                model: $model
                stream: true
                messages: $in
            }

            http post https://api.example.com/v1/chat
            -H { Authorization: $"Bearer ($env.EXAMPLE_API_KEY)" }
            $data
            | lines
            | each {|line| parse_content $line}
        }
    }
}
```

## Contributing

Contributions are welcome! Particularly new provider implementations. Please
feel free to submit a Pull Request.

## License

MIT
