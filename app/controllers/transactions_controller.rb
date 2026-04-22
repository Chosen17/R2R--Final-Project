# TransactionsController
# Handles the staff-facing receipt upload flow.
# The 'new' action shows the upload form.
# The 'create' action processes the uploaded receipt image through
# the OCR pipeline, saves the transaction, and generates a QR code.
class TransactionsController < ApplicationController
  # GET /transactions/new
  # Displays the receipt upload form for restaurant staff
  def new
  end

  # POST /transactions
  # Called when staff submit the upload form with a receipt photo.
  # Runs the OCR pipeline, calculates cashback, saves the transaction,
  # and generates a QR code for the customer to scan.
  def create
    # Check that an image was actually uploaded before processing
    unless params[:receipt_image].present?
      flash[:alert] = "Please select a receipt image."
      return redirect_to new_transaction_path
    end

  def show
    # Here we are loading the transaction and the associated QR token to display to the staff member after they have uploaded the receipt. This is where they will see the QR code that the customer needs to scan.
    @transaction = Transaction.find(params[:id])
    @qr_token = @transaction.qr_token
  end

    # Get the temporary file path of the uploaded image.
    # Rails stores uploaded files as tempfiles automatically.
    image_path = params[:receipt_image].tempfile.path

    # Run the OCR service to extract the bill total from the image.
    # Returns a BigDecimal if successful, or nil if no total was found.
    total = ReceiptOcrService.new(image_path).call

    # adding this line here to see what OCR is actual extracting (this is for test case 1, sorting out an error)
    Rails.logger.debug("OCR extracted total: #{total.inspect}")


    # If OCR could not extract a total, send staff back to try again
    if total.nil?
      flash[:alert] = "Could not read a total from that receipt. Please try a clearer photo."
      return redirect_to new_transaction_path
    end

    # Calculate 10% cashback using BigDecimal arithmetic.
    # We use BigDecimal instead of Float to avoid floating-point
    # rounding errors with currency values (e.g. 0.1 + 0.2 in Float
    # gives 0.30000000000000004, which is wrong for money)
    cashback = (total * BigDecimal("0.10")).round(2)

    # Generate a SHA-256 hash of the total and timestamp.
    # This acts as a unique fingerprint for this receipt to prevent
    # the same receipt being submitted twice (duplicate detection).
    receipt_hash = Digest::SHA256.hexdigest("#{total}-#{Time.now.to_f}")

    # Create the Transaction record in the database
    @transaction = Transaction.new(
      bill_total: total,
      cashback_amount: cashback,
      receipt_hash: receipt_hash,
      redeemed: false
    )

    if @transaction.save
      # Transaction saved successfully — now generate the QR code
      # that the customer will scan to claim their cashback
      @qr_token = QrCodeService.new(@transaction).call
      # this line above was a silent problem this is because it was performing trubo streaming
      # which is a problem because there was no frontend for the staff member to see that the reciept has been processed.
      # So we are going to force a page redirected to the show page where the staff members can see that the reciept has been processed.

      # Render the show view which displays the QR code to staff
      render :show
    else
      # Here we aretrying to see the validation errors that are preventing the transaction from saving (this is for test case 1, sorting out an error)
      Rails.logger.error("Transaction save failed: #{@transaction.errors.full_messages}")
      flash[:alert] = "the transaction could not be saved so saved failed #{@transaction.errors.full_messages.join(", ")}"
      # flash[:alert] = "Something went wrong saving the transaction."
      redirect_to new_transaction_path
    end
  end
end
