ActiveRecord::Schema.define(version: 20150330000000) do
  create_table 'buckets', force: true do |t|
    t.string   'color'
    t.string   'material'
    t.integer  'person_id'
    t.boolean  'used'

    t.timestamps null: false
  end

  add_index 'buckets', ['person_id'], name: 'index_buckets_on_person_id', using: :btree

  create_table 'marbles', force: true do |t|
    t.string   'color'
    t.integer  'radius'
    t.integer  'bucket_id'

    t.timestamps null: false
  end

  add_index 'marbles', ['bucket_id'], name: 'index_marbles_on_bucket_id', using: :btree

  create_table 'people', force: true do |t|
    t.string   'name'
    t.string   'gender'
    t.integer  'age'

    t.timestamps null: false
  end

  create_table 'dishes', force: true do |t|
    t.string   'name'
    t.string   'ingredients', array: true, default: []
    t.integer  'person_id'

    t.timestamps null: false
  end

  add_index 'dishes', ['ingredients'], name: 'index_dishes_on_ingredients', using: :gin
  add_index 'dishes', ['person_id'], name: 'index_dishes_on_person_id', using: :btree

  create_table 'beverages', force: true do |t|
    t.string   'name'
    t.string   'flavors', array: true, default: []
    t.integer  'dish_id'

    t.timestamps null: false
  end

  add_index 'beverages', ['flavors'], name: 'index_beverages_on_flavors', using: :gin
  add_index 'beverages', ['dish_id'], name: 'index_beverages_on_dish_id', using: :btree
end
