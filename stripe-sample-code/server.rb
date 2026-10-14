require "dotenv"
require "stripe"
require "sinatra"
require "sinatra/json"
require "json"
Dotenv.load

Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
stripe_client = Stripe::StripeClient.new(ENV["STRIPE_SECRET_KEY"])

set :public_folder, File.dirname(__FILE__) + "/public"
enable :sessions

# Create a sample product and return a price for it
post "/api/create-product" do
  data = parse_request_body
  product_name = data['productName']
  product_description = data['productDescription']
  product_price = data['productPrice']
  account_id = data['accountId']

  begin
    # Create the product on the platform
    product = Stripe::Product.create({
      name: product_name,
      description: product_description,
      metadata: { stripe_account: account_id }
    })

    # Create a price for the product on the platform
    price = Stripe::Price.create({
      product: product.id,
      unit_amount: product_price,
      currency: 'usd',
      metadata: { stripe_account: account_id }
    })

    content_type :json
    {
      productName: product_name,
      productDescription: product_description,
      productPrice: product_price,
      priceId: price.id
    }.to_json
  rescue Stripe::StripeError => e
    status 500
    { error: e.message }.to_json
  end
end

# Create a PaymentIntent for native mobile checkout
post "/api/create-payment-intent" do
  data = parse_request_body
  amount = data['amount'] || 5000
  currency = data['currency'] || 'usd'
  account_id = data['accountId']
  flash_title = data['flashTitle'] || 'Flash Artwork Deposit'
  customer_email = data['customerEmail']

  intent_params = {
    amount: amount,
    currency: currency,
    description: "Flash Ink Deposit: #{flash_title}",
    automatic_payment_methods: { enabled: true },
  }

  intent_params[:receipt_email] = customer_email if customer_email && !customer_email.empty?

  if account_id && !account_id.empty?
    intent_params[:transfer_data] = {
      destination: account_id,
    }
  end

  begin
    intent = Stripe::PaymentIntent.create(intent_params)
    content_type :json
    {
      clientSecret: intent.client_secret,
      id: intent.id,
    }.to_json
  rescue Stripe::StripeError => e
    status 500
    { error: e.message }.to_json
  end
end

# Create a Connected Account
post "/api/create-connect-account" do
  data = parse_request_body

  begin
    account = stripe_client.v2.core.accounts.create({
      display_name: data['email'],
      contact_email: data['email'],
      dashboard: 'express',
      defaults: {
        responsibilities: {
          fees_collector: 'application',
          losses_collector: 'application',
        },
      },
      identity: {
        country: 'US',
        entity_type: 'company',
      },
      configuration: {
        recipient: {
          capabilities: {
            stripe_balance: {
              stripe_transfers: { requested: true },
            },
          },
        },
      },
    })

    content_type :json
    { accountId: account.id }.to_json
  rescue Stripe::StripeError => e
    status 500
    { error: e.message }.to_json
  end
end

# Create Account Link for onboarding
post "/api/create-account-link" do
  data = parse_request_body
  account_id = data['accountId']

  begin
    account_link = stripe_client.v2.core.account_links.create({
      account: account_id,
      use_case: {
        type: 'account_onboarding',
        account_onboarding: {
          configurations: ['recipient'],
          refresh_url: 'https://example.com',
          return_url: "https://example.com?accountId=#{account_id}",
        },
      },
    })

    content_type :json
    { url: account_link.url }.to_json
  rescue Stripe::StripeError => e
    status 500
    { error: e.message }.to_json
  end
end

# Get Connected Account Status
get "/api/account-status/:account_id" do
  account_id = params[:account_id]

  begin
    account = stripe_client.v2.core.accounts.retrieve(account_id, {
      include: ['requirements', 'configuration.recipient'],
    })

    payouts_enabled = account.configuration&.recipient&.capabilities&.stripe_balance&.payouts&.status == 'active'
    charges_enabled = account.configuration&.recipient&.capabilities&.stripe_balance&.stripe_transfers&.status == 'active'
    summary_status = account.requirements&.summary&.minimum_deadline&.status
    details_submitted = summary_status.nil? || summary_status == 'eventually_due'

    content_type :json
    {
      id: account.id,
      payoutsEnabled: payouts_enabled,
      chargesEnabled: charges_enabled,
      detailsSubmitted: details_submitted,
      requirements: account.requirements&.entries,
    }.to_json
  rescue Stripe::StripeError => e
    status 500
    { error: e.message }.to_json
  end
end

