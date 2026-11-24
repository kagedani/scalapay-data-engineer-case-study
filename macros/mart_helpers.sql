{#-
    Shared building blocks of the marts, written in one place so every mart
    uses the same definitions.
-#}

{#- Joins each order to the subscription period valid when it was created
    (point-in-time tier). Periods are half-open [valid_from, valid_to), so exactly
    one period matches (checked by assert_orders_match_one_subscription_period). -#}
{% macro join_subscription_at_order_time(orders_alias, subscriptions_alias, join_type='inner') -%}
    {{ join_type }} join {{ ref('dim_customer_subscriptions') }} as {{ subscriptions_alias }}
        on {{ orders_alias }}.customer_id = {{ subscriptions_alias }}.customer_id
        and {{ orders_alias }}.created_at >= {{ subscriptions_alias }}.valid_from
        and {{ orders_alias }}.created_at < {{ subscriptions_alias }}.valid_to
{%- endmacro %}

{#- Observation window of the analysis: from the first to the last order creation
    in the data. Returns one row (window_start, window_end). -#}
{% macro observation_window() -%}
    select
        min(created_at) as window_start,
        max(created_at) as window_end
    from {{ ref('fct_orders') }}
{%- endmacro %}

{#- Order of the subscription tiers (var subscription_tiers, lowest first), to tell
    an upgrade from a downgrade. -#}
{% macro tier_rank(column) -%}
    case {{ column }}
        {%- for tier in var('subscription_tiers') %} when '{{ tier }}' then {{ loop.index }}{% endfor %} end
{%- endmacro %}

{#- GMV: current product price summed over the orders with the given outcome
    ('fulfilled' = GMV, 'dropped' = lost GMV). `condition` narrows the orders
    further (e.g. one dropoff reason). Null when no order matches. -#}
{% macro gmv(outcome='fulfilled', price='products.price', order_outcome='orders.order_outcome', condition=none) -%}
    sum({{ price }}) filter (where {{ order_outcome }} = '{{ outcome }}'{% if condition %} and ({{ condition }}){% endif %})
{%- endmacro %}

{#- Ratio rounded to `scale` decimals; null when the denominator is zero. -#}
{% macro safe_ratio(numerator, denominator, scale=4) -%}
    round(({{ numerator }})::numeric / nullif({{ denominator }}, 0), {{ scale }})
{%- endmacro %}

{#- A quantity normalised to a 30-day exposure, so periods of different length compare. -#}
{% macro per_30_days(quantity, exposure_days, scale) -%}
    {{ safe_ratio(quantity ~ ' * 30', exposure_days, scale) }}
{%- endmacro %}
