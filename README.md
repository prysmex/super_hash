# SuperHash

The idea of the SuperHash is to provide hashes with extended functionality by adding the concept of 'attributes'.
Attributes allow to have a powerful API for controlling what data can be set and more control over how the data is managed.

SuperHash provides:

- All the power of dry-types gem for each attribute! [dry-types](https://github.com/dry-rb/dry-types).
- Requiring some keys to be present with error raising
- Setting a default value to a key
- Setting transforms for specific keys
- Ensuring all keys are symbolized
- Accepting only whitelisted keys (default behavior)


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'super_hash'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install super_hash

## Usage


### Create a simple class
Let's create Person class that extends from SuperHash::Hasher with 3 attributes: gender, name and age

```ruby
class Person < ::SuperHash::Hasher
    attribute :'name'
    attribute :'age'
    attribute :gender
end

# we can now create our first person object
person = Person.new({name: 'John', age: 22, gender: 'male'})
person[:name] # 'John'
person[:age] # 22
person[:gender] # 'male'

# SuperHash extends from a ruby Hash so we can call any methods we want on it!
# person.is_a? Hash # => true
```

In this simple example all attributes are required, so this will fail 
```ruby
person = Person.new({name: 'John', age: 22}) # SuperHashExceptions::PropertyError (The attribute 'gender' is required)
person = Person.new({name: 'John', age: 22, gender: nil}) # SuperHashExceptions::PropertyError (The attribute 'gender' is required)
```

### Optional attributes
To create an optional attribute we use the `attribute?` class methodm instead of `attribute`.

```ruby
class Person < ::SuperHash::Hasher
    attribute :'name'
    attribute :'age'
    attribute? :gender
end

# this now works!
person = Person.new({name: 'John', age: 22})
person2 = Person.new({name: 'John', age: 22, gender: 'male'})
```

### Dynamic attributes

In the previous examples, assigning an unknown attribute will cause an exception
```ruby
person = Person.new({name: 'John', age: 22, likes_coffee: false}) # SuperHashExceptions::PropertyError (The attribute 'likes_coffee' is required)
```

To allow dynamic attributes we need to set the instance variable `@allow_dynamic_attributes` as true
```ruby
class Person < ::SuperHash::Hasher
    
    instance_variable_set('@allow_dynamic_attributes', true)
    
    attribute :'name'
    attribute :'age'
    attribute? :gender
end

# Now we know John does not like coffee
person = Person.new({name: 'John', age: 22, likes_coffee: false})
```
### Attribute validations

If we want to add validations to our attributes we can use the power of dry-types gem
```ruby
class Person < ::SuperHash::Hasher
    
    instance_variable_set('@allow_dynamic_attributes', true)
    
    attribute :'name'
    attribute :'age', {
        type: Types::Integer
    }
    attribute? :gender, {
        type: Types::String.optional # allow nil values
    }
end

person = Person.new({name: 'John', age: '22'}) # Dry::Types::ConstraintError ("22" violates constraints (type?(Integer, "22") failed))
person = Person.new({name: 'John', age: nil}) # SuperHashExceptions::PropertyError (The attribute 'age' is required)
person = Person.new({name: 'John', age: 22, gender: nil}) # Notice the .optional modifier on `gender` type validation
```

### Default values

```ruby
class Person < ::SuperHash::Hasher
    
    instance_variable_set('@allow_dynamic_attributes', true)
    
    attribute :'name'
    attribute :'nickname', {
        default: ->(instance) { instance[:name] }
    }
    attribute :'age', {
        type: Types::Integer
    }
    attribute? :gender, {
        type: Types::String.optional # allow nil values
    }
    attribute :children, {
        type: Types::Array.default([].freeze)
    }
end

# notice that data is required but does not fail due to default value
person = Person.new({name: 'John', age: 22}) # {:name=>"John", :age=>22, :nickname=>"John", :children=>[]}
```

### Attribute transforms
```ruby

class Person < ::SuperHash::Hasher
    
    instance_variable_set('@allow_dynamic_attributes', true)
    
    CHILDREN_PROC = ->(instance, childrenArray) {
        childrenArray.map do |child|
            Person.new(child)
        end
    }
    
    attribute :'name'
    attribute :'nickname', {
        default: ->(instance) { instance[:name] }
    }
    attribute :'age', {
        type: Types::Integer
    }
    attribute? :gender, {
        type: Types::String.optional # allow nil values
    }
    attribute :children, {
        type: Types::Array.default([].freeze),
        transform: CHILDREN_PROC
    }
end

person = Person.new({name: 'John', age: 22, children: [{name: 'John Jr', age: 2}]})

person.class #Person
person[:children].first.class #Person
```

### Callbacks (ToDo)


## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/super_hash.
