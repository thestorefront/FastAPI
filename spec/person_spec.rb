describe Person do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific person' do
    let!(:person)  { create(:example_person) }
    let(:response) { ModelHelper.response(Person, name: 'Example Person') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes) } }
    end
  end

  describe 'when locating a person using greater than' do
    let!(:people)  { create_list(:person, 15) }
    let(:response) { ModelHelper.response(Person, age__gte: 0) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 15, count: 15, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes) } }
    end
  end

  describe 'when locating a person using less than' do
    let!(:young_person) { create(:person, name: 'Young Dude', age: 15) }
    let!(:older_person) { create(:person, name: 'Old Guy', age: 65) }

    let(:response) {ModelHelper.response(Person, age__lt: 20) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes) } }
    end

    it 'has the correct name' do
      expect(response['data'].first['name']).to eq 'Young Dude'
    end
  end

  describe 'when whitelisting person attributes' do
    let!(:person) { create(:person) }
    let(:response) { ModelHelper.response(Person, {}, whitelist: 'created_at') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes created_at) } }
    end
  end

  describe 'when locating a person by id' do
    let!(:person)        { create(:person) }
    let(:response)       { ModelHelper.fetch(Person, person.id) }
    let(:fetched_person) { response['data'].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes) } }
    end

    it 'has the correct id' do
      expect(fetched_person['id']).to eq person.id
    end
  end

  describe 'when locating a person that does not exist by id' do
    let(:response) { ModelHelper.fetch(Person, 100) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 0, count: 0, offset: 0, error: /\w+ with id: \d+ does not exist/ } }
    end

    it 'has an empty data array' do
      expect(response['data']).to eq []
    end
  end

  describe 'when locating a person associated with a bucket' do
    let!(:person)            { create(:person_with_buckets) }
    let(:response)           { ModelHelper.response(Bucket) }
    let(:person_from_bucket) { response['data'].first['person'] }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 5, count: 5, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: person_from_bucket, attributes: %w(id name gender age) } }
    end
  end
end
