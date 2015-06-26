# FastAPI [![Gem Version](https://badge.fury.io/rb/fastapi.svg)](http://badge.fury.io/rb/fastapi) [![Build Status](https://travis-ci.org/thestorefront/FastAPI.svg?branch=master)](https://travis-ci.org/thestorefront/FastAPI)

Easily create robust, standardized API endpoints using lightning-fast database queries

FastAPI is a Rails library for querying interdependent datasets quickly and
returning a human-readable, standard API output.

It works by constructing complex SQL queries that make efficient use of JOINs
and subqueries based upon model dependencies (namely `belongs_to`, `has_one`, and `has_many`).

In only a few lines of code you can decide which fields you wish to expose to
your endpoint, any filters you wish to run the data through, and create your controller.

# Preview

You can preview a live example of FastAPI at http://fastapi.herokuapp.com/

The repository is located at [thestorefront/fastapi_example](https://github.com/thestorefront/fastapi_example)


# Requirements

This gem requires Oj >= 2.9.9 for JSONification, ActiveRecord >= 3.2.0,
and ActiveSupport >= 3.2.0.

FastAPI currently supports PostegreSQL as a data layer.


# Installation

FastAPI is available via RubyGems using:

```bash
$ gem install fastapi
```

Otherwise, in any Gemfile in a rails project, use:

```ruby
require 'fastapi'
```


# Examples

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

If we wanted to expose a top-level `Person` API endpoint, we would use
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

(Can also use `rails generate controller Api::V1::Buckets` in the
terminal):

```ruby
class Api::V1::BucketsController < ApplicationController

  def index

    filters = request.query_parameters

    render json: Bucket.fastapi.filter(filters).response

  end

end
```

Boom! Run your server with `rails server` and hop your way over to
`http://yourserver[:port]/api/v1/buckets` to see your beautiful list of
`Buckets` in the FastAPI standard JSON format. :)

Try to filter your datasets as well:

`http://yourserver[:port]/api/v1/buckets/?color=red` or

`http://yourserver[:port]/api/v1/buckets/?color__in[]=red&color__in[]=blue`

There are many to play with, go nuts!

# Documentation

FastAPI has four core components:

1. `ActiveRecord::Base` extension that adds necessary class and instance methods.
2. `class FastAPI` which is instantiated by an  `ActiveRecord::Base` instance.
3. Filters, which provide a way of easily interfacing with your data.
4. FastAPI standard output, a strict way of displaying all FastAPI responses.

---

## ActiveRecord::Base (Extension)

### ClassMethods

#### fastapi_standard_interface
`fastapi_standard_interface( fields [Array] )`

Sets the standard interface for the top level of a fastapi response.
Can use any available fields for the model, or `belongs_to` and `has_many`
associations. Be sure to use the correct word form (singular vs. plural).

#### fastapi_standard_interface_nested
`fastapi_standard_interface_nested( fields [Array] )`

Sets the standard interface for the second level of a fastapi response
(nested). Will be referred to whenever this model is found nested in another
API response. Can use any available fields for the model, *does not support
associations*.

#### fastapi_default_filters
`fastapi_default_filters( filters [Hash] )`

Sets any default filters for the top level fastapi response. Will be
overridden if the same filter keys are provided when calling `.filter` on
a FastAPI instance. See *Filters* section for more information on available
filters.

#### fastapi_safe_field
`fastapi_safe_fields( fields [Array] )`

Sets safe fields for `FastAPIInstance.safe_filter`. These safe fields are a
*whitelist* for filters, meaning safe_filter will only allow filtering by these
fields.

#### fastapi
`fastapi`

Shorthand for the FastAPI constructor. Equivalent to `FastAPI.new(MyModel)`.
Recommended usage is `MyModel.fastapi`.

---

## class FastAPI

`FastAPI` instances provide a way to interface with your datasets and obtain
necessary information (for an API response or otherwise).

### InstanceMethods

#### initialize
`initialize( model [Model < ActiveRecord::Base] )`

Constructor. Automatically called using `Model.fastapi`, but can be used as
`FastAPI.new(Model)`. Binds the provided Model to the FastAPI instance.

#### filter
`filter( filters [Hash] = {} , meta [Hash] = {} )`

Compiles and executes an SQL query based on the supplied filters (see *Filters*
  section for more details). Can add additional fields to the expected meta
  response in the output, as keys in the `meta` Hash.

#### safe_filter
`safe_filter( filters [Hash] = {} , meta [Hash] = {} )`

Compiles and executes an SQL query based on the supplied filters (see *Filters*
  section for more details). Will only allow filtering by fields set in
  `fastapi_safe_fields`, or `fastapi_standard_interface` if not set. Can add
  additional fields to the expected meta response in the output, as keys in the
  `meta` Hash. Intended for use with `filters = request.query_parameters`.

#### fetch
`fetch( id [Integer] , meta [Hash] = {} )`

Similar to filter, but will retrieve a single object based on a single `id`.
Ideal for `show` on a resource, as FastAPI will still format the response
appropriately (and give a customized error for id not found).

#### data
`data`

Returns a Hash containing the data from the most recently executed `filter` or
`fetch` call.

#### data_json
`data_json`

Returns a JSONified string containing the information in `data`

#### meta
`meta`

Returns a Hash containing the metadata from the most recently executed `filter`
or `fetch` call.

#### meta_json
`meta_json`

Returns a JSONified string containing the information in `meta`

