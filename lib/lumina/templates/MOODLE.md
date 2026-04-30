# 🧩 Moodle Plugin Development Rules

> **Target Version:** Moodle {{MOODLE_VERSION}} | **Path:** {{MOODLE_PATH}}

---

## Development Environment

- **Moodle Version:** {{MOODLE_VERSION}}
- **Installation Path:** {{MOODLE_PATH}}
- **MCP Server:** `moodle-dev-mcp` is configured and indices have been generated.

## moodle-dev-mcp — Usage Guide

Always load the plugin context before starting work:

```text
Load context for plugin local_myplugin.
```

### Available Tools
- `get_plugin_info`: Loads the complete plugin context into the current session.
- `search_api`: Searches for Moodle core API functions.
- `generate_plugin_context`: Generates `PLUGIN_*.md` documentation files for a plugin.
- `update_indexes`: Regenerates global indices after installing new plugins.
- `doctor`: Runs health checks on the `moodle-dev-mcp` environment.

### Recommended Workflow
1. **Initialize:** Load context using `get_plugin_info` before working on a plugin.
2. **Research:** Use `search_api` before suggesting or implementing core functions.
3. **Document:** Run `generate_plugin_context` after significant code changes.
4. **Sync:** Execute `update_indexes` whenever new plugins are added to the environment.

---

## Target Moodle Version

This project targets **Moodle {{MOODLE_VERSION}}+** (`requires = {{MOODLE_FULLVERSION}}`).

- Use only APIs compatible with Moodle {{MOODLE_VERSION}} or later.
- **Strictly avoid** functions deprecated in previous versions.
- **Note:** Hook API is **NOT** available in this version—use `lib.php` callbacks instead.

---

## Required Files

Every plugin must include these files at a minimum:

```text
version.php
lang/en/[component].php
db/install.xml
db/access.php
```

### Optional (Recommended)
`settings.php`, `lib.php`, `index.php`, `classes/`, `templates/`, `amd/src/`, `tests/`, `tests/behat/`.

---

## File Standards & Examples

### version.php
```php
defined('MOODLE_INTERNAL') || die();

$plugin->component = 'local_example';
$plugin->version   = 2025010100;
$plugin->requires  = 2022112800; // Matches {{MOODLE_FULLVERSION}}
$plugin->maturity  = MATURITY_STABLE;
$plugin->release   = '1.0';
```

### Language File
**Path:** `lang/en/local_example.php`
```php
defined('MOODLE_INTERNAL') || die();

$string['pluginname'] = 'Example Plugin';
```
> **Rule:** All user-facing strings must be defined here. Never hardcode strings in PHP or Mustache templates.

### db/install.xml
- Tables must use the Moodle prefix (handled by XMLDB).
- Every table **must** have a primary key.
- Define indexes for columns used in `WHERE` or `JOIN` clauses.
- Supported types: `INT`, `CHAR`, `TEXT`, `NUMBER`, `FLOAT`.

---

## PHP Namespaces & Architecture

All classes must use the plugin namespace. File paths must match namespaces under the `classes/` directory.

### Recommended Architecture
- `classes/service/`: Business logic.
- `classes/repository/`: Database abstraction/access.
- `classes/output/`: Rendering logic (renderers and renderables).
- `classes/external/`: Web service endpoints (External functions).
- `classes/task/`: Scheduled and ad-hoc tasks.
- `classes/event/`: Event definitions.
- `db/events.php`: Event observers.
- `templates/`: Mustache templates.
- `amd/src/`: Asynchronous Module Definition (JS).

---

## ⚠️ Common Mistakes (Anti-Patterns)

| Action | ❌ Wrong Way | ✅ Correct Way |
| :--- | :--- | :--- |
| **HTML Output** | `echo "<div>Hello</div>";` | `$output->render_from_template(...)` |
| **Request Vars** | `$id = $_POST['id'];` | `$id = required_param('id', PARAM_INT);` |
| **URLs** | `echo '/local/plugin/index.php';` | `new moodle_url('/local/plugin/index.php')` |
| **DB Queries** | `mysqli_query(...);` | `$DB->get_records('table', [...]);` |
| **Security** | Skipping checks | `require_login(); require_capability();` |

### JavaScript Injection
**Never use inline `<script>` tags.**
1. Define logic in `amd/src/module_name.js`.
2. Load via Mustache:
```mustache
{{#js}}
require(['local_example/module_name'], function(mod) {
    mod.init();
});
{{/js}}
```

---

## Global Context Guidelines
- **Always** use the global `$DB` object.
- SQL tables in custom queries must use `{bracket_format}`.
- Follow **Moodle Coding Style** (based on PSR-12).
- **Exclude from indexing:** `.git`, `node_modules`, `vendor`, `.grunt`, `moodledata`, `cache`.