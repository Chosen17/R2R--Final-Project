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

ActiveRecord::Schema[8.0].define(version: 2026_04_22_122854) do
  create_table "customers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "phone_number"
    t.string "name"
    t.decimal "cashback_balance", precision: 8, scale: 2
    t.string "conversation_state"
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_number"], name: "index_customers_on_phone_number", unique: true
  end

  create_table "qr_tokens", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "qr_transaction_id", null: false
    t.string "token"
    t.datetime "expires_at"
    t.boolean "used"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "qr_png_base64"
    t.index ["qr_transaction_id"], name: "index_qr_tokens_on_qr_transaction_id"
    t.index ["token"], name: "index_qr_tokens_on_token", unique: true
  end

  create_table "transactions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id"
    t.string "receipt_hash"
    t.decimal "bill_total", precision: 8, scale: 2
    t.decimal "cashback_amount", precision: 8, scale: 2
    t.boolean "redeemed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_transactions_on_customer_id"
    t.index ["receipt_hash"], name: "index_transactions_on_receipt_hash", unique: true
  end

  add_foreign_key "qr_tokens", "transactions", column: "qr_transaction_id"
  add_foreign_key "transactions", "customers"
end
