# tcr

TUI file manager with tree abstraction written in Crystal.

## Configuration

### Bindings

Currently `tcr` supports only bindings configuration. You can write any shellscript in configuration.
`$tcr_path` variable is available to execute some action on the currently selected path

Example:

```ini
[bindings]
enter = kcr edit $tcr_path
i = kcr open $tcr_path
```