#### to_hash
`to_hash`

Returns a Hash containing both the data and metadata from the most recently
executed `filter` or `fetch` call.

#### response
`response`

Intended to return the final API response. Returns a JSONified string containing
the information available in the `to_hash` method.

#### reject
`reject( message [String] = 'Access Denied' )`

Returns a JSONified string representing a standardized empty API response, with
a provided error `message`. For example, if a user is not allowed to access a
resource, you would call `render json: Model.fastapi.reject`.

---

## Filters

Filters are a powerful tool in FastAPI that allow for granular control
of your API responses. `FastAPIInstance.filter` accepts them, and they are
also used in `ActiveRecord::Base::fastapi_default_filters`.

Filters work in the following way:
```ruby
Model.fastapi.filter({
  key1: 2,
  key2: 'three'
})
```

Will grab a subset of all `Models` where `:key1` is `2` *and* `:key2` is
`'three'`.

---

### Filter Comparators

What if we want to find a subset of `Models` where `:key1` is *greater than or
equal to (>=)* 5?

```ruby
Model.fastapi.filter({
  key1__gte: 5
})
```

It's that easy. The double underscore indicates you're using a filter
comparator, and `gte` stands for *g*reater *t*han or *e*qual to.

The available comparators are as follows:
(Descriptions marked with * indicate scalar inputs will be converted to arrays)

```
Scalar Fields

'is'              # Field == Value
'not'             # Field != Value
'gt'              # Field > Value
'gte'             # Field >= Value
'lt'              # Field < Value
'lte'             # Field <= Value
'like'            # Field contains Value (string)
'not_like'        # Field does not contain Value (string)
'ilike'           # Field contains Value (case ins.)
'not_ilike'       # Field does not contain Value (case ins.)
'null'            # Field is NULL
'not_null'        # Field is not NULL
'in'              # * Field is in Value
'not_in'          # * Field is not in Value

Array Fields

'subset'          # * Field is a subset of Value
'not_subset'      # * Field is not a subset of Value
'contains'        # * Value is a subset of Field
'not_contains'    # * Value is not a subset of Field
'intersects'      # * Field and Value have shared elements
'not_intersects'  # * Field and Value have no shared elements
```

If your key contains a double underscore, make sure to use the `__is` comparator
if you look for a specific value.

---

### Filters in HTTP Requests

If you'd like to allow for client-side data filtration (highly recommended),
simply use the following in your API endpoint controller:

```ruby
filters = request.query_parameters
render json: Model.fastapi.filter(filters).response
```

This will allow you to use filters (and their comparators) in the HTTP
query parameters.

For example, `http://yourapp/api/v1/users/?active=t&age__gte=19&age__gte=35`
could return all active users between 19 and 35 years old.

---

### Data Types in HTTP Requests

While using FastAPI, boolean fields are automatically
detected, and the strings `'t'` and `'f'` are converted to `true` and `false`,
respectively. The same goes for integers. (Converted from string to int.)

---

### Sorting

In FastAPI, sorting is accomplished using a special filter: `:__order`


`:__order` Can be in the format of `'key'`, `'key,DIRECTION'` or
`[:key, 'DIRECTION']` where DIRECTION is `ASC` or `DESC`. (Default `ASC`.)

An example, order users by age (ascending):

```ruby
render json: User.fastapi.filter({__order: [:age, ASC]}).response
```

Or perhaps via HTTP (hitting an endpoint with `request.query_parameters` as the
  filter):

```
http://yourapp/api/v1/users/?__order=age,ASC
```

---

### Pagination

In FastAPI we opted for very robust, granular control of API responses. "Pages"
do not exist in a strict sense, but rather by `:__offset` and `:__count`, much
like you'd expect in a traditional database query.

For example,

```ruby
render json: Model.fastapi.filter({__offset: 100, __count: 100}).response
```

Would return (up to) 100 results from Model, beginning at result number 100.
(Page 2 at 100 results per page.)


# Standard Output

FastAPI has a very strict, standard way of outputting data in the form of
a response.

Responses will always look like the following:

```javascript
{
  'meta': {
    'total': 0,
    'count': 0,
    'offset': 0,
    'error': null,
  },
  'data': []
}
```

Where `meta.total` is the total number of records in the entire dataset,
`meta.count` is the number of records in the response, `meta.offset` is the
offset of the first record of the response, and `meta.error` is `null` if there
was no error, or a string containing an error message if there was an error.

`data` will always be an Array of Objects. If there was an error with the
response, data will be empty. If the response was formed by a
`FastAPIInstance.fetch` call and a record was retrieved, `data` will be a
length-1 Array.


# Credits

Thanks for reading! We welcome contributors with good ideas, and we're always
looking for new talent.

FastAPI was created by [Keith Horwood](http://keithwhor.com/) and [Trevor Strieber](http://strieber.org) of
[Storefront, Inc.](https://thestorefront.com/) in 2014 and is (happily!) MIT
licensed.


Twitter:
[@keithwhor](https://twitter.com/keithwhor),
[@TrevorStrieber](https://twitter.com/TrevorStrieber),
[@Storefront](https://twitter.com/storefront)


Github:
[keithwhor](https://github.com/keithwhor),
[TrevorS](https://github.com/TrevorS),
[thestorefront](https://github.com/thestorefront)

Most recent version of the gem is available at [RubyGems.org: fastapi](https://rubygems.org/gems/fastapi)
