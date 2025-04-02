# gpt.nu

A Nushell module for interacting with various Large Language Model providers.
This module provides a unified interface for making calls to different LLM APIs,
handling streaming responses, and managing provider configurations.

## Features

- Unified interface for multiple LLM providers
- Current providers: OpenAI, Anthropic, Cerebras, Gemini (@eggcaker 🙏)
- Streaming responses support
- Easy provider configuration and switching
- [Easy to add new providers](#adding-a-new-provider)

Here is an example of what we are attempting to accomplish. This page will help
you turn the following pseudo-code pipeline into a functioning example (TBD):

```nu
collect documents to discuss | inject system prompt | inject RAG results | inject episodic memory | gpt call | analyze results
```

## Installation

1. Install [Nushell](https://www.nushell.sh)
2. Clone this repository
3. Source the module in your Nushell config:

```nu
use path/to/gpt.nu *
```

## Basic Usage

First, select your provider and model interactively:

```nu
> gpt select-provider
Select a provider:
> openai
> anthropic
> cerebras
> gemini

Selected provider: openai

Required API key: $env.OPENAI_API_KEY = "..."
If you like, I can set it for you. Paste key: sk-...
key set 👍

Select model:
> gpt-4-turbo-preview
> gpt-4
> gpt-3.5-turbo

Selected model: gpt-4
```

Now you can make calls to your chosen LLM:

```nu
# Start with a system prompt
> [{
    role: "system"
    content: "You are a direct assistant. Provide concise answers without elaboration or follow-up questions."
  },
  {
    role: "user"
    content: "What's 2 + 2?"
  }] | gpt call
4
```

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
# Load a system prompt and add a user message
open system-prompts/coding-assistant.nuon | append {
    role: "user"
    content: "Write a function that calculates the Fibonacci sequence"
} | gpt call
```

## Response Streaming

By default, `gpt call` sends its complete response through the Nushell pipeline:

```nu
> [{role: "user" content: "Explain streams"}] | gpt call | save response.txt  # Works silently
```

Use the optional `--streamer` flag to monitor the response while it's being
generated:

```nu
> [{role: "user" content: "Explain streams"}] | gpt call --streamer {|| print -n $in} | save response.txt
This is the response being printed... # Shown in real-time
While also saving the complete response to response.txt
```

The streamer closure is called with small snippets of the response, as they are
generated, and can present them however you like. In this example we're just
printing to the terminal.

## Command Reference

### `gpt call`

Make a call to the configured LLM provider.

```nu
# Input type: list<record<role: string, content: string>>
# Output type: string
```

### `gpt select-provider`

Interactively select a provider and model. Will prompt for API key if not set.

### `gpt models`

List available models for the current provider.

```nu
# Output type: table<id: string, created: datetime>
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
