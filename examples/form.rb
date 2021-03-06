require 'dry-validation'

schema = Dry::Schema.Params do
  required(:email).filled

  required(:age).filled(:int?, gt?: 18)
end

errors = schema.call('email' => '', 'age' => '18').messages

puts errors.inspect
