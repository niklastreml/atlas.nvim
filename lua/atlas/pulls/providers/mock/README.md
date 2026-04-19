# Atlas Mock Provider

The Mock provider is the zero-setup sandbox for Atlas.

## Run It

Open Atlas directly with the mock provider:

```vim
:AtlasPulls mock
```

Or configure it as default in your setup:

```lua
require("atlas").setup({
  pulls = {
    providers = {
      mock = {},
    },
  },
})
```
