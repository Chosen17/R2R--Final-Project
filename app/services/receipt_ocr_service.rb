# ReceiptOcrService
# This service handles the full OCR pipeline for a receipt image.
# It takes the path to an uploaded image, preprocesses it to improve
# accuracy, runs Tesseract OCR to extract text, then uses pattern
# matching to find the bill total. If Tesseract is not confident
# enough, a cloud OCR fallback can be added here.
class ReceiptOcrService
  # Store the image path when the service is created
  def initialize(image_path)
    @image_path = image_path
  end

  # Main entry point — called from the TransactionsController.
  # Runs the full pipeline and returns the bill total as a BigDecimal,
  # or nil if no total could be found.
  def call
    # Step 1: preprocess the image (greyscale, contrast, deskew)
    preprocessed = preprocess

    # Step 2: extract raw text from the preprocessed image using Tesseract
    text = extract_text(preprocessed)

    # Step 3: search the extracted text for a bill total using regex
    total = parse_total(text)

    # Step 4: if Tesseract could not find a total, try the cloud fallback
    total = cloud_fallback if total.nil?

    total

  ensure
    # Always delete the temporary preprocessed image file when done,
    # even if an error occurred — we do not want to store receipt images
    File.delete(preprocessed) if preprocessed && File.exist?(preprocessed)
  end

  private

  # Preprocesses the receipt image to improve OCR accuracy.
  # Thermal receipts in particular benefit from greyscale conversion
  # and contrast enhancement, which makes faded text more readable.
  def preprocess
    output_path = "#{@image_path}_processed.png"

    image = MiniMagick::Image.open(@image_path)

    # Convert to greyscale — removes colour noise that confuses Tesseract
    image.colorspace "Gray"

    # Enhance contrast — makes text stand out against the background
    image.contrast

    # Deskew — corrects slight rotation in photographed receipts
    image.deskew "40%"

    # Save the processed image to a new temporary file
    image.write output_path

    output_path
  end

  # Runs Tesseract OCR on the preprocessed image and returns the
  # extracted text as a plain string.
  # --oem 1 = use the LSTM neural network engine (most accurate)
  # --psm 6 = treat the image as a single uniform block of text
  def extract_text(image_path)
    RTesseract.new(image_path, lang: "eng", psm: 6).to_s
  rescue => e
    # If Tesseract fails for any reason, log the error and return
    # an empty string so the pipeline continues gracefully
    Rails.logger.error "Tesseract OCR error: #{e.message}"
    ""
  end

  # Searches the extracted OCR text for a bill total using a series
  # of regular expression patterns targeting common UK receipt formats.
  # Returns the total as a BigDecimal for precise currency arithmetic,
  # or nil if no match is found.
  def parse_total(text)
    patterns = [
      # Pattern 1: "TOTAL" or "AMOUNT DUE" followed by digits with a decimal
      /(?:total|amount due|balance due|total due|amount payable)[^\d]*(\d+\.\d{2})/i,

      # Pattern 2: same labels but with a £ sign before the amount
      /(?:total|amount due|balance due)[^\d]*£\s*(\d+\.\d{2})/i,

      # Pattern 3: fallback — any £ amount at the end of a line
      # (catches receipts with unusual formatting)
      /£\s*(\d+\.\d{2})\s*$/
    ]

    # Try each pattern in order — return the first match found
    patterns.each do |pattern|
      match = text.match(pattern)
      return BigDecimal(match[1]) if match
    end

    # No pattern matched — return nil so the controller can handle it
    nil
  end

  # Placeholder for cloud OCR fallback (Google Cloud Vision).
  # This would be called when Tesseract confidence is too low.
  # For the prototype, we log a warning and return nil.
  # In a production system this would submit the image to the
  # Google Cloud Vision API and return the extracted total.
  def cloud_fallback
    Rails.logger.warn "Tesseract could not find a total — cloud OCR fallback not yet implemented"
    nil
  end
end
