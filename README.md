FastAPI
=======

Easily create robust, standardized API endpoints using lightning-fast database queries

FastAPI is a Rails library for querying interdependent datasets quickly and
returning a human-readable, standard API output.

It works by constructing complex SQL queries that make efficient use of JOINs
and subqueries based upon model dependencies (namely `belongs_to` and `has_many`).

In only a few lines of code you can decide which fields you wish to expose to
your endpoint, any filters you wish to run the data through, and create your controller.

Examples
========

Let's say we have three models. `Person`, `Bucket`, and `Marble`.
Each `Bucket` belongs to a `Person` and can have many `Marbles`.

Your model for `Bucket` might look something like this:

```ruby
class Bucket < ActiveRecord::Base

  belongs_to :person
  has_many :marbles

end
```

Assume `Bucket` also has the fields `:color`, and `:material`.

Each `Marble` can have `:color` and `:radius`.

Every `Person` has a `:name`, `:gender` and `:age`.

We want to expose a list of `Buckets` as a JSONified API endpoint that contains
records that look like the following:

```javascript
  {
    'id': 1,
    'color': 'blue',
    'material': 'plastic',
    'person': {
      'id': 107,
      'name': 'Mary-anne',
      'gender': 'Female',
      'age': 27
    },
    'marbles': [
      {
        'id': 22,
        'color': 'red',
        'radius': 5
      },
      {
        'id': 76,
        'color': 'green',
        'radius': 7
      }
    ]
  }
```

In order to do that we first look at our `Bucket` model and add the following:

```ruby
class Bucket < ActiveRecord::Base

  belongs_to :person
  has_many :marbles

  # A "standard interface" is a list of user-exposed fields for the endpoint
  fastapi_standard_interface [
    :id,
    :color,
    :material,
    :person,
    :marbles
  ]

end
```

We then modify our `Person` model:

```ruby
class Person < ActiveRecord::Base

  # Person is not top-level in the case of the "buckets"
  #   endpoint... we use a special setting indicating
  #   which fields to use if Person happens to be nested.

  # You can NOT include dependent fields here. (belongs_to, has_many)
  #   This is a hard-and-fast FastAPI rule that prevents overly
  #   complex nesting scenarios.

  fastapi_standard_interface_nested [
    :id,
    :name,
    :gender,
    :age
  ]

end
```

Keep in mind that this will only affect the cases where `Person` is a nested
object.

If we wanted to expose a top-level `Person` api endpoint, we would use
`fastapi_standard_interface` as well.

Finally, we must modify our `Marble` model in the same way:

```ruby
class Marble < ActiveRecord::Base

  fastapi_standard_interface_nested [
    :id,
    :color,
    :radius
  ]

end
```

Hmm... let's say we only want to list the `Marbles` that have a radius *less than or equal
to (<=)* 10. Easy! We go back and modify our `Bucket` model. Add the following
to `class Bucket < ActiveRecord::Base`:

```ruby
  # top level filters affect the data that is shown,
  #   while filters on "has_many" fields affect which rows are shown per
  #   record
  fastapi_default_filters({
    marbles: {
      radius__lte: 10
    }
  })
```

*Phew!* We're almost done. Now to create the endpoint.

First open `config/routes.rb` and add the following:

```ruby
namespace :api do
  namespace :v1, defaults: {format: :json} do
    resource :buckets
  end
end
```


We now create a route to an API controller for
`Bucket` in `app/controllers/api/v1/buckets_controller.rb`

(Can also use `rails generate controller Api::V1::BucketController` in the
terminal):

```ruby
class Api::V1::BucketController < ApplicationController

  def index

    filters = request.query_parameters

    render json: Bucket.fastapi.filter(filters).response

  end

end
```

Boom! Run your server with `rails s` and hop your way over to
`http://yourserver[:port]/api/v1/buckets` to see your beautiful list of
`Buckets` in the FastAPI standard JSON format. :)

Try to filter your datasets as well:

`http://yourserver[:port]/api/v1/buckets?color=red` or

`http://yourserver[:port]/api/v1/buckets?color__in[]=red&color__in[]=blue`

There are many to play with, go nuts!
