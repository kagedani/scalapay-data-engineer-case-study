{#-
    Timestamp of the current dbt invocation, used for the technical columns
    insert_ts / last_update_ts on star tables.

    run_started_at (UTC) is the same for every model in a run, so all rows
    written by one run share one value, unlike current_timestamp.
-#}
{% macro audit_run_ts() -%}
    '{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S.%f") }}'::timestamp
{%- endmacro %}
