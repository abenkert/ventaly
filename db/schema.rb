# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_01_10_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ebay_listings", force: :cascade do |t|
    t.string "ebay_item_id", null: false
    t.string "title"
    t.text "description"
    t.decimal "sale_price", precision: 10, scale: 2
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "shopify_ebay_account_id", null: false
    t.decimal "original_price", precision: 10, scale: 2
    t.string "shipping_profile_id"
    t.string "location"
    t.jsonb "image_urls", default: []
    t.string "listing_format"
    t.string "condition_id"
    t.string "condition_description"
    t.string "category_id"
    t.jsonb "item_specifics", default: {}
    t.string "listing_duration"
    t.datetime "end_time"
    t.boolean "best_offer_enabled", default: false
    t.string "ebay_status"
    t.datetime "last_sync_at"
    t.index ["shopify_ebay_account_id"], name: "index_ebay_listings_on_shopify_ebay_account_id"
  end

  create_table "kuralis_products", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.text "description_html"
    t.decimal "base_price", precision: 10, scale: 2
    t.integer "base_quantity", default: 0
    t.string "sku"
    t.string "brand"
    t.string "condition"
    t.string "location"
    t.jsonb "images", default: []
    t.jsonb "attributes", default: {}
    t.bigint "shop_id", null: false
    t.bigint "shopify_product_id"
    t.bigint "ebay_listing_id"
    t.string "source_platform"
    t.datetime "last_synced_at"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ebay_listing_id"], name: "index_kuralis_products_on_ebay_listing_id"
    t.index ["shop_id"], name: "index_kuralis_products_on_shop_id"
    t.index ["shopify_product_id"], name: "index_kuralis_products_on_shopify_product_id"
    t.index ["sku"], name: "index_kuralis_products_on_sku"
    t.index ["source_platform"], name: "index_kuralis_products_on_source_platform"
    t.index ["status"], name: "index_kuralis_products_on_status"
  end

  create_table "shopify_ebay_accounts", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "access_token_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "refresh_token_expires_at"
    t.datetime "last_listing_import_at"
    t.index ["shop_id"], name: "index_shopify_ebay_accounts_on_shop_id"
  end

  create_table "shopify_products", force: :cascade do |t|
    t.string "shopify_product_id", null: false
    t.string "shopify_variant_id", null: false
    t.decimal "price", precision: 10, scale: 2
    t.integer "quantity"
    t.string "sku"
    t.string "inventory_location"
    t.string "status", default: "active"
    t.boolean "published", default: true
    t.string "title"
    t.string "description"
    t.string "handle"
    t.string "product_type"
    t.string "vendor"
    t.jsonb "tags"
    t.jsonb "options"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shopify_product_id"], name: "index_shopify_products_on_shopify_product_id", unique: true
    t.index ["shopify_variant_id"], name: "index_shopify_products_on_shopify_variant_id"
    t.index ["status"], name: "index_shopify_products_on_status"
  end

  create_table "shops", force: :cascade do |t|
    t.string "shopify_domain", null: false
    t.string "shopify_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_scopes", default: "", null: false
    t.index ["shopify_domain"], name: "index_shops_on_shopify_domain", unique: true
  end

  add_foreign_key "ebay_listings", "shopify_ebay_accounts"
  add_foreign_key "kuralis_products", "ebay_listings"
  add_foreign_key "kuralis_products", "shopify_products"
  add_foreign_key "kuralis_products", "shops"
  add_foreign_key "shopify_ebay_accounts", "shops"
end
