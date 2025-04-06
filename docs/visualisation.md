# Visualisation

Operations tasks can be visualized as flowcharts using the built-in SVG exporter. This helps you understand the flow of your operations and can be useful for documentation.

```ruby
# Export a task to SVG
exporter = Operations::Exporters::SVG.new(MyTask)

# Save as SVG
exporter.save("my_task_flow.svg")

# Get SVG content directly
svg_string = exporter.to_svg
```

### Custom Condition Labels

By default, condition transitions in the visualization are labeled based on the state they lead to. For more clarity, you can provide custom labels when defining conditions:

```ruby
wait_until :document_status do
  condition(:ready_for_download, label: "Document processed successfully") { document.processed? }
  condition(:processing_failed, label: "Processing error occurred") { document.error? }
end

decision :user_access_level do
  condition(:allow_full_access, label: "User is an admin") { user.admin? }
  condition(:provide_limited_access, label: "User is a regular member") { user.member? }
  condition(:deny_access, label: "User has no permissions") { !user.member? }
end
```

The visualization includes:
- Color-coded nodes by state type (decisions, actions, wait states, results)
- Transition conditions between states with custom labels when provided
- Special handling for custom transition blocks
