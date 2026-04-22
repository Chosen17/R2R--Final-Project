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

# this is the new robust method which caters to more realistic phot conditions
# Preprocesses the receipt image to improve OCR accuracy.
# This pipeline is designed to handle real-world photo conditions
# including uneven lighting, skewed angles, and low contrast typical
# of thermal receipts photographed under restaurant lighting.
def preprocess
  output_path = "#{@image_path}_processed.png"

  image = MiniMagick::Image.open(@image_path)

  # Auto-rotate based on EXIF orientation metadata.
  # Phone photos often have orientation stored as metadata rather than
  # physically rotated pixels, and Tesseract doesn't read EXIF data.
  image.auto_orient

  # Resize large images down — very high resolution photos (>2000px)
  # actually hurt OCR accuracy because Tesseract was trained on
  # images at roughly 300 DPI equivalent
  image.resize "2000x2000>"

  # Convert to greyscale — removes colour noise
  image.colorspace "Gray"

  # Normalise the image's tonal range — stretches the histogram so
  # the darkest pixel becomes pure black and lightest becomes pure
  # white. This handles the uneven lighting problem.
  image.normalize

  # Increase contrast twice for extra effect on faded thermal print
  image.contrast
  image.contrast

  # Sharpen the edges — helps Tesseract distinguish characters
  image.combine_options do |c|
    c.sharpen "0x1.5"
  end

  # Deskew — corrects slight rotation up to 40 degrees
  image.deskew "40%"

  # Save the processed image as output
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
    # This is a debug line which will help us see OCR text to see what tesseract is actually reading
    Rails.logger.debug "=" * 20
    Rails.logger.debug "Actual OCR text:"
    Rails.logger.debug text
    Rails.logger.debug "=" * 60

    # Going to normalise the common OCR errors before pattern matching to improve accuracy.
    # For example, OCR often misreads 'TOTAL' as 'T0TAL' or 'AMOUNT DUE' as 'AM0UNT DUE', so we can fix these common mistakes before searching for the total.
    cleaned_text = text
      .gsub(/[£€$]/i, "£")
      .gsub(/[Oo](?=\d)/, "0")
      .gsub(/[Il|](?=\d)/, "1")


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
