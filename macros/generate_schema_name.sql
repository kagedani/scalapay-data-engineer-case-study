{#-
    Override of dbt's default schema naming.

    dbt's default concatenates the target schema and the custom schema
    (e.g. `public_staging`). This project uses one fixed schema per layer,
    so a node with `+schema: staging` lands in `staging`, not `public_staging`.
    Nodes without a custom schema fall back to the target schema.

    Trade-off: developers sharing one database would overwrite each other's
    layers. In a multi-developer setup, keep the prefix for non-prod targets
    (e.g. branch on `target.name`).
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