# Fetch products for a specific account
get "/api/products/:account_id" do
  account_id = params[:account_id]

  begin
    prices = Stripe::Price.search({
      query: "metadata['stripeAccount']:'#{account_id}' AND active:'true'",
      expand: ['data.product'],
      limit: 100,
    })

    products = prices.data.map do |price|
      {
        id: price.product.id,
        name: price.product.name,
        description: price.product.description,
        price: price.unit_amount,
        priceId: price.id,
        image: 'https://i.imgur.com/6Mvijcm.png'
      }
    end

    content_type :json
    products.to_json
  rescue Stripe::StripeError => e
    status 500
    { error: e.message }.to_json
  end
end

# Create checkout session
post "/api/create-checkout-session" do
  data = parse_request_body
  price_id = data['priceId']
  account_id = data['accountId']

  # Get the price's type from Stripe
  price = Stripe::Price.retrieve(price_id)
  price_type = price.type
  mode = price_type == 'recurring' ? 'subscription' : 'payment'

  session_params = {
    line_items: [
      {
        price: price_id,
        quantity: 1,
      },
    ],
    mode: mode,
    # Defines where Stripe will redirect a customer after successful payment
    success_url: "#{ENV['DOMAIN']}/done?session_id={CHECKOUT_SESSION_ID}",
    # Defines where Stripe will redirect if a customer cancels payment
    cancel_url: "#{ENV['DOMAIN']}",
  }

  # Add Connect-specific parameters based on payment mode
  if mode == 'subscription'
    session_params[:subscription_data] ||= {}
    session_params[:subscription_data][:transfer_data] = {
      destination: account_id,
    }
  else
    session_params[:payment_intent_data] = {
      transfer_data: {
        destination: account_id,
      },
    }
  end

  session = Stripe::Checkout::Session.create(session_params)

  # Redirect to the Stripe hosted checkout URL
  redirect session.url, 303
end

post "/api/webhook" do
  request.body.rewind
  payload = request.body.read

  # Replace this endpoint secret with your endpoint's unique secret
  # If you are testing with the CLI, find the secret by running 'stripe listen'
  # If you are using an endpoint defined with the API or dashboard, look in your webhook settings
  # at https://dashboard.stripe.com/webhooks
  endpoint_secret = ""

  # Only verify the event if you have an endpoint secret defined.
  # Otherwise use the basic event deserialized directly.
  if endpoint_secret != ""
    signature = request.env["HTTP_STRIPE_SIGNATURE"]
    begin
      event = Stripe::Webhook.construct_event(payload, signature, endpoint_secret)
    rescue => e
      puts "Webhook signature verification failed. #{e.message}"
      halt 400
    end
  else
    event = JSON.parse(payload, symbolize_names: true)
  end

  case event[:type]
  when "checkout.session.completed"
    stripe_object = event[:data][:object]
    status = stripe_object[:status]
    puts "Checkout Session status is #{status}."
    # handle_checkout_session_completed(stripe_object)
  when "checkout.session.async_payment_failed"
    stripe_object = event[:data][:object]
    status = stripe_object[:status]
    puts "Checkout Session status is #{status}."
    # handle_checkout_session_failed(stripe_object)
  else
    # Unexpected event type
    puts "Unhandled event type #{event[:type]}."
  end

  status 200
end

post "/api/thin-webhook" do
  request.body.rewind
  payload = request.body.read

  # Replace this endpoint secret with your endpoint's unique secret
  # If you are testing with the CLI, find the secret by running 'stripe listen'
  # If you are using an endpoint defined with the API or dashboard, look in your webhook settings
  # at https://dashboard.stripe.com/webhooks
  thin_endpoint_secret = nil
  signature = request.env["HTTP_STRIPE_SIGNATURE"]
  begin
    event_notif = stripe_client.parse_event_notification(payload, signature, thin_endpoint_secret)
  rescue => e
    puts "Webhook signature verification failed. #{e.message}"
    halt 400
  end

  if event_notif.type == "v2.account.created"
    stripe_object = event_notif.fetch_related_object
    event = event_notif.fetch_event
    # handle_v2_account_created(stripe_object)
  else
    puts "Unhandled event type #{event_notif.type}."
  end
  status 200
end

# Create a login link for the connected account's dashboard
post "/api/create-login-link" do
  data = parse_request_body
  account_id = data['accountId']

  begin
    login_link = Stripe::Account.create_login_link(account_id)
    content_type :json
    { url: login_link.url }.to_json
  rescue Stripe::StripeError => e
    status 500
    { error: e.message }.to_json
  end
end

# Helper method to parse request body (supports both JSON and form data)
def parse_request_body
  request.body.rewind

  if request.content_type&.include?('application/json')
    JSON.parse(request.body.read)
  else request.content_type&.include?('application/x-www-form-urlencoded')
    params.to_h
  end
end

set :port, 4242
puts "Server running on port 4242"