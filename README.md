# Data Engineering Case Study: E-Commerce Order Analytics

## Overview

Welcome to our data engineering case study! This project simulates a real-world scenario where you'll analyze e-commerce order data and customer behavior using DBT (Data Build Tool) and PostgreSQL.

## Business Context

You're working for an e-commerce platform that wants to understand their order fulfillment process and customer behavior. The platform tracks:

1. **Customer Management** - Customer profiles with subscription tiers (free, premium, enterprise)
2. **Product Catalog** - Products across various categories (Electronics, Home & Garden, Clothing, Books, Toys)
3. **Order Processing** - Order lifecycle from creation through fulfillment
4. **Shipping Operations** - Multiple shipping companies and delivery tracking
5. **Business Intelligence** - Analytics to optimize operations and customer experience

## Your Task

As a data engineer, you need to:

1. **Set up the data pipeline** using DBT to transform raw data into analysis-ready tables
2. **Model the order lifecycle** to track orders through each stage (created → payment → fulfilled)
3. **Build dimensional models** for customers, products, and shipping companies
4. **Calculate key metrics** like order conversion rates, customer lifetime value, and shipping performance

## Data Sources

The project includes 4 CSV files representing different data sources:

- `customers.csv` - Customer subscription events and profile changes over time
- `orders.csv` - Order lifecycle events from creation to fulfillment (including dropoffs)
- `products.csv` - Product catalog with pricing and categories  
- `shipping_company.csv` - Shipping company reference data

## Getting Started

### Prerequisites
- [Docker](https://www.docker.com/get-started) and [Docker Compose](https://docs.docker.com/compose/install/)
- [Make](https://www.gnu.org/software/make/) (usually pre-installed on macOS and Linux; for Windows, see [installation guide](https://gnuwin32.sourceforge.net/packages/make.htm))

### Setup Instructions

1. **Start and enter the DBT container:**
   ```bash
   make shell
   ```
2. **Inside the container, initialize DBT:**
   ```bash
   dbt run
   dbt test
   ...
   ```

### Cleaning up
   ```bash
   make clean
   ```
Will bring down the docker containers and clean the dbt project.

## Expected Deliverables

1. **Staging Models** - Clean and standardize raw data sources
2. **Dimensional Models** - Create fact and dimension tables for order analytics
3. **Order Funnel Analysis** - Analyze order conversion rates and dropoff points
4. **Analysis** - Insights and recommendations based on the data

## Key Analytics Questions to Answer

- What are the conversion rates from order creation to fulfillment?
- Which product categories have the highest order volumes?
- How do different subscription tiers (free, premium, enterprise) impact customer behavior?
- What are the main dropoff points in the order process?


## Questions?

If you have any questions about the requirements or need clarification on the business context, please don't hesitate to ask.

Good luck! 🚀
