# 🧩 Moodle Plugin Development Rules

## Ambiente de Desenvolvimento

- **Versão do Moodle:** {{MOODLE_VERSION}}
- **Caminho da instalação:** {{MOODLE_PATH}}
- **Servidor MCP:** moodle-dev-mcp está configurado e os índices foram gerados

## moodle-dev-mcp — Como usar

Antes de trabalhar em qualquer plugin, carregue o contexto:

```
Carregue o contexto do plugin local_myplugin.
```

Use as tools disponíveis:

- `get_plugin_info` — carrega o contexto completo de um plugin na sessão
- `search_api` — pesquisa funções da API do core do Moodle
- `generate_plugin_context` — gera os arquivos PLUGIN\_\*.md para um plugin
- `update_indexes` — regenera os índices globais após instalar novos plugins
- `doctor` — verifica a saúde do ambiente moodle-dev-mcp

Fluxo recomendado:

1. Antes de trabalhar em um plugin: carregue o contexto com get_plugin_info
2. Antes de sugerir funções do core: use search_api
3. Após mudanças significativas em um plugin: execute generate_plugin_context
4. Após instalar novos plugins no Moodle: execute update_indexes

---

## Target Moodle Version

This project targets **Moodle {{MOODLE_VERSION}}+** (`requires = {{MOODLE_FULLVERSION}}`).

- Use only APIs available in Moodle {{MOODLE_VERSION}} or later.
- Do not use functions deprecated in previous versions.
- Hook API NÃO disponível nesta versão — use callbacks do lib.php

---

## Required Files

Every plugin must include these files at minimum:

```
version.php
lang/en/[component].php
db/install.xml
db/access.php
```

Optional but recommended:

```
settings.php
lib.php
index.php
classes/
templates/
amd/src/
tests/
tests/behat/
```

---

## version.php

```php
defined('MOODLE_INTERNAL') || die();

$plugin->component = 'local_example';
$plugin->version   = 2025010100;
$plugin->requires  = 2022112800;
$plugin->maturity  = MATURITY_STABLE;
$plugin->release   = '1.0';
```

---

## Language File

Path: `lang/en/local_example.php`

```php
defined('MOODLE_INTERNAL') || die();

$string['pluginname'] = 'Example Plugin';
```

All user-facing strings must be defined here. Never hardcode strings in PHP or templates.

---

## db/install.xml

- All tables must use the Moodle table prefix (handled automatically by XMLDB).
- Every table must define a primary key.
- Define indexes for columns used in WHERE or JOIN clauses.
- Use correct XMLDB field types: `INT`, `CHAR`, `TEXT`, `NUMBER`, `FLOAT`.

---

## db/access.php

All capabilities must be declared in this file.

```php
defined('MOODLE_INTERNAL') || die();

$capabilities = [
    'local/example:view' => [
        'riskbitmask'  => RISK_PERSONAL,
        'captype'      => 'read',
        'contextlevel' => CONTEXT_SYSTEM,
        'archetypes'   => [
            'user'    => CAP_ALLOW,
            'manager' => CAP_ALLOW,
        ],
    ],
];
```

---

## PHP Namespaces

All classes must use the plugin namespace.

```php
namespace local_example\service;
namespace local_example\repository;
namespace local_example\output;
namespace local_example\external;
namespace local_example\task;
namespace local_example\event;
```

File paths must match namespaces under `classes/`.

---

## Recommended Plugin Architecture

```
classes/
  service/        → Business logic
  repository/     → Database access
  output/         → Rendering logic (renderers and renderables)
  external/       → Web service endpoints
  task/           → Scheduled and ad-hoc tasks
  event/          → Event classes
db/
  events.php      → Event observers
templates/        → Mustache templates
amd/src/          → AMD JavaScript modules
tests/            → PHPUnit tests
tests/behat/      → Behat acceptance tests
```

### Entry Point Pattern (index.php)

```php
require_once(__DIR__ . '/../../config.php');

require_login();
require_capability('local/example:view', context_system::instance());

$PAGE->set_url(new moodle_url('/local/example/index.php'));
$PAGE->set_context(context_system::instance());
$PAGE->set_title(get_string('pluginname', 'local_example'));

$service  = new \local_example\service\example_service();
$data     = $service->get_data();

$output   = $PAGE->get_renderer('local_example');
echo $output->header();
echo $output->render_from_template('local_example/main', $data);
echo $output->footer();
```

---

## ⚠️ Common Mistakes — Never Do These

### Do NOT use direct HTML in PHP

```php
// Wrong
echo "<div>Hello</div>";

// Correct
echo $output->render_from_template('local_example/component', $data);
```

### Do NOT access request variables directly

```php
// Wrong
$id = $_POST['id'];

// Correct
$id = required_param('id', PARAM_INT);
$id = optional_param('id', 0, PARAM_INT);
```

### Do NOT hardcode URLs

```php
// Wrong
echo '/local/example/index.php';

// Correct
echo new moodle_url('/local/example/index.php', ['id' => $id]);
```

### Do NOT hardcode language strings

```php
// Wrong
echo "Save";

// Correct
echo get_string('save', 'local_example');
```

### Do NOT query the database directly

```php
// Wrong
mysqli_query(...);

// Correct — always use the $DB API
$records = $DB->get_records('example_table', ['userid' => $userid]);
$DB->insert_record('example_table', $dataobject);
$DB->update_record('example_table', $dataobject);
$DB->delete_records('example_table', ['id' => $id]);
```

### Do NOT bypass authentication and capability checks

```php
// Always include at the top of every page script
require_login();
require_capability('local/example:view', $context);
```

### Do NOT use inline JavaScript

```javascript
// Correct: use AMD modules
// amd/src/example.js
define(["jquery"], function ($) {
    return {
        init: function () {
            /* ... */
        },
    };
});
```

```mustache
{{! Correct: load AMD module from template }}
{{#js}}
require(['local_example/example'], function(mod) {
    mod.init();
});
{{/js}}
```
