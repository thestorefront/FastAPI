describe Person do
  it_behaves_like 'fastapi_model'

  describe 'when locating a specific person' do
    let!(:person)  { create(:example_person) }
    let(:response) { ModelHelper.response(Person, name: 'Example Person') }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes pets) } }
    end
  end

  describe 'when locating a person using greater than' do
    let!(:people)  { create_list(:person, 15) }
    let(:response) { ModelHelper.response(Person, age__gte: 0) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 15, count: 15, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes pets) } }
    end
  end

  describe 'when locating a person using less than' do
    let!(:young_person) { create(:person, name: 'Young Dude', age: 15) }
    let!(:older_person) { create(:person, name: 'Old Guy', age: 65) }

    let(:response) { ModelHelper.response(Person, age__lt: 20) }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes pets) } }
    end

    it 'has the correct name' do
      expect(response['data'].first['name']).to eq 'Young Dude'
    end
  end

  describe 'when whitelisting person attributes' do
    let!(:person) { create(:person) }

    describe 'as arguments' do
      let(:response) { ModelHelper.response(Person, {}, whitelist: 'created_at') }

      it_behaves_like 'fastapi_meta' do
        let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
      end

      it_behaves_like 'fastapi_data' do
        let(:expected) { { attributes: %w(id name gender age buckets dishes created_at pets) } }
      end
    end

    describe 'as an array' do
      let(:response) { Oj.load(Person.fastapi.whitelist([:created_at]).filter.response) }

      it_behaves_like 'fastapi_meta' do
        let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
      end

      it_behaves_like 'fastapi_data' do
        let(:expected) { { attributes: %w(id name gender age buckets dishes created_at pets) } }
      end
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
      let(:expected) { { attributes: %w(id name gender age buckets dishes pets) } }
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

  describe 'when locating an owner (person) associated with a pet' do
    let!(:person)         { create(:person_with_pets) }
    let(:response)        { ModelHelper.response(Pet) }
    let(:person_from_pet) { response['data'].first['owner'] }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 5, count: 5, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { data: person_from_pet, attributes: %w(id name gender age) } }
    end
  end

  describe 'when overriding meta' do
    let!(:people)  { create_list(:person, 5) }
    let(:response) { ModelHelper.response(Person, {}, meta: { total: 1, offset: 1, count: 1}) }

    it 'has the correct actual count' do
      expect(Person.count).to eq 5
    end

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 1, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets dishes pets) } }
    end
  end

  describe 'when spoofing! a single model' do
    let!(:person)          { create(:person_with_buckets) }
    let(:response)         { ModelHelper.spoof!(Person, person) }
    let(:retrieved_person) { response["data"].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age) } }
    end

    it 'has the correct count' do
      expect(response["data"].size).to eq 1
    end

    it 'has the correct id' do
      expect(retrieved_person["id"]).to eq person.id
    end

    it 'has the correct name' do
      expect(retrieved_person["name"]).to eq person.name
    end

    it 'has the correct gender' do
      expect(retrieved_person["gender"]).to eq person.gender
    end

    it 'has the correct age' do
      expect(retrieved_person["age"]).to eq person.age
    end
  end

  describe 'when spoofing! without preload' do
    let!(:person)          { create(:person_with_buckets) }
    let(:people)           { Person.all }
    let(:response)         { ModelHelper.spoof!(Person, people) }
    let(:retrieved_person) { response["data"].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age) } }
    end

    it 'has the correct count' do
      expect(response["data"].size).to eq 1
    end

    it 'has the correct id' do
      expect(retrieved_person["id"]).to eq person.id
    end

    it 'has the correct name' do
      expect(retrieved_person["name"]).to eq person.name
    end

    it 'has the correct gender' do
      expect(retrieved_person["gender"]).to eq person.gender
    end

    it 'has the correct age' do
      expect(retrieved_person["age"]).to eq person.age
    end
  end

  describe 'when spoofing! using a whitelist' do
    let!(:person)          { create(:person_with_buckets) }
    let(:people)           { Person.all }
    let(:response)         { ModelHelper.spoof!(Person, people, whitelist: :created_at) }
    let(:retrieved_person) { response["data"].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age created_at) } }
    end
  end

  describe 'when spoofing! using preload' do
    let!(:person)          { create(:person_with_buckets) }
    let(:people)           { Person.eager_load(:buckets) }
    let(:response)         { ModelHelper.spoof!(Person, people) }
    let(:retrieved_person) { response["data"].first }

    it_behaves_like 'fastapi_meta' do
      let(:expected) { { total: 1, count: 1, offset: 0, error: false } }
    end

    it_behaves_like 'fastapi_data' do
      let(:expected) { { attributes: %w(id name gender age buckets) } }
    end

    it 'has the correct count' do
      expect(response["data"].size).to eq 1
    end

    it 'has the correct id' do
      expect(retrieved_person["id"]).to eq person.id
    end

    it 'has the correct name' do
      expect(retrieved_person["name"]).to eq person.name
    end

    it 'has the correct gender' do
      expect(retrieved_person["gender"]).to eq person.gender
    end

    it 'has the correct age' do
      expect(retrieved_person["age"]).to eq person.age
    end

    describe 'preloaded buckets' do
      let(:buckets)             { retrieved_person["buckets"] }
      let(:associated_bucket)   { buckets.first }
      let(:actual_first_bucket) { Bucket.find(associated_bucket["id"]) }

      it_behaves_like 'fastapi_data' do
        let(:expected) { { data: associated_bucket, attributes: %w(id color material used) } }
      end

      it 'has five buckets' do
        expect(buckets.size).to eq person.buckets.size
      end

      it 'the first bucket has the correct id' do
        expect(associated_bucket["id"]).to eq actual_first_bucket.id
      end

      it 'the first bucket has the correct color' do
        expect(associated_bucket["color"]).to eq actual_first_bucket.color
      end

      it 'the first bucket has the correct material' do
        expect(associated_bucket["material"]).to eq actual_first_bucket.material
      end

      it 'the first bucket has the correct used value' do
        expect(associated_bucket["used"]).to eq actual_first_bucket.used
      end
    end
  end
end
