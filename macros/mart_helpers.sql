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

{#- Order of the subscription tiers, to tell an upgrade from a downgrade. -#}
{% macro tier_rank(column) -%}
    case {{ column }} when 'free' then 1 when 'premium' then 2 when 'enterprise' then 3 end
{%- endmacro %}
