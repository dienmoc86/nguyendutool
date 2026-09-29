# SQLite Database Schema Specification

Database File: `ischool_tools.db`  
Storage Location: `<WorkspaceRoot>/projects/ischool_tools.db`  
Engine: SQLite 3 via `sqflite_common_ffi`

---

## 1. Table: `app_settings`
Stores persistent user preferences, UI options, and system parameters.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `key` | `TEXT` | `PRIMARY KEY` | Setting identifier (e.g., `theme_mode`, `language`, `developer_mode`) |
| `value` | `TEXT` | `NOT NULL` | Stored value string or serialized flag |
| `updated_at` | `TEXT` | `NOT NULL` | ISO 8601 timestamp of last update |

---

## 2. Table: `projects`
Groups processed files and jobs into logical workspaces or task batches.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `TEXT` | `PRIMARY KEY` | UUID v4 project identifier |
| `name` | `TEXT` | `NOT NULL` | Human-readable project name |
| `module_type` | `TEXT` | `NOT NULL` | Target module identifier |
| `created_at` | `TEXT` | `NOT NULL` | ISO 8601 creation timestamp |
| `updated_at` | `TEXT` | `NOT NULL` | ISO 8601 last modified timestamp |

---

## 3. Table: `files`
Tracks documents, raw inputs, and exported assets stored in the local workspace.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `TEXT` | `PRIMARY KEY` | UUID v4 file record identifier |
| `project_id` | `TEXT` | `NULLABLE, FK -> projects(id)` | Associated project |
| `original_name` | `TEXT` | `NOT NULL` | Original filename with extension |
| `local_path` | `TEXT` | `NOT NULL` | Absolute normalized filesystem path |
| `mime_type` | `TEXT` | `NULLABLE` | MIME type (e.g., `application/pdf`, `audio/mpeg`) |
| `size` | `INTEGER` | `NOT NULL` | File size in bytes |
| `created_at` | `TEXT` | `NOT NULL` | ISO 8601 creation timestamp |

---

## 4. Table: `jobs`
Maintains records and live statuses of background and foreground asynchronous tasks.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `TEXT` | `PRIMARY KEY` | UUID v4 job identifier |
| `job_type` | `TEXT` | `NOT NULL` | `pdfConvert`, `ocr`, `scanProcess`, `ttsGenerate`, `videoRender` |
| `module_type` | `TEXT` | `NOT NULL` | Name of the triggering feature module |
| `status` | `TEXT` | `NOT NULL` | `queued`, `running`, `completed`, `failed`, `cancelled` |
| `progress` | `REAL` | `NOT NULL DEFAULT 0.0` | Fractional progress from 0.0 to 1.0 |
| `input_json` | `TEXT` | `NULLABLE` | Serialized JSON parameters for the task |
| `output_json` | `TEXT` | `NULLABLE` | Serialized JSON result payloads |
| `error_message` | `TEXT` | `NULLABLE` | Human or technical error reason |
| `created_at` | `TEXT` | `NOT NULL` | ISO 8601 creation timestamp |
| `started_at` | `TEXT` | `NULLABLE` | ISO 8601 processing start timestamp |
| `finished_at` | `TEXT` | `NULLABLE` | ISO 8601 termination timestamp |

---

## 5. Table: `providers`
Records configuration and activation state of external and local engines.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `TEXT` | `PRIMARY KEY` | Provider ID (e.g., `gemini`, `google_tts`, `windows_ocr`) |
| `provider_type` | `TEXT` | `NOT NULL` | `ai`, `tts`, `video`, `ocr` |
| `provider_name` | `TEXT` | `NOT NULL` | Display name of the provider |
| `is_enabled` | `INTEGER` | `NOT NULL DEFAULT 1` | 1 if active, 0 if disabled |
| `config_json` | `TEXT` | `NULLABLE` | Non-sensitive configurations |
| `created_at` | `TEXT` | `NOT NULL` | ISO 8601 creation timestamp |
| `updated_at` | `TEXT` | `NOT NULL` | ISO 8601 update timestamp |

> [!IMPORTANT]
> API keys, access tokens, and sensitive secrets are strictly prohibited from being saved in `config_json` or anywhere in plaintext SQLite. Such credentials pass through the `ISecureStorage` abstraction.
