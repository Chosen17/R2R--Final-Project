class AddQrPngBase64ToQrTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :qr_tokens, :qr_png_base64, :text
  end
end
