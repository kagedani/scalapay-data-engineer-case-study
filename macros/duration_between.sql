{#- Time from start_ts to end_ts in the given unit ('hour' or 'day'), 2 decimals.
    On Postgres 13 extract(epoch ...) returns double precision: cast to numeric
    before rounding. Null when either timestamp is null. -#}
{% macro duration_between(start_ts, end_ts, unit) -%}
    {%- set seconds = {'hour': 3600, 'day': 86400}[unit] -%}
    round((extract(epoch from {{ end_ts }} - {{ start_ts }}) / {{ seconds }})::numeric, 2)
{%- endmacro %}
