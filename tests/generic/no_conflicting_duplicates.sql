{#-
    Fails (or warns) when the same key appears with different content.

    Exact duplicates are ignored: they are removed silently in staging.
    Rows sharing a key but differing in any column are returned, because they
    need a resolution rule (latest updated_at wins) or cannot be resolved at all.
-#}
{% test no_conflicting_duplicates(model, column_name) %}

with distinct_rows as (
    select distinct * from {{ model }}
)

select
    {{ column_name }} as conflicting_key,
    count(*) as distinct_versions
from distinct_rows
group by {{ column_name }}
having count(*) > 1

{% endtest %}
