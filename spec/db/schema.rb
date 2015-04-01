ActiveRecord::Schema.define(version: 20150330000000) do
  create_table 'buckets', force: true do |t|
    t.string   'color'
    t.string   'material'
    t.integer  'person_id'

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
end
